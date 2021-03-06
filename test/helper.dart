// SPDX-FileCopyrightText: (c) 2020 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:errno/errno.dart';
import 'package:file_errors/file_errors.dart';
import 'package:fmap/fmap.dart';
import 'package:fmap/src/20_readwrite_v3.dart';

void deleteTempDir(Directory d) {
  try {
    if (d.existsSync()) {
      d.deleteSync(recursive: true);
    }
  } on FileSystemException catch (exc) {
    if (!exc.isWindowsError(WindowsErrors.sharingViolation)) rethrow;
  }
}

String badHashFunc(String data) {
  // returns only 16 possible hash values.
  // This leads to frequent collisions.
  // Bad for production, good for testing
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);
  String result = digest.bytes[0].toRadixString(16)[0];
  assert(result.length == 1);
  return result;
}

Directory? findEmptySubdirectory(Directory d) {
  for (final fsEntry in d.listSync(recursive: true))
    if (fsEntry is Directory && fsEntry.listSync().length == 0) return fsEntry;
  return null;
}

int countFiles(Directory dir) {
  return dir.listSync(recursive: true).where((e) => FileSystemEntity.isFileSync(e.path)).length;
}

int averageFileSize(Directory dir) {
  int sum = 0;
  int count = 0;
  for (var fse in dir.listSync(recursive: true))
    if (FileSystemEntity.isFileSync(fse.path)) {
      sum += File(fse.path).statSync().size;
      count++;
    }
  return (sum / count).round();
}

int sumFilesSize(Directory dir) {
  int sum = 0;
  for (var fse in dir.listSync(recursive: true))
    if (FileSystemEntity.isFileSync(fse.path)) {
      sum += File(fse.path).statSync().size;
    }
  return sum;
}

/// Removes random files or directories from the [dir].
void deleteRandomItems(Directory dir, int count, FileSystemEntityType type,
    {emptyOk = false, errorOk = false}) {
  List<FileSystemEntity> files = <FileSystemEntity>[];
  for (final entry in dir.listSync(recursive: true))
    if (FileSystemEntity.typeSync(entry.path) == type) files.add(entry);
  if (!emptyOk) assert(files.length >= count);
  files.shuffle();
  for (final f in files.take(count))
    try {
      f.deleteSync(recursive: true);
    } on FileSystemException catch (_) {
      if (!errorOk) rethrow;
    }
}

// we don't want the first and last added chronologically to be also
// first and last when alphabetically sorted. So we will "hide" them between
// other keys
const KEY_EARLIEST = "5_first";
const KEY_LATEST = "10_first";

/// Fills the map with [n] blobs named `[KEY_EARLIEST, "3", "20", "6" ... KEY_LATEST]`.
Future<void> populate(Fmap theCache, {lmtMatters = false, int n = 100, int sizeEach = 1024}) async {
  List<String> allKeys = <String>[];

  // last-modification times on FAT are rounded to nearest 2 seconds
  final smallDelay = () => Future.delayed(Duration(milliseconds: 25));
  final longDelay = () => Future.delayed(Duration(milliseconds: lmtMatters ? 2050 : 25));

  theCache.writeSync(KEY_EARLIEST, TypedBlob(0, List.filled(1024, 5)));
  allKeys.add(KEY_EARLIEST);

  await longDelay();

  final indexesInRandomOrder = <int>[];
  for (int i = 0; i < n - 2; ++i) indexesInRandomOrder.add(i);
  indexesInRandomOrder.shuffle();

  for (int i in indexesInRandomOrder) {
    final key = i.toString();
    allKeys.add(key);
    theCache.writeSync(key, TypedBlob(0, List.filled(1024, i)));
    await smallDelay();
  }

  await longDelay();
  theCache.writeSync(KEY_LATEST, TypedBlob(0, List.filled(1024, 5)));
  allKeys.add(KEY_LATEST);

  assert(allKeys.length == n);
  assert(allKeys.length == allKeys.toSet().length); // all keys we added are unique
  assert(allKeys.contains(KEY_EARLIEST));
  assert(allKeys.contains(KEY_LATEST));
  allKeys.sort();
  assert(allKeys.first != KEY_EARLIEST); // keys that were first/last chronologically
  assert(allKeys.last != KEY_LATEST); // a not first/last alphabetically
}
