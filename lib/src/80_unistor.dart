// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:disk_cache/src/10_readwrite_v3.dart';
import 'package:meta/meta.dart';

import '00_common.dart';
import '10_file_and_stat.dart';
import '10_files.dart';
import '10_hashing.dart';

typedef String HashFunc(String key);

abstract class DiskBytesStore extends MapBase<String, List<int>?> {
  final Directory directory;
  final bool updateTimestampsOnRead;

  DiskBytesStore(this.directory, this.updateTimestampsOnRead);

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

  @protected
  void deleteFile(File file);

  Uint8List? readBytesSync(String key);
  bool deleteSync(String key);
  void writeBytesSync(String key, List<int> data);

  @protected
  bool isFile(String path);

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
    this.deleteSync(key as String);
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
}
