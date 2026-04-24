import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';
import { requireString, requireEnum } from '../lib/validate';
import { log } from '../lib/logger';

const ROLES = ['user', 'admin', 'superadmin'] as const;

// Superadmin-only role management. Every successful call appends an entry
// to role_audit/ so role changes are traceable.
export const setUserRole = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const actor = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const targetUid = requireString(data.targetUid, 'targetUid', { max: 128 });
    const role = requireEnum(data.role, 'role', ROLES);

    const userRef = db.collection('users').doc(targetUid);

    try {
      await db.runTransaction(async (tx) => {
        tx.set(
          userRef,
          {
            role,
            roleUpdatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        tx.set(db.collection('role_audit').doc(), {
          action: 'set_role',
          targetUid,
          role,
          actorUid: actor.uid,
          at: FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      log.error('set_role_failed', {
        actor: actor.uid,
        targetUid,
        role,
        err: (err as Error).message,
      });
      throw new HttpsError('internal', 'Role update failed.');
    }

    log.info('set_role_ok', { actor: actor.uid, targetUid, role });
    return { ok: true, targetUid, role };
  },
);
