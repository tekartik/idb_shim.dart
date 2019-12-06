@TestOn('browser')
library idb_browser_test;

import 'dart:html';

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_client_native.dart';

import 'test_runner_client_native_test.dart' as runner;

void main() {
  group('idb_native_factory', () {
    runner.idbNativeFactoryTests(idbFactoryFromIndexedDB(window.indexedDB));
  });
}
