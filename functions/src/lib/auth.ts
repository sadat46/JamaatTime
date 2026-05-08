import { HttpsError, CallableRequest } from 'firebase-functions/v2/https';

import { db } from './firebase';

// Authorization helpers for callable functions.
//
// Role source = users/{uid}.role (single authoritative source after P0.5).
// Never consult a hardcoded email list — the Firestore write rule and this
// guard must agree, or a caller can pass one and fail the other.

export interface AuthedUid {
  uid: string;
  email: string | null;
}

export function requireAuth(request: CallableRequest<unknown>): AuthedUid {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign-in required.');
  }
  return {
    uid: auth.uid,
    email: (auth.token.email as string | undefined) ?? null,
  };
}

export async function assertSuperAdmin(
  request: CallableRequest<unknown>,
): Promise<AuthedUid> {
  const me = requireAuth(request);
  const snap = await db.collection('users').doc(me.uid).get();
  const role = snap.exists ? (snap.data()?.role as string | undefined) : undefined;
  if (role !== 'superadmin') {
    throw new HttpsError('permission-denied', 'Superadmin only.');
  }
  return me;
}

export async function assertAdminOrAbove(
  request: CallableRequest<unknown>,
): Promise<AuthedUid> {
  const me = requireAuth(request);
  const snap = await db.collection('users').doc(me.uid).get();
  const role = snap.exists ? (snap.data()?.role as string | undefined) : undefined;
  if (role !== 'admin' && role !== 'superadmin') {
    throw new HttpsError('permission-denied', 'Admin-level access required.');
  }
  return me;
}
