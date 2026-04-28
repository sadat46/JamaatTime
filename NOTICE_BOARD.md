# Notice Board Phase-Wise Implementation Plan (Flagship v2)

## Summary

Build a public Notice Board for broadcast text/image notifications. The board is reachable for guests and signed-in users via a Home-screen bell, and notification taps deep-link to the matching notice detail. The existing admin notification history remains intact, but private operational metadata is split out of the public root document before any public Firestore read rule is enabled. The plan targets flagship quality on data integrity, security, accessibility, performance, observability, and rollout safety.

## Phase 0: Goals, Non-Goals, Success Metrics

- Goals:
  - Tappable notifications always resolve to a visible notice or a graceful fallback (never a blank Home).
  - Guests and signed-in users can browse a fast, accessible, offline-capable Notice Board.
  - Zero leakage of private operational metadata to public clients.
  - Schema and rollout are reversible at every step.
- Non-Goals (v1):
  - Per-user delivery receipts, per-user targeting, comments/reactions, push for individual notices to specific users only.
  - Cross-device read-state sync.
  - Rich text/HTML rendering (plain text only with safe inline links).
- Success Metrics (instrumented in Phase 10):
  - Tap → detail render P95 ≤ 1.5s (warm), ≤ 3.5s (cold).
  - Notice list first-paint P95 ≤ 1.0s on cached data.
  - Tap-to-blank rate < 0.1% of notification opens.
  - Crash-free sessions on Notice Board ≥ 99.9%.
  - Public Firestore rule denies on `admin_meta` = 100% in security tests.
  - Image fallback success rate ≥ 99.5%.

## Phase 1: Data Contract And Compatibility

- Define the v1 public notice schema on `notifications/{notifId}`:
  - Identity & versioning: `schemaVersion` (int, =1), `notifId` (string, mirror of doc id for query convenience).
  - Content: `type` (enum: `info | prayer_time_change | jamaat_time_change | event | urgent | announcement | other`), `category` (free-form admin tag), `title` (≤120 chars), `body` (≤2000 chars, plain text), `imageUrl` (HTTPS only, allow-listed host), `imageWidth`, `imageHeight`, `imageBlurHash` (optional), `deepLink` (internal route allow-listed), `locale` (BCP-47, default `en`), `localizedVariants` (map<locale, {title, body}>, optional).
  - Lifecycle: `status` (enum: `draft | queued | sending | sent | fallback_text | failed | cancelled | expired`), `publicVisible` (bool), `priority` (enum: `normal | high | critical`), `pinned` (bool, optional), `expiresAt` (Timestamp, optional), `archivedAt` (Timestamp, optional).
  - Provenance (public-safe only): `triggerSource` (enum: `manual | auto_prayer | auto_jamaat | system`), `createdAt`, `scheduledFor`, `sentAt`, `publishedAt`, `updatedAt`.
  - Audience (public-safe descriptor): `audience` (enum: `all_users | guests_and_users`), no PII.
- Public field allow-list is enforced at the Firestore rule layer and in a backend `PUBLIC_NOTICE_KEYS` constant; any write outside this list is rejected.
- Define private metadata at `notifications/{notifId}/admin_meta/meta`:
  - `createdBy`, `createdByDisplayName`, `target`, `targetTokensCount`, `sendMode`, `failureReason`, `failureCode`, `fcmResponse`, `fcmMessageId`, `dedupKey`, `idempotencyKey`, `retryCount`, `lastRetryAt`, `cancelledBy`, `cancelledAt`, `editHistory[]`, `clientIp` (hashed), `userAgent`, `diagnostics{}`.
- Constraints & invariants (enforced server-side, asserted in tests):
  - `publicVisible == true` ⇔ `status ∈ {sent, fallback_text}` AND `expiresAt == null || expiresAt > now`.
  - State transitions are forward-only except admin-driven `cancelled` from `queued|sending`.
  - `schemaVersion` is required; missing → treated as legacy and routed through migration adapter.
  - Document size budget: root ≤ 64 KB, `imageUrl` length ≤ 2 KB, `body` ≤ 2000 chars (rejected by validator before write).
