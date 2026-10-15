// « Mes 10 bourses » (chantier H) — les formes servies par
// `/scholarships/match/*` (docs/api-contracts.md, section « Mes 10 bourses »).
//
// ## Tolérant par construction
//
// Le serveur possède les listes (clés de préparation, jetons, groupes
// d'exclusion) et peut en ajouter sans prévenir. Chaque lecture ici suit la
// même règle :
//
// - une clé inconnue est IGNORÉE (jamais une erreur) ;
// - une valeur inconnue retombe sur un repli SÛR — celui qui promet le moins :
//   un statut d'élément inconnu devient « à vérifier », jamais « compatible » ;
//   une confiance de date inconnue devient « estimée » (pas de compte à
//   rebours) ; une source qui n'est pas une adresse https n'est pas un lien ;
// - un élément illisible (sans identifiant) est abandonné, pas deviné ;
// - un élément `not_eligible` n'est JAMAIS rendu (le serveur n'en sert pas,
//   c'est la bretelle de cette ceinture).
//
// Les libellés (`label`) viennent du serveur, déjà traduits : l'app ne les
// compose jamais. Ils ne contiennent ni « % » ni « chance » ; seules les
// citations officielles (`official.text`) peuvent en contenir.

import 'package:flutter/foundation.dart';

import '../utils/external_link.dart';

// ── Lecture tolérante ───────────────────────────────────────────────────────

String? _str(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? value) {
  if (value is int) return value < 0 ? 0 : value;
  if (value is num && value.isFinite) {
    final rounded = value.round();
    return rounded < 0 ? 0 : rounded;
  }
  return 0;
}

bool _bool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

DateTime? _date(Object? value) {
  final raw = _str(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false)
    : const <Map<String, dynamic>>[];

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  final out = <String>[];
  for (final item in value) {
    final s = _str(item);
    if (s != null && !out.contains(s)) out.add(s);
  }
  return List.unmodifiable(out);
}

String? _token(Object? value, List<String> known) {
  final s = _str(value);
  return s != null && known.contains(s) ? s : null;
}

/// Une adresse https ouvrable, sinon `null` : une source officielle qui ne
/// s'ouvre pas n'est pas affichée comme un lien.
String? _httpsUrl(Object? value) {
  final s = _str(value);
  if (s == null || !isOpenableWebUrl(s)) return null;
  return Uri.parse(s).scheme.toLowerCase() == 'https' ? s : null;
}

String? _iso(DateTime? date) => date?.toUtc().toIso8601String();

// ── Jetons connus de CETTE build ────────────────────────────────────────────

/// Les jetons des réponses que cette build sait poser. Une valeur servie hors
/// de ces listes est lue `null` (« pas de réponse ») et la question est posée.
abstract final class MatchTokens {
  static const diplomas = <String>[
    'none',
    'bac',
    'bac_plus_2',
    'licence',
    'master',
    'doctorat',
  ];
  static const targetLevels = <String>[
    'secondary',
    'bachelor',
    'master',
    'doctorate',
  ];
  static const gradeBands = <String>[
    'lt10',
    '10_12',
    '12_14',
    '14_16',
    '16_plus',
  ];
  static const languageBands = <String>['none', 'a1_a2', 'b1', 'b2', 'c1_c2'];
  static const experienceBands = <String>[
    'none',
    'lt12',
    '12_24',
    '24_36',
    '36_60',
    '60_plus',
  ];

  /// Les tests de langue et leurs bornes (`LANGUAGE_TEST_SCALES` du serveur).
  static const languageTestScales = <String, (double, double)>{
    'ielts': (0, 9),
    'toefl_ibt': (0, 120),
    'duolingo': (10, 160),
    'tcf': (100, 699),
    'tef': (0, 699),
  };

  /// Les niveaux visés qui demandent l'expérience professionnelle.
  static const experienceTargets = <String>{'master', 'doctorate'};
}

/// Les clés de `readiness` que cette build sait poser. Le serveur peut en
/// servir d'autres : elles sont ignorées (jamais une étape inventée).
abstract final class MatchReadinessKey {
  static const nationalityCode = 'nationalityCode';
  static const residence = 'residence';
  static const birthDate = 'birthDate';
  static const guardianConsent = 'guardianConsent';
  static const highestDiploma = 'highestDiploma';
  static const scholarshipTargetLevel = 'scholarshipTargetLevel';
  static const fields = 'fields';
  static const gradeBandOn20 = 'gradeBandOn20';
  static const englishLevel = 'englishLevel';
  static const workExperienceBand = 'workExperienceBand';
  static const targetCountryIds = 'targetCountryIds';
  static const frenchLevel = 'frenchLevel';
  static const languageTests = 'languageTests';
  static const secondNationalityCode = 'secondNationalityCode';

