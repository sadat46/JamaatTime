# Notice Board Admin Guide

## Send A Notice

1. Open the Notification Broadcast admin screen.
2. Choose text or image.
3. Enter title, body, optional image, and optional internal deep link.
4. Send now or schedule for later.

## Statuses

- `queued`: scheduled and hidden from public users.
- `sending`: dispatcher or immediate send is in progress.
- `sent`: FCM accepted the topic send and the notice is public.
- `fallback_text`: image delivery failed or was invalid; text was sent and the public notice is visible without an image.
- `failed`: send failed and the notice is hidden.
- `cancelled`: queued notice was cancelled and hidden.
- `expired`: notice passed `expiresAt` and is hidden.

## Retry And Cancel

- Retry failed notices from Notification History. The UI reuses merged root/admin metadata.
- Cancel only works for queued notices. Sent/fallback notices are no-op audited.

## Legacy Badge

Rows marked `legacy` are missing `admin_meta/meta`. They are expected only before Phase 5 migration completes.

