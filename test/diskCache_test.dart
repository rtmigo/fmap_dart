// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import "package:test/test.dart";
import 'package:disk_cache/disk_сache.dart';
import 'dart:io' show Platform;

String badHashFunc(String data) {
  // returns only 16 possible hash values.
  // So if we have more than 16 items, there will hash collisions.
  // Which is bad for production, but good for testing
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);
  String result = digest.bytes[0].toRadixString(16)[0];
  assert(result.length == 1);
  return result;
}

/// Removes random files or directories from the [dir].
void deleteRandomItems(Directory dir, int count, FileSystemEntityType type, {emptyOk=false, errorOk=false}) {
  List<FileSystemEntity> files = <FileSystemEntity>[];
  for (final entry in dir.listSync(recursive: true))
    if (FileSystemEntity.typeSync(entry.path) == type) files.add(entry);
  if (!emptyOk)
    assert(files.length >= count);
  files.shuffle();
  for (final f in files.take(count))
    try {
      f.deleteSync(recursive: true);
    }
    on FileSystemException catch (_) {
      if (!errorOk)
        rethrow;
    }
}

int countFiles(Directory dir) {
  return dir.listSync(recursive: true).where((e) => FileSystemEntity.isFileSync(e.path)).length;
}

class SampleWithData {
  static Future<SampleWithData> create({lmtMatters = false}) async {
    final longerDelays = lmtMatters; // && Platform.isWindows;

    final theDir = Directory.systemTemp.createTempSync();

    var theCache = DiskCache(theDir,
        keyToHash: badHashFunc); // maxCount: 999999, maxSizeBytes: 99999 * 1024 * 1024,

    Set<String> allKeys = Set<String>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      allKeys.add(key);

      if (i != 0) {
        if (longerDelays && (i == 1 || i == 99)) {
          // making a longer pause between 0..1 and 98..99, to be sure that the LMT of first file
          // is minimal and LMT of the last one is maximal.
          //
          // Last-modification times on FAT are rounded to nearest 2 seconds.
          //
          // https://stackoverflow.com/a/11547476
          // File time stamps on FAT drives are rounded to the nearest two seconds (even number)
          // when the file is written to the drive. The file time stamps on NTFS drives are rounded
          // to the nearest 100 nanoseconds when the file is written to the drive. Consequently,
          // file time stamps on FAT drives always end with an even number of seconds, while file
          // time stamps on NTFS drives can end with either even or odd number of seconds.
          //
          // So we make  that first and last files distant in time from the others.

          await Future.delayed(Duration(milliseconds: 2050));
        } else
          await Future.delayed(Duration(milliseconds: 25));
      }

      //print("Creating file ${longerDelays} at ${DateTime.now()}");

      await theCache.writeBytes(key, List.filled(1024, 0));
    }

    return SampleWithData(theCache, allKeys);
  }

  SampleWithData(this.cache, this.keys);

  final DiskCache cache;
  final Set<String> keys;

  Future<int> countItemsInCache() async {
    int countLeft = 0;
    for (var k in this.keys) if (await this.cache.readBytes(k) != null) countLeft++;
    return countLeft;
  }
}

Directory? findEmptySubdir(Directory d) {
  for (final fsEntry in d.listSync(recursive: true))
    if (fsEntry is Directory && fsEntry.listSync().length == 0)
      return fsEntry;
  return null;
}

