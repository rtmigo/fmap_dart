// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_errors/file_errors.dart';

import '00_common.dart';
import 'byte_sequence.dart';

const SIGNATURE_BYTE_1 = 0x4B;
const SIGNATURE_BYTE_2 = 0x42;

const ENTRY_END_MARKER = 0x42;

/// The file is essentially an analog of the TAR format, but extremely minimized.
///
/// Each record has a [String] key and bytes as as `List<int>`, nothing else.
///
/// File format
/// ===========
///
/// **Header**
///
///   Size    | Content
///   --------|-----------------------------------------
///   2 bytes | signature 0x4B 0x42 (ASCII "KB")
///   1 byte  | format version (always = 0x03)
///
/// **Body**
///
/// Contains variable number of entries
/// Each entry is
///
///   Size     | Content
///   ---------|-----------------------------------------
///   2 bytes  | key size in bytes
///   4 bytes  | blob size in bytes
///   variable | key string encoded in UTF-8
///   variable | the blob data
///   1 byte   | constant 0x42 - for consistency checking
///
/// So limitations are:
///   - blob size max 4 Gb
///   - UTF8 key size max 64 kb
///
/// Sample usage
/// ============
///
/// ``` dart
/// final writer = BlobsFileWriter(file);
/// writer.writeEntry('a', [1,2,3]);
/// writer.writeEntry('b', [5,6]);
/// writer.closeSync();
/// ```
///
class BlobsFileWriter {
  BlobsFileWriter(this.file);

  final File file;
  RandomAccessFile? _raf;
  final _savedKeys = Set<String>();

  void _openAndWriteHeader() {
    assert(this._raf == null);
    this._raf = this.file.openSync(mode: FileMode.write);
    this._raf!.writeFromSync([SIGNATURE_BYTE_1, SIGNATURE_BYTE_2, 0x03]);
  }

  void write(String key, List<int> blob) {
    if (this._raf == null) {
      this._openAndWriteHeader();
    }
    assert(this._raf != null);

    // we assume that we have a moderate amount of entries: we can keep all the keys in RAM
    if (_savedKeys.contains(key)) {
      throw ArgumentError.value(key, "key", "The key already added");
    }

    final List<int> keyBytes = utf8.encode(key);

    if (keyBytes.length > 0xFFFF) {
      throw ArgumentError.value(keyBytes.length, "keyBytes.length", "The key is too long.");
    }

    // ENTRY HEADER

    final entryHeaderBuffer = ByteSequence(ByteData(2 + 4));
    entryHeaderBuffer.writeUint16(keyBytes.length);
    entryHeaderBuffer.writeUint32(blob.length);
    _raf!.writeFromSync(entryHeaderBuffer.data.buffer.asInt8List());

    // ENTRY KEY

    _raf!.writeFromSync(keyBytes);

    // ENTRY DATA

    _raf!.writeFromSync(blob);

    // ONE MORE BYTE FOR CONSISTENCY CHECKING

    _raf!.writeByteSync(ENTRY_END_MARKER);
  }

  void closeSync() {
    if (this._raf != null) {
      this._raf!.closeSync();
      this._raf = null;
    }
  }
}

enum State { other, atEntryStart, atBlobStart, atFileEnd }

/// Reads a file created by [BlobsFileWriter].
///
/// Sample usage:
///
/// ``` dart
/// final reader = BlobsFileReader(file);
///
/// for (String key = reader.readKey();
///      key != null;
///      key = reader.readKey()) {
///
///   if (weLikeKey(key)) {
///     yield reader.readBlob();
///   } else {
///     reader.skipBlob();
///   }
/// }
///
/// reader.closeSync();
/// ```
class BlobsFileReader {
  BlobsFileReader(this.file, {this.mustExist = true}) {
    // OPENING THE FILE
    assert(this._raf == null);

    // opening file, ignoring "file not exist" errors if mustExist is false
    try {
      this._raf = file.openSync(mode: FileMode.read);
    } on FileSystemException catch (exc) {
      if (!mustExist && exc.isNoSuchFileOrDirectory) {
        this._state = State.atFileEnd;
        return;
      } else {
        rethrow;
      }
    }

    // READING THE HEADER
    List<int> header = this._raf!.readSync(3);
    this._cachedPosition += 3;
    if (header[0] != SIGNATURE_BYTE_1 || header[1] != SIGNATURE_BYTE_2 || header[2] != 0x03) {
      throw FileFormatError('Unexpected header $header.');
    }

    this._state = State.atEntryStart;
  }

  State _state = State.other;

  final bool mustExist;
  final File file;
  RandomAccessFile? _raf;

  // CACHED POSITION //

  int get _cachedPosition {
    //assert(this._cachedPositionVal==this._raf!.positionSync());
    return this._cachedPositionVal;
  }

  void set _cachedPosition(x) {
    this._cachedPositionVal = x;
    //print(this._raf!.positionSync());
    assert(this._cachedPositionVal == this._raf!.positionSync(),
        "cached ${this._cachedPositionVal} real ${this._raf!.positionSync()}");
  }

  int _cachedPositionVal = 0;

  int _currentEntryBlobSize = -1;

