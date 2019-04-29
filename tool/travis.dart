import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dartanalyzer --fatal-warnings lib test tool example
  dartfmt -w lib test tool example --set-exit-if-changed

  pub run test -p vm -j 1
  # pub run build_runner test -- -p vm -j 1 test/multiplatform
  
  pub run test -p chrome -j 1
  pub run build_runner test -- -p chrome -j 1 test/web test/multiplatform
  
  # test dartdevc support
  pub run build_runner build example -o example:build/example_debug
  pub run build_runner build -r example -o example:build/example_release

''');
}
