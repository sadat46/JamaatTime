import { getMessaging } from 'firebase-admin/messaging';

import { db } from '../lib/firebase';
import { log } from '../lib/logger';
import {
  adminMetaRef,
  markNoticeFailed,
  NoticePriority,
  NoticeTriggerSource,
  publishNotice,
  validatePublicPayload,
  writeAdminMeta,
  writeNoticeDraft,
} from '../notice/noticeContract';
import { logNoticeMetric } from '../notice/noticeMetrics';

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
  triggerSource: 'manual' | 'auto_jamaat_change' | NoticeTriggerSource;
  createdBy: string; // uid or "system"
  scheduledFor?: FirebaseFirestore.Timestamp | null;
  expiresAt?: FirebaseFirestore.Timestamp | null;
  dedupKey?: string;
  idempotencyKey?: string;
  priority?: NoticePriority;
  imageFallbackReason?: string | null;
}

export interface BroadcastResult {
  notifId: string;
  messageId: string;
  sendMode: 'topic';
  status: 'sent' | 'fallback_text';
}

// Builds the FCM message for a given payload.
function buildFcmMessage(
  notifId: string,
  p: BroadcastPayload,
  opts: { imageUrl?: string | null; schemaVersion: number; noticeType: string },
) {
  const data: Record<string, string> = {
    notifId,
    notification_id: notifId,
    title: p.title,
    body: p.body,
    triggerSource: p.triggerSource,
    type: opts.noticeType,
    priority: p.priority ?? 'normal',
    schemaVersion: String(opts.schemaVersion),
    payload: JSON.stringify({
      notifId,
      deepLink: p.deepLink ?? null,
      type: opts.noticeType,
      priority: p.priority ?? 'normal',
      schemaVersion: opts.schemaVersion,
    }),
  };
  if (p.deepLink) data.deepLink = p.deepLink;
  if (opts.imageUrl) data.imageUrl = opts.imageUrl;

  const androidNotif: Record<string, unknown> = {};
  if (opts.imageUrl) androidNotif.imageUrl = opts.imageUrl;

  return {
    topic: 'all_users',
    notification: { title: p.title, body: p.body },
    data,
    android: {
      priority: 'high' as const,
      notification: {
        ...androidNotif,
        channelId: 'notice_board',
      },
    },
  };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendWithSingleRetry(message: ReturnType<typeof buildFcmMessage>) {
  try {
    return await getMessaging().send(message);
  } catch (err) {
    await delay(500);
    try {
      return await getMessaging().send(message);
    } catch {
      throw err;
    }
  }
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
  const publicPayload = validatePublicPayload({
    notifId,
    title: payload.title,
    body: payload.body,
    imageUrl: payload.imageFallbackReason ? null : payload.imageUrl,
    deepLink: payload.deepLink,
    type: payload.triggerSource === 'auto_jamaat_change'
      ? 'jamaat_time_change'
      : 'announcement',
    triggerSource: payload.triggerSource,
    scheduledFor: payload.scheduledFor ?? null,
    expiresAt: payload.expiresAt ?? null,
    priority: payload.priority ?? 'normal',
    imageFallback: Boolean(payload.imageFallbackReason),
  });
  const idempotencyKey =
    payload.idempotencyKey ?? payload.dedupKey ?? `broadcast:${notifId}`;

  await writeNoticeDraft({
    notifRef,
    payload: publicPayload,
    status: 'sending',
    adminMeta: {
      createdBy: payload.createdBy,
      target: payload.target,
      sendMode: 'topic',
      failureReason: payload.imageFallbackReason ?? null,
      fcmResponse: null,
      dedupKey: payload.dedupKey ?? null,
      idempotencyKey,
      broadcastType: payload.type,
    },
  });

  try {
    const message = {
      ...buildFcmMessage(notifId, payload, {
        imageUrl: publicPayload.imageUrl,
        schemaVersion: publicPayload.schemaVersion,
        noticeType: publicPayload.type,
      }),
      topic: target,
    };
    const messageId = payload.imageUrl
      ? await sendWithSingleRetry(message)
      : await getMessaging().send(message);

    const fcmResponse = {
        sendMode: 'topic',
        messageId,
        deliveryReceiptTracked: false,
        perTokenErrorsTracked: false,
      };
    await publishNotice({
      notifId,
      messageId,
      fcmResponse,
      actor: payload.createdBy,
      imageFallback: Boolean(payload.imageFallbackReason),
      failureReason: payload.imageFallbackReason ?? null,
    });

    log.info('broadcast_sent', {
      notifId,
      target,
      type: payload.type,
      triggerSource: payload.triggerSource,
      createdBy: payload.createdBy,
      publicVisible: true,
    });
    logNoticeMetric(payload.imageFallbackReason ? 'notice.fallback.count' : 'notice.sent.count', {
      notifId,
      triggerSource: payload.triggerSource,
      priority: payload.priority ?? 'normal',
    });

    return {
      notifId,
      messageId,
      sendMode: 'topic',
      status: payload.imageFallbackReason ? 'fallback_text' : 'sent',
    };
  } catch (err) {
    const reason = (err as Error).message ?? 'unknown';
    if (payload.imageUrl && !payload.imageFallbackReason) {
      try {
        const fallbackPayload: BroadcastPayload = {
          ...payload,
          type: 'text',
          imageUrl: null,
          imageFallbackReason: `image_send_failed:${reason}`,
        };
        const fallbackMessage = {
          ...buildFcmMessage(notifId, fallbackPayload, {
            imageUrl: null,
            schemaVersion: publicPayload.schemaVersion,
            noticeType: publicPayload.type,
          }),
          topic: target,
        };
        const messageId = await getMessaging().send(fallbackMessage);
        const fcmResponse = {
          sendMode: 'topic',
          messageId,
          deliveryReceiptTracked: false,
          perTokenErrorsTracked: false,
        };
        await publishNotice({
          notifId,
          messageId,
          fcmResponse,
          actor: payload.createdBy,
          imageFallback: true,
          failureReason: `image_send_failed:${reason}`,
        });
        await writeAdminMeta(notifId, {
          broadcastType: 'text',
        });
        log.warn('broadcast_image_send_fallback', {
          notifId,
          target,
          reason,
          createdBy: payload.createdBy,
        });
        logNoticeMetric('notice.fallback.count', {
          notifId,
          reason: 'image_send_failed',
        });
        return { notifId, messageId, sendMode: 'topic', status: 'fallback_text' };
      } catch (fallbackErr) {
        await markNoticeFailed({
          notifId,
          reason: (fallbackErr as Error).message ?? reason,
          actor: payload.createdBy,
        });
        log.error('broadcast_failed_after_image_fallback', {
          notifId,
          target,
          reason: (fallbackErr as Error).message,
          createdBy: payload.createdBy,
        });
        logNoticeMetric('notice.failed.count', {
          notifId,
          reason: 'fallback_send_failed',
        });
        throw fallbackErr;
      }
    }
    await markNoticeFailed({
      notifId,
      reason,
      actor: payload.createdBy,
    });
    log.error('broadcast_failed', {
      notifId,
      target,
      reason,
      createdBy: payload.createdBy,
      metaPath: adminMetaRef(notifId).path,
    });
    logNoticeMetric('notice.failed.count', { notifId, reason });
    throw err;
  }
}
