import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';

import '00_common.dart';
import '10_file_removal.dart';
import '10_files.dart';
import '10_readwrite.dart';

abstract class FileMap extends MapBase<String, List<int>?> {

  final Directory directory;

  FileMap(this.directory);

  void compactSync({
    final int maxSizeBytes = JS_MAX_SAFE_INTEGER,
    final maxCount = JS_MAX_SAFE_INTEGER })
  {
    List<FileAndStat> files = <FileAndStat>[];

    List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(recursive: true);
    } on FileSystemException catch (e) {
      throw FileSystemException(
          "DiskCache failed to listSync directory $directory right after creation. "
              "osError: ${e.osError}.");
    }

    for (final entry in entries) {
      if (entry.path.endsWith(DIRTY_SUFFIX)) {
        deleteSyncCalm(File(entry.path));
        continue;
      }
      if (entry.path.endsWith(DATA_SUFFIX)) {
        final f = File(entry.path);
        files.add(FileAndStat(f));
      }
    }

    FileAndStat.deleteOldest(files, maxSumSize: maxSizeBytes, maxCount: maxCount,
        deleteFile: (file)=>this.deleteFile(file));
  }

  @protected
  void deleteFile(File file);

  Uint8List? readBytes(String key);
  bool delete(String key);
  File writeBytes(String key, List<int> data);

  @protected
  bool isFile(String path);

  @override
  Uint8List? operator [](Object? key) {
    return readBytes(key as String);
  }

  @override
  void operator []=(String key, List<int>? value) {
    if (value==null)
      this.delete(key);
    else
      writeBytes(key, value);
  }

  @override
  void clear() {
    this.directory.deleteSync(recursive: true); // todo test
  }

  @override
  Iterable<String> get keys sync* {
    for (final f in listSyncCalm(this.directory, recursive: true)) {
      if (this.isFile(f.path))
        yield readKeySync(File(f.path));
    }
  }

  @override
  Uint8List? remove(Object? key) {
    this.delete(key as String);
  }
}