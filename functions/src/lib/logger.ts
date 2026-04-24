import { logger } from 'firebase-functions';

// Thin wrapper so every log line is structured and searchable in Cloud Logging.
export const log = {
  info: (event: string, fields: Record<string, unknown> = {}) =>
    logger.info(event, { event, ...fields }),
  warn: (event: string, fields: Record<string, unknown> = {}) =>
    logger.warn(event, { event, ...fields }),
  error: (event: string, fields: Record<string, unknown> = {}) =>
    logger.error(event, { event, ...fields }),
};
