import { onCall, CallableRequest } from 'firebase-functions/v2/https';
import { Query } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';
import { assertSuperAdmin } from '../lib/auth';

async function count(query: Query): Promise<number> {
  const snap = await query.count().get();
  return snap.data().count;
}

// Read-only diagnostics for the admin history screen. The app cannot read
// device_tokens or other users' user_tokens directly under Firestore rules.
export const getNotificationDiagnostics = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest<unknown>) => {
    await assertSuperAdmin(request);

    const [
      deviceTokenDocs,
      androidDeviceTokenDocs,
      allUsersDeviceTopicDocs,
      userTokenDocs,
      allUsersUserTopicDocs,
      legacyUsersWithFcmToken,
    ] = await Promise.all([
      count(db.collection('device_tokens')),
      count(db.collection('device_tokens').where('platform', '==', 'android')),
      count(
        db
          .collection('device_tokens')
          .where('topics', 'array-contains', 'all_users'),
      ),
      count(db.collection('user_tokens')),
      count(
        db
          .collection('user_tokens')
          .where('topics', 'array-contains', 'all_users'),
      ),
      count(db.collection('users').where('fcm_token', '>', '')),
    ]);

    return {
      generatedAt: Date.now(),
      sendMode: 'topic',
      topic: 'all_users',
      deliveryReceiptTracked: false,
      perTokenErrorsTracked: false,
      activeAndroidUsersTracked: false,
      counts: {
        deviceTokenDocs,
        androidDeviceTokenDocs,
        allUsersDeviceTopicDocs,
        userTokenDocs,
        allUsersUserTopicDocs,
        legacyUsersWithFcmToken,
      },
      fcmErrorBreakdown: {
        invalidToken: null,
        unregistered: null,
        mismatchSenderId: null,
        permissionDenied: null,
        reason: 'Unavailable while broadcasts use FCM topic sends.',
      },
    };
  },
);
