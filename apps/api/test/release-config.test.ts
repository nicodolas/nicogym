import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

import {
  assertBaseVersion,
  assertProductionApiUrl,
} from '../../../scripts/validate-release-config.mjs';

const repositoryRoot = fileURLToPath(new URL('../../..', import.meta.url));

describe('release configuration', () => {
  it.each(['', 'http://localhost:3000', 'http://api.example.com', 'not a url'])(
    'rejects unsafe production API URL %j',
    (value) => expect(() => assertProductionApiUrl(value)).toThrow(),
  );

  it('accepts the deployed HTTPS API URL', () => {
    expect(
      assertProductionApiUrl('https://nicogym-api-huit.vercel.app'),
    ).toBe('https://nicogym-api-huit.vercel.app');
  });

  it.each(['', 'v1.1.1+5', '1.1+5', '1.1.1', '1.1.1+0'])(
    'rejects invalid base version %j',
    (value) => expect(() => assertBaseVersion(value)).toThrow(),
  );

  it('accepts the exact semantic base version', () => {
    expect(assertBaseVersion('1.1.1+5')).toBe('1.1.1+5');
  });

  it('keeps production release and patch commands wired to Dart defines', async () => {
    const release = await readFile(
      `${repositoryRoot}/.github/workflows/ci-release.yml`,
      'utf8',
    );
    const patch = await readFile(
      `${repositoryRoot}/.github/workflows/ota-patch.yml`,
      'utf8',
    );

    expect(release).toContain('validate-release-config.mjs');
    expect(release).toContain('--dart-define=API_BASE_URL=');
    expect(release).toContain('--dart-define=BASE_APP_VERSION=');
    expect(patch).toContain('validate-release-config.mjs');
    expect(patch).toContain('--dart-define=API_BASE_URL=');
    expect(patch).toContain('--dart-define=BASE_APP_VERSION=');
  });

  it('builds web without a generated PWA service worker', async () => {
    const buildScript = await readFile(
      `${repositoryRoot}/scripts/netlify-build.sh`,
      'utf8',
    );
    const netlify = await readFile(`${repositoryRoot}/netlify.toml`, 'utf8');

    expect(buildScript).toContain('--pwa-strategy=none');
    expect(buildScript).toContain('BASE_APP_VERSION');
    expect(netlify).toContain('for = "/flutter_bootstrap.js"');
    expect(netlify).toContain('for = "/main.dart.js"');
  });
});