  static const required = <String>[
    nationalityCode,
    residence,
    birthDate,
    guardianConsent,
    highestDiploma,
    scholarshipTargetLevel,
    fields,
    gradeBandOn20,
    englishLevel,
    workExperienceBand,
  ];

  static const optional = <String>[
    targetCountryIds,
    frenchLevel,
    languageTests,
    secondNationalityCode,
  ];

  static final Set<String> known = <String>{...required, ...optional};
}

// ── Préparation ─────────────────────────────────────────────────────────────

@immutable
class MatchReadiness {
  const MatchReadiness({
    this.ready = false,
    this.required = const <String>[],
    this.toConfirm = const <String>[],
    this.optional = const <String>[],
    this.targetLevelOptions = const <String>[],
  });

  /// Rien ne manque ET le récapitulatif a été validé.
  final bool ready;

  /// Clés obligatoires vides — connues de cette build seulement.
  final List<String> required;

  /// Valeurs utilisées mais pas encore confirmées (connues seulement).
  final List<String> toConfirm;

  /// Compléments facultatifs encore vides (connus seulement).
  final List<String> optional;

  /// Niveaux proposables à l'étape « Tu vises une bourse pour » (connus
  /// seulement). Vide quand le serveur n'en sert pas : l'app propose alors
  /// Licence / Master / Doctorat, jamais le lycée (il dépend de l'âge et du
  /// catalogue, que seul le serveur sait).
  final List<String> targetLevelOptions;

  factory MatchReadiness.fromJson(Object? raw) {
    final json = _map(raw);
    List<String> known(Object? value) => _strings(value)
        .where(MatchReadinessKey.known.contains)
        .toList(growable: false);
    return MatchReadiness(
      ready: _bool(json['ready']),
      required: known(json['required']),
      toConfirm: known(json['toConfirm']),
      optional: known(json['optional']),
      targetLevelOptions: _strings(json['targetLevelOptions'])
          .where(MatchTokens.targetLevels.contains)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ready': ready,
        'required': required,
        'toConfirm': toConfirm,
        'optional': optional,
        'targetLevelOptions': targetLevelOptions,
      };
}

/// Une suggestion tirée des anciens champs. `ambiguous` : la question DOIT être
/// posée (« 15+/20 » couvre deux tranches) ; sinon elle s'affiche au
/// récapitulatif, à confirmer.
@immutable
class MatchPrefill {
  const MatchPrefill({
    required this.key,
    required this.value,
    this.source,
    this.ambiguous = true,
  });

  final String key;
  final String value;
  final String? source;
  final bool ambiguous;

  static MatchPrefill? fromJson(Map<String, dynamic> json) {
    final key = _str(json['key']);
    final value = _str(json['value']);
    if (key == null || value == null) return null;
    if (!MatchReadinessKey.known.contains(key)) return null;
    return MatchPrefill(
      key: key,
      value: value,
      source: _str(json['source']),
      // Absent ou illisible : on pose la question (le repli qui promet le moins).
      ambiguous: _bool(json['ambiguous'], fallback: true),
    );
  }
}

/// Un score de test de langue (`languageTests`).
@immutable
class MatchLanguageTest {
  const MatchLanguageTest({
    required this.type,
    required this.score,
    this.takenAt,
  });

  final String type;
  final double score;
  final String? takenAt;

  static MatchLanguageTest? fromJson(Map<String, dynamic> json) {
    final type = _str(json['type']);
    final scale = MatchTokens.languageTestScales[type];
    final raw = json['score'];
    final score = raw is num
        ? raw.toDouble()
        : double.tryParse(_str(raw)?.replaceAll(',', '.') ?? '');
    if (type == null || scale == null || score == null || !score.isFinite) {
      return null;
    }
    if (score < scale.$1 || score > scale.$2) return null;
    final takenAt = _str(json['takenAt']);
    return MatchLanguageTest(
      type: type,
      score: score,
      takenAt:
          takenAt != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(takenAt)
              ? takenAt
              : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'score': score == score.roundToDouble() ? score.toInt() : score,
        if (takenAt != null) 'takenAt': takenAt,
      };

  @override
  bool operator ==(Object other) =>
      other is MatchLanguageTest &&
      other.type == type &&
      other.score == score &&
      other.takenAt == takenAt;

  @override
  int get hashCode => Object.hash(type, score, takenAt);
}

/// Les valeurs actuelles du profil (récapitulatif), jetons connus seulement.
@immutable
class MatchAnswers {
  const MatchAnswers({
    this.nationalityCode,
    this.secondNationalityCode,
    this.residence,
    this.birthDate,
    this.guardianConsented = false,
    this.highestDiploma,
    this.scholarshipTargetLevel,
    this.fieldIds = const <String>[],
    this.targetCountryIds = const <String>[],
    this.gradeBandOn20,
    this.englishLevel,
    this.frenchLevel,
    this.languageTests = const <MatchLanguageTest>[],
    this.workExperienceBand,
    this.confirmedAt,
  });

