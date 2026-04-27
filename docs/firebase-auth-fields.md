# Firebase Auth — Fields available for schema design

Audience: whoever is designing the Firestore schema. This doc lists what Firebase Auth gives us "for free" on every signed-in user, so you can decide what to **mirror** into Firestore vs. what to **read live** from `FirebaseAuth.instance.currentUser`.

Auth providers we currently support: **Email/Password** and **Google**. (Apple is on hold — requires $99/yr Apple Developer Program. Anonymous and Facebook were considered and dropped.)

---

## 1. The `User` object

Every authenticated session gives the client a `User` object (Dart type: `firebase_auth.User`). These fields are populated by Firebase based on the provider used.

| Field | Type | Always present? | Source / notes |
|---|---|---|---|
| `uid` | `String` | **Yes, always** | Firebase-issued, immutable, globally unique within our project. **This is the primary key for users.** Use it as the doc ID in `users/{uid}`. |
| `email` | `String?` | Yes for Email/Password and Google | Verified for Google; may be unverified for Email/Password until the user clicks the verification link. See `emailVerified` below. |
| `emailVerified` | `bool` | Yes | `true` for Google sign-ins automatically. For Email/Password, `false` until the user opens the verification email we send. Useful for gating sensitive actions. |
| `displayName` | `String?` | Sometimes | Auto-populated from Google profile. For Email/Password, populated only if our signup flow calls `updateDisplayName(...)`. Can be edited later by the user. |
| `photoURL` | `String?` | Sometimes | Set by Google to a Google-hosted profile image URL. Empty for Email/Password unless we set it. URL is stable but Google can rotate it. |
| `phoneNumber` | `String?` | No (we don't use phone auth) | Always `null` for our providers. |
| `isAnonymous` | `bool` | Yes | Always `false` for us — we don't use anonymous auth. |
| `tenantId` | `String?` | No | We don't use multi-tenancy. Always `null`. |
| `metadata.creationTime` | `DateTime?` | Yes | Account creation timestamp. Useful for "joined on" displays. |
| `metadata.lastSignInTime` | `DateTime?` | Yes | Updated on every successful sign-in. |
| `providerData` | `List<UserInfo>` | Yes | Array of one entry per linked provider. Each entry has `providerId` (`"password"`, `"google.com"`, etc.) plus a copy of `uid`/`email`/`displayName`/`photoURL`/`phoneNumber` from that provider. Useful for "Connected accounts" UI. |
| `refreshToken` | `String` | Yes (client only) | Used internally by the SDK; not for app code. |

### What's *not* in the `User` object

These are common things people expect Firebase Auth to track but it does **not**:

- **Username / handle** — Firebase has `displayName` (free-form) but no unique-username concept. If we want `@sarahchen`, that's our problem to design.
- **Friends list / social graph** — Firestore's job.
- **Bio, location, preferences** — Firestore's job.
- **Printer ID(s) the user owns** — Firestore's job.
- **FCM push token** — fetched separately via `firebase_messaging`, then stored in Firestore.
- **App-specific roles/permissions** — can be put in Firebase Auth as **custom claims** (set server-side via Admin SDK, max 1KB, included in every ID token), but for anything more than a simple `role: "admin"` flag, store in Firestore.

---

## 2. ID tokens (relevant for Cloud Functions / backend)

When the app talks to a Cloud Function or backend service, it sends an **ID token** (JWT). The token's claims include:

```
{
  "iss": "https://securetoken.google.com/printimate-XXXXX",
  "aud": "printimate-XXXXX",
  "auth_time": 1714000000,
  "user_id": "xCqZ...",         // same as uid
  "sub": "xCqZ...",
  "iat": 1714000000,
  "exp": 1714003600,             // 1-hour expiry, auto-refreshed by SDK
  "email": "alice@example.com",
  "email_verified": true,
  "firebase": {
    "identities": {
      "google.com": ["1080..."],
      "email": ["alice@example.com"]
    },
    "sign_in_provider": "google.com"
  }
}
```

In Firestore security rules, you can reference these as `request.auth.uid`, `request.auth.token.email`, `request.auth.token.email_verified`, etc.

---

## 3. What we recommend mirroring into Firestore

Firebase Auth is a *credential* store, not a profile store. It has tight rate limits on reads (the Admin SDK is ~3K queries/sec aggregate — fine for sign-in, bad for "fetch 50 friends' display names"). So mirror anything you want to **query** or **show in someone else's view** into Firestore.

Suggested `users/{uid}` doc shape (schema designer to confirm):

```jsonc
{
  "uid": "xCqZ...",                    // mirror of auth uid (also the doc ID)
  "displayName": "Sarah Chen",          // mirror of auth.displayName, editable
  "email": "sarah@example.com",         // mirror, lowercased for search
  "photoURL": "https://...",            // mirror or our own upload
  "createdAt": <serverTimestamp>,       // mirror auth.metadata.creationTime
  "handle": "sarahc",                   // app-specific, must be unique — Firestore problem
  "printerIds": ["PRT-98765"],          // pairing relationship
  "fcmTokens": ["..."],                 // push notification targets, one per device
  "friendCount": 12,                    // denormalized, optional
  "lastSeenAt": <serverTimestamp>       // updated on app open
}
```

**Write strategy:** populate this doc on first sign-in (a Cloud Function listening to `onCreate` of an Auth user, or a client-side `setDoc` with `merge: true` after sign-in). After that, any auth-side change (e.g., user edits `displayName`) should also write through to Firestore.

**Trust model:** the `uid` and `email` fields can be trusted because they come from the verified ID token. Don't trust client-supplied `displayName` for moderation-relevant purposes — use Auth's `displayName` if you need a "real" one.

---

## 4. Identifying users in other docs

When referring to a user from another doc (e.g., a `messages` doc has a sender and recipient), **always store the `uid` only**, not the email or displayName. Names change. Emails change. UIDs do not.

Read pattern: `messages/{id}` has `senderUid` → look up `users/{senderUid}` to render the name. If perf becomes an issue, denormalize the sender's `displayName` and `photoURL` into the message doc at write time (and accept that it'll show stale info if the sender renames).

