// @dart=2.9
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run build_runner test -- -r expanded -p chrome test/multiplatform test/web

''');
}
