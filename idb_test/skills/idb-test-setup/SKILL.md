---
name: idb-test-setup
description: >-
  Use when validating an IdbFactory implementation (native web, sembast io/
  memory, sqflite, a custom shim) against the shared idb_test conformance
  suite, or when writing idb_shim tests with its helpers: defineAllTests /
  defineAllSdbTests from test_runner.dart, TestContext /
  SembastTestContext / SembastFsTestContext / idbMemoryContext /
  idbMemoryFsContext, dbGroup / dbTest / dbTestName / setUpSimpleStore, the
  testStoreName / testNameIndex / testNameField constants, isDatabaseError and
  friends, wrapInLogger, and package:idb_test/idb_test_common.dart.
---

# Shared idb_shim test suite (idb_test)

`idb_test` is the conformance suite for `package:idb_shim`: wrap your
`IdbFactory` in a `TestContext` and `defineAllTests(ctx)` runs the whole
IndexedDB model (open/upgrade, object stores, indexes, cursors, key ranges,
transactions, types, exceptions) plus the SDB suite against it. It is also the
common toolbox (`idb_test_common.dart`) used to write new idb tests.

## Guidelines

* Dependency (git, not on pub.dev), in `dev_dependencies` of the package under
  test:
  ```yaml
  dev_dependencies:
    idb_test:
      git:
        url: https://github.com/tekartik/idb_shim.dart
        path: idb_test
  ```
* `import 'package:idb_test/idb_test_common.dart';` is the single import a
  test file needs: it re-exports `package:dev_test/test.dart` (so `group`,
  `test`, `expect`, `setUp`... come with it), `package:idb_shim/
  idb_client_memory.dart` (`idbFactoryMemory`, `newIdbFactoryMemory()`,
  `idbFactoryMemoryFs`), the `IdbObjectStoreMeta`/`IdbIndexMeta` metadata
  classes and `kIdbDartIsWeb` / `idbIsRunningAsJavascript`. Do not add
  `package:test/test.dart` on top of it.
* `TestContext` is what every suite takes:
  * `TestContext()..factory = myIdbFactory` for a plain factory, or
    `TestContext(factory: myIdbFactory)`.
  * `ctx.dbName` returns a *new* unique name on every read - never cache it.
  * Declare platform quirks so the suite skips what cannot work:
    `isIdbIe`, `isIdbEdge`, `isIdbSafari` (browser), `isIdbSembast`,
    `isInMemory` (data gone after `close`), `isIdbNoLazy`, `supportsDoubleKey`
    (read from the factory), `isWebWasm`.
  * `ctx.wrapInLogger()` replaces `ctx.factory` with a logging factory
    (`IdbFactoryLoggerType.all` by default) to debug a failing suite;
    `ctx.getFactory<T>()` unwraps it again.
* Ready-made contexts: `idbMemoryContext` (sembast in memory, fastest),
  `idbMemoryFsContext` (`SembastFsTestContext`, in-memory file system, keeps
  data across `close`), `SembastTestContext(sembastDatabaseFactory: ...)` for
  any sembast `DatabaseFactory` (io, jdb, web), `SembastMemoryTestContext` /
  `SembastMemoryFsTestContext` as subclasses to extend.
* Entry points from `package:idb_test/test_runner.dart`:
  `defineAllTests(TestContext ctx)` (everything, including the SDB suite) and
  `defineAllSdbTests(TestContext ctx)` (`package:idb_shim/sdb.dart` layer
  only, via `sdbFactoryFromIdb`). Individual suites are one library each -
  `package:idb_test/database_test.dart`, `open_test.dart`, `cursor_test.dart`,
  `index_test.dart`, `transaction_test.dart`, `key_range_test.dart`,
  `factory_test.dart`, `object_store_test.dart`, `exception_test.dart`,
  `type_test.dart`, `scenario_test.dart`, `indexeddb_1_test.dart` ..
  `indexeddb_5_test.dart` - each exporting `defineTests(TestContext ctx)`.
  Import them with a prefix, they all use the same name.
