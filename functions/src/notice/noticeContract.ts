import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../lib/firebase';

export const NOTICE_SCHEMA_VERSION = 1;

export const NOTICE_TYPES = [
  'info',
  'prayer_time_change',
  'jamaat_time_change',
  'event',
  'urgent',
  'announcement',
  'other',
] as const;

export const NOTICE_STATUSES = [
  'draft',
  'queued',
  'sending',
  'sent',
  'fallback_text',
  'failed',
  'cancelled',
  'expired',
] as const;

export const NOTICE_PRIORITIES = ['normal', 'high', 'critical'] as const;
export const NOTICE_AUDIENCES = ['all_users', 'guests_and_users'] as const;
export const NOTICE_TRIGGER_SOURCES = [
  'manual',
  'auto_prayer',
  'auto_jamaat',
  'system',
] as const;

export const PUBLIC_VISIBLE_STATUSES = ['sent', 'fallback_text'] as const;

export const PUBLIC_NOTICE_KEYS = [
  'schemaVersion',
  'notifId',
  'type',
  'category',
  'title',
  'body',
  'imageUrl',
  'imageWidth',
  'imageHeight',
  'imageBlurHash',
  'imageFallback',
  'deepLink',
  'locale',
  'localizedVariants',
  'status',
  'publicVisible',
  'priority',
  'pinned',
  'expiresAt',
  'archivedAt',
  'triggerSource',
  'audience',
  'createdAt',
  'scheduledFor',
  'sentAt',
  'publishedAt',
  'updatedAt',
] as const;

export const PRIVATE_NOTICE_KEYS = [
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
] as const;

export type NoticeType = (typeof NOTICE_TYPES)[number];
export type NoticeStatus = (typeof NOTICE_STATUSES)[number];
export type NoticePriority = (typeof NOTICE_PRIORITIES)[number];
export type NoticeAudience = (typeof NOTICE_AUDIENCES)[number];
export type NoticeTriggerSource = (typeof NOTICE_TRIGGER_SOURCES)[number];

export interface PublicNoticePayload {
  schemaVersion: typeof NOTICE_SCHEMA_VERSION;
  notifId: string;
  type: NoticeType;
  category: string | null;
  title: string;
  body: string;
  imageUrl: string | null;
  imageWidth: number | null;
  imageHeight: number | null;
  imageBlurHash: string | null;
  imageFallback: boolean;
  deepLink: string | null;
  locale: string;
  localizedVariants: Record<string, { title: string; body: string }> | null;
  status: NoticeStatus;
  publicVisible: boolean;
  priority: NoticePriority;
  pinned: boolean;
  expiresAt: Timestamp | null;
  archivedAt: Timestamp | null;
  triggerSource: NoticeTriggerSource;
  audience: NoticeAudience;
  createdAt: FirebaseFirestore.FieldValue | Timestamp;
  scheduledFor: Timestamp | null;
  sentAt: Timestamp | FirebaseFirestore.FieldValue | null;
  publishedAt: Timestamp | FirebaseFirestore.FieldValue | null;
  updatedAt: FirebaseFirestore.FieldValue | Timestamp;
}

export interface AdminNoticeMeta {
  createdBy: string;
  createdByDisplayName?: string | null;
  target: { kind: string; value?: unknown };
  targetTokensCount?: number | null;
  sendMode: 'topic';
  failureReason?: string | null;
  failureCode?: string | null;
  fcmResponse?: Record<string, unknown> | null;
  fcmMessageId?: string | null;
  dedupKey?: string | null;
  idempotencyKey: string;
  retryCount?: number;
  lastRetryAt?: Timestamp | null;
  cancelledBy?: string | null;
  cancelledAt?: Timestamp | FirebaseFirestore.FieldValue | null;
  editHistory?: unknown[];
  clientIp?: string | null;
  userAgent?: string | null;
  diagnostics?: Record<string, unknown> | null;
  broadcastType?: 'text' | 'image';
  legacyShape?: boolean;
}

export interface NoticeValidationInput {
  notifId: string;
  title: string;
  body: string;
  imageUrl?: string | null;
  deepLink?: string | null;
  category?: string | null;
  type?: NoticeType | 'text' | 'image' | 'auto_jamaat_change' | null;
  priority?: NoticePriority | null;
  triggerSource?: NoticeTriggerSource | 'auto_jamaat_change' | null;
  audience?: NoticeAudience | null;
  locale?: string | null;
  scheduledFor?: Timestamp | null;
  expiresAt?: Timestamp | null;
  pinned?: boolean | null;
  imageFallback?: boolean | null;
}

