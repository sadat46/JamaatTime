# Notification Broadcast System — Implementation Plan

**Scope:** Android-only FCM broadcast system (manual text/image + auto on jamaat change), SuperAdmin-gated, backend-driven.
**Backend:** Firebase Cloud Functions (TypeScript, Gen 2).
**Image source:** Firebase Storage upload **OR** pasted public HTTPS URL.
**Principle:** Reuse every existing primitive (auth, superadmin role, jamaat update flow, local notification service, admin UI skeleton). Never duplicate.

### Revision history
- **rev-5** — fixes applied after fourth review:
  1. **Phase 0.5 no longer has any client-side role writes.** The earlier "if missing, AuthService writes `role: 'superadmin'`" branch is removed — it was a privilege-escalation surface. Role seeding now happens exclusively through two new callables deployed in Phase 3: `bootstrapSuperadminRole` (single-use self-seed gated by a server-side allowlist at `system_config/bootstrap_superadmins`) and `setUserRole({ targetUid, role })` (superadmin-only ongoing role management). Both write to a `role_audit/` trail.
  2. **`AuthService` is now read-only for roles.** `getCurrentUserRole()` reads `users/{uid}.role` only; missing doc returns `UserRole.user` with no silent elevation. The hardcoded `superadminEmails` list is deleted from client code and its authoritative copy lives in `system_config/bootstrap_superadmins` (functions-only).
  3. **Firestore rule for `users/{uid}.role`** explicitly forbids client writes to the `role` field (profile fields remain owner-writable). The rule block is specified in Phase 0.5 step 5 and folded into the Phase 1 rules summary.
  4. **"Seed now" admin-panel button** and the "Complete admin setup" bootstrap UI both call the backend callables — no direct Firestore writes from any screen.
  5. New Firestore collections added to the Phase 1 schema: `system_config/bootstrap_superadmins` and `role_audit/{autoId}`.
  6. **Cross-cutting reuse inventory** fixed: the `jamaat_service.dart` row now accurately notes the one-line extension in Phase 9 (`updatedBy`, `updatedByEmail`, `writeSource`) instead of claiming the file is untouched.

- **rev-4** — fixes applied after third review:
  1. **New Phase 0.5 (Role-Source Unification)** — added as a prerequisite that must land before Phase 3. Introduces a one-time seed script + an `AuthService` patch that auto-writes `users/{uid}.role = 'superadmin'` on first role check for any email-list superadmin. Result: the Firestore role doc is the single authoritative source; the hardcoded email list is demoted to a bootstrap seed only.
  2. Phase 3 `assertSuperAdmin` helper no longer cross-checks the email list — it reads `users/{uid}.role` exclusively, matching the Phase 11 Firestore rule. No more divergence between callable auth and rule auth.
  3. Pre-flight table row for the role source updated to reflect the Phase 0.5 refactor.
  4. Phase 1 comment for `device_tokens/{installationId}` fixed to say the id comes from `FirebaseInstallations.instance.getId()` (was still referring to an FCM-token-hash derivation, contradicting Phase 2).

- **rev-3** — fixes applied after second review:
  1. Phase 11 rule no longer assumes custom claims. It now uses a Firestore `users/{uid}.role` rule helper (`userRole()` / `isAdminOrAbove()`) that matches the app's current `AuthService` role source, so legitimate admin writes are not blocked.
  2. Added an optional Phase 11b as a modify-option that migrates to custom claims properly (callable + Firestore trigger + one-time backfill + client `getIdToken(true)` step) — taken only if the per-write `get()` cost matters.
  3. Phase 1 `notifications.status` enum now includes `"cancelled"` (Phase 7 writes this value on `cancelScheduledBroadcast`).
  4. Phase 2 pubspec block now lists `http: ^1.2.2` (already in the project) and `firebase_app_installations` explicitly.
  5. Phase 2 `installationId` must come from `FirebaseInstallations.instance.getId()` — the FCM-token-hash fallback is removed because FCM tokens rotate and would orphan the `device_tokens` row on every rotation. The "future-proof multi-device" modify-option is rewritten to use the same installationId API for logged-in users.

- **rev-2** — fixes applied after first review:
  1. Phase 7 now routes scheduling through a `scheduleBroadcast` callable — no direct client writes to `scheduled_notifications/**` or `notifications/**`, so Phase 1 rules stand.
  2. Phase 2 FCM init runs **before** the auth gate and writes guest devices to a new `device_tokens/{installationId}` collection, so users who have never logged in still receive `all_users` broadcasts.
  3. Phase 9 moved to Functions v2 (`onDocumentUpdated`) and identity checks now read `after.updatedBy`/`after.writeSource` instead of the never-populated `context.auth`. `JamaatService.saveJamaatTimes()` is extended (one line) to write those fields. Phase 11 rules tighten to prevent client spoofing.
  4. Phase 2 + Phase 5 now explicitly wire the foreground BigPicture path: `imageUrl` is duplicated into the `data` payload, and a new `FcmForegroundRenderer` downloads bytes + builds `BigPictureStyleInformation` so image notifications render when the app is open.
  5. `fcmResponse` schema in Phase 1 is now a union of `{sendMode:'topic', messageId}` vs `{sendMode:'multicast', counts+ids}` to match what `admin.messaging().send()` actually returns for topic sends.
  6. Added a cross-cutting "Code organization" section — per-file responsibility rules, folder layout, 300-line cap, DI for Cloud Functions to keep emulator tests trivial.

---

## Pre-flight Findings (from code inspection)

