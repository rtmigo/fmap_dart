![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
[![Actions Status](https://github.com/rtmigo/dart_disk_cache/workflows/unittest/badge.svg?branch=master)](https://github.com/rtmigo/dart_disk_cache/actions)
![Generic badge](https://img.shields.io/badge/tested_on-Windows_|_MacOS_|_Ubuntu-blue.svg)

# disk_cache

The `DiskCache` relies on the file system to store the data. Each item actually stored in a separate
file. So there is no central index, that can be broken. It's just named files.

Even if the OS decides to clear the temporary directories, and deletes half of the `DiskCache`
files, it's not a big deal.

File names are created based on hashes from string keys. This could hypothetically lead to hash
collisions. If, by a rare miracle, the program encounters a collision, it will not affect the cache. 

# Example

``` dart
import 'dart:typed_data';
import 'package:disk_cache/disk_cache.dart';
import 'package:path/path.dart' as pathlib;
import 'dart:io';

void main() {
  
  // let's place the cache in the temp directory
  String dirPath = pathlib.join(Directory.systemTemp.path, "myCache");

  // creating the cache
  final diskCache = BytesCache(Directory(dirPath));

  // reading bytes from cache
  Uint8List? myData = diskCache["myKey"];

  print(myData); // on first start it's null

  // saving two bytes
  diskCache["myKey"] = [0x23, 0x21];

  // after restart diskCache["myKey"] will load the data
}
```