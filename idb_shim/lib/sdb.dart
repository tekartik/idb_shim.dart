/// Simple DB.
///
/// Opinionated strong type API. Design around indexed db API which is a
/// basic database API easy to implement with good web support and robust
/// desktop implementation using `idb_sqflite`
///
/// In memory available (mainly for testing) and io implementation using sembast
///
library;

export 'package:idb_shim/src/sdb.dart';
