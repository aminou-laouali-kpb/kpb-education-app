// La compétition des ambassadeurs vue par l'élève (`GET /referrals/campaigns/current`).
//
// Le compte à rebours suit l'horloge du SERVEUR, pas celle du téléphone : un
// téléphone réglé à la main (fréquent) afficherait sinon « commencée » ou
// « terminée » à tort. On mesure l'écart `serverTime − heure de réception` une
// fois, puis on l'ajoute à l'heure locale à chaque tic.

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../utils/external_link.dart';

/// Phase d'une campagne, telle que le serveur la calcule (`campaignPhase`).
enum ReferralCampaignPhase { upcoming, running, ended }

/// Le rythme du compte à rebours (affiché à la minute).
const referralCountdownTick = Duration(seconds: 30);

/// Jours, heures, minutes d'une durée positive (arrondie à la minute
/// supérieure : « 0 min » n'apparaît jamais avant la fin).
@immutable
class CountdownParts {
  const CountdownParts(this.days, this.hours, this.minutes);

  factory CountdownParts.of(Duration remaining) {
    final totalMinutes =
        remaining.isNegative ? 0 : (remaining.inSeconds + 59) ~/ 60;
    return CountdownParts(
      totalMinutes ~/ (24 * 60),
      (totalMinutes ~/ 60) % 24,
      totalMinutes % 60,
    );
  }

  final int days;
  final int hours;
  final int minutes;
}

/// La réponse de `GET /referrals/campaigns/current`, lue sans rien deviner.
@immutable
class ReferralCampaignStanding {
  const ReferralCampaignStanding({
    required this.participating,
    this.slug = '',
    this.nameFr = '',
    this.nameEn = '',
    this.status = '',
    this.serverPhase = ReferralCampaignPhase.upcoming,
    this.startsAt,
    this.endsAt,
    this.provisional = true,
    this.publicName = '',
    this.city = '',
    this.code = '',
    this.rank,
    this.qualified = 0,
    this.toReview = 0,
    this.pending = 0,
    this.ineligible = 0,
    this.rankable = false,
    this.clockOffset = Duration.zero,
    this.rulesUrl,
    this.otherCompetitionPhase,
  });

  static const notParticipating =
      ReferralCampaignStanding(participating: false);

  final bool participating;
  final String slug;
  final String nameFr;
  final String nameEn;
  final String status;
  final ReferralCampaignPhase serverPhase;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Vrai tant que la campagne n'est pas close : le classement peut bouger.
  final bool provisional;

  final String publicName;
  final String city;
  final String code;

  /// Null tant que l'élève n'a aucun filleul qualifié.
  final int? rank;
  final int qualified;
  final int toReview;
  final int pending;

  /// Filleuls dont le compte existait avant la compétition : ils ne compteront
  /// jamais (statut serveur `ineligible`, build 59+ ; 0 sur un serveur ancien).
  final int ineligible;

  /// Faux : l'élève n'apparaît pas encore dans le classement public (âge,
  /// autorisation parentale, statut — décision de l'équipe).
  final bool rankable;

  /// `serverTime − heure de réception`.
  final Duration clockOffset;

  /// Le règlement servi avec la campagne (`campaign.rulesUrl`, https), ou
  /// `null` (serveur ancien, lien absent).
  final String? rulesUrl;

  /// Pour un NON-participant : la phase de la dernière compétition publique
  /// (`competition.phase`, build 59+), ou `null` (aucune, ou trop ancienne).
  final ReferralCampaignPhase? otherCompetitionPhase;

  /// La compétition est terminée : un code saisi maintenant ne compte plus
  /// pour elle (écran Parrainage, onboarding).
  bool competitionEndedAt(DateTime deviceNow) => participating
      ? phaseAt(deviceNow) == ReferralCampaignPhase.ended
      : otherCompetitionPhase == ReferralCampaignPhase.ended;

