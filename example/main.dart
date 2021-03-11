import 'dart:typed_data';
import 'package:disk_cache/disk_cache.dart';
import 'package:path/path.dart' as pathlib;
import 'dart:io';

void main() {
  // choosing the cache directory name
  String cacheDirPath = pathlib.join(Directory.systemTemp.path, "myCache");

  // creating the map
  final diskCache = BytesMap(Directory(cacheDirPath));

  // reading bytes from cache
  Uint8List? firstBytes = diskCache.readBytes("firstKey");
  Uint8List? secondBytes = diskCache.readBytes("secondKey");

  // this will print [null] when started for the first time
  print("firstKey: $firstBytes");
  print("secondKey: $secondBytes");

  // storing values to cache
  diskCache.writeBytes("firstKey", [1, 2, 3]);
  diskCache.writeBytes("secondKey", [90, 60, 90]);

  // now the cache returns expected values
  assert (diskCache.readBytes("firstKey") == [1, 2, 3]);
  assert (diskCache.readBytes("secondKey") == [90, 60, 90]);

  // let's delete the second item
  diskCache.delete("secondKey");
  // it's null again
  assert (diskCache.readBytes("secondKey") == null);

  // if we restart the program, we'll see that "firstKey" still returns [1,2,3]
}