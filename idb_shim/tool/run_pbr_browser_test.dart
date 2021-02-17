import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  # pub run build_runner test -- -p chrome test/multiplatform
  # pub run build_runner test -- -p chrome test/web test/multiplatform
  pub run build_runner test -- -p chrome -j 1 test/web test/multiplatform

''');
}
