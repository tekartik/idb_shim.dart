// Stub for non-web platforms. BroadcastChannel is a web-only API.

/// Broadcast store changes to other tabs. No-op on non-web platforms.
void sdbBroadcastStoreChanges(String dbName, List<String> storeNames) {}

/// Stream of store changes from other tabs. Always empty on non-web.
Stream<(String, List<String>)> get sdbExternalStoreChangesStream =>
    const Stream.empty();
