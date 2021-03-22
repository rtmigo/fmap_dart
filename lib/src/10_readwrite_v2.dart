// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '00_common.dart';
import '10_files.dart';
import 'byte_sequence.dart';

const HEADER_SIZE = 9;
const TOC_ENTRY_SIZE_EXCEPT_KEY = 2 + 4;

const FILE_BEGIN_MAGIC_BYTES_1723 = 0x1723;
const ENTRY_BEGIN_MARKER = 0x17;
const ENTRY_END_MARKER = 0x23;


class RawBlobHeader {
  RawBlobHeader(this.keyAsBytes, this.blobData) {
    if (keyAsBytes.length > 0xFFFF) {
      throw ArgumentError.value(keyAsBytes.length, "keyAsBytes.length", "The key is too long.");
    }
    if (blobData.length > 0xFFFFFFFF) {
      throw ArgumentError.value(blobData.length, "data.length", "The data is too large.");
    }
  }

  final List<int> keyAsBytes;
  final List<int> blobData;

  int get headerSize => 4 + 2 + keyAsBytes.length; // 32-bit blob size, 16-bit key length, key
}

/// Saves a set of blob records to a file. Each record has a [String] key and bytes
/// as as `List<int>`, nothing else. The file is essentially an analog of the TAR
/// format, but extremely minimized.
///
/// File format
/// -----------
///
/// **Header**
///
///   - 2 magic bytes 0x1723
///   - 1 byte with file format version (always =2)
///   - 2 bytes with blobsCount
///   - 4 bytes with TOC size in bytes
///
/// **TOC**
///
///   Contains the same count of entries, as blobsCount
///   Each entry is
///
///   - 4 bytes blob size in bytes
///   - 2 bytes key length
///   - the key string encoded in UTF-8
///
/// **Body**
///
///   Contains the same count of entries, as blobsCount.
///   Each entry is
///
///   - 1 byte 0x17 - for consistency checking
///   - the blob data
///   - 1 byte 0x23 - for consistency checking
///
/// So limitations are:
///   - blob size max 4 Gb
///   - UTF8 key size max 64 kb
///   - entries count: ~64k
///
/// If all the entries will have ridiculously long keys, with 64k entries
/// sized larger than 64k we can also hit max TOC size: 4 Gb.
void writeBlobsSyncV2(File targetFile, Map<String, List<int>> blobs) {

  // This implementation assumes that we can easily keep in RAM all the blobs that
  // we are going to save.

  final chunks = blobs.entries.map((e) => RawBlobHeader(utf8.encode(e.key), e.value));

  final tocSize = chunks.isEmpty ? 0 : chunks.map((e) => e.headerSize).reduce((a, b) => a + b);
  if (tocSize > 0xFFFFFF) {
    throw ArgumentError.value(tocSize, "tocSize", "TOC is too long.");
  }

  RandomAccessFile raf = targetFile.openSync(mode: FileMode.write);
  try {
    // HEADER //
    final headerBuffer = ByteSequence(ByteData(HEADER_SIZE));

    headerBuffer.writeUint16(FILE_BEGIN_MAGIC_BYTES_1723); // magic bytes
    headerBuffer.writeUint8(2); // file version number
    headerBuffer.writeUint16(blobs.length); // big-endian 16-bit blobs count
    headerBuffer.writeUint32(tocSize); // big-endian 32-bit size of toc
    raf.writeFromSync(headerBuffer.data.buffer.asInt8List());

    // TOC //
    for (final chunk in chunks) {
      // a buffer to hold key length and data length
      final numbersBuffer = ByteData(TOC_ENTRY_SIZE_EXCEPT_KEY);

      assert(chunk.blobData.length >= 0 && chunk.blobData.length <= 0xFFFFFFFF);
      numbersBuffer.setUint32(0, chunk.blobData.length);

      assert(chunk.keyAsBytes.length >= 0 && chunk.keyAsBytes.length <= 0xFFFF);
      numbersBuffer.setUint16(4, chunk.keyAsBytes.length);

      raf.writeFromSync(numbersBuffer.buffer.asInt8List()); // writing two numbers
      raf.writeFromSync(chunk.keyAsBytes); // writing the UTF8-converted key string
    }

    assert(HEADER_SIZE + tocSize == raf.positionSync());

    // BODY //
    for (final chunk in chunks) {
      raf.writeByteSync(ENTRY_BEGIN_MARKER);
      raf.writeFromSync(chunk.blobData);
      raf.writeByteSync(ENTRY_END_MARKER);
    }
  } finally {
    raf.closeSync();
  }
}

