import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { createHash } from 'crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';
import { sendBroadcast, BroadcastType } from '../broadcast/sendBroadcast';

// Firestore trigger — fires on every jamaat_times/{city}/daily_times/{date}
// update. Decides whether the change warrants a broadcast per the
// notification_rules/jamaat_change config, then hands off to sendBroadcast.
//
// Identity note: Firestore triggers run as the service account, NOT the
// end user, so `event.authContext` is not populated for client writes.
// We defensively read `after.updatedBy` + `after.writeSource` (stamped by
// JamaatService on every save) and verify the user has admin/superadmin
// role before broadcasting. P11 rules will additionally enforce that
// `updatedBy == request.auth.uid` at write-time so clients cannot spoof.

const RULE_DOC_PATH = 'notification_rules/jamaat_change';
const COOLDOWN_COLLECTION = 'notification_cooldowns';

interface JamaatTimesDoc {
  times?: Record<string, string>;
  updatedBy?: string;
  updatedByEmail?: string;
  writeSource?: string;
}

interface RuleDoc {
  autoNotifyOnJamaatChange?: boolean;
  autoNotifyMode?: 'off' | 'text' | 'image' | 'both';
  autoNotifyTarget?: 'all_users' | 'affected_location';
  minChangeMinutes?: number;
  cooldownSeconds?: number;
  defaultImageUrl?: string | null;
}

// Convert "HH:MM" → minutes since midnight; returns null if unparseable.
function parseHhmm(v: string | undefined): number | null {
  if (!v) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(v.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const mi = Number(m[2]);
  if (h < 0 || h > 23 || mi < 0 || mi > 59) return null;
  return h * 60 + mi;
}

// Returns the max absolute delta across all shared keys, plus the list of
// keys whose values changed at all. A `null` max means no comparable change.
function diffTimes(
  before: Record<string, string> | undefined,
  after: Record<string, string> | undefined,
): { maxDeltaMin: number | null; changedKeys: string[] } {
  const changedKeys: string[] = [];
  let maxDelta: number | null = null;
  if (!before || !after) {
    return { maxDeltaMin: null, changedKeys };
  }
  for (const key of Object.keys(after)) {
    if (before[key] !== after[key]) changedKeys.push(key);
    const bMin = parseHhmm(before[key]);
    const aMin = parseHhmm(after[key]);
    if (bMin == null || aMin == null) continue;
    const delta = Math.abs(aMin - bMin);
    if (maxDelta == null || delta > maxDelta) maxDelta = delta;
  }
  return { maxDeltaMin: maxDelta, changedKeys };
}

function pickBroadcastType(mode: RuleDoc['autoNotifyMode']): BroadcastType {
  // 'both' and 'image' ride the image path; 'text' and anything else ride text.
  return mode === 'image' || mode === 'both' ? 'image' : 'text';
}

// Checks the role of the uid that stamped the write. Abandons early for
// unknown users — the trigger should not fire based on rogue writes.
async function isTrustedWriter(uid: string): Promise<boolean> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) return false;
  const role = snap.data()?.role;
  return role === 'admin' || role === 'superadmin';
}

