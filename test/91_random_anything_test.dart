// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:math';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";

import 'common.dart';

void main() {

  Directory? tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    if (tempDir!.existsSync()) tempDir!.deleteSync(recursive: true);
  });

  Future performRandomWritesAndDeletions(BytesStore cache) async {

    return 0; // not yet

    cache.keyToHash = badHashFunc;
    populate(cache);

    const ACTIONS = 1500;
    const DELAY = 10;
    assert (ACTIONS*DELAY < 30000); // to avoid test timeout

    const UNIQUE_KEYS_RANGE = 50;
    final dir = Directory.systemTemp.createTempSync();
    final random = Random();

    // it this function we randomly use the cache
    //final cache = createMap(dir);
    cache.keyToHash = badHashFunc;
    final keys = <String>[];
    for (int i = 0; i < ACTIONS; ++i) {
      // making a random delay
      await Future.delayed(Duration(milliseconds: random.nextInt(DELAY)));
      // and performing a random action
      switch (random.nextInt(5)) {
      // map adds a new key
        case 0:
          {
            final newKey = random.nextInt(UNIQUE_KEYS_RANGE).toRadixString(16);
            keys.add(newKey);
            // write random length of 42s (it's async but we are not waiting)
            cache.writeBytesSync(newKey, List.filled(random.nextInt(2048), 42));
            break;
          }
      // map removes some key
        case 1:
          {
            if (keys.length<=0)
              break;
            // (it's async but we are not waiting)
            final randomOldKey = keys.removeAt(random.nextInt(keys.length));
            cache.deleteSync(randomOldKey);
            break;
          }
      // map reads some key
        case 2:
          {
            if (keys.length<=0)
              break;
            final randomOldKey = keys.removeAt(random.nextInt(keys.length));
            // (it's async but we are not waiting)
            cache.readBytesSync(randomOldKey);
            break;
          }
      // file disappears
        case 3:
          deleteRandomItems(dir, 1, FileSystemEntityType.file, emptyOk: true, errorOk: true);
          break;

      // directory disappears
        case 4:
          deleteRandomItems(dir, 1, FileSystemEntityType.directory, emptyOk: true, errorOk: true);
          break;


        default:
          throw FallThroughError();
      }
    }

  }

  test("Random map", () async {
    await performRandomWritesAndDeletions(BytesMap(tempDir));
  });

  test("Random cache", () async {
    await performRandomWritesAndDeletions(BytesCache(tempDir));
  });

}