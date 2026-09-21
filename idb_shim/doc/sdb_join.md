# SDB - Join

`joinIterate` walks the records of a store together with the records they
reference in another store. It is the equivalent of an sql `LEFT JOIN` on a
field holding the primary key of another table: instead of reading a record,
then reading the one it points at, then the next one, you get both sides in
one iteration, and the joined records are read once even when several records
point at the same one.

Like [`iterate`](sdb_iterate.md), it is a cursor-style API: rows are handed
out one at a time, so the whole result never has to be held in memory and
stopping early stops reading.

## Joining two stores

```dart
var authorStore = SdbStoreRef<int, SdbModel>('author');
var bookStore = SdbStoreRef<int, SdbModel>('book');
// A book value looks like {'title': 't1', 'authorId': 1}

await bookStore.joinIterate<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  onRow: (row) {
    print('${row.record.value['title']} by '
        '${row.joinedRecord?.value['name']}');
    return true; // return false to stop early
  },
);
```

`joinKeyPath` is a field path in the iterated record value (dot separated for
a nested field, `'ref.authorId'`); the value found there is used as the
primary key in the target store. Leave it out to use the primary key of the source
record itself as the join key.

`target` says what the join key is matched against, and is **exactly one**
thing by construction — a store, on its primary key, or an index, on its index
key. Build it with `asJoinTarget` on either ref, or with
`SdbJoinTarget.store(...)` / `SdbJoinTarget.index(...)`. Passing neither or
both is a compile error, not a run time one.

Each `SdbJoinRow` carries:

- `record`: the record of the iterated (source) store, always there;
- `joinedRecord`: the record it references, `null` when there is none — this
  is a left join, see below;
- `joinKey`: the raw value read at `joinKeyPath`, `null` when the source
  record has no value there.

The iteration runs in a single transaction covering both stores. Pass a
transaction instead of the database to join inside an existing one — it must
cover both stores.

## Joining from an index — the shape to prefer

When the join key path is indexed, join from the index instead: the index key
*is* the join key, so there is no key path at all, and an implementation able
to join natively reads the key straight from the index instead of out of every
stored value.

```dart
var bookAuthorIndex = bookStore.index<int>('authorId');

await bookAuthorIndex.joinIterate<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  onRow: (row) {
    print('${row.record.value['title']} by '
        '${row.joinedRecord?.value['name']}');
    return true;
  },
);
```

Rows come out in **index key order** (so here, grouped by author), not in
primary key order, and a record with no index key is not in the index at all,
so it never shows up. `options` then applies to the index key: its boundaries
narrow the iteration to a range of authors.

## One to many, with an index target

A target built from a **store** matches the join key against a primary key, so
at most one record. A target built from an **index** matches it against that
index, so **any number** of records: the source record then gives one row per
match, the way an sql join does.

```dart
var commentPostIndex = commentStore.index<int>('postId');

// Every post with each of its comments. A post with three comments gives
// three rows; a post with none gives one row with a null joinedRecord.
await postStore.joinIterate<int, SdbModel>(
  db,
  target: commentPostIndex.asJoinTarget,
  // No joinKeyPath: the post primary key is the join key.
  onRow: (row) {
    print('${row.record.value['title']}: '
        '${row.joinedRecord?.value['text']}');
    return true;
  },
);
```

The two sides compose freely: a store or an index target on the joined side,
a store or an index on the iterated side. Iterating the child index instead
gives the same relation read the other way round, grouped by parent:

```dart
// Every comment with its post, comments of a post being consecutive.
await commentPostIndex.joinIterate<int, SdbModel>(
  db,
  target: postStore.asJoinTarget,
  onRow: (row) => true,
);
```

## Source and target

A join is a **source** (what is iterated, and where its join key comes from)
and a **target** (what the join key is matched against). Both can be a store
or an index, and both are built with a getter:

| | store | index |
|---|---|---|
| source | `store.asJoinSourceAt('field')` — join key in a field<br>`store.asJoinSource` — join key is its primary key | `index.asJoinSource` — join key is its index key, walked in index key order |
| target | `store.asJoinTarget` — matched on its primary key, at most one record | `index.asJoinTarget` — matched on its index key, any number of records |