  /// Lit la charge. [receivedAt] : l'heure locale de réception (tests).
  ///
  /// Une charge sans `participating: true` ou sans campagne lisible vaut
  /// « ne participe pas » — jamais une campagne inventée.
  factory ReferralCampaignStanding.fromJson(
    Object? raw, {
    DateTime? receivedAt,
  }) {
    if (raw is! Map) return notParticipating;
    if (raw['participating'] != true) {
      final competition = raw['competition'];
      final phase = competition is Map ? _phase(competition['phase']) : null;
      return phase == null
          ? notParticipating
          : ReferralCampaignStanding(
              participating: false,
              otherCompetitionPhase: phase,
            );
    }
    final campaign = raw['campaign'];
    final me = raw['me'];
    if (campaign is! Map || me is! Map) return notParticipating;
    final slug = _string(campaign['slug']);
    if (slug.isEmpty) return notParticipating;
    final serverTime = _date(raw['serverTime']);
    final now = receivedAt ?? DateTime.now();
    return ReferralCampaignStanding(
      participating: true,
      slug: slug,
      nameFr: _string(campaign['nameFr']),
      nameEn: _string(campaign['nameEn']),
      status: _string(campaign['status']),
      serverPhase: _phase(campaign['phase']) ?? ReferralCampaignPhase.upcoming,
      startsAt: _date(campaign['startsAt']),
      endsAt: _date(campaign['endsAt']),
      provisional: campaign['provisional'] != false,
      publicName: _string(me['publicName']),
      city: _string(me['city']),
      code: _string(me['code']),
      rank: _positiveInt(me['rank']),
      qualified: _count(me['qualified']),
      toReview: _count(me['toReview']),
      pending: _count(me['pending']),
      ineligible: _count(me['ineligible']),
      rulesUrl: _httpsUrl(campaign['rulesUrl']),
      rankable: me['rankable'] == true,
      clockOffset:
          serverTime == null ? Duration.zero : serverTime.difference(now),
    );
  }

  /// Le nom dans la langue de l'élève (repli sur l'autre langue).
  String name(String languageCode) {
    final en = languageCode == 'en';
    final preferred = en ? nameEn : nameFr;
    return preferred.isNotEmpty ? preferred : (en ? nameFr : nameEn);
  }

  /// L'heure du serveur, vue depuis [deviceNow].
  DateTime serverNow(DateTime deviceNow) => deviceNow.add(clockOffset);

  /// La phase À CET INSTANT : celle du serveur, avancée par l'horloge (une
  /// campagne « à venir » commence à `startsAt` sans attendre un rechargement).
  /// Une campagne close est terminée quoi qu'en dise l'horloge.
  ReferralCampaignPhase phaseAt(DateTime deviceNow) {
    if (status == 'closed') return ReferralCampaignPhase.ended;
    final now = serverNow(deviceNow);
    var phase = serverPhase;
    final start = startsAt;
    final end = endsAt;
    if (phase == ReferralCampaignPhase.upcoming &&
        start != null &&
        !now.isBefore(start)) {
      phase = ReferralCampaignPhase.running;
    }
    if (phase == ReferralCampaignPhase.running &&
        end != null &&
        !now.isBefore(end)) {
      phase = ReferralCampaignPhase.ended;
    }
    return phase;
  }

  /// Le temps restant avant le début (à venir) ou la fin (en cours) ; `null`
  /// une fois terminée ou si la borne est inconnue.
  Duration? remainingAt(DateTime deviceNow) {
    final now = serverNow(deviceNow);
    return switch (phaseAt(deviceNow)) {
      ReferralCampaignPhase.upcoming => startsAt?.difference(now),
      ReferralCampaignPhase.running => endsAt?.difference(now),
      ReferralCampaignPhase.ended => null,
    };
  }

  /// Le lien « Lire le règlement », TOUJOURS disponible : celui servi avec la
  /// campagne, sinon celui du classement public ([fromLeaderboard]), sinon la
  /// page publique du classement de cette campagne (qui affiche le règlement).
  String rulesLink({String? fromLeaderboard}) =>
      rulesUrl ?? fromLeaderboard ?? publicLeaderboardUrl;

  /// La page publique du classement de CETTE campagne.
  String get publicLeaderboardUrl =>
      'https://${AppConfig.brandDomain}/classement/'
      '?c=${Uri.encodeQueryComponent(slug)}';

  static String _string(Object? value) => value is String ? value.trim() : '';

  static ReferralCampaignPhase? _phase(Object? value) => switch (value) {
        'upcoming' => ReferralCampaignPhase.upcoming,
        'running' => ReferralCampaignPhase.running,
        'ended' => ReferralCampaignPhase.ended,
        _ => null,
      };

  static String? _httpsUrl(Object? value) {
    if (value is! String) return null;
    final url = value.trim();
    if (!isOpenableWebUrl(url)) return null;
    return Uri.parse(url).scheme.toLowerCase() == 'https' ? url : null;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static int _count(Object? value) =>
      value is num && value >= 0 ? value.toInt() : 0;

  static int? _positiveInt(Object? value) =>
      value is num && value >= 1 ? value.toInt() : null;
}

/// Le lien du règlement servi par `GET /public/campaigns/:slug/leaderboard`
/// (`campaign.rulesUrl`) : https seulement, sinon `null` (le bouton se replie
/// alors sur la page publique du classement, voir [ReferralCampaignStanding.rulesLink]).
String? referralRulesUrlFrom(Object? publicLeaderboard) {
  if (publicLeaderboard is! Map) return null;
  final campaign = publicLeaderboard['campaign'];
  if (campaign is! Map) return null;
  return ReferralCampaignStanding._httpsUrl(campaign['rulesUrl']);
}
