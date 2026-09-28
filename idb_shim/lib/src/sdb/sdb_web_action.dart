/// The browser actions of `SdbVersionChangeAction` and `SdbBlockedAction`,
/// no-ops outside the web.
library;

export 'sdb_web_action_stub.dart'
    if (dart.library.js_interop) 'sdb_web_action_web.dart';
