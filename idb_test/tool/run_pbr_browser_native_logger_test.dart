import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  # pub run build_runner test -- -p chrome -j 1 test/multiplatform/idb_shim_import_test.dart
  pub run build_runner test -- -p chrome -j 1 test/manual_web/test_runner_client_native_logger_test.dart
  

''');
}
