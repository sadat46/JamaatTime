# Claude Code — Notification Broadcast Implementation Prompt

You are implementing the plan in `NOTIFICATION_BROADCAST_PLAN.md` (rev-5) in this Flutter repo. Work phase by phase, commit after each, never break existing flows.

## Execution protocol

1. Read `NOTIFICATION_BROADCAST_PLAN.md` once. It is authoritative. If this prompt disagrees with the plan, the plan wins.
2. Create/checkout branch `feat/notification-broadcast`.
3. For each phase in order — P0, P0.5, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12:
   a. Read the phase section.
   b. Implement only that phase's steps. Don't pull work forward from later phases.
   c. `flutter analyze` + `flutter test` must pass (and `npm --prefix functions run build` after P3). If anything fails, fix before committing. No `--no-verify`.
   d. Run the phase's test list manually where the plan says "tests:". If a test cannot be run in this environment (needs a real Android device, Firebase project write, FCM send), note it in the commit body as "DEFERRED TEST:" and continue.
   e. Commit with the exact message under that phase's **Commit:** line. One commit per phase.
   f. Pause and print a one-line status: `P{n} done — {commit hash} — deferred: {count}`.
4. Do not run `firebase deploy`, `flutter build`, release scripts, or any destructive op. Build + analyze + test only.

## Hard constraints (non-negotiable)

- **Android-only** for FCM. Skip iOS config.
- **Cloud Functions = Gen 2, TypeScript.** `onDocumentUpdated` for Firestore triggers, `onCall` for callables. Never reference `context.auth` inside a Firestore trigger.
- **Role source = `users/{uid}.role` only.** Client never writes the `role` field. All role changes go through `bootstrapSuperadminRole` or `setUserRole` callables. `AuthService.superadminEmails` hardcoded list gets deleted in P0.5.
- **Local jamaat reminders untouched.** Do not edit `lib/services/notification_service.dart` in any phase. Remote FCM lives in a new `lib/services/notifications/` folder.
- **Guest-safe FCM.** `FcmService().init()` runs in `main.dart` after `Firebase.initializeApp()` and **before** any auth gate. Guests go to `device_tokens/{installationId}`, logged-in users to `user_tokens/{uid}`. `installationId = FirebaseInstallations.instance.getId()` — no fallbacks.
- **Image foreground path.** `imageUrl` goes in BOTH the FCM `notification` block and the `data` block. Foreground renderer downloads bytes with `http` and renders `BigPictureStyleInformation` via `flutter_local_notifications`.
- **Scheduling writes are backend-only.** Clients call `scheduleBroadcast` / `cancelScheduledBroadcast` callables. Never write `scheduled_notifications/**` or `notifications/**` from the client.
- **Send-to-all confirmation.** Manual broadcast form requires typing `SEND` to confirm.
- **`JamaatService.saveJamaatTimes()`** gets a one-line extension in P9 only: add `updatedBy`, `updatedByEmail`, `writeSource: 'admin_panel'`. Don't change its save logic.
- **Firestore rule for `jamaat_times`** uses `userRole()` / `isAdminOrAbove()` helpers reading `users/{uid}.role`. Don't reference `request.auth.token.role` (no custom claims in this app).
- **File cap:** ~300 lines per file; widgets under 150; pure fns under 50. Split early.

## Folder layout (create as phases demand, don't touch existing files outside this map)

```
lib/services/notifications/
  fcm_service.dart
  fcm_token_repository.dart
  fcm_foreground_renderer.dart
  fcm_deep_link_router.dart
  fcm_background_handler.dart
  broadcast_channel.dart
lib/widgets/notifications/        (form pieces, preview card)
lib/models/notifications/         (payload classes)
lib/screens/notifications/        (broadcast form, auto rules, history)

functions/
  src/
    broadcast/      (broadcastNotification)
    scheduled/      (scheduleBroadcast, cancelScheduledBroadcast, dispatcher)
    triggers/       (onJamaatChange)
    role/           (bootstrapSuperadminRole, setUserRole)
    lib/            (auth, validate, logger, sender, dedup)
  scripts/
    seed-bootstrap-allowlist.ts
```

## Reuse map (don't rediscover)

- Auth + superadmin check → `lib/services/auth_service.dart` (`AuthService().isSuperAdmin()`). P0.5 rewrites this to read-only.
- Admin hub UI pattern → `lib/screens/admin_jamaat_panel.dart`. Add new tiles here.
- Jamaat data path → `jamaat_times/{cityKey}/daily_times/{dateString}` in `lib/services/jamaat_service.dart`.
- Firebase project id → `jaamattime` (see `firebase.json` and `lib/firebase_options.dart`).
- Routing → inspect `lib/main.dart` once at P2 start to mirror the existing navigation pattern for deep links.
- Already-pinned deps: `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_local_notifications`, `http`, `device_info_plus`. New in P2: `firebase_messaging`, `firebase_storage`, `firebase_app_installations`.

## When to stop and ask

Stop and print `NEEDS INPUT: <question>` instead of guessing when:
- A phase step conflicts with existing code in a way the plan doesn't address.
- A required dep version is incompatible with `sdk: ^3.8.1`.
- A Firestore rule change would block existing non-notification flows.
- You'd have to invent a deep-link route the app's router doesn't already support.
- Any ambiguity about role authorization, security rules, or production data.

Do not ask about formatting, file names, or test values within the plan — pick the closest match to the plan and proceed.

## Commit discipline

- One phase = one commit. Use the exact message under the phase's **Commit:**.
- Commit body: short bullet list of files added/changed + any `DEFERRED TEST:` lines.
- No cross-phase commits. No amending earlier phase commits.
- If a later phase reveals an earlier bug, fix it in a new commit labeled `fix(notify): P{n} <thing>` and continue.

## Start

Begin now with **Phase 0**. After each phase, print the status line and wait briefly for me to say `continue` or give new input. If I say `continue` or say nothing, proceed to the next phase.
