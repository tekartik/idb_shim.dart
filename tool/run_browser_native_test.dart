import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run test -p chrome test/test_runner_client_native_test.dart

''');
}
