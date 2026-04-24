import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';
import { requireString, requireEnum, optionalString } from '../lib/validate';
import { log } from '../lib/logger';
import { sendBroadcast, BroadcastTargetKind, BroadcastType } from './sendBroadcast';
import { validateImageUrl } from './validateImage';
import { assertManualBroadcastBudget } from '../lib/rateLimit';

// P4: text-only manual broadcast.
// P5: extended to accept type='image' + imageUrl with HEAD validation and
// text fallback (reason recorded in notifications.failureReason).

const TARGETS = [
  'all_users',
  'affected_location',
  'selected_users',
  'role_based',
] as const;

const TYPES = ['text', 'image'] as const;

export const broadcastNotification = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    await assertManualBroadcastBudget(me.uid);
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

    let imageUrl: string | null = null;
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
        imageUrl = rawImageUrl;
      } else {
        // body is already required above, so a text fallback always has content.
        fallbackReason = `image_invalid_${result.reason}`;
        log.warn('broadcast_image_fallback', {
          imageUrl: rawImageUrl,
          reason: result.reason,
          detail: result.detail ?? null,
          uid: me.uid,
        });
      }
    }

    const result = await sendBroadcast({
      type: fallbackReason ? 'text' : type,
      title,
      body,
      imageUrl,
      target: { kind: targetKind },
      deepLink,
      triggerSource: 'manual',
      createdBy: me.uid,
    });

    if (fallbackReason) {
      await db.collection('notifications').doc(result.notifId).update({
        status: 'fallback_text',
        failureReason: fallbackReason,
        fallbackAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      notifId: result.notifId,
      messageId: result.messageId,
      status: fallbackReason ? 'fallback_text' : 'sent',
      failureReason: fallbackReason,
    };
  },
);
