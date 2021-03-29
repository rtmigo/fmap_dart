// SPDX-FileCopyrightText: (c) 2020 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


import 'dart:io';
import 'dart:math';
import 'package:disk_cache/disk_cache.dart';
import 'package:disk_cache/src/80_unistor.dart';
import 'package:disk_cache/src/81_file_stored_map.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  Future performRandomWritesAndDeletions(DiskBytesStore cache) async {

    cache.keyToHash = badHashFunc;
    await populate(cache);

    // we will perform 3000 actions in 3 seconds in async manner
    const ACTIONS = 3000;
    const MAX_DELAY = 3000;

    final random = Random();
    const UNIQUE_KEYS_COUNT = 50;

    List<Future> futures = [];
    final keys = <String>[];

    final typesOfActionsPerformed = Set<int>();
    int maxKeysCountEver = 0;

    // TODO purge
    // TODO compare to Map

    for (int i = 0; i < ACTIONS; ++i) {
      futures.add(Future.delayed(Duration(milliseconds: random.nextInt(MAX_DELAY))).then((_) {
        // after the random delay perform a random action

        if (keys.length>maxKeysCountEver)
          maxKeysCountEver = keys.length;

        int act = random.nextInt(3);
        typesOfActionsPerformed.add(act);
        switch (act) {
          case 0: // add a key
            final newKey = random.nextInt(UNIQUE_KEYS_COUNT).toRadixString(16);
            keys.add(newKey);
            cache.writeBytesSync(newKey, List.filled(random.nextInt(2048), 42));
            break;
          case 1: // remove previously added key
            if (keys.length>0) {
              final randomOldKey = keys.removeAt(random.nextInt(keys.length));
              cache.deleteSync(randomOldKey);
            }
            break;
          case 2: // read a value
            if (keys.length>0) {
              final randomKey = keys[random.nextInt(keys.length)];
              var x = cache[randomKey];
            }
            break;
          default:
            throw FallThroughError();
        }
      }));
    }

    await Future.wait(futures);
    //print(typesOfActionsPerformed);
    assert(typesOfActionsPerformed.length==3);
    assert(maxKeysCountEver>5);
  }

  test("Random stress", () async {
    await performRandomWritesAndDeletions(StoredBytesMap(tempDir));
  });



}