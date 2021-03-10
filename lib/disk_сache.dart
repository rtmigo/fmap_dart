// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as paths;

bool isBeforeOrSame(DateTime a, DateTime b) => a.isBefore(b) || a.isAtSameMomentAs(b);

bool isAfterOrSame(DateTime a, DateTime b) => a.isAfter(b) || a.isAtSameMomentAs(b);

// todo предусмотреть и протестировать совершенно рандомное удаление файлов системой

typedef DeleteFile(File file);

const JS_MAX_SAFE_INTEGER = 9007199254740991;

class FileAndStat {
  FileAndStat(this.file) {
    if (!this.file.isAbsolute) throw ArgumentError.value(this.file);
  }

  final File file;

  FileStat get stat {
    if (_stat == null) _stat = file.statSync();
    return _stat!;
  }

  set stat(FileStat x) {
    this._stat = x;
  }

  FileStat? _stat;

  static void sortByLastModifiedDesc(List<FileAndStat> files) {
    if (files.length >= 2) {
      files.sort((FileAndStat a, FileAndStat b) => -a.stat.modified.compareTo(b.stat.modified));
      assert(isAfterOrSame(files[0].stat.modified, files[1].stat.modified));
    }
  }

  static int sumSize(Iterable<FileAndStat> files) {
    return files.fold(0, (prev, curr) => prev + curr.stat.size);
  }

  static void deleteOldest(List<FileAndStat> files,
      {int maxSumSize = JS_MAX_SAFE_INTEGER, int maxCount = JS_MAX_SAFE_INTEGER, DeleteFile? deleteFile}) {
    //
    FileAndStat.sortByLastModifiedDesc(files); // now they are sorted by time
    int sumSize = FileAndStat.sumSize(files);

    DateTime? prevLastModified;

    bool tooLarge(int x, int max) {
      if (x > JS_MAX_SAFE_INTEGER) throw Exception("Integer overflow!"); // wow, we're dealing with zillion bytes cache?
      return x > max;
    }

    // iterating files from old to new
    for (int i = files.length - 1; i >= 0; --i) {
      // we update sumSize and files.length on each iteration
      if (!tooLarge(sumSize, maxSumSize) && !tooLarge(files.length, maxCount)) break; // todo move into for

      var item = files[i];
      // assert that the files are sorted from old to new
      assert(prevLastModified == null || isAfterOrSame(item.stat.modified, prevLastModified));

      if (deleteFile != null)
        deleteFile(item.file);
      else
        item.file.deleteSync();

      files.removeAt(i);
      assert(files.length == i);
      sumSize -= item.stat.size;
    }
  }
}

void writeKeyAndDataSync(File targetFile, String key, List<int> data) {
  RandomAccessFile raf = targetFile.openSync(mode: FileMode.write);

  try {
    final keyAsBytes = utf8.encode(key);

    // сохраняю номер версии
    raf.writeFromSync([1]);

    // сохраняю длину ключа
    final keyLenByteData = ByteData(2);
    keyLenByteData.setInt16(0, keyAsBytes.length);
    raf.writeFromSync(keyLenByteData.buffer.asInt8List());

    // сохраняю ключ
    raf.writeFromSync(keyAsBytes);

    // сохраняю данные
    raf.writeFromSync(data);
  } finally {
    raf.closeSync();
  }
}

Uint8List? readIfKeyMatchSync(File file, String key) {
  RandomAccessFile raf = file.openSync(mode: FileMode.read);

  try {
    final versionNum = raf.readSync(1)[0];
    if (versionNum > 1) throw Exception("Unsupported version");

    final keyBytesLen = ByteData.sublistView(raf.readSync(2)).getInt16(0);

    final keyAsBytes = raf.readSync(keyBytesLen); // utf8.encode(key);
    final keyFromFile = utf8.decode(keyAsBytes);

    if (keyFromFile != key) {
      //print("Jey mismatch: $key $keyFromFile");
      return null;
    }

    final bytes = <int>[];
    const CHUNK_SIZE = 128 * 1024;

    while (true) {
      // todo refactor
      final chunk = raf.readSync(CHUNK_SIZE);
      bytes.addAll(chunk);
      if (chunk.length < CHUNK_SIZE) break;
    }

    return Uint8List.fromList(bytes);
  } finally {
    raf.closeSync();
  }
}

String readKeySync(File file) {
  RandomAccessFile raf = file.openSync(mode: FileMode.read);

  try {
    final versionNum = raf.readSync(1)[0];
    if (versionNum > 1) throw Exception("Unsupported version");

    final keyBytesLen = ByteData.sublistView(raf.readSync(2)).getInt16(0);

    final keyAsBytes = raf.readSync(keyBytesLen); // utf8.encode(key);
    return utf8.decode(keyAsBytes);
  } finally {
    raf.closeSync();
  }
}

String stringToMd5(String data) {
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);
  return hex.encode(digest.bytes);
}

typedef String KeyToHash(String s);

