const JS_MAX_SAFE_INTEGER = 9007199254740991;
const DIRTY_SUFFIX = ".dirt";
const DATA_SUFFIX = ".dat";

class FileFormatError implements Exception {
  FileFormatError(this.message);
  final String message;
  @override
  String toString() {
    return this.message;
  }
}