- Add backend helper functions for reading/writing notice records:
  - `writeNoticeDraft`, `writeAdminMeta`, `publishNotice` (idempotent on `idempotencyKey`), `markNoticeFailed`, `markNoticeCancelled`, `markNoticeExpired`, `loadBroadcastDraft`, `validatePublicPayload`, `sanitizeBody`, `assertDeepLinkAllowed`.
  - `loadBroadcastDraft` supports both legacy root metadata and new `admin_meta/meta` during rollout, with explicit `legacyShape` flag in returned object.

## Phase 2: Backend Write Path

- Update `sendBroadcast` so new immediate sends:
  - Validate input via `validatePublicPayload` and `assertDeepLinkAllowed`.
  - Write public-safe root data first with `publicVisible=false`, `status='sending'`, `idempotencyKey` set.
  - Write `admin_meta/meta` in the same Firestore batch/transaction.
  - Publish (`status='sent'`, `publicVisible=true`, `publishedAt=serverTimestamp()`) only after FCM accepts; partial failure rolls status to `failed` with `publicVisible=false`.
- Move FCM response and failure details into `admin_meta/meta`; never write raw `createdBy`, `target`, `fcmResponse`, `dedupKey`, or IPs to the root document.
- Image fallback handling:
  - If image send fails, retry once with exponential backoff before falling back.
  - On fallback, root `status='fallback_text'`, `publicVisible=true`, `imageUrl` cleared, public reason code `imageFallback=true` (boolean only).
  - Detailed `failureReason` and provider error stored in `admin_meta/meta`.
- Update `scheduleBroadcast`:
  - Root doc is a public-safe queued draft with `publicVisible=false`, `status='queued'`.
  - Private metadata stores `createdBy`, `target`, pre-send fallback reason, `idempotencyKey`.
- Update `dispatchScheduledNotifications`:
  - Load root public fields plus private metadata.
  - Skip docs whose `expiresAt < now` and mark `status='expired'`.
  - Keep legacy fallback while migration is pending; gated by `LEGACY_NOTICE_DUAL_READ` env flag.
  - Use a Firestore transaction for the queued→sending→sent transition to prevent double-send.
- Update `cancelScheduledBroadcast`:
  - Root status becomes `cancelled`, `publicVisible=false`.
  - Private metadata receives `cancelledBy` and `cancelledAt`.
  - No-op + audit log if already `sent`.
- Update manual broadcast rate limiting:
  - Stop querying root `createdBy`.
  - Use `collectionGroup('admin_meta')` filtered by `createdBy` and `createdAt`, OR a dedicated `admin_rate_limits/{uid}` doc updated transactionally.
  - Add a global ceiling (per-minute, per-hour) and per-admin ceiling; emit `rateLimitHit` metric.
- Add a server-side `expireNotices` scheduled function (hourly): flips expired public notices to `status='expired'`, `publicVisible=false`, sets `archivedAt`.
- All writes go through a single `withAuditLog` wrapper that appends to `admin_meta/meta.editHistory` with actor, action, before/after diff (private only).

## Phase 3: Admin History Compatibility

- Update `AdminNotificationHistoryScreen` and `NotificationHistoryRow` to merge each root notice with `admin_meta/meta` via a single batched read (`getAll`).
- Keep existing filters by root fields: `status`, `triggerSource`, `createdAt`; add filters for `priority`, `type`, `publicVisible`.
- Keep retry/cancel behavior unchanged for admins:
  - Retry reads target/deepLink/type/title/body/image from merged root/private data and reuses original `idempotencyKey` to prevent duplicates.
  - Cancel still calls `cancelScheduledBroadcast`.
- Show old legacy docs correctly during migration:
  - If private metadata is missing, temporarily read legacy root fields and tag the row with a "legacy" badge in admin UI.
  - Remove this fallback only after migration is complete, verified via the migration verifier (Phase 5).
- Add a "View raw" admin debug drawer showing the merged JSON, gated by superadmin claim.