  static const empty = MatchAnswers();

  final String? nationalityCode;
  final String? secondNationalityCode;
  final String? residence;

  /// `AAAA-MM-JJ`, tel que servi (jamais reprojeté dans un fuseau).
  final String? birthDate;
  final bool guardianConsented;
  final String? highestDiploma;
  final String? scholarshipTargetLevel;
  final List<String> fieldIds;
  final List<String> targetCountryIds;
  final String? gradeBandOn20;
  final String? englishLevel;
  final String? frenchLevel;
  final List<MatchLanguageTest> languageTests;
  final String? workExperienceBand;
  final DateTime? confirmedAt;

  factory MatchAnswers.fromJson(Object? raw) {
    final json = _map(raw);
    String? country(Object? value) {
      final s = _str(value)?.toLowerCase();
      return s != null && RegExp(r'^[a-z]{3}$').hasMatch(s) ? s : null;
    }

    final birth = _str(json['birthDate']);
    return MatchAnswers(
      nationalityCode: country(json['nationalityCode']),
      secondNationalityCode: country(json['secondNationalityCode']),
      residence: country(json['residence']),
      birthDate: birth != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(birth)
          ? birth.substring(0, 10)
          : null,
      guardianConsented: _bool(json['guardianConsented']),
      highestDiploma: _token(json['highestDiploma'], MatchTokens.diplomas),
      scholarshipTargetLevel:
          _token(json['scholarshipTargetLevel'], MatchTokens.targetLevels),
      fieldIds: _strings(json['fieldIds']),
      targetCountryIds: _strings(json['targetCountryIds'])
          .map((id) => id.toLowerCase())
          .toList(growable: false),
      gradeBandOn20: _token(json['gradeBandOn20'], MatchTokens.gradeBands),
      englishLevel: _token(json['englishLevel'], MatchTokens.languageBands),
      frenchLevel: _token(json['frenchLevel'], MatchTokens.languageBands),
      languageTests: _maps(json['languageTests'])
          .map(MatchLanguageTest.fromJson)
          .whereType<MatchLanguageTest>()
          .toList(growable: false),
      workExperienceBand:
          _token(json['workExperienceBand'], MatchTokens.experienceBands),
      confirmedAt: _date(json['confirmedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nationalityCode': nationalityCode,
        'secondNationalityCode': secondNationalityCode,
        'residence': residence,
        'birthDate': birthDate,
        'guardianConsented': guardianConsented,
        'highestDiploma': highestDiploma,
        'scholarshipTargetLevel': scholarshipTargetLevel,
        'fieldIds': fieldIds,
        'targetCountryIds': targetCountryIds,
        'gradeBandOn20': gradeBandOn20,
        'englishLevel': englishLevel,
        'frenchLevel': frenchLevel,
        'languageTests': languageTests.map((t) => t.toJson()).toList(),
        'workExperienceBand': workExperienceBand,
        'confirmedAt': _iso(confirmedAt),
      };
}

// ── Listes servies ──────────────────────────────────────────────────────────

@immutable
class MatchCountryOption {
  const MatchCountryOption({
    required this.code,
    required this.name,
    this.priority = false,
  });

  /// ISO 3166-1 alpha-3, minuscules.
  final String code;
  final String name;

  /// Afrique de l'Ouest et centrale francophone : en tête de liste.
  final bool priority;
}

@immutable
class MatchNamedOption {
  const MatchNamedOption({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class MatchOptions {
  const MatchOptions({
    this.version,
    this.countries = const <MatchCountryOption>[],
    this.destinations = const <MatchNamedOption>[],
    this.fields = const <MatchNamedOption>[],
  });

  static const empty = MatchOptions();

  final String? version;

  /// Tous les pays, les prioritaires d'abord (ordre servi conservé ensuite).
  final List<MatchCountryOption> countries;
  final List<MatchNamedOption> destinations;
  final List<MatchNamedOption> fields;

  factory MatchOptions.fromJson(Object? raw) {
    final json = _map(raw);
    final countries = <MatchCountryOption>[];
    final seen = <String>{};
    for (final entry in _maps(json['countries'])) {
      final code = _str(entry['code'])?.toLowerCase();
      final name = _str(entry['name']);
      if (code == null || name == null || !seen.add(code)) continue;
      countries.add(MatchCountryOption(
        code: code,
        name: name,
        priority: _bool(entry['priority']),
      ));
    }
    // Tri STABLE : les prioritaires d'abord, l'ordre du serveur ensuite.
    final ordered = <MatchCountryOption>[
      ...countries.where((c) => c.priority),
      ...countries.where((c) => !c.priority),
    ];
    List<MatchNamedOption> named(Object? value) {
      final out = <MatchNamedOption>[];
      final ids = <String>{};
      for (final entry in _maps(value)) {
        final id = _str(entry['id']);
        final name = _str(entry['name']) ?? id;
        if (id == null || name == null || !ids.add(id)) continue;
        out.add(MatchNamedOption(id: id, name: name));
      }
      return List.unmodifiable(out);
    }

    return MatchOptions(
      version: _str(json['version']),
      countries: List.unmodifiable(ordered),
      destinations: named(json['destinations']),
      fields: named(json['fields']),
    );
  }

  String? countryName(String? code) {
    if (code == null) return null;
    for (final c in countries) {
      if (c.code == code) return c.name;
    }
    return null;
  }

  String? fieldName(String id) {
    for (final f in fields) {
      if (f.id == id) return f.name;
    }
    return null;
  }

  String? destinationName(String id) {
    for (final d in destinations) {
      if (d.id == id) return d.name;
    }
    return null;
  }
}

// ── Run ─────────────────────────────────────────────────────────────────────

enum MatchSection { compatible, toVerify }

enum MatchItemStatus { eligible, toVerify }

/// La fenêtre de candidature servie (statut recalculé à l'horloge du serveur).
enum MatchWindowStatus { open, forecast, closed, suspended, unknown }

@immutable
class MatchReason {
  const MatchReason({required this.code, required this.label});

  final String code;
  final String label;

  static MatchReason? fromJson(Map<String, dynamic> json) {
    final label = _str(json['label']);
    if (label == null) return null;
    return MatchReason(code: _str(json['code']) ?? 'unknown', label: label);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'label': label,
      };
}

/// La condition telle que publiée par l'organisme, et sa source.
@immutable
class MatchOfficialCondition {
  const MatchOfficialCondition({required this.text, this.sourceUrl});

  /// Citation EXACTE (peut contenir « % » : c'est le texte de l'organisme).
  final String text;

  /// Lien https, ou `null` quand la source servie n'est pas ouvrable.
  final String? sourceUrl;

  static MatchOfficialCondition? fromJson(Object? raw) {
    final json = _map(raw);
    final text = _str(json['text']);
    if (text == null) return null;
    return MatchOfficialCondition(
      text: text,
      sourceUrl: _httpsUrl(json['sourceUrl']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'sourceUrl': sourceUrl,
      };
}

@immutable
class MatchToVerifyPoint {
  const MatchToVerifyPoint({
    required this.code,
    required this.label,
    this.official,
  });

  final String code;
  final String label;
  final MatchOfficialCondition? official;

  static MatchToVerifyPoint? fromJson(Map<String, dynamic> json) {
    final label = _str(json['label']);
    if (label == null) return null;
    return MatchToVerifyPoint(
      code: _str(json['code']) ?? 'unknown',
      label: label,
      official: MatchOfficialCondition.fromJson(json['official']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'label': label,
        'official': official?.toJson(),
      };
}

@immutable
class MatchScholarshipCard {
  const MatchScholarshipCard({
    this.countryId,
    this.countryName,
    this.fundingType,
    this.fundingLabel,
    this.levelLabel,
    this.deadlineAt,
    this.deadlineLabel,
    this.applicationUrl,
    this.sourceUrl,
  });

  final String? countryId;
  final String? countryName;
  final String? fundingType;
  final String? fundingLabel;
  final String? levelLabel;
  final DateTime? deadlineAt;
  final String? deadlineLabel;
  final String? applicationUrl;
  final String? sourceUrl;

  static MatchScholarshipCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    return MatchScholarshipCard(
      countryId: _str(json['countryId'])?.toLowerCase(),
      countryName: _str(json['countryName']),
      fundingType: _str(json['fundingType']),
      fundingLabel: _str(json['fundingLabel']),
      levelLabel: _str(json['levelLabel']),
      deadlineAt: _date(json['deadlineAt']),
      deadlineLabel: _str(json['deadlineLabel']),
      applicationUrl: _httpsUrl(json['applicationUrl']),
      sourceUrl: _httpsUrl(json['sourceUrl']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'countryId': countryId,
        'countryName': countryName,
        'fundingType': fundingType,
        'fundingLabel': fundingLabel,
        'levelLabel': levelLabel,
        'deadlineAt': _iso(deadlineAt),
        'deadlineLabel': deadlineLabel,
        'applicationUrl': applicationUrl,
        'sourceUrl': sourceUrl,
      };
}

@immutable
class MatchWindow {
  const MatchWindow({
    this.cycleId,
    this.academicYear,
    this.status = MatchWindowStatus.unknown,
    this.dateConfirmed = false,
    this.opensAt,
    this.closesAt,
    this.estimatedOpenAt,
    this.estimatedCloseAt,
  });

  final String? cycleId;
  final String? academicYear;
  final MatchWindowStatus status;

  /// `dateConfidence == "confirmed"`. Toute autre valeur — y compris une
  /// valeur inconnue — vaut « estimée » : jamais de compte à rebours ni de
  /// « Clôturée » sur une date que personne n'a confirmée.
  final bool dateConfirmed;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? estimatedOpenAt;
  final DateTime? estimatedCloseAt;

  static MatchWindow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    return MatchWindow(
      cycleId: _str(json['cycleId']),
      academicYear: _str(json['academicYear']),
      status: switch (_str(json['status'])) {
        'open' => MatchWindowStatus.open,
        'forecast' => MatchWindowStatus.forecast,
        'closed' => MatchWindowStatus.closed,
        'suspended' => MatchWindowStatus.suspended,
        _ => MatchWindowStatus.unknown,
      },
      dateConfirmed: _str(json['dateConfidence']) == 'confirmed',
      opensAt: _date(json['opensAt']),
      closesAt: _date(json['closesAt']),
      estimatedOpenAt: _date(json['estimatedOpenAt']),
      estimatedCloseAt: _date(json['estimatedCloseAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cycleId': cycleId,
        'academicYear': academicYear,
        'status': status == MatchWindowStatus.unknown ? null : status.name,
        'dateConfidence': dateConfirmed ? 'confirmed' : 'estimated',
        'opensAt': _iso(opensAt),
        'closesAt': _iso(closesAt),
        'estimatedOpenAt': _iso(estimatedOpenAt),
        'estimatedCloseAt': _iso(estimatedCloseAt),
      };

  /// Close POUR DE BON : une date limite CONFIRMÉE est passée. C'est la seule
  /// règle valable hors ligne (le statut servi a pu vieillir depuis le run).
  bool isConfirmedClosed(DateTime now) {
    final close = closesAt;
    return dateConfirmed && close != null && !now.isBefore(close);
  }
}

@immutable
class MatchItem {
  const MatchItem({
    required this.scholarshipId,
    required this.name,
    this.cycleId,
    this.rank = 0,
    this.section = MatchSection.toVerify,
    this.status = MatchItemStatus.toVerify,
    this.isNew = false,
    this.available = true,
    this.scholarship,
    this.window,
    this.reasons = const <MatchReason>[],
    this.toVerify = const <MatchToVerifyPoint>[],
  });

  final String scholarshipId;
  final String? cycleId;
  final int rank;
  final MatchSection section;
  final MatchItemStatus status;

  /// Absente du run précédent (puce « Nouveau »).
  final bool isNew;

  /// Faux : la fiche n'est plus publique depuis le run (« Plus disponible »).
  final bool available;
  final String name;
  final MatchScholarshipCard? scholarship;
  final MatchWindow? window;

  /// Au plus 3, servies.
  final List<MatchReason> reasons;
  final List<MatchToVerifyPoint> toVerify;

  bool get isCompatible => section == MatchSection.compatible;

  static MatchItem? fromJson(Map<String, dynamic> json) {
    final id = _str(json['scholarshipId']);
    if (id == null) return null;
    final rawStatus = _str(json['status']);
    // Jamais une bourse exclue à l'écran, même si un serveur la servait.
    if (rawStatus == 'not_eligible') return null;
    // Statut inconnu → « à vérifier » : on ne promet jamais « compatible » sur
    // la foi d'un jeton qu'on ne comprend pas.
    final status = rawStatus == 'eligible'
        ? MatchItemStatus.eligible
        : MatchItemStatus.toVerify;
    final rawSection = _str(json['section']);
    final section =
        rawSection == 'compatible' && status == MatchItemStatus.eligible
            ? MatchSection.compatible
            : rawSection == null && status == MatchItemStatus.eligible
                ? MatchSection.compatible
                : MatchSection.toVerify;
    final available = _bool(json['available'], fallback: true);
    return MatchItem(
      scholarshipId: id,
      cycleId: _str(json['cycleId']),
      rank: _int(json['rank']),
      section: section,
      status: status,
      isNew: _bool(json['isNew']),
      available: available,
      name: _str(json['name']) ?? id,
      scholarship: MatchScholarshipCard.fromJson(json['scholarship']),
      window: MatchWindow.fromJson(json['window']),
      reasons: _maps(json['reasons'])
          .map(MatchReason.fromJson)
          .whereType<MatchReason>()
          .take(3)
          .toList(growable: false),
      toVerify: _maps(json['toVerify'])
          .map(MatchToVerifyPoint.fromJson)
          .whereType<MatchToVerifyPoint>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scholarshipId': scholarshipId,
        'cycleId': cycleId,
        'rank': rank,
        'section':
            section == MatchSection.compatible ? 'compatible' : 'to_verify',
        'status': status == MatchItemStatus.eligible ? 'eligible' : 'to_verify',
        'isNew': isNew,
        'available': available,
        'name': name,
        'scholarship': scholarship?.toJson(),
        'window': window?.toJson(),
        'reasons': reasons.map((r) => r.toJson()).toList(),
        'toVerify': toVerify.map((p) => p.toJson()).toList(),
      };
}

@immutable
class MatchCounts {
  const MatchCounts({
    this.eligible = 0,
    this.toVerify = 0,
    this.excluded = 0,
    this.notAnalyzed = 0,
    this.candidates = 0,
  });

  final int eligible;
  final int toVerify;
  final int excluded;
  final int notAnalyzed;
  final int candidates;

  factory MatchCounts.fromJson(Object? raw) {
    final json = _map(raw);
    return MatchCounts(
      eligible: _int(json['eligible']),
      toVerify: _int(json['toVerify']),
      excluded: _int(json['excluded']),
      notAnalyzed: _int(json['notAnalyzed']),
      candidates: _int(json['candidates']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'eligible': eligible,
        'toVerify': toVerify,
        'excluded': excluded,
        'notAnalyzed': notAnalyzed,
        'candidates': candidates,
      };
}

@immutable
class MatchExcludedGroup {
  const MatchExcludedGroup({
    required this.group,
    required this.count,
    required this.label,
    this.scholarships = const <MatchNamedOption>[],
  });

  /// `level`, `nationality`, `age`, `experience`, `suspended`… Un groupe
  /// inconnu reste affiché : son libellé est servi.
  final String group;
  final int count;
  final String label;

  /// Au plus 20 noms.
  final List<MatchNamedOption> scholarships;

  static MatchExcludedGroup? fromJson(Map<String, dynamic> json) {
    final label = _str(json['label']);
    final count = _int(json['count']);
    if (label == null || count == 0) return null;
    final names = <MatchNamedOption>[];
    for (final entry in _maps(json['scholarships']).take(20)) {
      final id = _str(entry['id']);
      final name = _str(entry['name']);
      if (id != null && name != null) {
        names.add(MatchNamedOption(id: id, name: name));
      }
    }
    return MatchExcludedGroup(
      group: _str(json['group']) ?? 'other',
      count: count,
      label: label,
      scholarships: List.unmodifiable(names),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'group': group,
        'count': count,
        'label': label,
        'scholarships': scholarships
            .map((s) => <String, dynamic>{'id': s.id, 'name': s.name})
            .toList(),
      };
}

@immutable
class MatchExcludedSummary {
  const MatchExcludedSummary({
    this.groups = const <MatchExcludedGroup>[],
    this.notAnalyzedCount = 0,
    this.notAnalyzedLabel,
  });

  final List<MatchExcludedGroup> groups;
  final int notAnalyzedCount;
  final String? notAnalyzedLabel;

  int get excludedCount => groups.fold<int>(0, (sum, g) => sum + g.count);

  bool get isEmpty => groups.isEmpty && notAnalyzedLabel == null;

  factory MatchExcludedSummary.fromJson(Object? raw) {
    final json = _map(raw);
    return MatchExcludedSummary(
      groups: _maps(json['groups'])
          .map(MatchExcludedGroup.fromJson)
          .whereType<MatchExcludedGroup>()
          .toList(growable: false),
      notAnalyzedCount: _int(json['notAnalyzedCount']),
      notAnalyzedLabel: _str(json['notAnalyzedLabel']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'groups': groups.map((g) => g.toJson()).toList(),
        'notAnalyzedCount': notAnalyzedCount,
        'notAnalyzedLabel': notAnalyzedLabel,
      };
}

/// « 1 bourse doctorale dans notre catalogue pour l'instant » — servi, jamais
/// écrit dans l'app. `label` nul : le niveau compte assez de bourses.
@immutable
class MatchLevelCatalog {
  const MatchLevelCatalog({this.level, this.count = 0, this.label});

  final String? level;
  final int count;
  final String? label;

  static MatchLevelCatalog? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    return MatchLevelCatalog(
      level: _str(json['level']),
      count: _int(json['count']),
      label: _str(json['label']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'level': level,
        'count': count,
        'label': label,
      };
}

/// Qui limite la précision quand la moitié au moins est « à vérifier ».
enum MatchPrecisionLimit { kpb, answers }

@immutable
class MatchRun {
  const MatchRun({
    required this.id,
    this.createdAt,
    this.algorithmVersion,
    this.trigger,
    this.counts = const MatchCounts(),
    this.items = const <MatchItem>[],
    this.excludedSummary = const MatchExcludedSummary(),
    this.levelCatalog,
    this.precisionLimitedBy,
  });

  final String id;
  final DateTime? createdAt;
  final String? algorithmVersion;
  final String? trigger;

  /// Sur TOUTES les candidates (pas seulement les ≤ 10 affichées).
  final MatchCounts counts;

  /// Au plus 10, compatibles d'abord.
  final List<MatchItem> items;
  final MatchExcludedSummary excludedSummary;
  final MatchLevelCatalog? levelCatalog;
  final MatchPrecisionLimit? precisionLimitedBy;

  List<MatchItem> get compatibleItems =>
      items.where((i) => i.isCompatible).toList(growable: false);

  List<MatchItem> get toVerifyItems =>
      items.where((i) => !i.isCompatible).toList(growable: false);

  /// Les compatibles qu'on peut suivre (encore publiques).
  List<String> get followableCompatibleIds => items
      .where((i) => i.isCompatible && i.available)
      .map((i) => i.scholarshipId)
      .toList(growable: false);

  static MatchRun? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = _str(json['id']);
    if (id == null) return null;
    final items = _maps(json['items'])
        .map(MatchItem.fromJson)
        .whereType<MatchItem>()
        .take(10)
        .toList();
    // Compatibles d'abord, quel que soit l'ordre reçu ; le rang ensuite.
    items.sort((a, b) {
      final bySection = a.section.index.compareTo(b.section.index);
      return bySection != 0 ? bySection : a.rank.compareTo(b.rank);
    });
    return MatchRun(
      id: id,
      createdAt: _date(json['createdAt']),
      algorithmVersion: _str(json['algorithmVersion']),
      trigger: _str(json['trigger']),
      counts: MatchCounts.fromJson(json['counts']),
      items: List.unmodifiable(items),
      excludedSummary: MatchExcludedSummary.fromJson(json['excludedSummary']),
      levelCatalog: MatchLevelCatalog.fromJson(json['levelCatalog']),
      precisionLimitedBy: switch (_str(json['precisionLimitedBy'])) {
        'kpb' => MatchPrecisionLimit.kpb,
        'answers' => MatchPrecisionLimit.answers,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': _iso(createdAt),
        'algorithmVersion': algorithmVersion,
        'trigger': trigger,
        'counts': counts.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'excludedSummary': excludedSummary.toJson(),
        'levelCatalog': levelCatalog?.toJson(),
        'precisionLimitedBy': precisionLimitedBy?.name,
      };
}

@immutable
class MatchRunDiff {
  const MatchRunDiff({
    this.previousRunId,
    this.addedIds = const <String>[],
    this.removedIds = const <String>[],
  });

  static const none = MatchRunDiff();

  final String? previousRunId;
  final List<String> addedIds;
  final List<String> removedIds;

  bool get isEmpty => addedIds.isEmpty && removedIds.isEmpty;

  factory MatchRunDiff.fromJson(Object? raw) {
    final json = _map(raw);
    return MatchRunDiff(
      previousRunId: _str(json['previousRunId']),
      addedIds: _strings(json['addedIds']),
      removedIds: _strings(json['removedIds']),
    );
  }
}

// ── État ────────────────────────────────────────────────────────────────────

@immutable
class ScholarshipMatchState {
  const ScholarshipMatchState({
    this.algorithmVersion,
    this.readiness = const MatchReadiness(),
    this.prefill = const <MatchPrefill>[],
    this.answers = MatchAnswers.empty,
    this.options = MatchOptions.empty,
    this.latestRun,
    this.isStale = false,
    this.staleReasons = const <String>[],
    this.catalogSize = 0,
    this.alertsOptIn = false,
  });

  final String? algorithmVersion;
  final MatchReadiness readiness;
  final List<MatchPrefill> prefill;
  final MatchAnswers answers;
  final MatchOptions options;
  final MatchRun? latestRun;

  /// Le profil, le catalogue ou l'algorithme ont changé depuis le run.
  final bool isStale;
  final List<String> staleReasons;

  /// Bourses analysées (« On analyse 29 bourses… »).
  final int catalogSize;
  final bool alertsOptIn;

  factory ScholarshipMatchState.fromJson(Object? raw) {
    final json = _map(raw);
    return ScholarshipMatchState(
      algorithmVersion: _str(json['algorithmVersion']),
      readiness: MatchReadiness.fromJson(json['readiness']),
      prefill: _maps(json['prefill'])
          .map(MatchPrefill.fromJson)
          .whereType<MatchPrefill>()
          .toList(growable: false),
      answers: MatchAnswers.fromJson(json['answers']),
      options: MatchOptions.fromJson(json['options']),
      latestRun: MatchRun.fromJson(json['latestRun']),
      isStale: _bool(json['isStale']),
      staleReasons: _strings(json['staleReasons']),
      catalogSize: _int(json['catalogSize']),
      alertsOptIn: _bool(json['alertsOptIn']),
    );
  }

  MatchPrefill? prefillFor(String key) {
    for (final p in prefill) {
      if (p.key == key) return p;
    }
    return null;
  }

  ScholarshipMatchState copyWith({
    MatchRun? latestRun,
    bool? isStale,
    bool? alertsOptIn,
    MatchReadiness? readiness,
  }) =>
      ScholarshipMatchState(
        algorithmVersion: algorithmVersion,
        readiness: readiness ?? this.readiness,
        prefill: prefill,
        answers: answers,
        options: options,
        latestRun: latestRun ?? this.latestRun,
        isStale: isStale ?? this.isStale,
        staleReasons: isStale == false ? const <String>[] : staleReasons,
        catalogSize: catalogSize,
        alertsOptIn: alertsOptIn ?? this.alertsOptIn,
      );
}

/// Réponse de `POST /scholarships/match/runs`.
sealed class MatchRunResponse {
  const MatchRunResponse();

  /// `status` inconnu → `null` : l'appelant le traite comme un échec, jamais
  /// comme un run vide.
  static MatchRunResponse? fromJson(Object? raw) {
    final json = _map(raw);
    switch (_str(json['status'])) {
      case 'ok':
        final run = MatchRun.fromJson(json['run']);
        if (run == null) return null;
        return MatchRunOk(run: run, diff: MatchRunDiff.fromJson(json['diff']));
      case 'profile_incomplete':
        return MatchRunIncomplete(
          readiness: MatchReadiness.fromJson(json['readiness']),
        );
      default:
        return null;
    }
  }
}

class MatchRunOk extends MatchRunResponse {
  const MatchRunOk({required this.run, this.diff = MatchRunDiff.none});

  final MatchRun run;
  final MatchRunDiff diff;
}

class MatchRunIncomplete extends MatchRunResponse {
  const MatchRunIncomplete({required this.readiness});

  final MatchReadiness readiness;
}

/// `POST /me/scholarship-alerts` (groupé).
@immutable
class MatchBulkFollowResult {
  const MatchBulkFollowResult({
    this.subscribedIds = const <String>[],
    this.skippedIds = const <String>[],
  });

  final List<String> subscribedIds;
  final List<String> skippedIds;

  factory MatchBulkFollowResult.fromJson(Object? raw) {
    final json = _map(raw);
    return MatchBulkFollowResult(
      subscribedIds: _strings(json['subscribedIds']),
      skippedIds: _strings(json['skippedIds']),
    );
  }
}

// ── Échecs ──────────────────────────────────────────────────────────────────

/// Pourquoi un appel du test a échoué — des identifiants fermés, aussi
/// envoyés tels quels dans `scholarship_match_failed`.
enum ScholarshipMatchFailure {
  /// 404/405/501 : drapeau serveur coupé (`{disabled: true}`) ou backend sans
  /// les routes. Traité comme « drapeau fermé » : la carte se masque.
  disabled,

  /// 401 : la session n'est plus valable.
  unauthorized,

  /// 403 : compte parent ou partenaire (le test leur est caché).
  forbidden,

  /// 429 : trop d'essais en une minute.
  rateLimited,

  /// Délai dépassé.
  timeout,

  /// Pas de réseau.
  offline,

  /// 5xx ou autre réponse inattendue.
  server,

  /// Réponse illisible (forme inconnue).
  invalid,
}

/// Une erreur typée du test.
class ScholarshipMatchException implements Exception {
  const ScholarshipMatchException(this.failure, [this.statusCode]);

  final ScholarshipMatchFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'ScholarshipMatchException(${failure.name}${statusCode == null ? '' : ', $statusCode'})';
}
