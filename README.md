![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
[![Actions Status](https://github.com/rtmigo/dart_disk_cache/workflows/unittest/badge.svg?branch=master)](https://github.com/rtmigo/dart_disk_cache/actions)
![Generic badge](https://img.shields.io/badge/tested_on-Windows_|_MacOS_|_Ubuntu-blue.svg)

``` dart
import 'dart:typed_data';
import 'package:disk_cache/disk_cache.dart';
import 'package:path/path.dart' as pathlib;
import 'dart:io';

void main() async {
  // choosing the cache directory name
  String cacheDirPath = pathlib.join(Directory.systemTemp.path, "myCache");

  // creating the cache
  final diskCache = DiskCache(Directory(cacheDirPath));

  // reading bytes from cache
  Uint8List? firstBytes = await diskCache.readBytes("firstKey");
  Uint8List? secondBytes = await diskCache.readBytes("secondKey");

  // this will print [null] when started for the first time
  print("firstKey: $firstBytes");
  print("secondKey: $secondBytes");

  // storing values to cache
  diskCache.writeBytes("firstKey", [1, 2, 3]);
  diskCache.writeBytes("secondKey", [90, 60, 90]);

  // now the cache returns expected values
  assert (await diskCache.readBytes("firstKey") == [1, 2, 3]);
  assert (await diskCache.readBytes("secondKey") == [90, 60, 90]);

  // let's delete the second one
  await diskCache.delete("secondKey");
  // it's null again
  assert (await diskCache.readBytes("secondKey") == null);

  // if we restart the program, we'll see that "firstKey" still returns [1,2,3]
}
```