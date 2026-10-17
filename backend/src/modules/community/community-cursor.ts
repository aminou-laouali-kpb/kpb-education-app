import { BadRequestException } from '@nestjs/common';

/**
 * Curseurs opaques (§4.1 du contrat) : JSON en base64url, porteurs du fil qui
 * les a émis. Le client les renvoie tels quels ; un curseur d'un autre fil, ou
 * illisible, répond 400 `community_invalid_cursor`.
 */
export interface CursorPayload {
  /** Le fil émetteur (`recent`, `for_you`, `space:scholarship:x`, …). */
  f: string;
  [key: string]: string | number | boolean | null;
}

export function invalidCursor(): BadRequestException {
  return new BadRequestException({
    message: 'Invalid cursor.',
    code: 'community_invalid_cursor',
  });
}

export function encodeCursor(payload: CursorPayload): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

export function decodeCursor(
  raw: string | undefined | null,
  feed: string,
): CursorPayload | null {
  if (raw === undefined || raw === null || raw === '') return null;
  if (raw.length > 600 || !/^[A-Za-z0-9_-]+$/.test(raw)) throw invalidCursor();
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
  } catch {
    throw invalidCursor();
  }
  if (
    !parsed ||
    typeof parsed !== 'object' ||
    Array.isArray(parsed) ||
    (parsed as CursorPayload).f !== feed
  ) {
    throw invalidCursor();
  }
  return parsed as CursorPayload;
}

/** Lit un champ date (ISO) d'un curseur, ou 400. */
export function cursorDate(payload: CursorPayload, key: string): Date {
  const value = payload[key];
  if (typeof value !== 'string') throw invalidCursor();
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw invalidCursor();
  return date;
}

export function cursorString(payload: CursorPayload, key: string): string {
  const value = payload[key];
  if (typeof value !== 'string' || value.length === 0 || value.length > 200) {
    throw invalidCursor();
  }
  return value;
}

export function cursorNumber(payload: CursorPayload, key: string): number {
  const value = payload[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) throw invalidCursor();
  return value;
}
