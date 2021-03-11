// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
//import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';

void runTests(String prefix, create(Directory d)) {
  Directory? tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });

  test('$prefix write and read', () {
    final map = create(tempDir!); // maxCount: 3, maxSizeBytes: 10
    // check it's null by default
    expect(map["A"], null);
    // write and check it's not null anymore
    map["A"] = [1, 2, 3];
    //cache.writeBytes("A", [1, 2, 3]);
    expect(map["A"], [1, 2, 3]);
    expect(map["A"], [1, 2, 3]); // reading again
  });

  test('$prefix write and delete', () {
    final map = create(tempDir!); // maxCount: 3, maxSizeBytes: 10

    // check it's null by default
    expect(map["A"], isNull);

    // write and check it's not null anymore
    map["A"] = [1, 2, 3];
    expect(map["A"], isNotNull);

    // delete
    map.remove("A");

    // reading the item returns null again
    expect(map["A"], isNull);

    // deleting again does not throw errors, but returns false
    map.remove("A"); // todo different for  store and cache?
    //expect(cache.delete("A"), false);
    //expect(cache.delete("A"), false);
  });

  test('$prefix list items', () {
    final map = create(tempDir!);

    expect(map.keys.toSet(), isEmpty);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.keys.toSet(), {"A", "B", "C"});

    map["B"] = null;

    expect(map.keys.toSet(), {"A", "C"});
  });

  test('$prefix Disk cache: clear', () {
    final map = create(tempDir!);

    expect(map.keys.toSet(), isEmpty);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.keys.toSet(), {"A", "B", "C"});

    map.clear();

    expect(map.keys.toSet(), isEmpty);
  });

  test('$prefix Disk cache: timestamps', () async {
    final map = create(tempDir!);
    final itemFile = await map.writeBytes("key", [23, 42]);
    final lmt = itemFile.lastModifiedSync();

    // reading the file attribute again gives the same last-modified
    expect(itemFile.lastModifiedSync(), equals(lmt));
    await Future.delayed(const Duration(milliseconds: 2100));

    // now we access the item through the cache object
    await map.readBytes("key");

    // the last-modified is now be changed
    expect(itemFile.lastModifiedSync(), isNot(equals(lmt)));
  });
}

void main() {
  runTests("BytesMap:", (dir)=>BytesMap(dir));
}