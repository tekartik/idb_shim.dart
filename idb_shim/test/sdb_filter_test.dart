import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';

Future<void> main() async {
  group('sdb_filter', () {
    SdbFilter.equals('test', 1);
    SdbFilter.custom((snapshot) {
      // ignore: unused_local_variable
      var key = snapshot.key;
      // ignore: unused_local_variable
      var value = snapshot.value;
      // ignore: unused_local_variable
      var someInnerValue = snapshot['someInnerValue'];
      return false;
    });
  });
}
