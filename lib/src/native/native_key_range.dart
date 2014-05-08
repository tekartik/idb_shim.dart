part of idb_native;


idb.KeyRange _nativeKeyRange(KeyRange common) {
  //print(common);
  if (common == null) {
    return null;
  }
  if (common.lower != null) {
    if (common.upper != null) {
      return new idb.KeyRange.bound(common.lower, common.upper, common.lowerOpen == true, common.upperOpen == true);    
    } else {
      return new idb.KeyRange.lowerBound(common.lower, common.lowerOpen == true);
    }
  } else {
    return new idb.KeyRange.upperBound(common.upper, common.upperOpen == true);
  }
  
}
