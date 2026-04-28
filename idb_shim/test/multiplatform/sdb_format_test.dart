import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_internal_migration.dart';
import 'package:test/test.dart';

void main() {
  group('format', () {
    group('1 to 2', () {
      test('timestamp migration', () {
        var codec = SdbCodec.defaultCodec;
        var now = SdbTimestamp.now();
        expect(
          rawValueCompatMigrate1To2(codec, {
            '@Timestamp': now.toIso8601String(),
          }),
          {r'$Timestamp': now.toIso8601String()},
        );
        expect(
          rawValueCompatMigrate1To2(codec, [
            [
              {
                'timestamp': [
                  {'@Timestamp': now.toIso8601String()},
                ],
              },
            ],
          ]),
          [
            [
              {
                'timestamp': [
                  {r'$Timestamp': now.toIso8601String()},
                ],
              },
            ],
          ],
        );
        var value = {'@Timestamp': now.toIso8601String()};
        expect(
          migrateValuesAreEqual(rawValueCompatMigrate1To2(codec, value), value),
          isFalse,
        );
        value = {r'$Timestamp': now.toIso8601String()};
        expect(
          migrateValuesAreEqual(rawValueCompatMigrate1To2(codec, value), value),
          isTrue,
        );
      });
      test('migration codec none', () {
        var codec = SdbCodec.none;
        var value = {'test': 1};
        expect(
          migrateValuesAreEqual(rawValueCompatMigrate1To2(codec, value), value),
          isTrue,
        );
        var now = SdbTimestamp.now();
        expect(
          rawValueCompatMigrate1To2(codec, {
            '@Timestamp': now.toIso8601String(),
          }),
          {r'@Timestamp': now.toIso8601String()},
        );
      });
    });
  });
}

//import '../idb_test_common.dart';
