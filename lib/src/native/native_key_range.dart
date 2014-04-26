part of idb_browser;


idb.KeyRange _nativeKeyRange(KeyRange common) {
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
//
//class NativeKeyRange extends KeyRange {
//  idb.KeyRange idbKeyRange;
//
//  NativeKeyRange(this.idbKeyRange);
//
//  Object get lower => idbKeyRange.lower;
//  bool get lowerOpen => idbKeyRange.lowerOpen;
//  Object get upper => idbKeyRange.upper;
//  bool get upperOpen => idbKeyRange.upperOpen;
//}
//
//class NativeKeyRangeFactory extends KeyRangeFactory {
//  KeyRange createOnly(/*Key*/ value) => new NativeKeyRange(new idb.KeyRange.only(value));
//  KeyRange createLowerBound(/*Key*/ bound, [bool open = false]) => new NativeKeyRange(new idb.KeyRange.lowerBound(bound, open));
//  KeyRange createUpperBound(/*Key*/ bound, [bool open = false]) => new NativeKeyRange(new idb.KeyRange.upperBound(bound, open));
//  KeyRange createBound(/*Key*/ lower,  /*Key*/ upper, [bool lowerOpen = false, bool upperOpen = false]) => new NativeKeyRange(new idb.KeyRange.bound(lower, upper, lowerOpen, upperOpen));
//}