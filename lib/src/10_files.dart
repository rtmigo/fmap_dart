// SPDX-FileCopyrightText: (c) 2020 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:file_errors/file_errors.dart';

/// If directory exists, returns the result of [Directory.listSync].
/// Otherwise returns empty list.
List<FileSystemEntity> listSyncOrEmpty(Directory d, {bool recursive = false}) {
  try {
    return d.listSync(recursive: recursive);
  } on FileSystemException catch (e) {
    if (e.isNoSuchFileOrDirectory) {
      return [];
    } else {
      rethrow;
    }
  }
}

void deleteDirIfEmptySync(Directory d) {
  try {
    d.deleteSync(recursive: false);
  } on FileSystemException catch (e) {
    if (!e.isDirectoryNotEmpty)
      print("WARNING: Got unexpected osError.errorCode=${e.osError?.errorCode} "
          "trying to remove directory.");
  }
}

bool deleteSyncCalm(File file) {
  try {
    file.deleteSync();
    return true;
  } on FileSystemException catch (e) {
    print("WARNING: Failed to delete $file: $e");
    return false;
  }
}
