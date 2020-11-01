import 'package:dev_test/package.dart';

Future main() async {
  for (var dir in [
    'idb_shim',
    'idb_test',
    // last
    '.',
  ]) {
    await packageRunCi(dir);
  }
}
