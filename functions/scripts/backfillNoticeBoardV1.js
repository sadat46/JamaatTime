#!/usr/bin/env node

const crypto = require('crypto');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

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
];

const PUBLIC_STATUSES = new Set(['sent', 'fallback_text']);

function parseArgs(argv) {
  const args = {
    dryRun: true,
    verifyOnly: false,
    limit: null,
    since: null,
  };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--dry-run') args.dryRun = true;
    else if (arg === '--live') args.dryRun = false;
    else if (arg === '--verify-only') args.verifyOnly = true;
    else if (arg === '--limit') args.limit = Number(argv[++i]);
    else if (arg === '--since') args.since = argv[++i];
    else throw new Error(`Unknown arg: ${arg}`);
  }
  return args;
}

function stableJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (typeof value.toMillis === 'function') {
    return JSON.stringify(value.toMillis());
  }
  const keys = Object.keys(value).sort();
  return `{${keys.map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
}

function sha256(value) {
  return crypto.createHash('sha256').update(stableJson(value)).digest('hex');
}

function normalizeType(value) {
  if (value === 'auto_jamaat_change') return 'jamaat_time_change';
  if (value === 'text' || value === 'image' || !value) return 'announcement';
  return value;
}

function normalizeTriggerSource(value) {
  if (value === 'auto_jamaat_change') return 'auto_jamaat';
  return value || 'manual';
}

function rootUpdateFor(docId, data) {
  const status = data.status || 'failed';
  const publicVisible = PUBLIC_STATUSES.has(status);
  const update = {
    schemaVersion: 1,
    notifId: docId,
    type: normalizeType(data.type),
    category: data.category ?? null,
    title: data.title ?? '',
    body: data.body ?? '',
    imageUrl: data.imageUrl ?? null,
    imageWidth: data.imageWidth ?? null,
    imageHeight: data.imageHeight ?? null,
    imageBlurHash: data.imageBlurHash ?? null,
    imageFallback: status === 'fallback_text' || Boolean(data.imageFallback),
    deepLink: data.deepLink ?? null,
    locale: data.locale ?? 'en',
    localizedVariants: data.localizedVariants ?? null,
    status,
    publicVisible,
    priority: data.priority ?? 'normal',
    pinned: data.pinned ?? false,
    expiresAt: data.expiresAt ?? null,
    archivedAt: data.archivedAt ?? null,
    triggerSource: normalizeTriggerSource(data.triggerSource),
    audience: data.audience ?? 'guests_and_users',
    createdAt: data.createdAt ?? FieldValue.serverTimestamp(),
    scheduledFor: data.scheduledFor ?? null,
    sentAt: data.sentAt ?? null,
    publishedAt: publicVisible
      ? (data.publishedAt ?? data.sentAt ?? data.createdAt ?? FieldValue.serverTimestamp())
      : (data.publishedAt ?? null),
    updatedAt: FieldValue.serverTimestamp(),
  };
  for (const key of PRIVATE_KEYS) update[key] = FieldValue.delete();
  return update;
}

function adminMetaFor(data, preHash) {
  const meta = {
    createdBy: data.createdBy ?? 'unknown',
    createdByDisplayName: data.createdByDisplayName ?? null,
    target: data.target ?? { kind: 'all_users' },
    targetTokensCount: data.targetTokensCount ?? null,
    sendMode: data.sendMode ?? 'topic',
    failureReason: data.failureReason ?? null,
    failureCode: data.failureCode ?? null,
    fcmResponse: data.fcmResponse ?? null,
    fcmMessageId: data.fcmMessageId ?? null,
    dedupKey: data.dedupKey ?? null,
    idempotencyKey: data.idempotencyKey ?? null,
    retryCount: data.retryCount ?? 0,
    lastRetryAt: data.lastRetryAt ?? null,
    cancelledBy: data.cancelledBy ?? null,
    cancelledAt: data.cancelledAt ?? null,
    clientIp: data.clientIp ?? null,
    userAgent: data.userAgent ?? null,
    diagnostics: data.diagnostics ?? null,
    broadcastType: data.type === 'image' || data.imageUrl ? 'image' : 'text',
    legacyShape: true,
    migration: {
      name: 'notice_board_v1',
      preHash,
      migratedAt: FieldValue.serverTimestamp(),
    },
  };
  if (Array.isArray(data.editHistory)) meta.editHistory = data.editHistory;
  return meta;
}

async function verifyOnly(query) {
  const offenders = [];
  const snap = await query.get();
  for (const doc of snap.docs) {
    const data = doc.data();
    const privateAtRoot = PRIVATE_KEYS.filter((key) => data[key] !== undefined);
    if (privateAtRoot.length > 0 || data.schemaVersion !== 1) {
      offenders.push({ id: doc.id, privateAtRoot, schemaVersion: data.schemaVersion });
    }
  }
  console.log(JSON.stringify({ checked: snap.size, offenders }, null, 2));
  if (offenders.length > 0) process.exitCode = 1;
}

async function main() {
  const args = parseArgs(process.argv);
  let query = db.collection('notifications').orderBy('createdAt');
  if (args.since) {
    query = query.where('createdAt', '>=', Timestamp.fromDate(new Date(args.since)));
  }
  if (args.limit) query = query.limit(args.limit);

  if (args.verifyOnly) {
    await verifyOnly(query);
    return;
  }

  const runId = new Date().toISOString().replace(/[:.]/g, '-');
  const snap = await query.get();
  const report = {
    runId,
    dryRun: args.dryRun,
    scanned: snap.size,
    migrated: 0,
    skipped: 0,
    errors: [],
    offendingDocIds: [],
    startedAt: new Date().toISOString(),
  };

  let batch = db.batch();
  let writes = 0;
  async function flush() {
    if (writes === 0 || args.dryRun) return;
    await batch.commit();
    batch = db.batch();
    writes = 0;
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    try {
      if (data.schemaVersion === 1 && PRIVATE_KEYS.every((key) => data[key] === undefined)) {
        report.skipped++;
        continue;
      }
      const preHash = sha256(data);
      const rootUpdate = rootUpdateFor(doc.id, data);
      const meta = adminMetaFor(data, preHash);
      report.migrated++;
      if (!args.dryRun) {
        batch.set(doc.ref, rootUpdate, { merge: true });
        batch.set(doc.ref.collection('admin_meta').doc('meta'), meta, { merge: true });
        writes += 2;
        if (writes >= 398) await flush();
      }
    } catch (err) {
      report.errors.push({ id: doc.id, message: err.message });
      report.offendingDocIds.push(doc.id);
    }
  }
  await flush();
  report.finishedAt = new Date().toISOString();

  if (!args.dryRun) {
    await db.collection('migrations').doc('notice_board_v1').collection('runs').doc(runId).set(report);
  }
  console.log(JSON.stringify(report, null, 2));
  if (report.errors.length > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
