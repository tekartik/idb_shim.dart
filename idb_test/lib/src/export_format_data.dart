/// The export format examples, the same database exported in each format,
/// copies of the files of `test/data` (checked by
/// `test/io/export_format_io_test.dart`) so that the tests run on every
/// platform.
library;

/// [text] with \n line endings (a Windows checkout of this file can turn the
/// line endings of its multi-line strings into \r\n).
String _lf(String text) => text.replaceAll('\r\n', '\n');

/// The legacy export: an idb export and an sdb export before the
/// `sdb_export` marker (`@Timestamp`, `@Blob`). It must never change.
///
/// `test/data/legacy_export1.jsonl`.
final legacyExport1Jsonl = _lf(r'''
{"sembast_export":1,"version":1}
{"store":"_main"}
["store_note",{"autoIncrement":true,"indecies":[{"keyPath":"title","name":"title"}],"keyPath":"id","name":"note"}]
["store_setting",{"name":"setting"}]
["stores",["note","setting"]]
["version",2]
{"store":"note"}
[1,{"id":1,"tags":["a","b"],"title":"hello"}]
[2,{"bigInt":9007199254740991,"bytes":{"@Blob":"AQID"},"date":{"@Timestamp":"2026-11-02T12:30:00.000Z"},"double":4.5,"false":false,"id":2,"int":-3,"list":[1,[2,"three"],{},[]],"nested":{"done":true,"empty":{}},"null":null,"text":"été ✓","title":"world","true":true}]
{"store":"setting"}
["escaped_at",{"$":{"@":{"@Timestamp":"not a timestamp"}}}]
["escaped_dollar",{"$blob":"not a blob"}]
["theme","dark"]
''');

/// The sdb export (`sdb_export` marker).
///
/// `test/data/sdb_export1.jsonl`.
final sdbExport1Jsonl = _lf(r'''
{"sdb_export":1,"sembast_export":1,"version":1}
{"store":"_main"}
["store_note",{"autoIncrement":true,"indecies":[{"keyPath":"title","name":"title"}],"keyPath":"id","name":"note"}]
["store_setting",{"name":"setting"}]
["stores",["note","setting"]]
["version",2]
{"store":"note"}
[1,{"id":1,"tags":["a","b"],"title":"hello"}]
[2,{"bigInt":9007199254740991,"bytes":{"@Blob":"AQID"},"date":{"@Timestamp":"2026-11-02T12:30:00.000Z"},"double":4.5,"false":false,"id":2,"int":-3,"list":[1,[2,"three"],{},[]],"nested":{"done":true,"empty":{}},"null":null,"text":"été ✓","title":"world","true":true}]
{"store":"setting"}
["escaped_at",{"$":{"@":{"@Timestamp":"not a timestamp"}}}]
["escaped_dollar",{"$blob":"not a blob"}]
["theme","dark"]
''');

/// The `$` idb export (`$Timestamp`, `$Blob`, `type_prefix`).
///
/// `test/data/idb_dollar_export1.jsonl`.
final idbDollarExport1Jsonl = _lf(r'''
{"sembast_export":1,"type_prefix":"$","version":1}
{"store":"_main"}
["store_note",{"autoIncrement":true,"indecies":[{"keyPath":"title","name":"title"}],"keyPath":"id","name":"note"}]
["store_setting",{"name":"setting"}]
["stores",["note","setting"]]
["version",2]
{"store":"note"}
[1,{"id":1,"tags":["a","b"],"title":"hello"}]
[2,{"bigInt":9007199254740991,"bytes":{"$Blob":"AQID"},"date":{"$Timestamp":"2026-11-02T12:30:00.000Z"},"double":4.5,"false":false,"id":2,"int":-3,"list":[1,[2,"three"],{},[]],"nested":{"done":true,"empty":{}},"null":null,"text":"été ✓","title":"world","true":true}]
{"store":"setting"}
["escaped_at",{"$":{"$":{"@Timestamp":"not a timestamp"}}}]
["escaped_dollar",{"$":{"$blob":"not a blob"}}]
["theme","dark"]
''');

/// The `$` sdb export (`sdb_export` and `type_prefix`).
///
/// `test/data/sdb_dollar_export1.jsonl`.
final sdbDollarExport1Jsonl = _lf(r'''
{"sdb_export":1,"sembast_export":1,"type_prefix":"$","version":1}
{"store":"_main"}
["store_note",{"autoIncrement":true,"indecies":[{"keyPath":"title","name":"title"}],"keyPath":"id","name":"note"}]
["store_setting",{"name":"setting"}]
["stores",["note","setting"]]
["version",2]
{"store":"note"}
[1,{"id":1,"tags":["a","b"],"title":"hello"}]
[2,{"bigInt":9007199254740991,"bytes":{"$Blob":"AQID"},"date":{"$Timestamp":"2026-11-02T12:30:00.000Z"},"double":4.5,"false":false,"id":2,"int":-3,"list":[1,[2,"three"],{},[]],"nested":{"done":true,"empty":{}},"null":null,"text":"été ✓","title":"world","true":true}]
{"store":"setting"}
["escaped_at",{"$":{"$":{"@Timestamp":"not a timestamp"}}}]
["escaped_dollar",{"$":{"$blob":"not a blob"}}]
["theme","dark"]
''');
