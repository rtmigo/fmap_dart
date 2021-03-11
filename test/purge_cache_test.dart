// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";

import 'tstcommon.dart';

void main() {

  Directory? tempDir;
  late FilledWithData sample;
  late BytesCache cache;


  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
    cache = BytesCache(tempDir);
    cache.keyToHash = badHashFunc;
    sample = FilledWithData(cache, lmtMatters: true);
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });

  test('Purge with maxCount', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 15);

    sample.cache.compactSync(maxCount: 10);

    expect(await sample.countItemsInCache(), 10);
    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  test('Purge with maxSize', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 15);

    sample.cache.compactSync(maxSizeBytes: 5 * 1024);

    // 5<=n<95 files left
    expect(await sample.countItemsInCache(), greaterThanOrEqualTo(2));
    expect(await sample.countItemsInCache(), lessThan(10));

    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  test('Purge with maxSize and maxCount', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(sample.cache.directory), 15);

    sample.cache.compactSync(maxSizeBytes: 7 * 1024, maxCount: 5);

    expect(await sample.countItemsInCache(), 5);

    expect(findEmptySubdir(sample.cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });

  // RANDOM DELETIONS //////////////////////////////////////////////////////////////////////////////

  test('Deleting random files', () async {

    expect(countFiles(cache.directory), 15);

    deleteRandomItems(cache.directory, 3, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 12);
    expect(await sample.countItemsInCache(), 12);

    deleteRandomItems(cache.directory, 2, FileSystemEntityType.file);
    expect(await sample.countItemsInCache(), 10);
    expect(countFiles(cache.directory), 10);
  });



}