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