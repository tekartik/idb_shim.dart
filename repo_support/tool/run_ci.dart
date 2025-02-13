import 'package:dev_build/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in ['idb_shim', 'idb_test']) {
    await packageRunCi(
      join('..', dir),
      options: PackageRunCiOptions(noBrowserTest: true),
    );
  }
}
