// M11 — Simulateur d'éligibilité.
//
// Deterministic, fully client-side engine: the student provides ~5 inputs and
// receives a 🟢 / 🟡 / 🔴 verdict for each of the 9 MVP destinations, with
// human-readable reasons. No backend round-trip — works offline and is cheap
// to unit-test.

import 'package:get/get.dart';
import '../../core/models/app_models.dart';

/// Self-rated proficiency for a given language.
enum LangLevel { faible, moyen, bon }

extension LangLevelLabel on LangLevel {
  String get labelFr {
    switch (this) {
      case LangLevel.faible:
        return 'lang_level_beginner'.tr;
      case LangLevel.moyen:
        return 'lang_level_intermediate'.tr;
      case LangLevel.bon:
        return 'lang_level_fluent'.tr;
    }
  }

  /// Points contributed to the eligibility score (0–2).
  int get points {
    switch (this) {
      case LangLevel.faible:
        return 0;
      case LangLevel.moyen:
        return 1;
      case LangLevel.bon:
        return 2;
    }
  }
}

/// The five inputs that drive the simulation. All are optional so the form can
/// run with partial data (missing budget is treated as "à confirmer").
class EligibilityInput {
  const EligibilityInput({
    this.studyLevel,
    this.bacSeries,
    this.monthlyBudgetEur,
    this.frenchLevel = LangLevel.bon,
    this.englishLevel = LangLevel.moyen,
  });

  final String? studyLevel;
  final String? bacSeries;
  final int? monthlyBudgetEur;
  final LangLevel frenchLevel;
  final LangLevel englishLevel;

  /// Build sensible defaults from the user's saved profile.
  factory EligibilityInput.fromProfile(UserProfile profile) {
    return EligibilityInput(
      studyLevel: profile.currentLevel,
      bacSeries: profile.bacSeries,
      monthlyBudgetEur: profile.monthlyBudgetEur,
    );
  }

  EligibilityInput copyWith({
    String? studyLevel,
    String? bacSeries,
    int? monthlyBudgetEur,
    LangLevel? frenchLevel,
    LangLevel? englishLevel,
    bool clearBudget = false,
    bool clearStudyLevel = false,
    bool clearBacSeries = false,
  }) {
    return EligibilityInput(
      studyLevel: clearStudyLevel ? null : (studyLevel ?? this.studyLevel),
      bacSeries: clearBacSeries ? null : (bacSeries ?? this.bacSeries),
      monthlyBudgetEur:
          clearBudget ? null : (monthlyBudgetEur ?? this.monthlyBudgetEur),
      frenchLevel: frenchLevel ?? this.frenchLevel,
      englishLevel: englishLevel ?? this.englishLevel,
    );
  }
}

/// The language that primarily matters for studying in a country.
enum PrimaryLang { fr, en }

/// Per-country eligibility ruleset. Budgets are expressed in EUR/month so they
/// can be compared against a single budget input regardless of local currency.
class EligibilityRule {
  const EligibilityRule({
    required this.countryId,
    required this.nameFr,
    required this.flag,
    required this.budgetComfortEur,
    required this.budgetMinimumEur,
    required this.primaryLanguage,
    required this.noteFr,
    this.acceptsEnglishPrograms = false,
    this.bilingualFrEn = false,
  });

  final String countryId;
  final String nameFr;
  final String flag;

  /// Monthly budget (EUR) for a comfortable 🟢 verdict.
  final int budgetComfortEur;

  /// Monthly budget (EUR) below which the country is 🔴 on budget alone.
  final int budgetMinimumEur;

  final PrimaryLang primaryLanguage;
  final String noteFr;

  /// Whether English-taught programs let a non-English-primary country qualify
  /// through the student's English level.
  final bool acceptsEnglishPrograms;

  /// Canada: French OR English both fully count.
  final bool bilingualFrEn;
}