export interface BroadcastDraft {
  notifId: string;
  type: 'text' | 'image';
  title: string;
  body: string;
  imageUrl: string | null;
  target: { kind: string; value?: unknown };
  deepLink: string | null;
  triggerSource: NoticeTriggerSource;
  createdBy: string;
  scheduledFor: Timestamp | null;
  expiresAt: Timestamp | null;
  failureReason: string | null;
  idempotencyKey: string | null;
  legacyShape: boolean;
}

const CONTROL_CHARS = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g;
const ZERO_WIDTH_ABUSE = /[\u200b-\u200f\ufeff]/g;
const ALLOWED_DEEP_LINK_PREFIXES = [
  '/home',
  '/settings',
  '/admin/jamaat',
  '/calendar',
  '/profile',
  '/ebadat',
  '/notice-board',
  '/notice',
];

function hasValue<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined;
}

function stableIdempotencyKey(notifId: string): string {
  return `notice:${notifId}`;
}

function normalizePublicType(value: NoticeValidationInput['type']): NoticeType {
  if (value === 'auto_jamaat_change') return 'jamaat_time_change';
  if (value === 'text' || value === 'image' || !value) return 'announcement';
  if ((NOTICE_TYPES as readonly string[]).includes(value)) return value as NoticeType;
  throw new HttpsError(
    'invalid-argument',
    `type must be one of: ${NOTICE_TYPES.join(', ')}.`,
  );
}

function normalizeTriggerSource(
  value: NoticeValidationInput['triggerSource'],
): NoticeTriggerSource {
  if (value === 'auto_jamaat_change') return 'auto_jamaat';
  if (!value) return 'manual';
  if ((NOTICE_TRIGGER_SOURCES as readonly string[]).includes(value)) {
    return value as NoticeTriggerSource;
  }
  throw new HttpsError(
    'invalid-argument',
    `triggerSource must be one of: ${NOTICE_TRIGGER_SOURCES.join(', ')}.`,
  );
}

function requireEnumValue<T extends string>(
  value: string | null | undefined,
  allowed: readonly T[],
  field: string,
  fallback: T,
): T {
  if (!value) return fallback;
  if ((allowed as readonly string[]).includes(value)) return value as T;
  throw new HttpsError(
    'invalid-argument',
    `${field} must be one of: ${allowed.join(', ')}.`,
  );
}

function sanitizeText(value: string, field: string, maxLength: number): string {
  const normalized = value
    .normalize('NFC')
    .replace(CONTROL_CHARS, '')
    .replace(ZERO_WIDTH_ABUSE, '')
    .trim();
  if (!normalized) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  if (normalized.length > maxLength) {
    throw new HttpsError(
      'invalid-argument',
      `${field} must be ${maxLength} characters or fewer.`,
    );
  }
  return normalized;
}

export function sanitizeBody(value: string): string {
  return sanitizeText(value, 'body', 2000);
}

export function assertDeepLinkAllowed(value: string | null | undefined): string | null {
  if (!value) return null;
  const deepLink = value.trim();
  if (!deepLink) return null;
  let uri: URL;
  try {
    uri = new URL(deepLink, 'app://jamaat-time');
  } catch {
    throw new HttpsError('invalid-argument', 'deepLink is not a valid route.');
  }
  if (uri.origin !== 'app://jamaat-time' || !uri.pathname.startsWith('/')) {
    throw new HttpsError('invalid-argument', 'deepLink must be an internal route.');
  }
  if (!ALLOWED_DEEP_LINK_PREFIXES.some((prefix) => uri.pathname === prefix || uri.pathname.startsWith(`${prefix}/`))) {
    throw new HttpsError('invalid-argument', 'deepLink route is not allowed.');
  }
  return `${uri.pathname}${uri.search}${uri.hash}`;
}

export function assertImageUrlAllowed(value: string | null | undefined): string | null {
  if (!value) return null;
  let uri: URL;
  try {
    uri = new URL(value.trim());
  } catch {
    throw new HttpsError('invalid-argument', 'imageUrl is not a valid URL.');
  }
  if (uri.protocol !== 'https:') {
    throw new HttpsError('invalid-argument', 'imageUrl must use HTTPS.');
  }

  const allowedHosts = (process.env.NOTICE_IMAGE_HOST_ALLOWLIST ?? '')
    .split(',')
    .map((host) => host.trim().toLowerCase())
    .filter(Boolean);
  if (allowedHosts.length > 0 && !allowedHosts.includes(uri.host.toLowerCase())) {
    throw new HttpsError('invalid-argument', 'imageUrl host is not allowed.');
  }
  if (value.length > 2000) {
    throw new HttpsError('invalid-argument', 'imageUrl must be 2000 characters or fewer.');
  }
  return uri.toString();
}

