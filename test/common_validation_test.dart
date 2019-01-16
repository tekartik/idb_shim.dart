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
  });
}
