// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:disk_cache/src/10_readwrite.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:path/path.dart' as paths;
import '00_common.dart';
import '10_files.dart';
import '10_hashing.dart';

typedef DeleteFile(File file);

/// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
class BytesCache extends BytesStore {
  // this object should not be too insistent when saving data.

  BytesCache(directory) : super(directory);

  @override
  @protected
  void deleteFile(File file) {
    file.deleteSync();
  }

  @override
  bool delete(String key) {
    final f = this._keyToFile(key);
    if (f.existsSync()) {
      this._keyToFile(key).deleteSync();
      return true;
    }
    return false;
  }

  @override
  File writeBytes(String key, List<int> data) {
    final prefix = this._keyFilePrefix(key);
    final cacheFile = _combine(prefix, DATA_SUFFIX);
    final dirtyFile = _combine(prefix, DIRTY_SUFFIX);

    bool renamed = false;
    try {
      writeKeyAndDataSync(dirtyFile, key, data); //# dirtyFile.writeAsBytes(data);
      dirtyFile.renameSync(cacheFile.path);
      renamed = true;
    } finally {
      if (!renamed) deleteSyncCalm(dirtyFile);
    }

    return cacheFile;
  }

  String _keyFilePrefix(String key) {
    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return paths.join(this.directory.path, "$hash$DATA_SUFFIX");
  }

  _combine(String prefix, String suffix) {
    assert(suffix == DATA_SUFFIX || suffix == DIRTY_SUFFIX);
    return File("$prefix$suffix");
  }

  File _keyToFile(String key) {
    return _combine(this._keyFilePrefix(key), DATA_SUFFIX);
    //return File("${this._keyFilePrefix(key)}$DATA_SUFFIX");
  }

  Uint8List? readBytes(String key) {
    final file = this._keyToFile(key);
    try {
      final data = readIfKeyMatchSync(file, key);
      // data will be null if file contains wrong key (hash collision)
      if (data != null) {
        setTimestampToNow(file); // calling async func without waiting
        return data;
      }
    } on FileSystemException catch (_) {
      return null;
    }
  }

  @override
  bool isFile(String path) {
    return FileSystemEntity.isFileSync(path); // todo needed?
  }
}