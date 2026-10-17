import '../controllers/app_controller.dart';
import '../models/app_models.dart';
import '../utils/study_level.dart';
import '../utils/tuition_reading.dart';

/// M6 filter criteria for the university program catalog.
class ProgramFilterState {
  const ProgramFilterState({
    this.query = '',
    this.countryId,
    this.budgetMaxEur = 30000,
    this.levelKey,
    this.fieldId,
    this.languageKey,
    this.partnerOnly = true,
  });

  final String query;
  final String? countryId;
  final double budgetMaxEur;
  final String? levelKey;
  final String? fieldId;
  final String? languageKey;
  final bool partnerOnly;

  ProgramFilterState copyWith({
    String? query,
    String? countryId,
    bool clearCountryId = false,
    double? budgetMaxEur,
    String? levelKey,
    bool clearLevelKey = false,
    String? fieldId,
    bool clearFieldId = false,
    String? languageKey,
    bool clearLanguageKey = false,
    bool? partnerOnly,
  }) {
    return ProgramFilterState(
      query: query ?? this.query,
      countryId: clearCountryId ? null : (countryId ?? this.countryId),
      budgetMaxEur: budgetMaxEur ?? this.budgetMaxEur,
      levelKey: clearLevelKey ? null : (levelKey ?? this.levelKey),
      fieldId: clearFieldId ? null : (fieldId ?? this.fieldId),
      languageKey: clearLanguageKey ? null : (languageKey ?? this.languageKey),
      partnerOnly: partnerOnly ?? this.partnerOnly,
    );
  }

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      countryId != null ||
      budgetMaxEur < 30000 ||
      levelKey != null ||
      fieldId != null ||
      languageKey != null;
}

const programLevelFilters = <({String key, String labelFr})>[
  (key: 'bachelor', labelFr: 'Bachelor'),
  (key: 'master', labelFr: 'Master'),
  (key: 'mba', labelFr: 'MBA / DBA'),
  (key: 'doctorate', labelFr: 'Doctorat'),
  (key: 'college', labelFr: 'Collège'),
  (key: 'other', labelFr: 'Autre'),
];

const programLanguageFilters = <({String key, String labelFr})>[
  (key: 'fr', labelFr: 'Français'),
  (key: 'en', labelFr: 'Anglais'),
  (key: 'de', labelFr: 'Allemand'),
  (key: 'es', labelFr: 'Espagnol'),
  (key: 'tr', labelFr: 'Turc'),
  (key: 'ar', labelFr: 'Arabe'),
];

/// Taux INDICATIFS, en euros par unité — relevés le 14/08/2026.
///
/// ## Réservés à la COMPARAISON. Jamais affichés.
///
/// C'est la distinction qui tient tout ce fichier. « Ce programme est-il sous mon
/// budget ? » tolère quelques pour cent d'erreur ; « ce programme coûte X » n'en
/// tolère aucun. Alors le filtre a le droit d'approximer, et l'affichage ne
/// convertit que sur des parités FIXES (`TuitionUtils`, qui ne connaît que
/// l'euro et le franc CFA).
///
/// Deux garde-fous rendent cette promesse vérifiable plutôt que déclarative :
/// `TuitionUtils` n'a structurellement pas accès à cette table, et
/// `test/core/services/program_filter_service_test.dart` affirme qu'aucun de ces
/// nombres ne peut apparaître dans une chaîne rendue.
///
/// La dérive est bornée par [_budgetTolerance] : même si un taux vieillit de
/// 20 %, aucune formation abordable ne peut être RECACHÉE par le curseur.
const _indicativeEurPerUnit = <TuitionCurrency, double>{
  TuitionCurrency.eur: 1.0,
  // Parité fixe BCEAO : celle-ci n'est pas indicative, elle est exacte.
  TuitionCurrency.xof: 1 / 655.957,
  TuitionCurrency.mad: 0.0930, // 1 € ≈ 10,75 MAD
  TuitionCurrency.aed: 0.2350, // 1 € ≈ 4,26 AED
  TuitionCurrency.cad: 0.6750, // 1 € ≈ 1,48 CAD
  TuitionCurrency.gbp: 1.1700, // 1 € ≈ 0,855 GBP
  TuitionCurrency.usd: 0.9260, // 1 € ≈ 1,08 USD
  TuitionCurrency.cny: 0.1280, // 1 € ≈ 7,81 CNY
};

/// Marge accordée à l'utilisateur sur son propre plafond.
///
/// Le curseur dit « moins de 30 000 € » ; on garde jusqu'à 36 000 € d'équivalent
/// estimé. Le sens de la marge est délibéré : une erreur de taux doit pouvoir
/// faire apparaître une formation légèrement au-dessus du budget, jamais
/// disparaître une formation en dessous. C'est le défaut qu'on vient de corriger,
/// et on ne veut pas le reproduire par arrondi.
const _budgetTolerance = 1.2;

