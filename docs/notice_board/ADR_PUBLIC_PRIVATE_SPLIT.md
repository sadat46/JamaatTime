# ADR: Notice Board Public/Private Split

## Decision

Public notice content stays in `notifications/{notifId}`. Operational metadata moves to `notifications/{notifId}/admin_meta/meta`.

## Rationale

- Guests must be able to read public notices without exposing admin identity, targets, FCM provider responses, retry state, IP hashes, user agents, diagnostics, or migration data.
- Firestore rules can block public reads if the root document contains any non-public key.
- Admin history still works by merging the root document with `admin_meta/meta`.

## Consequences

- All backend writes must use the notice contract helpers.
- Admin UI needs a metadata read per row during migration.
- Public read rules must not be deployed until the migration verifier reports zero offenders.

