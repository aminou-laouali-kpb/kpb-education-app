import type { Response } from "express";

import {
  ADMIN_ACCESS_COOKIE,
  ADMIN_REFRESH_COOKIE,
  clearAdminAuthCookies,
  readCookie,
  setAdminAuthCookies,
} from "./admin-cookies";

/**
 * Audit 41 : lecture des cookies de session admin et options d'écriture.
 * `readCookie` est utilisé par AdminAuthGuard (jeton d'accès) et par
 * AuthController (refresh / logout).
 */
describe("admin-cookies", () => {
  describe("readCookie", () => {
    it("renvoie undefined sans en-tête Cookie", () => {
      expect(readCookie(undefined, ADMIN_ACCESS_COOKIE)).toBeUndefined();
      expect(readCookie("", ADMIN_ACCESS_COOKIE)).toBeUndefined();
    });

    it("lit la valeur du cookie demandé parmi plusieurs, espaces retirés", () => {
      const header = `a=1; ${ADMIN_ACCESS_COOKIE}= jwt.abc ;${ADMIN_REFRESH_COOKIE}=r1`;
      expect(readCookie(header, ADMIN_ACCESS_COOKIE)).toBe("jwt.abc");
      expect(readCookie(header, ADMIN_REFRESH_COOKIE)).toBe("r1");
    });

    it("compare le nom exact (pas un préfixe ni un suffixe)", () => {
      const header = `${ADMIN_ACCESS_COOKIE}_old=x; my${ADMIN_ACCESS_COOKIE}=y`;
      expect(readCookie(header, ADMIN_ACCESS_COOKIE)).toBeUndefined();
    });

    it("garde les « = » de la valeur (padding base64)", () => {
      expect(readCookie("t=abc==", "t")).toBe("abc==");
    });

    it("décode une valeur encodée en URI", () => {
      expect(readCookie("t=a%20b%2Fc", "t")).toBe("a b/c");
    });

    it("ignore les segments sans « = »", () => {
      expect(readCookie("garbage; t=ok", "t")).toBe("ok");
    });

    it("renvoie le premier cookie quand le nom est dupliqué", () => {
      expect(readCookie("t=first; t=second", "t")).toBe("first");
    });

    // Une valeur mal encodée ne doit pas faire lever une URIError (le garde
    // répondrait 500) : elle est traitée comme un cookie absent (401).
    it("renvoie undefined pour une valeur mal encodée (%E0%A4%A)", () => {
      expect(
        readCookie(`${ADMIN_ACCESS_COOKIE}=%E0%A4%A`, ADMIN_ACCESS_COOKIE),
      ).toBeUndefined();
    });
  });

  describe("setAdminAuthCookies / clearAdminAuthCookies", () => {
    const originalEnv = process.env.NODE_ENV;
    afterEach(() => {
      process.env.NODE_ENV = originalEnv;
    });

    function fakeResponse() {
      const cookie = jest.fn();
      const clearCookie = jest.fn();
      return {
        res: { cookie, clearCookie } as unknown as Response,
        cookie,
        clearCookie,
      };
    }

    it("pose les deux cookies httpOnly, SameSite=Lax, avec leurs chemins et durées", () => {
      process.env.NODE_ENV = "test";
      const { res, cookie } = fakeResponse();
      setAdminAuthCookies(res, { token: "acc", refreshToken: "ref" });

      expect(cookie).toHaveBeenCalledTimes(2);
      expect(cookie).toHaveBeenCalledWith(ADMIN_ACCESS_COOKIE, "acc", {
        httpOnly: true,
        secure: false,
        sameSite: "lax",
        path: "/",
        maxAge: 60 * 60 * 1000,
      });
      // Le chemin du refresh doit inclure le préfixe global `api` (main.ts),
      // sinon le navigateur n'envoie jamais le cookie à /api/auth/admin/refresh.
      expect(cookie).toHaveBeenCalledWith(ADMIN_REFRESH_COOKIE, "ref", {
        httpOnly: true,
        secure: false,
        sameSite: "lax",
        path: "/api/auth/admin",
        maxAge: 7 * 24 * 60 * 60 * 1000,
      });
    });

    it("marque les cookies Secure en production", () => {
      process.env.NODE_ENV = "production";
      const { res, cookie } = fakeResponse();
      setAdminAuthCookies(res, { token: "acc", refreshToken: "ref" });
      for (const call of cookie.mock.calls) {
        expect(call[2]).toMatchObject({ secure: true, httpOnly: true });
      }
    });

    it("efface chaque cookie sur le chemin où il a été posé", () => {
      const { res, clearCookie } = fakeResponse();
      clearAdminAuthCookies(res);
      expect(clearCookie).toHaveBeenCalledWith(ADMIN_ACCESS_COOKIE, {
        path: "/",
      });
      expect(clearCookie).toHaveBeenCalledWith(ADMIN_REFRESH_COOKIE, {
        path: "/api/auth/admin",
      });
    });
  });
});
