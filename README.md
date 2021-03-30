![Generic badge](https://img.shields.io/badge/status-it_works-ok.svg)
[![Pub Package](https://img.shields.io/pub/v/fmap.svg)](https://pub.dev/packages/fmap)
![Generic badge](https://img.shields.io/badge/testing_on-Windows_|_MacOS_|_Ubuntu-blue.svg)
[![pub points](https://badges.bar/fmap/pub%20points)](https://pub.dev/fmap/tabular/score)



# [fmap](https://github.com/rtmigo/fmap)

Dart library with a `Map` implementation that stores its elements in files.

Can be used as a **cache** or **persistent** key-value **storage**.

``` dart
var fmap = Fmap(directory);

fmap['keyA'] = 'my string';         // saved string into a file
fmap['keyB'] = 777;                 // saved int into a file
fmap['keyC'] = [0x12, 0x34, 0x56];  // saved three-bytes into a file

print(fmap['keyA']); // read from file
```

This object implements `Map`, so it can be used in the same way.

``` dart
Map fmap = Fmap(directory);

print('Count of items: ${fmap.length}');

for (var entry in fmap.entries) {
    print('Item ${entry.name} ${entry.value}'); 
}
```

Each item of the storage is kept in a separate file. This makes the storage 
most efficient when large objects, such as strings or blobs.

## Basic types

The storage can store such basic types as `String`, `int`, `double` and `bool`.


They can be read as dynamic types

``` dart
var objects = Fmap(directory);
var myJsonString = fmap['json']; // a dynamic type
var myIntValue = fmap['number']; // a dynamic type
```

As with a regular `Map` class, an `Fmap` object can be created with 
a generic type

``` dart
var strings = Fmap<String>(directory);
var myJsonString = strings['json'];  // definitely a string 

// but now only strings can be read or written
var myIntValue = strings['number'];  // throws exception
```

## Blobs (binary data)

All values with type derived from `List<int>` are treated as lists of bytes.
This allows you to efficiently save and load **blobs** both in the `Uint8List` 
format and in the more basic `List`. When saving, each `int` will be truncated to 
the range 0..255.

``` dart
fmap['blob1'] = [0x12, 0x34, 0x56];
fmap['blob2'] = myFile.readAsBytesSync();
```

When reading, we are always getting an `Uint8List`
``` dart  
Uint8List myBlob = fmap['blob1'];
```





## Purge

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the freshest 16 Mb
fmap.purgeSync(16*1024*1024);
```

Which elements are removed depends on the `policy` argument passed to the 
constructor.

``` dart
final fmap = Fmap(dir, policy: Policy.fifo);
```

Two policies are supported: FIFO and LRU. By default, this is FIFO.

If you want the `purgeSync` method to purge storage with LRU policy, you must
not only create `Fmap(policy: Policy.lru)` before purging, but always
create the object this way. It will cause `Fmap` to update the the last-used 
timestamps every time an item is read.

When you do not specify this argument, the timestamps are only updates on 
writes, but not on reads. The order of the elements becomes closer to the FIFO.




