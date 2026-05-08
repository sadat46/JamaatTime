import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';
import { markNoticeExpired } from '../notice/noticeContract';
import { logNoticeMetric } from '../notice/noticeMetrics';

const EXPIRE_BATCH_LIMIT = 400;

export const expireNotices = onSchedule(
  { schedule: 'every 60 minutes', region: 'us-central1' },
  async () => {
    const now = Timestamp.now();
    const snap = await db
      .collection('notifications')
      .where('publicVisible', '==', true)
      .where('expiresAt', '<=', now)
      .limit(EXPIRE_BATCH_LIMIT)
      .get();

    if (snap.empty) {
      log.info('notice_expire_idle', { checkedAt: now.toMillis() });
      return;
    }

    let expired = 0;
    let failed = 0;
    for (const doc of snap.docs) {
      try {
        await markNoticeExpired({ notifId: doc.id, actor: 'expireNotices' });
        expired++;
      } catch (err) {
        failed++;
        log.error('notice_expire_failed', {
          notifId: doc.id,
          reason: (err as Error).message,
        });
      }
    }

    log.info('notice_expire_summary', { expired, failed });
    if (expired > 0) {
      logNoticeMetric('notice.expire.count', { count: expired });
    }
  },
);
