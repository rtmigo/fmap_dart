// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'package:fmap/src/81_bytes_fmap.dart';
import 'package:path/path.dart' as path;
import "package:test/test.dart";

import 'helper.dart';

void runTests(String prefix, Fmap create(Directory d)) {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  group('in non-existent dir', () {
    test('write then read', () {
      final map = Fmap(Directory(path.join(tempDir.path, 'nonexistent')));
      map['A'] = [1, 2, 3];
      expect(map['A'], [1, 2, 3]);
    });

    test('read then write', () {
      final map = Fmap(Directory(path.join(tempDir.path, 'nonexistent')));
      expect(map['A'], null);
      map['A'] = [1, 2, 3];
      expect(map['A'], [1, 2, 3]);
    });

    test('list', () {
      final map = Fmap(Directory(path.join(tempDir.path, 'nonexistent')));
      expect(map.entries.toList().length, 0);
    });
  });

  group('in temp dir', () {
    test('no param', () {
      final map = Fmap.temp();
      expect(map.directory.path.endsWith('fmap'), isTrue);
      map['A'] = [1, 2, 3];
      expect(map['A'], [1, 2, 3]);
      map.directory.deleteSync(recursive: true);
    });

    test('subdirname', () {
      final map = Fmap.temp(subdir: 'tempSubdir123');
      expect(map.directory.path.endsWith('tempSubdir123'), isTrue);
      map['A'] = [1, 2, 3];
      expect(map['A'], [1, 2, 3]);
      assert(map.directory.path.contains('temp'));
      map.directory.deleteSync(recursive: true);
    });

    test('with policy', () {
      final map = Fmap.temp(policy: Policy.lru);
      expect(map.updateTimestampsOnRead, isTrue);
    });

    test('without policy', () {
      final map = Fmap.temp();
      expect(map.updateTimestampsOnRead, isFalse);
    });
  });

  test('All files are in v1 subdir', () {
    final map = Fmap(tempDir);
    expect(map.keyToFile('key').path.contains('v1'), isTrue);
  });

  test('$prefix write and read', () {
    final map = create(tempDir); // maxCount: 3, maxSizeBytes: 10
    // check it's null by default
    expect(map["A"], null);
    // write and check it's not null anymore
    map["A"] = [1, 2, 3];
    //cache.writeBytes("A", [1, 2, 3]);
    expect(map["A"], [1, 2, 3]);
    expect(map["A"], [1, 2, 3]); // reading again
  });

  test('$prefix write and delete', () {
    final map = create(tempDir); // maxCount: 3, maxSizeBytes: 10

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

  test('delete', () {
    final map = create(tempDir);
    map["A"] = [1, 2, 3];
    expect(map["A"], isNotNull);

    // deleting must return the removed item
    expect(map.remove("A"), [1, 2, 3]);
    expect(map["A"], isNull);

    // deleting when the item does not exist returns null
    expect(map.remove("A"), isNull);
  });

  test('keys and entries when empty', () {
    final map = create(tempDir);

    expect(map.keys.toList(), isEmpty);
    expect(map.entries.toList(), isEmpty);
    expect(map.length, 0);
  });

  test('keys', () {
    final map = create(tempDir);

    expect(map.keys.toSet(), isEmpty);
    expect(map.length, 0);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.keys.toSet(), {"A", "B", "C"});
    expect(map.length, 3);

    map["B"] = null;

    expect(map.keys.toSet(), {"A", "C"});
    expect(map.length, 2);
  });

  test('entries', () {
    final map = create(tempDir);

    expect(map.length, 0);

    map["A"] = 1.0;
    map["B"] = 'data';
    map["C"] = [5];

    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    expect(entries.length, 3);

    expect(entries[0].key, 'A');
    expect(entries[0].value, 1.0);

    expect(entries[1].key, 'B');
    expect(entries[1].value, 'data');

    expect(entries[2].key, 'C');
    expect(entries[2].value, [5]);
  });

  test('contains', () {
    final map = create(tempDir);

    expect(map.containsKey('A'), isFalse);
    expect(map.containsKey('B'), isFalse);
    expect(map.containsKey('C'), isFalse);
    expect(map.containsKey('D'), isFalse);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.containsKey('A'), isTrue);
    expect(map.containsKey('B'), isTrue);
    expect(map.containsKey('C'), isTrue);
    expect(map.containsKey('D'), isFalse);
  });

  test('$prefix Disk cache: clear', () {
    final map = create(tempDir);

    expect(map.keys.toSet(), isEmpty);

    map["A"] = [1, 2, 3];
    map["B"] = [4, 5];
    map["C"] = [5];

    expect(map.keys.toSet(), {"A", "B", "C"});

    map.clear();

    expect(map.keys.toSet(), isEmpty);
  });

  test('$prefix Contains', () {
    final map = create(tempDir);

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

  test('string', () {
    final map = create(tempDir);
    map["A"] = "hello";
    map["B"] = "good bye";
    map["C"] = "";
    expect(map['A'], 'hello');
    expect(map['B'], 'good bye');
    expect(map['C'], '');
  });

  test('int', () {
    final map = create(tempDir);
    map["A"] = 1024;
    map["B"] = 5;
    expect(map['A'], 1024);
    expect(map['B'], 5);
  });

  test('bool', () {
    final map = create(tempDir);
    map["A"] = true;
    map["B"] = false;
    expect(map['A'], true);
    expect(map['B'], false);
  });

  test('double', () {
    final map = create(tempDir);
    map["A"] = 3.1415;
    map["B"] = 2.7183;
    expect(map['A'], 3.1415);
    expect(map['B'], 2.7183);
  });

  test('string list', () {
    final map = create(tempDir);
    map['key1'] = ['aaa', 'bbb', 'ccc'];
    map['key3'] = <String>[];
    map['key2'] = ['one', 'two', 'three'];


    expect(map['key2'], ['one', 'two', 'three']);
    expect(map['key1'], ['aaa', 'bbb', 'ccc']);
    expect(map['key3'], []);
  });


  test('Type mix', () {
    final map = create(tempDir);

    map['a'] = 'hello';
    map['b'] = [1, 2, 3];
    map['c'] = 'hi';
    map['d'] = [5];

    expect(map['a'], 'hello');
    expect(map['b'], [1, 2, 3]);
    expect(map['c'], 'hi');
    expect(map['d'], [5]);

    map['b'] = 'new string';
    map['c'] = [7, 7, 7];
    expect(map['a'], 'hello');
    expect(map['b'], 'new string');
    expect(map['c'], [7, 7, 7]);
    expect(map['d'], [5]);
  });

  test('Generic string', () {
    final map = Fmap<String>(tempDir);

    map['a'] = 'hello';
    map['c'] = 'hi';

    expect(map['a'], 'hello');
    expect(map['c'], 'hi');
  });

  test('Generic Uint8List', () {
    final map = Fmap<Uint8List>(tempDir);

    map['a'] = Uint8List.fromList([1, 2, 3]);
    map['c'] = Uint8List.fromList([4, 5]);

    expect(map['a'], [1, 2, 3]);
    expect(map['c'], [4, 5]);
  });
}

void main() {
  runTests("BytesMap:", (dir) => Fmap(dir));
  // runTests("BytesCache:", (dir)=>DiskBytesCache(dir));
}
