import { HttpsError } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';

import { db } from './firebase';

// P11: manual-broadcast rate limiter. Counts notifications created by the
// given uid within the last hour (both sent and queued count — a superadmin
// cannot evade by scheduling 50 pushes). auto_jamaat_change pushes are
// excluded because they are authored by createdBy='system'.
//
// Throws `resource-exhausted` when the limit is hit. Firestore count()
// aggregations bill per read; one aggregate per call is acceptable for
// superadmin-only traffic.

const LIMIT_PER_HOUR = 20;
const WINDOW_MS = 60 * 60 * 1000;

export async function assertManualBroadcastBudget(uid: string): Promise<void> {
  const windowStart = Timestamp.fromMillis(Date.now() - WINDOW_MS);
  const aggr = await db
    .collection('notifications')
    .where('createdBy', '==', uid)
    .where('createdAt', '>=', windowStart)
    .count()
    .get();
  const count = aggr.data().count;
  if (count >= LIMIT_PER_HOUR) {
    throw new HttpsError(
      'resource-exhausted',
      `Rate limit: at most ${LIMIT_PER_HOUR} broadcasts per hour. You have ${count} in the last hour.`,
    );
  }
}