void main() {
  test('Files: saving and reading', () async {
    final theDir = Directory.systemTemp.createTempSync();
    final path = theDir.path + "/temp";
    // writing
    writeKeyAndDataSync(File(path), "c:/key/name/", [4, 5, 6, 7]);
    // reading
    expect(readKeySync(File(path)), "c:/key/name/");
    expect(readIfKeyMatchSync(File(path), "c:/key/name/"), [4, 5, 6, 7]);
    expect(readIfKeyMatchSync(File(path), "other"), null);
  });

  test('Disk cache: write and read', () async {
    final dir = Directory.systemTemp.createTempSync();
    final cache = DiskCache(dir); // maxCount: 3, maxSizeBytes: 10
    // check it's null by default
    expect(await cache.readBytes("A"), null);
    // write and check it's not null anymore
    await cache.writeBytes("A", [1, 2, 3]);
    expect(await cache.readBytes("A"), [1, 2, 3]);
    expect(await cache.readBytes("A"), [1, 2, 3]); // reading again
  });

  test('Disk cache: write and delete', () async {
    final dir = Directory.systemTemp.createTempSync();
    final cache = DiskCache(dir); // maxCount: 3, maxSizeBytes: 10
    // check it's null by default
    expect(await cache.readBytes("A"), isNull);
    // write and check it's not null anymore
    await cache.writeBytes("A", [1, 2, 3]);
    expect(await cache.readBytes("A"), isNotNull);
    // delete
    expect(await cache.delete("A"), true);
    // reading the item returns null again
    expect(await cache.readBytes("A"), isNull);
    // deleting again does not produce errors, but returns false
    expect(await cache.delete("A"), false);
    expect(await cache.delete("A"), false);
  });

  test('Disk cache: timestamps', () async {
    final dir = Directory.systemTemp.createTempSync();
    final cache = DiskCache(dir);
    final itemFile = await cache.writeBytes("key", [23, 42]);
    final lmt = itemFile.lastModifiedSync();
    // reading the file attribute again gives the same last-modified
    expect(itemFile.lastModifiedSync(), equals(lmt));
    await Future.delayed(const Duration(milliseconds: 2100));
    // now we access the item through the cache object
    await cache.readBytes("key");
    // the last-modified is now be changed
    expect(itemFile.lastModifiedSync(), isNot(equals(lmt)));
  });

  test('hash collisions', () async {
    final theDir = Directory.systemTemp.createTempSync();
    //print(theDir);

    final cache = DiskCache(theDir,
        keyToHash: badHashFunc); // maxCount: 1000, maxSizeBytes: 10 * 1024 * 1024,

    Set<Directory> allSubdirs = Set<Directory>();
    Set<String> allKeys = Set<String>();
    Set<File> allFiles = Set<File>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      final file = await cache.writeBytes(key, [i, i + 10]);

      allFiles.add(file);
      allSubdirs.add(file.parent);
      allKeys.add(key);
    }

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      expect(await cache.readBytes(key), [i, i + 10]);
      //await cache.writeBytes(key, [i,i+10]);
    }

    // убеждаемся, что пока все файл и все подкаталоги на месте
    for (final d in allSubdirs) expect(d.existsSync(), isTrue);
    for (final f in allFiles) expect(f.existsSync(), isTrue);

    // удаляем все элементы, убеждаясь, что удаление одних элементов никогда не мешает другим
    // (а удаляем умышленно не по порядку, а рандомно)

    for (final key in allKeys.toList()..shuffle()) {
      expect(await cache.readBytes(key), isNotNull);
      await cache.delete(key);
      expect(await cache.readBytes(key), isNull);
    }

    // убеждаемся, что и файлы, и подкаталоги удалены
    for (final d in allSubdirs) expect(d.existsSync(), isFalse);
    for (final f in allFiles) expect(f.existsSync(), isFalse);

    expect(findEmptySubdir(theDir), null); // пустых подкаталогов не осталось
  });

  // CLEARING //////////////////////////////////////////////////////////////////////////////////////

  test('Compacting with maxCount', () async {
    final sample = await SampleWithData.create(lmtMatters: true);

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 100);

    sample.cache.compactSync(maxCount: 55);

    expect(await sample.countItemsInCache(), 55);
    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  test('Compacting with maxSize', () async {
    final sample = await SampleWithData.create(lmtMatters: true);

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 100);

    sample.cache.compactSync(maxSizeBytes: 52 * 1024); // max sum size = 52 KiB

    // 5<=n<95 files left
    expect(await sample.countItemsInCache(), greaterThanOrEqualTo(5));
    expect(await sample.countItemsInCache(), lessThan(95));

    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  test('Compacting with maxSize and maxCount', () async {
    final sample = await SampleWithData.create(lmtMatters: true);

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 100);

    sample.cache.compactSync(maxSizeBytes: 47 * 1024, maxCount: 45); // max sum size = 52 KiB

    expect(await sample.countItemsInCache(), 45);

    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  // RANDOM DELETIONS //////////////////////////////////////////////////////////////////////////////

  test('Deleting random files', () async {
    final sample = await SampleWithData.create();
    final cache = sample.cache;
    expect(countFiles(cache.directory), 100);
    // deleting 10 files
    deleteRandomItems(cache.directory, 10, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 90);
    expect(await sample.countItemsInCache(), 90);
    // deleting 15 more files
    deleteRandomItems(cache.directory, 15, FileSystemEntityType.file);
    expect(await sample.countItemsInCache(), 75);
    expect(countFiles(cache.directory), 75);
  });

  test('Deleting random directories', () async {
    final sample = await SampleWithData.create();
    final cache = sample.cache;
    expect(countFiles(cache.directory), 100);
    // deleting 10 directories
    deleteRandomItems(cache.directory, 10, FileSystemEntityType.directory);
    // checking that some items are left (and the cache works ok)
    expect(countFiles(cache.directory), greaterThan(5));
    expect(await sample.countItemsInCache(), greaterThan(5));
    // deleting 15 more files
    deleteRandomItems(cache.directory, 15, FileSystemEntityType.file);
    // checking that some items are left (and the cache works ok)
    expect(countFiles(cache.directory), greaterThan(5));
    expect(await sample.countItemsInCache(), greaterThan(5));
  });

  // RANDOM MONSTROUS //////////////////////////////////////////////////////////////////////////////

  test('Random monstrous', () async {

    // we will run two async functions that will work in parallel.
    // One will randomly add/read/delete items in the cache.
    // The other one will randomly delete them.

    const ACTIONS = 2000;
    const DELAY = 10;
    const UNIQUE_KEYS_RANGE = 50;
    final dir = Directory.systemTemp.createTempSync();
    final random = Random();

    Future<void> randomUser() async {
      // it this function we randomly use the cache
      final cache = DiskCache(dir, keyToHash: badHashFunc);
      final keys = <String>[];
      for (int i = 0; i < ACTIONS; ++i) {
        // making a random delay
        await Future.delayed(Duration(milliseconds: random.nextInt(DELAY)));
        // and performing a random action
        switch (random.nextInt(5)) {
          // adding a new key
          case 0:
          case 1:
          case 2:
            {
              final newKey = random.nextInt(UNIQUE_KEYS_RANGE).toRadixString(16);
              keys.add(newKey);
              // write random length of 42s (it's async but we are not waiting)
              cache.writeBytes(newKey, List.filled(random.nextInt(2048), 42));
              break;
            }
          // removing an old key
          case 3:
            {
              if (keys.length<=0)
                break;
              // (it's async but we are not waiting)
              final randomOldKey = keys.removeAt(random.nextInt(keys.length));
              cache.delete(randomOldKey);
              break;
            }
          // reading some key
          case 4:
            {
              if (keys.length<=0)
                break;
              final randomOldKey = keys.removeAt(random.nextInt(keys.length));
              // (it's async but we are not waiting)
              cache.readBytes(randomOldKey);
              break;
            }
        }
      }
    }

    Future<void> randomRemover() async {
      for (int i = 0; i < ACTIONS; ++i) {
        // making a random delay
        await Future.delayed(Duration(milliseconds: random.nextInt(DELAY)));
        // and performing a random action
        final deleteWhat =
                random.nextBool()
                ? FileSystemEntityType.file
                : FileSystemEntityType.directory;
        deleteRandomItems(dir, 1, deleteWhat, emptyOk: true, errorOk: true);
      }
    }

    await Future.wait([randomUser(), randomRemover()]);
  });
}
