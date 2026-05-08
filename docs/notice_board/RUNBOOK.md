# Notice Board On-Call Runbook

## Public Read Denials

1. Check Firestore rules logs for denied `notifications/*` reads.
2. Run `npm --prefix functions run notice:verify`.
3. If offenders exist, disable `notice_board_enabled` and revert rules to admin-only reads.
4. Inspect `migrations/notice_board_v1/runs/*` for the last migration report.

## High Failure Or Fallback Rate

1. Search Cloud Logging for `notice_metric` with `notice.failed.count` or `notice.fallback.count`.
2. Check image URL host allow-list and provider availability.
3. Confirm text fallback sends are still being accepted.
4. If failures continue, disable image sends in the admin process and send text-only.

## Tap Opens Blank Or Wrong Screen

1. Search client logs for `notice_unavailable_view`.
2. Confirm FCM data includes `notifId`, `deepLink`, `schemaVersion`, `type`, and `priority`.
3. Verify the notice is public, sent/fallback, and not expired.
4. Use the Home bell as fallback while investigating routing.

## Rollback

1. Set `notice_board_enabled=false`.
2. Revert Firestore rules to admin-only notice reads.
3. Redeploy functions from the previous tag if write path regressions are present.
4. Use migration pre-hashes and Firestore export backups for forensic recovery.