The methods on a store and on an index are sugar that builds the source for
you; when you need to hold the shape of a join in a variable — a list
controller, a repository method — take a `SdbJoinSource` and a
`SdbJoinTarget`:

```dart
Future<void> report<K extends SdbKey, V extends SdbValue, SK extends SdbKey>(
  SdbDatabase db,
  SdbJoinSource<K, V, SK> source,
  SdbJoinTarget<int, SdbModel> target,
) => source.joinIterate(db, target: target, onRow: (row) => true);

await report(db, bookStore.asJoinSourceAt('authorId'), authorStore.asJoinTarget);
await report(db, bookAuthorIndex.asJoinSource, authorStore.asJoinTarget);
```

The third type parameter of a source is the key it is walked by — the primary
key of a store, the index key of an index — which is what `SdbFindOptions`
applies to, so the boundaries of a join always have the type of the key that
is actually walked.

## Left join and inner join

By default this is a **left join**: a record whose join key is null, or whose
join key matches no record, is still handed out with a null `joinedRecord`.
Pass `inner: true` in the join options to skip those rows.

```dart
// Only the books that do have an existing author.
await bookStore.joinIterate<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  joinOptions: const SdbJoinFindOptions(inner: true),
  onRow: (row) => true,
);
```

## One side only

A join hands out one of three things, and **only reads what it hands out**:

| what you want | iterate | list |
| --- | --- | --- |
| both sides | `joinIterate` | `findJoinRows` |
| the source records | `joinIterateRecords` | `findJoinRecords` |
| the referenced records | `joinIterateJoinedRecords` | `findJoinedRecords` |

The two one-sided shapes hand out a plain `SdbRecordSnapshot`, never null, so
there is no flag to remember and nothing to null check.

`joinIterateRecords` gives **one entry per source record**, however many rows
it would give: joining on an index, a record matching three records is handed
out once, not three times. With `inner: true` it is a semi join, an sql
`WHERE EXISTS`:

```dart
// The books that do have an existing author, the authors not being read.
var books = await bookStore.findJoinRecords<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  joinOptions: const SdbJoinFindOptions(inner: true),
);
```

`joinIterateJoinedRecords` gives the referenced records; it is always inner
(there is nothing to hand out for a row matching nothing), so what you get is
never null:

```dart
// All the authors actually referenced by a book, each one once.
var authors = await bookStore.findJoinedRecords<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  joinOptions: const SdbJoinFindOptions(distinct: true),
);
for (var author in authors) {
  print(author.value['name']);
}
```

## Distinct

`distinct` (false by default) only expands the first source record of each
join key, the records without a join key counting as one group. It is what you
want when you iterate a store only to reach the records it references. Joining
on an index, that first record still gives one row per match.

## Options, offset and limit

Every join method takes **two** options, which describe two different things:

- `options`, the usual `SdbFindOptions` on the iterated side: `boundaries`,
  `filter`, `descending`, `offset`, `limit`;
- `joinOptions`, a `SdbJoinFindOptions` saying how the two sides are joined:
  `distinct`, `inner`, `chunkSize`.

They are separate types on purpose — a `SdbJoinFindOptions` is not a
`SdbFindOptions` — and both are optional. Both are shared as is with the
runner resolving the join.

`offset` and `limit` apply to what is handed out, i.e. **after** `inner` and
`distinct` dropped any row, the way an sql `LIMIT` applies after the join —
and, for `joinIterateRecords`, after the rows of one source record collapsed
into one.

```dart
await bookStore.joinIterate<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  options: SdbFindOptions(offset: 10, limit: 20),
  joinOptions: const SdbJoinFindOptions(inner: true),
  onRow: (row) => true,
);
```

## Getting a list or a count

`findJoinRows` returns the rows as a list, `joinCount` returns how many rows
`joinIterate` would hand out. Both take the same options.

