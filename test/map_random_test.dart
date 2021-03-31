// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:fmap/fmap.dart';
import 'package:fmap/src/20_readwrite_v3.dart';
import 'package:fmap/src/81_bytes_fmap.dart';
import "package:test/test.dart";
import 'package:xrandom/xrandom.dart';

import 'helper.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  Future performRandomWritesAndDeletions(Fmap cache) async {
    cache.keyToHash = badHashFunc;
    await populate(cache);

    // we will perform 3000 actions in 3 seconds in async manner
    const ACTIONS = 3000;
    const MAX_DELAY = 3000;

    final random = Drandom();
    const UNIQUE_KEYS_COUNT = 50;

    List<Future> futures = [];
    final keys = <String>[];

    final typesOfActionsPerformed = Set<int>();
    int maxKeysCountEver = 0;

    Map<String, TypedBlob> reference = Map<String, TypedBlob>();

    // TODO purge

    for (int i = 0; i < ACTIONS; ++i) {
      futures.add(Future.delayed(Duration(milliseconds: random.nextInt(MAX_DELAY))).then((_) {
        // after the random delay perform a random action

        if (keys.length > maxKeysCountEver) maxKeysCountEver = keys.length;

        int act = random.nextInt(3);
        typesOfActionsPerformed.add(act);
        switch (act) {
          case 0: // add a key
            final newKey = random.nextInt(UNIQUE_KEYS_COUNT).toRadixString(16);
            keys.add(newKey);
            final item = TypedBlob(random.nextInt(2), List.filled(random.nextInt(2048), 42));
            reference[newKey] = item;
            cache.writeSync(newKey, item);
            break;
          case 1: // remove previously added key
            if (keys.length > 0) {
              final randomOldKey = keys.removeAt(random.nextInt(keys.length));
              ;
              final returned = cache.deleteSync(randomOldKey);
              expect(returned, reference.remove(randomOldKey));
            }
            break;
          case 2: // read a value
            if (keys.length > 0) {
              final randomKey = keys[random.nextInt(keys.length)];
              final existingValue = cache.readSync(randomKey);
              expect(existingValue, reference[randomKey]);
            }
            break;
          default:
            throw FallThroughError();
        }
      }));
    }

    await Future.wait(futures);
    //print(typesOfActionsPerformed);
    assert(typesOfActionsPerformed.length == 3);
    assert(maxKeysCountEver > 5);
  }

  test("Random stress", () async {
    await performRandomWritesAndDeletions(Fmap(tempDir));
  });
}
