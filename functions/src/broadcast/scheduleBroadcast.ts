import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';
import { requireString, requireEnum, optionalString } from '../lib/validate';
import { log } from '../lib/logger';
import { BroadcastTargetKind, BroadcastType } from './sendBroadcast';
import { validateImageUrl } from './validateImage';

// Writes a queued broadcast in one transaction:
//   notifications/{id}                — status='queued', full payload
//   scheduled_notifications/{id}      — fireAt + claimed:false for dispatcher
//
// Image validation mirrors broadcastNotification (P5): if the image fails the
// HEAD check, the queued draft is demoted to text and the failureReason is
// recorded so the dispatcher can send text without re-validating. Clients
// never write scheduled_notifications/** directly — this is the only entry.

const TARGETS = [
  'all_users',
  'affected_location',
  'selected_users',
  'role_based',
] as const;

const TYPES = ['text', 'image'] as const;

// Reject fireAt earlier than (now - 1s) so clock skew does not flake a send
// meant for "right now"; dispatcher will still pick it up within 5 min.
const PAST_TOLERANCE_MS = 1000;

export const scheduleBroadcast = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    const type = requireEnum(data.type, 'type', TYPES) as BroadcastType;
    const title = requireString(data.title, 'title', { max: 65 });
    const body = requireString(data.body, 'body', { max: 240 });
    const deepLink = optionalString(data.deepLink, 'deepLink', { max: 500 });
    const rawImageUrl = optionalString(data.imageUrl, 'imageUrl', { max: 2000 });

    const targetObj = (data.target ?? {}) as { kind?: unknown };
    const targetKind = requireEnum(
      targetObj.kind,
      'target.kind',
      TARGETS,
    ) as BroadcastTargetKind;
    if (targetKind !== 'all_users') {
      throw new HttpsError(
        'unimplemented',
        `target.kind='${targetKind}' is not available yet.`,
      );
    }

    const fireAtRaw = data.fireAt;
    const fireAtMs =
      typeof fireAtRaw === 'number'
        ? fireAtRaw
        : typeof fireAtRaw === 'string'
          ? Number(fireAtRaw)
          : NaN;
    if (!Number.isFinite(fireAtMs)) {
      throw new HttpsError(
        'invalid-argument',
        'fireAt must be a unix-ms number.',
      );
    }
    if (fireAtMs < Date.now() - PAST_TOLERANCE_MS) {
      throw new HttpsError(
        'invalid-argument',
        'fireAt must not be in the past.',
      );
    }
    const fireAt = Timestamp.fromMillis(fireAtMs);

    let effectiveType: BroadcastType = type;
    let effectiveImageUrl: string | null = null;
    let fallbackReason: string | null = null;

    if (type === 'image') {
      if (!rawImageUrl) {
        throw new HttpsError(
          'invalid-argument',
          'imageUrl is required when type=image.',
        );
      }
      const result = await validateImageUrl(rawImageUrl);
      if (result.ok) {
        effectiveImageUrl = rawImageUrl;
      } else {
        effectiveType = 'text';
        fallbackReason = `image_invalid_${result.reason}`;
        log.warn('schedule_image_fallback', {
          imageUrl: rawImageUrl,
          reason: result.reason,
          detail: result.detail ?? null,
          uid: me.uid,
        });
      }
    }

    const notifRef = db.collection('notifications').doc();
    const notifId = notifRef.id;
    const schedRef = db.collection('scheduled_notifications').doc(notifId);

    await db.runTransaction(async (tx) => {
      tx.set(notifRef, {
        type: effectiveType,
        title,
        body,
        imageUrl: effectiveImageUrl,
        target: { kind: targetKind },
        deepLink: deepLink ?? null,
        triggerSource: 'manual',
        createdBy: me.uid,
        createdAt: FieldValue.serverTimestamp(),
        scheduledFor: fireAt,
        status: 'queued',
        sendMode: 'topic',
        failureReason: fallbackReason,
        fcmResponse: null,
        dedupKey: null,
      });
      tx.set(schedRef, {
        payloadRef: `notifications/${notifId}`,
        fireAt,
        claimed: false,
        createdBy: me.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    log.info('broadcast_scheduled', {
      notifId,
      fireAtMs,
      type: effectiveType,
      fallbackReason,
      createdBy: me.uid,
    });

    return {
      notifId,
      fireAt: fireAtMs,
      status: 'queued',
      failureReason: fallbackReason,
    };
  },
);
