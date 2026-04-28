import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';

const ARCHIVE_AFTER_DAYS = 180;
const ARCHIVE_BATCH_LIMIT = 200;

export const archiveOldNotices = onSchedule(
  { schedule: 'every 24 hours', region: 'us-central1' },
  async () => {
    const cutoff = Timestamp.fromMillis(
      Date.now() - ARCHIVE_AFTER_DAYS * 24 * 60 * 60 * 1000,
    );
    const snap = await db
      .collection('notifications')
      .where('publicVisible', '==', false)
      .where('publishedAt', '<=', cutoff)
      .limit(ARCHIVE_BATCH_LIMIT)
      .get();

    if (snap.empty) {
      log.info('notice_archive_idle', { cutoff: cutoff.toMillis() });
      return;
    }

    const batch = db.batch();
    let archived = 0;
    for (const doc of snap.docs) {
      const metaRef = doc.ref.collection('admin_meta').doc('meta');
      const metaSnap = await metaRef.get();
      const archiveRef = db.collection('notifications_archive').doc(doc.id);
      batch.set(archiveRef, {
        ...doc.data(),
        archivedFrom: doc.ref.path,
        archivedAt: FieldValue.serverTimestamp(),
      });
      if (metaSnap.exists) {
        batch.set(archiveRef.collection('admin_meta').doc('meta'), metaSnap.data());
        batch.delete(metaRef);
      }
      batch.delete(doc.ref);
      archived++;
    }
    await batch.commit();
    log.info('notice_archive_summary', { archived });
  },
);

