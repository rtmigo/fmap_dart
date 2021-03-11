import 'dart:convert';
import 'package:crypto/crypto.dart';

String stringToMd5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}
