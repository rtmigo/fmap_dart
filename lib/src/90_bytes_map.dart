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
// typedef String HashFunc(String key);
//
//
// /// Persistent data storage that provides access to [Uint8List] binary items by [String] keys.
// class DiskBytesMap extends DiskBytesStore {
//
//   DiskBytesMap(directory, {bool updateTimestampsOnRead=false}): keyToHash=stringToMd5, super(directory, updateTimestampsOnRead);
//
//   @internal
//   HashFunc keyToHash;
//
//
//   @override
//   @protected
//   void deleteFile(File file) {
//     file.deleteSync();
//     deleteDirIfEmptySync(file.parent);
//   }
//
//   @override
//   bool deleteSync(String key) {
//     final file = this._findExistingFile(key);
//     if (file==null)
//       return false;
//     assert(file.path.endsWith(DATA_SUFFIX));
//     this.deleteFile(file);
//     return true;
//   }
//
//   @override
//   File writeBytesSync(String key, List<int> data) {
//
//     final cacheFile = this._findExistingFile(key) ?? this._proposeUniqueFile(key);
//
//     File? dirtyFile = _uniqueDirtyFn();
//     try {
//       writeKeyAndDataSyncV1(dirtyFile, key, data); //# dirtyFile.writeAsBytes(data);
//
//       try {
//         Directory(paths.dirname(cacheFile.path)).createSync();
//       } on FileSystemException {}
//
//       if (cacheFile.existsSync()) cacheFile.deleteSync();
//       dirtyFile.renameSync(cacheFile.path);
//       dirtyFile = null;
//     } finally {
//       if (dirtyFile != null && dirtyFile.existsSync())
//         dirtyFile.delete();
//     }
//
//     return cacheFile;
//   }
//
//   /// Returns the target directory path for a file that holds the data for [key].
//   /// The directory may exist or not.
//   ///
//   /// Each directory corresponds to a hash value. Due to hash collision different keys
//   /// may produce the same hash. Files with the same hash will be placed in the same
//   /// directory.
//   Directory _keyToHypotheticalDir(String key) {
//     String hash = this.keyToHash(key);
//     assert(!hash.contains(paths.style.context.separator));
//     return Directory(paths.join(this.directory.path, hash));
//   }
//
//   /// Returns all existing files whose key-hashes are the same as the hash of [key].
//   /// Any of them may be the file that is currently storing the data for [key].
//   /// It's also possible, that neither of them stores the data for [key].
//   Iterable<File> _keyToExistingFiles(String key) sync* {
//     final parent = this._keyToHypotheticalDir(key);
//     for (final fse in listSyncOrEmpty(parent))
//       if (fse.path.endsWith(DATA_SUFFIX))
//         yield File(fse.path);
//   }
//
//   /// Generates a unique filename in a directory that should contain file [key].
//   File _proposeUniqueFile(String key) {
//     final dirPath = _keyToHypotheticalDir(key).path;
//     for (int i = 0;; ++i) {
//       final candidateFile = File(paths.join(dirPath, "$i$DATA_SUFFIX"));
//       if (!candidateFile.existsSync()) return candidateFile;
//     }
//   }
//
//   /// Tries to find a file for the [key]. If file does not exist, returns `null`.
//   File? _findExistingFile(String key) {
//     for (final existingFile in this._keyToExistingFiles(key)) {
//       if (readKeySyncV1(existingFile) == key) return existingFile;
//     }
//     return null;
//   }
//
//   Uint8List? readBytesSync(String key) {
//     for (final file in this._keyToExistingFiles(key)) {
//       final data = readIfKeyMatchSyncV1(file, key);
//       if (data != null) {
//         // this is the file with key=key :)
//         //if (updateLastModified)
//         maybeUpdateTimestampOnRead(file); // calling async func without waiting
//         return data;
//       }
//     }
//     return null;
//   }
//
//   File _uniqueDirtyFn() {
//     for (int i = 0;; ++i) {
//       final f = File(directory.path + "/$i$DIRTY_SUFFIX");
//       if (!f.existsSync()) return f;
//     }
//   }
//
//   @override
//   bool isFile(String path)
//   {
//     return FileSystemEntity.isFileSync(path);
//   }
//
//   @override
//   bool containsKey(Object? key) {
//     return _findExistingFile(key as String)!=null;
//   }
// }
