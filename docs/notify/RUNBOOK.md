# Notification Broadcast — Runbook

Operator's guide for the FCM broadcast system. Read before responding
to a paging incident or rolling out a config change.

## Architecture at a glance

```
admin (Flutter) ──▶ broadcastNotification (callable)  ──┐
                    scheduleBroadcast (callable)        ├──▶ sendBroadcast() ──▶ FCM topic 'all_users'
                    cancelScheduledBroadcast (callable) │           │
                                                        │           └──▶ writes notifications/{id}
                                                        │
jamaat_times write ──▶ onJamaatChange (Firestore trig) ─┘
                          │
                          └──▶ reads notification_rules/jamaat_change
                               + notification_cooldowns/{city}

dispatchScheduledNotifications (every 5 min Pub/Sub)
   └──▶ scheduled_notifications where claimed=false AND fireAt<=now
        ──▶ sendBroadcast()
```

All sends funnel through `functions/src/broadcast/sendBroadcast.ts`.
That helper owns the draft → send → status lifecycle. Never duplicate
its body in a new caller.

## Where things live

| Concern | Path |
|---------|------|
| Manual send callable | `functions/src/broadcast/broadcastNotification.ts` |
| Schedule callable | `functions/src/broadcast/scheduleBroadcast.ts` |
| Cancel callable | `functions/src/broadcast/cancelScheduledBroadcast.ts` |
| Dispatcher (Pub/Sub) | `functions/src/scheduled/dispatchScheduledNotifications.ts` |
| Auto-trigger | `functions/src/triggers/onJamaatChange.ts` |
| Rate limiter | `functions/src/lib/rateLimit.ts` |
| Auth guards | `functions/src/lib/auth.ts` |
| Image HEAD check | `functions/src/broadcast/validateImage.ts` |
| Receive layer (Flutter) | `lib/services/notifications/` |
| Admin UI | `lib/screens/admin_notification_*.dart`, `lib/screens/admin_auto_rules_screen.dart` |

## Firestore collections

- `notifications/{id}` — append-only history. Backend writes only.
  Status lifecycle: `sending → sent | failed | fallback_text` for
  immediate sends; `queued → sent | cancelled | failed` for scheduled.
- `scheduled_notifications/{id}` — dispatcher worklist. `claimed: bool`,
  `fireAt: Timestamp`. Deleted after successful send.
- `notification_rules/jamaat_change` — single config doc, written by
  superadmin via the auto-rules screen.
- `notification_cooldowns/{city}` — P9 dedup + cooldown lock. Functions
  only.
- `user_tokens/{uid}` / `device_tokens/{installationId}` — FCM tokens.
  Receive layer writes; functions read.

## Common incidents

### "A scheduled push didn't fire"

1. `firebase functions:log --only dispatchScheduledNotifications` —
   look for `scheduled_dispatch_summary` logs every 5 min.
2. Open Firestore: `scheduled_notifications/{id}`. If `claimed: true`
   and the row still exists, `sendBroadcast` threw — check
   `notifications/{id}.failureReason`.
3. If `claimed: false` and `fireAt < now` for >10 min, the scheduler
   trigger is broken. Re-deploy the function and verify Pub/Sub job
   exists in GCP Console → Cloud Scheduler.

### "Auto-trigger isn't firing on a jamaat edit"

Logs show one of these reasons; treat each by name:

- `rule_disabled` — `autoNotifyOnJamaatChange === false` or `mode='off'`.
  Check `notification_rules/jamaat_change`.
- `untrusted_write_source` — write didn't go through `JamaatService`.
  Someone edited via the Firebase console or a script.
- `writer_not_admin` — `updatedBy` uid no longer has admin role.
- `below_min_change` — Δ smaller than `minChangeMinutes`. Expected.
- `dedup_hit` / `cooldown_active` — same payload or too soon. Expected.

### "Rate limit hit unexpectedly"

`assertManualBroadcastBudget` counts every `notifications/{id}` where
`createdBy == uid` AND `createdAt >= now-1h`. Failed and queued sends
both count. To reset before the hour, no-op — the limiter is
deliberately uncircumventable. If a real emergency requires more,
temporarily raise `LIMIT_PER_HOUR` in `rateLimit.ts` and redeploy.

### "Image broadcast didn't render"

Two paths:

1. **Foreground**: `FcmForegroundRenderer` downloads bytes via `http`.
   Check `flutter logs` for the `image_fetch_*` line.
2. **Background/killed**: Android renders the FCM `notification.image`
   directly. If the URL fails, OS silently drops the image and shows
   text-only.

The send-side HEAD check rejects non-2xx, non-image-content-type, and
URLs over 5 MB. If a valid image is being rejected, log the
`broadcast_image_fallback` entry's `reason` and check
`validateImage.ts`.

## Toggles & dials

- `LIMIT_PER_HOUR` in `functions/src/lib/rateLimit.ts` — broadcasts/hr cap.
- `BATCH_LIMIT` in `dispatchScheduledNotifications.ts` — rows per tick.
- `minChangeMinutes`, `cooldownSeconds`, `defaultImageUrl` — runtime via
  the Auto Rules screen, no redeploy.
- Schedule cadence — `every 5 minutes` in `dispatchScheduledNotifications.ts`.
  Lower bound is 1 min; tightening costs proportional Pub/Sub invocations.

## Logs to grep

| Event | Function |
|-------|----------|
| `broadcast_sent` / `broadcast_failed` | sendBroadcast |
| `broadcast_image_fallback` | broadcastNotification |
| `scheduled_dispatch_summary` | dispatcher |
| `jamaat_change_skip` (with `reason`) | onJamaatChange |
| `jamaat_change_broadcast` | onJamaatChange (success) |

All structured-logged via `functions/src/lib/logger.ts`.
