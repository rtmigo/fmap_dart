// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';
import 'dart:io' show Platform;


void main() {

  test('Disk cache: write and read', () {
    final dir = Directory.systemTemp.createTempSync();
    final cache = BytesStorage(dir); // maxCount: 3, maxSizeBytes: 10
    // check it's null by default
    expect(cache["A"], null);
    // write and check it's not null anymore
    cache["A"] = [1, 2, 3];
    //cache.writeBytes("A", [1, 2, 3]);
    expect(cache["A"], [1, 2, 3]);
    expect(cache["A"], [1, 2, 3]); // reading again
  });

  test('Disk cache: write and delete', () {
    final dir = Directory.systemTemp.createTempSync();
    final cache = BytesStorage(dir); // maxCount: 3, maxSizeBytes: 10

    // check it's null by default
    expect(cache["A"], isNull);

    // write and check it's not null anymore
    cache["A"] = [1, 2, 3];
    expect(cache["A"], isNotNull);

    // delete
    cache.remove("A");

    // reading the item returns null again
    expect(cache["A"], isNull);

    // deleting again does not throw errors, but returns false
    cache.remove("A"); // todo different for  store and cache?
    //expect(cache.delete("A"), false);
    //expect(cache.delete("A"), false);
  });

  test('Disk cache: list items', () {

    final dir = Directory.systemTemp.createTempSync();
    final cache = BytesStorage(dir);

    expect(cache.keys.toSet(), isEmpty);

    cache["A"] = [1,2,3];
    cache["B"] = [4,5];
    cache["C"] = [5];

    expect(cache.keys.toSet(), {"A", "B", "C"});

    cache["B"] = null;

    expect(cache.keys.toSet(), {"A", "C"});
  });

  test('Disk cache: clear', () {

    final dir = Directory.systemTemp.createTempSync();
    final cache = BytesStorage(dir);

    expect(cache.keys.toSet(), isEmpty);

    cache["A"] = [1,2,3];
    cache["B"] = [4,5];
    cache["C"] = [5];

    expect(cache.keys.toSet(), {"A", "B", "C"});

    cache.clear();

    expect(cache.keys.toSet(), isEmpty);
  });



  test('Disk cache: timestamps', () async {
    final dir = Directory.systemTemp.createTempSync();
    final cache = BytesStorage(dir);
    final itemFile = await cache.writeBytes("key", [23, 42]);
    final lmt = itemFile.lastModifiedSync();

    // reading the file attribute again gives the same last-modified
    expect(itemFile.lastModifiedSync(), equals(lmt));
    await Future.delayed(const Duration(milliseconds: 2100));

    // now we access the item through the cache object
    await cache.readBytes("key");

    // the last-modified is now be changed
    expect(itemFile.lastModifiedSync(), isNot(equals(lmt)));
  });
}