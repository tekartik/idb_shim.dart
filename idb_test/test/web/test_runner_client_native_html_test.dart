@TestOn('browser && !wasm')
library;

import 'package:idb_shim/idb_client_native_html.dart';
import 'package:idb_test/idb_test_common.dart';

import 'test_runner_client_native_test_common.dart';

void main() {
  group('native_html', () {
    if (idbFactoryNativeSupported) {
      idbNativeFactoryTests(idbFactoryNative);
    } else {
      test('idb native html supported', () {},
          skip: 'idb native html not supported');
    }
  });
}
