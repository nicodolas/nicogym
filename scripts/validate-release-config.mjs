import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const baseVersionPattern = /^\d+\.\d+\.\d+\+[1-9]\d*$/;

export function assertProductionApiUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('API_BASE_URL must be a valid absolute URL.');
  }
  if (url.protocol !== 'https:') {
    throw new Error('API_BASE_URL must use HTTPS.');
  }
  if (['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
    throw new Error('API_BASE_URL must not target a local host.');
  }
  return url.origin;
}

export function assertBaseVersion(value) {
  if (!baseVersionPattern.test(value)) {
    throw new Error('BASE_APP_VERSION must use MAJOR.MINOR.PATCH+BUILD.');
  }
  return value;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const apiUrl = assertProductionApiUrl(process.env.API_BASE_URL ?? '');
  const baseVersion = assertBaseVersion(process.env.BASE_APP_VERSION ?? '');
  process.stdout.write(`Release configuration valid for ${apiUrl} (${baseVersion}).\n`);
}