export const onJamaatChange = onDocumentUpdated(
  {
    document: 'jamaat_times/{city}/daily_times/{date}',
    region: 'us-central1',
  },
  async (event) => {
    const city = event.params.city as string;
    const date = event.params.date as string;
    const before = event.data?.before?.data() as JamaatTimesDoc | undefined;
    const after = event.data?.after?.data() as JamaatTimesDoc | undefined;

    if (!after) {
      log.info('jamaat_change_skip', { reason: 'no_after', city, date });
      return;
    }

    // Gate 1 — rule doc must exist and have autoNotify enabled.
    const ruleSnap = await db.doc(RULE_DOC_PATH).get();
    const rule = (ruleSnap.data() ?? {}) as RuleDoc;
    if (rule.autoNotifyOnJamaatChange !== true || rule.autoNotifyMode === 'off') {
      log.info('jamaat_change_skip', { reason: 'rule_disabled', city, date });
      return;
    }

    // Gate 2 — identity. The write must have come from the admin panel, and
    // the stamping uid must currently hold admin/superadmin role.
    if (after.writeSource !== 'admin_panel' || !after.updatedBy) {
      log.warn('jamaat_change_skip', {
        reason: 'untrusted_write_source',
        city,
        date,
        writeSource: after.writeSource ?? null,
      });
      return;
    }
    if (!(await isTrustedWriter(after.updatedBy))) {
      log.warn('jamaat_change_skip', {
        reason: 'writer_not_admin',
        city,
        date,
        updatedBy: after.updatedBy,
      });
      return;
    }

    // Gate 3 — minimum-change threshold. Skip noisy updates where nothing
    // actually moved by `minChangeMinutes`.
    const minChange = Math.max(0, rule.minChangeMinutes ?? 1);
    const { maxDeltaMin, changedKeys } = diffTimes(before?.times, after.times);
    if (changedKeys.length === 0) {
      log.info('jamaat_change_skip', { reason: 'no_time_changes', city, date });
      return;
    }
    if (maxDeltaMin != null && maxDeltaMin < minChange) {
      log.info('jamaat_change_skip', {
        reason: 'below_min_change',
        city,
        date,
        maxDeltaMin,
        minChange,
      });
      return;
    }

    // Gate 4 — dedup. Same city+date+times hash should fire once only.
    const dedupKey = createHash('sha1')
      .update(`${city}|${date}|${JSON.stringify(after.times ?? {})}`)
      .digest('hex');

    // Gate 5 — cooldown. Per-city lock kept in notification_cooldowns/{city}.
    const cooldownSec = Math.max(0, rule.cooldownSeconds ?? 300);
    const cooldownRef = db.collection(COOLDOWN_COLLECTION).doc(city);
    const nowMs = Date.now();

    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(cooldownRef);
      if (snap.exists) {
        const data = snap.data() ?? {};
        if (data.dedupKey === dedupKey) return { ok: false, why: 'dedup_hit' };
        const lastAt = data.lastAt as Timestamp | undefined;
        if (lastAt && nowMs - lastAt.toMillis() < cooldownSec * 1000) {
          return { ok: false, why: 'cooldown_active' };
        }
      }
      tx.set(cooldownRef, {
        dedupKey,
        lastAt: FieldValue.serverTimestamp(),
        city,
      });
      return { ok: true, why: 'claimed' };
    });

    if (!claimed.ok) {
      log.info('jamaat_change_skip', {
        reason: claimed.why,
        city,
        date,
        dedupKey,
      });
      return;
    }

    // Compose the broadcast. Use plain English — localization of the push
    // itself is out of scope; the app renders notif text as-is.
    const title = `Jamaat time updated: ${city}`;
    const prayersLabel = changedKeys.join(', ');
    const body = `Jamaat time for ${prayersLabel} has been updated for ${date}. Tap to view.`;
    const mode = rule.autoNotifyMode ?? 'text';
    const type = pickBroadcastType(mode);
    const imageUrl = type === 'image' ? rule.defaultImageUrl ?? null : null;

    try {
      const result = await sendBroadcast({
        type,
        title,
        body,
        imageUrl,
        target: { kind: 'all_users' },
        deepLink: `/home?city=${encodeURIComponent(city)}&date=${date}`,
        triggerSource: 'auto_jamaat_change',
        createdBy: 'system',
        scheduledFor: null,
        dedupKey,
      });
      log.info('jamaat_change_broadcast', {
        city,
        date,
        notifId: result.notifId,
        type,
        changedKeys,
        maxDeltaMin,
      });
    } catch (err) {
      log.error('jamaat_change_broadcast_failed', {
        city,
        date,
        reason: (err as Error).message,
      });
    }
  },
);
