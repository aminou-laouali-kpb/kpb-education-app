// ─────────────────────────────────────────────────────────────────────────────
// Per-type notification opt-outs (KPB-169).
//
// Each recurring, non-transactional notification family is one stable key,
// stored in `UserProfile.disabledNotificationTypes`. The keys are deliberately
// the same strings as the dispatch `kind` — one vocabulary for the feed, the
// analytics and the preference screen.
//
// One exception, on purpose: `followed_scholarship_updates` is a FAMILY key,
// not a kind. It covers the `scholarship_opened` feed rows (and their bundled
// push, `scholarship_opened_bundle`) — the announcement that a scholarship the
// student follows is open. It silences the PUSH only: the inbox row is still
// written (as `skipped / opt_out`), so the student finds it in the app.
//
// This replaces the per-type boolean columns (`dailyScholarshipOptOut`,
// `weeklyDigestOptOut`): a third type was the point at which one column per
// preference stopped scaling. Adding a fourth family is now a one-line change
// here plus a label in the app — no migration.
//
// Opting out of one family NEVER silences another, and never silences
// transactional notifications (deadlines, dossier updates, messages) — deadline
// reminders for a followed scholarship keep coming after
// `followed_scholarship_updates` is turned off.
//
// Builds 53/56 have no switch for the newest keys but keep unknown keys when
// they write the list back (`notification_opt_out.dart` `applyOptOut`), so a key
// set by a newer build survives a round trip through an older one.
// ─────────────────────────────────────────────────────────────────────────────

export const NOTIFICATION_OPT_OUT_TYPES = [
  'daily_scholarship', // KPB-162 — "Bourse du jour", 19h local.
  'weekly_digest', // KPB-163 — Monday 08h local recap (push + email).
  'parcours_weekly', // KPB-169 — Sunday 18h local "récit de la semaine".
  'followed_scholarship_updates', // Chantier C — "a scholarship you follow is open" (kind `scholarship_opened`).
  // Communauté C1 + C2 — FAMILY key like the one above: silences the PUSH of
  // `community_reply`, `community_followed_reply` and `community_verified_answer`
  // (the inbox row is still written). Moderation notices (`community_moderation`)
  // are never silenced.
  'community',
] as const;

export type NotificationOptOutType = (typeof NOTIFICATION_OPT_OUT_TYPES)[number];

/** Keeps unknown/legacy strings out of the column. Order is not significant, so
 *  the result is sorted and deduped to make stored values comparable. */
export function sanitizeOptOutTypes(raw: unknown): NotificationOptOutType[] {
  if (!Array.isArray(raw)) return [];
  const allowed = new Set<string>(NOTIFICATION_OPT_OUT_TYPES);
  return [...new Set(raw.filter((v): v is string => typeof v === 'string'))]
    .filter((v): v is NotificationOptOutType => allowed.has(v))
    .sort();
}

/** Applies a single `{ type, optOut }` change to an existing list. */
export function withOptOut(
  current: readonly string[],
  type: NotificationOptOutType,
  optOut: boolean,
): NotificationOptOutType[] {
  const next = new Set(sanitizeOptOutTypes([...current]));
  if (optOut) next.add(type);
  else next.delete(type);
  return [...next].sort();
}
