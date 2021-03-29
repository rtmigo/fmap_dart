// SPDX-FileCopyrightText: (c) 2021 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


import 'dart:io';

import 'package:disk_cache/src/10_readwrite_v3.dart';
import "package:test/test.dart";
import 'package:xrandom/xrandom.dart';

import 'helper.dart';

void main() {
  int sumKeysRandomlyRead = 0;

  late Directory tempDir;
  late File tempFile;
  late File otherTempFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
    tempFile = File(tempDir.path + "/temp");
    otherTempFile = File(tempDir.path + "/tempOther");
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  tearDownAll(() {
    assert(sumKeysRandomlyRead > 10);
  });

  test('One entry write & read', () {
    // WRITING

    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("Key in UTF8: это ключ", [4, 5, 6, 7]);
    } finally {
      writer.closeSync();
    }

    // READING
    expect(tempFile.existsSync(), true);
    expect(tempFile.statSync().size, 42);
    final reader = BlobsFileReader(tempFile);
    expect(reader.readKey(), "Key in UTF8: это ключ");
    expect(reader.readBlob(), [4, 5, 6, 7]);
    expect(reader.readKey(), null);
  });

  test('Three entries write & read', () {
    // WRITING

    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("one", [1, 2]);
      writer.write("two", []);
      writer.write("three", [3]);
    } finally {
      writer.closeSync();
    }

    // READING
    expect(tempFile.existsSync(), true);
    final reader = BlobsFileReader(tempFile);
    try {
      expect(reader.readKey(), "one");
      expect(reader.readBlob(), [1, 2]);
      expect(reader.readKey(), "two");
      expect(reader.readBlob(), []);
      expect(reader.readKey(), "three");
      expect(reader.readBlob(), [3]);
    } finally {
      reader.closeSync();
    }
  });

  test('Three entries skip two', () {
    // WRITING

    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("one", [1, 2]);
      writer.write("two", []);
      writer.write("three", [3, 4, 5]);
    } finally {
      writer.closeSync();
    }

    // READING
    expect(tempFile.existsSync(), true);
    final reader = BlobsFileReader(tempFile);
    try {
      expect(reader.readKey(), "one");
      reader.skipBlob();
      expect(reader.readKey(), "two");
      reader.skipBlob();
      expect(reader.readKey(), "three");
      expect(reader.readBlob(), [3, 4, 5]);
    } finally {
      reader.closeSync();
    }
  });

  test('Three entries write & read with state errors', () {
    // here we test that even after state errors the object
    // continues reading data as usual

    // WRITING

    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("one", [1, 2]);
      writer.write("two", []);
      writer.write("three", [3]);
    } finally {
      writer.closeSync();
    }

    // READING
    expect(tempFile.existsSync(), true);
    final reader = BlobsFileReader(tempFile);

    try {
      expect(() => reader.readBlob(), throwsStateError);
      expect(reader.readKey(), "one");

      expect(() => reader.readKey(), throwsStateError);
      expect(reader.readBlob(), [1, 2]);

      expect(() => reader.readBlob(), throwsStateError);
      expect(() => reader.skipBlob(), throwsStateError);
      expect(reader.readKey(), "two");

      expect(() => reader.readKey(), throwsStateError);
      expect(() => reader.readKey(), throwsStateError);
      reader.skipBlob();

      expect(() => reader.readBlob(), throwsStateError);
      expect(() => reader.skipBlob(), throwsStateError);
      expect(() => reader.readBlob(), throwsStateError);
      expect(() => reader.skipBlob(), throwsStateError);
      expect(reader.readKey(), "three");

      expect(() => reader.readKey(), throwsStateError);
      expect(reader.readBlob(), [3]);

      expect(reader.readKey(), null);
      expect(() => reader.readBlob(), throwsStateError);

      expect(reader.readKey(), null);
      expect(() => reader.readBlob(), throwsStateError);
      expect(() => reader.readBlob(), throwsStateError);
      expect(reader.readKey(), null);
    } finally {
      reader.closeSync();
    }
  });

  test('mustExist=true', () {
    expect(tempFile.existsSync(), false);
    expect(() => BlobsFileReader(tempFile), throwsA(isA<FileSystemException>()));
  });

  test('mustExist=false', () {
    expect(tempFile.existsSync(), false);
    final reader = BlobsFileReader(tempFile, mustExist: false);
    expect(reader.readKey(), null);
    expect(reader.readKey(), null);
  });

  test("replace", () {
    // WRITING
    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("one", [1, 2]);
      writer.write("two", []);
      writer.write("three", [3]);
    } finally {
      writer.closeSync();
    }

    // REPLACING
    Replace(tempFile, otherTempFile, "two", [1, 50, 10]);

    // READING
    final reader = BlobsFileReader(otherTempFile);
    try {
      expect(reader.readKey(), "two");
      expect(reader.readBlob(), [1, 50, 10]);

      expect(reader.readKey(), "one");
      expect(reader.readBlob(), [1, 2]);
      expect(reader.readKey(), "three");
      expect(reader.readBlob(), [3]);
    } finally {
      reader.closeSync();
    }
  });

  test("delete", () {
    // WRITING
    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    try {
      writer.write("one", [1, 2]);
      writer.write("two", [100, 101]);
      writer.write("three", [3]);
    } finally {
      writer.closeSync();
    }

    // REPLACING
    Replace(tempFile, otherTempFile, "two", null);

    // READING
    final reader = BlobsFileReader(otherTempFile);
    try {
      expect(reader.readKey(), "one");
      expect(reader.readBlob(), [1, 2]);
      expect(reader.readKey(), "three");
      expect(reader.readBlob(), [3]);
    } finally {
      reader.closeSync();
    }
  });

  test("write zero entries", () {
    expect(tempFile.existsSync(), false);
    final writer = BlobsFileWriter(tempFile);
    writer.closeSync();
    expect(tempFile.existsSync(), false);
  });

  group('replaceBlobSync', () {

    test("replace with nothing", () {
      // WRITING
      expect(tempFile.existsSync(), false);
      final writer = BlobsFileWriter(tempFile);
      try {
        writer.write("one", [1, 2]);
      } finally {
        writer.closeSync();
      }

      // REPLACING
      Replace(tempFile, otherTempFile, "one", null);

      expect(otherTempFile.existsSync(), false);
    });

    test("replace when no source", () {
      // there is no source file
      expect(tempFile.existsSync(), false);
      // we we are "replacing" an entry in non-existent file
      Replace(tempFile, otherTempFile, "one", [1,2,3], mustExist: false);
      // new file must be created
      expect(otherTempFile.existsSync(), true);
    });
  });

  group("random tests", () {
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

        BlobsFileWriter bfw = BlobsFileWriter(tempFile);
        try {
          for (final entry in sourceBlobs.entries) {
            bfw.write(entry.key, entry.value);
          }
        } finally {
          bfw.closeSync();
        }

        // READING MULTIPLE KEYS //

        // picking random keys
        final keysToRead = sourceBlobs.keys.toList()
          ..shuffle(random)
          ..take(sourceBlobs.length > 0 ? random.nextInt(sourceBlobs.length) : 0).toSet();

        int foundCount = 0;

        BlobsFileReader reader = BlobsFileReader(tempFile, mustExist: false);
        try {
          for (var key = reader.readKey(); key != null; key = reader.readKey()) {
            if (keysToRead.contains(key)) {
              expect(reader.readBlob(), sourceBlobs[key]);
              foundCount++;
              sumKeysRandomlyRead++;
            } else {
              reader.skipBlob();
            }
          }
          expect(foundCount, keysToRead.length);
        } finally {
          reader.closeSync();
        }
      });
    }
  });
}
