import { onCall, CallableRequest } from 'firebase-functions/v2/https';

import { assertSuperAdmin } from './lib/auth';

// Smoke-test callable. Used during Phase 3 deploy verification:
// superadmin → 200 { ok: true, uid }; non-superadmin → 403.
export const ping = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    return { ok: true, uid: me.uid };
  },
);
