[![Pub Package](https://img.shields.io/pub/v/fmap.svg)](https://pub.dev/packages/fmap)
[![pub points](https://badges.bar/fmap/pub%20points)](https://pub.dev/fmap/tabular/score)
![Generic badge](https://img.shields.io/badge/tested_on-Windows_|_MacOS_|_Ubuntu-blue.svg)



# [fmap](https://github.com/rtmigo/fmap)

Easy-to-use approach to caching or persistent blob storage. Key-value 
collection stored on the filesystem. 

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
var fmap = Fmap(Directory('/path/to/my_precious_data'));
```

To cache data in the system temporary directory

``` dart
var fmap = Fmap.temp(); // will be placed into {temp}/fmap dir
```

To cache data in a specific subdirectory of the system temporary directory

``` dart
var images = Fmap.temp(subdir: 'images_cache'); // {temp}/images_cache
var jsons  = Fmap.temp(subdir: 'jsons_cache');  // {temp}/jsons_cache
```

If all the storage items have the same type, you can set the type with generics

``` dart
var strings1 = Fmap<String>(directory);
var strings2 = Fmap.temp<String>();
```


## Types

The collection allows you to store only values of certain types. 
Supported types are `String`, `List<int>`, `int`, `double` and `bool`.

``` dart
var fmap = Fmap(directory);
fmap['string'] = '^_^';
fmap['int'] = 5;
fmap['double'] = 5.0; 
fmap['bool'] = true;
```

Any `List<int>` is treated as list of bytes.

``` dart
fmap['blob1'] = [0x12, 0x34, 0x56]; // List<int>
fmap['blob2'] = utf8.encode('my string'); // List<int>
fmap['blob3'] = myFile.readAsBytesSync(); // Uint8List implements List<int> 
```

Since numbers are bytes, each `int` inside a list is truncated to the range 0..255.

``` dart
fmap['blob4'] = [1, 10, -1, 777]; // saves 1, 10, 255, 9 
```

Keep in mind that each entry is saved in a separate file. Therefore, storing a lot of atomic values like `double` 
associated  with different keys may not be very practical. Conversely, saving large objects such as `String`s or `List<int>` is efficient. It's almost like writing directly to files, but without restrictions on key names.



## Purging

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the newest 16 megabytes
fmap.purge(16*1024*1024);
```

Which elements are removed depends on the `policy` argument passed to the 
constructor.

``` dart
var fmap = Fmap(dir, policy: Policy.fifo);
```

Two policies are supported: FIFO and LRU. By default, this is FIFO.

If you want the `purge` method to purge storage with LRU policy, you must
not only create `Fmap(policy: Policy.lru)` before purging but always
create the object this way. It will force `Fmap` to update the last-used 
timestamps every time an entry is read.

When you do not specify this argument, the timestamps are only updated on 
writes, but not on reads.

## Compatibility

The library is unit-tested on Linux, Windows and MacOS. Mobile systems such as 
Android and iOS have the same kernels as their desktop relatives.





