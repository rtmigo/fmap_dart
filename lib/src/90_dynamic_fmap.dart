import 'dart:collection';

import 'package:disk_cache/disk_cache.dart';

class Fmap<T> extends MapBase<String, T> {
  Fmap(directory, {bool updateTimestampsOnRead = false}): _inner = BytesFmap(directory, updateTimestampsOnRead: updateTimestampsOnRead);

  BytesFmap _inner;

  @override
  T? operator [](Object? key) {
    // TODO: implement []
    throw UnimplementedError();
  }

  @override
  void operator []=(String key, T value) {
    // TODO: implement []=
  }

  @override
  void clear() => this._inner.clear();

  @override
  Iterable<String> get keys => this._inner.keys;

  @override
  T? remove(Object? key) {
    this._inner.remove(key);
    // TODO: implement remove
    throw UnimplementedError();
  }
}