/// The MVP destinations, in canonical order (Belgique ajoutée le 12/11/2026).
const kEligibilityRules = <EligibilityRule>[
  EligibilityRule(
    countryId: 'fra',
    nameFr: 'France',
    flag: '🇫🇷',
    budgetComfortEur: 900,
    budgetMinimumEur: 650,
    primaryLanguage: PrimaryLang.fr,
    acceptsEnglishPrograms: true,
    noteFr:
        'Majorité de programmes en français ; quelques masters enseignés en anglais.',
  ),
  EligibilityRule(
    countryId: 'deu',
    nameFr: 'Allemagne',
    flag: '🇩🇪',
    budgetComfortEur: 950,
    budgetMinimumEur: 700,
    primaryLanguage: PrimaryLang.en,
    acceptsEnglishPrograms: true,
    noteFr:
        'Nombreux masters en anglais ; l\'allemand aide pour le quotidien et les jobs étudiants.',
  ),
  EligibilityRule(
    countryId: 'usa',
    nameFr: 'États-Unis',
    flag: '🇺🇸',
    budgetComfortEur: 1500,
    budgetMinimumEur: 1100,
    primaryLanguage: PrimaryLang.en,
    noteFr:
        'TOEFL/IELTS exigé. Budget élevé : prévois le logement et l\'assurance santé.',
  ),
  EligibilityRule(
    countryId: 'can',
    nameFr: 'Canada',
    flag: '🇨🇦',
    budgetComfortEur: 1100,
    budgetMinimumEur: 850,
    primaryLanguage: PrimaryLang.en,
    acceptsEnglishPrograms: true,
    bilingualFrEn: true,
    noteFr:
        'Anglais ou français accepté selon la province. Preuve de fonds requise pour le permis d\'études.',
  ),
  EligibilityRule(
    countryId: 'mar',
    nameFr: 'Maroc',
    flag: '🇲🇦',
    budgetComfortEur: 450,
    budgetMinimumEur: 300,
    primaryLanguage: PrimaryLang.fr,
    noteFr:
        'Enseignement majoritairement francophone ; coût de la vie le plus accessible.',
  ),
  EligibilityRule(
    countryId: 'tur',
    nameFr: 'Turquie',
    flag: '🇹🇷',
    budgetComfortEur: 600,
    budgetMinimumEur: 450,
    primaryLanguage: PrimaryLang.en,
    acceptsEnglishPrograms: true,
    noteFr:
        'Programmes en anglais disponibles ; bourses Türkiye Burslari intéressantes.',
  ),
  EligibilityRule(
    countryId: 'are',
    nameFr: 'EAU (Dubaï)',
    flag: '🇦🇪',
    budgetComfortEur: 1300,
    budgetMinimumEur: 1000,
    primaryLanguage: PrimaryLang.en,
    noteFr:
        'Campus internationaux anglophones ; coût de la vie élevé, surtout à Dubaï.',
  ),
  EligibilityRule(
    countryId: 'gbr',
    nameFr: 'Royaume-Uni',
    flag: '🇬🇧',
    budgetComfortEur: 1350,
    budgetMinimumEur: 1050,
    primaryLanguage: PrimaryLang.en,
    noteFr:
        'IELTS exigé et preuve de fonds pour le visa étudiant (Student route).',
  ),
  EligibilityRule(
    countryId: 'esp',
    nameFr: 'Espagne',
    flag: '🇪🇸',
    budgetComfortEur: 850,
    budgetMinimumEur: 650,
    primaryLanguage: PrimaryLang.en,
    acceptsEnglishPrograms: true,
    noteFr:
        'Espagnol recommandé ; offre de programmes en anglais en forte hausse.',
  ),
  // Belgique francophone (12/11/2026) : preuve de moyens de 1 062 €/mois
  // exigée pour le visa D ; coût de la vie 1 000 – 1 300 €/mois (Study in
  // Belgium, WBI).
  EligibilityRule(
    countryId: 'bel',
    nameFr: 'Belgique',
    flag: '🇧🇪',
    budgetComfortEur: 1300,
    budgetMinimumEur: 1062,
    primaryLanguage: PrimaryLang.fr,
    noteFr:
        'Cours en français (B2 en général). Droits réduits à 1 194 €/an pour de nombreux pays d\'Afrique francophone.',
  ),
];

