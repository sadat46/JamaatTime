import { onCall, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';
import { requireString } from '../lib/validate';
import { log } from '../lib/logger';
import { logNoticeMetric } from '../notice/noticeMetrics';

// Superadmin retracts a broadcast from every user's notice board.
//
// This is NOT a purge: the notification doc, admin_meta, read-state and the
// Cloudflare R2 image are all preserved for audit/history. "Remove" means
// (1) hide from user notice-board queries (which filter publicVisible==true and
// status in ['sent','fallback_text']) and (2) best-effort cancel the OS
// notification on devices that rendered it in the foreground via a data-only
// tombstone push.
//
// Idempotent: removing a missing doc returns 'already_absent'; re-removing an
// already-removed doc is a no-op (no duplicate audit entry, no second tombstone).

export const removeBroadcast = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const notifId = requireString(data.notifId, 'notifId', { max: 128 });

    const notifRef = db.collection('notifications').doc(notifId);
    const schedRef = db.collection('scheduled_notifications').doc(notifId);
    const metaRef = notifRef.collection('admin_meta').doc('meta');

    // The transaction reports its outcome so we know whether to send a
    // tombstone after it commits.
    type Outcome = { kind: 'removed' | 'already_absent' | 'already_removed'; prevStatus?: string };

    const { kind: outcome, prevStatus } = await db.runTransaction<Outcome>(async (tx) => {
      const notifSnap = await tx.get(notifRef);
      if (!notifSnap.exists) return { kind: 'already_absent' };

      const status = notifSnap.data()?.status as string | undefined;
      if (status === 'removed') return { kind: 'already_removed', prevStatus: status };

      // A queued notice may still have a scheduled row the dispatcher would
      // otherwise pick up — drop it in the same transaction (defensive).
      if (status === 'queued') {
        const schedSnap = await tx.get(schedRef);
        if (schedSnap.exists) tx.delete(schedRef);
      }

      tx.update(notifRef, {
        status: 'removed',
        publicVisible: false,
        removedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(metaRef, {
        removedBy: me.uid,
        removedAt: FieldValue.serverTimestamp(),
        editHistory: FieldValue.arrayUnion({
          actor: me.uid,
          action: 'notice_removed',
          at: Timestamp.now(),
        }),
      }, { merge: true });
      return { kind: 'removed', prevStatus: status };
    });

    if (outcome === 'already_absent') {
      log.info('broadcast_remove_noop', { notifId, actor: me.uid, reason: 'absent' });
      return { notifId, status: 'already_absent' };
    }
    if (outcome === 'already_removed') {
      log.info('broadcast_remove_noop', { notifId, actor: me.uid, reason: 'already_removed' });
      return { notifId, status: 'removed', alreadyRemoved: true, tombstoneSent: false };
    }

    // Best-effort tombstone: failure here must never roll back the removal.
    // Data-only (no notification block) so clients silently cancel rather than
    // render. Foreground-rendered notifications cancel reliably; notifications
    // Android rendered natively while the app was killed are not cancelable here.
    let tombstoneSent = false;
    try {
      await getMessaging().send({
        topic: 'all_users',
        data: { action: 'remove_notice', notifId },
        android: { priority: 'high' },
      });
      tombstoneSent = true;
    } catch (err) {
      log.warn('broadcast_remove_tombstone_failed', {
        notifId,
        error: err instanceof Error ? err.message : String(err),
      });
    }

    log.info('broadcast_removed', { notifId, actor: me.uid, prevStatus, tombstoneSent });
    logNoticeMetric('notice.remove.count', { notifId, actorUid: me.uid });
    return { notifId, status: 'removed', tombstoneSent };
  },
);
