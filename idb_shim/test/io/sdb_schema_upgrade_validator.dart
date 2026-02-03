import 'dart:convert';
import 'dart:io';

import 'package:idb_shim/sdb/sdb.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart' as sembast;
import 'package:sembast/utils/sembast_import_export.dart';

/// Validate database schema upgrades by comparing database content.
class SdbSchemaUpgradeValidator {
  /// Database name.
  final String name;

  /// Path to database files.
  final String path;

  /// Create a validator for the given database [name].
  SdbSchemaUpgradeValidator({String? path, required this.name})
    : path = path ?? join('test', 'data');

  Future<List<int>> _findVersions() async {
    var dir = Directory(path);
    if (!dir.existsSync()) {
      return [];
    }
    var versions = <int>[];
    await for (var entity in dir.list()) {
      if (entity is File) {
        var baseName = basename(entity.path);
        var match = RegExp(
          '^${RegExp.escape(name)}_(\\d+)\\.db\$',
        ).firstMatch(baseName);
        if (match != null) {
          var version = int.parse(match.group(1)!);
          versions.add(version);
        }
      }
    }
    versions.sort();
    return versions;
  }

  final _sembastDatabaseFactoryIo = sembast.databaseFactoryIo;

  Future<String> _getContent(String dbPath) async {
    var sembastDb = await _sembastDatabaseFactoryIo.openDatabase(dbPath);
    try {
      var existingContent = jsonEncode(await exportDatabaseLines(sembastDb));
      return existingContent;
    } finally {
      await sembastDb.close();
    }
  }

  Future<void> _setContent(String dbPath, String content) async {
    var sembastDb = await importDatabaseAny(
      content,
      _sembastDatabaseFactoryIo,
      dbPath,
    );
    await sembastDb.close();
  }

  /// Run the validator.
  Future<void> run({required SdbOpenDatabaseOptions options}) async {
    var version = options.version!;
    var schema = options.schema;
    var dbPath = join(path, '${name}_$version.db');
    var dbFile = File(dbPath);
    String? existingContent;
    if (!dbFile.existsSync()) {
      await dbFile.parent.create(recursive: true);
    } else {
      existingContent = await _getContent(dbPath);
      await dbFile.delete();
    }
    var factory = sdbFactoryIo;
    var db = await factory.openDatabase(dbPath, options: options);
    await db.close();
    var newContent = await _getContent(dbPath);

    if (existingContent != null) {
      if (existingContent != newContent) {
        await dbFile.writeAsString(existingContent, flush: true);
        stdout.writeln('expected:');
        stdout.writeln(existingContent);
        stdout.writeln('new:');
        stdout.writeln(newContent);
        throw StateError(
          'Database schema upgrade validation failed for $name '
          'version $version: content changed',
        );
      }
    }
    var versions = await _findVersions();
    for (var existingVersion in versions) {
      await _check(
        existingVersion: existingVersion,
        version: version,
        schema: schema,
      );
    }
  }

  final _workPath = join(
    '.dart_tool',
    'tekartik',
    'idb_shim_sdb_schema_upgrade_validator',
  );
  Future<void> _check({
    required int existingVersion,
    required int version,
    SdbDatabaseSchema? schema,
  }) async {
    var filename = '${name}_$existingVersion.db';
    var dbExistingPath = join(path, '${name}_$existingVersion.db');
    var dbPath = join(path, '${name}_$version.db');
    var workDirectory = Directory(_workPath);
    if (!workDirectory.existsSync()) {
      await workDirectory.create(recursive: true);
    }
    var workDbPath = join(_workPath, filename);

    var existingContent = await _getContent(dbExistingPath);
    await _setContent(workDbPath, existingContent);
    var expectedContent = await _getContent(dbPath);

    var factory = sdbFactoryIo;
    var db = await factory.openDatabase(
      workDbPath,
      version: version,
      schema: schema,
    );
    await db.close();
    var newContent = await _getContent(workDbPath);

    if (expectedContent != newContent) {
      stdout.writeln('expected:');
      stdout.writeln(expectedContent);
      stdout.writeln('new:');
      stdout.writeln(newContent);
      throw StateError(
        'Database schema upgrade validation failed for $name '
        'existingVersion: $existingVersion, version $version: content changed',
      );
    }
  }
}
