import { afterEach, describe, expect, it, vi } from 'vitest';

import { apiFetch } from './api-client';

describe('apiFetch', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('forwards additive request headers and the abort signal', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 204,
      text: vi.fn(),
    });
    vi.stubGlobal('fetch', fetchMock);
    const controller = new AbortController();

    await apiFetch('/admin/competition-readiness/pilots', {
      method: 'POST',
      body: { code: 'pilot-ne-2026' },
      headers: { 'Idempotency-Key': 'pilot-create-1' },
      signal: controller.signal,
    });

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:4000/api/admin/competition-readiness/pilots',
      {
        method: 'POST',
        cache: 'no-store',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': 'pilot-create-1',
        },
        signal: controller.signal,
        body: JSON.stringify({ code: 'pilot-ne-2026' }),
      },
    );
  });
});

describe('readableErrorText', () => {
  it('extracts a Nest message instead of showing raw JSON', async () => {
    const { readableErrorText } = await import('./api-client');
    expect(readableErrorText('{"message":"Case not found.","statusCode":404}', 404)).toBe(
      'Case not found.',
    );
    expect(
      readableErrorText('{"message":["name must be a string","x too long"]}', 400),
    ).toBe('name must be a string x too long');
    expect(readableErrorText('Bad Gateway', 502)).toBe('Bad Gateway');
    expect(readableErrorText('', 500)).toBe('Request failed with status 500');
  });
});
