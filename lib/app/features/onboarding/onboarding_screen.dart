import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/services/onesignal_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/currency_utils.dart';
import '../legal/legal_pages.dart';
import '../matches/aha_moment_screen.dart';
import 'onboarding_m2_constants.dart';

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

  // State
  AccountType _accountType = AccountType.student;
  String _language = 'fr';
  String _country = 'Niger';
  String _currentLevel = 'High school';
  String _targetLevel = 'Bachelor';
  String _languageLevel = 'Intermediate';
  String _gradeRange = '12 - 14/20';
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
    AnalyticsService.instance.logOnboardingSkipped(step: _page + 1);
    _ctrl.skipOnboarding();
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
      countryOfResidence: _country,
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
      0 => () {
          final formValid = _key0.currentState?.validate() ?? false;
          if (!formValid) return false;
          if (!_hasConsented) {
            Get.snackbar(
              'onboarding_consent_required_title'.tr,
              'onboarding_consent_required_body'.tr,
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.privacy_tip_outlined,
                  color: KpbColors.error),
            );
            return false;
          }
          if (_accountType == AccountType.student) {
            if (_birthDate == null) {
              Get.snackbar(
                'onboarding_birthdate_required_title'.tr,
                'onboarding_birthdate_required'.tr,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 3),
                icon: const Icon(Icons.cake_outlined, color: KpbColors.error),
              );
              return false;
            }
            if (_isUnderMinimumAge) {
              Get.snackbar(
                'onboarding_under_16_title'.tr,
                'onboarding_under_16_body'.tr,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 3),
                icon: const Icon(Icons.cake_outlined, color: KpbColors.error),
              );
              return false;
            }
            // Declared minor: a guardian must be named, reachable, and consent
            // recorded before any data sync or AI processing.
            if (_isMinor &&
                (_guardianNameCtrl.text.trim().isEmpty ||
                    _guardianContactCtrl.text.trim().isEmpty ||
                    !_guardianConsented)) {
              Get.snackbar(
                'guardian_consent_required_title'.tr,
                'guardian_consent_required'.tr,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 3),
                icon: const Icon(Icons.family_restroom_outlined,
                    color: KpbColors.error),
              );
              return false;
            }
          }
          return true;
        }(),
      1 => _key1.currentState?.validate() ?? false,
      2 => () {
          if (_fieldIds.isEmpty) {
            Get.snackbar(
              'onboarding_selection_required_title'.tr,
              'onboarding_select_field_body'.tr,
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.info_outline_rounded,
                  color: KpbColors.warning),
            );
            return false;
          }
          if (_countryIds.isEmpty) {
            Get.snackbar(
              'onboarding_selection_required_title'.tr,
              'onboarding_select_country_body'.tr,
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.info_outline_rounded,
                  color: KpbColors.warning),
            );
            return false;
          }
          return true;
        }(),
      _ => true,
    };
    if (!valid) return;
    HapticFeedback.lightImpact();
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
      // Ask for push permission via OneSignal; identity is linked in
      // completeOnboarding() → syncOneSignalIdentity().
      await OneSignalService.instance.requestPermission();
      AnalyticsService.instance
          .logOnboardingCompleted(accountType: _accountType.name);
      final profile = _buildProfile();
      if (_accountType == AccountType.student) {
        // AHA moment (P0-D): await the profile PATCH so the server scores the
        // answers just given, then reveal the matches. Guest/skip paths never
        // reach _submit, so they keep landing on home.
        await _ctrl.completeOnboardingSynced(profile);
        if (!mounted) return;
        Get.offAll(() => const AhaMomentScreen());
      } else {
        _ctrl.completeOnboarding(profile);
        Get.offAllNamed(AppRoutes.home);
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
            onSkip: _page > 0 ? _skip : null,
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
                    onAccountType: (v) => setState(() => _accountType = v),
                    onLanguage: (v) => setState(() => _language = v),
                    onPhoneCode: (v) => setState(() => _phoneCode = v),
                    onWaCode: (v) => setState(() => _waCode = v),
                    onSameWhatsApp: (v) => setState(() => _sameWhatsApp = v),
                    onCountry: (v) => setState(() => _country = v ?? _country),
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

// ─────────────────────────────────────────────────────────────────────────────
// Progress Header
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.page,
    required this.total,
    this.onBack,
    this.onSkip,
  });
  final int page, total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (onBack != null)
                  Semantics(
                    button: true,
                    label: 'a11y_back'.tr,
                    child: GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: KpbColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 18, color: KpbColors.brandNavy),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 38),
                const Spacer(),
                Text(
                  '${page + 1} / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: KpbColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(38, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('skip'.tr),
                  )
                else
                  const SizedBox(width: 38),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            ClipRRect(
              borderRadius: KpbRadius.pillBr,
              child: LinearProgressIndicator(
                value: (page + 1) / total,
                minHeight: 6,
                backgroundColor: KpbColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    KpbColors.actionPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Page extends StatelessWidget {
  const _Page({
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final Key formKey;
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          const SizedBox(height: KpbSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.25,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: KpbColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.total,
    required this.onNext,
    this.busy = false,
  });
  final int page, total;
  final VoidCallback onNext;

  /// Vrai pendant l'envoi. `onPressed: null` — pas un bouton actif dont on
  /// ignore les appuis : un bouton actif qui ne fait rien est indiscernable
  /// d'une app plantée, et c'est exactement le rapport de bug que la 49
  /// aurait reçu.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onNext,
          style: FilledButton.styleFrom(
            backgroundColor: KpbColors.actionPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isLast ? 'create_account'.tr : 'continue'.tr),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 0 — Identité
// ─────────────────────────────────────────────────────────────────────────────
class _PageIdentity extends StatelessWidget {
  const _PageIdentity({
    required this.accountType,
    required this.language,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.whatsAppCtrl,
    required this.phoneCode,
    required this.waCode,
    required this.sameWhatsApp,
    required this.country,
    required this.onAccountType,
    required this.onLanguage,
    required this.onPhoneCode,
    required this.onWaCode,
    required this.onSameWhatsApp,
    required this.onCountry,
    required this.hasConsented,
    required this.onConsent,
    required this.birthDate,
    required this.isMinor,
    required this.guardianNameCtrl,
    required this.guardianContactCtrl,
    required this.guardianConsented,
    required this.onBirthDate,
    required this.onGuardianConsent,
  });

  final AccountType accountType;
  final String language, country;
  final TextEditingController firstNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      whatsAppCtrl;
  final _DialCode phoneCode, waCode;
  final bool sameWhatsApp;
  final ValueChanged<AccountType> onAccountType;
  final ValueChanged<String> onLanguage;
  final ValueChanged<_DialCode> onPhoneCode;
  final ValueChanged<_DialCode> onWaCode;
  final ValueChanged<bool> onSameWhatsApp;
  final ValueChanged<String?> onCountry;
  final bool hasConsented;
  final ValueChanged<bool> onConsent;
  final DateTime? birthDate;
  final bool isMinor, guardianConsented;
  final TextEditingController guardianNameCtrl, guardianContactCtrl;
  final ValueChanged<DateTime> onBirthDate;
  final ValueChanged<bool> onGuardianConsent;

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'field_required'.tr : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type de compte
        Text('onboarding_i_am'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Row(
          children: onboardingAccountTypes.map((t) {
            final sel = t == accountType;
            return Expanded(
              child: KpbPressable(
                onTap: () => onAccountType(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: t != onboardingAccountTypes.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? KpbColors.actionPrimary : Colors.white,
                    borderRadius: KpbRadius.mdBr,
                    border: sel ? null : Border.all(color: KpbColors.border),
                    boxShadow: sel ? KpbShadow.card : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        t == AccountType.student
                            ? Icons.school_outlined
                            : t == AccountType.parent
                                ? Icons.family_restroom_outlined
                                : Icons.handshake_outlined,
                        color: sel ? Colors.white : KpbColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t == AccountType.student
                            ? 'account_type_student'.tr
                            : t == AccountType.parent
                                ? 'account_type_parent_short'.tr
                                : 'badge_partner'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : KpbColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),

        if (kLanguageSwitchVisible) ...[
          Text('preferred_language'.tr, style: KpbTextStyles.titleMd),
          const SizedBox(height: 10),
          Row(
            children: [
              _LangBtn(
                label: 'lang_name_french'.tr,
                selected: language == 'fr',
                onTap: () => onLanguage('fr'),
              ),
              const SizedBox(width: 10),
              _LangBtn(
                label: 'lang_name_english'.tr,
                selected: language == 'en',
                onTap: () => onLanguage('en'),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.lg),
        ],

        // Nom / Prénom
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: firstNameCtrl,
                validator: _req,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'first_name'.tr),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: lastNameCtrl,
                validator: _req,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'last_name'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.md),

        // Email
        TextFormField(
          controller: emailCtrl,
          validator: _req,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'email'.tr),
        ),
        const SizedBox(height: KpbSpacing.md),

        // Téléphone
        _PhoneRow(
          controller: phoneCtrl,
          dialCode: phoneCode,
          label: 'phone'.tr,
          required: true,
          onDialCode: onPhoneCode,
        ),
        const SizedBox(height: KpbSpacing.sm),

        // WhatsApp
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: sameWhatsApp,
          title: Text('whatsapp_same_as_phone'.tr, style: KpbTextStyles.bodySm),
          onChanged: (v) => onSameWhatsApp(v ?? true),
        ),
        if (!sameWhatsApp) ...[
          _PhoneRow(
            controller: whatsAppCtrl,
            dialCode: waCode,
            label: 'whatsapp'.tr,
            required: false,
            onDialCode: onWaCode,
          ),
          const SizedBox(height: KpbSpacing.md),
        ],

        // Pays de résidence
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: country,
          decoration: InputDecoration(labelText: 'country'.tr),
          items: _countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onCountry,
        ),
        const SizedBox(height: KpbSpacing.lg),

        // ── Âge + consentement tuteur (mineurs) ────────────────────
        if (accountType == AccountType.student) ...[
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final lastDate = DateTime(now.year - 16, now.month, now.day);
              var initial =
                  birthDate ?? DateTime(now.year - 18, now.month, now.day);
              if (initial.isAfter(lastDate)) initial = lastDate;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year - 80),
                lastDate: lastDate,
                helpText: 'birth_date'.tr,
              );
              if (picked != null) onBirthDate(picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'birth_date'.tr,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                birthDate == null
                    ? 'birth_date_hint'.tr
                    : '${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}',
                style: birthDate == null
                    ? TextStyle(color: KpbColors.textMuted)
                    : null,
              ),
            ),
          ),
          if (isMinor) ...[
            const SizedBox(height: KpbSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: guardianConsented
                    ? KpbColors.successLight
                    : KpbColors.surfaceMuted,
                borderRadius: KpbRadius.mdBr,
                border: Border.all(
                  color:
                      guardianConsented ? KpbColors.success : KpbColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('minor_guardian_title'.tr, style: KpbTextStyles.titleMd),
                  const SizedBox(height: 4),
                  Text(
                    'minor_guardian_intro'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      color: KpbColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  TextFormField(
                    controller: guardianNameCtrl,
                    decoration: InputDecoration(labelText: 'guardian_name'.tr),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  TextFormField(
                    controller: guardianContactCtrl,
                    decoration:
                        InputDecoration(labelText: 'guardian_contact'.tr),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: guardianConsented,
                    activeColor: KpbColors.success,
                    title: Text('guardian_consent_checkbox'.tr,
                        style: KpbTextStyles.bodySm),
                    onChanged: (v) => onGuardianConsent(v ?? false),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.lg),
        ],

        // ── GDPR Consent ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                hasConsented ? KpbColors.successLight : KpbColors.surfaceMuted,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(
              color: hasConsented ? KpbColors.success : KpbColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: hasConsented,
                  onChanged: (v) => onConsent(v ?? false),
                  activeColor: KpbColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: KpbColors.textMuted,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: 'onboarding_consent_accept_prefix'.tr),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => Get.to(() => PrivacyPolicyScreen()),
                          child: Text(
                            'privacy_policy_inline'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: KpbColors.actionPrimary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: KpbColors.actionPrimary,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: 'onboarding_consent_and'.tr),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () =>
                              Get.to(() => const TermsOfServiceScreen()),
                          child: Text(
                            'onboarding_terms_of_use_inline'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: KpbColors.actionPrimary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: KpbColors.actionPrimary,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Académique
// ─────────────────────────────────────────────────────────────────────────────
class _PageAcademic extends StatelessWidget {
  const _PageAcademic({
    required this.currentLevel,
    required this.targetLevel,
    required this.languageLevel,
    required this.gradeRange,
    required this.annualTuitionBudgetEur,
    required this.preferredCurrency,
    required this.wantsScholarship,
    required this.wantsNewsletter,
    required this.onCurrentLevel,
    required this.onTargetLevel,
    required this.onLanguageLevel,
    required this.onGradeRange,
    required this.onAnnualTuitionBudget,
    required this.onPreferredCurrency,
    required this.onWantsScholarship,
    required this.onWantsNewsletter,
  });

  final String currentLevel, targetLevel, languageLevel, gradeRange;
  final int? annualTuitionBudgetEur;
  final String preferredCurrency;
  final bool wantsScholarship;
  final bool wantsNewsletter;
  final ValueChanged<String?> onCurrentLevel,
      onTargetLevel,
      onLanguageLevel,
      onGradeRange;
  final ValueChanged<int?> onAnnualTuitionBudget;
  final ValueChanged<String?> onPreferredCurrency;
  final ValueChanged<bool> onWantsScholarship;
  final ValueChanged<bool> onWantsNewsletter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DD(
          label: 'current_level'.tr,
          value: currentLevel,
          items: _studyLevels,
          onChanged: onCurrentLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DD(
          label: 'target_level'.tr,
          value: targetLevel,
          items: _targetLevels,
          onChanged: onTargetLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DD(
          label: 'language_level'.tr,
          value: languageLevel,
          items: _langLevels,
          onChanged: onLanguageLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: preferredCurrency,
          decoration: InputDecoration(labelText: 'preferred_currency'.tr),
          items: DisplayCurrency.values
              .map(
                (currency) => DropdownMenuItem(
                  value: currency.code,
                  child: Text('currency_${currency.code.toLowerCase()}'.tr),
                ),
              )
              .toList(),
          onChanged: onPreferredCurrency,
        ),
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: gradeRange,
          decoration: InputDecoration(labelText: 'grade_range'.tr),
          items: _grades
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: onGradeRange,
        ),
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<int>(
          initialValue: annualTuitionBudgetEur,
          decoration: InputDecoration(labelText: 'tuition_budget_annual'.tr),
          items: _budgetRanges
              .map(
                (r) => DropdownMenuItem(
                  value: r.$1,
                  child: Text(
                    CurrencyUtils.formatEur(
                      r.$1,
                      preferredCurrency,
                      perYear: true,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onAnnualTuitionBudget,
        ),
        const SizedBox(height: KpbSpacing.lg),
        KpbPressable(
          onTap: () => onWantsScholarship(!wantsScholarship),
          child: KpbCard(
            color: wantsScholarship ? KpbColors.warningLight : Colors.white,
            border: Border.all(
              color: wantsScholarship ? KpbColors.warning : KpbColors.border,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: wantsScholarship
                        ? KpbColors.warning.withValues(alpha: 0.15)
                        : KpbColors.surfaceMuted,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: wantsScholarship
                        ? KpbColors.warning
                        : KpbColors.textFaint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'scholarship_interest'.tr,
                    style: KpbTextStyles.titleMd,
                  ),
                ),
                Icon(
                  wantsScholarship
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: wantsScholarship
                      ? KpbColors.warning
                      : KpbColors.textFaint,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        // Newsletter opt-in — a real GDPR consent, so a plain checkbox
        // UNCHECKED by default (never pre-ticked), distinct from the
        // preference card above.
        CheckboxListTile(
          value: wantsNewsletter,
          onChanged: (v) => onWantsNewsletter(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: KpbColors.success,
          title: Text(
            'onboarding_newsletter_consent'.tr,
            style: KpbTextStyles.bodySm,
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1b — Partenaire
// ─────────────────────────────────────────────────────────────────────────────
class _PagePartner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return KpbCard(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.handshake_outlined,
              size: 48, color: KpbColors.actionPrimary),
          const SizedBox(height: KpbSpacing.md),
          Text('onboarding_partnership_space'.tr, style: KpbTextStyles.title),
          const SizedBox(height: 8),
          Text(
            'partner_redirect'.tr,
            style: KpbTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Intérêts
// ─────────────────────────────────────────────────────────────────────────────
class _PageInterests extends StatelessWidget {
  const _PageInterests({
    required this.controller,
    required this.fieldIds,
    required this.countryIds,
    required this.docs,
    required this.onToggleField,
    required this.onToggleCountry,
    required this.onToggleDoc,
  });

  final AppController controller;
  final Set<String> fieldIds, countryIds, docs;
  final ValueChanged<String> onToggleField, onToggleCountry, onToggleDoc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('explore_fields'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.fields.map((f) {
            final sel = fieldIds.contains(f.id);
            return FilterChip(
              label: Text(controller.resolve(f.name)),
              selected: sel,
              onSelected: (_) => onToggleField(f.id),
              selectedColor: KpbColors.actionPrimary,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: sel ? Colors.white : KpbColors.brandNavy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                    color: sel ? KpbColors.actionPrimary : KpbColors.border),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),
        Text('explore_countries'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.countries.map((c) {
            final sel = countryIds.contains(c.id);
            return FilterChip(
              label: Text(controller.resolve(c.name)),
              selected: sel,
              onSelected: (_) => onToggleCountry(c.id),
              selectedColor: KpbColors.actionPrimary,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: sel ? Colors.white : KpbColors.brandNavy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                    color: sel ? KpbColors.actionPrimary : KpbColors.border),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),
        Text('available_documents'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _documentKeys.map((e) {
            final sel = docs.contains(e.$1);
            return FilterChip(
              label: Text(_optionLabel(e.$1)),
              selected: sel,
              onSelected: (_) => onToggleDoc(e.$1),
              selectedColor: KpbColors.actionPrimary,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: sel ? Colors.white : KpbColors.brandNavy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                    color: sel ? KpbColors.actionPrimary : KpbColors.border),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  const _LangBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KpbPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? KpbColors.actionPrimary : Colors.white,
            borderRadius: KpbRadius.mdBr,
            border: selected ? null : Border.all(color: KpbColors.border),
            boxShadow: selected ? KpbShadow.card : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : KpbColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DD extends StatelessWidget {
  const _DD({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) =>
              DropdownMenuItem(value: e.$1, child: Text(_optionLabel(e.$1))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.controller,
    required this.dialCode,
    required this.label,
    required this.required,
    required this.onDialCode,
  });
  final TextEditingController controller;
  final _DialCode dialCode;
  final String label;
  final bool required;
  final ValueChanged<_DialCode> onDialCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KpbRadius.md),
            border: Border.all(color: KpbColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_DialCode>(
              value: dialCode,
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: _dialCodes
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child:
                            Text(d.label, style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onDialCode(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            validator: required
                ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'field_required'.tr : null
                : null,
            decoration: InputDecoration(labelText: label),
          ),
        ),
      ],
    );
  }
}
