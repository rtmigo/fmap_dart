// import 'dart:collection';
// import 'dart:typed_data';
//
// import 'package:disk_cache/disk_cache.dart';
//
// class Fmap<T> extends MapBase<String, T> {
//   Fmap(directory, {bool updateTimestampsOnRead = false}): _inner = BytesFmap(directory, updateTimestampsOnRead: updateTimestampsOnRead);
//
//   BytesFmap _inner;
//
//   @override
//   T? operator [](Object? key) {
//     // TODO: implement []
//     throw UnimplementedError();
//   }
//
//   @override
//   void operator []=(String key, T value) {
//     // TODO: implement []=
//   }
//
//   @override
//   void clear() => this._inner.clear();
//
//   @override
//   Iterable<String> get keys => this._inner.keys;
//
//   T _deserialize(Uint8List data) {
//
//   }
//
//   @override
//   T? remove(Object? key) {
//     final oldData = this._inner.remove(key);
//     return (oldData!=null) ? _deserialize(oldData) : null;
//   }
// }
