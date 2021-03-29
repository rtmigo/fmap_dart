![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
![Generic badge](https://img.shields.io/badge/testing_on-Windows_|_MacOS_|_Ubuntu-blue.svg)

# disk_bytes

`DiskBytesMap` and `DiskBytesCache` are objects for storing binary data in files. They are good for
small chunks of data that easily fit into a `Uint8List`. For example, to cache data from the web or
store user images.

``` dart
final diskBytes = DiskBytesMap(directory);
diskBytes.saveBytesSync('myKey', [0x21, 0x23]);  // saved into a file!
Uint8List fromDisk = diskBytes.loadBytesSync('myKey'); 
```

Each item actually stored in a separate file. So it's just named files. Fast, simple and reliable.

This does not impose any restrictions on the keys. They can be of any length and can contain any
characters.

``` dart
diskBytes.saveBytesSync('C:\\con', ...);  // no problem
diskBytes.saveBytesSync('*_*', ...);      // no problem
```

## They both are `Map`s

Both objects implement `Map<String, List<int>>`. So they can be used like an ordinary `Map`.

``` dart
Map diskBytes = DiskBytesMap(directory);

diskBytes["mykey"] = [1,2,3];  // saved into a file 

for (int byte in diskBytes["mykey"])  // read from file
  print("$byte");

print(diskBytes.length);   
```

It is worth remembering that `BytesMap`
and `BytesCache` do not store lists or ints. They just accept `List<int>` as an argument. Each item
of the list will be truncated to a byte.

``` dart
diskBytes["a"] = [1, 2, 3];
print(diskBytes["a"]);  // prints [1, 2, 3]

diskBytes["b"] = [0, -1, -2];
print(diskBytes["b"]);  // prints [0, 255, 254]
```

## Cache or Map

`DiskBytesMap` is more reliable. `DiskBytesCache` is faster.

Choose the `DiskBytesMap` if it is absolutely important for you that all stored data is readable
while the files are in place.

Choose `DiskBytesCache` for temporary files that are sometimes deleted randomly.

The difference is in the readiness of the objects for
[hash collisions](https://en.wikipedia.org/wiki/Collision_(computer_science)). Even if this rare
occurrence happens once a decade, `DiskBytesMap` is always ready for it. Both elements with the same
hashes will be stored side by side.

`DiskBytesCache` is much more relaxed in this regard. When faced with a rare collision, it will
simply remove one of the elements. There is nothing important in the cache, is there.

## Purge

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the freshest 16 Mb
diskBytes.purgeSync(maxSizeBytes=16*1024*1024);
  
// leave only the freshest 1000 elements
diskBytes.purgeSync(maxCount=1000);              
```

The constructor has the `updateTimestampsOnRead` argument. This argument determines which elements
will be considered fresh at the time of purging.

``` dart
final diskBytes = DiskBytesCache(updateTimestampsOnRead=true);
diskBytes.purge(...);  // LRU
```

In this case, the elements will be deleted according to the **LRU** policy. Items that were accessed
recently or added recently will remain in the cache.

However, accounting for usage will require an extra write operation on each read.

``` dart
final diskBytes = DiskBytesCache(updateTimestampsOnRead=false);
diskBytes.purge(...);  // FIFO
```

In this case, it's a **FIFO**. Items that were added recently will remain in the cache.

This is the default mode. This prevents wear to the SSD drives.

