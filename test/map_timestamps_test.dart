// SPDX-FileCopyrightText: (c) 2020 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


import 'dart:io';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:disk_cache/src/file_stored_map.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';

void runTests(String prefix, StoredBytesMap create(Directory d), bool mustUpdate) {
  Directory? tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });


  test('$prefix Disk cache: timestamp updated', () async {

    const key = "key";

    final map = create(tempDir!);
    map.writeBytesSync(key, [23, 42]);
    final lmt = map.keyToFile(key).lastModifiedSync();
    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));

    // reading the same value a bit later
    await Future.delayed(const Duration(milliseconds: 2100));
    await map.readBytesSync("key");

    if (mustUpdate)
      // the last-modified is now be changed
      expect(map.keyToFile(key).lastModifiedSync(), isNot(equals(lmt)));
    else
      expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));
  });
}

void main() {
  runTests("non", (dir)=>StoredBytesMap(dir), false);
  runTests("updating", (dir)=>StoredBytesMap(dir, updateTimestampsOnRead: true), true);
  //runTests("BytesMap:", (dir)=>DiskBytesMap(dir), false);
  //runTests("BytesCache:", (dir)=>DiskBytesCache(dir), false);

  //runTests("BytesMap updating:", (dir)=>DiskBytesMap(dir, updateTimestampsOnRead: true), true);
  //runTests("BytesCache updating:", (dir)=>DiskBytesCache(dir, updateTimestampsOnRead: true), true);

}