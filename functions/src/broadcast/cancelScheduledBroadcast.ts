import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';
import { requireString } from '../lib/validate';
import { log } from '../lib/logger';

// Superadmin cancels a queued broadcast before the dispatcher claims it.
// Runs in a transaction: fails fast if the scheduled row is already claimed
// (i.e. the dispatcher is mid-send) so we never race into a double-send.
// On success the draft's status flips to 'cancelled' and the scheduled row
// is removed so the dispatcher will not pick it up.

export const cancelScheduledBroadcast = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const notifId = requireString(data.notifId, 'notifId', { max: 128 });

    const notifRef = db.collection('notifications').doc(notifId);
    const schedRef = db.collection('scheduled_notifications').doc(notifId);
    const metaRef = notifRef.collection('admin_meta').doc('meta');
    let finalStatus = 'cancelled';

    await db.runTransaction(async (tx) => {
      const notifSnap = await tx.get(notifRef);
      if (!notifSnap.exists) {
        throw new HttpsError('not-found', `notifications/${notifId} missing.`);
      }
      const status = notifSnap.data()?.status as string | undefined;
      if (status === 'sent' || status === 'fallback_text') {
        tx.set(metaRef, {
          editHistory: FieldValue.arrayUnion({
            actor: me.uid,
            action: 'cancel_noop_already_sent',
            at: Timestamp.now(),
          }),
        }, { merge: true });
        finalStatus = status;
        return;
      }

      const schedSnap = await tx.get(schedRef);
      if (!schedSnap.exists) {
        throw new HttpsError(
          'not-found',
          `scheduled_notifications/${notifId} does not exist.`,
        );
      }
      if (schedSnap.data()?.claimed === true) {
        throw new HttpsError(
          'failed-precondition',
          'broadcast already claimed by dispatcher; cannot cancel.',
        );
      }
      if (status !== 'queued') {
        throw new HttpsError(
          'failed-precondition',
          `cannot cancel broadcast with status='${status ?? 'unknown'}'.`,
        );
      }

      tx.update(notifRef, {
        status: 'cancelled',
        publicVisible: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(metaRef, {
        cancelledAt: FieldValue.serverTimestamp(),
        cancelledBy: me.uid,
        editHistory: FieldValue.arrayUnion({
          actor: me.uid,
          action: 'notice_cancelled',
          at: Timestamp.now(),
        }),
      }, { merge: true });
      tx.delete(schedRef);
    });

    log.info('broadcast_cancelled', { notifId, cancelledBy: me.uid, finalStatus });
    return { notifId, status: finalStatus };
  },
);
