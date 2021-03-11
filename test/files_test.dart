// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:disk_cache/src/10_files.dart';
import 'package:disk_cache/src/10_hashing.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';
import 'dart:io' show Platform;
import 'package:path/path.dart' as path;

void main() {

  Directory tempDir = Directory("/tmp"); // will redefined

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('listIfExists when does not exist', () async {
    final unexisting = Directory(path.join(tempDir.path, "unexisting"));
    expect(listCalm(unexisting), []);
  });

  test('listIfExists when exists', () async {

    File(path.join(tempDir.path, "a.txt")).writeAsStringSync(":)");
    File(path.join(tempDir.path, "b.txt")).writeAsStringSync("(:");

    expect(listCalm(tempDir).map((e) => path.basename(e.path)).toSet(), {'b.txt', 'a.txt'});
  });

}
