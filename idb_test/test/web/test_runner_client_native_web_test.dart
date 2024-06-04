@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_test/idb_test_common.dart';

import 'test_runner_client_native_test_common.dart';

void main() {
  group('native_web', () {
    if (idbFactoryNativeSupported) {
      idbNativeFactoryTests(idbFactoryNative);
    } else {
      test('idb native web supported', () {},
          skip: 'idb native hweb not supported');
    }
  });
}
