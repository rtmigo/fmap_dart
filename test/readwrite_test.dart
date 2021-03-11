// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:disk_cache/src/10_readwrite.dart';
import "package:test/test.dart";


void main() {
  test('Files: saving and reading', () async {
    final theDir = Directory.systemTemp.createTempSync();
    final path = theDir.path + "/temp";
    // writing
    writeKeyAndDataSync(File(path), "c:/key/name/", [4, 5, 6, 7]);
    // reading
    expect(readKeySync(File(path)), "c:/key/name/");
    expect(readIfKeyMatchSync(File(path), "c:/key/name/"), [4, 5, 6, 7]);
    expect(readIfKeyMatchSync(File(path), "other"), null);
  });
}