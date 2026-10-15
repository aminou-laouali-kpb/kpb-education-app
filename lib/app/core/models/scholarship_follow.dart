part of 'app_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// « Suivre » une bourse (chantier G, contrat backend du chantier C —
// docs/api-contracts.md, « Annonce d'ouverture des bourses suivies »).
//
// Suivre = favori + alerte d'ouverture + rappels de date limite. Le serveur
// reste la source de vérité ; ces modèles ne font que lire ses réponses, et
// chaque champ est OPTIONNEL côté lecture : la build doit marcher face à un
// backend qui ne connaît pas encore ces routes (réponse 404, bloc absent).
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _followDate(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? DateTime.tryParse(raw) : null;

/// Bloc additif `follow` de `GET /scholarships/:id` (chantier C). Absent d'un
/// backend plus ancien : la fiche le lit alors comme `null` et masque ce qui en
/// dépend (l'interrupteur « Me prévenir à l'ouverture »).
@immutable
class ScholarshipFollowState {
  const ScholarshipFollowState({
    required this.following,
    required this.viaFavorite,
    required this.viaAlert,
    required this.notifyOpening,
    required this.globalOptOut,
  });

  final bool following;
  final bool viaFavorite;
  final bool viaAlert;

  /// Faux quand l'annonce est en sourdine : la bourse reste suivie (rappels,
  /// liste), seul le push d'ouverture est coupé.
  final bool notifyOpening;

  /// L'élève a coupé « Bourses que je suis : ouverture » dans ses préférences.
  final bool globalOptOut;

  static ScholarshipFollowState? tryParse(Object? raw) {
    if (raw is! Map) return null;
    bool flag(String key) => raw[key] == true;
    if (raw['following'] is! bool) return null;
    return ScholarshipFollowState(
      following: flag('following'),
      viaFavorite: flag('viaFavorite'),
      viaAlert: flag('viaAlert'),
      notifyOpening: flag('notifyOpening'),
      globalOptOut: flag('globalOptOut'),
    );
  }

  ScholarshipFollowState copyWith({bool? notifyOpening, bool? following}) =>
      ScholarshipFollowState(
        following: following ?? this.following,
        viaFavorite: viaFavorite,
        viaAlert: viaAlert,
        notifyOpening: notifyOpening ?? this.notifyOpening,
        globalOptOut: globalOptOut,
      );
}

/// `displayStatus` de `GET /me/followed-scholarships`.
enum FollowedDisplayStatus { open, openingConfirmed, forecast, closed }

FollowedDisplayStatus _parseFollowedStatus(Object? raw) => switch (raw) {
      'open' => FollowedDisplayStatus.open,
      'opening_confirmed' => FollowedDisplayStatus.openingConfirmed,
      'closed' => FollowedDisplayStatus.closed,
      _ => FollowedDisplayStatus.forecast,
    };

String _followedStatusWire(FollowedDisplayStatus status) => switch (status) {
      FollowedDisplayStatus.open => 'open',
      FollowedDisplayStatus.openingConfirmed => 'opening_confirmed',
      FollowedDisplayStatus.forecast => 'forecast',
      FollowedDisplayStatus.closed => 'closed',
    };

/// Une ligne de `GET /me/followed-scholarships`.
@immutable
class FollowedScholarship {
  const FollowedScholarship({
    required this.id,
    required this.title,
    required this.countryId,
    required this.countryName,
    required this.displayStatus,
    this.academicYear,
    this.opensAt,
    this.closesAt,
    this.estimatedOpenAt,
    this.estimatedCloseAt,
    this.deadlineAt,
    this.dateConfidence,
    this.viaFavorite = false,
    this.viaAlert = false,
    this.notifyOpening = true,
    this.detailAvailable = true,
  });

  final String id;
  final String title;
  final String countryId;
  final String countryName;
  final FollowedDisplayStatus displayStatus;
  final String? academicYear;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? estimatedOpenAt;
  final DateTime? estimatedCloseAt;
  final DateTime? deadlineAt;
  final String? dateConfidence;
  final bool viaFavorite;
  final bool viaAlert;
  final bool notifyOpening;

  /// Faux quand la fiche répondrait 404 (retirée, non vérifiée) : la ligne
  /// reste listée — l'élève la suit — mais ne s'ouvre pas sur une erreur.
  final bool detailAvailable;

  /// La date de clôture qu'on peut AFFIRMER (confirmée), sinon null.
  DateTime? get confirmedCloseAt {
    if (closesAt != null) return closesAt;
    if (dateConfidence == 'estimated') return null;
    return deadlineAt;
  }

  /// La ligne de statut honnête de cette bourse (voir
  /// [resolveScholarshipStatusLine]).
  ScholarshipStatusLine statusLine({DateTime? now}) =>
      resolveScholarshipStatusLine(
        status: switch (displayStatus) {
          FollowedDisplayStatus.open => 'open',
          FollowedDisplayStatus.openingConfirmed => 'opening_confirmed',
          FollowedDisplayStatus.forecast => 'forecast',
          FollowedDisplayStatus.closed => 'closed',
        },
        dateConfidence: dateConfidence,
        opensAt: opensAt,
        closesAt: closesAt,
        estimatedOpenAt: estimatedOpenAt,
        deadlineAt: deadlineAt,
        now: now,
      );

  static FollowedScholarship? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    String text(String key) {
      final value = raw[key];
      return value is String ? value : '';
    }

    return FollowedScholarship(
      id: id.trim(),
      title: text('title'),
      countryId: text('countryId'),
      countryName: text('countryName'),
      displayStatus: _parseFollowedStatus(raw['displayStatus']),
      academicYear:
          raw['academicYear'] is String ? raw['academicYear'] as String : null,
      opensAt: _followDate(raw['opensAt']),
      closesAt: _followDate(raw['closesAt']),
      estimatedOpenAt: _followDate(raw['estimatedOpenAt']),
      estimatedCloseAt: _followDate(raw['estimatedCloseAt']),
      deadlineAt: _followDate(raw['deadlineAt']),
      dateConfidence: raw['dateConfidence'] is String
          ? raw['dateConfidence'] as String
          : null,
      viaFavorite: raw['viaFavorite'] == true,
      viaAlert: raw['viaAlert'] == true,
      notifyOpening: raw['notifyOpening'] != false,
      detailAvailable: raw['detailAvailable'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'countryId': countryId,
        'countryName': countryName,
        'displayStatus': _followedStatusWire(displayStatus),
        'academicYear': academicYear,
        'opensAt': opensAt?.toIso8601String(),
        'closesAt': closesAt?.toIso8601String(),
        'estimatedOpenAt': estimatedOpenAt?.toIso8601String(),
        'estimatedCloseAt': estimatedCloseAt?.toIso8601String(),
        'deadlineAt': deadlineAt?.toIso8601String(),
        'dateConfidence': dateConfidence,
        'viaFavorite': viaFavorite,
        'viaAlert': viaAlert,
        'notifyOpening': notifyOpening,
        'detailAvailable': detailAvailable,
      };
}

/// Réponse de `GET /me/followed-scholarships` : `{items, total, globalOptOut}`.
@immutable
class FollowedScholarshipsPage {
  const FollowedScholarshipsPage({
    required this.items,
    required this.total,
    required this.globalOptOut,
    this.fetchedAt,
  });

  final List<FollowedScholarship> items;
  final int total;
  final bool globalOptOut;

  /// Quand cette page a été reçue du serveur (null : jamais). Sert à dire
  /// « données du … » quand on la relit hors ligne.
  final DateTime? fetchedAt;

  static const empty =
      FollowedScholarshipsPage(items: [], total: 0, globalOptOut: false);

  factory FollowedScholarshipsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .map(FollowedScholarship.tryParse)
            .whereType<FollowedScholarship>()
            .toList()
        : <FollowedScholarship>[];
    final total = json['total'];
    return FollowedScholarshipsPage(
      items: List.unmodifiable(items),
      total: total is num ? total.toInt() : items.length,
      globalOptOut: json['globalOptOut'] == true,
      fetchedAt: _followDate(json['fetchedAt']),
    );
  }

  FollowedScholarshipsPage withFetchedAt(DateTime at) =>
      FollowedScholarshipsPage(
        items: items,
        total: total,
        globalOptOut: globalOptOut,
        fetchedAt: at,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'globalOptOut': globalOptOut,
        'fetchedAt': fetchedAt?.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne de statut d'une bourse — UNE règle pour la fiche et « Mes suivis »
// ─────────────────────────────────────────────────────────────────────────────

/// Ce que la ligne de statut peut affirmer.
enum ScholarshipStatusKind {
  /// Ouverte maintenant ; [ScholarshipStatusLine.date] = clôture confirmée
  /// (null : date à confirmer).
  open,

  /// Ouverture confirmée à venir ; [ScholarshipStatusLine.date] = ouverture.
  opensOn,

  /// Ouverture estimée ; [ScholarshipStatusLine.date] = ouverture estimée
  /// (null : période inconnue).
  openingEstimated,

  /// Clôturée.
  closed,
}

@immutable
class ScholarshipStatusLine {
  const ScholarshipStatusLine(this.kind, [this.date]);

  final ScholarshipStatusKind kind;
  final DateTime? date;

  @override
  bool operator ==(Object other) =>
      other is ScholarshipStatusLine &&
      other.kind == kind &&
      other.date == date;

  @override
  int get hashCode => Object.hash(kind, date);

  @override
  String toString() => 'ScholarshipStatusLine($kind, $date)';
}

/// Le statut d'une bourse tel qu'on peut le DIRE à l'élève.
///
/// Règle d'honnêteté : jamais « Ouverte » avant `opensAt`. Un cycle saisi
/// `open` dont la date d'ouverture confirmée est encore à venir se lit
/// « Ouvre le … » — c'est exactement ce que le push d'ouverture annoncera, et la
/// fiche ne doit pas le contredire. Une clôture passée l'emporte sur tout.
ScholarshipStatusLine resolveScholarshipStatusLine({
  required String? status,
  String? dateConfidence,
  DateTime? opensAt,
  DateTime? closesAt,
  DateTime? estimatedOpenAt,
  DateTime? deadlineAt,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final estimated = dateConfidence == 'estimated';
  final confirmedClose = closesAt ?? (estimated ? null : deadlineAt);
  if (status == 'closed' ||
      (confirmedClose != null && !ref.isBefore(confirmedClose))) {
    return const ScholarshipStatusLine(ScholarshipStatusKind.closed);
  }
  final opensInFuture = opensAt != null && opensAt.isAfter(ref);
  if (status == 'open') {
    if (opensInFuture) {
      return ScholarshipStatusLine(ScholarshipStatusKind.opensOn, opensAt);
    }
    return ScholarshipStatusLine(ScholarshipStatusKind.open, confirmedClose);
  }
  // `opening_confirmed` (liste des suivis) ou `forecast` à date confirmée.
  if (opensInFuture && (status == 'opening_confirmed' || !estimated)) {
    return ScholarshipStatusLine(ScholarshipStatusKind.opensOn, opensAt);
  }
  return ScholarshipStatusLine(
    ScholarshipStatusKind.openingEstimated,
    estimatedOpenAt ?? (opensInFuture ? opensAt : null),
  );
}
