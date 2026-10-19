import 'package:flutter/foundation.dart';

import '../../core/models/scholarship_match.dart';

/// Comment l'assistant s'ouvre.
enum MatchFlowMode {
  /// Seulement ce qui manque (ou ce qui est ambigu), puis le récapitulatif.
  missing,

  /// « Refaire le test » : toutes les questions, valeurs actuelles cochées.
  full,

  /// « Modifier mes infos » : directement le récapitulatif.
  recap,
}

/// Les écrans hors questions.
abstract final class MatchFlowScreen {
  static const intro = 'intro';
  static const recap = 'recap';
}

/// L'ordre des questions. Chaque clé est une clé de `readiness` que cette
/// build sait poser ; la résidence se règle au récapitulatif.
const List<String> matchStepOrder = <String>[
  MatchReadinessKey.nationalityCode,
  MatchReadinessKey.birthDate,
  MatchReadinessKey.guardianConsent,
  MatchReadinessKey.highestDiploma,
  MatchReadinessKey.scholarshipTargetLevel,
  MatchReadinessKey.fields,
  MatchReadinessKey.gradeBandOn20,
  MatchReadinessKey.englishLevel,
  MatchReadinessKey.workExperienceBand,
];

/// Les noms d'étape envoyés à l'analytique (identifiants fermés, jamais une
/// valeur).
String matchStepAnalyticsName(String key) => switch (key) {
      MatchReadinessKey.nationalityCode => 'nationality',
      MatchReadinessKey.birthDate => 'birth_date',
      MatchReadinessKey.guardianConsent => 'guardian',
      MatchReadinessKey.highestDiploma => 'diploma',
      MatchReadinessKey.scholarshipTargetLevel => 'target_level',
      MatchReadinessKey.fields => 'fields',
      MatchReadinessKey.gradeBandOn20 => 'grade',
      MatchReadinessKey.englishLevel => 'language',
      MatchReadinessKey.workExperienceBand => 'work_experience',
      MatchFlowScreen.intro => 'intro',
      MatchFlowScreen.recap => 'recap',
      MatchReadinessKey.residence => 'residence',
      _ => 'other',
    };

/// Les clés de valeur du brouillon (celles de `answers` côté serveur, plus
/// trois marqueurs locaux).
abstract final class MatchDraftKey {
  static const nationalityCode = 'nationalityCode';
  static const secondNationalityCode = 'secondNationalityCode';
  static const residence = 'residence';
  static const birthDate = 'birthDate';
  static const guardianName = 'guardianName';
  static const guardianContact = 'guardianContact';
  static const guardianConsent = 'guardianConsent';
  static const highestDiploma = 'highestDiploma';
  static const scholarshipTargetLevel = 'scholarshipTargetLevel';
  static const fieldIds = 'fieldIds';

  /// Local : « Pas encore décidé » a été choisi (une liste vide est une
  /// réponse).
  static const fieldsDecided = 'fieldsDecided';
  static const targetCountryIds = 'targetCountryIds';
  static const gradeBandOn20 = 'gradeBandOn20';
  static const englishLevel = 'englishLevel';
  static const frenchLevel = 'frenchLevel';
  static const languageTests = 'languageTests';
  static const workExperienceBand = 'workExperienceBand';

  /// Local : la case de consentement explicite à l'usage de la nationalité
  /// (décision du propriétaire, 18/10/2026 : base légale = consentement).
  /// Jamais envoyée au serveur, jamais gardée dans le brouillon : décochée à
  /// chaque ouverture de l'assistant.
  static const nationalityConsent = 'nationalityConsent';
}

/// Âge révolu à [now] d'une date `AAAA-MM-JJ`, ou `null`.
int? matchAgeFromIsoDay(String? isoDay, DateTime now) {
  if (isoDay == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDay);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  var age = now.year - year;
  if (now.month < month || (now.month == month && now.day < day)) age -= 1;
  return age;
}

