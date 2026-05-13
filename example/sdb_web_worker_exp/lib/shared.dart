import 'package:idb_shim/sdb.dart';

const commandVarSet = 'varSet';
const commandVarGet = 'varGet';
const commandTrackStart = 'varTrackStart';
const commandTrackStop = 'varTrackStop';

const databasePath = 'sdb_web_worker_exp.db';
const storeKey = 'value';

final store = SdbStoreRef<String, int>('values');

extension SdbWorkerExp on SdbDatabase {
  Future<int?> getValue(String key) async {
    return (await store.record(key).get(this))?.value;
  }

  Stream<SdbRecordSnapshot<String, int>?> trackValue(String key) {
    return store.record(key).onSnapshot(this);
  }

  Future<void> setValue(String key, int? value) async {
    if (value != null) {
      await store.record(key).put(this, value);
    } else {
      await store.record(key).delete(this);
    }
  }

  Future<int?> getTestValue() => getValue(storeKey);
  Future<void> setTestValue(int? value) => setValue(storeKey, value);
}
