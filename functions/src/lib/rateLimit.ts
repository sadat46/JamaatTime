import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from './firebase';
import { log } from './logger';

const ADMIN_LIMIT_PER_HOUR = 20;
const GLOBAL_LIMIT_PER_MINUTE = 30;
const GLOBAL_LIMIT_PER_HOUR = 200;
const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

interface RateBucket {
  minuteWindowStartMs?: number;
  minuteCount?: number;
  hourWindowStartMs?: number;
  hourCount?: number;
}

function windowStart(nowMs: number, windowMs: number): number {
  return Math.floor(nowMs / windowMs) * windowMs;
}

function nextCount(
  data: RateBucket,
  field: 'minute' | 'hour',
  startMs: number,
): number {
  const windowKey = `${field}WindowStartMs` as const;
  const countKey = `${field}Count` as const;
  return data[windowKey] === startMs ? (data[countKey] ?? 0) + 1 : 1;
}

function assertBelowLimit(params: {
  uid: string;
  scope: 'admin' | 'global';
  windowLabel: 'minute' | 'hour';
  count: number;
  limit: number;
}): void {
  if (params.count <= params.limit) return;
  log.warn('rateLimitHit', {
    uid: params.uid,
    scope: params.scope,
    window: params.windowLabel,
    count: params.count - 1,
    limit: params.limit,
  });
  throw new HttpsError(
    'resource-exhausted',
    `Rate limit: ${params.scope} ${params.windowLabel} broadcast ceiling reached.`,
  );
}

// Manual-broadcast limiter no longer queries notifications.createdBy because
// that field is private under notifications/{id}/admin_meta/meta.
export async function assertManualBroadcastBudget(uid: string): Promise<void> {
  const nowMs = Date.now();
  const minuteStart = windowStart(nowMs, MINUTE_MS);
  const hourStart = windowStart(nowMs, HOUR_MS);
  const adminRef = db.collection('admin_rate_limits').doc(uid);
  const globalRef = db.collection('admin_rate_limits').doc('_global');

  await db.runTransaction(async (tx) => {
    const [adminSnap, globalSnap] = await Promise.all([
      tx.get(adminRef),
      tx.get(globalRef),
    ]);
    const admin = (adminSnap.data() ?? {}) as RateBucket;
    const global = (globalSnap.data() ?? {}) as RateBucket;

    const adminHourCount = nextCount(admin, 'hour', hourStart);
    const globalMinuteCount = nextCount(global, 'minute', minuteStart);
    const globalHourCount = nextCount(global, 'hour', hourStart);

    assertBelowLimit({
      uid,
      scope: 'admin',
      windowLabel: 'hour',
      count: adminHourCount,
      limit: ADMIN_LIMIT_PER_HOUR,
    });
    assertBelowLimit({
      uid,
      scope: 'global',
      windowLabel: 'minute',
      count: globalMinuteCount,
      limit: GLOBAL_LIMIT_PER_MINUTE,
    });
    assertBelowLimit({
      uid,
      scope: 'global',
      windowLabel: 'hour',
      count: globalHourCount,
      limit: GLOBAL_LIMIT_PER_HOUR,
    });

    tx.set(adminRef, {
      uid,
      hourWindowStartMs: hourStart,
      hourCount: adminHourCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(globalRef, {
      minuteWindowStartMs: minuteStart,
      minuteCount: globalMinuteCount,
      hourWindowStartMs: hourStart,
      hourCount: globalHourCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

