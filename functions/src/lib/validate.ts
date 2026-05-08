import { HttpsError } from 'firebase-functions/v2/https';

// Manual validators for callable payloads. Kept dependency-free so the
// functions bundle stays small; upgrade to zod only if the surface area grows.

export function requireString(
  value: unknown,
  field: string,
  opts: { max?: number; min?: number } = {},
): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${field} must be a string.`);
  }
  const trimmed = value.trim();
  if (trimmed.length < (opts.min ?? 1)) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  if (opts.max && trimmed.length > opts.max) {
    throw new HttpsError(
      'invalid-argument',
      `${field} must be ${opts.max} characters or fewer.`,
    );
  }
  return trimmed;
}

export function requireEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  if (typeof value !== 'string' || !(allowed as readonly string[]).includes(value)) {
    throw new HttpsError(
      'invalid-argument',
      `${field} must be one of: ${allowed.join(', ')}.`,
    );
  }
  return value as T;
}

export function optionalString(
  value: unknown,
  field: string,
  opts: { max?: number } = {},
): string | null {
  if (value === undefined || value === null || value === '') return null;
  return requireString(value, field, { max: opts.max });
}
