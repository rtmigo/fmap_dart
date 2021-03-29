// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:collection';
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
class BytesFmap extends MapBase<String, List<int>?> {
  BytesFmap(this.directory, {this.updateTimestampsOnRead = false})
      : keyToHash = stringToMd5;
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
        deleteFile: (file) => this.deleteFile(file));
  }

  // @protected
  // void deleteFile(File file);

  // Uint8List? readBytesSync(String key);
  // bool deleteSync(String key);
  // void writeBytesSync(String key, List<int> data);
  //
  // @protected
  // bool isFile(String path);

  @override
  Uint8List? operator [](Object? key) {
    return readBytesSync(key as String);
  }

  @override
  void operator []=(String key, List<int>? value) {
    if (value == null)
      this.deleteSync(key);
    else
      writeBytesSync(key, value);
  }

  @override
  void clear() {
    this.directory.deleteSync(recursive: true);
  }

  @override
  Iterable<String> get keys sync* {
    // TODO move from this class
    for (final f in listSyncOrEmpty(this.directory, recursive: true)) {
      if (this.isFile(f.path)) {
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
  Uint8List? remove(Object? key) {
    return this.deleteSync(key as String);
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


  // @internal
  // HashFunc keyToHash;

  @override
  void deleteFile(File file) {
    file.deleteSync(); // TODO Outdated?
  }

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

  @override
  bool isFile(String path) {
    return FileSystemEntity.isFileSync(path); // TODO Outdated?
  }

  @override
  Uint8List? readBytesSync(String key) {
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

  // @visibleForTesting
  // File? lastWrittenFile;

  Uint8List? _writeOrDelete(String key, List<int>? data, {wantOldData=false}) {
    //this.lastWrittenFile = null;

    final prefix = this._keyFilePrefix(key);
    final cacheFile = _combine(prefix, DATA_SUFFIX);
    final dirtyFile = _combine(prefix, DIRTY_SUFFIX);

    assert(this.keyToFile(key).path == cacheFile.path, 'ktf ${keyToFile(key)} cf $cacheFile');

    bool renamed = false;
    try {
      final replaceResult =
          Replace(cacheFile, dirtyFile, key, data, 0, mustExist: false, wantOldData: wantOldData);
      assert(data == null || dirtyFile.existsSync());

      if (replaceResult.entriesWritten >= 1) {
        dirtyFile.renameSync(cacheFile.path);
      } else {
        // nothing is written, so no more data to keep in the file
        assert(replaceResult.entriesWritten==0);
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


  Uint8List? deleteSync(String key) {
    return _writeOrDelete(key, null, wantOldData: true);
  }


  void writeBytesSync(String key, List<int> data) {
    _writeOrDelete(key, data);
  }
}
