/// Per-type notification opt-outs (KPB-169) — the app-side mirror of
/// `backend/src/common/notification-types.ts`.
///
/// Each recurring, non-transactional notification family is one stable key.
/// The same strings are the dispatch `kind` server-side, so a key read in the
/// feed, in analytics and in the preference screen always means the same thing.
///
/// Transactional notifications (deadlines, dossier updates, messages) are NOT
/// listed here on purpose: they are not opt-out-able, and an opt-out of one
/// family never silences another.
abstract final class NotificationOptOutType {
  /// KPB-162 — "Bourse du jour", 19h local.
  static const dailyScholarship = 'daily_scholarship';

  /// KPB-163 — Monday 08h local recap (push + email).
  static const weeklyDigest = 'weekly_digest';

  /// KPB-169 — Sunday 18h local "récit de la semaine".
  static const parcoursWeekly = 'parcours_weekly';

  /// Chantier C/G — « une bourse que tu suis est ouverte » (`scholarship_opened`
  /// et son push groupé). Une clé de FAMILLE, pas un `kind`. Coupe le push
  /// seulement : l'entrée reste dans le centre de notifications, et les rappels
  /// de date limite (transactionnels) continuent. Un backend antérieur au
  /// chantier C ne la connaît pas et la retire à l'écriture : la ligne des
  /// préférences ne s'affiche donc que si le serveur sert les routes du suivi.
  static const followedScholarshipUpdates = 'followed_scholarship_updates';

  /// Communauté (C1 + C2) — réponses à tes publications, aux discussions que
  /// tu suis, réponses vérifiées (`community_reply`,
  /// `community_followed_reply`, `community_verified_answer`). Coupe le push
  /// seulement : la ligne reste dans le centre de notifications. Les
  /// notifications de modération (`community_moderation`) concernent le
  /// compte et ne se coupent pas. La ligne des préférences ne s'affiche que
  /// drapeau `community` ouvert.
  static const community = 'community';

  /// Every key this build understands. An unknown key coming back from a newer
  /// server is preserved as-is (see [applyOptOut]) rather than dropped, so an
  /// older app never silently re-enables a family it cannot render a row for.
  static const all = [
    dailyScholarship,
    weeklyDigest,
    parcoursWeekly,
    followedScholarshipUpdates,
    community,
  ];
}

/// Returns [current] with [type] added or removed. Unknown keys are carried
/// through untouched — this build must not clear a preference it doesn't know.
List<String> applyOptOut(
  List<String> current,
  String type, {
  required bool optOut,
}) {
  final next = current.toSet();
  if (optOut) {
    next.add(type);
  } else {
    next.remove(type);
  }
  final sorted = next.toList()..sort();
  return List.unmodifiable(sorted);
}
