// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'package:disk_cache/src/10_readwrite_v3.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:file_errors/file_errors.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as paths;

import '00_common.dart';
import '10_files.dart';
import '10_hashing.dart';

typedef DeleteFile(File file);

typedef String HashFunc(String key);

/// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
class StoredBytesMap extends DiskBytesStore {
  StoredBytesMap(directory, {bool updateTimestampsOnRead = false})
      : keyToHash = stringToMd5,
        super(directory, updateTimestampsOnRead);

  @internal
  HashFunc keyToHash;

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

  // @override
  // void deleteSync(String key) {
  //   return this.writeBytesSync(key, null);
  // }

  @override
  bool isFile(String path) {
    return FileSystemEntity.isFileSync(path); // TODO Outdated?
    // TODO: implement isFile
    throw UnimplementedError();
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

  bool _writeOrDelete(String key, List<int>? data) {
    //this.lastWrittenFile = null;

    final prefix = this._keyFilePrefix(key);
    final cacheFile = _combine(prefix, DATA_SUFFIX);
    final dirtyFile = _combine(prefix, DIRTY_SUFFIX);

    assert(this.keyToFile(key).path == cacheFile.path, 'ktf ${keyToFile(key)} cf $cacheFile');

    bool renamed = false;
    try {
      final repl = Replace(cacheFile, dirtyFile, key, data, mustExist: false);
      assert(data == null || dirtyFile.existsSync());

      if (repl.entriesWritten >= 1) {
        dirtyFile.renameSync(cacheFile.path);
      } else {
        //assert(!dirtyFile.existsSync());
        deleteSyncCalm(cacheFile);
      }

      // try {
      //   dirtyFile.renameSync(cacheFile.path);
      // } on FileSystemException catch (exc) {
      //   if (exc.isNoSuchFileOrDirectory && data==null) {
      //     // we were deleting an entry from the file. If it was the only entry,
      //     // there is no file created, and it's ok
      //   }
      //   else {
      //     rethrow;
      //   }
      // }

      renamed = true;
      //this.lastWrittenFile = cacheFile;
      return repl.entryWasFound;
    } finally {
      if (!renamed) {
        deleteSyncCalm(dirtyFile);
      }
    }
  }

  @override
  bool deleteSync(String key) {
    return _writeOrDelete(key, null);
  }

  @override
  void writeBytesSync(String key, List<int> data) {
    _writeOrDelete(key, data);
  }

  // @override
  // void writeBytesSync(String key, List<int>? data) => _writeOrDelete(key, data);
}
