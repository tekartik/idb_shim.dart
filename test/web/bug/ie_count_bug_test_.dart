import 'dart:html';
import 'dart:indexed_db';

import 'package:test/test.dart';

void main() {
  test('count', () async {
    if (IdbFactory.supported) {
      String dbName = "com.tekartik.ie_count_bug.test";
      await window.indexedDB.deleteDatabase(dbName);
      void _setupDb(e) {
        final db = e.target.result as Database;
        db.createObjectStore("store", autoIncrement: true);
      }

      Database db = await window.indexedDB
          .open(dbName, version: 1, onUpgradeNeeded: _setupDb);

      Transaction transaction = db.transaction("store", "readwrite");
      var objectStore = transaction.objectStore("store");
      Map value = {'sample': 'value'};
      final key = await objectStore.add(value) as int;
      print('added $key $value');
      int count = await objectStore.count(key);
      print('count_by_key: $count');
      expect(count, 1);

      // This crashes on ie
      count = await objectStore.count();
      print('count_all: $count');

      await transaction.completed;
      db.close();
    }
  });
}
