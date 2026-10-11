// ─────────────────────────────────────────────────────────────────────────────
// YouTube playlist proxy (Chantier C).
//
// Fetches the KPB channel playlist via the YouTube Data API v3 server-side
// (the API key never reaches the mobile app) and returns a clean video list.
// Results are cached in-memory for `CACHE_TTL_MS` so we stay well under the
// free 10k-units/day quota — a playlist changes rarely.
//
// Degrades gracefully: if YOUTUBE_API_KEY is missing or the upstream call
// fails, we return `{ items: [], configured: false }` instead of throwing, so
// the app can show an informative empty state rather than an error.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';

/// Default KPB channel playlist (overridable per request or via env).
const DEFAULT_PLAYLIST_ID = 'PLpk-LrNodqDjKAEF8B1WwWuMsmK4s2-zD';
const CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6 hours
const MAX_RESULTS = 50;
const FETCH_TIMEOUT_MS = 10_000;

export interface YoutubeVideoDto {
  videoId: string;
  title: string;
  description: string;
  thumbnailUrl: string;
  publishedAt: string | null;
  position: number;
}

interface CacheEntry {
  fetchedAt: number;
  payload: { items: YoutubeVideoDto[]; configured: boolean };
}

@Injectable()
export class YoutubeService {
  private readonly logger = new Logger(YoutubeService.name);
  private readonly cache = new Map<string, CacheEntry>();

  private get apiKey(): string | undefined {
    const key = process.env.YOUTUBE_API_KEY;
    return key && key.trim() !== '' ? key.trim() : undefined;
  }

  private allowedPlaylistIds(fallback: string): Set<string> {
    const extra = (process.env.YOUTUBE_ALLOWED_PLAYLIST_IDS ?? '')
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean);
    return new Set([DEFAULT_PLAYLIST_ID, fallback, ...extra]);
  }

  async getPlaylist(
    playlistId?: string,
    nowMs = Date.now(),
  ): Promise<{ items: YoutubeVideoDto[]; configured: boolean; cached: boolean }> {
    const fallback = process.env.YOUTUBE_PLAYLIST_ID?.trim() || DEFAULT_PLAYLIST_ID;
    // Route publique : un `playlistId` arbitraire consommait le quota de la clé
    // serveur et remplissait le cache sans limite. Seules les playlists KPB
    // connues sont servies ; tout autre id retombe sur la playlist par défaut.
    const requested = playlistId?.trim();
    const id =
      requested && this.allowedPlaylistIds(fallback).has(requested)
        ? requested
        : fallback;

    const cached = this.cache.get(id);
    if (cached && nowMs - cached.fetchedAt < CACHE_TTL_MS) {
      return { ...cached.payload, cached: true };
    }

    if (!this.apiKey) {
      this.logger.warn(
        'YOUTUBE_API_KEY not configured — returning empty playlist.',
      );
      return { items: [], configured: false, cached: false };
    }

    try {
      const items = await this.fetchAllPages(id);
      const payload = { items, configured: true };
      this.cache.set(id, { fetchedAt: nowMs, payload });
      return { ...payload, cached: false };
    } catch (error) {
      this.logger.error(`Failed to fetch playlist ${id}: ${String(error)}`);
      // Serve a stale cache if we have one; otherwise an empty (but configured)
      // response so the client knows it's a transient fetch problem.
      if (cached) return { ...cached.payload, cached: true };
      return { items: [], configured: true, cached: false };
    }
  }

  /// Follows nextPageToken so playlists longer than 50 items are fully listed.
  private async fetchAllPages(playlistId: string): Promise<YoutubeVideoDto[]> {
    const out: YoutubeVideoDto[] = [];
    let pageToken: string | undefined;
    let guard = 0; // hard cap: 5 pages = 250 videos

    do {
      const url = new URL(
        'https://www.googleapis.com/youtube/v3/playlistItems',
      );
      url.searchParams.set('part', 'snippet,contentDetails,status');
      url.searchParams.set('maxResults', String(MAX_RESULTS));
      url.searchParams.set('playlistId', playlistId);
      url.searchParams.set('key', this.apiKey as string);
      if (pageToken) url.searchParams.set('pageToken', pageToken);

      const res = await fetch(url.toString(), {
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
      if (!res.ok) {
        throw new Error(`YouTube API HTTP ${res.status}`);
      }
      const json = (await res.json()) as YoutubeApiResponse;

      for (const item of json.items ?? []) {
        const videoId =
          item.contentDetails?.videoId ?? item.snippet?.resourceId?.videoId;
        if (!videoId) continue;
        // Skip private/deleted videos.
        const privacy = item.status?.privacyStatus;
        if (privacy === 'private') continue;
        const title = item.snippet?.title ?? '';
        if (title === 'Private video' || title === 'Deleted video') continue;

        out.push({
          videoId,
          title,
          description: item.snippet?.description ?? '',
          thumbnailUrl: this.bestThumbnail(item.snippet?.thumbnails),
          publishedAt: item.snippet?.publishedAt ?? null,
          position: item.snippet?.position ?? out.length,
        });
      }

      pageToken = json.nextPageToken;
      guard += 1;
    } while (pageToken && guard < 5);

    out.sort((a, b) => a.position - b.position);
    return out;
  }

  private bestThumbnail(thumbs?: YoutubeThumbnails): string {
    if (!thumbs) return '';
    return (
      thumbs.high?.url ??
      thumbs.medium?.url ??
      thumbs.standard?.url ??
      thumbs.default?.url ??
      ''
    );
  }
}

// ── Minimal shape of the YouTube Data API v3 playlistItems response ──────────
interface YoutubeThumbnail {
  url: string;
}
interface YoutubeThumbnails {
  default?: YoutubeThumbnail;
  medium?: YoutubeThumbnail;
  high?: YoutubeThumbnail;
  standard?: YoutubeThumbnail;
}
interface YoutubeApiItem {
  contentDetails?: { videoId?: string };
  status?: { privacyStatus?: string };
  snippet?: {
    title?: string;
    description?: string;
    publishedAt?: string;
    position?: number;
    resourceId?: { videoId?: string };
    thumbnails?: YoutubeThumbnails;
  };
}
interface YoutubeApiResponse {
  items?: YoutubeApiItem[];
  nextPageToken?: string;
}
