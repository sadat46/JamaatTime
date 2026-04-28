import { log } from '../lib/logger';

export function logNoticeMetric(
  metric: string,
  fields: Record<string, unknown> = {},
): void {
  log.info('notice_metric', { metric, ...fields });
}