/// `AAAA-MM-JJ` d'une date choisie au calendrier (jour calendaire, sans
/// fuseau).
String matchIsoDay(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// « Mon système n'est pas sur 20 » : une note sur [scale] (4, 10 ou 100)
/// ramenée à la tranche sur 20. `null` si la note sort de l'échelle.
String? matchGradeBandFromScale(double value, double scale) {
  if (!value.isFinite || scale <= 0 || value < 0 || value > scale) return null;
  final on20 = value / scale * 20;
  if (on20 < 10) return 'lt10';
  if (on20 < 12) return '10_12';
  if (on20 < 14) return '12_14';
  if (on20 < 16) return '14_16';
  return '16_plus';
}

/// Le diplôme minimal attendu pour un niveau visé (indication douce).
bool matchTargetNeedsMoreDiploma(String? target, String? diploma) {
  if (target == null || diploma == null) return false;
  const rank = <String, int>{
    'none': 0,
    'bac': 1,
    'bac_plus_2': 2,
    'licence': 3,
    'master': 4,
    'doctorat': 5,
  };
  final have = rank[diploma] ?? 0;
  return switch (target) {
    'bachelor' => have < 1,
    'master' => have < 3,
    'doctorate' => have < 4,
    _ => false,
  };
}

/// Le brouillon de l'assistant, persisté après chaque étape (Hive, par
/// compte) : un téléphone tué en pleine saisie reprend au même écran.
@immutable
class ScholarshipMatchDraft {
  const ScholarshipMatchDraft({
    required this.values,
    required this.touched,
    required this.screen,
    required this.mode,
    required this.startedAt,
  });

  static const version = 1;

  final Map<String, Object?> values;
  final Set<String> touched;
  final String screen;
  final MatchFlowMode mode;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': version,
        'values': values,
        'touched': touched.toList(),
        'screen': screen,
        'mode': mode.name,
        'startedAt': startedAt.toUtc().toIso8601String(),
      };

  static ScholarshipMatchDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['v'] != version) return null;
    final values = json['values'];
    final screen = json['screen'];
    if (values is! Map || screen is! String) return null;
    final mode =
        MatchFlowMode.values.where((m) => m.name == json['mode']).firstOrNull;
    return ScholarshipMatchDraft(
      values: Map<String, Object?>.from(values),
      touched: (json['touched'] is List)
          ? (json['touched'] as List).whereType<String>().toSet()
          : <String>{},
      screen: screen,
      mode: mode ?? MatchFlowMode.missing,
      startedAt: DateTime.tryParse('${json['startedAt']}') ?? DateTime.now(),
    );
  }
}

