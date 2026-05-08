// HEAD-fetches an image URL and decides whether FCM will accept it.
// FCM Android image limits: HTTPS, 2xx response, content-type image/*,
// content-length ≤ 1 MB (above this the image is silently dropped on many OEMs).

const MAX_BYTES = 1_000_000; // 1 MB

export interface ImageValidationOk {
  ok: true;
  contentType: string;
  contentLength: number | null;
}

export interface ImageValidationFail {
  ok: false;
  // Suffix matches the `image_invalid_<reason>` contract logged to notifications.failureReason.
  reason:
    | 'not_https'
    | 'bad_url'
    | 'http_error'
    | 'not_image'
    | 'too_large'
    | 'network_error';
  detail?: string;
}

export type ImageValidationResult = ImageValidationOk | ImageValidationFail;

export async function validateImageUrl(
  url: string,
): Promise<ImageValidationResult> {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { ok: false, reason: 'bad_url' };
  }
  if (parsed.protocol !== 'https:') {
    return { ok: false, reason: 'not_https' };
  }

  let resp: Response;
  try {
    resp = await fetch(url, { method: 'HEAD' });
  } catch (err) {
    return {
      ok: false,
      reason: 'network_error',
      detail: (err as Error).message,
    };
  }

  if (!resp.ok) {
    return {
      ok: false,
      reason: 'http_error',
      detail: String(resp.status),
    };
  }

  const contentType = resp.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().startsWith('image/')) {
    return { ok: false, reason: 'not_image', detail: contentType };
  }

  const lenHeader = resp.headers.get('content-length');
  const contentLength = lenHeader ? Number(lenHeader) : null;
  if (contentLength !== null && contentLength > MAX_BYTES) {
    return { ok: false, reason: 'too_large', detail: String(contentLength) };
  }

  return { ok: true, contentType, contentLength };
}
