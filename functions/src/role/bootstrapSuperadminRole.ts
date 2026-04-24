import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { requireAuth } from '../lib/auth';
import { log } from '../lib/logger';

// Single-use self-bootstrap: lets an allowlisted email promote themselves
// to superadmin on a fresh environment. The email is removed from the
// allowlist on success, so re-running from the same account is a no-op
// (throws permission-denied).
//
// The allowlist lives at system_config/bootstrap_superadmins and is
// writable only from the admin SDK (Firestore rules deny all client access).

export const bootstrapSuperadminRole = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = requireAuth(request);
    if (!me.email) {
      log.warn('bootstrap_denied_no_email', { uid: me.uid });
      throw new HttpsError('permission-denied', 'Email required.');
    }

    const allowlistRef = db.doc('system_config/bootstrap_superadmins');

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(allowlistRef);
        const emails: string[] = snap.exists
          ? ((snap.data()?.emails as string[] | undefined) ?? [])
          : [];
        const match = emails.find(
          (e) => e.toLowerCase() === me.email!.toLowerCase(),
        );
        if (!match) {
          log.warn('bootstrap_denied_not_allowlisted', {
            uid: me.uid,
            email: me.email,
          });
          throw new HttpsError(
            'permission-denied',
            'Not on bootstrap allowlist.',
          );
        }

        tx.set(
          db.collection('users').doc(me.uid),
          {
            role: 'superadmin',
            email: me.email,
            bootstrappedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        tx.update(allowlistRef, {
          emails: FieldValue.arrayRemove(match),
        });

        tx.set(db.collection('role_audit').doc(), {
          action: 'bootstrap',
          targetUid: me.uid,
          role: 'superadmin',
          actorUid: me.uid,
          email: me.email,
          at: FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      log.error('bootstrap_failed', {
        uid: me.uid,
        email: me.email,
        err: (err as Error).message,
      });
      throw new HttpsError('internal', 'Bootstrap failed.');
    }

    log.info('bootstrap_ok', { uid: me.uid, email: me.email });
    return { ok: true, uid: me.uid };
  },
);
