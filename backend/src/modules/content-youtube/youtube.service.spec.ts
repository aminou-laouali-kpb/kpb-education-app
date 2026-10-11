import { YoutubeService } from './youtube.service';

describe('YoutubeService — playlist allowlist', () => {
  const env = { ...process.env };
  afterEach(() => {
    process.env = { ...env };
    jest.restoreAllMocks();
  });

  function fetchSpy() {
    return jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ items: [] }),
    } as unknown as Response);
  }

  it('ignores an unknown playlistId and serves the KPB playlist', async () => {
    process.env.YOUTUBE_API_KEY = 'k';
    process.env.YOUTUBE_PLAYLIST_ID = 'PL_KPB';
    const spy = fetchSpy();
    await new YoutubeService().getPlaylist('PL_ATTACKER');
    const url = new URL(String(spy.mock.calls[0][0]));
    expect(url.searchParams.get('playlistId')).toBe('PL_KPB');
  });

  it('serves an explicitly allowed extra playlist', async () => {
    process.env.YOUTUBE_API_KEY = 'k';
    process.env.YOUTUBE_ALLOWED_PLAYLIST_IDS = 'PL_A, PL_B';
    const spy = fetchSpy();
    await new YoutubeService().getPlaylist('PL_B');
    const url = new URL(String(spy.mock.calls[0][0]));
    expect(url.searchParams.get('playlistId')).toBe('PL_B');
    expect(spy.mock.calls[0][1]).toMatchObject({ signal: expect.anything() });
  });
});
