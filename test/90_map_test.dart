// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:disk_cache/disk_cache.dart';
import "package:test/test.dart";

import 'common.dart';

void main() {

  Directory? tempDir;
  late BytesMap cache;


  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync();
    cache = BytesMap(tempDir);
    cache.keyToHash = badHashFunc;
    await populate(cache);
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });

  test('Purge with maxCount', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(cache.directory), 100);

    cache.compactSync(maxCount: 55);

    expect(countFiles(cache.directory), 55);
    expect(findEmptySubdirectory(cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(cache.readBytesSync(KEY_EARLIEST), isNull);
    expect(cache.readBytesSync(KEY_LATEST), isNotNull);
  });

  test('Purge with maxSize', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(cache.directory), 100);

    cache.compactSync(maxSizeBytes: 52 * 1024); // max sum size = 52 KiB

    // 5<=n<95 files left
    expect(cache.length, greaterThanOrEqualTo(5));
    expect(countFiles(cache.directory), lessThan(95));

    expect(findEmptySubdirectory(cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(cache.readBytesSync(KEY_EARLIEST), isNull);
    expect(cache.readBytesSync(KEY_LATEST), isNotNull);
  });

  test('Purge with maxSize and maxCount', () async {

    // [!!!] if we call sample.cache.readBytes now, it will lead to rewriting
    // the last-modified date, so we will lose the expected files order.
    // We should not do that

    expect(countFiles(cache.directory), 100);

    cache.compactSync(maxSizeBytes: 47 * 1024, maxCount: 45); // max sum size = 52 KiB

    expect(countFiles(cache.directory), 45);

    expect(findEmptySubdirectory(cache.directory), null); // no empty subdirectories

    // the first element was definitely deleted, the last one was definitely left
    expect(cache.readBytesSync(KEY_EARLIEST), isNull);
    expect(cache.readBytesSync(KEY_LATEST), isNotNull);
  });

  // RANDOM DELETIONS //////////////////////////////////////////////////////////////////////////////

  test('Deleting random files', () async {
    expect(countFiles(cache.directory), 100);

    // deleting 10 files
    deleteRandomItems(cache.directory, 10, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 90);

    // deleting 15 more files
    deleteRandomItems(cache.directory, 15, FileSystemEntityType.file);
    expect(countFiles(cache.directory), 75);
  });

  test('Deleting random directories', () async {

    expect(countFiles(cache.directory), 100);

    // deleting 10 directories
    deleteRandomItems(cache.directory, 10, FileSystemEntityType.directory);

    // checking that some items are left (and the cache works ok)
    expect(countFiles(cache.directory), greaterThan(5));

    // deleting 15 more files
    deleteRandomItems(cache.directory, 15, FileSystemEntityType.file);

    // checking that some items are left (and the cache works ok)
    expect(countFiles(cache.directory), greaterThan(5));
  });

}