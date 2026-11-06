import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/currency_utils.dart';
import '../legal/legal_pages.dart';
import '../matches/aha_moment_screen.dart';
import 'onboarding_m2_constants.dart';
import 'onboarding_referral_step.dart';

part 'onboarding_screen/chrome.dart';
part 'onboarding_screen/pages.dart';
part 'onboarding_screen/fields.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).
// L'ancienne _Palette locale (App-engagement handoff) a été absorbée par les
// tokens au lot 3 ; red/green/amberSoft ont été normalisés sur les rôles
// sémantiques AA (error/success/warningLight).
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Dial codes
// ─────────────────────────────────────────────────────────────────────────────
class _DialCode {
  const _DialCode(this.flag, this.code, this.country);

  /// [code] est un INDICATIF, rien d'autre : il est concaténé tel quel dans
  /// `profile.phone` et `profile.whatsApp`, que le backend accepte sans
  /// validation de format. L'entrée États-Unis portait `'+1 🇺🇸'` — un
  /// bricolage pour la distinguer du `+1` canadien dans le menu — et chaque
  /// numéro américain était enregistré « +1 🇺🇸 5551234567 », emoji compris,
  /// dans les deux champs. Un numéro corrompu ne se compose pas et ne s'ouvre
  /// pas dans WhatsApp. La désambiguïsation vit dans [label], qui n'est
  /// jamais persisté ; un test l'exige (onboarding_phone_code_test.dart).
  final String flag, code, country;
  String get label => '$flag $code · $country';
}

