// SPDX-FileCopyrightText: (c) 2020 Artёm I.G. <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:io';

import '00_common.dart';


const _DEBUG_LOGGING = false;

extension DateTimeCmp on DateTime {
  bool isBeforeOrSame(DateTime b) => this.isBefore(b) || this.isAtSameMomentAs(b);
  bool isAfterOrSame(DateTime b) => this.isAfter(b) || this.isAtSameMomentAs(b);
}


class FileAndStat {
  FileAndStat(this.file) {
    if (!this.file.isAbsolute) throw ArgumentError.value(this.file);
  }

  final File file;

  FileStat get stat {
    if (_stat == null) _stat = file.statSync();
    return _stat!;
  }

  set stat(FileStat x) {
    this._stat = x;
  }

  FileStat? _stat;

  static void sortByLastModifiedDesc(List<FileAndStat> files) {
    if (files.length >= 2) {
      files.sort((FileAndStat a, FileAndStat b) => -a.stat.modified.compareTo(b.stat.modified));
      assert(files[0].stat.modified.isAfterOrSame(files[1].stat.modified));
    }
  }

  static int sumSize(Iterable<FileAndStat> files) {
    return files.fold(0, (prev, curr) => prev + curr.stat.size);
  }

  static void deleteOldest(List<FileAndStat> files,
      {int maxSumSize = JS_MAX_SAFE_INTEGER,
        int maxCount = JS_MAX_SAFE_INTEGER,
        void Function(File file)? deleteFile}) {

    files = files.toList();

    FileAndStat.sortByLastModifiedDesc(files); // now they are sorted by time
    int sumSize = FileAndStat.sumSize(files);

    if (_DEBUG_LOGGING)
    {
      print("ALL THE FILE LMTS");
      for (var f in files)
        print("- "+f.file.lastModifiedSync().toString());
    }

    DateTime? prevLastModified;

    //iterating files from old to new
    for (int i = files.length - 1;
         i >= 0 && (sumSize > maxSumSize || files.length > maxCount);
         --i)
    {
      var item = files[i];
      // assert that the files are sorted from old to new
      assert(prevLastModified == null || item.stat.modified.isAfterOrSame(prevLastModified));
      if (_DEBUG_LOGGING)
        print("Deleting file ${item.file.path} LMT ${item.file.lastModifiedSync()}");

      if (deleteFile != null)
        deleteFile(item.file);
      else
        item.file.deleteSync();

      files.removeAt(i);
      assert(files.length == i);
      sumSize -= item.stat.size;
    }
  }
}