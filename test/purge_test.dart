// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/81_bytes_fmap.dart';
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

  test("purge", () async {
    final cache = BytesFmap(tempDir);
    await populate(cache);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(100 * 1024));
      expect(sfz, lessThan(120 * 1024));
    }

    cache.purgeSync(75 * 1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(70 * 1024));
      expect(sfz, lessThan(80 * 1024));
    }

    cache.purgeSync(30 * 1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, greaterThan(20 * 1024));
      expect(sfz, lessThan(40 * 1024));
    }

    cache.purgeSync(0 * 1024);

    {
      int sfz = sumFilesSize(tempDir);
      expect(sfz, 0);
    }
  });
}
