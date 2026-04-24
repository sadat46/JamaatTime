import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';
import {
  sendBroadcast,
  BroadcastTargetKind,
  BroadcastType,
} from '../broadcast/sendBroadcast';

// Pub/Sub-scheduled dispatcher. Runs every 5 minutes, claims any due
// scheduled_notifications row atomically, and hands the draft to the shared
// sendBroadcast helper so the send path is identical to the immediate one
// from P4/P5. The scheduled row is deleted on success; on failure the row
// stays claimed so the doc is not retried (sendBroadcast already marked the
// notifications/{id} doc as 'failed', visible in P10 history for retry).

const BATCH_LIMIT = 100;

interface NotifDoc {
  type?: BroadcastType;
  title?: string;
  body?: string;
  imageUrl?: string | null;
  target?: { kind?: BroadcastTargetKind };
  deepLink?: string | null;
  createdBy?: string;
  scheduledFor?: Timestamp;
  status?: string;
  failureReason?: string | null;
}

export const dispatchScheduledNotifications = onSchedule(
  { schedule: 'every 5 minutes', region: 'us-central1' },
  async () => {
    const now = Timestamp.now();
    const dueSnap = await db
      .collection('scheduled_notifications')
      .where('claimed', '==', false)
      .where('fireAt', '<=', now)
      .limit(BATCH_LIMIT)
      .get();

    if (dueSnap.empty) {
      log.info('scheduled_dispatch_idle', { checkedAt: now.toMillis() });
      return;
    }

    let dispatched = 0;
    let skipped = 0;
    let failed = 0;

    for (const schedDoc of dueSnap.docs) {
      const notifId = schedDoc.id;

      // Claim the row. If another runner got it first, skip.
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

      const notifRef = db.collection('notifications').doc(notifId);
      const notifSnap = await notifRef.get();
      if (!notifSnap.exists) {
        log.warn('scheduled_draft_missing', { notifId });
        skipped++;
        continue;
      }
      const draft = notifSnap.data() as NotifDoc;
      if (draft.status === 'cancelled') {
        // Cancelled after we claimed; clean up the scheduled row and move on.
        await schedDoc.ref.delete();
        skipped++;
        continue;
      }
      if (
        !draft.type ||
        !draft.title ||
        !draft.body ||
        !draft.target?.kind ||
        !draft.createdBy
      ) {
        log.error('scheduled_draft_incomplete', { notifId });
        failed++;
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
            target: { kind: draft.target.kind },
            deepLink: draft.deepLink ?? null,
            triggerSource: 'manual',
            createdBy: draft.createdBy,
            scheduledFor: draft.scheduledFor ?? null,
          },
          { notifId },
        );

        if (preFallbackReason) {
          await notifRef.update({
            status: 'fallback_text',
            failureReason: preFallbackReason,
            fallbackAt: FieldValue.serverTimestamp(),
          });
        }

        await schedDoc.ref.delete();
        dispatched++;
      } catch (err) {
        log.error('scheduled_dispatch_failed', {
          notifId,
          reason: (err as Error).message,
        });
        failed++;
      }
    }

    log.info('scheduled_dispatch_summary', { dispatched, skipped, failed });
  },
);
