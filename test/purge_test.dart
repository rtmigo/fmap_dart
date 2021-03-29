// SPDX-FileCopyrightText: (c) 2021 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


import 'dart:io';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:disk_cache/src/file_stored_map.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir.existsSync()) { tempDir.deleteSync(recursive: true); }
  });

  test("purge", () async {

    final cache = StoredBytesMap(tempDir);
    await populate(cache);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(100 * 1024));
      expect(sfz, lessThan(120 * 1024));
    }

    cache.purgeSync(75*1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(70 * 1024));
      expect(sfz, lessThan(80 * 1024));
    }

    cache.purgeSync(30*1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(20 * 1024));
      expect(sfz, lessThan(40 * 1024));
    }

    cache.purgeSync(0*1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, 0);
    }

  });


}