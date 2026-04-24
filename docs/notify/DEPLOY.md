# Notification Broadcast — Deploy Guide

Step-by-step for shipping the broadcast stack to the `jaamattime`
Firebase project. Run from the repo root unless noted.

## Prerequisites

- `firebase` CLI (latest), authenticated as a project owner.
- `node` 20.x (matches `functions/package.json` engines field).
- `flutter` 3.8.1+ on the build machine.
- Local clone of this repo on `feat/notification-broadcast` (or main
  after merge).

## One-time project setup

1. **FCM topic `all_users`** is created lazily on first publish; no
   console step needed.
2. **Cloud Scheduler API** must be enabled for Pub/Sub-scheduled
   functions: `gcloud services enable cloudscheduler.googleapis.com
   --project=jaamattime`.
3. **Storage bucket** for broadcast images uses the default bucket
   (`jaamattime.appspot.com`). No CORS change needed — clients upload
   via the Firebase SDK.
4. **Firestore indexes** — none required at this phase. Aggregation
   queries (`count()`) and equality+range filters used by the rate
   limiter and history screen are served by the auto-managed index.

## Per-deploy checklist

Run in this order. Each step is independently rollback-safe.

### 1. Compile + test locally

```
flutter analyze lib/
flutter test
npm --prefix functions ci
npm --prefix functions run build
```

CI must be green on the branch before any deploy.

### 2. Deploy Firestore rules

```
firebase deploy --only firestore:rules --project jaamattime
```

Verify in console: rules tab shows the catch-all
`match /{document=**} { allow read, write: if false; }` line.
Rule changes are atomic and take effect within seconds.

### 3. Deploy functions

```
npm --prefix functions run build
firebase deploy --only functions --project jaamattime
```

Functions deployed (Gen 2, region `us-central1`):

- `ping`
- `bootstrapSuperadminRole`
- `setUserRole`
- `broadcastNotification`
- `scheduleBroadcast`
- `cancelScheduledBroadcast`
- `dispatchScheduledNotifications` (Pub/Sub, every 5 min)
- `onJamaatChange` (Firestore trigger)

First deploy of `dispatchScheduledNotifications` creates the Cloud
Scheduler job. Subsequent deploys reuse it.

### 4. Smoke test on staging device

Run the §1 receive-layer rows of `TEST_MATRIX.md` on the staging
build (debug APK) before promoting to production users:

- Send a test push from the Firebase console to topic `all_users`.
- Foreground / background / killed — all three must render.
- Tap test — opens `/home`.

### 5. Build + ship the Flutter app

```
flutter build appbundle --release
```

Upload the AAB to the Play Console internal-testing track first.
Promote to production only after the §2 + §5 + §6 rows of
`TEST_MATRIX.md` pass on the internal track.

## Rolling back

- **Rules**: redeploy the previous `firestore.rules` from git history.
- **Functions**: `firebase deploy --only
  functions:<name>` after `git checkout` on the prior commit. Every
  callable is independently versioned.
- **App**: use Play Console "Roll back this release" — server side
  stays compatible because all FCM payloads are additive.

## Service account scoping (P11 follow-up)

The default app-engine service account is currently used for both FCM
sends and Firestore admin writes. To narrow the blast radius:

1. Create a dedicated service account
   `notify-sender@jaamattime.iam.gserviceaccount.com`.
2. Grant only:
   - `roles/firebasecloudmessaging.admin`
   - `roles/datastore.user` (for `notifications/**` writes)
3. Bind the new SA to functions via
   `serviceAccount: 'notify-sender@...'` in each `onCall` /
   `onSchedule` / `onDocumentUpdated` options block.
4. Redeploy and verify a manual broadcast still succeeds.

This is documented but not yet wired — open issue #notify-sa.

## Post-deploy verification

After every production deploy, within 24 h:

- Open the Notification History screen as superadmin and confirm the
  most recent send appears with status `sent`.
- Pull last 1 h of `dispatchScheduledNotifications` logs — expect
  `scheduled_dispatch_idle` lines unless something is queued.
- Sample the FCM "Reports" tab in Firebase console for delivery rate
  drop-offs >5% vs the prior week.