/// Outcome for a single country.
class EligibilityResult {
  const EligibilityResult({
    required this.rule,
    required this.verdict,
    required this.score,
    required this.reasons,
    required this.advice,
  });

  final EligibilityRule rule;
  final EligibilityVerdict verdict;

  /// 0–100, for the progress bar / sorting.
  final int score;
  final List<String> reasons;
  final String advice;

  String get verdictLabel {
    switch (verdict) {
      case EligibilityVerdict.eligible:
        return 'eligibility_summary_eligible'.tr;
      case EligibilityVerdict.eligibleWithConditions:
        return 'eligibility_verdict_conditions'.tr;
      case EligibilityVerdict.notEligible:
        return 'eligibility_verdict_not_eligible'.tr;
    }
  }

  String get verdictEmoji {
    switch (verdict) {
      case EligibilityVerdict.eligible:
        return '🟢';
      case EligibilityVerdict.eligibleWithConditions:
        return '🟡';
      case EligibilityVerdict.notEligible:
        return '🔴';
    }
  }
}

/// Pure scoring engine. No I/O, no Flutter — trivially unit-testable.
class EligibilityEngine {
  const EligibilityEngine();

  List<EligibilityResult> evaluate(EligibilityInput input) {
    final results =
        kEligibilityRules.map((rule) => _evaluateCountry(rule, input)).toList()
          // Best matches first.
          ..sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  EligibilityResult _evaluateCountry(
    EligibilityRule rule,
    EligibilityInput input,
  ) {
    final reasons = <String>[];

    // ── Budget (weight 2, points 0–2) ──────────────────────────────
    final budget = input.monthlyBudgetEur;
    final int budgetPoints;
    if (budget == null) {
      budgetPoints = 1;
      reasons.add(
          'Budget à confirmer (≈ ${rule.budgetComfortEur} €/mois recommandé).');
    } else if (budget >= rule.budgetComfortEur) {
      budgetPoints = 2;
      reasons.add(
          'Budget suffisant ($budget € ≥ ${rule.budgetComfortEur} €/mois).');
    } else if (budget >= rule.budgetMinimumEur) {
      budgetPoints = 1;
      reasons.add(
          'Budget serré ($budget €) : vise ${rule.budgetComfortEur} €/mois ou une bourse.');
    } else {
      budgetPoints = 0;
      reasons.add(
          'Budget insuffisant ($budget € < ${rule.budgetMinimumEur} €/mois minimum).');
    }

    // ── Language (weight 2, points 0–2) ────────────────────────────
    final langPoints = _languagePoints(rule, input, reasons);

    // ── Study level (weight 1, points 0–2) ─────────────────────────
    final int levelPoints;
    if ((input.studyLevel ?? '').trim().isEmpty) {
      levelPoints = 1;
      reasons.add('Renseigne ton niveau d\'études pour affiner.');
    } else {
      levelPoints = 2;
    }

    final raw = budgetPoints * 2 + langPoints * 2 + levelPoints; // 0–10
    final score = (raw * 10).clamp(0, 100);

    final EligibilityVerdict verdict;
    if (budgetPoints == 0 || langPoints == 0) {
      verdict = EligibilityVerdict.notEligible;
    } else if (raw >= 8) {
      verdict = EligibilityVerdict.eligible;
    } else {
      verdict = EligibilityVerdict.eligibleWithConditions;
    }

    return EligibilityResult(
      rule: rule,
      verdict: verdict,
      score: score,
      reasons: reasons,
      advice: _advice(verdict, rule),
    );
  }

  int _languagePoints(
    EligibilityRule rule,
    EligibilityInput input,
    List<String> reasons,
  ) {
    // Determine the best relevant language level for this country.
    LangLevel relevant;
    String langName;
    if (rule.bilingualFrEn) {
      relevant = input.frenchLevel.points >= input.englishLevel.points
          ? input.frenchLevel
          : input.englishLevel;
      langName = 'français ou anglais';
    } else if (rule.primaryLanguage == PrimaryLang.fr) {
      relevant = input.frenchLevel;
      langName = 'français';
      if (rule.acceptsEnglishPrograms &&
          input.englishLevel.points > relevant.points) {
        relevant = input.englishLevel;
        langName = 'anglais (programmes internationaux)';
      }
    } else {
      relevant = input.englishLevel;
      langName = 'anglais';
      if (rule.acceptsEnglishPrograms &&
          input.frenchLevel.points > relevant.points &&
          (rule.countryId == 'can')) {
        relevant = input.frenchLevel;
        langName = 'français';
      }
    }

    switch (relevant) {
      case LangLevel.bon:
        reasons.add('Niveau de $langName courant : atout fort.');
      case LangLevel.moyen:
        reasons.add(
            'Niveau de $langName intermédiaire : une remise à niveau aidera.');
      case LangLevel.faible:
        reasons.add(
            'Niveau de $langName trop faible : test de langue à préparer.');
    }
    return relevant.points;
  }

  String _advice(EligibilityVerdict verdict, EligibilityRule rule) {
    switch (verdict) {
      case EligibilityVerdict.eligible:
        return 'Tu peux démarrer un dossier dès maintenant. ${rule.noteFr}';
      case EligibilityVerdict.eligibleWithConditions:
        return 'Destination accessible en renforçant budget et/ou langue. ${rule.noteFr}';
      case EligibilityVerdict.notEligible:
        return 'Concentre-toi d\'abord sur le blocage principal. ${rule.noteFr}';
    }
  }

  // ── Per-country quiz scoring (KPB-62) ──────────────────────────────────────
  // Single source of truth for the explore per-country eligibility quiz, ported
  // verbatim from the former backend `country-quiz.scorer.ts` so the quiz and
  // the simulator share ONE deterministic engine (no divergent backend scorer).
  EligibilityVerdict scoreCountryQuiz(
    String countryId,
    Map<String, String> answers,
  ) =>
      eligibilityVerdictFromKey(_scoreQuizKey(countryId, answers));

  String _scoreQuizKey(String countryId, Map<String, String> a) {
    switch (countryId) {
      case 'fra':
        return _scoreFrance(a);
      case 'deu':
        return _scoreGermany(a);
      case 'usa':
        return _scoreUsa(a);
      case 'can':
        return _scoreCanada(a);
      case 'mar':
        return _scoreMorocco(a);
      case 'tur':
        return _scoreTurkey(a);
      case 'are':
        return _scoreUae(a);
      case 'gbr':
        return _scoreUk(a);
      case 'esp':
        return _scoreSpain(a);
      case 'bel':
        return _scoreBelgium(a);
      default:
        return 'eligible_with_conditions';
    }
  }

  String _scoreFrance(Map<String, String> a) {
    final diploma = _qp(a, 'q2_diploma');
    final french = _qp(a, 'q5_french_level');
    final funds = _qp(a, 'q7_financial_proof');
    final visa = _qp(a, 'q6_visa_history');
    if (diploma == 'no') return 'not_eligible';
    if (french == 'basic' && funds == 'no') return 'not_eligible';
    if (_qin(diploma, const ['yes_obtained', 'yes_this_year']) &&
        _qin(french, const ['native', 'fluent', 'intermediate']) &&
        funds != 'no' &&
        visa != 'yes_recent') {
      return 'eligible';
    }
    if (_qin(diploma, const ['yes_obtained', 'yes_this_year']) &&
        (french == 'basic' || funds == 'no' || visa == 'yes_recent')) {
      return 'eligible_with_conditions';
    }
    return 'eligible_with_conditions';
  }

  /// Belgique francophone (quiz `bel` de m5-countries.seed.ts) : diplôme,
  /// français (cours en français, B2 en général) et preuve de moyens de
  /// 1 062 €/mois exigée pour le visa D.
  String _scoreBelgium(Map<String, String> a) {
    final diploma = _qp(a, 'q2_diploma');
    final french = _qp(a, 'q3_french_level');
    final means = _qp(a, 'q4_means');
    if (diploma == 'no') return 'not_eligible';
    if (french == 'basic' && means == 'no') return 'not_eligible';
    if (_qin(diploma, const ['yes_obtained', 'yes_this_year']) &&
        _qin(french, const ['native', 'b2']) &&
        means == 'yes_easily') {
      return 'eligible';
    }
    return 'eligible_with_conditions';
  }

  String _scoreGermany(Map<String, String> a) {
    final german = _qp(a, 'q2_german_level');
    final track = _qp(a, 'q4_language_track');
    final blocked = _qp(a, 'q5_blocked_account');
    if (blocked == 'no' && track == 'no_only_english') return 'not_eligible';
    if (blocked == 'no') return 'not_eligible';
    if (track == 'yes_partial' && blocked == 'yes_difficult') {
      return 'eligible_with_conditions';
    }
    if (german == 'advanced' || (track != null && track != 'no_only_english')) {
      return 'eligible';
    }
    return 'eligible_with_conditions';
  }

  String _scoreUsa(Map<String, String> a) {
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    final diploma = _qp(a, 'q2_diploma');
    if (diploma == 'no') return 'not_eligible';
    if (budget == 'low') return 'not_eligible';
    if (english == 'advanced' && budget != 'low') return 'eligible';
    if (english == 'intermediate' || budget == 'medium') {
      return 'eligible_with_conditions';
    }
    return 'eligible_with_conditions';
  }

  String _scoreCanada(Map<String, String> a) {
    final diploma = _qp(a, 'q2_diploma');
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    if (diploma == 'no') return 'not_eligible';
    if (budget == 'low') return 'not_eligible';
    if (_qin(diploma, const ['yes_obtained', 'yes_this_year']) &&
        _qin(english, const ['advanced', 'intermediate']) &&
        budget != 'low') {
      return 'eligible';
    }
    return 'eligible_with_conditions';
  }

  String _scoreMorocco(Map<String, String> a) {
    final diploma = _qp(a, 'q2_diploma');
    final french = _qp(a, 'q3_french_level');
    final budget = _qp(a, 'q4_budget');
    if (diploma == 'no' && budget == 'low') return 'not_eligible';
    if (_qin(diploma, const ['yes_obtained', 'yes_this_year']) &&
        _qin(french, const ['native', 'fluent', 'intermediate'])) {
      return 'eligible';
    }
    if (french == 'basic' || budget == 'low') {
      return 'eligible_with_conditions';
    }
    return 'eligible_with_conditions';
  }

  String _scoreTurkey(Map<String, String> a) {
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    final diploma = _qp(a, 'q2_diploma');
    if (diploma == 'no') return 'not_eligible';
    if (budget == 'low') return 'eligible_with_conditions';
    if (_qin(english, const ['advanced', 'intermediate']) && budget != 'low') {
      return 'eligible';
    }
    return 'eligible_with_conditions';
  }

  String _scoreUae(Map<String, String> a) {
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    if (budget == 'low') return 'not_eligible';
    if (english == 'advanced' && budget != 'low') return 'eligible';
    return 'eligible_with_conditions';
  }

  String _scoreUk(Map<String, String> a) {
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    final diploma = _qp(a, 'q2_diploma');
    if (diploma == 'no') return 'not_eligible';
    if (budget == 'low') return 'not_eligible';
    if (english == 'advanced') return 'eligible';
    return 'eligible_with_conditions';
  }

  String _scoreSpain(Map<String, String> a) {
    final english = _qp(a, 'q3_english_level');
    final budget = _qp(a, 'q4_budget');
    final diploma = _qp(a, 'q2_diploma');
    if (diploma == 'no') return 'not_eligible';
    if (_qin(english, const ['advanced', 'intermediate']) && budget != 'low') {
      return 'eligible';
    }
    if (budget == 'low' || english == 'basic') {
      return 'eligible_with_conditions';
    }
    return 'eligible_with_conditions';
  }
}

// Quiz answer helpers (mirror the former backend scorer's pick/inValues).
String? _qp(Map<String, String> a, String key) {
  final v = a[key]?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

bool _qin(String? value, List<String> allowed) =>
    value != null && allowed.contains(value);
