import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_factory.dart' show IdbFactoryBase;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

var testStore = SdbStoreRef<int, SdbModel>('test');

class _IdbFactoryMock extends IdbFactoryBase {
  @override
  Future<IdbFactory> deleteDatabase(
    String name, {
    OnBlockedFunction? onBlocked,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDatabaseNames() {
    throw UnimplementedError();
  }

  @override
  String get name => throw UnimplementedError();

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) {
    throw UnimplementedError();
  }

  @override
  bool get persistent => throw UnimplementedError();

  @override
  bool get supportsDatabaseNames => throw UnimplementedError();

  @override
  bool get supportsDoubleKey => throw UnimplementedError();
}

void main() {
  group('idb_factory', () {
    test('mock', () async {
      var mock = _IdbFactoryMock();
      expect(mock.pathContext, p.context);
    });
    test('isImmutableDatabaseName()', () {
      var mock = _IdbFactoryMock();
      expect(mock.isImmutableDatabaseName('test'), isFalse);
      expect(mock.isImmutableDatabaseName(':memory:'), isFalse);
    });
  });
}
