library idb_shim.src.client.client;

import 'package:idb_shim/src/common/common_import.dart';

/// to simply add a warning in a code for
/// something todo later
/// idbDevWarning;
@Deprecated('Dev only')
dynamic get idbDevWarning => null;

/// Dev print (deprecated on purpose)
@Deprecated('Dev only')
void idbDevPrint(Object? msg) => idbLog(msg);
