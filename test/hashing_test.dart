// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:math';

import 'package:fmap/src/10_hashing.dart';
import "package:test/test.dart";

import 'helper.dart';

void main() {
  test('MD5', () {
    expect(stringToMd5("Don't panic"), "6a1e03f6a6dee59ef4d9f1b332e86b6d");
    expect(stringToMd5(""), "d41d8cd98f00b204e9800998ecf8427e");
  });

  test('Bad hash func', () {
    final r = Random();
    final hashes = Set<String>();
    for (int i = 0; i < 100000; ++i) {
      final randomText = i.toString() + " " + r.nextInt(0xFFFFFFFF).toString();
      hashes.add(badHashFunc(randomText));
    }
    // although we made hashed for 100000 different strings, there
    // are only 16 unique hash values generated
    expect(hashes.length, 16);
  });
}
