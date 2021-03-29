// SPDX-FileCopyrightText: (c) 2021 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT


const JS_MAX_SAFE_INTEGER = 9007199254740991;
const DIRTY_SUFFIX = ".dirt";
const DATA_SUFFIX = ".kbl"; // "keyed blobs list"

class FileFormatError implements Exception {
  FileFormatError(this.message);
  final String message;
  @override
  String toString() {
    return this.message;
  }
}
