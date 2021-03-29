// SPDX-FileCopyrightText: (c) 2020 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:disk_cache/src/81_file_stored_map.dart';
import "package:test/test.dart";

import 'helper.dart';

void runTests(String prefix, DiskBytesStore create(Directory d)) {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
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

  test('$prefix Contains', () {
    final map = create(tempDir!);

    expect(map.keys.toSet(), isEmpty);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.containsKey("A"), true);
    expect(map.containsKey("X"), false);
    expect(map.containsKey("B"), true);
    expect(map.containsKey("Y"), false);
    expect(map.containsKey("C"), true);
  });
}

void main() {
  runTests("BytesMap:", (dir)=>StoredBytesMap(dir));
  // runTests("BytesCache:", (dir)=>DiskBytesCache(dir));
}