library common_value_test;

import 'package:idb_shim/src/common/common_validation.dart';

import 'idb_test_common.dart';

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

    void checkKeyValueParamFail(String keyPath, dynamic key, dynamic value) {
      try {
        checkKeyValueParam(keyPath, key, value);
      } catch (_) {
        return;
      }
      fail('$key should fail');
    }

    test('checkKeyValueParam', () {
      checkKeyValueParamFail('keyPath', 'key', {});
      checkKeyValueParamFail('keyPath', 'key', {'keyPath': 'key'});
      checkKeyValueParam('keyPath', null, {'keyPath': 'key'});
      checkKeyValueParamFail('keyPath', null, {'noKeyPath': 'key'});
      checkKeyValueParamFail('key.path', 'key', {
        'key': {'path': 'key'}
      });
    });
  });
}