| Concern | Current state | Implication |
|---|---|---|
| Firebase SDK | `firebase_core 3.14`, `firebase_auth 5.6`, `cloud_firestore 5.6.9` already in `pubspec.yaml` | ✅ Foundation ready |
| FCM | **Not installed** (`firebase_messaging` missing) | Add in Phase 2 |
| Cloud Storage | Not installed | Add in Phase 2 (for admin image upload) |
| Cloud Functions | **No `functions/` directory** | Create in Phase 3 |
| SuperAdmin role | `lib/services/auth_service.dart` → `UserRole.superadmin`. **Today** it reads the hardcoded email list AND `users/{uid}.role`. **After Phase 0.5** the Firestore doc is the single authoritative source everywhere; the email list is demoted to a bootstrap seed. | Reuse with Phase 0.5 refactor |
| Admin UI | `admin_jamaat_panel.dart`, `user_management_screen.dart` exist | Extend pattern, do not re-theme |
| Jamaat data path | `jamaat_times/{cityKey}/daily_times/{dateString}` in `jamaat_service.dart` | Auto-trigger hooks here |
| Local notifications | `notification_service.dart` (flutter_local_notifications) — jamaat reminders | **Remote FCM is a SEPARATE layer**. No edits to this file in Phases 1-9 |
| Project IDs | Firebase project `jaamattime`, Android app `1:148161891333:android:ead88c67f231a4d9f8e06c` | Used for Cloud Functions deploy target |

**Rule for every phase:** each phase ends with a working app, a green build, and a **single git commit** using the phase's commit message below. No phase may break the current jamaat reminder flow.

**Code organization (applies to every phase — flagship cleanliness):**
- One responsibility per file. Flutter: `lib/services/notifications/` subfolder already laid out in Phase 2; `lib/widgets/notifications/` for preview/form pieces; `lib/models/notifications/` for payload classes; `lib/screens/notifications/` for full screens. Cloud Functions: `functions/src/{broadcast,triggers,scheduled,lib}/` with `lib/` for shared helpers (auth, validate, logger, sender).
- No file over ~300 lines — split when approaching. Widgets under 150 lines, pure functions under 50.
- Every new widget takes its data via constructor params (no globals), so each can be rendered in isolation in a widget test.
- Every Cloud Function handler file exports exactly one function + its unit-testable `run(payload, deps)` helper, with Firebase/FCM as injected dependencies — makes emulator tests trivial.
- No business logic in screen files — screens only compose widgets and wire callbacks to services.
- Shared primitives (dedup hash, payload validator, channel constants) live in `lib/` on both sides and are imported, never copy-pasted.

---

## Phase 0 — Foundation Document & Branch

**Goal:** Land this plan and open a tracking branch. No code yet.

Steps:
1. Create branch `feat/notification-broadcast`.
2. Land this file (`NOTIFICATION_BROADCAST_PLAN.md`) on that branch.
3. Add one-line anchor entry in `readme.md` linking to this plan.

**Commit:** `docs(notify): add notification broadcast implementation plan`

**Modify-option (flagship upgrade):** add a tracking issue template at `.github/ISSUE_TEMPLATE/notify-phase.md` so each phase below maps 1:1 to an issue with the test checklist auto-populated.

---

## Phase 0.5 — Role-Source Unification (prerequisite, must land before Phase 3)

**Goal:** Single authoritative source of truth for who is admin/superadmin, with **no client-side role writes anywhere**. Every authorization path — the callable auth guard (Phase 3), the Firestore trigger identity check (Phase 9), and the `jamaat_times` write rule (Phase 11) — reads the same Firestore field. Seeding and role changes happen only through privileged backend paths.

**Why this phase exists:** today `AuthService` grants `UserRole.superadmin` via a hardcoded email fallback even when `users/{uid}.role` is unset. If Phase 11's rule only checks `users/{uid}.role`, an email-fallback user would pass the callable but be denied by the rule. Letting the client self-write `role` to fix that would open a privilege-escalation hole. Correct design: the client never writes `role`; the backend owns all seeding.

Steps:
1. **Server-side bootstrap allowlist.** Create Firestore doc `system_config/bootstrap_superadmins` with `{ emails: ["sadat46@gmail.com", ...], seededAt: serverTimestamp }`. Rules deny all client access; only Cloud Functions can read or write it. Provisioned by a one-time script `functions/scripts/seed-bootstrap-allowlist.ts` run by a developer with admin SDK credentials (or pasted once via the Firebase console).
2. **New callable function `bootstrapSuperadminRole` (deployed in Phase 3):**
   - Requires `context.auth != null`.
   - Reads `context.auth.token.email`.
   - Reads `system_config/bootstrap_superadmins`.
   - If the email is in the allowlist, in a single Firestore transaction:
     - Upsert `users/{uid}` with `{ role: 'superadmin', email, bootstrappedAt: serverTimestamp }`.
     - Remove that email from the allowlist (single-use — re-running does nothing).
     - Append an entry to `role_audit/{autoId}` with `action: 'bootstrap'`, `uid`, `email`, `at`.
   - Otherwise throw `permission-denied`.
   - All calls (success + denial) are also logged to Cloud Logging.
3. **New callable function `setUserRole({ targetUid, role })` (deployed in Phase 3):**
   - `assertSuperAdmin(context)` — the Phase 3 guard.
   - Validates `role in ['user','admin','superadmin']`.
   - Writes `users/{targetUid}.role = role`, appends a `role_audit/` entry.
   - This replaces every direct client-side role write going forward. The "Seed now" button (step 6) and any future admin role-management UI calls this callable, never writes Firestore directly.
