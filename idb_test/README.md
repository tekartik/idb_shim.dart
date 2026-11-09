# idb_test

The shared test suite of [idb_shim](https://pub.dev/packages/idb_shim): every
`IdbFactory` implementation (sembast memory and io, native IndexedDB,
idb_sqflite, ...) runs the same tests, so they all behave like IndexedDB. It
also covers the sdb layer (`package:idb_shim/sdb.dart`) and holds the helpers
(`TestContext`, `dbTest`, error predicates) to write new idb tests.

## Getting started

Not on pub.dev. Add it to the `dev_dependencies` of the package that provides
the factory:

```yaml
dev_dependencies:
  test: ">=1.31.0"
  idb_test:
    git:
      url: https://github.com/tekartik/idb_shim.dart
      path: idb_test
```

Then one test file runs the whole suite on your factory:

```dart
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  // Replace by the factory under test.
  var ctx = TestContext(factory: newIdbFactoryMemory());
  group('my_factory', () {
    defineAllTests(ctx); // idb + sdb suites
  });
}
```

`dart test` runs it on the VM; a browser factory goes in a
`@TestOn('browser')` file run with `dart test -p chrome` (add `-c dart2js,dart2wasm`,
or a `compilers:` list in `dart_test.yaml`, to run both compilers).

## Entry points

* `defineAllTests(TestContext ctx)` (`test_runner.dart`): every idb suite,
  the review regression suites and the sdb suites on top of the factory.
* `defineAllSdbTests(TestContext ctx)`: the sdb suites only, through
  `sdbFactoryFromIdb(ctx.factory)`.
* `sdbDefineAllTests(SdbTestContext ctx)`: the sdb suites on any `SdbFactory`,
  idb based or not (as `tekartik_sdb_sembast` does); add `sdbIterateTests` and
  `sdbReviewRegressionTests` for an idb like implementation.
* Each suite is also a library with its own `defineTests(TestContext ctx)`
  (`open_test.dart`, `cursor_test.dart`, `review_regression_test.dart`...):
  import it with a prefix to run or debug one suite.

## Who runs it

| Implementation | Runner |
|---|---|
| idb_shim sembast (memory, memory fs, jdb, logger) | `idb_test/test/multiplatform`, VM and Chrome |
| idb_shim sembast io | `idb_test/test/io` |
| idb_shim native IndexedDB | `idb_test/test/web` (dart2js and dart2wasm) |
| idb_sqflite | `idb_sqflite_common_test` (sqflite ffi, sandbox) |
| sdb on sembast (`tekartik_sdb_sembast`) | `idb_shim_more`, memory, io and web: the sdb suites |
| `idb_shim_html_compat` (dart:html) | `idb_shim_more`: object store and review regression suites only |

## Writing a shared test

* Use a new database name per test: `ctx.dbName` (a new name at every read)
  or `dbTest`, and delete it first.
* A test must be able to fail: never wrap expectations in a catch all (it
  catches the `TestFailure` of `fail()` and `expect`). In an expected error
  check, catch the error type, or `expect(e, isNot(isA<TestFailure>()))`.
* A broken implementation must fail fast: bound loops and cursor walks, give a
  slow test a `timeout:`, and wait for an event rather than a fixed delay.
* A behaviour an implementation does not have yet is skipped there with the
  reason (`skip: ctx.isIdbHtmlCompat ? 'reason' : null`), not removed from the
  shared test. `TestContext` flags set by the runner: `isIdbIe`, `isIdbEdge`,
  `isIdbSafari`, `isIdbHtmlCompat`, `isIdbSembast`; computed: `isInMemory`
  (override it in a subclass), `isIdbNoLazy`, `isWebWasm`.

More: the `idb-test-setup` skill (`skills/idb-test-setup/SKILL.md`).
