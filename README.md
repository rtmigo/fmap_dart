[![Pub Package](https://img.shields.io/pub/v/fmap.svg)](https://pub.dev/packages/fmap)
[![pub points](https://badges.bar/fmap/pub%20points)](https://pub.dev/fmap/tabular/score)
![Generic badge](https://img.shields.io/badge/tested_on-Windows_|_MacOS_|_Ubuntu-blue.svg)



# [fmap](https://github.com/rtmigo/fmap)

`Fmap` is a file-based key-value collection. Good for caching and blob storage.

``` dart
var fmap = Fmap(directory);

fmap['keyA'] = 'my string';         // saved string into a file
fmap['keyB'] = 777;                 // saved int into a file
fmap['keyC'] = [0x12, 0x34, 0x56];  // saved three-bytes into a file

print(fmap['keyA']); // read from file
```

`Fmap` implements a `Map`, so it can be used the same way.

``` dart
print('Count of items: ${fmap.length}');

for (var entry in fmap.entries) {
    print('Item ${entry.key}: ${entry.value}'); 
}
```

## Creating

For permanent data storage

``` dart
var fmap = Fmap(Directory('/path/to/mydata'));
```

To cache temporary data in the system temporary directory

``` dart
var fmap = Fmap.temp(); // will be placed into <temp>/fmap dir
```

To cache temporary data in a specific subdirectory of the system temporary directory

``` dart
var blobs = Fmap.temp(subdir: 'blobsCache'); // <temp>/blobsCache
var texts = Fmap.temp(subdir: 'textsCache'); // <temp>/textsCache
```

If all the storage items have the same type, you can specify it with generics

``` dart
var strings1 = Fmap<String>(directory);
var strings2 = Fmap.temp<String>();
```


## Types

The object is intended primarily for storing values of type `String` 
and `Uint8List` (blobs).

``` dart
var objects = Fmap(directory);
fmap['myJson'] = httpGet('http://somewhere'); // String
fmap['blob'] = myFile.readAsBytesSync(); // Uint8List
```

Any `List<int>` will also be treated as list of bytes.

``` dart
fmap['blob2'] = [0x12, 0x34, 0x56];
fmap['blob3'] = utf8.encode('my string'); // List<int>
```

When saving, each `int` inside a list will be truncated to the range 0..255.

``` dart
fmap['blob3'] = [1, 10, -1, 777]; // saves 1, 10, 255, 9 
```

In addition to strings and bytes, you can also store simple values of the 
`int`, `double`, and `bool` types. But keep in mind that each value is saved 
in a separate file. Therefore, storing a lot of small values like `int` may 
not be the most efficient approach.

``` dart
fmap['int'] = 5;
fmap['double'] = 5.0; 
fmap['bool'] = true;
```

## Purging

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the freshest 16 Mb
fmap.purge(16*1024*1024);
```

Which elements are removed depends on the `policy` argument passed to the 
constructor.

``` dart
final fmap = Fmap(dir, policy: Policy.fifo);
```

Two policies are supported: FIFO and LRU. By default, this is FIFO.

If you want the `purge` method to purge storage with LRU policy, you must
not only create `Fmap(policy: Policy.lru)` before purging but always
create the object this way. It will force `Fmap` to update the last-used 
timestamps every time an entry is read.

When you do not specify this argument, the timestamps are only updated on 
writes, but not on reads.