* Wrap the call in a `group('<impl>', () => defineAllTests(ctx))` and guard the
  file with `@TestOn('vm')` / `@TestOn('browser')` when the factory is platform
  specific. A browser test must also check availability
  (`idbFactoryNativeSupported`) before running.
* Writing your own tests with the same helpers: `dbGroup(ctx, 'name', () {
  ... })` registers the context, then `dbTest('name', () async { ... })`
  deletes and names a fresh database available as the global `dbTestName`.
  `setUpSimpleStore(factory, dbName: ..., meta: ...)` opens a v1 database with
  one store (default meta: `idbSimpleObjectStoreMeta`, from
  `package:idb_test/idb_test_common_meta.dart`). Constants:
  `testStoreName`, `testStoreName2`, `testNameIndex`, `testNameField`,
  `testValueIndex`, `testValueField`, `testValue`, `testKey`. Error
  predicates: `isDatabaseError`, `isTransactionReadOnlyError`,
  `isTransactionInactiveError`, `isNotFoundError`, `isTestFailure`.
* Extras: `package:idb_test/sembast.dart` re-exports sembast plus
  `disableSembastCooperator()` (faster memory runs);
  `package:idb_test/simple_provider.dart` (`SimpleProvider`, `SimpleRow`) is a
  small provider used by `simple_provider_test.dart`;
  `package:idb_test/indexeddb_utils.dart` has `verifyGraph(expected, actual)`
  for structural value comparison; the sdb stress groups
  (`sdbStressNotesGroup`, `sdbStressAddListNotesGroup`) live in
  `package:idb_test/src/stress_notes_db_test.dart` and are slow: keep them in
  a dedicated test file.
* Anti-patterns: reusing one database name across tests (use `ctx.dbName` or
  `dbTest`), forgetting `db.close()` / `await transaction.completed`, running
  the full suite on a real browser database without deleting it first, putting
  `idb_test` in `dependencies`.

## Examples

### Full suite against your own factory

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void defineMyFactoryTests(IdbFactory myFactory) {
  var ctx = TestContext(factory: myFactory)..isIdbSembast = false;
  group('my_factory', () {
    defineAllTests(ctx);
  });
}
```

### Memory and file system contexts (multiplatform)

```dart
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sembast.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  disableSembastCooperator();
  group('memory', () {
    defineAllTests(idbMemoryContext);
  });
  group('memory_fs', () {
    defineAllTests(idbMemoryFsContext);
  });
}
```

### A sembast io context on the Dart VM

```dart
@TestOn('vm')
library;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

class IoTestContext extends SembastFsTestContext {
  IoTestContext() {
    factory = IdbFactorySembast(
      databaseFactoryIo,
      join('.dart_tool', 'idb_shim', 'test'),
    );
  }
}

void main() {
  group('io', () {
    defineAllTests(IoTestContext());
  });
}
```

### Native (browser) factory, with the browser quirks declared

```dart
@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  group('native', () {
    if (idbFactoryNativeSupported) {
      var ctx = TestContext(factory: idbFactoryNative)
        ..isIdbSafari = false
        ..isIdbEdge = false;
      // ctx.wrapInLogger(); // uncomment to trace a failure
      defineAllTests(ctx);
    } else {
      test('native supported', () {}, skip: 'idb native not supported');
    }
  });
}
```

### Your own test using the shared helpers

```dart
import 'package:idb_test/idb_test_common.dart';

void main() {
  var ctx = idbMemoryContext;
  dbGroup(ctx, 'my_store', () {
    dbTest('put/get', () async {
      var db = await setUpSimpleStore(ctx.factory, dbName: dbTestName);
      var txn = db.transaction(testStoreName, idbModeReadWrite);
      var store = txn.objectStore(testStoreName);
      var key = await store.put({testNameField: testValue});
      await txn.completed;
      expect(await db.transaction(testStoreName, idbModeReadOnly)
          .objectStore(testStoreName)
          .getObject(key), {testNameField: testValue});
      db.close();
    });
  });
}
```

### SDB layer only

```dart
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  group('sdb_memory', () {
    defineAllSdbTests(idbMemoryContext);
  });
}
```
