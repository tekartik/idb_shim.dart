import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

Future main() async {
  var shell = Shell();
  var version = Version.parse(
    (loadYaml(await File(join('..', 'idb_shim', 'pubspec.yaml')).readAsString())
            as Map)['version']
        as String,
  );
  stdout.writeln('Version $version');
  stdout.writeln('Tap anything or CTRL-C: $version');

  await sharedStdIn.first;
  await shell.run('''
git tag v$version
git push origin --tags
''');
}