## Phase 4: Firestore Rules And Indexes

- Do not enable public reads until all unsafe root docs are migrated and the verifier reports zero offenders.
- Update rules for `notifications/{notifId}`:
  - Admins can read all root notices; superadmin can read `admin_meta`.
  - Public clients can read only if `resource.data.publicVisible == true`, `resource.data.status in ['sent', 'fallback_text']`, `resource.data.expiresAt == null || resource.data.expiresAt > request.time`, and document keys are a subset of the approved public field list (validated via `hasOnly`).
  - All client writes remain denied; writes only via Cloud Functions/Admin SDK.
  - Use a `request.time`-aware rule for `expiresAt` to avoid stale reads after expiry.
- Update rules for `notifications/{notifId}/admin_meta/{doc}`:
  - Admin read only (superadmin-claim or `admin == true` custom claim).
  - Client writes denied.
- Add required indexes:
  - Public board query: `publicVisible ASC`, `status ASC`, `publishedAt DESC`.
  - Pinned-first query: `publicVisible ASC`, `pinned DESC`, `publishedAt DESC`.
  - Admin filters: `status`, `triggerSource`, `priority`, `type`, `createdAt DESC`.
  - Rate-limit collection-group index: `admin_meta.createdBy ASC`, `createdAt DESC`.
  - Expiry sweep: `status ASC`, `expiresAt ASC`.
- Add Firestore Security Rules unit tests (`@firebase/rules-unit-testing`) covering every allow/deny path; CI fails if coverage < 100% of rules branches.
- Add Storage rules for notice images: read public if path is under `notice_images/{notifId}/...`, write only via Admin SDK; size cap 5 MB, content-type `image/*` only.

## Phase 5: Migration And Rollout Order

- One-time backfill script for existing `notifications/{id}`:
  - Idempotent, resumable, batched (≤ 400 writes/batch), with `--dry-run`, `--limit`, `--since`, and `--verify-only` flags.
  - For each doc: copy private root fields into `admin_meta/meta`, remove private fields from root, add `schemaVersion=1`, set `publicVisible=true` and `publishedAt=sentAt ?? createdAt` only for `sent` and `fallback_text`, keep queued/failed/cancelled hidden.
  - Computes a SHA-256 of the original doc and stores it in `admin_meta/meta.migration.preHash` for rollback.
  - Writes a per-run report to `migrations/notice_board_v1/{runId}` with counts, errors, and offending doc IDs.
- Verifier script `verifyNoticeMigration` scans all notices and asserts: no private keys at root, all public docs satisfy invariants, `schemaVersion=1` everywhere. CI gate on green verifier before rules deploy.
- Safe deploy order:
  - 1. Deploy backend with dual-read/new-write support while rules remain admin-only (`LEGACY_NOTICE_DUAL_READ=true`).
  - 2. Run backfill in dry-run, then live, then verifier.
  - 3. Deploy Firestore rules and indexes (canary project first, then prod).
  - 4. Release app UI and routing changes behind a remote-config flag `notice_board_enabled` (default off; ramp 1% → 10% → 50% → 100%).
  - 5. After one full release cycle and verifier still green, flip `LEGACY_NOTICE_DUAL_READ=false` and remove legacy fallback reads.
- Rollback playbook:
  - Per-step rollback documented (revert rules, disable flag, restore from `admin_meta/meta.migration.preHash`).
  - Backups: pre-migration Firestore export to GCS, retention 90 days.

## Phase 6: App Data Layer

- Add `NoticeModel` with null-safe parsing from Firestore timestamps and optional image/deep link fields; rejects unknown `schemaVersion > 1` gracefully (renders "update app" placeholder card).
- Add `NoticeRepository`:
  - `fetchPage({cursor, limit})` ordered by `pinned DESC, publishedAt DESC` where `publicVisible == true` and (`expiresAt == null || expiresAt > now`).
  - `getById(notifId)` for notification taps, with single-flight de-dup and 30 s in-memory cache.
  - `watchLatest()` for Home bell unread state, throttled to 1 update/sec.
  - Offline cache via Firestore persistence + a small Hive box for the most recent 50 notices (for cold-start render before network).