4. **Patch `AuthService` to be read-only for roles:**
   - `getCurrentUserRole()` reads **only** `users/{uid}.role`. No writes, ever.
   - If the doc is missing → return `UserRole.user`. No silent elevation from the email list.
   - Delete the hardcoded `superadminEmails` list and all references to it in `AuthService`. The list conceptually moves to the server-side `system_config/bootstrap_superadmins` doc.
5. **Firestore rules for `users/{uid}` (add in Phase 1; preview here because this phase depends on them):**
   ```
   match /users/{uid} {
     allow read:   if request.auth != null && request.auth.uid == uid;
     allow create: if request.auth != null && request.auth.uid == uid
                   && !('role' in request.resource.data.keys());
     allow update: if request.auth != null && request.auth.uid == uid
                   && !('role' in request.resource.data.diff(resource.data).affectedKeys());
     // role field is written ONLY by Cloud Functions (admin SDK bypasses rules).
   }
   match /system_config/{doc} {
     allow read, write: if false;   // functions-only
   }
   match /role_audit/{id} {
     allow read: if isAdminOrAbove();    // defined in Phase 11
     allow write: if false;
   }
   ```
6. **UI bootstrap flow.** If a signed-in user reaches an admin-only screen with no role doc, the app shows a "Complete admin setup" screen with one button that calls `bootstrapSuperadminRole`. On success → `user.getIdToken(true)` to force refresh, re-read role, navigate. On denial → "Not authorized. Contact an existing superadmin." In `user_management_screen.dart`, add a drift banner that lists users whose role might be out of date and a "Re-seed" button that calls `setUserRole({ targetUid, role: 'superadmin' })` — same backend path, no direct writes.

**Tests:**
- Log in as an allowlisted email on a fresh install → hit admin area → press the bootstrap button → verify `users/{uid}.role === 'superadmin'` and the email is removed from `system_config/bootstrap_superadmins`.
- Call `bootstrapSuperadminRole` a second time with the same email → `permission-denied` (single-use worked).
- Non-allowlisted email calls `bootstrapSuperadminRole` → `permission-denied`.
- Unauthenticated call → `unauthenticated`.
- Attempt direct client write of `users/{uid}.role` from browser devtools → blocked by the rule (run both as the owner and as another user).
- Existing superadmin calls `setUserRole` on a teammate → succeeds. Non-superadmin calls it → denied.
- `role_audit/` contains one entry per successful role change.

**Commit:** `refactor(auth): backend-only role seeding + management; AuthService becomes read-only`

**Modify-option:** replace the `bootstrapSuperadminRole` single-use-allowlist pattern with a fully manual bootstrap (developer runs the seed script once against admin SDK, then there is no allowlist and no bootstrap callable at all). Simpler, but loses the "log in on a fresh environment and self-bootstrap" UX — only pick this if you always have CLI admin access when standing up a new environment.

---

## Phase 1 — Firestore Schema & Security Rules

**Goal:** Freeze the data model before any code touches it.

Collections (all new, no edits to existing):

```
notifications/{autoId}
  type:           "text" | "image"
  title:          string
  body:           string
  imageUrl:       string | null
  target:         { kind: "all_users" | "affected_location" | "selected_users" | "role_based", value?: any }
  deepLink:       string | null              // e.g. "/home?highlight=jamaat"
  triggerSource:  "manual" | "auto_jamaat_change"
  createdBy:      uid | "system"
  createdAt:      serverTimestamp
  scheduledFor:   timestamp | null
  status:         "queued" | "sending" | "sent" | "partial" | "failed" | "fallback_text" | "cancelled"
  failureReason:  string | null
  fcmResponse:                               // shape depends on send mode
    | { sendMode: "topic",     messageId: string }                   // topic sends return ONE id
    | { sendMode: "multicast", successCount, failureCount, messageIds[] }   // Phase >10 per-token
    | null
  sendMode:       "topic" | "multicast"      // so history UI can pick the right renderer
  dedupKey:       string                     // hash for auto sends

notification_rules/jamaat_change             (single doc, config)
  autoNotifyOnJamaatChange: bool
  autoNotifyMode:           "text" | "image" | "both" | "off"
  autoNotifyTarget:         "all_users" | "affected_location"
  minChangeMinutes:         int = 1          // ignore changes smaller than this
  cooldownSeconds:          int = 300        // anti-spam between sends for same city
  defaultImageUrl:          string | null    // used when mode = image/both

user_tokens/{uid}                            (logged-in users — tokens keyed by auth uid)
  tokens:     [ { token, platform: "android", deviceId, updatedAt } ]
  topics:     [ "all_users", ... ]           // mirror of subscribed topics
  locale:     string                         // for future localization

device_tokens/{installationId}               (GUEST users — app works without login)
  token:      string
  platform:   "android"
  topics:     [ "all_users" ]
  locale:     string
  updatedAt:  timestamp
  // installationId = FirebaseInstallations.instance.getId() (see Phase 2).
  // Stable across FCM token rotations and across app launches;
  // regenerated only on reinstall / data clear.

scheduled_notifications/{autoId}             (sendLater queue — Phase 7, written ONLY by Cloud Functions)
  payloadRef:  path to draft in notifications/
  fireAt:      timestamp
  claimed:     bool                          // dispatcher claim flag
  createdBy:   uid                           // set server-side from callable context.auth

system_config/bootstrap_superadmins          (Phase 0.5 allowlist, functions-only)
  emails:      [ string ]
  seededAt:    timestamp
  // emails are single-use; bootstrapSuperadminRole removes an email on successful use.

role_audit/{autoId}                          (audit trail for every role change)
  action:      "bootstrap" | "set_role"
  targetUid:   string
  role:        "user" | "admin" | "superadmin"
  actorUid:    string | "system"
  at:          serverTimestamp
```

