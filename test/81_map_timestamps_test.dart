// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';

void runTests(String prefix, BytesStore create(Directory d), bool mustUpdate) {
  Directory? tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });


  test('$prefix Disk cache: timestamp updated', () async {

    final map = create(tempDir!);
    final itemFile = await map.writeBytesSync("key", [23, 42]);
    final lmt = itemFile.lastModifiedSync();
    expect(itemFile.lastModifiedSync(), equals(lmt));

    // reading the same value a bit later
    await Future.delayed(const Duration(milliseconds: 2100));
    await map.readBytesSync("key");

    if (mustUpdate)
      // the last-modified is now be changed
      expect(itemFile.lastModifiedSync(), isNot(equals(lmt)));
    else
      expect(itemFile.lastModifiedSync(), equals(lmt));
  });
}

void main() {
  runTests("BytesMap:", (dir)=>BytesMap(dir), false);
  runTests("BytesCache:", (dir)=>BytesCache(dir), false);

  runTests("BytesMap updating:", (dir)=>BytesMap(dir, updateTimestampsOnRead: true), true);
  runTests("BytesCache updating:", (dir)=>BytesCache(dir, updateTimestampsOnRead: true), true);

}