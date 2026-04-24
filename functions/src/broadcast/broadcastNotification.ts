import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';

import { assertSuperAdmin } from '../lib/auth';
import { requireString, requireEnum, optionalString } from '../lib/validate';
import { sendBroadcast, BroadcastTargetKind } from './sendBroadcast';

// P4: text-only broadcast. P5 extends this same callable to accept
// type='image' with imageUrl + HEAD validation + text fallback.

const TARGETS = [
  'all_users',
  'affected_location',
  'selected_users',
  'role_based',
] as const;

const TYPES = ['text'] as const; // P5 adds 'image'

export const broadcastNotification = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    const type = requireEnum(data.type, 'type', TYPES);
    const title = requireString(data.title, 'title', { max: 65 });
    const body = requireString(data.body, 'body', { max: 240 });
    const deepLink = optionalString(data.deepLink, 'deepLink', { max: 500 });

    const targetObj = (data.target ?? {}) as { kind?: unknown };
    const targetKind = requireEnum(
      targetObj.kind,
      'target.kind',
      TARGETS,
    ) as BroadcastTargetKind;
    if (targetKind !== 'all_users') {
      // P4 ships only all_users; form hides other kinds until their phase.
      throw new HttpsError(
        'unimplemented',
        `target.kind='${targetKind}' is not available yet.`,
      );
    }

    const result = await sendBroadcast({
      type,
      title,
      body,
      imageUrl: null,
      target: { kind: targetKind },
      deepLink,
      triggerSource: 'manual',
      createdBy: me.uid,
    });

    return { notifId: result.notifId, messageId: result.messageId };
  },
);