const _dialCodes = <_DialCode>[
  _DialCode('🇳🇪', '+227', 'Niger'),
  _DialCode('🇳🇬', '+234', 'Nigeria'),
  _DialCode('🇸🇳', '+221', 'Sénégal'),
  _DialCode('🇨🇮', '+225', 'Côte d\'Ivoire'),
  _DialCode('🇲🇱', '+223', 'Mali'),
  _DialCode('🇬🇳', '+224', 'Guinée'),
  _DialCode('🇧🇫', '+226', 'Burkina Faso'),
  _DialCode('🇹🇬', '+228', 'Togo'),
  _DialCode('🇧🇯', '+229', 'Bénin'),
  _DialCode('🇲🇷', '+222', 'Mauritanie'),
  _DialCode('🇬🇭', '+233', 'Ghana'),
  _DialCode('🇨🇲', '+237', 'Cameroun'),
  _DialCode('🇸🇱', '+232', 'Sierra Leone'),
  _DialCode('🇬🇲', '+220', 'Gambie'),
  _DialCode('🇱🇷', '+231', 'Liberia'),
  _DialCode('🇬🇼', '+245', 'Guinée-Bissau'),
  _DialCode('🇨🇻', '+238', 'Cap-Vert'),
  // Afrique centrale, de l'Est et du Nord : ils manquaient, et le public de
  // l'app y est (audit build 57, T1-10). Ajoutés APRÈS le Niger : l'indicatif
  // par défaut (`_dialCodes[0]`) ne change pas.
  _DialCode('🇨🇩', '+243', 'RD Congo'),
  _DialCode('🇨🇬', '+242', 'Congo'),
  _DialCode('🇬🇦', '+241', 'Gabon'),
  _DialCode('🇹🇩', '+235', 'Tchad'),
  _DialCode('🇨🇫', '+236', 'Centrafrique'),
  _DialCode('🇲🇬', '+261', 'Madagascar'),
  _DialCode('🇷🇼', '+250', 'Rwanda'),
  _DialCode('🇧🇮', '+257', 'Burundi'),
  _DialCode('🇩🇯', '+253', 'Djibouti'),
  _DialCode('🇰🇲', '+269', 'Comores'),
  _DialCode('🇹🇳', '+216', 'Tunisie'),
  _DialCode('🇩🇿', '+213', 'Algérie'),
  _DialCode('🇫🇷', '+33', 'France'),
  _DialCode('🇨🇦', '+1', 'Canada'),
  _DialCode('🇬🇧', '+44', 'Royaume-Uni'),
  _DialCode('🇩🇪', '+49', 'Allemagne'),
  _DialCode('🇲🇦', '+212', 'Maroc'),
  _DialCode('🇹🇷', '+90', 'Turquie'),
  _DialCode('🇪🇸', '+34', 'Espagne'),
  _DialCode('🇺🇸', '+1', 'États-Unis'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────
const _studyLevels = [
  ('High school', 'Lycée'),
  ('Bachelor', 'Licence'),
  ('Master', 'Master'),
  ('PhD', 'Doctorat'),
];
// Ces quatre listes vivent maintenant dans onboarding_m2_constants.dart, pour
// que l'écran de profil puisse ouvrir les mêmes champs à l'édition sans en
// recopier les valeurs. Les alias gardent le corps de ce fichier inchangé.
const _targetLevels = onboardingTargetLevels;
const _langLevels = onboardingLanguageLevels;
const _grades = onboardingGradeRanges;
const _budgetRanges = onboardingBudgetRanges;
const _documentKeys = [
  ('Passport', 'Passeport'),
  ('CV', 'CV'),
  ('Transcripts', 'Relevés de notes'),
  ('Test score', 'Score de test'),
];
const _countries = [
  'Niger',
  'Nigeria',
  'Sénégal',
  'Côte d\'Ivoire',
  'Mali',
  'Guinée',
  'Burkina Faso',
  'Togo',
  'Bénin',
  'Mauritanie',
  'Ghana',
  'Cameroun',
  'Sierra Leone',
  'Gambie',
  'Liberia',
  'Guinée-Bissau',
  'Cap-Vert',
  'RD Congo',
  'Congo',
  'Gabon',
  'Tchad',
  'Centrafrique',
  'Madagascar',
  'Rwanda',
  'Burundi',
  'Djibouti',
  'Comores',
  'Maroc',
  'Tunisie',
  'Algérie',
  'France',
  'Belgique',
  'Suisse',
  'Canada',
  'Autre',
];

// Localizes a dropdown/chip option by its stable value token (e.$1) so the
// visible label follows the active locale instead of always showing French.
String _optionLabel(String token) {
  const keys = {
    'High school': 'level_high_school',
    'Bachelor': 'level_bachelor',
    'Master': 'level_master',
    'PhD': 'level_phd',
    'Beginner': 'lang_beginner',
    'Intermediate': 'lang_intermediate',
    'Advanced': 'lang_advanced',
    'Passport': 'doc_passport',
    'CV': 'doc_cv',
    'Transcripts': 'doc_transcripts',
    'Test score': 'doc_test_score',
  };
  final key = keys[token];
  return key != null ? key.tr : token;
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen — Stepper paginé (light-premium)
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _page = 0;

  // Form keys per page
  final _key0 = GlobalKey<FormState>();
  final _key1 = GlobalKey<FormState>();
  // Clé STABLE : une `GlobalKey()` créée dans build() recréait le Form et sa
  // ListView à chaque setState, et la page remontait en haut à chaque puce.
  final _key2 = GlobalKey<FormState>();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsAppCtrl = TextEditingController();

  /// Onboarding « la valeur d'abord » (`features.onboardingV2`), lu UNE fois
  /// à l'ouverture : un rafraîchissement des drapeaux en cours de saisie ne
  /// change pas le formulaire sous les doigts de l'élève. Fermé : l'ancien
  /// parcours, inchangé.
  late final bool _v2;

  /// Étape facultative « code de ton parrain » après la synchro du profil
  /// (`features.referralOnboardingCode`, build 57), lue UNE fois à l'ouverture
  /// comme [_v2]. Indépendante de [_v2] : elle suit les deux parcours.
  late final bool _referralStep;

  // State
  AccountType _accountType = AccountType.student;
  String _language = 'fr';
  // Nuls tant que l'élève n'a pas choisi (parcours V2). L'ancien parcours les
  // pré-remplit dans [initState] avec ses valeurs historiques : des choix
  // jamais faits partaient tels quels dans le profil (Niger, Lycée → Licence,
  // anglais intermédiaire, 12-14/20) et biaisaient le matching.
  String? _country;
  String? _currentLevel;
  String? _targetLevel;
  String? _languageLevel;
  String? _gradeRange;
  int? _annualTuitionBudgetEur;
  String _preferredCurrency = DisplayCurrency.xof.code;
  bool _wantsScholarship = true;
  // Newsletter opt-in: UNCHECKED by default — GDPR requires an explicit,
  // freely given consent (audience includes 16-18 year olds).
  bool _wantsNewsletter = false;
  bool _sameWhatsApp = true;
  _DialCode _phoneCode = _dialCodes[0];
  _DialCode _waCode = _dialCodes[0];
  // Vides par défaut : des choix pré-cochés (informatique, commerce, Canada,
  // France…) partaient tels quels dans le profil et biaisaient le matching et
  // les filtres de bourses. La page exige au moins une filière et un pays.
  final Set<String> _fieldIds = {};
  final Set<String> _countryIds = {};
  final Set<String> _docs = {};
  bool _hasConsented = false;

  /// Vrai dès qu'un « Continuer » a échoué sur la page. Avant : les erreurs
  /// restent cachées (on ne gronde pas un formulaire vide) ; après : chaque
  /// champ se revalide à la frappe, et les sections hors formulaire
  /// (naissance, tuteur, consentement) affichent leur erreur EN PLACE.
  ///
  /// Le bouton qui « ne faisait rien » — erreur hors de l'écran, simple bandeau
  /// posé SUR le bouton — était l'écran le plus rage-cliqué de l'app : 253
  /// comptes, 13 % de ceux qui voyaient l'étape 1 (PostHog, octobre 2026).
  final Set<int> _attemptedPages = {};

  // Les sections de l'étape 1 qui ne sont pas des champs de formulaire : on y
  // fait défiler la page quand ce sont elles qui bloquent.
  final _birthDateKey = GlobalKey();
  final _guardianKey = GlobalKey();
  final _consentKey = GlobalKey();
  // Étape 3 (V2) : les deux groupes de puces obligatoires, pour y faire
  // défiler la page quand ce sont eux qui bloquent.
  final _fieldsKey = GlobalKey();
  final _countriesKey = GlobalKey();

  // Age gate + self-attested guardian consent for declared minors (<18).
  DateTime? _birthDate;
  final _guardianNameCtrl = TextEditingController();
  final _guardianContactCtrl = TextEditingController();
  bool _guardianConsented = false;

  int? get _age {
    final b = _birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years;
  }

  /// Declared minor. False when no birth date is set — we never assume.
  bool get _isMinor => (_age ?? 99) < 18;

  /// Plancher des CGU : 16 ans révolus. Distinct du tuteur (< 18).
  bool get _isUnderMinimumAge {
    final age = _age;
    return age != null && age < 16;
  }

  /// Snap an arbitrary persisted budget to the nearest selectable range value
  /// so the dropdown never asserts on an off-grid value.
  int? _snapBudget(int? raw) {
    if (raw == null || raw <= 0) return null;
    var best = _budgetRanges.first.$1;
    var bestDiff = (best - raw).abs();
    for (final r in _budgetRanges) {
      final d = (r.$1 - raw).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = r.$1;
      }
    }
    return best;
  }

  AppController get _ctrl => Get.find<AppController>();

  int get _totalPages => _accountType == AccountType.partner ? 2 : 3;

  @override
  void initState() {
    super.initState();
    _v2 = RemoteFeatureFlags.instance.onboardingV2Enabled;
    _referralStep = RemoteFeatureFlags.instance.referralOnboardingCodeEnabled;
    if (!_v2) {
      // Ancien parcours (drapeau fermé) : ses valeurs par défaut historiques,
      // à l'identique.
      _country = 'Niger';
      _currentLevel = 'High school';
      _targetLevel = 'Bachelor';
      _languageLevel = 'Intermediate';
      _gradeRange = '12 - 14/20';
    }
    _restoreFromProfile();
    // For a freshly-authenticated user with no persisted profile yet, seed the
    // email (and name, when the OAuth provider supplied it) from the Supabase
    // session so onboarding never re-asks for the identity just signed in with.
    _prefillFromAuthSession();
    _page = _ctrl.onboardingStep.clamp(0, _totalPages - 1);
    _pageController = PageController(initialPage: _page);
    _logStepViewed(_page);
  }

  /// KPB-158 onboarding funnel: 1-based step, total step count, and account
  /// type, so drop-off between pages is visible in PostHog.
  void _logStepViewed(int page) {
    AnalyticsService.instance.logOnboardingStepViewed(
      step: page + 1,
      stepCount: _totalPages,
      accountType: _accountType.name,
    );
  }

  void _skip() {
    // V2 : « Passer » existe dès la page 1, donc avant le contrôle de l'âge.
    // Il ne contourne pas le plancher des CGU : une date de moins de 16 ans
    // déjà saisie (ou restaurée) bloque, avec l'erreur dans le champ.
    if (_v2 && _accountType == AccountType.student && _isUnderMinimumAge) {
      if (_page != 0) _pageController.jumpToPage(0);
      // Pas `markAttempted` : un « Passer » refusé n'allume pas les erreurs
      // des AUTRES champs (consentement, téléphone) — seule celle de l'âge,
      // déjà visible dans son champ en V2, est en cause.
      _onPageInvalid(
        0,
        'under_minimum_age',
        _key0,
        section: _birthDateKey,
        markAttempted: false,
      );
      return;
    }
    AnalyticsService.instance.logOnboardingSkipped(step: _page + 1);
    _ctrl.skipOnboarding(ageDeclaration: _v2 ? _ageDeclaration() : null);
  }

  /// L'âge et l'accord du tuteur déjà saisis, conservés par « Passer » (V2).
  /// Null quand rien n'a été déclaré ou que le compte n'est pas élève.
  OnboardingAgeDeclaration? _ageDeclaration() {
    if (_accountType != AccountType.student || _birthDate == null) return null;
    final guardianName = _guardianNameCtrl.text.trim();
    final guardianContact = _guardianContactCtrl.text.trim();
    final guardianComplete = _isMinor &&
        _guardianConsented &&
        guardianName.isNotEmpty &&
        guardianContact.isNotEmpty;
    return OnboardingAgeDeclaration(
      birthDate: _birthDate,
      guardianName: guardianComplete ? guardianName : null,
      guardianContact: guardianComplete ? guardianContact : null,
      guardianConsented: guardianComplete,
    );
  }

  /// Fills email/name from the current Supabase session, but only where the
  /// form is still empty — never overrides a value restored from a profile.
  void _prefillFromAuthSession() {
    if (!Get.isRegistered<AuthService>()) return;
    final auth = Get.find<AuthService>();

    if (_emailCtrl.text.trim().isEmpty && auth.sessionEmail != null) {
      _emailCtrl.text = auth.sessionEmail!;
    }

    final name = auth.sessionFullName;
    if (name != null &&
        _firstNameCtrl.text.trim().isEmpty &&
        _lastNameCtrl.text.trim().isEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
  }

  /// Rehydrate the form from any persisted (partial) profile so a user who
  /// left mid-onboarding resumes where they stopped.
  void _restoreFromProfile() {
    _language = kShippedLocale;
    final profile = _ctrl.profile;
    if (profile == null) return;

    _accountType = profile.accountType;
    if (kLanguageSwitchVisible && profile.preferredLanguage.isNotEmpty) {
      _language = profile.preferredLanguage;
    }
    // Only restore dropdown-backed values when they exist in the current
    // option lists — a value persisted by an earlier onboarding flow that is
    // absent here would crash DropdownButtonFormField.
    if (_countries.contains(profile.countryOfResidence)) {
      _country = profile.countryOfResidence;
    }
    if (_studyLevels.any((e) => e.$1 == profile.currentLevel)) {
      _currentLevel = profile.currentLevel!;
    }
    if (_targetLevels.any((e) => e.$1 == profile.targetLevel)) {
      _targetLevel = profile.targetLevel!;
    }
    if (_langLevels.any((e) => e.$1 == profile.languageLevel)) {
      _languageLevel = profile.languageLevel!;
    }
    if (_grades.contains(profile.gradeRange)) {
      _gradeRange = profile.gradeRange!;
    }
    _annualTuitionBudgetEur = _snapBudget(
      profile.annualTuitionBudgetEur ??
          ((profile.monthlyBudgetEur ?? 0) > 0
              ? profile.monthlyBudgetEur! * 12
              : null),
    );
    _preferredCurrency =
        DisplayCurrency.fromCode(profile.preferredCurrency).code;
    _wantsScholarship = profile.wantsScholarshipSupport;
    _wantsNewsletter = profile.wantsScholarshipNewsletter;
    if (profile.fieldIds.isNotEmpty) {
      _fieldIds
        ..clear()
        ..addAll(profile.fieldIds);
    }
    if (profile.targetCountryIds.isNotEmpty) {
      _countryIds
        ..clear()
        ..addAll(profile.targetCountryIds);
    }
    if (profile.availableDocuments.isNotEmpty) {
      _docs
        ..clear()
        ..addAll(profile.availableDocuments);
    }

    // Names / contact come back as composite strings — best-effort rehydrate.
    final parts = profile.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
    _emailCtrl.text = profile.email;
    if (profile.consentedAt != null) {
      _hasConsented = true;
    }
    _birthDate = profile.birthDate;
    if (profile.guardianName != null) {
      _guardianNameCtrl.text = profile.guardianName!;
    }
    if (profile.guardianContact != null) {
      _guardianContactCtrl.text = profile.guardianContact!;
    }
    if (profile.guardianConsentedAt != null) {
      _guardianConsented = true;
    }
  }

  /// Choisir le pays règle l'indicatif du téléphone (et du WhatsApp), tant que
  /// le numéro n'est pas saisi : le pays et l'indicatif étaient indépendants,
  /// donc un élève du Gabon voyait « +227 » (audit build 57, T1-10). Un numéro
  /// déjà tapé n'est jamais réinterprété.
  void _onCountryPicked(String? value) {
    setState(() {
      _country = value ?? _country;
      final match = _dialCodes.where((d) => d.country == value);
      if (match.isEmpty) return;
      if (_phoneCtrl.text.trim().isEmpty) _phoneCode = match.first;
      if (_whatsAppCtrl.text.trim().isEmpty) _waCode = match.first;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsAppCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianContactCtrl.dispose();
    super.dispose();
  }

  /// Builds the (possibly partial) profile from current form state.
  /// Shared by progress persistence and final submit so a resumed session
  /// keeps the same stable id.
  UserProfile _buildProfile() {
    final existing = _ctrl.profile;
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final isPartner = _accountType == AccountType.partner;
    final phone = _phoneCtrl.text.trim().isEmpty
        ? (existing?.phone ?? '')
        : '${_phoneCode.code} ${_phoneCtrl.text.trim()}';
    final whatsApp = _sameWhatsApp
        ? phone
        : (_whatsAppCtrl.text.trim().isEmpty
            ? (existing?.whatsApp ?? '')
            : '${_waCode.code} ${_whatsAppCtrl.text.trim()}');

    return UserProfile(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: _accountType,
      fullName: '$firstName $lastName'.trim(),
      email: _emailCtrl.text.trim(),
      phone: phone,
      whatsApp: whatsApp,
      countryOfResidence: _country ?? '',
      preferredLanguage: _language,
      currentLevel: isPartner ? null : _currentLevel,
      targetLevel: isPartner ? null : _targetLevel,
      languageLevel: isPartner ? null : _languageLevel,
      fieldIds: isPartner ? const [] : _fieldIds.toList(),
      targetCountryIds: isPartner ? const [] : _countryIds.toList(),
      gradeRange: isPartner ? null : _gradeRange,
      annualTuitionBudgetEur: isPartner ? null : _annualTuitionBudgetEur,
      preferredCurrency: _preferredCurrency,
      wantsScholarshipSupport:
          _accountType == AccountType.student && _wantsScholarship,
      wantsScholarshipNewsletter:
          _accountType == AccountType.student && _wantsNewsletter,
      availableDocuments: isPartner ? const [] : _docs.toList(),
      consentedAt:
          _hasConsented ? (existing?.consentedAt ?? DateTime.now()) : null,
      birthDate: _birthDate,
      guardianName: _isMinor && _guardianNameCtrl.text.trim().isNotEmpty
          ? _guardianNameCtrl.text.trim()
          : null,
      guardianContact: _isMinor && _guardianContactCtrl.text.trim().isNotEmpty
          ? _guardianContactCtrl.text.trim()
          : null,
      guardianConsentedAt: _isMinor && _guardianConsented
          ? (existing?.guardianConsentedAt ?? DateTime.now())
          : null,
    );
  }

  void _next() {
    final valid = switch (_page) {
      0 => _validateIdentityPage(),
      1 => () {
          final ok = _key1.currentState?.validate() ?? false;
          if (!ok) _onPageInvalid(1, 'required_fields', _key1);
          return ok;
        }(),
      2 when _v2 => _validateInterestsPage(),
      2 => () {
          if (_fieldIds.isEmpty) {
            _logValidationFailed(2, 'fields_missing');
            KpbToast.info(
              'onboarding_select_field_body'.tr,
              title: 'onboarding_selection_required_title'.tr,
            );
            return false;
          }
          if (_countryIds.isEmpty) {
            _logValidationFailed(2, 'countries_missing');
            KpbToast.info(
              'onboarding_select_country_body'.tr,
              title: 'onboarding_selection_required_title'.tr,
            );
            return false;
          }
          return true;
        }(),
      _ => true,
    };
    if (!valid) return;
    KpbHaptics.confirm();
    if (_page < _totalPages - 1) {
      final nextPage = _page + 1;
      // Persist progress so the user can resume mid-onboarding.
      _ctrl.saveOnboardingProgress(nextPage, _buildProfile());
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  /// V2 : l'étape 3 dit ce qui manque SOUS le groupe de puces concerné, et y
  /// fait défiler la page — plus de toast générique.
  bool _validateInterestsPage() {
    final issue = _fieldIds.isEmpty
        ? 'fields_missing'
        : _countryIds.isEmpty
            ? 'countries_missing'
            : null;
    if (issue == null) return true;
    _onPageInvalid(
      2,
      issue,
      _key2,
      section: issue == 'fields_missing' ? _fieldsKey : _countriesKey,
    );
    return false;
  }

  /// La raison qui bloque l'étape 1, dans l'ORDRE de la page (de haut en bas),
  /// ou null quand tout passe. Les champs du formulaire viennent d'abord : ils
  /// sont au-dessus de la naissance, du tuteur et du consentement.
  String? _identityIssue({required bool formValid}) {
    if (!formValid) return 'required_fields';
    if (_accountType == AccountType.student) {
      if (_birthDate == null) return 'birth_date_missing';
      if (_isUnderMinimumAge) return 'under_minimum_age';
      if (_guardianIncomplete) return 'guardian_incomplete';
    }
    if (!_hasConsented) return 'consent_missing';
    return null;
  }

  /// Déclaré mineur : un tuteur doit être nommé, joignable, et son accord
  /// donné avant toute synchronisation ou tout traitement IA.
  bool get _guardianIncomplete =>
      _isMinor &&
      (_guardianNameCtrl.text.trim().isEmpty ||
          _guardianContactCtrl.text.trim().isEmpty ||
          !_guardianConsented);

  bool _validateIdentityPage() {
    final formValid = _key0.currentState?.validate() ?? false;
    final issue = _identityIssue(formValid: formValid);
    if (issue == null) return true;
    final target = switch (issue) {
      'birth_date_missing' || 'under_minimum_age' => _birthDateKey,
      'guardian_incomplete' => _guardianKey,
      'consent_missing' => _consentKey,
      _ => null,
    };
    _onPageInvalid(0, issue, _key0, section: target);
    return false;
  }

  /// Un « Continuer » refusé : on le DIT (erreurs en place, page défilée
  /// jusqu'au premier problème, vibration) et on le mesure.
  void _onPageInvalid(
    int page,
    String reason,
    GlobalKey<FormState> formKey, {
    GlobalKey? section,
    bool markAttempted = true,
  }) {
    if (markAttempted) setState(() => _attemptedPages.add(page));
    KpbHaptics.error();
    _logValidationFailed(page, reason);
    // Après la trame : les erreurs qu'on vient d'allumer doivent être montées
    // pour qu'on puisse les atteindre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = section?.currentContext ?? _firstFieldError(formKey);
      if (target == null || !target.mounted) return;
      unawaited(Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ));
    });
  }

  void _logValidationFailed(int page, String reason) {
    unawaited(AnalyticsService.instance.logOnboardingValidationFailed(
      step: page + 1,
      reason: reason,
    ));
  }

  /// Le premier champ en erreur, dans l'ordre de l'arbre — qui est celui de
  /// l'écran, la page étant une seule colonne.
  BuildContext? _firstFieldError(GlobalKey<FormState> formKey) {
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement) {
        final state = element.state;
        if (state is FormFieldState && state.hasError) {
          found = element;
          return;
        }
      }
      element.visitChildren(visit);
    }

    final root = formKey.currentContext;
    if (root is Element) root.visitChildren(visit);
    return found;
  }

  void _prev() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Vrai pendant que « Créer mon compte » travaille.
  ///
  /// Ce bouton est le DERNIER du tunnel d'inscription : la toute première chose
  /// que fait un testeur, et le dernier geste avant que l'app ait un utilisateur.
  /// Il enchaînait une demande de permission de notification puis un PATCH de
  /// profil plafonné à quinze secondes, sans rien changer à l'écran et sans
  /// jamais se désactiver. Sur une connexion lente-mais-connectée — le cas
  /// courant du public visé — l'utilisateur voyait donc un écran figé pendant
  /// une quinzaine de secondes, et appuyait de nouveau. Chaque appui relançait
  /// `requestPermission()` et un second PATCH.
  ///
  /// Un bouton principal qui n'accuse pas réception EST cassé, même quand tout
  /// finit par marcher.
  bool _submitting = false;

  Future<void> _submit() async {
    // Le garde-fou de la double soumission. `_next` reste câblé, mais un
    // deuxième appui pendant l'attente ne relance rien : ni la permission, ni
    // le PATCH.
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // Plus de demande d'autorisation des notifications ici : elle arrivait
      // avant toute valeur, sans contexte, et grillait l'invite unique d'iOS.
      // Elle est faite au premier « Suivre », derrière une feuille qui dit à
      // quoi elle sert (FollowPushPrimer). Le jeton d'un appareil DÉJÀ
      // autorisé reste rattaché par completeOnboarding() → syncPushIdentity().
      unawaited(AnalyticsService.instance
          .logOnboardingCompleted(accountType: _accountType.name));
      final profile = _buildProfile();
      if (_accountType == AccountType.student) {
        // AHA moment (P0-D): await the profile PATCH so the server scores the
        // answers just given, then reveal the matches. Guest/skip paths never
        // reach _submit, so they keep landing on home.
        await _ctrl.completeOnboardingSynced(profile);
        if (!mounted) return;
        if (_referralStep) {
          // Le code du parrain APRÈS la synchro du profil, avant l'écran
          // « aha ». L'onboarding est déjà terminé : quitter l'app sur cette
          // étape ne fait rien perdre (le code reste proposé dans Parrainage).
          unawaited(Get.offAll(() => OnboardingReferralStep(
                onFinished: () => Get.offAll(() => const AhaMomentScreen()),
              )));
        } else {
          unawaited(Get.offAll(() => const AhaMomentScreen()));
        }
      } else {
        _ctrl.completeOnboarding(profile);
        unawaited(Get.offAllNamed(AppRoutes.home));
      }
    } finally {
      // Dans un `finally`, et pas après le `await` : si la remontée échoue, un
      // bouton resté grisé serait une impasse de plus — celle-là définitive,
      // sur le dernier écran avant l'app.
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: Column(
        children: [
          // ── Progress bar ─────────────────────────────────────────
          _ProgressHeader(
            page: _page,
            total: _totalPages,
            onBack: _page > 0 ? _prev : null,
            // V2 : « Passer » dès la page 1. Ancien parcours : à partir de
            // la page 2, comme avant.
            onSkip: (_v2 || _page > 0) ? _skip : null,
          ),

          // ── Pages ────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) {
                setState(() => _page = p);
                _logStepViewed(p);
              },
              children: [
                // Page 0 — Identité & compte
                _Page(
                  formKey: _key0,
                  autovalidate: _attemptedPages.contains(0),
                  title: 'onboarding_welcome_title'.tr,
                  subtitle: 'onboarding_welcome_subtitle'.tr,
                  child: _PageIdentity(
                    accountType: _accountType,
                    language: _language,
                    firstNameCtrl: _firstNameCtrl,
                    lastNameCtrl: _lastNameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    whatsAppCtrl: _whatsAppCtrl,
                    phoneCode: _phoneCode,
                    waCode: _waCode,
                    sameWhatsApp: _sameWhatsApp,
                    country: _country,
                    hasConsented: _hasConsented,
                    birthDate: _birthDate,
                    isMinor: _isMinor,
                    guardianNameCtrl: _guardianNameCtrl,
                    guardianContactCtrl: _guardianContactCtrl,
                    guardianConsented: _guardianConsented,
                    showErrors: _attemptedPages.contains(0),
                    requireCountry: _v2,
                    showAgeErrorEagerly: _v2,
                    isUnderMinimumAge: _isUnderMinimumAge,
                    guardianIncomplete: _guardianIncomplete,
                    birthDateKey: _birthDateKey,
                    guardianKey: _guardianKey,
                    consentKey: _consentKey,
                    onGuardianChanged: () => setState(() {}),
                    onAccountType: (v) => setState(() => _accountType = v),
                    onLanguage: (v) => setState(() => _language = v),
                    onPhoneCode: (v) => setState(() => _phoneCode = v),
                    onWaCode: (v) => setState(() => _waCode = v),
                    onSameWhatsApp: (v) => setState(() => _sameWhatsApp = v),
                    onCountry: _onCountryPicked,
                    onConsent: (v) => setState(() => _hasConsented = v),
                    onBirthDate: (v) => setState(() => _birthDate = v),
                    onGuardianConsent: (v) =>
                        setState(() => _guardianConsented = v),
                  ),
                ),

                // Page 1 — Niveau académique
                if (_accountType != AccountType.partner)
                  _Page(
                    formKey: _key1,
                    autovalidate: _attemptedPages.contains(1),
                    title: 'onboarding_academic_title'.tr,
                    subtitle: 'onboarding_academic_subtitle'.tr,
                    child: _PageAcademic(
                      currentLevel: _currentLevel,
                      targetLevel: _targetLevel,
                      languageLevel: _languageLevel,
                      gradeRange: _gradeRange,
                      annualTuitionBudgetEur: _annualTuitionBudgetEur,
                      preferredCurrency: _preferredCurrency,
                      wantsScholarship: _wantsScholarship,
                      wantsNewsletter: _wantsNewsletter,
                      requireLevels: _v2,
                      onCurrentLevel: (v) =>
                          setState(() => _currentLevel = v ?? _currentLevel),
                      onTargetLevel: (v) =>
                          setState(() => _targetLevel = v ?? _targetLevel),
                      onLanguageLevel: (v) =>
                          setState(() => _languageLevel = v ?? _languageLevel),
                      onGradeRange: (v) =>
                          setState(() => _gradeRange = v ?? _gradeRange),
                      onAnnualTuitionBudget: (v) =>
                          setState(() => _annualTuitionBudgetEur = v),
                      onPreferredCurrency: (v) => setState(
                        () => _preferredCurrency = v ?? _preferredCurrency,
                      ),
                      onWantsScholarship: (v) =>
                          setState(() => _wantsScholarship = v),
                      onWantsNewsletter: (v) =>
                          setState(() => _wantsNewsletter = v),
                    ),
                  )
                else
                  _Page(
                    formKey: _key1,
                    title: 'onboarding_partner_title'.tr,
                    subtitle: 'onboarding_partner_subtitle'.tr,
                    child: _PagePartner(),
                  ),

                // Page 2 — Filières, pays, documents
                if (_accountType != AccountType.partner)
                  _Page(
                    formKey: _key2,
                    title: 'onboarding_interests_title'.tr,
                    subtitle: 'onboarding_interests_subtitle'.tr,
                    child: _PageInterests(
                      controller: _ctrl,
                      fieldIds: _fieldIds,
                      countryIds: _countryIds,
                      docs: _docs,
                      showErrors: _v2 && _attemptedPages.contains(2),
                      fieldsKey: _fieldsKey,
                      countriesKey: _countriesKey,
                      onToggleField: (id) => setState(() {
                        if (_fieldIds.contains(id)) {
                          _fieldIds.remove(id);
                        } else {
                          _fieldIds.add(id);
                        }
                      }),
                      onToggleCountry: (id) => setState(() {
                        if (_countryIds.contains(id)) {
                          _countryIds.remove(id);
                        } else {
                          _countryIds.add(id);
                        }
                      }),
                      onToggleDoc: (key) => setState(() {
                        if (_docs.contains(key)) {
                          _docs.remove(key);
                        } else {
                          _docs.add(key);
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom CTA ───────────────────────────────────────────
          _BottomBar(
            page: _page,
            total: _totalPages,
            onNext: _next,
            busy: _submitting,
          ),
        ],
      ),
    );
  }
}