---

## 5. Edge cases worth knowing

- **Account linking.** A user can sign up with email/password, later link Google. Both providers point at the same `uid`. `providerData` will have two entries. If your schema needs to know "did this user sign in with Google?", check `providerData`, not `email`.
- **Email change.** A user can change their email via `updateEmail()`. The `uid` doesn't change. If you've duplicated email anywhere as an identifier, you'll need to update it.
- **Account deletion.** Calling `user.delete()` removes the auth record. **Firestore docs are not auto-cleaned.** We need either a Cloud Function on `onDelete` or a manual `deleteUser` cloud function that removes both. Plan for this in the schema (e.g., consider what cascade-delete means for messages the user sent).
- **Multi-device sessions.** A user can be signed in on phone + laptop simultaneously. Both clients will see the same `uid`. FCM tokens differ per device — store as an array.
- **Custom claims.** If we ever need `role: "moderator"` or feature flags scoped per user, set them via Admin SDK and read them from `auth.token` in security rules. Don't store them in Firestore — they'd be re-readable and editable by client tampering.

---

## 6. Quick reference: how to read these on the client (Flutter)

```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print(user.uid);                      // primary key
  print(user.email);                    // may be null
  print(user.emailVerified);
  print(user.displayName);              // may be null
  print(user.photoURL);
  print(user.metadata.creationTime);
  for (final p in user.providerData) {
    print('${p.providerId}: ${p.email}');
  }
}
```

To listen for changes (sign-in, sign-out, profile update):
```dart
FirebaseAuth.instance.userChanges().listen((user) { ... });
```

---

## 7. Open questions for the schema designer

1. **Username uniqueness.** Do we want `@handles`? If yes, we need a separate `usernames/{handle}` collection with `uid` as a value, written transactionally with `users/{uid}` to enforce uniqueness.
2. **Email-based friend lookup.** Sarah wants to add Mike by email — do we lookup `users` by email field? If so, we need an index. Storing email lowercased is required.
3. **Soft delete vs. hard delete.** When a user deletes their account, do their old printed messages stay readable to recipients (with sender shown as "Deleted user")? This affects whether `messages.senderUid` is required or nullable.
4. **Printer ownership model.** Is a printer owned by exactly one user, or can it be shared (e.g., a household printer)? Affects whether `printers/{id}.ownerUid` is a single field or an array.

Bring these to whoever is designing the schema; the answers shape several collections.
