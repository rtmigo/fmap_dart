import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';

import '00_common.dart';
import '10_file_removal.dart';
import '10_files.dart';

abstract class UniStorage extends MapBase<String, List<int>?> {

  final Directory directory;

  UniStorage(this.directory);

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
}