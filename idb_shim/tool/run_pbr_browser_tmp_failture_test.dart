import 'package:process_run/shell.dart';

/// This occurs with dart 2.3
Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run build_runner test -- -p chrome test/multiplatform/index_test.dart
  # pub run build_runner test -- -p chrome test/multiplatform/test_runner_client_sembast_memory_test.dart

''');
}
