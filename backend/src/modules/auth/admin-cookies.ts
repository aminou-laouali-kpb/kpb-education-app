import type { Response } from "express";

/**
 * Admin session cookies. The access + refresh JWTs live in httpOnly cookies so
 * they are never readable from JavaScript (defends against XSS token theft),
 * replacing the previous localStorage storage in the admin console.
 */
export const ADMIN_ACCESS_COOKIE = "kpb_admin_token";
export const ADMIN_REFRESH_COOKIE = "kpb_admin_refresh";

// Scope the refresh cookie to the admin auth routes so it is only sent where it
// is actually used, while the short-lived access cookie is sent to all API routes.
const REFRESH_COOKIE_PATH = "/api/auth/admin";

const ACCESS_MAX_AGE_MS = 60 * 60 * 1000; // 1h — matches the access token TTL
const REFRESH_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7d — matches the refresh TTL

function baseOptions() {
  return {
    httpOnly: true,
    // Secure only in production: dev serves the admin over http://localhost.
    secure: process.env.NODE_ENV === "production",
    // Lax is enough: admin + API are same-site (*.kpbeducation.cloud), so the
    // cookie is sent on the admin's XHR while cross-site requests are blocked.
    sameSite: "lax" as const,
  };
}

export function setAdminAuthCookies(
  res: Response,
  tokens: { token: string; refreshToken: string },
): void {
  res.cookie(ADMIN_ACCESS_COOKIE, tokens.token, {
    ...baseOptions(),
    path: "/",
    maxAge: ACCESS_MAX_AGE_MS,
  });
  res.cookie(ADMIN_REFRESH_COOKIE, tokens.refreshToken, {
    ...baseOptions(),
    path: REFRESH_COOKIE_PATH,
    maxAge: REFRESH_MAX_AGE_MS,
  });
}

export function clearAdminAuthCookies(res: Response): void {
  res.clearCookie(ADMIN_ACCESS_COOKIE, { path: "/" });
  res.clearCookie(ADMIN_REFRESH_COOKIE, { path: REFRESH_COOKIE_PATH });
}

/** Minimal cookie reader (avoids adding cookie-parser just to read one value). */
export function readCookie(
  cookieHeader: string | undefined,
  name: string,
): string | undefined {
  if (!cookieHeader) return undefined;
  for (const part of cookieHeader.split(";")) {
    const idx = part.indexOf("=");
    if (idx === -1) continue;
    if (part.slice(0, idx).trim() === name) {
      // Une valeur mal encodée (ex. « %E0%A4%A ») ferait lever une URIError :
      // le garde répondrait 500. On la traite comme un cookie absent (401).
      try {
        return decodeURIComponent(part.slice(idx + 1).trim());
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}
