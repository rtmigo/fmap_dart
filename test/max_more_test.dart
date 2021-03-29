// SPDX-FileCopyrightText: (c) 2021 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


import 'dart:io';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:disk_cache/src/81_file_stored_map.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {

  late Directory tempDir;
  late StoredBytesMap cache;


  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync();
    cache = StoredBytesMap(tempDir);
    cache.keyToHash = badHashFunc;
    await populate(cache);
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test('updateTimestamps default', () {
    var z = StoredBytesMap(Directory("labuda321"));
    expect(z.updateTimestampsOnRead, false);
  });

  test('updateTimestamps changed', () {
    var z = StoredBytesMap(Directory("labuda321"), updateTimestampsOnRead: true);
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