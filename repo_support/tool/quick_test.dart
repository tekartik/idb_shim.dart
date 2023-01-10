import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  shell = shell.pushd(join('..', 'idb_shim'));
  await shell.run('''

dart pub get
dart test -p vm test/multiplatform

    ''');
  shell = shell.popd();
  shell = shell.pushd(join('..', 'idb_test'));
  await shell.run('''

dart pub get
dart test -p vm test/io/test_runner_client_sembast_io_test.dart
dart test -p chrome test/web/test_runner_client_native_test.dart

    ''');
  shell = shell.popd();
}
