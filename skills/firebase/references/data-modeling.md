# Data modeling — denormalization, sharding, pagination, indexes

Firestore is a NoSQL document store. You pay for and wait on reads, so the unit of design is the read
path, not the normalized entity. No joins exist; you either denormalize or you fan out.

## Denormalization and fan-out

Copy the few fields a screen needs onto the document that screen reads, and update the copies on
write. Example: a feed shows `authorName` next to each post.

```ts
// Write path keeps the copy in sync (a small batch, or a Cloud Function on the user doc).
const batch = writeBatch(db);
batch.set(doc(db, "posts", postId), { authorId, authorName: user.displayName, body });
await batch.commit();
```

Fan-out write: when one event must appear in many places (a message into every member's inbox), write
N documents in a batch (max 500 ops) or trigger a Cloud Function to do the fan-out asynchronously.

## Sharded counters

A single document tolerates ~1 sustained write/sec. A "likes" counter on a viral post will exceed
that. Spread writes across N shard docs and sum on read.

```ts
const N = 10;
// increment a random shard
await updateDoc(doc(db, "posts", postId, "shards", String(Math.floor(Math.random() * N))), {
  count: increment(1),
});
// read = sum of shards
const shards = await getDocs(collection(db, "posts", postId, "shards"));
const total = shards.docs.reduce((s, d) => s + d.data().count, 0);
```

Pick N to cover peak writes/sec (each shard absorbs ~1/sec).

## Avoiding hotspots

Sequential IDs and monotonically increasing indexed fields (auto-increment, `Date.now()` written to an
indexed field at high rate) concentrate writes on one index range. Use Firestore's scattered auto-IDs
(`addDoc` / `doc(collection(db,'x'))`), and if you must index a timestamp at high write rate, add a
sharding prefix to spread the index.

## Pagination with cursors

Don't use numeric offsets (Firestore still reads the skipped docs). Use cursors.

```ts
const first = query(collection(db, "posts"), orderBy("createdAt", "desc"), limit(20));
const snap = await getDocs(first);
const last = snap.docs[snap.docs.length - 1];
const next = query(collection(db, "posts"), orderBy("createdAt", "desc"), startAfter(last), limit(20));
```

## Aggregation

For counts/sums without reading every doc, use server-side aggregation:

```ts
import { getCountFromServer } from "firebase/firestore";
const c = await getCountFromServer(query(collection(db, "posts"), where("ownerId", "==", uid)));
c.data().count; // billed as a small number of reads, not one-per-doc
```

## Collection-group queries

To query the same-named subcollection across all parents (every `messages` subcollection at once):

```ts
import { collectionGroup } from "firebase/firestore";
const recent = query(collectionGroup(db, "messages"), orderBy("createdAt", "desc"), limit(50));
```

This needs a collection-group composite index (declared in `firestore.indexes.json`) and Rules that
match the subcollection path with a wildcard.

## Composite index design

A query that filters/ranges on one field and orders by another needs a composite index. Firestore's
error in production gives you a one-click link to create it, but you should commit it to source.

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy with `firebase deploy --only firestore:indexes`. The emulator runs queries without these
indexes, so "works locally, fails in prod with *requires an index*" is the expected gap — keep this
file in sync and deploy it before shipping new queries.

## Query constraint caps

- `in`, `not-in`, `array-contains-any`: up to ~30 values per query.
- A single range/inequality filter applies to one field; combine with other filters via composite
  indexes. There is no `OR` across different fields without `or()` + the matching indexes.