```dart
var rows = await bookStore.findJoinRows<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  joinOptions: const SdbJoinFindOptions(inner: true),
);
var count = await bookStore.joinCount<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinKeyPath: 'authorId',
  joinOptions: const SdbJoinFindOptions(inner: true),
);
```

Without `distinct` nor `inner`, and joining on a store, every record gives one
row, so `joinCount` is just the record count and costs nothing more than
`count`. Otherwise rows are dropped (or, with an index target, added) in a way only
a scan can tell, so the join is run, reading as little as it can (neither side
being handed out).

## Implementation notes

A join is resolved in one of two ways, transparently:

- **Natively**, when the implementation can join in its own backend. This is
  what `idb_sqflite` does: the join becomes a single sql `LEFT JOIN` (or
  `INNER JOIN`) per chunk of rows, with `offset`, `limit`, `inner` and the key
  range pushed down to sql.
- **Generically**, by walking a cursor on the iterated store and reading each
  joined record, a record being read once for the whole iteration however many
  source records point at it.

Both paths hand out exactly the same rows, in the same order.

### Index the join key path

`idb_sqflite` reads the join key in three different ways, and **an index on
the join key path is what makes it fast**:

- **From the index itself**, when iterating an index (`index.joinIterate`):
  the index key is the join key, so nothing has to be looked up to find it.
  This is the shape to aim for.
- **From an index table**, when iterating a store whose `joinKeyPath` is
  indexed: one index seek per row, and no value is parsed to find the key.
- **From the stored value** otherwise, with `json_extract`, which parses the
  json of every record scanned.

The joined side is an index seek either way: on the primary key with
a store target, on the index with an index target (through the view that joins the
index table back to its store).

```dart
// Give the iterated store an index on the join key path.
var bookStore = SdbStoreRef<int, SdbModel>('book');
var bookAuthorIndex = bookStore.index<int>('authorId');

schema: SdbDatabaseSchema(
  stores: [
    authorStore.schema(),
    bookStore.schema(
      indexes: [bookAuthorIndex.schema(keyPath: 'authorId')],
    ),
  ],
),
```

The index is only used to read the key; you keep using `joinIterate` exactly
the same way, and the rows are identical either way.

It falls back to the generic (dart) path when the joined store has a composite
primary key, when a join key would be a composite (list) key, when a `filter`
is used (a filter runs in dart, so the limit cannot be pushed down), or — for
the `json_extract` path only — when sqlite has no json1 functions (compiled in
by default only since sqlite 3.38, so an older android system sqlite can be
missing them). Neither indexed path needs json1 at all.

Two records can share an index key, and the order of such a tie is not
specified: an index cursor sorts on the index key alone, so iterating an index
backwards keeps the tie ascending on some implementations and reverses it on
others. Only the index key order is guaranteed.

## Key points

- Return `true` to continue, `false` to stop early.
- The default transaction mode is `readOnly`, pass
  `mode: SdbTransactionMode.readWrite` to write during the iteration.
- **Do not perform non-database async operations** inside the callback — the
  same rules as for transactions apply.
- `options` (`SdbFindOptions`) says what is read on the iterated side,
  `joinOptions` (`SdbJoinFindOptions`) says how the two sides are joined; they
  are two separate types and every method takes both.
- `target` is one required `SdbJoinTarget`: `store.asJoinTarget` matches on a
  primary key, `index.asJoinTarget` on an index key.
- `offset`/`limit` apply after `inner` and `distinct`, like an sql `LIMIT`.
- `SdbJoinRow.record` is never null; `joinedRecord` is, because a left join
  hands out the rows matching nothing.
- Only need one side? `joinIterateRecords`/`findJoinRecords` for the source
  records, `joinIterateJoinedRecords`/`findJoinedRecords` for the referenced
  ones — both hand out a plain record, never null, and the other side is not
  read at all.
- Index the join key path and join from the index (`index.joinIterate`): it is
  the fastest shape, and the only one that says so in the API.
- An index target matches against an index rather than a primary key, so a source
  record can give several rows: that is the one to many shape.
- For a Flutter list showing both sides, see `SdbJoinListView` in
  `tekartik_app_sdb_ui_flutter`.