  /// We assume that we are exactly at the beginning of the entry. This method reads the header
  /// and changes values [currentEntryKey] and [_currentEntryBlobSize]. If if was the last
  /// entry (no more data), the [currentEntryKey] if set to [null].
  String? readKey() {
    // read everything except the blob

    if (_state == State.atFileEnd) {
      return null;
    }

    if (_state != State.atEntryStart) {
      throw StateError('Cannot read entry: current state is $_state');
    }

    final entryHeaderBuffer = ByteSequence(ByteData.sublistView(_raf!.readSync(2 + 4)));
    this._cachedPosition += entryHeaderBuffer.data.lengthInBytes;

    if (entryHeaderBuffer.data.lengthInBytes == 0) {
      // no more entries
      //this._currentEntryKey = null;
      this._currentEntryBlobSize = -1;
      this._state = State.atFileEnd;
      return null;
    } else if (entryHeaderBuffer.data.lengthInBytes != 6) {
      throw FileFormatError('Unexpected count of bytes at entry start.');
    }

    // decoding key size and blob size
    int keySize = entryHeaderBuffer.readUint16();
    this._currentEntryBlobSize = entryHeaderBuffer.readUint32();

    // reading the key
    final keyBytes = _raf!.readSync(keySize);
    if (keyBytes.length != keySize) {
      throw FileFormatError('Failed to read entry key.');
    }
    this._cachedPosition += keySize;
    //this._currentEntryKey = utf8.decode(keyBytes);

    this._state = State.atBlobStart;
    return utf8.decode(keyBytes);
  }

  Uint8List readBlob() {
    if (_state != State.atBlobStart) {
      throw StateError('Cannot read entry: current state is $_state');
    }

    assert(this._currentEntryBlobSize >= 0);
    //assert(this._currentEntryKey!=null);

    // READING BLOB BYTES

    final blobBytes = _raf!.readSync(this._currentEntryBlobSize);
    this._cachedPosition += blobBytes.length;
    if (blobBytes.length != this._currentEntryBlobSize) {
      throw FileFormatError(
          "Unexpected count of bytes read: ${blobBytes.length} instead of ${this._currentEntryBlobSize}.");
    }

    // READING MARKER

    final marker = _raf!.readByteSync();
    this._cachedPosition += 1;
    if (marker != ENTRY_END_MARKER) {
      throw FileFormatError("Entry end marker not found.");
    }

    this._state = State.atEntryStart;

    return blobBytes;
  }

  void skipBlob() {
    if (_state != State.atBlobStart) {
      throw StateError('Cannot read entry: current state is $_state');
    }

    assert(this._currentEntryBlobSize >= 0);

    int markerPos = _cachedPosition + _currentEntryBlobSize;
    _raf!.setPositionSync(markerPos);
    _cachedPosition = markerPos;

    // READING MARKER

    final marker = _raf!.readByteSync();
    this._cachedPosition += 1;
    if (marker != ENTRY_END_MARKER) {
      throw FileFormatError("Entry end marker not found.");
    }

    this._state = State.atEntryStart;
  }

  void closeSync() {
    if (this._raf != null) {
      this._raf!.closeSync();
      this._raf = null;
    }
  }
}

class Replace {
  /// Created a copy with file with particular blob replaced or removed.
  Replace(File source, File target, String newKey, List<int>? newBlob, {bool mustExist: true}) {
    BlobsFileReader? reader;
    BlobsFileWriter? writer;

    try {
      reader = BlobsFileReader(source, mustExist: mustExist);
      writer = BlobsFileWriter(target);

      // the new data will become the first entry in the file.
      // Accessing the first record is faster than the others

      if (newBlob != null) {
        writer.write(newKey, newBlob);
        this.entriesWritten++;
      } else {
        // not writing = deleting
      }

      for (var oldKey = reader.readKey(); oldKey != null; oldKey = reader.readKey()) {
        if (oldKey == newKey) {
          reader.skipBlob(); // we don't need old data
          this.entryWasFound = true; // todo test
          continue;
        } else {
          // copying old data
          writer.write(oldKey, reader.readBlob());
          this.entriesWritten++;
        }
      }
    } finally {
      reader?.closeSync();
      writer?.closeSync();
    }
  }

  int entriesWritten = 0;
  bool entryWasFound = false;
}

// /// Created a copy with file with particular blob replaced or removed.
// bool replaceBlobSync(File source, File target, String newKey, List<int>? newBlob,
//     {bool mustExist: true}) {
//   BlobsFileReader? reader;
//   BlobsFileWriter? writer;
//
//   bool entryWasFound = false;
//
//   try {
//     reader = BlobsFileReader(source, mustExist: mustExist);
//     writer = BlobsFileWriter(target);
//
//     // the new data will become the first entry in the file.
//     // Accessing the first record is faster than the others
//
//     if (newBlob != null) {
//       writer.write(newKey, newBlob);
//     } else {
//       // not writing = deleting
//     }
//
//
//
//     for (var oldKey = reader.readKey(); oldKey != null; oldKey = reader.readKey()) {
//       if (oldKey == newKey) {
//         reader.skipBlob(); // we don't need old data
//         entryWasFound = true; // todo test
//         continue;
//       } else {
//         // copying old data
//         writer.write(oldKey, reader.readBlob());
//       }
//     }
//
//   } finally {
//     reader?.closeSync();
//     writer?.closeSync();
//   }
//
//   return entryWasFound;
// }
