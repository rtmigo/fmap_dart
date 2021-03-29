![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
![Generic badge](https://img.shields.io/badge/testing_on-Windows_|_MacOS_|_Ubuntu-blue.svg)


# [fmap](https://github.com/rtmigo/fmap)

А `Map` stored in the file system. Equally suitable for caching and persistent 
storage.

``` dart
Map fmap = Fmap(directory);

fmap['keyA'] = 'my string';         // saved string into a file
fmap['keyB'] = 777;                 // saved int into a file
fmap['keyC'] = [0x12, 0x34, 0x56];  // saved three-bytes into a file

print(fmap['keyA']); // read from file
```

The storage is most efficient for storing large objects: blobs and strings. Although it can store small ones like bool and int without any problems.

This object implements `Map`, so it can be used in the same way.

``` dart
Map fmap = Fmap(directory);

print('Count of items: ${fmap.length}');

for (var entry in fmap.entries) {
    print('Item ${entry.name} ${entry.value}'); 
}
```

## Basic types

The storage can store such basic types as `String`, `int`, `double` and `bool`.


They can be read as dynamic types ...

``` dart
var objects = Fmap(directory);
var myJsonString = fmap['json']; // a dynamic type
var myIntValue = fmap['number']; // a dynamic type
```

Or more strictly, limiting to generic arguments:

``` dart
var strings = Fmap<String>(directory);
var myJsonString = strings['json'];  // definitely a string 

// but beware of type errors:
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
final fmap = Fmap(dir, policy: Policy.lru);
```

Two modes are supported: FIFO and LRU. By default, this is FIFO.

If you want the `purgeSync` method to purge storage in LRU mode, you must always 
use an `Fmap` object with `Policy.lru`. This will cause `Fmap` to update the 
last-used timestamp every time an element is read.

If you do not specify this argument, the timestamp is not updated - and the 
order of the elements becomes closer to the FIFO.




