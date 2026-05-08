# Notice Board Contract

## Public Root: `notifications/{notifId}`

Allowed public keys:

- Identity: `schemaVersion`, `notifId`
- Content: `type`, `category`, `title`, `body`, `imageUrl`, `imageWidth`, `imageHeight`, `imageBlurHash`, `imageFallback`, `deepLink`, `locale`, `localizedVariants`
- Lifecycle: `status`, `publicVisible`, `priority`, `pinned`, `expiresAt`, `archivedAt`
- Provenance: `triggerSource`, `audience`, `createdAt`, `scheduledFor`, `sentAt`, `publishedAt`, `updatedAt`

Public read invariant:

`publicVisible == true`, `status in ['sent', 'fallback_text']`, `expiresAt == null || expiresAt > request.time`, and root keys must be a subset of the allow-list.

## Private Metadata: `notifications/{notifId}/admin_meta/meta`

Private keys include actor, target, send mode, FCM response, failure details, idempotency/dedup keys, retry state, cancellation state, diagnostics, and migration metadata.

## Scripts

- `npm --prefix functions run notice:migrate -- --dry-run`
- `npm --prefix functions run notice:migrate -- --live`
- `npm --prefix functions run notice:verify`

