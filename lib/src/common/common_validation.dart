library idb_shim.common_validation;

import '../../idb_client.dart';

checkKeyParam(var key) {
  if (key == null) {
    throw new DatabaseNoKeyError();
  }
}