/// La logique de l'assistant, sans widget : quels écrans, quelles valeurs,
/// quelle requête.
///
/// Les écrans sont TIRÉS de `readiness` : seules les clés manquantes (ou
/// dont la suggestion est ambiguë) et connues de cette build deviennent une
/// question. Deux exceptions dynamiques, parce qu'elles dépendent d'une
/// réponse donnée DANS l'assistant :
/// - l'accord du représentant légal, pour un mineur sans accord ;
/// - l'expérience professionnelle, seulement pour une cible Master/Doctorat.
class ScholarshipMatchFlowController extends ChangeNotifier {
  ScholarshipMatchFlowController({
    required this.state,
    this.mode = MatchFlowMode.missing,
    ScholarshipMatchDraft? draft,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final restored = draft;
    if (restored != null) {
      mode = restored.mode;
      _values.addAll(restored.values);
      _touched.addAll(restored.touched);
      startedAt = restored.startedAt;
    } else {
      _seedValues();
      startedAt = _now();
    }
    _baseSteps = _computeBaseSteps();
    final screens = this.screens;
    final resumeAt = restored == null ? -1 : screens.indexOf(restored.screen);
    _index = resumeAt >= 0
        ? resumeAt
        : mode == MatchFlowMode.recap
            ? screens.length - 1
            : 0;
    resumed = restored != null;
  }

  final ScholarshipMatchState state;
  MatchFlowMode mode;
  final DateTime Function() _now;
  late final DateTime startedAt;

  /// Vrai quand l'assistant a repris un brouillon.
  late final bool resumed;

  final Map<String, Object?> _values = <String, Object?>{};
  final Set<String> _touched = <String>{};
  late final List<String> _baseSteps;
  int _index = 0;

  /// Clé en cours d'édition depuis le récapitulatif (« Modifier »), ou null.
  String? editing;

  // ── Valeurs ──────────────────────────────────────────────────────────────

  void _seedValues() {
    final a = state.answers;
    void put(String key, Object? value) {
      if (value != null) _values[key] = value;
    }

    put(MatchDraftKey.nationalityCode, a.nationalityCode);
    put(MatchDraftKey.secondNationalityCode, a.secondNationalityCode);
    put(MatchDraftKey.residence, a.residence);
    put(MatchDraftKey.birthDate, a.birthDate);
    put(MatchDraftKey.highestDiploma, a.highestDiploma);
    put(MatchDraftKey.scholarshipTargetLevel, a.scholarshipTargetLevel);
    _values[MatchDraftKey.fieldIds] = List<String>.of(a.fieldIds);
    if (a.fieldIds.isNotEmpty || a.confirmedAt != null) {
      _values[MatchDraftKey.fieldsDecided] = true;
    }
    _values[MatchDraftKey.targetCountryIds] = List<String>.of(
      a.targetCountryIds,
    );
    put(MatchDraftKey.gradeBandOn20, a.gradeBandOn20);
    put(MatchDraftKey.englishLevel, a.englishLevel);
    put(MatchDraftKey.frenchLevel, a.frenchLevel);
    _values[MatchDraftKey.languageTests] =
        a.languageTests.map((t) => t.toJson()).toList();
    put(MatchDraftKey.workExperienceBand, a.workExperienceBand);

    // Suggestions des anciens champs, pour les clés encore vides. Une
    // suggestion n'est jamais une valeur confirmée : elle s'affiche (cochée)
    // et l'élève la valide.
    for (final p in state.prefill) {
      final key = _valueKeyFor(p.key);
      if (key == null || _values[key] != null) continue;
      final value = _validPrefill(p);
      if (value != null) _values[key] = value;
    }
  }

  static String? _valueKeyFor(String readinessKey) => switch (readinessKey) {
        MatchReadinessKey.nationalityCode => MatchDraftKey.nationalityCode,
        MatchReadinessKey.residence => MatchDraftKey.residence,
        MatchReadinessKey.highestDiploma => MatchDraftKey.highestDiploma,
        MatchReadinessKey.scholarshipTargetLevel =>
          MatchDraftKey.scholarshipTargetLevel,
        MatchReadinessKey.gradeBandOn20 => MatchDraftKey.gradeBandOn20,
        MatchReadinessKey.englishLevel => MatchDraftKey.englishLevel,
        _ => null,
      };

  static String? _validPrefill(MatchPrefill p) {
    final value = p.value;
    return switch (p.key) {
      MatchReadinessKey.nationalityCode ||
      MatchReadinessKey.residence =>
        RegExp(r'^[a-z]{3}$').hasMatch(value.toLowerCase())
            ? value.toLowerCase()
            : null,
      MatchReadinessKey.highestDiploma =>
        MatchTokens.diplomas.contains(value) ? value : null,
      MatchReadinessKey.scholarshipTargetLevel =>
        MatchTokens.targetLevels.contains(value) ? value : null,
      MatchReadinessKey.gradeBandOn20 =>
        MatchTokens.gradeBands.contains(value) ? value : null,
      MatchReadinessKey.englishLevel =>
        MatchTokens.languageBands.contains(value) ? value : null,
      _ => null,
    };
  }

  /// Copie des valeurs du brouillon.
  Map<String, Object?> get values => Map.unmodifiable(_values);

  T? value<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  List<String> stringList(String key) {
    final v = _values[key];
    return v is List ? v.whereType<String>().toList() : <String>[];
  }

  bool wasTouched(String key) => _touched.contains(key);

  /// Pose une valeur (une puce touchée, une date choisie).
  void set(String key, Object? value) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _touched.add(key);
    notifyListeners();
  }

  /// La suggestion servie pour une clé de `readiness`, ou `null`.
  MatchPrefill? prefillFor(String readinessKey) =>
      state.prefillFor(readinessKey);

  /// L'élève a-t-il changé la valeur suggérée (analytique, sans la valeur) ?
  bool changedPrefill(String readinessKey) {
    final p = prefillFor(readinessKey);
    final key = _valueKeyFor(readinessKey);
    if (p == null || key == null) return false;
    return _values[key] != _validPrefill(p);
  }

