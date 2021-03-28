// // SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// // SPDX-License-Identifier: BSD-3-Clause
//
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:meta/meta.dart';
// import 'package:disk_cache/src/10_readwrite_v2.dart';
// import 'package:disk_cache/src/80_unistor.dart';
// import 'package:path/path.dart' as paths;
// import '00_common.dart';
// import '10_files.dart';
// import '10_hashing.dart';
// import '10_readwrite_v1.dart';
//
// typedef DeleteFile(File file);
//
// /// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
// class DiskBytesCache extends DiskBytesStore {
//   // this object should not be too insistent when saving data.
//
//   DiskBytesCache(directory, {bool updateTimestampsOnRead=false}) : super(directory, updateTimestampsOnRead);
//
//   @override
//   @protected
//   void deleteFile(File file) {
//     file.deleteSync();
//   }
//
//   @override
//   bool deleteSync(String key) {
//     final f = this._keyToFile(key);
//     if (f.existsSync()) {
//       this._keyToFile(key).deleteSync();
//       return true;
//     }
//     return false;
//   }
//
//   @override
//   File writeBytesSync(String key, List<int> data) {
//     final prefix = this._keyFilePrefix(key);
//     final cacheFile = _combine(prefix, DATA_SUFFIX);
//     final dirtyFile = _combine(prefix, DIRTY_SUFFIX);
//
//     bool renamed = false;
//     try {
//       writeKeyAndDataSyncV1(dirtyFile, key, data); //# dirtyFile.writeAsBytes(data);
//       dirtyFile.renameSync(cacheFile.path);
//       renamed = true;
//     } finally {
//       if (!renamed) deleteSyncCalm(dirtyFile);
//     }
//
//     return cacheFile;
//   }
//
//   String _keyFilePrefix(String key) {
//     String hash = this.keyToHash(key);
//     assert(!hash.contains(paths.style.context.separator));
//     return paths.join(this.directory.path, "$hash$DATA_SUFFIX");
//   }
//
//   _combine(String prefix, String suffix) {
//     assert(suffix == DATA_SUFFIX || suffix == DIRTY_SUFFIX);
//     return File("$prefix$suffix");
//   }
//
//   File _keyToFile(String key) {
//     return _combine(this._keyFilePrefix(key), DATA_SUFFIX);
//   }
//
//   Uint8List? readBytesSync(String key) {
//     final file = this._keyToFile(key);
//     try {
//       final data = readIfKeyMatchSyncV1(file, key);
//       // data will be null if file contains wrong key (hash collision)
//       if (data != null) {
//         //if (updateLastModified)
//         maybeUpdateTimestampOnRead(file); // calling async func without waiting
//         return data;
//       }
//     } on FileSystemException catch (_) {
//       return null;
//     }
//   }
//
//   @override
//   bool isFile(String path) {
//     return FileSystemEntity.isFileSync(path); // todo needed?
//   }
//
//   @override
//   bool containsKey(Object? key) {
//     final file = this._keyToFile(key as String);
//     try {
//       return readKeySyncV1(file)==key;
//     } on FileSystemException catch (_) {
//       return false;
//     }
//   }
// }
