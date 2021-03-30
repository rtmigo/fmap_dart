// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:fmap/fmap.dart';
import 'package:fmap/src/81_bytes_fmap.dart';
import "package:test/test.dart";
import 'package:fmap/src/10_readwrite_v3.dart';

import 'helper.dart';

void runTests(String prefix, Fmap create(Directory d), bool mustUpdate) {
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
    map.writeSync(key, TypedBlob(0, [23, 42]));
    final lmt = map.keyToFile(key).lastModifiedSync();
    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));

    // reading the same value a bit later
    await Future.delayed(const Duration(milliseconds: 2100));
    await map.readSync("key");

    if (mustUpdate)
      // the last-modified is now be changed
      expect(map.keyToFile(key).lastModifiedSync(), isNot(equals(lmt)));
    else
      expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));
  });
}

void main() {
  runTests("non", (dir) => Fmap(dir), false);
  runTests("updating", (dir) => Fmap(dir, policy: Policy.lru), true);
  //runTests("BytesMap:", (dir)=>DiskBytesMap(dir), false);
  //runTests("BytesCache:", (dir)=>DiskBytesCache(dir), false);

  //runTests("BytesMap updating:", (dir)=>DiskBytesMap(dir, updateTimestampsOnRead: true), true);
  //runTests("BytesCache updating:", (dir)=>DiskBytesCache(dir, updateTimestampsOnRead: true), true);
}
