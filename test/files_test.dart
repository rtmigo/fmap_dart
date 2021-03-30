// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:fmap/src/10_files.dart';
import 'package:path/path.dart' as path;
import "package:test/test.dart";

import 'helper.dart';

void main() {
  Directory tempDir = Directory("/tmp"); // will redefined

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
  });

  tearDown(() {
    deleteTempDir(tempDir);
  });

  test('listIfExists when does not exist', () async {
    final unexisting = Directory(path.join(tempDir.path, "unexisting"));
    expect(listSyncOrEmpty(unexisting), []);
  });

  test('listIfExists when exists', () async {
    File(path.join(tempDir.path, "a.txt")).writeAsStringSync(":)");
    File(path.join(tempDir.path, "b.txt")).writeAsStringSync("(:");

    expect(listSyncOrEmpty(tempDir).map((e) => path.basename(e.path)).toSet(), {'b.txt', 'a.txt'});
  });
}
