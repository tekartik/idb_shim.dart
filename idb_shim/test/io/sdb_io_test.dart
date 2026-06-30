@TestOn('vm')
library;

import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var factory = sdbFactoryIo;

  test('getDatabaseFullPath()', () async {
    expect(await factory.getDatabaseFullPath('test.db'), 'test.db');

    expect(
      await factory.sandbox(path: 'sub').getDatabaseFullPath('test.db'),
      join('sub', 'test.db'),
    );
  });
}
