# Data modeling (MongoDB 8.2)

The rule that overrides every other: **model for the queries you run, not the shape of your data.**
A document should make your common read a single, index-eligible fetch. Everything below is a tool
for getting there.

## The embed-vs-reference decision tree

Walk it top to bottom; the first match wins.

1. **Is the child read together with the parent, almost always?** No → reference.
2. **Is the child set bounded and small (will it stay under a few dozen, forever)?** No → reference.
3. **Is the child shared across multiple parents, or independently/frequently mutated?** Yes →
   reference (embedding would duplicate and drift, or rewrite a big parent per child edit).
4. **Could the embedded array ever push the document toward 16 MB?** Yes → reference or bucket.
5. **Otherwise → embed.** One read, atomic update, no `$lookup`.

The 16 MB cap is the hard backstop. There is no overflow storage; a write that would exceed it
fails. So any one-to-many whose "many" is unbounded (comments, events, line items on a long-lived
cart) is referenced or bucketed, never embedded as a growing array.

### 16 MB math (sanity-check before you embed)

Estimate average child size × expected count, with headroom. A 300-byte comment subdocument hits
16 MB at roughly 52,000 comments — but you are in trouble long before that, because every read of the
parent deserializes the whole array. Treat a few hundred unbounded children as the practical ceiling
for embedding, and reference past it.

## The six patterns, with worked Bad → Good

### 1. Subset

Embed only the hot fields the common view needs; reference the cold rest.

```javascript
// BAD: product carries its full 200-review history; the catalog card read drags all of it.
db.products.insertOne({ _id: ObjectId(), name: "Lamp", reviews: [ /* 200 full reviews */ ] })

// GOOD: embed the 3 most-recent reviews for the card; full set lives in its own collection.
db.products.insertOne({
  _id: ObjectId(), name: "Lamp",
  recentReviews: [ { author: "Ada", stars: 5, text: "…" } /* top 3 only */ ],
  reviewCount: 200
})
db.reviews.insertOne({ _id: ObjectId(), productId: ObjectId(), author: "Ada", stars: 5, text: "…" })
```

### 2. Extended reference

Copy the few joined fields you display so the read needs no `$lookup`.

```javascript
// BAD: every order render does a $lookup into customers just to show a name.
db.orders.insertOne({ _id: ObjectId(), customerId: ObjectId(), amount: NumberDecimal("9.99") })

// GOOD: duplicate the small, slow-changing fields you actually display.
db.orders.insertOne({
  _id: ObjectId(),
  customer: { _id: ObjectId(), name: "Ada", tier: "gold" }, // the display fields, copied
  amount: NumberDecimal("9.99")
})
// Trade-off: when the source name changes, refresh the copies (a background job or change stream).
```

### 3. Bucket

Group N time-ordered events per document instead of one document per event — fewer documents,
smaller indexes, and the array stays bounded by the bucket size.

```javascript
// BAD: one document per sensor reading — millions of tiny docs, huge index.
db.readings.insertOne({ sensorId: ObjectId(), ts: new Date(), value: 21.4 })

// GOOD: one bucket per sensor per hour, capped at N readings; roll to a new bucket past the cap.
db.readings.updateOne(
  { sensorId: ObjectId(), hour: ISODate("2026-06-02T10:00:00Z"), count: { $lt: 200 } },
  { $push: { samples: { ts: new Date(), value: 21.4 } }, $inc: { count: 1 } },
  { upsert: true }
)
// For pure metrics, also consider a native time-series collection (timeField/metaField).
```

### 4. Computed

Store the rollup; update it on write rather than recomputing on every read.

```javascript
// GOOD: keep commentCount on the post; bump it when a comment is inserted.
db.posts.updateOne({ _id: postId }, { $inc: { commentCount: 1 } })
// Read is O(1); you trade a tiny write cost for avoiding a count aggregation per page load.
```

### 5. Outlier

When ~1% of documents break the shape (a celebrity with millions of followers), flag them and
overflow into linked documents so the common case stays small.

```javascript
db.users.insertOne({
  _id: ObjectId(), name: "Ada",
  followerIds: [ /* up to N */ ],
  hasExtras: false            // flip to true and spill into a followers_overflow collection past N
})
```

### 6. Polymorphic

One collection holding several entity shapes, distinguished by a `type` field, sharing an `_id`
space and the indexes they have in common.

```javascript
db.assets.insertMany([
  { _id: ObjectId(), type: "image", url: "…", width: 800, height: 600 },
  { _id: ObjectId(), type: "video", url: "…", durationSec: 42 }
])
// Index the shared fields (type, createdAt); query with the discriminator in the filter.
```

## Schema versioning

Documents in one collection can have different shapes over time. Stamp a `schemaVersion` and migrate
lazily on read/write — no big-bang migration, no downtime.

```javascript
db.users.insertOne({ _id: ObjectId(), schemaVersion: 2, name: "Ada", emails: ["ada@x.io"] })
// App reads: if doc.schemaVersion < 2, upconvert in code (and optionally write the upgraded shape back).
```

## `_id` discipline

- Default `ObjectId` is fine: 12 bytes, roughly time-ordered, generated client- or server-side.
- A natural unique key (a slug, an external id) is a valid `_id` — but it is immutable, so only use
  one that never changes.
- Don't add a second unique field as your "real" key and ignore `_id`; make the meaningful key the
  `_id` or give it its own unique index.
