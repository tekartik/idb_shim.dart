# SDB - Iterate

The `iterate` method lets you walk over records one at a time using a cursor. Unlike `findRecords`, which loads all matching records into memory, `iterate` processes each record in the callback as the cursor advances — making it efficient for large datasets and suitable for in-place updates.

## Store iterate

```dart
await bookStore.iterate(db, onRow: (row) {
  // process row ...
  return true; // return false to stop early
});
```

The `onRow` callback receives an `SdbCursorRow` and must return `true` to continue or `false` to stop iteration. The callback may be `async`.

### Stopping early

```dart
var found = false;
await bookStore.iterate(db, onRow: (row) async {
  // do some work ...
  found = true;
  return false; // stop after the first match
});
```

### Updating records in place

To update records during iteration, pass `mode: SdbTransactionMode.readWrite` and call `row.update()` with the new value.

```dart
await bookStore.iterate(
  db,
  mode: SdbTransactionMode.readWrite,
  onRow: (row) async {
    await row.update({'status': 'archived'});
    return true;
  },
);
```

### Using options

Use `SdbFindOptions` to limit, offset, filter, or set boundaries on the iteration. The options type parameter matches the store's key type.

```dart
// Iterate only the first 10 records
await bookStore.iterate(
  db,
  options: SdbFindOptions(limit: 10),
  onRow: (row) {
    // ...
    return true;
  },
);

// Iterate records with keys between 100 and 200 (exclusive upper bound)
await bookStore.iterate(
  db,
  options: SdbFindOptions(
    boundaries: SdbBoundaries(SdbLowerBoundary(100), SdbUpperBoundary(200)),
  ),
  onRow: (row) {
    // ...
    return true;
  },
);
```

### Iterating inside an existing transaction

You can pass a transaction instead of the database. The transaction mode must be compatible (i.e. `readWrite` if you intend to call `row.update()`).

```dart
await db.inStoreTransaction(bookStore, SdbTransactionMode.readWrite, (txn) async {
  await bookStore.iterate(txn, onRow: (row) async {
    await row.update({'migrated': true});
    return true;
  });
});
```

## Index iterate

Index `iterate` works the same way but uses `SdbIndexCursorRow`, which carries the index key type information. The boundaries of the `options` apply to the index key, so type them with the index key type (`SdbFindOptions<String>` below); options typed with the store key type are still accepted.

```dart
var bookStore = SdbStoreRef<int, SdbModel>('books');
var authorIndex = bookStore.index<String>('author');

await authorIndex.iterate(db, onRow: (row) {
  // ...
  return true;
});
```

### Updating via an index cursor

```dart
await authorIndex.iterate(
  db,
  mode: SdbTransactionMode.readWrite,
  onRow: (row) async {
    await row.update({'verified': true});
    return true;
  },
);
```

### Index boundaries

```dart
// Authors from 'A' (included) to 'M' (excluded)
await authorIndex.iterate(
  db,
  options: SdbFindOptions<String>(
    boundaries: SdbBoundaries(SdbLowerBoundary('A'), SdbUpperBoundary('M')),
  ),
  onRow: (row) {
    // ...
    return true;
  },
);
```

### Limiting index iteration

```dart
// Iterate only the first 5 records as ordered by the index
await authorIndex.iterate(
  db,
  options: SdbFindOptions(limit: 5),
  onRow: (row) {
    // ...
    return true;
  },
);
```

## Key points

- Return `true` to continue, `false` to stop early. If `onRow` throws, the iteration stops and `iterate` completes with that error.
- `row.update()` encodes the value like `put` (timestamps, blobs) and the change listeners (`onSnapshot`, `onSnapshots`...) are notified.
- The default transaction mode is `readOnly`. Use `mode: SdbTransactionMode.readWrite` when calling `row.update()`.
- **Do not perform non-database async operations** inside the callback — the same rules as for transactions apply.
- For simple read-only queries that fit in memory, prefer `findRecords`. Use `iterate` when you need to update records in place or want to avoid loading all results at once.