import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import "package:test/test.dart";
import 'package:disk_cache/disk_сache.dart';

String badHashFunc(String data) {
  // guaranteed to produce collisions
  var content = new Utf8Encoder().convert(data);
  var md5 = crypto.md5;
  var digest = md5.convert(content);

  String result = digest.bytes[0].toRadixString(16)[0];

  assert(result.length == 1);

  return result;
}

class SampleWithData {
  static Future<SampleWithData> create({longerDelays=false}) async {


    final theDir = Directory.systemTemp.createTempSync();

    var theCache = DiskCache(theDir, maxCount: 999999, maxSizeBytes: 99999 * 1024 * 1024, keyToHash: badHashFunc);

    Set<String> allKeys = Set<String>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      allKeys.add(key);

      if (i!=0)
        if (longerDelays && (i==1||i==98)) {

          // making a longer pause between 0..1 and 98..99
          //
          // TL;DR Last-modification times on FAT are rounded to nearest 2 seconds.
          // If we want to compare files by LMT, we need to make 2+ seconds delays between
          // writing operations.
          //
          // https://stackoverflow.com/a/11547476
          // File time stamps on FAT drives are rounded to the nearest two seconds (even number)
          // when the file is written to the drive. The file time stamps on NTFS drives are rounded
          // to the nearest 100 nanoseconds when the file is written to the drive. Consequently,
          // file time stamps on FAT drives always end with an even number of seconds, while file
          // time stamps on NTFS drives can end with either even or odd number of seconds.

          await Future.delayed(Duration(milliseconds: 2050));
        }
        else
          await Future.delayed(Duration(milliseconds: 25));

      await theCache.writeBytes(key, List.filled(1024, 0));
    }

    return SampleWithData(theCache, allKeys);
  }

  SampleWithData(this.cache, this.keys);

  final DiskCache cache;
  final Set<String> keys;

  Future<int> countItemsInCache() async {
    int countLeft = 0;
    for (var k in this.keys) if (await this.cache.readBytes(k) != null) countLeft++;
    return countLeft;
  }
}

Directory? findEmptySubdir(Directory d) {
  for (var sub in d.listSync(recursive: true)) {
    if (sub is Directory) if (sub.listSync().length == 0) return sub;
//      if (sub. is Directo)
  }

  return null;
}

void main() {
  test('files: saving and reading', () async {
    final theDir = Directory.systemTemp.createTempSync();
    final path = theDir.path + "/temp";

    writeKeyAndDataSync(File(path), "c:/key/name/", [4, 5, 6, 7]);

    expect(readKeySync(File(path)), "c:/key/name/");

    expect(readIfKeyMatchSync(File(path), "c:/key/name/"), [4, 5, 6, 7]);
    expect(readIfKeyMatchSync(File(path), "other"), null);
  });

  test('dk', () async {
    final theDir = Directory.systemTemp.createTempSync();
    //print(theDir);

    final cacheA = DiskCache(theDir, maxCount: 3, maxSizeBytes: 10);

    expect(await cacheA.readBytes("A"), null);
    await cacheA.writeBytes("A", [1, 2, 3]);
    expect(await cacheA.readBytes("A"), [1, 2, 3]);
  });

  test('hash collisions', () async {
    final theDir = Directory.systemTemp.createTempSync();
    //print(theDir);

    final cache = DiskCache(theDir, maxCount: 1000, maxSizeBytes: 10 * 1024 * 1024, keyToHash: badHashFunc);

    Set<Directory> allSubdirs = Set<Directory>();
    Set<String> allKeys = Set<String>();
    Set<File> allFiles = Set<File>();

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      final file = await cache.writeBytes(key, [i, i + 10]);

      allFiles.add(file);
      allSubdirs.add(file.parent);
      allKeys.add(key);
    }

    for (var i = 0; i < 100; ++i) {
      var key = i.toString();
      expect(await cache.readBytes(key), [i, i + 10]);
      //await cache.writeBytes(key, [i,i+10]);
    }

    // убеждаемся, что пока все файл и все подкаталоги на месте
    for (final d in allSubdirs) expect(d.existsSync(), isTrue);
    for (final f in allFiles) expect(f.existsSync(), isTrue);

    // удаляем все элементы, убеждаясь, что удаление одних элементов никогда не мешает другим
    // (а удаляем умышленно не по порядку, а рандомно)

    for (final key in allKeys.toList()..shuffle()) {
      expect(await cache.readBytes(key), isNotNull);
      await cache.delete(key);
      expect(await cache.readBytes(key), isNull);
    }

    // убеждаемся, что и файлы, и подкаталоги удалены
    for (final d in allSubdirs) expect(d.existsSync(), isFalse);
    for (final f in allFiles) expect(f.existsSync(), isFalse);

    expect(findEmptySubdir(theDir), null); // пустых подкаталогов не осталось
  });



  test('clearing on start by count', () async {
    final sample = await SampleWithData.create(longerDelays: true);

    // оставляем только 50 новейших файлов
    await DiskCache(sample.cache.directory, maxCount: 50, keyToHash: sample.cache.keyToHash).initialized;

    expect(await sample.countItemsInCache(), 50);
    expect(findEmptySubdir(sample.cache.directory), null); // пустых подкаталогов не осталось

    // первый элемент точно был удален, последний точно остался
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull); // fails on windows
  });

  test('clearing on start by size', () async {
    final sample = await SampleWithData.create(longerDelays: true);

    // оставляем только 52 килобайта
    await DiskCache(sample.cache.directory, maxSizeBytes: 52 * 1024, keyToHash: sample.cache.keyToHash).initialized;

    expect(
        await sample.countItemsInCache(), 51); // получилось на один меньше, т.е. каждый файл больше на размер заголовка
    expect(findEmptySubdir(sample.cache.directory), null); // пустых подкаталогов не осталось

    // первый элемент точно был удален, последний точно остался
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);


  });

  test('clearing on start by size and count', () async {
    final sample = await SampleWithData.create(longerDelays: true);

    // оставляем только 52 килобайта
    await DiskCache(sample.cache.directory, maxSizeBytes: 47 * 1024, maxCount: 45, keyToHash: sample.cache.keyToHash)
        .initialized;

    expect(await sample.countItemsInCache(), 45);
    expect(findEmptySubdir(sample.cache.directory), null); // пустых подкаталогов не осталось

    // первый элемент точно был удален, последний точно остался
    expect(await sample.cache.readBytes("0"), isNull);
    expect(await sample.cache.readBytes("99"), isNotNull);
  });
}
