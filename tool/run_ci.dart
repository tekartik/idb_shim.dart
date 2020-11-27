import 'dart:io';

import 'package:dev_test/package.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'idb_shim',
      'idb_test',
      // last
      // '.',
    ]) {
      await packageRunCi(dir);
    }
  } else {
    stderr.writeln('ci test skipped for $dartVersion');
  }
}
