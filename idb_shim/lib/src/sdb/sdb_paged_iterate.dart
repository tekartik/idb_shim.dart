import 'dart:math';

import 'package:idb_shim/src/common/common_paged_query.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/cursor_utils.dart';

import 'import_idb.dart' as idb;

/// Rows read per query when reading through a native paged query.
///
/// A cursor is walked row by row, a paged implementation has to read a chunk
/// at a time: small enough to stop early cheaply, big enough to keep the
/// number of queries low.
const sdbPagedIterateChunkSize = 200;

/// Rows of a range read through an implementation able to page natively,
/// chunk by chunk instead of by walking a cursor.
///
/// The stream is lazy: a chunk is only read when its first row is asked for,
/// so a consumer stopping early (or a limit) does not read the rest.
///
/// A chunk is read with an sql-like offset, so the rows must not move while
/// the stream is read. That holds for what a cursor row can do (update its
/// own value in place, which changes neither the record count nor the primary
/// key order), but an update changing the index key of a record being read
/// through an index reorders it, exactly like it would invalidate a live
/// cursor.
Stream<IdbCursorRow> sdbPagedRowStream({
  required IdbPagedQuerySupport paged,
  idb.KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
  int chunkSize = sdbPagedIterateChunkSize,
}) async* {
  var start = offset ?? 0;
  var read = 0;
  while (true) {
    var wanted = limit == null ? chunkSize : min(chunkSize, limit - read);
    if (wanted <= 0) {
      return;
    }
    var rows = await paged.pagedRowList(
      range: range,
      direction: direction,
      offset: start + read,
      limit: wanted,
    );
    if (rows.isEmpty) {
      return;
    }
    for (var row in rows) {
      read++;
      yield row;
    }
    if (rows.length < wanted) {
      // Short chunk, the end is reached.
      return;
    }
  }
}

/// Iterate a range through an implementation able to page natively, see
/// [sdbPagedRowStream].
///
/// [handleRow] returns false to stop the iteration, as a cursor row handler
/// does.
Future<void> sdbPagedIterate({
  required IdbPagedQuerySupport paged,
  required FutureOr<bool> Function(IdbCursorRow row) handleRow,
  idb.KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
  int chunkSize = sdbPagedIterateChunkSize,
}) async {
  var stream = sdbPagedRowStream(
    paged: paged,
    range: range,
    direction: direction,
    offset: offset,
    limit: limit,
    chunkSize: chunkSize,
  );
  await for (var row in stream) {
    var result = handleRow(row);
    var doContinue = result is Future<bool> ? await result : result;
    if (!doContinue) {
      return;
    }
  }
}

/// Delete the rows of a range through an implementation able to page
/// natively, reading the keys only (the values are not needed to delete) and
/// deleting them chunk by chunk.
///
/// Deleting a chunk moves the rows that follow it to the same offset, so
/// unlike [sdbPagedRowStream] the offset stays put between chunks.
Future<void> sdbPagedDelete({
  required IdbPagedQuerySupport paged,
  required Future<void> Function(Object primaryKey) deleteKey,
  idb.KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
  int chunkSize = sdbPagedIterateChunkSize,
}) async {
  var deleted = 0;
  while (true) {
    var wanted = limit == null ? chunkSize : min(chunkSize, limit - deleted);
    if (wanted <= 0) {
      return;
    }
    var rows = await paged.pagedKeyRowList(
      range: range,
      direction: direction,
      offset: offset,
      limit: wanted,
    );
    if (rows.isEmpty) {
      return;
    }
    for (var row in rows) {
      await deleteKey(row.primaryKey);
      deleted++;
    }
    if (rows.length < wanted) {
      // Short chunk, everything left was deleted.
      return;
    }
  }
}
