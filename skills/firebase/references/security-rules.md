# Security Rules — CEL patterns and testing

Firestore/Storage Security Rules are written in CEL. They are evaluated server-side on every direct
client request, and they are the access-control layer — there is no app server in the trust path by
default. Rules are **not** query filters: a query is rejected entirely unless the rules can prove
every matched document is allowed.

## Structure and granular methods

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /posts/{postId} {
      // read  = get + list ; write = create + update + delete
      allow get:    if isOwner();
      allow list:   if request.auth != null;   // pair with a constrained query
      allow create: if isValidNewPost();
      allow update: if isOwner() && ownerUnchanged();
      allow delete: if isOwner();
    }
  }
}
```

Split `get` from `list` and `create` from `update` so a permissive query path can't leak documents a
single-doc read would block, and so create-time validation differs from edit-time validation.

## Reusable functions

```javascript
function signedIn()  { return request.auth != null; }
function isOwner()   { return signedIn() && resource.data.ownerId == request.auth.uid; }
function isAdmin()   { return signedIn() && request.auth.token.admin == true; } // custom claim
function ownerUnchanged() {
  return request.resource.data.ownerId == resource.data.ownerId; // immutable field
}
```

- `resource.data` = the existing stored document.
- `request.resource.data` = the incoming write (what the doc will become).
- `request.auth.uid` = authenticated user id; `request.auth.token.<claim>` = custom claims.

## RBAC via custom claims

Custom claims are the cheapest role check — they live in the token, so no extra read.

```javascript
match /admin/{doc=**} {
  allow read, write: if isAdmin();
}
```

Set them server-side only:

```ts
import { getAuth } from "firebase-admin/auth";
await getAuth().setCustomUserClaims(uid, { admin: true, plan: "pro" });
// Claims refresh on the client's next ID-token refresh, not instantly.
```

## Cross-document checks with get() / exists()

When the role lives in another document rather than a claim:

```javascript
function memberRole(orgId) {
  return get(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data.role;
}
match /orgs/{orgId}/projects/{projectId} {
  allow write: if memberRole(orgId) in ['owner', 'editor'];
}
```

Each `get()`/`exists()` is a billed read and counts against the rule-evaluation lookup limit per
request — keep them shallow and prefer custom claims for hot paths.

## Write validation

```javascript
allow create: if signedIn()
  && request.resource.data.ownerId == request.auth.uid          // can't forge ownership
  && request.resource.data.keys().hasOnly(['title','body','ownerId','createdAt'])
  && request.resource.data.title is string
  && request.resource.data.title.size() < 200
  && request.resource.data.createdAt == request.time;           // server-stamped
```

`hasOnly` blocks privilege-escalation fields a client might smuggle in.

## Time-based throttling

```javascript
// Allow a write only if the last one on this doc was > 60s ago.
allow update: if request.time > resource.data.lastWrite + duration.value(60, 's');
```

## Testing with @firebase/rules-unit-testing

This is the only library that can mock `request.auth` against the emulator. Run it under the emulator.

```ts
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { setDoc, getDoc, doc } from "firebase/firestore";
import { readFileSync } from "node:fs";

const env = await initializeTestEnvironment({
  projectId: "demo-test",
  firestore: { rules: readFileSync("firestore.rules", "utf8") },
});

const alice = env.authenticatedContext("alice").firestore();
const bob   = env.authenticatedContext("bob").firestore();

// owner can write their own post
await assertSucceeds(setDoc(doc(alice, "posts/p1"), { ownerId: "alice", title: "hi" }));
// someone else cannot read it
await assertFails(getDoc(doc(bob, "posts/p1")));
// unauthenticated is denied
await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "posts/p1")));

await env.cleanup();
```

Run it: `firebase emulators:exec --only firestore "npm test"`.

## Reading firestore-debug.log

When a rule denies a request you didn't expect, the Firestore emulator writes the evaluated
expression and the deny reason to `firestore-debug.log` in the project root. Grep it for the
collection path to see which `allow` failed and which variable was null.

## App Check

App Check attests that a request originated from your genuine app (reCAPTCHA Enterprise on web, Play
Integrity on Android, App Attest on iOS) **before** Rules even evaluate. Enforce it in production so
Rules only ever run for legitimate clients, not scrapers or scripts hitting the REST API directly.
