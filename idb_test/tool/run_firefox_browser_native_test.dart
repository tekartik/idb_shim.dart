// @dart=2.9
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run test -p firefox test/web/test_runner_client_native_test.dart

''');
}
