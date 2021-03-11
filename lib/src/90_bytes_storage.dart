// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:disk_cache/src/10_file_removal.dart';
import 'package:disk_cache/src/10_readwrite.dart';
import 'package:path/path.dart' as paths;

import '00_common.dart';
import '10_files.dart';
import 'src/00_common.dart';
import 'src/10_files.dart';

typedef DeleteFile(File file);

String stringToMd5(String data) {
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);
  return hex.encode(digest.bytes);
}


/// A persistent data storage that provides access to [Uint8List] binary items by [String] keys.
abstract class BytesStorageBase {

  BytesStorageBase(this.directory) {
    this._initialized = this._init();
  }

  String keyToHash(String key);

  static const _DIRTY_SUFFIX = ".dirt";
  static const _DATA_SUFFIX = ".dat";

  Future<BytesStorageBase> _init() async {
    directory.createSync(recursive: true);
    this.compactSync();

    return this;
  }

  void compactSync({
    final int maxSizeBytes = JS_MAX_SAFE_INTEGER,
    final maxCount = JS_MAX_SAFE_INTEGER })
  {
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
      if (entry.path.endsWith(_DIRTY_SUFFIX)) {
        deleteSyncCalm(File(entry.path));
        continue;
      }
      if (entry.path.endsWith(_DATA_SUFFIX)) {
        final f = File(entry.path);
        files.add(FileAndStat(f));
      }
    }

    FileAndStat.deleteOldest(files, maxSumSize: maxSizeBytes, maxCount: maxCount,
        deleteFile: (file) {
          deleteSyncCalm(file);
          deleteDirIfEmptySync(file.parent);
        });
  }

  Future<BytesStorageBase> get initialized => this._initialized!;

  Future<BytesStorageBase>? _initialized;
  final Directory directory;

  Future<bool> delete(String key) async {
    await this._initialized;
    final file = this._findExistingFile(key);
    if (file==null)
      return false;

    assert(file.path.endsWith(_DATA_SUFFIX));
    file.deleteSync();
    deleteDirIfEmptySync(file.parent);
    return true;
  }

  Future<File> writeBytes(String key, List<int> data) async {
    //final cacheFile = _fnToCacheFile(filename);

    await this._initialized;
    final cacheFile = this._findExistingFile(key) ?? this._proposeUniqueFile(key);

    File? dirtyFile = _uniqueDirtyFn();
    try {
      writeKeyAndDataSync(dirtyFile, key, data); //# dirtyFile.writeAsBytes(data);

      try {
        Directory(paths.dirname(cacheFile.path)).createSync();
      } on FileSystemException {}
      //print("Writing to $cacheFile");

      if (cacheFile.existsSync()) cacheFile.deleteSync();
      dirtyFile.renameSync(cacheFile.path);
      dirtyFile = null;
    } finally {
      if (dirtyFile != null && dirtyFile.existsSync()) dirtyFile.delete();
    }

    return cacheFile;
  }

  /// Returns the target directory path for a file that holds the data for [key].
  /// The directory may exist or not.
  ///
  /// Each directory corresponds to a hash value. Due to hash collision different keys
  /// may produce the same hash. Files with the same hash will be placed in the same
  /// directory.
  Directory _keyToHypotheticalDir(String key) {
    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return Directory(paths.join(this.directory.path, hash));
  }

  /// Returns all existing files whose key-hashes are the same as the hash of [key].
  /// Any of them may be the file that is currently storing the data for [key].
  /// It's also possible, that neither of them stores the data for [key].
  Iterable<File> _keyToExistingFiles(String key) sync* {
    // возвращает существующие файлы, в которых _возможно_ хранится значение key
    final kd = this._keyToHypotheticalDir(key);

    List<FileSystemEntity> files;

    if (kd.existsSync()) {
      files = kd.listSync();
      for (final entity in files) {
        if (entity.path.endsWith(_DATA_SUFFIX)) yield File(entity.path);
      }
    }
  }

  /// Generates a unique filename in a directory that should contain file [key].
  File _proposeUniqueFile(String key) {
    final dirPath = _keyToHypotheticalDir(key).path;
    for (int i = 0;; ++i) {
      final candidateFile = File(paths.join(dirPath, "$i$_DATA_SUFFIX"));
      if (!candidateFile.existsSync()) return candidateFile;
    }
  }

  /// Tries to find a file for the [key]. If file does not exist, returns `null`.
  File? _findExistingFile(String key) {
    for (final existingFile in this._keyToExistingFiles(key)) {
      if (readKeySync(existingFile) == key) return existingFile;
    }
    return null;
  }

  Future<Uint8List?> readBytes(String key) async {
    await this._initialized;

    for (final fileCandidate in _keyToExistingFiles(key)) {
      final data = readIfKeyMatchSync(fileCandidate, key);
      if (data != null) {
        setTimestampToNow(fileCandidate);  // calling async func w/o waiting
        return data;
      }
    }

    return null;
  }

  File _uniqueDirtyFn() {
    for (int i = 0;; ++i) {
      final f = File(directory.path + "/$i$_DIRTY_SUFFIX");
      if (!f.existsSync()) return f;
    }
  }
}

class BytesStorage extends BytesStorageBase {

  BytesStorage(Directory directory) : super(directory);

  @override
  String keyToHash(String key) => stringToMd5(key);
}