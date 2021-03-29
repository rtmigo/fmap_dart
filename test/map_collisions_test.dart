// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/81_file_stored_map.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test("cache collisions", () {
    //test('BytesMap hash collisions', () async {

    final cache = StoredBytesMap(tempDir);
    cache.keyToHash = badHashFunc;

    //Set<Directory> allSubdirs = Set<Directory>();
    Set<String> allKeys = Set<String>();
    Set<File> allFiles = Set<File>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      cache.writeBytesSync(key, [i, i + 10]);
      allFiles.add(cache.keyToFile(key));
      //allSubdirs.add(file.parent);
      allKeys.add(key);
    }

    int stillInCacheCount = 0;

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();

      var bytes = cache.readBytesSync(key);
      if (bytes != null) {
        expect(bytes, [i, i + 10]);
        stillInCacheCount++;
      }
    }

    expect(stillInCacheCount, 100);

    // make sure that all the files and the subdirectories are still in place
    //for (final d in allSubdirs) expect(d.existsSync(), isTrue);
    for (final f in allFiles) expect(f.existsSync(), isTrue);

    // deleting items in random order

    for (final key in allKeys.toList()..shuffle()) {
      cache.deleteSync(key);
      expect(cache.readBytesSync(key), isNull);
    }

    // making sure that both files and subdirectories are deleted
    //for (final d in allSubdirs) expect(d.existsSync(), isFalse);
    for (final f in allFiles) expect(f.existsSync(), isFalse);

    expect(findEmptySubdirectory(tempDir), null); // no empty subdirs
    //});
  });

  test("cache overwrite", () {
    // test whether new elements (with same hash) overwrite old ones

    final cache = StoredBytesMap(tempDir);
    cache.keyToHash = badHashFunc;

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      cache.writeBytesSync(key, [i, i + 1, i + 2]);
      expect(cache.readBytesSync(key), [i, i + 1, i + 2]);
    }
  });
}
