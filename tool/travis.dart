import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    var shell = Shell();

    for (var dir in ['idb_shim', 'idb_test']) {
      shell = shell.pushd(dir);
      await shell.run('''

pub get
dart tool/travis.dart

    ''');
      shell = shell.popd();
    }
  }
}
