// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

bool isDirectoryNotEmptyException(FileSystemException e)
{
  // https://www-numi.fnal.gov/offline_software/srt_public_context/WebDocs/Errors/unix_system_errors.html
  if (Platform.isLinux && e.osError?.errorCode == 39)
    return true;

  // there is no evident source of macOS errors in 2021 O_O
  if (Platform.isMacOS && e.osError?.errorCode == 66)
    return true;

  return false;
}

void deleteDirIfEmptySync(Directory d) {
  try {
    d.deleteSync(recursive: false);
  } on FileSystemException catch (e) {

    if (!isDirectoryNotEmptyException(e))
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

Future<void> setTimestampToNow(File file) async {
  // since the cache is located in a temporary directory,
  // any file there can be deleted at any time
  try {
    file.setLastModifiedSync(DateTime.now());
  } on FileSystemException catch (e, _) {
    print("WARNING: Cannot set timestamp to file $file: $e");
  }
}