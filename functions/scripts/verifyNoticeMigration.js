#!/usr/bin/env node

const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const PRIVATE_KEYS = [
  'createdBy',
  'createdByDisplayName',
  'target',
  'targetTokensCount',
  'sendMode',
  'failureReason',
  'failureCode',
  'fcmResponse',
  'fcmMessageId',
  'dedupKey',
  'idempotencyKey',
  'retryCount',
  'lastRetryAt',
  'cancelledBy',
  'cancelledAt',
  'editHistory',
  'clientIp',
  'userAgent',
  'diagnostics',
  'broadcastType',
  'legacyShape',
  'migration',
];

const PUBLIC_STATUSES = new Set(['sent', 'fallback_text']);

function timestampMillis(value) {
  return value && typeof value.toMillis === 'function' ? value.toMillis() : null;
}

function verifyDoc(doc) {
  const data = doc.data();
  const errors = [];
  const privateAtRoot = PRIVATE_KEYS.filter((key) => data[key] !== undefined);
  if (privateAtRoot.length > 0) {
    errors.push(`private root keys: ${privateAtRoot.join(', ')}`);
  }
  if (data.schemaVersion !== 1) {
    errors.push(`schemaVersion=${data.schemaVersion}`);
  }
  if (!data.notifId || data.notifId !== doc.id) {
    errors.push('notifId missing or not equal to document id');
  }
  if (data.publicVisible === true) {
    if (!PUBLIC_STATUSES.has(data.status)) {
      errors.push(`visible status is not public: ${data.status}`);
    }
    const expiresMs = timestampMillis(data.expiresAt);
    if (expiresMs !== null && expiresMs <= Date.now()) {
      errors.push('visible notice is expired');
    }
  }
  return errors;
}

async function main() {
  const snap = await db.collection('notifications').get();
  const offenders = [];
  for (const doc of snap.docs) {
    const errors = verifyDoc(doc);
    if (errors.length > 0) offenders.push({ id: doc.id, errors });
  }
  const report = {
    checked: snap.size,
    offenders: offenders.length,
    offenderIds: offenders.map((item) => item.id),
    details: offenders,
  };
  console.log(JSON.stringify(report, null, 2));
  if (offenders.length > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

