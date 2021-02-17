import 'package:process_run/shell.dart';

Future<void> main() async {
  var shell = Shell();

  await shell.run('''

  pub run test -p firefox

''');
}
