import 'package:process_run/shell.dart';
import 'package:dev_test/package.dart';

Future main() async {
  var shell = Shell();
  await packageRunCi('.',
      options: PackageRunCiOptions(noTest: true, noOverride: true));

  await shell.run('''
  dart test -p vm,chrome -j 1

  # Currently running as 2 commands
  dart pub run build_runner test -- -p chrome -j 1 test/web
  dart pub run build_runner test -- -p chrome -j 1 test/multiplatform
  
  # test dartdevc support
  dart pub run build_runner build example -o example:build/example_debug
  dart pub run build_runner build -r example -o example:build/example_release

  ''');
}
