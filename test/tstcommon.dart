// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:disk_cache/src/80_unistor.dart';
import "package:test/test.dart";
import 'package:disk_cache/disk_cache.dart';
import 'dart:io' show Platform;



String badHashFunc(String data) {
  // returns only 16 possible hash values.
  // So if we have more than 16 items, there will be hash collisions.
  // Bad for production, but good for testing
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);
  String result = digest.bytes[0].toRadixString(16)[0];
  assert(result.length == 1);
  return result;
}

Directory? findEmptySubdir(Directory d) {
  for (final fsEntry in d.listSync(recursive: true))
    if (fsEntry is Directory && fsEntry.listSync().length == 0)
      return fsEntry;
  return null;
}

int countFiles(Directory dir) {
  return dir.listSync(recursive: true).where((e) => FileSystemEntity.isFileSync(e.path)).length;
}

/// Removes random files or directories from the [dir].
void deleteRandomItems(Directory dir, int count, FileSystemEntityType type, {emptyOk=false, errorOk=false}) {
  List<FileSystemEntity> files = <FileSystemEntity>[];
  for (final entry in dir.listSync(recursive: true))
    if (FileSystemEntity.typeSync(entry.path) == type) files.add(entry);
  if (!emptyOk)
    assert(files.length >= count);
  files.shuffle();
  for (final f in files.take(count))
    try {
      f.deleteSync(recursive: true);
    }
    on FileSystemException catch (_) {
      if (!errorOk)
        rethrow;
    }
}

class FilledWithData {

  FilledWithData(BytesStore theCache, {lmtMatters = false}) {
    final longerDelays = lmtMatters; // && Platform.isWindows;

    //theCache.keyToHash = badHashFunc;

    Set<String> allKeys = Set<String>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      allKeys.add(key);

      if (i != 0) {
        if (longerDelays && (i == 1 || i == 99)) {
          // making a longer pause between 0..1 and 98..99, to be sure that the LMT of first file
          // is minimal and LMT of the last one is maximal.
          //
          // Last-modification times on FAT are rounded to nearest 2 seconds.
          //
          // https://stackoverflow.com/a/11547476
          // File time stamps on FAT drives are rounded to the nearest two seconds (even number)
          // when the file is written to the drive. The file time stamps on NTFS drives are rounded
          // to the nearest 100 nanoseconds when the file is written to the drive. Consequently,
          // file time stamps on FAT drives always end with an even number of seconds, while file
          // time stamps on NTFS drives can end with either even or odd number of seconds.
          //
          // So we make  that first and last files distant in time from the others.

          Future.delayed(Duration(milliseconds: 2050));
        } else
          Future.delayed(Duration(milliseconds: 25));
      }

      theCache.writeBytes(key, List.filled(1024, 0));
    }

    this.cache = theCache;
    this.keys = allKeys;
  }


  late BytesStore cache;
  late Set<String> keys;

  Future<int> countItemsInCache() async {
    //return countFiles()
    int countLeft = 0; //
    for (var k in this.keys) if (await this.cache.readBytes(k, updateLastModified: false) != null) countLeft++;
    return countLeft;
  }
}