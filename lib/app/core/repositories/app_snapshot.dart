import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.localeCode,
    required this.hasCompletedOnboarding,
    this.hasSeenIntro = false,
    this.isGuestMode = false,
    this.isAppLockEnabled = false,
    this.dataSaverEnabled = false,
    this.analyticsOptOut = true,
    this.analyticsConsentDecided = false,
    this.themeMode = ThemeMode.system,
    this.profile,
    this.savedItems = const [],
    this.savedItemTombstones = const {},
    this.cases = const [],
    this.orientationHistory = const [],
    this.searchHistory = const [],
    this.pendingOrientationAnswers = const {},
    this.pendingOrientationQuestionIndex = 0,
    this.fields = const [],
    this.countries = const [],
    this.institutions = const [],
    this.programs = const [],
    this.scholarships = const [],
    this.purchasedCourseIds = const [],
    this.reviewCredits = 0,
    this.completedRoadmapSteps = const {},
    this.profileNeedsPush = false,
    this.pendingConsentKeys = const {},
    this.onboardingStep = 0,
    this.onboardingSkipped = false,
    this.caseLastReadAt = const {},
    this.reviewedCaseIds = const [],
  });

  /// Local profile edits not yet confirmed by PATCH `/profiles/me`; avoids overwriting on sync.
  final bool profileNeedsPush;

  /// Consentements changés sur CET appareil et pas encore accusés par le
  /// serveur (audit 57, F24) : seuls eux partent dans le PATCH du profil. Voir
  /// `ProfileConsentFields`.
  final Set<String> pendingConsentKeys;

  final String localeCode;
  final bool hasCompletedOnboarding;
  final bool hasSeenIntro;
  final bool isGuestMode;
  final bool isAppLockEnabled;

  /// Data-saver: skip non-essential network image loads on low-bandwidth links.
  final bool dataSaverEnabled;

  /// User opted out of product analytics, crash reporting, and session replay.
  ///
  /// La valeur portée ici n'est LUE que si [analyticsConsentDecided] est vrai :
  /// `AppController.hydrate` écrase celle d'un indécis par le défaut du produit
  /// (mesure active, annoncée dans les CGU). Le `true` du constructeur est donc
  /// le repli d'un instantané qui n'a jamais été écrit, pas la politique.
  final bool analyticsOptOut;

  /// L'utilisateur a-t-il TOUCHÉ l'interrupteur « Analyse d'usage » ?
  ///
  /// C'est ce champ, et lui seul, qui rend un refus explicite distinguable d'un
  /// silence — donc préservable quand le défaut du produit change. Sans lui,
  /// basculer le défaut aurait retourné les refus en acceptations.
  final bool analyticsConsentDecided;
  final ThemeMode themeMode;
  final UserProfile? profile;
  final List<SavedItem> savedItems;
  // Keys of locally-deleted saved items not yet confirmed by the server.
  // Format: 'type:itemId'. Excluded from the merge union to prevent
  // remote items from being resurrected on reconnect.
  final Set<String> savedItemTombstones;
  final List<StudentCase> cases;
  final List<OrientationSession> orientationHistory;
  final List<String> searchHistory;
  final Map<String, List<String>> pendingOrientationAnswers;
  final int pendingOrientationQuestionIndex;
  final List<FieldModel> fields;
  final List<CountryModel> countries;
  final List<InstitutionModel> institutions;
  final List<ProgramModel> programs;
  final List<ScholarshipModel> scholarships;
  final List<String> purchasedCourseIds;

  /// No-cash referral reward balance (KPB-77) — last value synced from backend.
  final int reviewCredits;
  final Map<String, List<String>> completedRoadmapSteps;
  final int onboardingStep;
  final bool onboardingSkipped;
  final Map<String, String> caseLastReadAt;

  /// Case ids the student has already been prompted to review at admission
  /// (KPB-75) — so the rating prompt is shown at most once per case.
  final List<String> reviewedCaseIds;

  factory AppSnapshot.initial() {
    return const AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: false,
      hasSeenIntro: false,
      isAppLockEnabled: false,
    );
  }
}
