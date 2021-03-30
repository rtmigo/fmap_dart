import 'dart:typed_data';
import 'package:fmap/fmap.dart';
import 'package:path/path.dart' as pathlib;
import 'dart:io';

void main() {

  // let's place the cache in the temp directory
  String dirPath = pathlib.join(Directory.systemTemp.path, "myCache");

  // creating the cache
  final fmap = Fmap(Directory(dirPath));

  // reading bytes from cache
  Uint8List? myData = fmap["myKey"];

  print(myData); // on first start it's null

  // saving two bytes
  fmap["myKey"] = [0x23, 0x21];

  fmap["x"] = [0, -1, -2];
  print(fmap["x"]);

  // after restart diskCache["myKey"] will load the data
}