# Notification Broadcast — Test Matrix

Manual + on-device verification checklist. Run before each release that
touches `lib/services/notifications/`, `functions/src/{broadcast,scheduled,triggers}/`,
or `firestore.rules`. CI covers the unit/widget gates; this matrix
covers everything CI cannot reach (FCM delivery, Android system UI,
deployed Firestore rules).

Required hardware: one Pixel + one Samsung running stock Android, both
signed in to a real Google account so FCM tokens resolve.

## 1. Receive layer (P2)

| # | Scenario | Expected |
|---|----------|----------|
| 1.1 | Foreground app, topic push from Firebase console | Heads-up notification renders with title + body |
| 1.2 | Background (recents) | Tray notification, tap opens `/home` |
| 1.3 | Killed (force-stop) | Tray notification fires, tap cold-starts to `/home` |
| 1.4 | Guest (never signed in) | Notification still arrives — token written to `device_tokens/{installationId}` |
| 1.5 | Logged in | Token written to `user_tokens/{uid}`, old `device_tokens` row deleted |
| 1.6 | Image notification, foreground | `BigPictureStyleInformation` renders inline image |
| 1.7 | Image notification, broken URL | Falls back to text-only push, `notifications/{id}.status == 'fallback_text'` |

## 2. Manual broadcast (P4 + P5 + P6)

| # | Scenario | Expected |
|---|----------|----------|
| 2.1 | Superadmin opens admin form | Tile visible in Profile → Admin Tools |
| 2.2 | Non-superadmin admin | Broadcast tile hidden |
| 2.3 | Type SEND, send text | All devices receive within 30s; `notifications/{id}.status == 'sent'` |
| 2.4 | Type SEND, image valid | Foreground BigPicture renders; status `sent` |
| 2.5 | Type SEND, image 404 | Status `fallback_text`, `failureReason` starts with `image_invalid_` |
| 2.6 | Title >65 chars | Inline error, send button disabled |
| 2.7 | Body >240 chars | Inline error |

## 3. Schedule + cancel (P7)

| # | Scenario | Expected |
|---|----------|----------|
| 3.1 | Schedule +2 min | Row in `scheduled_notifications`, status `queued` |
| 3.2 | Wait 5 min | Dispatcher fires, push lands, row deleted, status `sent` |
| 3.3 | Cancel before fire | `cancelScheduledBroadcast` returns OK, status `cancelled` |
| 3.4 | Cancel after dispatcher claims | `failed-precondition` error |
| 3.5 | Schedule with bad image URL | Queued draft has `failureReason: image_invalid_*` |

## 4. Auto rules + jamaat trigger (P8 + P9)

| # | Scenario | Expected |
|---|----------|----------|
| 4.1 | Save rule with auto=on, mode=text | Doc at `notification_rules/jamaat_change` |
| 4.2 | Edit jamaat time (≥1 min Δ) | Single push within 1 min, `triggerSource=auto_jamaat_change`, `createdBy=system` |
| 4.3 | Re-save same value | No push (dedup hit) |
| 4.4 | Edit again within cooldown | No push (cooldown) |
| 4.5 | Edit with <1 min Δ | No push (below_min_change) |
| 4.6 | Toggle rule off, edit | No push (rule_disabled) |
| 4.7 | Edit `jamaat_times` doc directly via console (no `writeSource`) | No push, `untrusted_write_source` log |

## 5. History screen (P10)

| # | Scenario | Expected |
|---|----------|----------|
| 5.1 | Open as superadmin | List populated, paginated 20/page |
| 5.2 | Filter "Failed" | Only failed rows visible |
| 5.3 | Retry failed row | New `notifications/{id}` created, original unchanged |
| 5.4 | Cancel queued row | Inline cancel succeeds, list refreshes |
| 5.5 | Open as admin (non-super) | Screen returns "Superadmin only." |

## 6. Security (P11)

| # | Scenario | Expected |
|---|----------|----------|
| 6.1 | Non-admin tries `jamaat_times` write | Rule denial |
| 6.2 | Admin write missing `updatedBy` | Rule denial |
| 6.3 | Admin write with spoofed `writeSource: 'cli'` | Rule denial |
| 6.4 | Superadmin sends 21st broadcast in an hour | `resource-exhausted` |
| 6.5 | Random collection write attempt | Catch-all denies |

## Pass criteria

All rows in §1–§6 must pass on **both** devices before tagging a
release. Record exceptions in the release issue with device + OS
version + repro.