  // ── Dérivés ──────────────────────────────────────────────────────────────

  int? get age =>
      matchAgeFromIsoDay(value<String>(MatchDraftKey.birthDate), _now());

  /// Un mineur sans accord du représentant légal (cas du « Passer » de
  /// l'onboarding : ni date de naissance ni accord).
  bool get needsGuardian =>
      !state.answers.guardianConsented && (age ?? 99) < 18;

  String? get target => value<String>(MatchDraftKey.scholarshipTargetLevel);

  /// La case « J'accepte que KPB Education utilise ma nationalité… » est
  /// cochée. Sans elle, le récapitulatif ne s'envoie pas : la nationalité
  /// n'est collectée qu'avec un consentement explicite.
  bool get nationalityConsented =>
      value<bool>(MatchDraftKey.nationalityConsent) == true;

  bool get needsExperience =>
      target != null && MatchTokens.experienceTargets.contains(target);

  /// Les niveaux proposables : ceux servis (connus), le lycée seulement si
  /// le serveur le propose ET que l'âge saisi le permet (19 ans au plus).
  List<String> get targetLevelOptions {
    final served = state.readiness.targetLevelOptions;
    final base = served.isEmpty
        ? const <String>['bachelor', 'master', 'doctorate']
        : served;
    final a = age;
    return base
        .where((level) => level != 'secondary' || (a != null && a <= 19))
        .toList(growable: false);
  }

  // ── Écrans ───────────────────────────────────────────────────────────────

  List<String> _computeBaseSteps() {
    if (mode == MatchFlowMode.recap) return const <String>[];
    if (mode == MatchFlowMode.full) return List<String>.of(matchStepOrder);
    final required = state.readiness.required.toSet();
    final steps = <String>[];
    for (final key in matchStepOrder) {
      final prefill = state.prefillFor(key);
      final askedByServer = required.contains(key) &&
          (prefill == null ||
              prefill.ambiguous ||
              _validPrefill(prefill) == null);
      // Une suggestion ambiguë se pose toujours, même si la clé n'est pas
      // listée comme manquante.
      final ambiguous = prefill != null && prefill.ambiguous;
      if (askedByServer || ambiguous) steps.add(key);
    }
    return steps;
  }

  /// Les questions actives, dans l'ordre.
  List<String> get steps {
    final out = <String>[];
    for (final key in matchStepOrder) {
      switch (key) {
        case MatchReadinessKey.guardianConsent:
          if (needsGuardian &&
              (_baseSteps.contains(key) ||
                  _baseSteps.contains(MatchReadinessKey.birthDate) ||
                  mode == MatchFlowMode.full)) {
            out.add(key);
          }
        case MatchReadinessKey.workExperienceBand:
          final missing = state.answers.workExperienceBand == null;
          if (needsExperience &&
              (mode == MatchFlowMode.full ||
                  _baseSteps.contains(key) ||
                  (missing &&
                      _baseSteps.contains(
                          MatchReadinessKey.scholarshipTargetLevel)))) {
            out.add(key);
          }
        default:
          if (_baseSteps.contains(key)) out.add(key);
      }
    }
    return out;
  }

  /// L'écran d'accueil n'apparaît qu'au premier test.
  bool get showIntro =>
      mode == MatchFlowMode.missing && state.latestRun == null;

  List<String> get screens => <String>[
        if (showIntro) MatchFlowScreen.intro,
        ...steps,
        MatchFlowScreen.recap,
      ];

  int get index => _index.clamp(0, screens.length - 1);

  String get current => editing ?? screens[index];

  bool get onRecap => editing == null && current == MatchFlowScreen.recap;

  /// « 2/5 » : la position parmi les QUESTIONS (accueil et récapitulatif ne
  /// comptent pas). `null` hors question.
  (int, int)? get progress {
    if (editing != null) return null;
    final s = steps;
    final i = s.indexOf(current);
    return i < 0 ? null : (i + 1, s.length);
  }

  /// Nombre de questions annoncé à l'accueil (« 3 questions »).
  int get questionCount => steps.length;

  bool get canGoBack => editing != null || index > 0;

  void next() {
    if (editing != null) {
      editing = null;
      notifyListeners();
      return;
    }
    final total = screens.length;
    if (_index < total - 1) _index = index + 1;
    notifyListeners();
  }

