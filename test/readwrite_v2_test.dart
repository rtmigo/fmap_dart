// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:disk_cache/src/10_readwrite_v2.dart';
import "package:test/test.dart";
import 'package:xrandom/xrandom.dart';

void main() {

  int sumKeysRandomlyRead = 0;

  late Directory tempDir;
  late File tempFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
    tempFile = File(tempDir.path + "/temp");
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  tearDownAll(() {
    assert(sumKeysRandomlyRead > 10);
  });

  test('Files: one entry read', () {
    // writing
    writeBlobsSyncV2(tempFile, {
      "Key in UTF8: это ключ": [4, 5, 6, 7]
    });
    // reading
    final entries = readBlobsSyncV2(tempFile, (_) => Decision.readAndContinue).toList();
    expect(entries.length, 1);
    expect(entries[0].key, "Key in UTF8: это ключ");
    expect(entries[0].value, [4, 5, 6, 7]);
  });
  //return;

  test('Files: one entry skip', () {
    // writing
    writeBlobsSyncV2(tempFile, {
      "Key in UTF8: это ключ": [4, 5, 6, 7]
    });
    // reading
    final entries = readBlobsSyncV2(tempFile, (_) => Decision.skipAndContinue).toList();
    expect(entries.length, 0);
  });

  test('many entries, read some', () {
    // writing
    writeBlobsSyncV2(tempFile, {
      "a": [1, 2],
      "bb": [4, 5, 6],
      "ccc": [7],
      "dd": [8, 9],
    });
    // reading
    final entries = readBlobsSyncV2(tempFile,
            (key) => (key == 'bb' || key == 'dd') ? Decision.readAndContinue : Decision.skipAndContinue)
        .toList();
    expect(entries.length, 2);

    final bb = entries.firstWhere((e) => e.key == "bb");
    expect(bb.value, [4, 5, 6]);

    final dd = entries.firstWhere((e) => e.key == "dd");
    expect(dd.value, [8, 9]);
  });

  final random = Drandom();

  for (int i = 0; i < 100; ++i) {
    test('random test #$i', () {
      final sourceBlobs = <String, List<int>>{};

      // generating random number of random length blobs
      for (int i = random.nextInt(50); i > 0; --i) {
        String blobKey = "key${random.nextInt(99999)}";
        final blobBytes = List<int>.generate(random.nextInt(1024), (_) => random.nextInt(0x100));
        sourceBlobs[blobKey] = blobBytes;
      }

      writeBlobsSyncV2(tempFile, sourceBlobs);
      
      // READING MULTIPLE KEYS //

      // picking random keys
      final keysToRead = sourceBlobs.keys.toList()
        ..shuffle(random)
        ..take(sourceBlobs.length > 0 ? random.nextInt(sourceBlobs.length) : 0).toSet();

      final blobsFromFile = Map.fromEntries(
          readBlobsSyncV2(
              tempFile,
              (key) => keysToRead.contains(key) ? Decision.readAndContinue : Decision.skipAndContinue));
      
      sumKeysRandomlyRead += blobsFromFile.length;
      expect(blobsFromFile.length, keysToRead.length);
      for (final expectedKey in keysToRead) {
        // check the read data is the same as source
        expect(blobsFromFile[expectedKey], sourceBlobs[expectedKey]);
      }
      
      // READING SINGLE RANDOM KEYS // 
      
      for (final singleKey in keysToRead) {
        final blobsFromFile = Map.fromEntries(
            readBlobsSyncV2(
                tempFile,
                (k) => k == singleKey ? Decision.readAndStop : Decision.skipAndContinue));
        expect(blobsFromFile.length, 1);
        expect(blobsFromFile.keys.first, singleKey);
        expect(blobsFromFile.values.first, sourceBlobs[singleKey]);

      }
    });
  }
}
