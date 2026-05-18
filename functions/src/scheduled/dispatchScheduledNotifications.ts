import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';
import { sendBroadcast, BroadcastTargetKind } from '../broadcast/sendBroadcast';
import { loadBroadcastDraft, markNoticeExpired } from '../notice/noticeContract';

// Pub/Sub-scheduled dispatcher. Runs every 5 minutes, claims due
// scheduled_notifications rows atomically, and hands the draft to the shared
// sendBroadcast helper so the send path is identical to the immediate one
// from P4/P5. The scheduled row is deleted on success and on terminal
// failure (attempts >= MAX_ATTEMPTS); for non-terminal failures the claim
// is released after STALE_CLAIM_MS so the next run retries.

const BATCH_LIMIT = 100;
const STALE_CLAIM_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 3;

export const dispatchScheduledNotifications = onSchedule(
  { schedule: 'every 5 minutes', region: 'us-central1' },
  async () => {
    const now = Timestamp.now();

    // Recovery pass: release stale claims so transient failures don't
    // permanently strand scheduled rows.
    let recovered = 0;
    try {
      const staleCutoff = Timestamp.fromMillis(now.toMillis() - STALE_CLAIM_MS);
      const staleSnap = await db
        .collection('scheduled_notifications')
        .where('claimed', '==', true)
        .where('claimedAt', '<=', staleCutoff)
        .limit(BATCH_LIMIT)
        .get();
      for (const stale of staleSnap.docs) {
        const attempts = (stale.data()?.attempts as number | undefined) ?? 0;
        if (attempts >= MAX_ATTEMPTS) {
          await stale.ref.delete();
          log.warn('scheduled_dispatch_terminal_drop', {
            notifId: stale.id,
            attempts,
          });
          continue;
        }
        await stale.ref.update({
          claimed: false,
          claimedAt: FieldValue.delete(),
          attempts: attempts + 1,
          lastRecoveredAt: FieldValue.serverTimestamp(),
        });
        recovered++;
        log.info('scheduled_dispatch_recover', {
          notifId: stale.id,
          attempts: attempts + 1,
        });
      }
    } catch (err) {
      log.error('scheduled_dispatch_recover_failed', {
        reason: (err as Error).message,
      });
    }

    const dueSnap = await db
      .collection('scheduled_notifications')
      .where('claimed', '==', false)
      .where('fireAt', '<=', now)
      .limit(BATCH_LIMIT)
      .get();

    if (dueSnap.empty) {
      log.info('scheduled_dispatch_idle', {
        checkedAt: now.toMillis(),
        recovered,
      });
      return;
    }

    let dispatched = 0;
    let skipped = 0;
    let failed = 0;

    for (const schedDoc of dueSnap.docs) {
      const notifId = schedDoc.id;

      // Pre-claim checks: load draft and verify lifecycle state BEFORE
      // setting claimed=true, so an early throw cannot strand the row.
      const notifRef = db.collection('notifications').doc(notifId);
      const draft = await loadBroadcastDraft(notifId);
      if (!draft) {
        log.warn('scheduled_draft_missing', { notifId });
        // No payload to send and no useful retry — drop the orphan row.
        await schedDoc.ref.delete();
        skipped++;
        continue;
      }
      const currentSnap = await notifRef.get();
      const currentStatus = currentSnap.data()?.status as string | undefined;
      if (currentStatus === 'cancelled') {
        await schedDoc.ref.delete();
        skipped++;
        continue;
      }
      if (draft.expiresAt && draft.expiresAt.toMillis() < now.toMillis()) {
        await markNoticeExpired({
          notifId,
          actor: 'dispatchScheduledNotifications',
        });
        await schedDoc.ref.delete();
        skipped++;
        continue;
      }

      // Claim the row only after the pre-checks pass; another runner may
      // have grabbed it concurrently.
      const claimed = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(schedDoc.ref);
        if (!fresh.exists) return false;
        if (fresh.data()?.claimed === true) return false;
        tx.update(schedDoc.ref, {
          claimed: true,
          claimedAt: FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!claimed) {
        skipped++;
        continue;
      }

      const preFallbackReason = draft.failureReason ?? null;
      try {
        await sendBroadcast(
          {
            type: draft.type,
            title: draft.title,
            body: draft.body,
            imageUrl: draft.imageUrl ?? null,
            target: {
              kind: draft.target.kind as BroadcastTargetKind,
              value: draft.target.value,
            },
            deepLink: draft.deepLink ?? null,
            triggerSource: draft.triggerSource,
            createdBy: draft.createdBy,
            scheduledFor: draft.scheduledFor ?? null,
            idempotencyKey: draft.idempotencyKey ?? `schedule:${notifId}`,
            imageFallbackReason: preFallbackReason,
          },
          { notifId },
        );

        await schedDoc.ref.delete();
        dispatched++;
      } catch (err) {
        const attempts =
          (schedDoc.data()?.attempts as number | undefined) ?? 0;
        log.error('scheduled_dispatch_failed', {
          notifId,
          attempts,
          reason: (err as Error).message,
        });
        if (attempts + 1 >= MAX_ATTEMPTS) {
          // Terminal: notifications/{id}.status is already 'failed' (set by
          // sendBroadcast), so dropping the scheduled row makes the
          // notifications doc the single source of truth for retry.
          try {
            await schedDoc.ref.delete();
            log.warn('scheduled_dispatch_terminal_drop', {
              notifId,
              attempts: attempts + 1,
            });
          } catch (delErr) {
            log.error('scheduled_dispatch_terminal_drop_failed', {
              notifId,
              reason: (delErr as Error).message,
            });
          }
        }
        // Non-terminal: leave claimed=true; the next run's recovery pass
        // will release it after STALE_CLAIM_MS so it gets retried.
        failed++;
      }
    }

    log.info('scheduled_dispatch_summary', {
      dispatched,
      skipped,
      failed,
      recovered,
    });
  },
);