export function validatePublicPayload(input: NoticeValidationInput): PublicNoticePayload {
  const title = sanitizeText(input.title, 'title', 120);
  const body = sanitizeBody(input.body);
  const imageUrl = assertImageUrlAllowed(input.imageUrl);
  const deepLink = assertDeepLinkAllowed(input.deepLink);
  const priority = requireEnumValue(
    input.priority,
    NOTICE_PRIORITIES,
    'priority',
    'normal',
  );
  const audience = requireEnumValue(
    input.audience,
    NOTICE_AUDIENCES,
    'audience',
    'guests_and_users',
  );

  return {
    schemaVersion: NOTICE_SCHEMA_VERSION,
    notifId: input.notifId,
    type: normalizePublicType(input.type),
    category: input.category ? sanitizeText(input.category, 'category', 80) : null,
    title,
    body,
    imageUrl,
    imageWidth: null,
    imageHeight: null,
    imageBlurHash: null,
    imageFallback: input.imageFallback === true,
    deepLink,
    locale: input.locale?.trim() || 'en',
    localizedVariants: null,
    status: 'draft',
    publicVisible: false,
    priority,
    pinned: input.pinned === true,
    expiresAt: input.expiresAt ?? null,
    archivedAt: null,
    triggerSource: normalizeTriggerSource(input.triggerSource),
    audience,
    createdAt: FieldValue.serverTimestamp(),
    scheduledFor: input.scheduledFor ?? null,
    sentAt: null,
    publishedAt: null,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export function adminMetaRef(notifId: string) {
  return db.collection('notifications').doc(notifId).collection('admin_meta').doc('meta');
}

export function publicPayloadForStatus(
  payload: PublicNoticePayload,
  status: NoticeStatus,
): PublicNoticePayload {
  const publicVisible = isPubliclyVisible(status, payload.expiresAt);
  return {
    ...payload,
    status,
    publicVisible,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export function isPubliclyVisible(
  status: NoticeStatus,
  expiresAt: Timestamp | null | undefined,
): boolean {
  if (!(PUBLIC_VISIBLE_STATUSES as readonly string[]).includes(status)) {
    return false;
  }
  return !expiresAt || expiresAt.toMillis() > Date.now();
}

export async function writeNoticeDraft(params: {
  notifRef: FirebaseFirestore.DocumentReference;
  payload: PublicNoticePayload;
  adminMeta: AdminNoticeMeta;
  status?: Extract<NoticeStatus, 'draft' | 'queued' | 'sending'>;
}): Promise<void> {
  const status = params.status ?? 'draft';
  const batch = db.batch();
  batch.set(params.notifRef, publicPayloadForStatus(params.payload, status), {
    merge: true,
  });
  batch.set(params.notifRef.collection('admin_meta').doc('meta'), {
    ...params.adminMeta,
    idempotencyKey: params.adminMeta.idempotencyKey || stableIdempotencyKey(params.notifRef.id),
    editHistory: FieldValue.arrayUnion({
      actor: params.adminMeta.createdBy,
      action: `notice_${status}`,
      at: Timestamp.now(),
    }),
  }, { merge: true });
  await batch.commit();
}

export async function writeAdminMeta(
  notifId: string,
  meta: Partial<AdminNoticeMeta>,
): Promise<void> {
  await adminMetaRef(notifId).set(meta, { merge: true });
}

export async function publishNotice(params: {
  notifId: string;
  messageId: string;
  fcmResponse: Record<string, unknown>;
  actor: string;
  imageFallback?: boolean;
}): Promise<void> {
  const notifRef = db.collection('notifications').doc(params.notifId);
  const metaRef = notifRef.collection('admin_meta').doc('meta');
  await db.runTransaction(async (tx) => {
    tx.update(notifRef, {
      status: params.imageFallback ? 'fallback_text' : 'sent',
      publicVisible: true,
      imageFallback: params.imageFallback === true,
      sentAt: FieldValue.serverTimestamp(),
      publishedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(metaRef, {
      fcmResponse: params.fcmResponse,
      fcmMessageId: params.messageId,
      editHistory: FieldValue.arrayUnion({
        actor: params.actor,
        action: params.imageFallback ? 'notice_publish_fallback_text' : 'notice_publish_sent',
        at: Timestamp.now(),
      }),
    }, { merge: true });
  });
}

export async function markNoticeFailed(params: {
  notifId: string;
  reason: string;
  actor: string;
  code?: string | null;
}): Promise<void> {
  const notifRef = db.collection('notifications').doc(params.notifId);
  const metaRef = notifRef.collection('admin_meta').doc('meta');
  await db.runTransaction(async (tx) => {
    tx.update(notifRef, {
      status: 'failed',
      publicVisible: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(metaRef, {
      failureReason: params.reason,
      failureCode: params.code ?? null,
      editHistory: FieldValue.arrayUnion({
        actor: params.actor,
        action: 'notice_failed',
        at: Timestamp.now(),
      }),
    }, { merge: true });
  });
}

export async function markNoticeCancelled(params: {
  notifId: string;
  actor: string;
}): Promise<void> {
  const notifRef = db.collection('notifications').doc(params.notifId);
  const metaRef = notifRef.collection('admin_meta').doc('meta');
  await db.runTransaction(async (tx) => {
    tx.update(notifRef, {
      status: 'cancelled',
      publicVisible: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(metaRef, {
      cancelledBy: params.actor,
      cancelledAt: FieldValue.serverTimestamp(),
      editHistory: FieldValue.arrayUnion({
        actor: params.actor,
        action: 'notice_cancelled',
        at: Timestamp.now(),
      }),
    }, { merge: true });
  });
}

export async function markNoticeExpired(params: {
  notifId: string;
  actor?: string;
}): Promise<void> {
  const notifRef = db.collection('notifications').doc(params.notifId);
  const metaRef = notifRef.collection('admin_meta').doc('meta');
  await db.runTransaction(async (tx) => {
    tx.update(notifRef, {
      status: 'expired',
      publicVisible: false,
      archivedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(metaRef, {
      editHistory: FieldValue.arrayUnion({
        actor: params.actor ?? 'system',
        action: 'notice_expired',
        at: Timestamp.now(),
      }),
    }, { merge: true });
  });
}

export async function loadBroadcastDraft(notifId: string): Promise<BroadcastDraft | null> {
  const notifRef = db.collection('notifications').doc(notifId);
  const [rootSnap, metaSnap] = await Promise.all([
    notifRef.get(),
    notifRef.collection('admin_meta').doc('meta').get(),
  ]);
  if (!rootSnap.exists) return null;

  const root = rootSnap.data() ?? {};
  const meta = metaSnap.data() ?? {};
  const legacyDualRead = process.env.LEGACY_NOTICE_DUAL_READ !== 'false';
  const legacyShape = !metaSnap.exists;
  if (legacyShape && !legacyDualRead) return null;

  const imageUrl = root.imageUrl as string | null | undefined;
  const broadcastType =
    (meta.broadcastType as 'text' | 'image' | undefined) ??
    ((hasValue(imageUrl) && imageUrl !== '') ? 'image' : 'text');
  const target =
    (meta.target as { kind: string; value?: unknown } | undefined) ??
    (legacyDualRead ? (root.target as { kind: string; value?: unknown } | undefined) : undefined);
  const createdBy =
    (meta.createdBy as string | undefined) ??
    (legacyDualRead ? (root.createdBy as string | undefined) : undefined);

  if (
    typeof root.title !== 'string' ||
    typeof root.body !== 'string' ||
    !target?.kind ||
    !createdBy
  ) {
    return null;
  }

  return {
    notifId,
    type: broadcastType,
    title: root.title,
    body: root.body,
    imageUrl: imageUrl ?? null,
    target,
    deepLink: (root.deepLink as string | null | undefined) ?? null,
    triggerSource: normalizeTriggerSource(
      root.triggerSource as NoticeValidationInput['triggerSource'],
    ),
    createdBy,
    scheduledFor: (root.scheduledFor as Timestamp | null | undefined) ?? null,
    expiresAt: (root.expiresAt as Timestamp | null | undefined) ?? null,
    failureReason:
      (meta.failureReason as string | null | undefined) ??
      (legacyDualRead ? ((root.failureReason as string | null | undefined) ?? null) : null),
    idempotencyKey: (meta.idempotencyKey as string | null | undefined) ?? null,
    legacyShape,
  };
}

export function onlyPublicNoticeKeys(data: Record<string, unknown>): boolean {
  const allowed = new Set<string>(PUBLIC_NOTICE_KEYS);
  return Object.keys(data).every((key) => allowed.has(key));
}

