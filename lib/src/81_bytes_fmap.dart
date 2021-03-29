// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:disk_cache/src/10_readwrite_v3.dart';
import 'package:file_errors/file_errors.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as paths;

import '00_common.dart';
import '10_file_and_stat.dart';
import '10_files.dart';
import '10_hashing.dart';

typedef DeleteFile(File file);

typedef String HashFunc(String key);



/// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
class BytesFmap<T> extends MapBase<String, T?> {
  BytesFmap(this.directory, {this.updateTimestampsOnRead = false}) : keyToHash = stringToMd5;

  //super(directory, updateTimestampsOnRead);

  final Directory directory;
  final bool updateTimestampsOnRead;

  @internal
  HashFunc keyToHash = stringToMd5;

  void purgeSync(int maxSizeBytes) {
    List<FileAndStat> files = <FileAndStat>[];

    List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(recursive: true);
    } on FileSystemException catch (e) {
      throw FileSystemException(
          "DiskCache failed to listSync directory $directory right after creation. "
          "osError: ${e.osError}.");
    }

    for (final entry in entries) {
      if (entry.path.endsWith(DIRTY_SUFFIX)) {
        deleteSyncCalm(File(entry.path));
        continue;
      }
      if (entry.path.endsWith(DATA_SUFFIX)) {
        final f = File(entry.path);
        files.add(FileAndStat(f));
      }
    }

    FileAndStat.deleteOldest(files,
        maxSumSize: maxSizeBytes,
        maxCount: JS_MAX_SAFE_INTEGER,
        deleteFile: (file) => file.deleteSync());
  }

  @override
  T? operator [](Object? key) {
    return _deserialize(readTypedBlobSync(key as String));
  }

  T? _deserialize(TypedBlob? typedBlob) {
    if (typedBlob==null) {
      return null;
    }

    //print("THE TYPE ${typedBlob.type}");

    switch (typedBlob.type) {
      case TypedBlob.typeBytes:
        return typedBlob.bytes as T;
      case TypedBlob.typeString:
        return utf8.decode(typedBlob.bytes) as T;
      default:
        throw FallThroughError();
    }
  }

  @override
  void operator []=(String key, T? value) {
    if (value == null) {
      this.deleteSync(key);
    }
    else {
      if (value is List<int>) {
        writeBytesSync(key, TypedBlob(TypedBlob.typeBytes, value));
      } else if (value is String) {
        writeBytesSync(key, TypedBlob(TypedBlob.typeString, utf8.encode(value)));
      } else {
        throw TypeError();
      }

    }

  }

  @override
  void clear() {
    this.directory.deleteSync(recursive: true);
  }

  @override
  Iterable<String> get keys sync* {
    for (final f in listSyncOrEmpty(this.directory, recursive: true)) {
      if (FileSystemEntity.isFileSync(f.path)) {
        BlobsFileReader? reader;
        try {
          reader = BlobsFileReader(File(f.path));
          for (var key = reader.readKey(); key != null; key = reader.readKey()) {
            yield key;
            reader.skipBlob();
          }
        } finally {
          reader?.closeSync();
        }
      }
    }
  }

  @override
  T? remove(Object? key) {
    return _deserialize(this.deleteSync(key as String));
  }

  @internal
  void maybeUpdateTimestampOnRead(File file) {
    if (this.updateTimestampsOnRead) {
      // scheduling async timestamp modification
      () async {
        try {
          file.setLastModifiedSync(DateTime.now());
        } on FileSystemException catch (e, _) {
          // not a big deal ...
          print("WARNING: Failed set timestamp to file $file: $e");
        }
      }();
    }
  }

  // KEYS AND FILES ////////////////////////////////////////////////////////////////////////////////


  String _keyFilePrefix(String key) {
    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return paths.join(this.directory.path, hash);
  }

  File _combine(String prefix, String suffix) {
    assert(suffix == DATA_SUFFIX || suffix == DIRTY_SUFFIX);
    return File("$prefix$suffix");
  }

  @visibleForTesting
  File keyToFile(String key) {
    return _combine(this._keyFilePrefix(key), DATA_SUFFIX);
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  @visibleForTesting
  TypedBlob? readTypedBlobSync(String key) {
    final file = keyToFile(key);
    BlobsFileReader? reader;
    try {
      maybeUpdateTimestampOnRead(file); // calling async func without waiting
      reader = BlobsFileReader(file);
      for (var storedKey = reader.readKey(); storedKey != null; storedKey = reader.readKey()) {
        if (storedKey == key) {
          return reader.readBlob();
        } else {
          reader.skipBlob();
        }
      }
    } on FileSystemException catch (e) {
      if (e.isNoSuchFileOrDirectory) {
        return null;
      }
      rethrow;
    } finally {
      reader?.closeSync();
    }
  }

  TypedBlob? _writeOrDelete(String key, TypedBlob? data, {wantOldData = false}) {

    final prefix = this._keyFilePrefix(key);
    final cacheFile = _combine(prefix, DATA_SUFFIX);
    final dirtyFile = _combine(prefix, DIRTY_SUFFIX);

    assert(this.keyToFile(key).path == cacheFile.path, 'ktf ${keyToFile(key)} cf $cacheFile');

    bool renamed = false;
    try {
      final replaceResult =
          Replace(cacheFile, dirtyFile, key, data?.bytes, data?.type ?? 0, mustExist: false, wantOldData: wantOldData);
      assert(data == null || dirtyFile.existsSync());

      if (replaceResult.entriesWritten >= 1) {
        // at least one entry written to the new file. Replacing the old file
        dirtyFile.renameSync(cacheFile.path);
      } else {
        // nothing is written, so no more data to keep in the file
        assert(replaceResult.entriesWritten == 0);
        deleteSyncCalm(cacheFile);
      }
      renamed = true;
      return replaceResult.oldData;
    } finally {
      if (!renamed) {
        deleteSyncCalm(dirtyFile);
      }
    }
  }

  TypedBlob? deleteSync(String key) {
    return _writeOrDelete(key, null, wantOldData: true);
  }

  void writeBytesSync(String key, TypedBlob data) {
    _writeOrDelete(key, data);
  }
}