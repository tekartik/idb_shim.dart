library common_value_test;

import 'package:idb_shim/src/common/common_error.dart';
import 'package:idb_shim/src/common/common_validation.dart';

import '../idb_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('validation', () {
    void checkKeyParamFail(key) {
      try {
        checkKeyParam(key);
      } catch (_) {
        return;
      }
      fail('$key should fail');
    }

    test('checkKeyParam', () {
      checkKeyParam('');
      checkKeyParam('a');
      checkKeyParam(0);
      checkKeyParam(1.1);
      checkKeyParam([1, '123', 1.1]);

      checkKeyParamFail(null);
      checkKeyParamFail([]);
      checkKeyParamFail(DateTime.now());
    });

    void checkKeyValueParamFail(
        {String? keyPath, dynamic key, dynamic value, required bool autoIncrement}) {
      try {
        checkKeyValueParam(
            keyPath: keyPath,
            key: key,
            value: value,
            autoIncrement: autoIncrement);
      } catch (_) {
        return;
      }
      fail('$key should fail');
    }

    test('checkKeyValueParam', () {
      checkKeyValueParamFail(keyPath: 'keyPath', key: 'key', value: {});
      checkKeyValueParamFail(
          keyPath: 'keyPath', key: 'key', value: {'keyPath': 'key'});
      checkKeyValueParam(keyPath: 'keyPath', value: {'keyPath': 'key'});
      checkKeyValueParamFail(keyPath: 'keyPath', value: {'noKeyPath': 'key'});
      checkKeyValueParamFail(keyPath: 'key.path', key: 'key', value: {
        'key': {'path': 'key'}
      });

      try {
        checkKeyValueParam();
        fail('should fail');
      } on DatabaseMissingKeyError catch (_) {}

      checkKeyValueParam(autoIncrement: true);
      checkKeyValueParam(value: {}, autoIncrement: true);
    });
  });
}
