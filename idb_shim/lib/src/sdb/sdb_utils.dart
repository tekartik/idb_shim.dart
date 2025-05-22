import 'package:idb_shim/idb.dart';

/// Find records descending argument to idb direction.
String descendingToIdbDirection(bool? descending) {
  return (descending ?? false) ? idbDirectionPrev : idbDirectionNext;
}