void deleteDirIfEmptySync(Directory d) {
  try {
    d.deleteSync(recursive: false);
  } on FileSystemException catch (e) {
    const DIRECTORY_NOT_EMPTY = 66;
    if (e.osError?.errorCode != DIRECTORY_NOT_EMPTY)
      print("WARNING: Got unexpected osError.errorCode=${e.osError?.errorCode} trying to remove directory.");
  }
}

bool deleteSyncCalm(File file) {
  try {
    file.deleteSync();
    return true;
  } on FileSystemException catch (e) {
    print("WARNING: Failed to delete $file: $e");
    return false;
  }
}

class DiskCache {
  // дисковый кэш.
  // Умеет сохранять и читать байты.
  // При запуске сканирует все сохраненное и удаляет старые файлы (если файлов стало много или размер большой).
  // Какой файл старше - определеяет по таймстампу файловой системы, т.е. не всегда точно
  // (возможно, с точностью до двух секунд).
  //
  // Удаление файлов НЕ при запуске теоретически реализуемо, фактически я поленился.

  DiskCache(this.directory,
      {this.maxSizeBytes = JS_MAX_SAFE_INTEGER,
      this.maxCount = JS_MAX_SAFE_INTEGER,
      this.keyToHash = stringToMd5,
      this.asyncTimestamps = true}) {
    this._initialized = this._init();
  }

  final int maxSizeBytes;
  final int maxCount;
  final bool asyncTimestamps;

  // по умолчанию тут используется MD5, что вполне замечательный выбор.
  // Я сделал возможность переопределения этой переменной исключительно в тестовых целях (отладить поведение кэша
  // при коллизиях хэшей, хотя они может и происходят раз в 10 лет)
  final KeyToHash keyToHash;

  static const _DIRTY_SUFFIX = ".dirt";
  static const _DATA_SUFFIX = ".dat";

  Future<DiskCache> _init() async {
    directory.createSync(recursive: true);

    List<FileAndStat> files = <FileAndStat>[];

    List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(recursive: true);
    } on FileSystemException catch (e) {
      throw FileSystemException(
          "DiskCache failed to listSync directory $directory right after creation. osError: ${e.osError}.");
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
    FileAndStat.deleteOldest(files, maxSumSize: this.maxSizeBytes, maxCount: this.maxCount, deleteFile: (file) {
      deleteSyncCalm(file);
      deleteDirIfEmptySync(file.parent);
    });

    return this;
  }

  Future<DiskCache>? _initialized;
  final Directory directory;

  Future<void> delete(String key) async {
    await this._initialized;
    final file = _findTargetFile(key);
    assert(file.path.endsWith(_DATA_SUFFIX));
    file.deleteSync();
    deleteDirIfEmptySync(file.parent);
  }

  Future<File> writeBytes(String key, List<int> data) async {
    //final cacheFile = _fnToCacheFile(filename);

    await this._initialized;
    final cacheFile = this._findTargetFile(key);

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

  /// Returns the target directory path for a file that holds value for [key]. The directory may exist or not.
  ///
  /// Each directory corresponds to a hash value. Due to hash collision different keys may produce the same hash.
  /// In this case their files will be kept in the same directory.
  Directory _keyToHypotheticalDir(String key) {
    // один и тот же ключ может сгенерировать одинаковые хэши.
    // Все файлы с одинаковыми хэшами будут находиться в одном и тот же подкаталоге.
    // Этот подкаталог и возвращаем.

    String hash = this.keyToHash(key);
    assert(!hash.contains(paths.style.context.separator));
    return Directory(paths.join(this.directory.path, hash));
  }

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

  File _findTargetFile(String key) {
    //print("FTF");
    for (final existingFile in this._keyToExistingFiles(key)) {
      //print("Comparing with $existingFile");
      if (readKeySync(existingFile) == key) return existingFile;
    }

    for (int i = 0;; ++i) {
      final candidateFile = File(paths.join(_keyToHypotheticalDir(key).path, "$i$_DATA_SUFFIX"));
      if (!candidateFile.existsSync()) return candidateFile;
    }
  }

  Future<Uint8List?> readBytes(String key) async {
    await this._initialized;

    for (final fileCandidate in _keyToExistingFiles(key)) {
      //print("Reading $fileCandidate");
      final data = readIfKeyMatchSync(fileCandidate, key);
      if (data != null) {
        if (this.asyncTimestamps) // todo юниттест таймстампов
          _setTimestampToNow(fileCandidate);
        else
          await _setTimestampToNow(fileCandidate);

        return data;
      }
    }

    return null;
  }

  Future<void> _setTimestampToNow(File file) async {
    // поскольку кэш расположен во временном каталоге, там любой файл может быть удален в любой момент

    try {
      file.setLastModifiedSync(DateTime.now());
    } on FileSystemException catch (e, _) {
      print("WARNING: Cannot set timestamp to file $file: $e");

      //#if (e.osError.errorCode==2) // (OS Error: No such file or directory, errno = 2)
      //print("WARNING: File $file seems to be deleted.");
      //else
      //rethrow;
    }
  }

  File _uniqueDirtyFn() {
    for (int i = 0;; ++i) {
      final f = File(directory.path + "/$i$_DIRTY_SUFFIX");
      if (!f.existsSync()) return f;
    }
  }
}
