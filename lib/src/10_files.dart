// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

// TODO use file errors


// also tried [ErrorCodes](https://git.io/JqnbR) but their codes for Windows
// (as for 2021-03) are totally different from
// (https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-)
//
// class _WindowsCodes { ...
//   final int esrch = 3;       // WTF is that? WinAPI uses 3 (0x3) for ERROR_PATH_NOT_FOUND,
//                              // while ESRCH is for "no such process"...
//   final int enotempty = 41;  // Must be 145 etc.
// }

bool isFileNotFoundException(FileSystemException e) {
  if (Platform.isWindows && e.osError?.errorCode == WINDOWS_ERROR_PATH_NOT_FOUND)
    return true;
  if ((Platform.isMacOS||Platform.isIOS) && e.osError?.errorCode == MACOS_NO_SUCH_FILE)
    return true;
  // assuming we're on linux-like system
  if (e.osError?.errorCode==LINUX_ENOENT)
    return true;
  return false;
}

const int LINUX_ENOTEMPTY = 39;
const int LINUX_ENOENT = 2;

// there is no official list of macOS errors for 2021.
// I have to catch them in the woods
const int MACOS_NOT_EMPTY = 66;
const int MACOS_NO_SUCH_FILE = LINUX_ENOENT;

const int WINDOWS_DIR_NOT_EMPTY = 145; // 0x91
const int WINDOWS_ERROR_PATH_NOT_FOUND = 3; // 0x3

/// If directory exists, returns the result of [Directory.listSync]. 
/// Otherwise returns empty list.
List<FileSystemEntity> listSyncOrEmpty(Directory d, {bool recursive = false}) {
  try {
    return d.listSync(recursive: recursive);
  }
  on FileSystemException catch (e) {

    if (Platform.isWindows && e.osError?.errorCode == WINDOWS_ERROR_PATH_NOT_FOUND)
      return [];
    if ((Platform.isMacOS||Platform.isIOS) && e.osError?.errorCode == MACOS_NO_SUCH_FILE)
      return [];
    // assuming we're on a kind of linux
    if (e.osError?.errorCode==LINUX_ENOENT)
      return [];

    rethrow;
  }
}

bool isDirectoryNotEmptyException(FileSystemException e)
{
  if (Platform.isWindows && e.osError?.errorCode == WINDOWS_DIR_NOT_EMPTY)
    return true;

  if ((Platform.isMacOS||Platform.isIOS) && e.osError?.errorCode == MACOS_NOT_EMPTY)
    return true;

  // assuming we're on a kind of linux
  return e.osError?.errorCode == LINUX_ENOTEMPTY;
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

