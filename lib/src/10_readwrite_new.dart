// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _EACH_ENTRY_HEADER_BYTES_LENGTH = 2 + 4; // except the string key

/// Saves a set of blob records to a file. Each record has a [String] key and bytes
/// as as `List<int>`, nothing else. The file is essentially an analog of the TAR
/// format, but extremely minimized.
///
/// All keys of all records are saved at the beginning of the file, all blob data
/// goes later. To start reading the data, we will have to read all the headers with
/// all the keys. This is the only way to understand where the header ends and
/// where the data begins.
///
/// This is done intentionally: we assume that each file stores a minimum number
/// of blob records: most often exactly one. And the header is an extremely important
/// piece of information. It is almost always easier for us to read everything
/// that is written in the header than to make unnecessary `setPositionSync` calls,
/// which would be necessary if the keys were scattered around the file along
/// with their blobs.
void writeBlobsSync(File targetFile, Map<String, List<int>> blobs) {
  RandomAccessFile raf = targetFile.openSync(mode: FileMode.write);

  // to be sure that the order of entries will not change
  // when we iterate it fo the second time
  final entriesList = blobs.entries.toList(growable: false);

  try {
    // saving file format version number (one byte)
    // and the blobs count (two bytes big-endian)
    raf.writeFromSync([3, (blobs.length & 0xFF00) >> 8, blobs.length & 0xFF]);

    // writing all headers
    for (final entry in entriesList) {
      // converting key to bytes
      final keyAsBytes = utf8.encode(entry.key);

      // a buffer to hold key length and data length
      final numbersBuffer = ByteData(_EACH_ENTRY_HEADER_BYTES_LENGTH);

      // key length to the buffer
      if (keyAsBytes.length > 0xFFFF) {
        throw ArgumentError.value(entry.key, "entry.key", "The key is too long.");
      }
      numbersBuffer.setUint16(0, keyAsBytes.length);

      // data length to the buffer
      final List<int> blob = entry.value;
      if (blob.length > 0xFFFFFFFF) {
        throw ArgumentError.value(blob.length, "blob.length", "Blob is too large.");
      }
      numbersBuffer.setUint32(2, blob.length);

      // writing the buffer (two numbers)
      raf.writeFromSync(numbersBuffer.buffer.asInt8List());

      // saving the UTF8-converted key string
      raf.writeFromSync(keyAsBytes);
    }

    // writing all data
    for (final entry in entriesList) {
      raf.writeFromSync(entry.value);
    }
  } finally {
    raf.closeSync();
  }
}

typedef ShouldWeReadIt = bool Function(String key);

/// Reads the data from file previously written by [writeBlobsSync].
Iterable<MapEntry<String, Uint8List>> readBlobsSync(
    File sourceFile, ShouldWeReadIt shouldWeRead) sync* {
  RandomAccessFile raf = sourceFile.openSync(mode: FileMode.read);
  try {
    int currentPos = 0;
    final firstThree = raf.readSync(3);
    currentPos += 3;
    if (firstThree[0] != 3) {
      throw UnsupportedError('Unexpected version number');
    }

    int entriesCount = (firstThree[1] << 8) | firstThree[2];

    final keysAndBlobSizes = <MapEntry<String, int>>[];

    for (var i = 0; i < entriesCount; ++i) {
      final numbersView = ByteData.sublistView(raf.readSync(_EACH_ENTRY_HEADER_BYTES_LENGTH));
      //print(numbersView.buffer.lengthInBytes);
      currentPos += _EACH_ENTRY_HEADER_BYTES_LENGTH;
      final keyBytesLen = numbersView.getUint16(0); // length of the UTF8-encoded key
      final dataLen = numbersView.getUint32(2); // bytes count in the blob
      final keyAsBytes = raf.readSync(keyBytesLen);
      currentPos += keyBytesLen;
      final keyAsString = utf8.decode(keyAsBytes);

      // now we know the String key of this entry and size of blob in bytes.
      // But we don't know the position of the blob in the file.
      // All blobs are stored after the header, and the header has variable length.
      // So we'll just remember it for now
      keysAndBlobSizes.add(MapEntry(keyAsString, dataLen));
    }

    // we have read the header. The rest of the file is a sequence of blobs and nothing more
    assert(currentPos == raf.positionSync());
    int blobsStartPos = currentPos;


    int sumBlobsSize = 0;
    for (final keyAndSize in keysAndBlobSizes) {
      final blobLength = keyAndSize.value;
      if (shouldWeRead(keyAndSize.key)) {
        final thisBlobStartPos = blobsStartPos + sumBlobsSize;
        if (thisBlobStartPos != currentPos) {
          raf.setPositionSync(thisBlobStartPos);
          currentPos = thisBlobStartPos;
        }
        final blobBytes = raf.readSync(blobLength);
        //assert();
        if (blobBytes.length != blobLength) {
          throw AssertionError(
              "Unexpected count of bytes read: ${blobBytes.length} instead of $blobLength.");
        }
        yield MapEntry(keyAndSize.key, blobBytes);
        currentPos += blobBytes.length;
        assert(currentPos == raf.positionSync());
      }

      sumBlobsSize += keyAndSize.value;
    }
  } finally {
    raf.closeSync();
  }
}
