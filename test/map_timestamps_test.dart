// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/81_bytes_fmap.dart';
import "package:test/test.dart";
import 'package:disk_cache/src/10_readwrite_v3.dart';

import 'helper.dart';

void runTests(String prefix, BytesFmap create(Directory d), bool mustUpdate) {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test('$prefix Disk cache: timestamp updated', () async {
    const key = "key";

    final map = create(tempDir);
    map.writeBytesSync(key, TypedBlob(0, [23, 42]));
    final lmt = map.keyToFile(key).lastModifiedSync();
    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));

    // reading the same value a bit later
    await Future.delayed(const Duration(milliseconds: 2100));
    await map.readTypedBlobSync("key");

    if (mustUpdate)
      // the last-modified is now be changed
      expect(map.keyToFile(key).lastModifiedSync(), isNot(equals(lmt)));
    else
      expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));
  });
}

void main() {
  runTests("non", (dir) => BytesFmap(dir), false);
  runTests("updating", (dir) => BytesFmap(dir, updateTimestampsOnRead: true), true);
  //runTests("BytesMap:", (dir)=>DiskBytesMap(dir), false);
  //runTests("BytesCache:", (dir)=>DiskBytesCache(dir), false);

  //runTests("BytesMap updating:", (dir)=>DiskBytesMap(dir, updateTimestampsOnRead: true), true);
  //runTests("BytesCache updating:", (dir)=>DiskBytesCache(dir, updateTimestampsOnRead: true), true);
}
