// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/81_bytes_fmap.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {
  late Directory tempDir;
  late BytesFmap cache;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync();
    cache = BytesFmap(tempDir);
    cache.keyToHash = badHashFunc;
    await populate(cache);
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test('updateTimestamps default', () {
    var z = BytesFmap(Directory("labuda321"));
    expect(z.updateTimestampsOnRead, false);
  });

  test('updateTimestamps changed', () {
    var z = BytesFmap(Directory("labuda321"), updateTimestampsOnRead: true);
    expect(z.updateTimestampsOnRead, true);
  });

  // // RANDOM DELETIONS ///////////////////////////////////////////////////////////////////////////

  test('Deleting random files', () async {
    expect(countFiles(cache.directory), 15);

    deleteRandomItems(cache.directory, 3, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 12);

    deleteRandomItems(cache.directory, 2, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 10);
  });
}