enum Decision { readAndContinue, skipAndContinue, readAndStop }

typedef ShouldWeReadIt = Decision Function(String key);

class FoundEntry {
  FoundEntry(this.key, this.position, this.size);

  String key;
  int position;
  int size;
}


/// Reads the data from file previously written by [writeBlobsSyncV2].
///
/// The entry search time is O(number of entries).
Iterable<MapEntry<String, Uint8List>> readBlobsSyncV2(
    File sourceFile, ShouldWeReadIt shouldWeRead, {
      bool mustExist = true
    }
    ) sync* {

  // opening file, ignoring "file not exist" errors if mustExist is false    
  RandomAccessFile raf;
  try {
    raf = sourceFile.openSync(mode: FileMode.read);
  } on FileSystemException catch (exc) {
    if (!mustExist && isFileNotFoundException(exc)) {
      return;
    } else {
      rethrow;
    }
  }

  try {
    final headerBuffer = ByteSequence(ByteData.sublistView(raf.readSync(HEADER_SIZE)));
    int currentPos = HEADER_SIZE;
    assert(currentPos == raf.positionSync());

    int magicBytes = headerBuffer.readUint16();
    int version = headerBuffer.readUint8(); // file version number
    int entriesCount = headerBuffer.readUint16(); // big-endian 16-bit blobs count
    int tocSize = headerBuffer.readUint32(); // big-endian 32-bit size of toc

    if (magicBytes != FILE_BEGIN_MAGIC_BYTES_1723) {
      throw FileFormatError('Magic bytes not found at the beginning of the file.');
    }

    if (version != 2) {
      throw FileFormatError('Unexpected version number');
    }

    final entriesToRead = <FoundEntry>[];

    int sumPreviousBlobsSize = 0;

    for (var i = 0; i < entriesCount; ++i) {
      final numbersView = ByteData.sublistView(raf.readSync(TOC_ENTRY_SIZE_EXCEPT_KEY));

      currentPos += TOC_ENTRY_SIZE_EXCEPT_KEY;
      final blobSize = numbersView.getUint32(0); // bytes count in the blob
      final keySize = numbersView.getUint16(4); // length of the UTF8-encoded key

      final keyBytes = raf.readSync(keySize);
      currentPos += keySize;
      assert(currentPos == raf.positionSync());

      final keyString = utf8.decode(keyBytes);

      final should = shouldWeRead(keyString);

      if (should == Decision.readAndContinue || should == Decision.readAndStop) {
        final position = HEADER_SIZE + tocSize + sumPreviousBlobsSize;
        entriesToRead.add(FoundEntry(keyString, position, blobSize));
      }

      sumPreviousBlobsSize += blobSize+2; // blob and two one-byte markers

      if (should == Decision.readAndStop) {
        break;
      }
    }

    // we have read the header. The rest of the file is a sequence of blobs and nothing more
    assert(currentPos == raf.positionSync());

    for (final entry in entriesToRead) {
      if (currentPos != entry.position) {
        raf.setPositionSync(entry.position);
        currentPos = entry.position;
        assert(currentPos == raf.positionSync());
      }

      if (raf.readByteSync()!=ENTRY_BEGIN_MARKER) {
        throw FileFormatError(
            "Entry begin marker not found.");
      }

      currentPos += 1;
      assert(currentPos == raf.positionSync());

      final blobBytes = raf.readSync(entry.size);
      currentPos += blobBytes.length;
      assert(currentPos == raf.positionSync());

      if (raf.readByteSync()!=ENTRY_END_MARKER) {
        throw FileFormatError(
            "Entry end marker not found.");
      }

      currentPos += 1;
      assert(currentPos == raf.positionSync());


      if (blobBytes.length != entry.size) {
        throw FileFormatError(
            "Unexpected count of bytes read: ${blobBytes.length} instead of ${entry.size}.");
      }
      yield MapEntry(entry.key, blobBytes);
    }
  } finally {
    raf.closeSync();
  }

}

void createModifiedCopy(File sourceFile, File targetFile, Map<String,List<int>> entriesToAdd, Set<String> keysToRemove) {

  throw UnimplementedError();
  
  bool isKeyToKeep(String key) => !(keysToRemove.contains(key) || entriesToAdd.containsKey(key));

  for (final oldEntry in readBlobsSyncV2(sourceFile,
      (key) => isKeyToKeep(key) ? Decision.readAndContinue : Decision.skipAndContinue)) {}

  try {
    
  }
  on FileSystemException catch (exc) {
    if (isFileNotFoundException(exc)) {
      
    } else {
      rethrow;  
    }
  }
}