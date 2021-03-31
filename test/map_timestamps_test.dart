// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:fmap/fmap.dart';
import 'package:fmap/src/10_readwrite_v3.dart';
import 'package:fmap/src/81_bytes_fmap.dart';
import "package:test/test.dart";

import 'helper.dart';

void runTests(String prefix, Fmap createFmap(Directory d), bool mustUpdate) {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test('$prefix Disk cache: timestamp updated', () async {
    const key = "key";

    final map = createFmap(tempDir);
    map.writeSync(key, TypedBlob(0, [23, 42]));
    final lmt = map.keyToFile(key).lastModifiedSync();
    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));

    // reading the same value a bit later
    await Future.delayed(const Duration(milliseconds: 2100));
    await map.readSync(key);

    if (mustUpdate) {
      // the last-modified is now be changed
      expect(map.keyToFile(key).lastModifiedSync(), isNot(equals(lmt)));
    } else {
      expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));
    }
  });

  test('$prefix containsKey does not update timestamps', () async {
    const key = "key";

    final map = createFmap(tempDir);
    map[key] = 10;

    final lmt = map.keyToFile(key).lastModifiedSync();
    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));

    // pause
    await Future.delayed(const Duration(milliseconds: 2100));
    // checking key, but not reading data
    expect(map.containsKey(key), isTrue);

    expect(map.keyToFile(key).lastModifiedSync(), equals(lmt));
  });

  test('$prefix iterating entries updates timestamps', () async {
    final map = createFmap(tempDir);

    map['A'] = 1;
    map['B'] = 2;

    // remembering timestamps
    final lmt1 = map.keyToFile('A').lastModifiedSync();
    final lmt2 = map.keyToFile('B').lastModifiedSync();

    // pause
    await Future.delayed(const Duration(milliseconds: 2100));

    // iterating all entries (and possibly updating)
    map.entries.toList();

    if (mustUpdate) {
      // the last-modified is now be changed
      expect(map.keyToFile('A').lastModifiedSync(), isNot(equals(lmt1)));
      expect(map.keyToFile('B').lastModifiedSync(), isNot(equals(lmt2)));
    } else {
      expect(map.keyToFile('A').lastModifiedSync(), equals(lmt1));
      expect(map.keyToFile('B').lastModifiedSync(), equals(lmt2));
    }
  });

  test('$prefix iterating keys does not update timestamps', () async {
    final map = createFmap(tempDir);

    map['A'] = 1;
    map['B'] = 2;

    // remembering timestamps
    final lmt1 = map.keyToFile('A').lastModifiedSync();
    final lmt2 = map.keyToFile('B').lastModifiedSync();

    // pause
    await Future.delayed(const Duration(milliseconds: 2100));

    // iterating all entries (and possibly updating)
    map.keys.toList();

    expect(map.keyToFile('A').lastModifiedSync(), equals(lmt1));
    expect(map.keyToFile('B').lastModifiedSync(), equals(lmt2));
  });
}

void main() {
  runTests("non", (dir) => Fmap(dir), false);
  runTests("updating", (dir) => Fmap(dir, policy: Policy.lru), true);
}
