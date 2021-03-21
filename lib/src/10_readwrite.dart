// SPDX-FileCopyrightText: (c) 2020 Art Galkin <ortemeo@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

@deprecated
void writeKeyAndDataSync(File targetFile, String key, List<int> data) {
  RandomAccessFile raf = targetFile.openSync(mode: FileMode.write);

  try {
    final keyAsBytes = utf8.encode(key);

    // сохраняю номер версии
    raf.writeFromSync([1]);

    // сохраняю длину ключа
    final keyLenByteData = ByteData(2);
    keyLenByteData.setInt16(0, keyAsBytes.length);
    raf.writeFromSync(keyLenByteData.buffer.asInt8List());

    // сохраняю ключ
    raf.writeFromSync(keyAsBytes);

    // сохраняю данные
    raf.writeFromSync(data);
  } finally {
    raf.closeSync();
  }
}

@deprecated
Uint8List? readIfKeyMatchSync(File file, String key) {
  RandomAccessFile raf = file.openSync(mode: FileMode.read);

  try {
    final versionNum = raf.readSync(1)[0];
    if (versionNum > 1) throw Exception("Unsupported version"); // todo custom exceptions

    final keyBytesLen = ByteData.sublistView(raf.readSync(2)).getInt16(0);

    final keyAsBytes = raf.readSync(keyBytesLen); // utf8.encode(key);
    final keyFromFile = utf8.decode(keyAsBytes);

    if (keyFromFile != key)
      return null;

    final bytes = <int>[];
    const CHUNK_SIZE = 128 * 1024;

    while (true) {
      final chunk = raf.readSync(CHUNK_SIZE);
      bytes.addAll(chunk);
      if (chunk.length < CHUNK_SIZE) break;
    }

    return Uint8List.fromList(bytes);
  } finally {
    raf.closeSync();
  }
}

@deprecated
String readKeySync(File file) {
  RandomAccessFile raf = file.openSync(mode: FileMode.read);
  try {
    final versionNum = raf.readSync(1)[0];
    if (versionNum > 1)
      throw Exception("Unsupported version");
    final keyBytesLen = ByteData.sublistView(raf.readSync(2)).getInt16(0);
    final keyAsBytes = raf.readSync(keyBytesLen); // utf8.encode(key);
    return utf8.decode(keyAsBytes);
  } finally {
    raf.closeSync();
  }
}