  void back() {
    if (editing != null) {
      editing = null;
    } else if (_index > 0) {
      _index = index - 1;
    }
    notifyListeners();
  }

  /// « Modifier » depuis le récapitulatif : ouvre une question seule.
  void edit(String key) {
    editing = key;
    notifyListeners();
  }

  /// Revient à la première question qui manque encore (réponse
  /// `profile_incomplete` du serveur), sinon au récapitulatif.
  void jumpToFirstMissing() {
    final missing = recapMissing;
    if (missing.isNotEmpty) {
      editing =
          missing.first == MatchReadinessKey.residence ? null : missing.first;
    }
    _index = screens.length - 1;
    notifyListeners();
  }

  /// La question en cours a-t-elle une réponse valable ?
  bool isAnswered(String key) {
    switch (key) {
      case MatchFlowScreen.intro:
        return true;
      case MatchReadinessKey.nationalityCode:
        return value<String>(MatchDraftKey.nationalityCode) != null;
      case MatchReadinessKey.residence:
        return value<String>(MatchDraftKey.residence) != null;
      case MatchReadinessKey.birthDate:
        final a = age;
        return a != null && a >= 16;
      case MatchReadinessKey.guardianConsent:
        return (value<String>(
                        MatchDraftKey.guardianName) ??
                    '')
                .trim()
                .isNotEmpty &&
            (value<String>(MatchDraftKey.guardianContact) ?? '')
                .trim()
                .isNotEmpty &&
            value<bool>(MatchDraftKey.guardianConsent) == true;
      case MatchReadinessKey.highestDiploma:
        return value<String>(MatchDraftKey.highestDiploma) != null;
      case MatchReadinessKey.scholarshipTargetLevel:
        final t = target;
        return t != null && targetLevelOptions.contains(t);
      case MatchReadinessKey.fields:
        return stringList(MatchDraftKey.fieldIds).isNotEmpty ||
            value<bool>(MatchDraftKey.fieldsDecided) == true;
      case MatchReadinessKey.gradeBandOn20:
        return value<String>(MatchDraftKey.gradeBandOn20) != null;
      case MatchReadinessKey.englishLevel:
        return value<String>(MatchDraftKey.englishLevel) != null;
      case MatchReadinessKey.workExperienceBand:
        return value<String>(MatchDraftKey.workExperienceBand) != null;
      case MatchFlowScreen.recap:
        return recapMissing.isEmpty && nationalityConsented;
      default:
        return true;
    }
  }

  bool get canContinue => isAnswered(current);

  /// Les clés obligatoires encore vides, dans l'ordre du récapitulatif.
  List<String> get recapMissing => <String>[
        if (!isAnswered(MatchReadinessKey.nationalityCode))
          MatchReadinessKey.nationalityCode,
        if (!isAnswered(MatchReadinessKey.residence))
          MatchReadinessKey.residence,
        if (!isAnswered(MatchReadinessKey.birthDate))
          MatchReadinessKey.birthDate,
        if (needsGuardian && !isAnswered(MatchReadinessKey.guardianConsent))
          MatchReadinessKey.guardianConsent,
        if (!isAnswered(MatchReadinessKey.highestDiploma))
          MatchReadinessKey.highestDiploma,
        if (!isAnswered(MatchReadinessKey.scholarshipTargetLevel))
          MatchReadinessKey.scholarshipTargetLevel,
        if (!isAnswered(MatchReadinessKey.fields)) MatchReadinessKey.fields,
        if (!isAnswered(MatchReadinessKey.gradeBandOn20))
          MatchReadinessKey.gradeBandOn20,
        if (!isAnswered(MatchReadinessKey.englishLevel))
          MatchReadinessKey.englishLevel,
        if (needsExperience &&
            !isAnswered(MatchReadinessKey.workExperienceBand))
          MatchReadinessKey.workExperienceBand,
      ];

  // ── Requête ──────────────────────────────────────────────────────────────

