# Android-First Flagship Gap Plan (Excluding Focus Guard)

## Summary
Current app quality is good for active development, but it is not yet at flagship release standard. The biggest blockers are release hardening, Firebase correctness, and server-enforced authorization.

## Findings (Ordered by Severity)

1. Release build is not production-safe: debug signing is used, `applicationId` is still placeholder-style, and shrinking/obfuscation are off.
2. Firebase config is inconsistent and can fail silently: Flutter options contain placeholder API keys while app continues even after init failure.
3. Authorization is client-trust heavy: hardcoded admin/superadmin email fallback and role-change/delete methods in client layer.
4. Admin data write surface has no in-screen auth guard: `AdminJamaatPanel` performs write operations directly; access is mostly UI-gated upstream.
5. Data integrity risk on Firestore failure: writes/reads fall back to in-memory mock storage, which can hide outages and lose state after restart.
6. Permissions are broader than needed for modern Android: legacy storage permissions are declared without clear need.
7. Timezone handling in notifications is inconsistent: mixed use of configured location, `tz.local`, and hardcoded `Asia/Dhaka`.
8. Quality gates are too thin for flagship: only secret-scan workflow exists; no CI analyze/test/build checks.

## Implementation Changes

1. Release Hardening
- Set final `applicationId`, add proper release signing config, enable R8/resource shrinking.
- Add release verification checklist (signed AAB/APK, mapping files, smoke install).

2. Firebase Correctness
- Regenerate `firebase_options.dart` with real per-platform config.
- Remove silent startup fallback for critical Firebase failures; show explicit degraded-mode message.

3. Security/RBAC Hardening
- Remove hardcoded admin/superadmin email fallback.
- Enforce role checks in backend (Firestore rules and/or Cloud Functions) for user role changes and jamaat writes.
- Add explicit role verification guard inside admin screens/services before write calls.

4. Data Reliability
- Replace in-memory mock fallback with explicit retry/error flow for production builds.
- Surface Firebase write/read failures to admin UI with actionable retry states.

5. Notification Consistency
- Standardize all scheduling/calculation paths on configured timezone source.
- Add deterministic timezone tests for Bangladesh, Saudi, and world/GPS modes.

6. Engineering Quality Gate
- Add CI workflow: `flutter pub get`, `flutter analyze`, `flutter test`, and one release build job.
- Expand tests to cover auth role logic, jamaat write flows, notification scheduling, and startup initialization failure paths.

## Implementation Plan (No Code Changes Yet)

### Phase 0 - Baseline and Safety Setup
1. Create a dedicated hardening branch from current mainline.
2. Capture baseline artifacts: current `flutter doctor -v`, current Android release build output, and current notification scheduling behavior logs.
3. Freeze non-critical feature merges while release hardening is in progress.

### Phase 1 - Android Release Hardening
1. Replace placeholder `applicationId` with final production package id.
2. Configure production signing (keystore, gradle properties, secure key handling).
3. Enable R8 and resource shrinking for release builds.
4. Validate release build reproducibility and mapping file generation.
Done when: signed release artifact installs cleanly and app launches with no startup regressions.

### Phase 2 - Firebase Correctness and Startup Reliability
1. Regenerate `firebase_options.dart` from actual Firebase project config.
2. Remove placeholder API keys from committed runtime config paths.
3. Replace silent Firebase-init failure path with explicit degraded mode UI and clear user/admin messaging.
4. Verify startup on clean install, upgrade install, and offline startup states.
Done when: startup behavior is deterministic and Firebase misconfiguration is visible, not silent.

### Phase 3 - Security and RBAC Enforcement
1. Remove hardcoded admin/superadmin email fallback from client.
2. Enforce role-based access in Firestore security rules (and Cloud Functions where needed for privileged mutations).
3. Add explicit role verification guards before admin mutation actions in app layer.
4. Validate direct API/Firestore write attempts from non-admin accounts are denied.
Done when: authorization is server-enforced even if client UI checks are bypassed.

### Phase 4 - Data Reliability Hardening
1. Replace in-memory mock fallback behavior for production writes/reads with explicit failure and retry flow.
2. Surface actionable admin errors for jamaat import/save/update operations.
3. Add retry/backoff policy for transient Firestore/network failures.
4. Ensure no "success" state is shown after failed remote persistence.
Done when: remote failure cannot be mistaken as successful persistence.

### Phase 5 - Notification Timezone Normalization
1. Standardize all prayer/jamaat notification calculations on one timezone source from location config.
2. Remove mixed usage of `tz.local` and hardcoded `Asia/Dhaka` in scheduling paths.
3. Add tests for Bangladesh, Saudi, and world GPS modes, including midnight boundary cases.
Done when: scheduled notifications match expected local prayer logic in all supported location modes.

### Phase 6 - CI Quality Gate and Test Expansion
1. Add GitHub Actions workflow for analyze, test, and Android release build checks.
2. Keep existing secret scan and run it in parallel with quality checks.
3. Expand automated tests for:
- startup initialization paths,
- RBAC behavior,
- jamaat write flows,
- notification scheduling and timezone math.
Done when: PRs are blocked on failing analyze/tests/build.

### Phase 7 - Release Rehearsal
1. Run full regression on target Android versions/devices.
2. Execute checklist for permissions, notifications, auth/roles, jamaat admin operations, and update-check flow.
3. Run internal beta rollout and monitor crash/error signals before public release.
Done when: no critical or high-severity issues remain and release checklist is fully green.

## Test Plan

1. Release pipeline test: signed release artifact, minified build, install/run smoke test.
2. Firebase startup test: valid config path succeeds; invalid config yields user-visible degraded mode.
3. RBAC tests: non-admin cannot write jamaat/user-role changes even if route/service is called directly.
4. Data failure tests: Firestore outage shows clear error and no silent local-only success.
5. Notification tests: timezone correctness across location configs and midnight boundaries.
6. CI gate: PR must pass analyze + tests before merge.

## Assumptions

1. Target is Android-first flagship, with Focus Guard intentionally excluded from this review.
2. "Flagship" means public Play Store quality with strong reliability/security, not just feature completeness.
3. Local `flutter analyze/test` commands timed out in this environment, so findings are based on source inspection plus available command outputs.
