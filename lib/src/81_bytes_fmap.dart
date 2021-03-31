// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_errors/file_errors.dart';
import 'package:fmap/src/10_readwrite_v3.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as paths;

import '00_common.dart';
import '10_file_and_stat.dart';
import '10_files.dart';
import '10_hashing.dart';

typedef HashFunc = String Function(String key);

enum Policy {
  // First in first out. The cache evicts the entries in the order they were added, without
  // any regard to how often or how many times they were accessed before.
  fifo,
  // Least recently used. Discards the least recently used items first. This algorithm requires
  // keeping track of what was used when.
  lru
}

/// A [Map] implementation that stores its entries in files.
///
/// Dictionary keys are always of type `String`. These can be arbitrary strings, limited only by
/// size: after encoding in UTF-8, the string must fit into 64 kilobytes.
///
/// Values can be of type `String`, `List<int>` (array of bytes), and also `int`, `double`
/// or `bool`.
///
/// We can conventionally assume that each entry will be stored in a separate file. In fact,
/// in the case of a hash collision, a file may include two or more entries. But collisions
/// are rare.
class Fmap<T> extends MapBase<String, T?> {
  Fmap(this.directory, {Policy policy = Policy.fifo})
      : updateTimestampsOnRead = policy == Policy.lru,
        keyToHash = stringToMd5 {
    this.innerDir = Directory(paths.join(directory.path, 'v1'));
  }

  static Fmap temp<TYPE>({String subdir = 'fmap', Policy policy = Policy.fifo}) {
    return Fmap<TYPE>(Directory(paths.join(Directory.systemTemp.path, subdir)), policy: policy);
  }

  @internal
  @visibleForTesting
  late Directory innerDir;

  /// The directory inside which the data is stored. The directory can be non-existent
  /// when the object is created.
  final Directory directory;

  @visibleForTesting
  @internal
  final bool updateTimestampsOnRead;

  @internal
  HashFunc keyToHash = stringToMd5;

