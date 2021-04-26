import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  shell = shell.pushd(join('..', 'idb_shim'));
  await shell.run('''

pub get
pub run test test/test_runner_client_sembast_io_test.dart
pub run build_runner test -- -p chrome test/web/idb_native_factory_test.dart

    ''');
  shell = shell.popd();
}