Firestore rules (add to `firestore.rules`, create if missing):
- `notifications/**`: read allowed for admins+superadmin, **write only from Cloud Functions** (deny all client writes).
- `notification_rules/**`: read admin+superadmin, write superadmin only.
- `user_tokens/{uid}`: read/write own doc only. Functions read all.
- `device_tokens/{installationId}`: create/update allowed for any client (guest-safe); reads restricted to functions.
- `scheduled_notifications/**`: **no client access, read/write only from Cloud Functions** — all scheduling must go through a callable (see Phase 7).
- `users/{uid}`: the `role` field is **never writable from a client**; profile fields are writable by the owner. Exact rule block is in Phase 0.5 step 5 (add it here in `firestore.rules`).
- `system_config/**`: no client access (functions-only).
- `role_audit/**`: read for admins+superadmin, no client writes.

**Commit:** `feat(notify): add firestore schema + rules for notifications, rules, user_tokens`

**Modify-option:** add a `notifications/_counters/daily/{yyyymmdd}` shard pattern now to enable per-day rate-limit reads in O(1) instead of aggregation queries later.

---

## Phase 2 — App: FCM Receive Layer (Android)

**Goal:** The app receives push notifications in all 3 states and routes deep links. No send yet.

Steps:
1. `pubspec.yaml` add:
   ```yaml
   firebase_messaging: ^15.1.0
   firebase_storage: ^12.3.0
   firebase_app_installations: ^0.3.0     # stable installationId for guest devices
   flutter_local_notifications: ^19.3.0   # already present — reused for foreground display
   http: ^1.2.2                           # already present — reused by foreground image downloader
   ```
   `http` and `flutter_local_notifications` are already pinned; listed here only so the dependency story for this phase is explicit.
2. **Code organization** — split into small, single-responsibility files so each can be debugged in isolation:
   ```
   lib/services/notifications/
     fcm_service.dart                 // facade: init(), token refresh, topic subs
     fcm_token_repository.dart        // reads/writes user_tokens or device_tokens
     fcm_foreground_renderer.dart     // foreground display incl. BigPicture image
     fcm_deep_link_router.dart        // parses data.deepLink, calls app router
     fcm_background_handler.dart      // top-level background entry point
     broadcast_channel.dart           // channel constants, importance, sound
   ```
   Do **not** touch the existing `lib/services/notification_service.dart` — it stays responsible for local jamaat reminders only.
