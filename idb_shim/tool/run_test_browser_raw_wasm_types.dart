import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dart test -p chrome -c dart2wasm test/web/idb_browser_raw_types_test.dart

''');
}
