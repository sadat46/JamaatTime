# Notice Board Security And Privacy Review

## Public/Private Split

- Public clients can read only `notifications/{id}` documents that contain the approved public key set and are visible, sent/fallback, and not expired.
- Operational metadata lives under `notifications/{id}/admin_meta/meta` and is readable only by admin-level accounts.
- Client writes to notices, admin metadata, scheduled queues, and rate-limit state are denied. Cloud Functions/Admin SDK own writes.

## Input Controls

- Titles and bodies are normalized server-side, control characters are stripped, and length caps are enforced before write.
- Deep links must be internal app routes. External schemes, hostnames, `javascript:`, `data:`, and traversal-style links are rejected.
- Image URLs must be HTTPS. `NOTICE_IMAGE_HOST_ALLOWLIST` can restrict hosts in production.
- Notice image upload keys now use `notice_images/...`, matching the public read-only Storage rules.

## STRIDE Notes

- Spoofing: callable writes require superadmin role checks; Firestore client writes are denied.
- Tampering: root documents are validated against the public allow-list before public reads are allowed.
- Repudiation: admin metadata keeps private edit history and migration pre-hashes.
- Information disclosure: private fields such as actor UID, target, FCM response, failure reason, and diagnostics are not stored at the root.
- Denial of service: per-admin and global broadcast rate limits are transactional.
- Elevation of privilege: admin/superadmin roles are read from the existing `users/{uid}.role` authority and enforced consistently in functions and rules.

## Operational Requirements

- Run `npm --prefix functions run notice:verify` before deploying public read rules to production.
- Keep `LEGACY_NOTICE_DUAL_READ=true` only during migration. Disable it after verifier stays green for one full release cycle.
- Review Cloud Logging for `notice_metric` and `rateLimitHit` events during rollout.

