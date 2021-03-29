![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
![Generic badge](https://img.shields.io/badge/testing_on-Windows_|_MacOS_|_Ubuntu-blue.svg)


# fmap

А `Map` stored in the file system. Equally suitable for caching and persistent 
storage.

``` dart
Map fmap = Fmap(directory);

fmap['keyA'] = 'my string'; // saved string into a file
fmap['keyB'] = 5;           // saved int into a file
fmap['keyC'] = [23,42,77];  // saved three bytes into a file

print(fmap['keyA']); // read from file
```

The storage is most efficient for storing large objects: blobs and strings. Although it can store small ones like bool and int without any problems.

This object implements Map, so it can be used in the same way.

``` dart
Map fmap = Fmap(directory);

print('Count of items: ${fmap.length}');

for (var entry in fmap.entries) {
    print('Item ${entry.name} ${entry.value}'); 
}
```

## Purge

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the freshest 16 Mb
fmap.purgeSync(16*1024*1024);
```

The constructor has the `updateTimestampsOnRead` argument. This argument determines which elements
will be considered fresh at the time of purging.

``` dart
final fmap = Fmap(updateTimestampsOnRead=true);
fmap.purge(...);  // LRU
```

In this case, the elements will be deleted according to the **LRU** policy. Items that were accessed
recently or added recently will remain in the cache.

However, accounting for usage will require an extra write operation on each read.

``` dart
final fmap = Fmap(updateTimestampsOnRead=false);
fmap.purge(...);  // FIFO
```

In this case, it's a **FIFO**. Items that were added recently will remain in the cache.

This is the default mode. This prevents wear to the SSD drives.