3. `FcmService.init()` behavior (runs on app start, **BEFORE** any auth gate):
   - Request notification permission (Android 13+ `POST_NOTIFICATIONS`).
   - Create Android channel `broadcast_channel` (distinct from the jamaat reminder channel).
   - Always call `FirebaseMessaging.instance.subscribeToTopic('all_users')` — topic subscription requires no auth and covers guest users.
   - Fetch FCM token.
   - **If logged in** → write to `user_tokens/{uid}` via `FcmTokenRepository.saveForUser(uid, token)`.
   - **If NOT logged in (guest)** → write to `device_tokens/{installationId}` via `FcmTokenRepository.saveForDevice(installationId, token)`. `installationId` **must** be `FirebaseInstallations.instance.getId()` — it is stable across FCM token rotations and across app launches. Do NOT derive it from the FCM token itself (FCM tokens rotate on reinstall/restore/push-certificate change, which would orphan the existing `device_tokens` row and double-count the device on every rotation).
   - On `authStateChanges()`, migrate guest token: copy row from `device_tokens/{id}` into `user_tokens/{uid}`, leave the device row in place (don't delete — user may log out).
4. Foreground handler (`FirebaseMessaging.onMessage`) → `FcmForegroundRenderer.show(message)`:
   - Decode `message.notification` + `message.data`.
   - If `message.notification.android.imageUrl` is present, **download the image bytes with `http`** into a temp file (cache dir), then build `BigPictureStyleInformation(FilePathAndroidBitmap(path), ...)` for `flutter_local_notifications`. This is the step that was previously missing.
   - If download fails → render as plain text `BigTextStyleInformation` (reuses the text fallback contract).
5. Background + killed → handled by Android system tray via FCM `notification` payload (Android renders the image natively).
6. Tap handler → `FcmDeepLinkRouter.handle(message.data.deepLink)` — uses existing Navigator from `main.dart`.
7. Android config (`android/app/src/main/AndroidManifest.xml`):
   - Add `POST_NOTIFICATIONS` permission.
   - Add `INTERNET` (already present, but verify).
   - Add meta-data for default channel id + notification icon.
   - `FirebaseMessagingService` receiver (auto-injected by plugin, just verify).
8. Wire `FcmService().init()` into `main.dart` **after `Firebase.initializeApp()` and BEFORE any auth-gated navigation** — NOT gated on `currentUser != null`.
9. Write a test hook: one-time debug button in settings (behind dev-mode flag) that prints the current FCM token + whether the user is logged in — used during Phase 4 testing.

**Tests (manual):** send test notification from Firebase console to topic `all_users`, verify foreground/background/killed display + icon + tap deep-link to `/home`. **Explicitly test on a freshly-installed build with NO login** — that path must receive the push (guest coverage).

**Commit:** `feat(notify): FCM receive layer with foreground/background/killed support (guest-safe)`

**Modify-option:** link logged-in users to their devices by also writing `FirebaseInstallations.instance.getId()` into `user_tokens/{uid}.tokens[].installationId`, so a single user on multiple devices gets addressed across all of them — future-proofs multi-device users.

---

## Phase 3 — Cloud Functions Scaffold + Auth Guard

**Goal:** Empty functions project that can verify a caller is SuperAdmin and is deployable.

Steps:
1. In repo root: `firebase init functions` → TypeScript, ESLint, npm install now.
2. Create `functions/src/lib/auth.ts`:
   ```ts
   export async function assertSuperAdmin(context): Promise<string>
   ```
   - Reads `users/{context.auth.uid}` doc, checks `role === 'superadmin'`.
   - **Does NOT check the hardcoded email list** — Phase 0.5 already unified every superadmin onto the Firestore doc, so the callable and the Firestore write rule both read the same field. No divergent paths.
   - If the doc is missing or `role != 'superadmin'`, throw `functions.https.HttpsError('permission-denied', ...)`.
   - On `context.auth == null`, throw `'unauthenticated'`.
3. Create `functions/src/lib/logger.ts` — structured logger writing to Cloud Logging + mirroring critical events to `notifications/`.
4. Create `functions/src/lib/validate.ts` — payload validators (Zod or manual) for the shapes in Phase 1.
5. Add one placeholder callable `ping` that only returns `{ ok: true, uid }` after `assertSuperAdmin` passes — used to smoke-test deploy.
6. **Deploy the two role-management callables from Phase 0.5:**
   - `bootstrapSuperadminRole` — single-use self-bootstrap against `system_config/bootstrap_superadmins`.
   - `setUserRole({ targetUid, role })` — superadmin-only role management.
   Both write to `role_audit/`. These land in this phase because Phase 0.5 is a refactor; the actual server implementation ships alongside the rest of the functions scaffold.
7. Set up CI: add `.github/workflows/functions-build.yml` that runs `npm --prefix functions run build` on PRs.

**Tests:** deploy to `jaamattime` project, call `ping` from a superadmin and a non-superadmin account, verify 200 vs 403.

**Commit:** `feat(notify): cloud functions scaffold + superadmin auth guard`

**Modify-option:** use Firebase **App Check** on callable functions — blocks unauthenticated/abusive clients even before auth runs. Adds `firebase_app_check` to pubspec.

---

## Phase 4 — Cloud Function: `broadcastNotification` (Text Only)

**Goal:** SuperAdmin can send a text-only push to topic `all_users` via a callable function. Full logging.

Steps:
1. `functions/src/broadcast/broadcastNotification.ts` — HTTPS callable.
2. Payload (validated):
   ```ts
   { type: 'text', title, body, target: {kind}, deepLink?, sendNow: true }
   ```
3. Flow:
   - `assertSuperAdmin(context)`.
   - Write draft doc `notifications/{id}` with `status: 'sending'`.
   - Build FCM message with `notification: {title, body}` + `data: {deepLink, notifId}`.
   - `admin.messaging().send(message)` to topic `all_users` (Phase 1 target).
   - Update doc with `status: 'sent'`, `fcmResponse`.
   - On any error → `status: 'failed'`, `failureReason`, re-throw to caller.
4. Return `{ notifId, messageId }` to caller for receipt.

**Tests:** call from app (temporary debug screen), verify delivery to another device, verify log doc, verify non-superadmin is rejected.

**Commit:** `feat(notify): broadcastNotification callable — text push to all_users`

**Modify-option:** wrap the send in a Firestore transaction that increments `notifications/_counters/daily/{yyyymmdd}.count` — enables daily quota enforcement in one Phase.

---

## Phase 5 — Cloud Function: Image Payload + Fallback

**Goal:** Same function accepts an image payload. On failure, falls back to text-only, never crashes.

Steps:
1. Extend `broadcastNotification` to accept `type: 'image'` + `imageUrl`.
2. Before send:
   - `fetch(imageUrl, { method: 'HEAD' })` — must be HTTPS, `2xx`, `content-type: image/*`, `content-length ≤ 1MB` (FCM image limit on Android).
   - If validation fails and the caller provided a `body` → send text-only, set `status: 'fallback_text'`, record `failureReason: 'image_invalid_<reason>'`.
   - If validation fails and there is no body → reject call with `invalid-argument`.
3. FCM message builder adds:
   ```ts
   android: { notification: { imageUrl }, priority: 'high' }
   data:    { deepLink, notifId, imageUrl }   // imageUrl ALSO in data so foreground renderer can fetch it
   ```
   Why `imageUrl` lives in *both* `notification` and `data`: when the app is backgrounded/killed, Android uses the `notification` block and renders the image natively. When foregrounded, `onMessage` receives the payload but does **not** auto-render — the foreground renderer built in Phase 2 pulls `data.imageUrl`, downloads the bytes, and displays `BigPictureStyleInformation`. Without duplicating into `data`, foreground image display silently drops.
4. Log the fallback branch distinctly in `notifications/`.
5. End-to-end foreground image smoke test is a **required** sign-off for this phase — not just background/killed.

**Tests:**
- Valid image (Storage URL + external URL).
- Invalid: 404, non-HTTPS, oversized, HTML MIME type.
- Confirm collapsed vs expanded rendering on a real Android device (notification drawer → pull down to expand).
- **Foreground with image** — app open, send image push, verify BigPicture renders (not just title/body).
- **Foreground with broken image URL** — app open, send push with 404 imageUrl, verify text-only fallback renders without crash.

**Commit:** `feat(notify): image broadcast support with text fallback`

**Modify-option:** if an uploaded image is >1MB, auto-resize server-side with `sharp` inside the function and re-upload to a `notification_images/resized/` path — saves admins from resizing manually.

---

## Phase 6 — Admin UI: Manual Broadcast Form

**Goal:** SuperAdmin screen to compose, preview, and send.

Steps:
1. New screen `lib/screens/admin_notification_broadcast_screen.dart`.
2. Entry point: add a tile in `admin_jamaat_panel.dart` (or wherever the superadmin hub lives today) — reuse existing nav style, do not create a new menu system.
3. Form fields:
   - **Type** (SegmentedButton): `text` · `image`.
   - **Title** (required, max 65 chars — Android lock-screen limit).
   - **Body** (required, max 240 chars).
   - **Image**: tabs for `Upload` (picks from gallery → `firebase_storage` upload to `notification_images/{uuid}`) and `Paste URL`.
   - **Target**: dropdown — Phase 6 ships only `all_users`; other options present but disabled with "Coming soon" tooltip (future-ready).
   - **Deep link / Route**: free-text, with dropdown of common routes (`/home`, `/settings`, `/admin/jamaat`).
   - **When to send**: `Now` · `Schedule…` (Phase 7 enables the second).
4. **Live preview widget** — renders a fake Android notification card with the entered title/body/image matching system styling.
5. **Confirm dialog** before send: shows "This will send to EVERY user. Type SEND to confirm." — matches user's "Protection for send-to-all action" requirement.
6. Submit → call `broadcastNotification` → show spinner → toast success/failure with the returned `notifId` (tap to view history, wired in Phase 10).
7. Gate entire screen behind `AuthService().isSuperAdmin()` — reuse existing check.

**Tests:** empty fields, invalid image URL, confirm dialog bypass attempt, SuperAdmin vs Admin access.

**Commit:** `feat(notify): admin broadcast form with preview and confirm`

**Modify-option:** add a **"Send to me only" test-shot button** next to "Send to all" — it sends to the admin's own FCM tokens only. Catches typos before a real broadcast hits all users.

---

## Phase 7 — Schedule-Later Dispatcher

**Goal:** `Schedule…` option in the form is now functional, without any client writes to restricted collections.

Steps:
1. New callable `scheduleBroadcast` (Cloud Function):
   - `assertSuperAdmin(context)`.
   - Validates payload (same schema as `broadcastNotification` + required `fireAt`).
   - Transactionally creates the draft in `notifications/{notifId}` with `status: 'queued'` **and** the row in `scheduled_notifications/{notifId}` with `fireAt`, `claimed: false`, `createdBy = context.auth.uid`.
   - Returns `{ notifId, fireAt }` to the client.
   - This is the **only** write path into `scheduled_notifications` — client never writes there directly, so the Phase 1 rules (no client access) stand.
2. Admin UI: when the admin picks "Schedule…" + a future datetime, the form calls `scheduleBroadcast` instead of `broadcastNotification`.
3. New callable `cancelScheduledBroadcast(notifId)`:
   - `assertSuperAdmin`.
   - Fails if already claimed/sent.
   - Sets `notifications/{notifId}.status = 'cancelled'` and deletes the `scheduled_notifications` row.
4. New Cloud Function: `dispatchScheduledNotifications` (Pub/Sub schedule `every 5 minutes`):
   - Query `scheduled_notifications` where `fireAt <= now` AND `claimed == false`.
   - For each: transactionally flip `claimed = true`; if the txn wins, invoke the shared internal `sendBroadcast()` helper (the same one used by `broadcastNotification`, extracted in Phase 4/5).
5. Admin history screen (Phase 10) shows scheduled items with a `Scheduled` chip and an inline "Cancel" button that calls `cancelScheduledBroadcast`.

**Tests:** schedule +2 min, schedule in the past (should send within 5 min), cancel before fire, cancel after fire (should fail cleanly), non-superadmin call (should 403).

**Commit:** `feat(notify): scheduled broadcast via callable (schedule + cancel + dispatcher)`

**Modify-option:** finer granularity — switch to a Cloud Tasks queue (1-minute precision) instead of 5-min cron. Only needed if scheduling precision matters.

---

## Phase 8 — Auto Notification Rules: Storage + Admin UI

**Goal:** SuperAdmin can toggle `autoNotifyOnJamaatChange` and choose mode/target.

Steps:
1. New screen `lib/screens/admin_auto_rules_screen.dart` — single-form bound to `notification_rules/jamaat_change` doc (Phase 1 schema).
2. Fields: `autoNotifyOnJamaatChange` (switch), `autoNotifyMode` (segmented), `autoNotifyTarget` (dropdown — only `all_users` enabled initially), `minChangeMinutes` (number), `cooldownSeconds` (number), `defaultImageUrl` (upload/paste).
3. Save writes directly (Firestore rules restrict to superadmin).
4. Link from admin broadcast hub.

**Commit:** `feat(notify): admin UI for auto-notification rules`

**Modify-option:** add a "Dry run" toggle that routes auto-sends to a test topic `admin_dry_run` only. Lets you verify the auto trigger behavior against a real jamaat edit without waking 10k users.

---

## Phase 9 — Auto-Trigger: `onJamaatChange` Firestore Function

**Goal:** Any edit to `jamaat_times/{city}/daily_times/{date}` that changes values fires a broadcast per the rules — once only.

Steps:
1. **Pre-requisite** — extend `JamaatService.saveJamaatTimes()` (existing code) to also write `updatedBy: currentUid`, `updatedByEmail: currentEmail`, and `writeSource: 'admin_panel'` on every save. Firestore triggers **do not** populate `context.auth` (they run with admin privileges regardless of who wrote the doc), so caller identity **must** be recorded in the document body by the writer. This one-line addition unlocks the defensive check in Phase 11.
2. New function `functions/src/triggers/onJamaatChange.ts` — use **Functions v2** (Gen 2) syntax, which is the current supported API:
   ```ts
   import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

   export const onJamaatChange = onDocumentUpdated(
     'jamaat_times/{city}/daily_times/{date}',
     async (event) => {
       const before = event.data?.before.data();
       const after  = event.data?.after.data();
       // ...
     }
   );
   ```
   Note: there is no `context.auth` here — the Firestore trigger runs as the service account, not as the end user. Any identity-based logic must read `after.updatedBy` instead (set in step 1).
3. Flow:
   - Read rule doc; if `autoNotifyOnJamaatChange === false` → exit.
   - Verify the write came from a trusted source: `after.writeSource === 'admin_panel'` AND the uid in `after.updatedBy` has admin/superadmin role in `users/{uid}`. If not → log a warning and exit (defends against rogue server-side writes).
   - Diff `before.times` vs `after.times`. Skip if keys identical OR all deltas < `minChangeMinutes`.
   - Build `dedupKey = sha1(city + date + JSON.stringify(after.times))`.
   - Look up `notifications` where `dedupKey === <key>` AND `createdAt > now - cooldownSeconds`. If found → exit (prevents double sends from re-saves, retries, or multiple admin writes).
   - Compose payload:
     - `text`: `"{city} জামাতের সময় পরিবর্তন"` / `"{city} jamaat time updated"` — i18n-ready, reuse app's locale keys from `lib/l10n/` (check existing keys first).
     - `image`: use `defaultImageUrl` from rule doc; fallback to text if missing (reuse Phase 5 fallback logic).
     - `data.deepLink = "/home?city={cityKey}&date={date}"` so tap opens the exact day.
   - Reuse the internal `sendBroadcast()` helper from Phase 4/5 (extract in this phase if not already).
   - Log to `notifications/` with `triggerSource: 'auto_jamaat_change'`, `createdBy: 'system'`.
3. **Do not** add any new jamaat save flow — Firestore trigger fires off the *existing* `JamaatService.saveJamaatTimes()` writes automatically.

**Tests:**
- Edit a jamaat time via existing admin panel → verify notification.
- Re-save the same value → no notification.
- Toggle rule off → no notification.
- Two near-simultaneous edits → one notification (dedup).
- Edit a field with <1 minute change → no notification.

**Commit:** `feat(notify): onJamaatChange auto-trigger with dedup + cooldown`

**Modify-option:** emit a **single digest per city per 10-minute window** instead of one-per-field — if the admin is mid-editing multiple prayers, users see one clean "3 prayers updated" push. Gated by a new rule flag `digestMode`.

---

## Phase 10 — Notification History & Status Screen

**Goal:** SuperAdmin can audit every send.

Steps:
1. New screen `lib/screens/admin_notification_history_screen.dart`.
2. Query `notifications` ordered by `createdAt desc`, paginated (20/page).
3. Filters: trigger source (manual/auto), status, date range.
4. Each row expands to show full payload + `fcmResponse`.
5. "Retry" button on failed rows (calls `broadcastNotification` with the stored payload).

**Commit:** `feat(notify): admin notification history screen`

**Modify-option:** add open-rate telemetry — app logs a `notification_opened` event to `notifications/{id}/events/` on deep-link tap. Unlocks per-broadcast engagement analytics.

---

## Phase 11 — Security Hardening & Rate Limiting

**Goal:** Close the blast radius.

Steps:
1. Firestore rules audit — re-verify Phase 1 rules, add deny-by-default catch-all.
2. In `broadcastNotification` and `scheduleBroadcast`: reject if same superadmin sent >20 broadcasts in the last hour (read `notifications` count). Return `resource-exhausted`.
3. In `onJamaatChange`: verify the `after.writeSource === 'admin_panel'` and `after.updatedBy` has admin role (this check is wired in Phase 9 step 3). Firestore triggers cannot read end-user `context.auth` — identity lives in the document body.
4. Tighten Firestore security rules on `jamaat_times/**` writes. The app's current role source is `users/{uid}.role` + a hardcoded email list in `AuthService` — there are **no Firebase custom claims** set today. Using `request.auth.token.role` would therefore block every legitimate admin write. Instead, define a rule helper and check the Firestore `users` doc:

   ```
   // firestore.rules
   function userRole() {
     return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
   }
   function isAdminOrAbove() {
     return request.auth != null && userRole() in ['admin','superadmin'];
   }

   match /jamaat_times/{city}/daily_times/{date} {
     allow read: if true;                                   // jamaat times are public in the app
     allow write: if isAdminOrAbove()
                  && request.resource.data.updatedBy == request.auth.uid
                  && request.resource.data.writeSource == 'admin_panel';
   }
   ```

   The `updatedBy == request.auth.uid` clause prevents client spoofing of the identity field that Phase 9 depends on. The `writeSource` clause blocks clients from pretending to be the admin panel with arbitrary strings. Note: `get()` costs one extra document read per write — acceptable for jamaat writes (low frequency, admin-only). If that cost becomes a concern at scale, take the "Role custom claims" phase below.
5. Add **App Check** enforcement on the callable (if Modify-option from Phase 3 was taken).
6. Rotate FCM server key to a dedicated service account with only `roles/firebasecloudmessaging.admin`.
7. Add CI lint for the rules file: `firebase emulators:exec --only firestore "npm test"`.

**Commit:** `chore(notify): security rules + rate limits + service account scope`

**Modify-option A (Audit Logs):** turn on **Google Cloud Audit Logs** for the functions — every broadcast is logged immutably, useful for post-incident forensics.

**Modify-option B (Role custom claims — optional prerequisite, ~half-day of work):** migrate role checks from Firestore `get()` to Firebase custom claims for O(1) rule evaluation.
- New Cloud Function `setUserRoleClaim(uid, role)` — callable, superadmin-only, sets `admin.auth().setCustomUserClaims(uid, { role })`.
- New Cloud Function `onUserRoleDocWrite` — Firestore trigger on `users/{uid}` that mirrors the doc's `role` field into custom claims automatically.
- One-time backfill script `functions/scripts/backfill-role-claims.ts` — iterates all `users/**` docs and stamps claims.
- Client: call `user.getIdToken(true)` after login so the refreshed token carries the claim.
- Then, and only then, swap the rule helper in step 4 above to `request.auth.token.role in ['admin','superadmin']` and delete the `userRole()` helper.
- Do this as its own phase (call it Phase 11b) with its own commit `feat(notify): migrate role checks to custom claims`. Not required for correctness — only take it if you want to remove the per-write `get()` cost.

---

## Phase 12 — Test Matrix & Runbook

**Goal:** Every requirement in your spec is explicitly verified.

Deliverables:
1. `docs/notify/TEST_MATRIX.md` — grid of every test case from your requirements:
   - text manual / image manual / text auto / image auto.
   - foreground / background / killed.
   - invalid image URL, slow internet, oversized image.
   - collapsed vs expanded.
   - duplicate jamaat update.
2. `docs/notify/RUNBOOK.md` —
   - FCM payload structure (text-only + image + auto).
   - Topic subscription flow.
   - Fallback behavior diagram.
   - Dedup key derivation.
   - How to revoke a misfired broadcast (best-effort: can't recall Android pushes, but can send a corrective push + log).
3. `docs/notify/DEPLOY.md` — exact steps: deploy functions, set env config, regenerate FCM topic subscriptions.
4. Final pass: run test matrix end-to-end on a real Pixel + Samsung device (different OEM notification stacks behave differently).

**Commit:** `docs(notify): test matrix, runbook, deploy guide`

**Modify-option:** add an integration test suite running against the Firebase **Local Emulator** (Firestore + Functions) so the auto-trigger logic runs in CI on every PR — catches regressions to the dedup/cooldown rules before they hit prod.

---

## Cross-Cutting Reuse Inventory (what we will NOT rebuild)

| Need | Reused from |
|---|---|
| Auth + user id | `lib/services/auth_service.dart` |
| SuperAdmin check | `AuthService().isSuperAdmin()` |
| Admin UI shell | `lib/screens/admin_jamaat_panel.dart` pattern |
| Local notification rendering (foreground) | `flutter_local_notifications` already in pubspec |
| Jamaat write flow / data path | `lib/services/jamaat_service.dart` — **one-line extension in Phase 9** to write `updatedBy`, `updatedByEmail`, `writeSource: 'admin_panel'` on every save (Firestore triggers can't read `context.auth`, so identity must live in the document body). Core save logic untouched. |
| Firestore SDK | already initialized in `main.dart` |
| Routing / deep links | whatever `main.dart` already uses (to inspect in Phase 2) |
| Localization | `lib/l10n/` keys + `l10n.yaml` |

---

## Phase-by-Phase Commit Summary

```
P0    docs(notify): add notification broadcast implementation plan
P0.5  refactor(auth): backend-only role seeding + management; AuthService becomes read-only
P1   feat(notify): add firestore schema + rules for notifications, rules, user_tokens
P2   feat(notify): FCM receive layer with foreground/background/killed support (guest-safe)
P3   feat(notify): cloud functions scaffold + superadmin auth guard
P4   feat(notify): broadcastNotification callable — text push to all_users
P5   feat(notify): image broadcast support with text fallback
P6   feat(notify): admin broadcast form with preview and confirm
P7   feat(notify): scheduled broadcast via callable (schedule + cancel + dispatcher)
P8   feat(notify): admin UI for auto-notification rules
P9   feat(notify): onJamaatChange auto-trigger with dedup + cooldown
P10  feat(notify): admin notification history screen
P11  chore(notify): security rules + rate limits + service account scope
P12  docs(notify): test matrix, runbook, deploy guide
```

Each commit is independent and production-deployable — a rollback at any phase leaves the app in a working state with no broken jamaat reminders.

---

## Deliverables (ties back to your spec)

- **files changed** — listed per phase above.
- **backend flow** — Phase 3-5, 9; summarized in RUNBOOK (P12).
- **app flow** — Phase 2, 6, 8, 10; foreground/background/killed diagram in RUNBOOK.
- **FCM payload structure** — documented Phase 5 + RUNBOOK.
- **topic subscription flow** — Phase 2 (`all_users` now; `affected_location` / `role_based` stubs in Phase 1 schema for future enablement).
- **fallback behavior** — Phase 5.
- **auto-trigger behavior** — Phase 9 + diagram in RUNBOOK.
- **duplicate-prevention logic** — Phase 9 (`dedupKey` + `cooldownSeconds`).

---

## Open items flagged for you to decide later (not blocking)

1. **`affected_location_users` targeting** — requires a user→city mapping. The `users/{uid}` doc likely has this already; to be confirmed in Phase 1.
2. **iOS support** — explicitly out of scope per your requirements. When iOS is added later, Phases 2/5 will need APNs config + payload shape changes only. The backend send code is platform-agnostic.
3. **Notification language** — if your app supports multiple locales, should auto jamaat notifications pick the user's locale (per token record) or always send the app default? Default to user locale if `user_tokens.locale` is populated.