abstract final class ProgramFilterService {
  static List<ProgramModel> apply(
    List<ProgramModel> programs,
    ProgramFilterState filters,
    AppController controller,
  ) {
    final query = filters.query.trim().toLowerCase();

    final filtered = programs.where((program) {
      final institution =
          controller.institutionByIdOrNull(program.institutionId);
      final isPartner = institution?.isPartner ?? false;

      if (filters.partnerOnly && !isPartner) return false;

      if (filters.countryId != null &&
          program.countryId.toLowerCase() != filters.countryId!.toLowerCase()) {
        return false;
      }

      if (filters.fieldId != null && program.fieldId != filters.fieldId) {
        return false;
      }

      if (filters.levelKey != null &&
          !_matchesLevel(
            filters.levelKey!,
            controller.resolve(program.level),
          )) {
        return false;
      }

      if (filters.languageKey != null &&
          !_matchesLanguage(
            filters.languageKey!,
            controller.resolve(program.language),
          )) {
        return false;
      }

      // Le budget se compare en euros, après lecture de la devise RÉELLEMENT
      // écrite dans l'étiquette. Avant, le premier nombre était traité comme des
      // euros : 40 000 dirhams étaient comparés à un budget de 30 000 €, donc
      // les 50 programmes marocains disparaissaient de la vue par défaut — ceux
      // qui coûtent en réalité ~3 700 €, parmi les moins chers du catalogue.
      final comparable = _comparableEur(controller.resolve(program.tuition));
      // Devise inconnue ou montant illisible : on GARDE. On ne filtre pas sur
      // une donnée qu'on ne sait pas lire — la cacher serait décider à la place
      // de l'étudiant, sur la base d'un aveu d'ignorance.
      if (comparable != null &&
          comparable > filters.budgetMaxEur * _budgetTolerance) {
        return false;
      }

      if (query.isEmpty) return true;
      final haystack = [
        controller.resolve(program.name),
        controller.resolve(program.level),
        institution != null ? controller.resolve(institution.name) : '',
        program.fieldId,
        program.countryId,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      bool isPartner(ProgramModel p) =>
          controller.institutionByIdOrNull(p.institutionId)?.isPartner ?? false;

      final partnerCmp = (isPartner(a) ? 0 : 1).compareTo(isPartner(b) ? 0 : 1);
      if (partnerCmp != 0) return partnerCmp;

      // « Prix inconnu en dernier », sans nombre magique. La sentinelle
      // `?? 999999` d'avant était un prix : un programme à 1 200 000 XOF lu comme
      // 1 200 000 « euros » passait DERRIÈRE elle, et un vrai programme à plus de
      // 999 999 € s'y serait mélangé. Un ordre n'a pas besoin d'un montant
      // inventé pour exister.
      final tuitionA = _comparableEur(controller.resolve(a.tuition));
      final tuitionB = _comparableEur(controller.resolve(b.tuition));
      if (tuitionA == null && tuitionB != null) return 1;
      if (tuitionA != null && tuitionB == null) return -1;
      if (tuitionA != null && tuitionB != null) {
        final budgetCmp = tuitionA.compareTo(tuitionB);
        if (budgetCmp != 0) return budgetCmp;
      }

      return controller
          .resolve(a.name)
          .toLowerCase()
          .compareTo(controller.resolve(b.name).toLowerCase());
    });

    return filtered;
  }

  /// Le montant de [label] ramené en euros pour être COMPARÉ, ou `null` si
  /// l'étiquette est illisible ou libellée dans une devise qu'on ne sait pas
  /// rapprocher de l'euro.
  ///
  /// Une fourchette est comparée sur sa borne BASSE : « ce programme commence à
  /// combien ? » est la question que pose un curseur de budget.
  static double? _comparableEur(String label) {
    final reading = readTuition(label);
    if (reading == null) return null;
    final rate = _indicativeEurPerUnit[reading.currency];
    if (rate == null) return null;
    return reading.amount * rate;
  }

  /// Matches the selected filter family against the program's level using the
  /// canonical normalizer (single source of truth in `study_level.dart`).
  static bool _matchesLevel(String key, String levelText) {
    return normalizeProgramLevel(levelText).filterKey == key;
  }

  static bool _matchesLanguage(String key, String languageText) {
    final normalized = languageText.toLowerCase();
    switch (key) {
      case 'fr':
        return normalized.contains('fr') ||
            normalized.contains('français') ||
            normalized.contains('french');
      case 'en':
        return normalized.contains('en') ||
            normalized.contains('anglais') ||
            normalized.contains('english');
      case 'de':
        return normalized.contains('de') ||
            normalized.contains('allemand') ||
            normalized.contains('german');
      case 'es':
        return normalized.contains('es') ||
            normalized.contains('espagnol') ||
            normalized.contains('spanish');
      case 'tr':
        return normalized.contains('tr') ||
            normalized.contains('turc') ||
            normalized.contains('turkish');
      case 'ar':
        return normalized.contains('ar') ||
            normalized.contains('arabe') ||
            normalized.contains('arabic');
      default:
        return true;
    }
  }
}
