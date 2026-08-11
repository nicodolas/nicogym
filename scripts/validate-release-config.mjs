import { resolve } from 'node:path';
import { isIP } from 'node:net';
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
  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (isNonPublicHostname(hostname)) throw new Error('API_BASE_URL must target a public host.');
  return url.origin;
}

function isNonPublicHostname(hostname) {
  if (
    hostname === 'localhost' ||
    hostname.endsWith('.localhost') ||
    hostname.endsWith('.internal') ||
    hostname.endsWith('.local')
  ) return true;

  const ipVersion = isIP(hostname);
  if (ipVersion === 4) {
    const [first, second, third] = hostname.split('.').map(Number);
    return (
      first === 0 ||
      first === 10 ||
      first === 127 ||
      (first === 100 && second >= 64 && second <= 127) ||
      (first === 169 && second === 254) ||
      (first === 172 && second >= 16 && second <= 31) ||
      (first === 192 && second === 0 && third === 0) ||
      (first === 192 && second === 0 && third === 2) ||
      (first === 192 && second === 88 && third === 99) ||
      (first === 192 && second === 168) ||
      (first === 198 && (second === 18 || second === 19)) ||
      (first === 198 && second === 51 && third === 100) ||
      (first === 203 && second === 0 && third === 113) ||
      first >= 224
    );
  }
  if (ipVersion === 6) {
    const normalized = hostname.toLowerCase();
    return (
      normalized === '::' ||
      normalized === '::1' ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      /^fe[89ab]/.test(normalized) ||
      normalized.startsWith('::ffff:')
    );
  }
  return false;
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
