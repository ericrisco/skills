# Worked model: multi-tenant SaaS / e-commerce

A single end-to-end example. The domain has four entities — **Org**, **User**, **Project**, **Task** —
plus orders to show one-to-many and many-to-many. Follow the order: patterns → keys → GSIs → calls.

## 1. Access patterns

| # | pattern | key condition | type | served by |
|---|---|---|---|---|
| 1 | Get an org by id | `PK=ORG#<id>`, `SK=ORG#<id>` | GetItem | base |
| 2 | Get all users in an org | `PK=ORG#<id>`, `SK begins_with USER#` | Query | base |
| 3 | Get a user by id | `PK=USER#<id>`, `SK=USER#<id>` | GetItem | base |
| 4 | Look up a user by email | `GSI1PK=EMAIL#<email>` | Query | GSI1 (inverted) |
| 5 | Get a user's tasks, newest first | `PK=USER#<id>`, `SK begins_with TASK#`, ScanIndexForward=false | Query | base |
| 6 | List all overdue tasks in an org | `GSI2PK=ORG#<id>#OVERDUE` | Query | GSI2 (sparse) |
| 7 | Get all users on a project (M:N) | `GSI1PK=PROJECT#<id>` | Query | GSI1 (inverted) |

Patterns 1–5 are served by the base table. Only 4, 6, 7 force an index — note how few do.

## 2. Key design (single table `App`)

```text
# Base table key schema
PK (partition)   SK (sort)
-------------------------------------------------------------
ORG#o1           ORG#o1                       Org item
ORG#o1           USER#u1                      User (co-located under org)  -> pattern 2
USER#u1          USER#u1                      User canonical item          -> pattern 3
USER#u1          TASK#2026-06-02T09:00#t1     Task (sorts chronologically) -> pattern 5
USER#u1          TASK#2026-06-01T14:00#t2
```

User items carry GSI attributes for the inverted/sparse lookups; tasks carry the sparse key only when overdue:

```json
{ "PK": "USER#u1", "SK": "USER#u1", "Type": "User",
  "Email": "ana@acme.com", "OrgId": "o1",
  "GSI1PK": "EMAIL#ana@acme.com", "GSI1SK": "USER#u1" }
```

```json
{ "PK": "USER#u1", "SK": "TASK#2026-06-02T09:00#t1", "Type": "Task",
  "DueDate": "2026-05-30", "Status": "OPEN",
  "GSI2PK": "ORG#o1#OVERDUE", "GSI2SK": "2026-05-30#t1" }
```

When a task is completed or not yet overdue, **omit `GSI2PK`** — the sparse index then contains only
overdue tasks, so pattern 6 is a cheap `Query`, never a `Scan`.

## 3. GSI map

| GSI | partition key | sort key | projection | serves |
|---|---|---|---|---|
| GSI1 (inverted/overloaded) | `GSI1PK` | `GSI1SK` | `KEYS_ONLY` + email | patterns 4, 7 |
| GSI2 (sparse) | `GSI2PK` | `GSI2SK` | `INCLUDE` DueDate,Title | pattern 6 |

GSI1 is **overloaded**: an `EMAIL#...` value serves user-by-email; a `PROJECT#...` value (written on a
membership edge item) serves project members. One index, two patterns, under quota.

## 4. Example calls (AWS SDK v3, `@aws-sdk/lib-dynamodb`)

```typescript
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand, GetCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

// Pattern 5: a user's tasks, newest first, page of 25
const tasks = await ddb.send(new QueryCommand({
  TableName: "App",
  KeyConditionExpression: "PK = :pk AND begins_with(SK, :p)",
  ExpressionAttributeValues: { ":pk": "USER#u1", ":p": "TASK#" },
  ScanIndexForward: false,            // descending = newest first
  Limit: 25,
}));

// Pattern 4: user by email (inverted GSI — eventually consistent)
const byEmail = await ddb.send(new QueryCommand({
  TableName: "App",
  IndexName: "GSI1",
  KeyConditionExpression: "GSI1PK = :e",
  ExpressionAttributeValues: { ":e": "EMAIL#ana@acme.com" },
}));

// Pattern 6: overdue tasks across the org (sparse GSI — only overdue items are present)
const overdue = await ddb.send(new QueryCommand({
  TableName: "App",
  IndexName: "GSI2",
  KeyConditionExpression: "GSI2PK = :o",
  ExpressionAttributeValues: { ":o": "ORG#o1#OVERDUE" },
}));
```

## 5. Pagination loop (1 MB page limit)

```typescript
let cursor: Record<string, unknown> | undefined;
const all = [];
do {
  const page = await ddb.send(new QueryCommand({
    TableName: "App",
    KeyConditionExpression: "PK = :pk AND begins_with(SK, :p)",
    ExpressionAttributeValues: { ":pk": "USER#u1", ":p": "ORDER#" },
    ExclusiveStartKey: cursor,
  }));
  all.push(...(page.Items ?? []));
  cursor = page.LastEvaluatedKey;     // absent => done
} while (cursor);
```

## 6. Many-to-many via adjacency list

A user belongs to many projects; a project has many users. Store the edge so both directions Query:

```text
PK = USER#u1      SK = PROJECT#p9     (GSI1PK = PROJECT#p9, GSI1SK = USER#u1)
```

- "projects for a user" → base `Query PK=USER#u1, SK begins_with PROJECT#`.
- "users on a project" → GSI1 `Query GSI1PK=PROJECT#p9` (pattern 7).

## 7. Time-series & leaderboard

- **Time-series**: PK = `SENSOR#<id>#<yyyy-mm>` (bucket by month to bound partition size), SK = ISO
  timestamp. Range queries slice by time; monthly buckets keep any single partition under the heat ceiling.
- **Leaderboard**: a sparse/overloaded GSI with PK = `BOARD#<id>`, SK = zero-padded score
  (`0000420#user`). `Query` descending = top-N. Pad numerically so lexical sort matches numeric sort.
