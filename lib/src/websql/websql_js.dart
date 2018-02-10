@JS()
library idb_shim.websql.websql_js;

import 'package:js/js.dart';

@JS("Object.keys")
external List<String> objectKeys(Object obj);
