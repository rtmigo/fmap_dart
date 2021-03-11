// SPDX-FileCopyrightText: (c) 2021 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause


import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:disk_cache/src/10_hashing.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';
import 'dart:io' show Platform;


void main() {
  test('MD5', () async {
    expect(stringToMd5("Don't panic"), "6a1e03f6a6dee59ef4d9f1b332e86b6d");
    expect(stringToMd5(""), "d41d8cd98f00b204e9800998ecf8427e");
  });
}
