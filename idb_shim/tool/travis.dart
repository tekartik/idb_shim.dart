// @dart=2.9
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dart analyze --fatal-warnings --fatal-infos .
  dart format -o none --set-exit-if-changed .

  dart test

  pub run test -p chrome -j 1
  pub run test -p firefox -j 1
  
  # Currently running as 2 commands
  pub run build_runner test -- -p chrome -j 1 test/web
  pub run build_runner test -- -p chrome -j 1 test/multiplatform
  
  # test dartdevc support
  pub run build_runner build example -o example:build/example_debug
  pub run build_runner build -r example -o example:build/example_release

  ''');
}