- Add `NoticeReadStateService` using `SharedPreferences`:
  - Store latest seen notice timestamp and a bounded LRU set (max 500) of read notice IDs with schema versioning for forward-compatible migrations.
  - Mark all visible notices seen when opening the board.
  - Mark a notice read when opening detail.
  - Migration path if storage schema changes (`readState.schemaVersion`).
- Image loading:
  - Use `cached_network_image` (or equivalent) with disk cache cap 50 MB, memory cache cap 30 items.
  - Show blurhash placeholder when available; fallback to skeleton.
- Use current app localization style with `context.tr(...)`; do not introduce a new localization system. Add new keys under `notice_board.*` namespace and provide all supported locales before launch.
- Network resilience: typed errors (`NoticeNotFound`, `NoticeHidden`, `Network`, `PermissionDenied`), exponential backoff with jitter, max 3 retries on transient errors.

## Phase 7: User Interface

- Add `NoticeBoardScreen`:
  - App bar title: Notice Board.
  - Pull-to-refresh, infinite scroll pagination (page size 20), skeleton loaders for first paint, empty, retryable error, and offline states (with "showing cached" banner).
  - List cards showing title, body preview (3 lines, ellipsized), image thumbnail when available, sent/published time (relative + tooltip absolute), manual/auto source label, priority badge for `high|critical`, pinned indicator.
  - Filter chips (optional v1): All / Prayer / Events / Announcements.
  - Long-press to share notice (text + deep link).
- Add `NoticeDetailScreen`:
  - Full title/body, large image if present (tap to view full-screen with pinch-zoom), timestamp, source label, related-action button when `deepLink` is present and allow-listed.
  - Share button (system share sheet) emitting a public URL or in-app deep link.
  - If a notice ID is missing, hidden, or expired, show a clear "notice unavailable" empty state with title localized, plus a button back to the Notice Board.
  - Selectable text body for copy.
- Home-screen bell action in `HomeScreen` app bar:
  - Bell opens `NoticeBoardScreen`.
  - Dot/badge appears when latest public notice is newer than local seen state; badge clears on board open.
  - Badge is local-device only for v1.
  - Bell has accessible label, min tap target 48x48 dp.
- Theming, accessibility, and localization:
  - Light/dark theme parity, dynamic type / text scale up to 200%, high-contrast mode verified.
  - Screen reader labels for every interactive element; semantic order matches visual order.
  - RTL layout verified for Arabic/Urdu/etc.
  - Reduced-motion respected for transitions.
- Keep bottom navigation unchanged.
- State restoration: deep-linked Notice Detail survives process death.

## Phase 8: Notification Tap Routing

- Update FCM foreground local notification payload:
  - Encode JSON containing `notifId`, `deepLink`, `type`, `priority`, and `schemaVersion` — not only the deep link string.
  - Android notification channel `notice_board` (importance HIGH) with category and group key for stacking; iOS interruption level `time-sensitive` for `high|critical` priority where entitled.
- Update `FcmService`:
  - Handle three entry points consistently: `getInitialMessage()` (terminated), `onMessageOpenedApp` (background), and foreground tap on the local notification — all funnel into one `_routeFromMessage(data)` method.
  - Pass both `message.data['notifId']` and `message.data['deepLink']` to the router.
  - De-dup the same `notifId` if user taps multiple stacked notifications within 2 s.
