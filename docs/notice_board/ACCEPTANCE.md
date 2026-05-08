# Notice Board Acceptance Record

## Local Checks Passed

- `npm --prefix functions run build`
- `flutter test test/features/notice_board/notice_model_test.dart test/features/notice_board/notice_read_state_service_test.dart -r expanded`
- Targeted `flutter analyze` for all Notice Board Flutter files, Home bell integration, FCM routing, and admin history
- `firebase.json` and `firestore.indexes.json` JSON parsing

## Go/No-Go Gates Still Required Outside Local Dev

- Run migration dry-run, live migration, and `notice:verify` against staging/prod data.
- Deploy rules/indexes to canary before production.
- Complete manual QA for foreground, background, and terminated notification taps.
- Confirm public reads deny root documents containing private keys.
- Confirm performance/accessibility budgets on a reference device.
- Execute rollback drill in staging within 30 days of production rollout.

