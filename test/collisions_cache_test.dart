// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";

import 'tstcommon.dart';

void main() {

  Directory? tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });

  test("map collisions", () {

    //test('BytesMap hash collisions', () async {

      final cache = BytesCache(tempDir);
      cache.keyToHash = badHashFunc;

      //Set<Directory> allSubdirs = Set<Directory>();
      Set<String> allKeys = Set<String>();
      Set<File> allFiles = Set<File>();

      for (var i = 0; i < 100; ++i) {
        var key = i.toString();
        final file = cache.writeBytes(key, [i, i + 10]);

        allFiles.add(file);
        //allSubdirs.add(file.parent);
        allKeys.add(key);
      }

      int stillInCacheCount = 0;

      for (var i = 0; i < 100; ++i) {
        var key = i.toString();

        var bytes = cache.readBytes(key);
        if (bytes!=null) {
          expect(bytes, [i, i + 10]);
          stillInCacheCount++;
        }
      }

      expect(stillInCacheCount, 15);

      // make sure that all the files and the subdirectories are still in place
      //for (final d in allSubdirs) expect(d.existsSync(), isTrue);
      for (final f in allFiles) expect(f.existsSync(), isTrue);

      // deleting items in random order

      for (final key in allKeys.toList()..shuffle()) {
        cache.delete(key);
        expect(cache.readBytes(key), isNull);
      }

      // making sure that both files and subdirectories are deleted
      //for (final d in allSubdirs) expect(d.existsSync(), isFalse);
      for (final f in allFiles) expect(f.existsSync(), isFalse);

      expect(findEmptySubdir(tempDir!), null); // no empty subdirs
    //});
  });
}