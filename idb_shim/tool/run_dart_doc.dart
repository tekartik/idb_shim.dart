import 'package:dev_build/shell.dart';

Future<void> main(List<String> args) async {
  await run(
    'dart doc'
    ' --validate-links', // (Standard) Checks for broken cross-references within your documentation.
  );
}
