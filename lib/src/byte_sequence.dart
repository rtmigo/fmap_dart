// SPDX-FileCopyrightText: (c) 2021 Artёm IG <github.com/rtmigo>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

class ByteSequence {
  ByteSequence(this.data);
  final ByteData data;
  int position = 0;

  void writeUint8(int x) {
    data.setUint8(position, x);
    position += 1;
  }

  void writeUint16(int x) {
    data.setUint16(position, x);
    position += 2;
  }

  void writeUint32(int x) {
    data.setUint32(position, x);
    position += 4;
  }

  int readUint8() {
    final r = data.getUint8(position);
    position += 1;
    return r;
  }

  int readUint16() {
    final r = data.getUint16(position);
    position += 2;
    return r;
  }

  int readUint32() {
    final r = data.getUint32(position);
    position += 4;
    return r;
  }

  Uint8List asInt8List() => this.data.buffer.asUint8List();
}
