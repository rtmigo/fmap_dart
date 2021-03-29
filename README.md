![Generic badge](https://img.shields.io/badge/status-draft-red.svg)
![Generic badge](https://img.shields.io/badge/testing_on-Windows_|_MacOS_|_Ubuntu-blue.svg)


# fmap

File based key value store.

``` dart
Map fmap = Fmap(directory);

fmap['keyA'] = 'my string'; // saved into a file
fmap['keyB'] = 5;           // saved into a file

print(fmap['keyA']); // read from file
```

Each item actually stored in a separate file. So it's just named files. 
Fast, simple and reliable.

This does not impose any restrictions on the keys. They can be of any length 
and can contain any characters.

``` dart
diskBytes.saveBytesSync('C:\\con', ...);  // no problem
diskBytes.saveBytesSync('*_*', ...);      // no problem
```

## Purge

If the storage has become too large, you can delete the oldest data.

``` dart
// leave only the freshest 16 Mb
diskBytes.purgeSync(16*1024*1024);
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

