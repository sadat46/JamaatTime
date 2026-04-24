import { getMessaging } from 'firebase-admin/messaging';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';

// Internal helper shared by every broadcast code path:
//   - P4: broadcastNotification (text)
//   - P5: broadcastNotification (image + fallback)
//   - P7: scheduleBroadcast dispatcher
//   - P9: onJamaatChange auto-trigger
//
// Owns the full "draft → send → mark status" lifecycle so no caller has to
// reimplement the failure-reason contract.

export type BroadcastTargetKind =
  | 'all_users'
  | 'affected_location'
  | 'selected_users'
  | 'role_based';

export type BroadcastType = 'text' | 'image';

export interface BroadcastPayload {
  type: BroadcastType;
  title: string;
  body: string;
  imageUrl?: string | null;
  target: { kind: BroadcastTargetKind; value?: unknown };
  deepLink?: string | null;
  triggerSource: 'manual' | 'auto_jamaat_change';
  createdBy: string; // uid or "system"
  scheduledFor?: FirebaseFirestore.Timestamp | null;
  dedupKey?: string;
}

export interface BroadcastResult {
  notifId: string;
  messageId: string;
  sendMode: 'topic';
  status: 'sent' | 'fallback_text';
}

// Builds the FCM message for a given payload.
function buildFcmMessage(notifId: string, p: BroadcastPayload) {
  const data: Record<string, string> = {
    notifId,
    triggerSource: p.triggerSource,
  };
  if (p.deepLink) data.deepLink = p.deepLink;
  if (p.imageUrl) data.imageUrl = p.imageUrl;

  const androidNotif: Record<string, unknown> = {};
  if (p.imageUrl) androidNotif.imageUrl = p.imageUrl;

  return {
    topic: 'all_users',
    notification: { title: p.title, body: p.body },
    data,
    android: {
      priority: 'high' as const,
      notification: {
        ...androidNotif,
        channelId: 'broadcast_channel',
      },
    },
  };
}

// Resolves FCM target to a topic string. Only 'all_users' is wired in P4;
// future kinds throw until their Phase lands.
function resolveTopic(kind: BroadcastTargetKind): string {
  if (kind === 'all_users') return 'all_users';
  throw new Error(`target.kind='${kind}' is not implemented yet`);
}

export async function sendBroadcast(
  payload: BroadcastPayload,
  opts: { notifId?: string } = {},
): Promise<BroadcastResult> {
  const notifRef = opts.notifId
    ? db.collection('notifications').doc(opts.notifId)
    : db.collection('notifications').doc();
  const notifId = notifRef.id;

  const target = resolveTopic(payload.target.kind);

  await notifRef.set(
    {
      type: payload.type,
      title: payload.title,
      body: payload.body,
      imageUrl: payload.imageUrl ?? null,
      target: payload.target,
      deepLink: payload.deepLink ?? null,
      triggerSource: payload.triggerSource,
      createdBy: payload.createdBy,
      createdAt: FieldValue.serverTimestamp(),
      scheduledFor: payload.scheduledFor ?? null,
      status: 'sending',
      sendMode: 'topic',
      failureReason: null,
      fcmResponse: null,
      dedupKey: payload.dedupKey ?? null,
    },
    { merge: true },
  );

  try {
    const message = { ...buildFcmMessage(notifId, payload), topic: target };
    const messageId = await getMessaging().send(message);

    await notifRef.update({
      status: 'sent',
      fcmResponse: { sendMode: 'topic', messageId },
      sentAt: FieldValue.serverTimestamp(),
    });

    log.info('broadcast_sent', {
      notifId,
      target,
      type: payload.type,
      triggerSource: payload.triggerSource,
      createdBy: payload.createdBy,
    });

    return { notifId, messageId, sendMode: 'topic', status: 'sent' };
  } catch (err) {
    const reason = (err as Error).message ?? 'unknown';
    await notifRef.update({
      status: 'failed',
      failureReason: reason,
    });
    log.error('broadcast_failed', {
      notifId,
      target,
      reason,
      createdBy: payload.createdBy,
    });
    throw err;
  }
}
