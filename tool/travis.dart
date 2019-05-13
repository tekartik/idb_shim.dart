import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

import 'tool_test.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dartanalyzer --fatal-warnings lib test tool example
  dartfmt -w lib test tool example --set-exit-if-changed

  pub run test -p vm -j 1
  # pub run build_runner test -- -p vm -j 1 test/multiplatform
  
  pub run test -p chrome -j 1
  ''');

  // Fails on Dart 2.1.1
  var dartVersion = parsePlatformVersion(Platform.version);
  if (dartVersion >= Version(2, 2, 0, pre: 'dev')) {
    await shell.run('''
    # pub run build_runner test -- -p vm -j 1 test/multiplatform test/vm
    pub run build_runner test -- -p chrome -j 1 test/web test/multiplatform
  ''');
  }

  await shell.run('''
  # test dartdevc support
  pub run build_runner build example -o example:build/example_debug
  pub run build_runner build -r example -o example:build/example_release

  ''');
}