  /// Removes old data from storage, reducing the maximum total file size to [maxSizeBytes].
  void purge(int maxSizeBytes) {
    List<FileAndStat> files = <FileAndStat>[];

    List<FileSystemEntity> entries;
    try {
      entries = innerDir.listSync(recursive: true);
    } on FileSystemException catch (e) {
      throw FileSystemException(
          'DiskCache failed to listSync directory $innerDir right after creation. '
          'osError: ${e.osError}.');
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
    return _deserialize(readSync(key as String));
  }

  T? _deserialize(TypedBlob? typedBlob) {
    if (typedBlob == null) {
      return null;
    }

    //print("THE TYPE ${typedBlob.type}");

    switch (typedBlob.type) {
      case TypedBlob.typeBytes:
        return typedBlob.bytes as T;
      case TypedBlob.typeString:
        return utf8.decode(typedBlob.bytes) as T;
      case TypedBlob.typeInt:
        {
          final sl = ByteData.sublistView(typedBlob.bytes as Uint8List);
          return sl.getInt64(0) as T;
        }
      case TypedBlob.typeDouble:
        {
          final sl = ByteData.sublistView(typedBlob.bytes as Uint8List);
          return sl.getFloat64(0) as T;
        }
      case TypedBlob.typeBool:
        {
          return (typedBlob.bytes[0] != 0) as T;
          //#final sl = ByteData.sublistView(typedBlob.bytes as Uint8List);
          //return sl.ge(0) as T;
        }

      default:
        throw FallThroughError();
    }
  }

  @override
  void operator []=(String key, T? value) {
    if (value == null) {
      this.deleteSync(key);
    } else {
      if (value is List<int>) {
        writeSync(key, TypedBlob(TypedBlob.typeBytes, value));
      } else if (value is String) {
        writeSync(key, TypedBlob(TypedBlob.typeString, utf8.encode(value)));
      } else if (value is int) {
        final bd = ByteData(8);
        bd.setInt64(0, value);
        writeSync(key, TypedBlob(TypedBlob.typeInt, bd.buffer.asUint8List()));
      } else if (value is double) {
        final bd = ByteData(8);
        bd.setFloat64(0, value);
        writeSync(key, TypedBlob(TypedBlob.typeDouble, bd.buffer.asUint8List()));
      } else if (value is bool) {
        writeSync(key, TypedBlob(TypedBlob.typeBool, [value ? 1 : 0]));
      } else {
        throw TypeError();
      }
    }
  }

  @override
  void clear() {
    this.innerDir.deleteSync(recursive: true);
  }

  Iterable<TResult> _iterate<TResult>(TResult Function(BlobsFileReader blf, String key) toResult,
      bool maybeUpdateTimestamps) sync* {
    for (final f in listSyncOrEmpty(this.innerDir, recursive: true)) {
      if (FileSystemEntity.isFileSync(f.path) && f.path.endsWith(DATA_SUFFIX)) {
        BlobsFileReader? reader;
        try {
          reader = BlobsFileReader(File(f.path));
          bool timestampUpdated = false;
          for (var key = reader.readKey(); key != null; key = reader.readKey()) {
            if (maybeUpdateTimestamps && !timestampUpdated) {
              maybeUpdateTimestampAsync(File(f.path));
              timestampUpdated = true;
            }
            yield toResult(reader, key);
            // yield key;
            // reader.skipBlob();
          }
        } finally {
          reader?.closeSync();
        }
      }
    }
  }

  @override
  Iterable<String> get keys {
    return _iterate((blf, key) {
      blf.skipBlob();
      return key;
    }, false);
  }

  @override
  Iterable<MapEntry<String, T>> get entries {
    return _iterate(
        (reader, key) => MapEntry<String, T>(key, _deserialize(reader.readBlob())!), true);
  }

  @override
  T? remove(Object? key) {
    return _deserialize(this.deleteSync(key as String));
  }

  @internal
  void maybeUpdateTimestampAsync(File file) {
    if (this.updateTimestampsOnRead) {
      // scheduling async timestamp modification
      () async {
        try {
          file.setLastModifiedSync(DateTime.now());
        } on FileSystemException catch (e, _) {
          // not a big deal ...
          print('WARNING: Failed set timestamp to file $file: $e');
        }
      }();
    }
  }

  // KEYS AND FILES ////////////////////////////////////////////////////////////////////////////////

  String _keyFilePrefix(String key) {
    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return paths.join(this.innerDir.path, hash);
  }

  File _combine(String prefix, String suffix) {
    assert(suffix == DATA_SUFFIX || suffix == DIRTY_SUFFIX);
    return File('$prefix$suffix');
  }

  @visibleForTesting
  @internal
  File keyToFile(String key) {
    return _combine(this._keyFilePrefix(key), DATA_SUFFIX);
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  @visibleForTesting
  @internal
  TypedBlob? readSync(String key) {
    return _readOne<TypedBlob>(key, (reader, key) => reader.readBlob(), true);
  }

  @override
  bool containsKey(Object? key) {
    if (!(key is String)) {
      return false;
    }
    return _readOne<bool>(key, (reader, key) => true, false) ?? false;
  }

  TResult? _readOne<TResult>(String key,
      TResult Function(BlobsFileReader reader, String key) toResult, bool maybeUpdateTimestamps) {
    final file = keyToFile(key);
    BlobsFileReader? reader;
    try {
      reader = BlobsFileReader(file);
      for (var storedKey = reader.readKey(); storedKey != null; storedKey = reader.readKey()) {
        if (storedKey == key) {
          if (maybeUpdateTimestamps) {
            maybeUpdateTimestampAsync(file);
          }
          return toResult(reader, storedKey);
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
      final replaceResult = Replace(cacheFile, dirtyFile, key, data?.bytes, data?.type ?? 0,
          mustExist: false, wantOldData: wantOldData);
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

  @visibleForTesting
  @internal
  TypedBlob? deleteSync(String key) {
    return _writeOrDelete(key, null, wantOldData: true);
  }

  @visibleForTesting
  @internal
  void writeSync(String key, TypedBlob data) {
    _writeOrDelete(key, data);
  }
}