  /// Le corps `answers` de `POST /scholarships/match/runs` : seulement des
  /// clés comprises par le serveur, jamais une valeur vide pour une clé
  /// obligatoire.
  Map<String, dynamic> buildAnswers() {
    final out = <String, dynamic>{};
    void put(String key) {
      final v = _values[key];
      if (v is String && v.isNotEmpty) out[key] = v;
    }

    put(MatchDraftKey.nationalityCode);
    final second = value<String>(MatchDraftKey.secondNationalityCode);
    if (second != null) {
      out[MatchDraftKey.secondNationalityCode] = second;
    } else if (wasTouched(MatchDraftKey.secondNationalityCode)) {
      // « Je n'ai qu'une nationalité » : `null` efface côté serveur.
      out[MatchDraftKey.secondNationalityCode] = null;
    }
    put(MatchDraftKey.residence);
    put(MatchDraftKey.birthDate);
    if (needsGuardian && value<bool>(MatchDraftKey.guardianConsent) == true) {
      out[MatchDraftKey.guardianConsent] = true;
      final name = value<String>(MatchDraftKey.guardianName)?.trim();
      final contact = value<String>(MatchDraftKey.guardianContact)?.trim();
      if (name != null && name.isNotEmpty) {
        out[MatchDraftKey.guardianName] = name;
      }
      if (contact != null && contact.isNotEmpty) {
        out[MatchDraftKey.guardianContact] = contact;
      }
    }
    put(MatchDraftKey.highestDiploma);
    put(MatchDraftKey.scholarshipTargetLevel);
    if (isAnswered(MatchReadinessKey.fields)) {
      out[MatchDraftKey.fieldIds] =
          stringList(MatchDraftKey.fieldIds).take(3).toList();
    }
    final destinations = stringList(MatchDraftKey.targetCountryIds);
    if (destinations.isNotEmpty || wasTouched(MatchDraftKey.targetCountryIds)) {
      out[MatchDraftKey.targetCountryIds] = destinations;
    }
    put(MatchDraftKey.gradeBandOn20);
    put(MatchDraftKey.englishLevel);
    final french = value<String>(MatchDraftKey.frenchLevel);
    if (french != null) {
      out[MatchDraftKey.frenchLevel] = french;
    } else if (wasTouched(MatchDraftKey.frenchLevel)) {
      out[MatchDraftKey.frenchLevel] = null;
    }
    final tests = _values[MatchDraftKey.languageTests];
    if (tests is List &&
        (tests.isNotEmpty || wasTouched(MatchDraftKey.languageTests))) {
      out[MatchDraftKey.languageTests] = tests;
    }
    if (needsExperience) put(MatchDraftKey.workExperienceBand);
    return out;
  }

  /// Ce qui ne se garde JAMAIS sur l'appareil : le nom et le contact du
  /// représentant légal (même règle que l'onboarding). À la reprise, l'élève
  /// les ressaisit.
  static const Set<String> _notPersisted = <String>{
    MatchDraftKey.guardianName,
    MatchDraftKey.guardianContact,
    // Le consentement se donne au moment de l'envoi : un brouillon repris
    // redemande la case.
    MatchDraftKey.nationalityConsent,
  };

  /// Le brouillon à persister.
  ScholarshipMatchDraft toDraft() => ScholarshipMatchDraft(
        values: Map<String, Object?>.of(_values)
          ..removeWhere((key, _) => _notPersisted.contains(key)),
        touched: Set<String>.of(_touched),
        screen: screens[index],
        mode: mode,
        startedAt: startedAt,
      );

  /// Les tests de langue du brouillon.
  List<MatchLanguageTest> get languageTests {
    final raw = _values[MatchDraftKey.languageTests];
    if (raw is! List) return const <MatchLanguageTest>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => MatchLanguageTest.fromJson(Map<String, dynamic>.from(m)))
        .whereType<MatchLanguageTest>()
        .toList(growable: false);
  }

  /// Ajoute (ou remplace, un par type) un score de test.
  void putLanguageTest(MatchLanguageTest test) {
    final next = <MatchLanguageTest>[
      ...languageTests.where((t) => t.type != test.type),
      test,
    ];
    set(MatchDraftKey.languageTests, next.map((t) => t.toJson()).toList());
  }

  void removeLanguageTest(String type) {
    set(
      MatchDraftKey.languageTests,
      languageTests
          .where((t) => t.type != type)
          .map((t) => t.toJson())
          .toList(),
    );
  }
}
