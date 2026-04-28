# Notice Board Release Strategy

## Flags

- `notice_board_enabled`: represented locally by `kNoticeBoardEnabled` until Remote Config is introduced.
- `notice_board_min_app_version`: represented locally by `kNoticeBoardMinAppVersion`.
- `notice_board_pin_limit`: represented locally by `kNoticeBoardPinLimit`.

## Deploy Order

1. Deploy backend with dual-read/new-write support and keep public reads disabled until verification is green.
2. Run `npm --prefix functions run notice:migrate -- --dry-run`, then live migration, then `npm --prefix functions run notice:verify`.
3. Deploy Firestore/Storage rules and indexes after verifier reports zero offenders.
4. Ship the app UI with `notice_board_enabled` off for canary, then ramp 1%, 10%, 50%, 100%.
5. After one full release cycle, set `LEGACY_NOTICE_DUAL_READ=false` and remove legacy reads in a follow-up cleanup.

## Kill Switch

- Set `notice_board_enabled=false` to hide the Home bell and route notification taps back to Home.
- Revert rules to admin-only reads if verifier or monitoring reports private root fields.
- Keep migration reports under `migrations/notice_board_v1/runs/{runId}` for rollback evidence.

