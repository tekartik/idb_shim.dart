library idb_shim.src.client.client;

/// to simply add a warning in a code for
/// something todo later
/// idbDevWarning;
@Deprecated('Dev only')
dynamic get idbDevWarning => null;

@Deprecated('Dev only')

/// Dev print (deprecated on purpose)
void idbDevPrint(msg) => print(msg);
