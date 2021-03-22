// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:typed_data';

import 'package:disk_cache/src/10_readwrite_v3.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as paths;

import '00_common.dart';
import '10_files.dart';
import '10_hashing.dart';
import '10_readwrite_v1.dart';

typedef DeleteFile(File file);

typedef String HashFunc(String key);


/// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
class StoredBytesMap extends DiskBytesStore {

  StoredBytesMap(directory, {bool updateTimestampsOnRead=false}): keyToHash=stringToMd5, super(directory, updateTimestampsOnRead);

  @internal
  HashFunc keyToHash;

  @override
  void deleteFile(File file) {
    file.deleteSync();  // TODO Outdated?
  }

  String _keyFilePrefix(String key) {
    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return paths.join(this.directory.path, "$hash$DATA_SUFFIX");
  }

  File _combine(String prefix, String suffix) {
    assert(suffix == DATA_SUFFIX || suffix == DIRTY_SUFFIX);
    return File("$prefix$suffix");
  }

  File _keyToFile(String key) {
    return _combine(this._keyFilePrefix(key), DATA_SUFFIX);
  }


  @override
  void deleteSync(String key) {
    return this.writeBytesSync(key, null);
  }

  @override
  bool isFile(String path) {
    return FileSystemEntity.isFileSync(path); // TODO Outdated?
    // TODO: implement isFile
    throw UnimplementedError();
  }

  @override
  Uint8List? readBytesSync(String key) {
    final file = _keyToFile(key);
    BlobsFileReader? reader;
    try {
      reader = BlobsFileReader(file);
      for (var storedKey = reader.readKey(); storedKey != null; storedKey = reader.readKey()) {
        if (storedKey==key) {
          return reader.readBlob();
        } else {
          reader.skipBlob();
        }
      }
    }
    finally {
      reader?.closeSync();
    }
  }

  bool _writeOrDelete(String key, List<int>? data) {
    final prefix = this._keyFilePrefix(key);
    final cacheFile = _combine(prefix, DATA_SUFFIX);
    final dirtyFile = _combine(prefix, DIRTY_SUFFIX);

    bool entryWasFound;
    bool renamed = false;
    try {
      entryWasFound = replaceBlobSync(cacheFile, dirtyFile, key, data, mustExist: false);
      dirtyFile.renameSync(cacheFile.path);
      renamed = true;
      return entryWasFound;
    }
    finally {
      if (!renamed) {
        deleteSyncCalm(dirtyFile);
      }
    }
  }

  @override
  void writeBytesSync(String key, List<int>? data) => _writeOrDelete(key, data);
}