- Replace `FcmDeepLinkRouter` stub:
  - Maintain an allow-list of internal routes; any non-allow-listed `deepLink` falls back to Notice Board with an error toast.
  - If `notifId` exists, push `NoticeDetailScreen(notifId)`; if the load fails or returns hidden/expired, push Notice Board with the "unavailable" banner.
  - If only `deepLink` exists, route to existing handler for `/home`-style links.
  - Queue tap intents until `navigatorKey.currentState` is ready, then route after the first frame; persist the queued intent to disk so a process death between tap and Flutter init does not drop the route.
  - Guard against duplicate stacks (don't push Notice Detail twice on the same id).
- iOS specifics: register `UNNotificationCategory` for actions; ensure `content-available`/`mutable-content` flags as needed for image attachments.
- Android specifics: respect Android 13+ POST_NOTIFICATIONS permission with rationale UX; default channel created at app start.

## Phase 9: Testing And Acceptance

- Backend checks:
  - `npm run build`, `npm run lint`, `npm test` (unit + integration via Firebase Emulator).
  - Verify immediate send, image fallback, scheduled send, failed send, expire, and cancel write the correct root/private fields and emit the correct audit log entries.
  - Verify rate limiting still works after `createdBy` moves private; load test at 2× expected peak.
  - Idempotency test: replay the same `idempotencyKey` does not duplicate writes or FCM sends.
- Firestore rule checks (rules-unit-testing):
  - Public can read visible sent/fallback notices.
  - Public cannot read hidden queued/failed/cancelled/expired notices.
  - Public cannot read `admin_meta`.
  - Admin can still read history and metadata.
  - Public reads denied if root doc contains any non-allow-listed key (regression guard).
  - Storage rules: only Admin SDK can write `notice_images/`; size/content-type enforced.
- Flutter tests:
  - Unit: `NoticeModel` parsing (incl. malformed/legacy/forward-compat), repository pagination, hidden/expired notice handling with mocked Firestore, `NoticeReadStateService` LRU eviction and migration, `FcmDeepLinkRouter` allow-list and queueing.
  - Widget: Notice Board list states (loading/empty/error/offline/loaded/paginating), Notice Detail states (loaded/unavailable/no-image), Home bell unread dot behavior, accessibility semantics.
  - Integration: cold-start tap routing under `getInitialMessage`, background tap, foreground tap dedup, process-death-after-tap recovery via persisted intent.
  - Golden tests: list card and detail in light/dark/RTL/large-text variants.
  - Coverage gate: ≥ 85% for new files; CI fails otherwise.
- Security & privacy tests:
  - Static check that no public read query selects fields from `admin_meta`.
  - Fuzz `deepLink` and `imageUrl` inputs for traversal/JS schemes; assert allow-list rejects.
  - Body sanitizer test: control characters and zero-width joiners stripped or normalized.
- Performance tests:
  - Cold start to first list paint < target on a low-end reference device (e.g., Pixel 4a).
  - Memory: scrolling 200 items keeps RSS within budget; image cache evicts as expected.
- Manual QA checklist:
  - Send text notification, tap from background, terminated, and foreground states.
  - Send image notification, verify board card/detail image, blurhash placeholder, and full-screen viewer.
  - Verify guest user can open board (no auth gate).
  - Verify superadmin history still shows diagnostics, retry, cancel, private fields, and legacy badge during migration.
  - Verify expired notice disappears from public board after sweep.
  - Verify cancelled queued notice never appears publicly.
  - Verify offline behavior: airplane mode shows cached list and offline banner.
  - Verify accessibility: TalkBack/VoiceOver linear traversal works; tap targets ≥ 48 dp.
  - Verify RTL layout in Arabic locale.

## Phase 10: Observability, Analytics, and Monitoring

- Structured logs (Cloud Functions): include `notifId`, `idempotencyKey`, `actorUid`, `action`, `latencyMs`, `outcome`. No PII in logs.
- Metrics:
  - `notice.sent.count`, `notice.fallback.count`, `notice.failed.count`, `notice.cancel.count`, `notice.expire.count`.
  - `notice.publish.latencyMs` histogram.
  - `notice.tap.toDetail.latencyMs`, `notice.tap.toBlank.count` (client → BigQuery via Analytics).
  - `rules.deny.public_admin_meta.count` (should be 0 in steady state).
- Alerts:
  - Spike in `failed`/`fallback` rate above threshold.
  - Non-zero `rules.deny` for unexpected paths.
  - Tap-to-blank rate > 0.5% for any 30-min window.
- Crashlytics/Sentry: Notice Board screens tagged; non-fatal on hidden/expired notice tap.
- Analytics events (privacy-reviewed): `notice_board_open`, `notice_card_tap`, `notice_detail_open`, `notice_share`, `notice_unavailable_view`, `bell_open`, `bell_badge_seen`.

## Phase 11: Performance, Accessibility, Localization

- Performance budgets:
  - Notice Board cold-start render (cached): ≤ 1.0s P95.
  - Notice Detail render: ≤ 800 ms P95 from cache, ≤ 1.5 s from network.
  - List scroll jank < 1% dropped frames at 60 Hz on reference device.
- Accessibility:
  - WCAG 2.1 AA contrast on all text and badges.
  - Screen-reader announcements for new-notice badge state changes.
  - Focus order, focus traps in dialogs, keyboard navigation where applicable.
- Localization:
  - All strings via `context.tr(...)`; pseudolocale CI check to catch hardcoded strings.
  - Date/time formatting via locale-aware formatter; relative time strings localized.
  - Image alt text derived from `title` when no explicit alt is provided.

## Phase 12: Security and Privacy Hardening

- Input sanitization on title/body (strip control chars, normalize Unicode, length caps); reject zero-width joiner abuse.
- `deepLink` allow-list of internal routes; reject `javascript:`, `data:`, external schemes by default.
- `imageUrl` must be HTTPS and host-allow-listed (Firebase Storage / approved CDN).
- CSP-equivalent constraints in any in-app web view used for notices.
- PII review: ensure no email/phone/UID surfaces on root doc; audit log redactor for sensitive fields.
- Threat model documented (STRIDE) covering spoofed admin, replayed FCM, malicious image, deep-link redirect, rule bypass.
- Abuse: per-admin ceiling and global ceiling on broadcasts; suspicious-pattern alerting.
- Data residency and retention reviewed against existing app policy.

## Phase 13: Lifecycle — Retention, Archival, TTL

- `expiresAt` flips notices to `status='expired'`, `publicVisible=false` automatically (Phase 2 sweep).
- Archival: notices older than 180 days move to `notifications_archive/{notifId}` (admin-readable only) via scheduled job.
- Storage: archived images keep cold-storage class; deletion policy after 365 days unless legal hold.
- Public board hard cap: at most 200 most-recent visible notices for client queries; older still accessible via direct deep link until archived.

## Phase 14: Release Strategy and Feature Flag

- Remote config flags: `notice_board_enabled`, `notice_board_min_app_version`, `notice_board_pin_limit`.
- Staged rollout: dev → internal testers → 1% → 10% → 50% → 100% with bake time and metric gates between steps.
- Kill switch: `notice_board_enabled=false` instantly hides bell and routes notification taps to Home gracefully.
- Min app version gate prevents old clients from rendering forward-incompatible schema.

## Phase 15: Documentation and Runbook

- ADR documenting public/private split decision and field allow-list.
- Admin guide: how to send, schedule, cancel, retry; what each `status` means; how to interpret legacy badge.
- On-call runbook: how to respond to alert types in Phase 10, rollback steps from Phase 5.
- API/contract docs auto-generated from the schema source of truth.
- Privacy & security review sign-off recorded.

## Phase 16: Acceptance Criteria (Go/No-Go)

- All Phase 9 tests green, coverage gates met.
- Verifier (Phase 5) reports 0 offending docs in production.
- Rules unit-test suite passes with 100% branch coverage.
- Performance budgets met on reference device.
- Accessibility audit passed (manual + automated scanner).
- Privacy/security review signed off.
- Rollback drill executed successfully in staging within last 30 days.
- No P0/P1 bugs open against Notice Board for 72 hours on canary.

## Assumptions

- Notice Board v1 covers server broadcast text/image notifications, not local prayer/jamaat reminder history.
- Public Notice Board is available to guests because current broadcasts target `all_users`.
- Read/unread state is per device only.
- Exact delivery receipts remain out of scope because current FCM topic sends do not track per-device receipt.
- The app's existing observability stack (Crashlytics/Analytics/Cloud Logging) is already wired in; this plan only adds events/metrics, not new SDKs.
