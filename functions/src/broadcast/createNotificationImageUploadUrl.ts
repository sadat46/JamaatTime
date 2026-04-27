import { randomUUID } from 'crypto';

import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { HttpsError, CallableRequest, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { assertSuperAdmin } from '../lib/auth';
import { log } from '../lib/logger';

const MAX_IMAGE_BYTES = 1_000_000;
const SIGNED_URL_TTL_SECONDS = 15 * 60;

const R2_ACCOUNT_ID = defineSecret('R2_ACCOUNT_ID');
const R2_ACCESS_KEY_ID = defineSecret('R2_ACCESS_KEY_ID');
const R2_SECRET_ACCESS_KEY = defineSecret('R2_SECRET_ACCESS_KEY');
const R2_BUCKET = defineSecret('R2_BUCKET');
const R2_PUBLIC_BASE_URL = defineSecret('R2_PUBLIC_BASE_URL');

const ALLOWED_CONTENT_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

function requireUploadContentType(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'contentType must be a string.');
  }
  const contentType = value.trim().toLowerCase();
  if (!ALLOWED_CONTENT_TYPES[contentType]) {
    throw new HttpsError(
      'invalid-argument',
      'contentType must be image/jpeg, image/png, or image/webp.',
    );
  }
  return contentType;
}

function requireUploadSize(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new HttpsError('invalid-argument', 'sizeBytes must be an integer.');
  }
  if (value <= 0) {
    throw new HttpsError('invalid-argument', 'sizeBytes must be positive.');
  }
  if (value > MAX_IMAGE_BYTES) {
    throw new HttpsError(
      'invalid-argument',
      `Image must be ${MAX_IMAGE_BYTES} bytes or smaller.`,
    );
  }
  return value;
}

function secretValue(secret: ReturnType<typeof defineSecret>, name: string): string {
  const value = secret.value().trim();
  if (!value) {
    throw new HttpsError('failed-precondition', `${name} is not configured.`);
  }
  return value;
}

function encodeObjectUrl(baseUrl: string, key: string): string {
  const normalizedBase = baseUrl.replace(/\/+$/, '');
  const encodedKey = key.split('/').map(encodeURIComponent).join('/');
  return `${normalizedBase}/${encodedKey}`;
}

export const createNotificationImageUploadUrl = onCall(
  {
    region: 'us-central1',
    secrets: [
      R2_ACCOUNT_ID,
      R2_ACCESS_KEY_ID,
      R2_SECRET_ACCESS_KEY,
      R2_BUCKET,
      R2_PUBLIC_BASE_URL,
    ],
  },
  async (request: CallableRequest<unknown>) => {
    const me = await assertSuperAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const contentType = requireUploadContentType(data.contentType);
    const sizeBytes = requireUploadSize(data.sizeBytes);

    const accountId = secretValue(R2_ACCOUNT_ID, 'R2_ACCOUNT_ID');
    const accessKeyId = secretValue(R2_ACCESS_KEY_ID, 'R2_ACCESS_KEY_ID');
    const secretAccessKey = secretValue(R2_SECRET_ACCESS_KEY, 'R2_SECRET_ACCESS_KEY');
    const bucket = secretValue(R2_BUCKET, 'R2_BUCKET');
    const publicBaseUrl = secretValue(R2_PUBLIC_BASE_URL, 'R2_PUBLIC_BASE_URL');

    const ext = ALLOWED_CONTENT_TYPES[contentType];
    const key = `notification_images/${me.uid}/${Date.now()}-${randomUUID()}.${ext}`;
    const s3 = new S3Client({
      region: 'auto',
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: { accessKeyId, secretAccessKey },
    });

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: contentType,
      CacheControl: 'public, max-age=31536000, immutable',
    });
    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: SIGNED_URL_TTL_SECONDS,
    });
    const publicUrl = encodeObjectUrl(publicBaseUrl, key);

    log.info('notification_image_upload_url_created', {
      uid: me.uid,
      key,
      contentType,
      sizeBytes,
    });

    return {
      uploadUrl,
      publicUrl,
      key,
      expiresInSeconds: SIGNED_URL_TTL_SECONDS,
      maxSizeBytes: MAX_IMAGE_BYTES,
    };
  },
);
