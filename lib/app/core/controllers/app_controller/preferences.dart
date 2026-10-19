part of '../app_controller.dart';

/// Profil et préférences : langue, thème, verrou, économie de données, consentements, notifications.
mixin _PreferencesMixin on _AppControllerBase {
  /// Build 49 : toute préférence `en` (snapshot ou profil distant) redevient
  /// `fr`. `switchLanguage` n'est pas touché — le test de parité s'en sert.
  @override
  void _clampShippedLocale() {
    localeCode = canonicalAppLocale(localeCode);
    final p = profile;
    if (p == null) return;
    final shipped = canonicalAppLocale(p.preferredLanguage);
    if (p.preferredLanguage != shipped) {
      profile = p.copyWith(preferredLanguage: shipped);
    }
    localeCode = shipped;
  }

  /// Re-render every `.tr` string in [localeCode]. Guarded so it is a no-op in
  /// pure unit tests (no live GetMaterialApp), where forcing a frame asserts.
  @override
  void _applyLocaleToUi() {
    if (Get.context == null) return;
    // Ne RIEN faire quand la langue n'a pas changé.
    //
    // `Get.updateLocale` déclenche un `forceAppUpdate`, c'est-à-dire un
    // réassemblage complet de l'application. L'appeler à la fin de l'onboarding
    // — où l'immense majorité des utilisateurs garde le français — reconstruisait
    // tout l'arbre pour rien, en plein milieu de l'envoi du profil.
    //
    // C'est aussi ce qui rendait l'état occupé de « Créer mon compte »
    // intestable : le réassemblage laisse l'ordonnanceur hors de son état de
    // repos, et la frame suivante du test échoue sur
    // `schedulerPhase == SchedulerPhase.idle`. Un correctif qu'on ne peut pas
    // mesurer n'est pas un correctif.
    if (Get.locale?.toString() == Locale(localeCode).toString()) return;
    Get.updateLocale(Locale(localeCode));
  }

  void switchLanguage(String newLocaleCode) {
    localeCode = newLocaleCode;
    _applyLocaleToUi();
    final p = profile;
    if (p != null) {
      profile = p.copyWith(preferredLanguage: newLocaleCode);
    }
    _profileNeedsPush = true;
    unawaited(_pushProfileUpdate());
    _persist();
    update();
  }

  void toggleAppLock(bool enable) {
    isAppLockEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void toggleDataSaver(bool enable) {
    dataSaverEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  /// Profile switch: [allowed] true = analytics + session replay ON. Persists
  /// the inverse ([analyticsOptOut]) and flips Firebase + PostHog collection at
  /// runtime immediately (no restart needed). Applied again on every boot from
  /// the persisted flag ([applyAnalyticsConsent]).
  void setAnalyticsAllowed(bool allowed) {
    analyticsConsentDecided = true;
    analyticsOptOut = !allowed;
    _repository.saveSnapshot(_snapshot);
    unawaited(AnalyticsService.instance.setCollectionEnabled(allowed));
    update();
  }

  /// Re-applies the persisted analytics consent to the SDKs. Called at boot,
  /// after [hydrate], so a prior opt-out survives restarts.
  void applyAnalyticsConsent() {
    unawaited(AnalyticsService.instance.setCollectionEnabled(!analyticsOptOut));
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist();
    update();
    AnalyticsService.instance.logThemeToggled(mode == ThemeMode.dark);
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    profile = newProfile;
    _profileNeedsPush = true;
    _persist();
    update();
    // Plus rien à pousser côté push : le ciblage (niveau, pays visé) se calcule
    // sur le serveur, à partir du profil que `_pushProfileUpdate` lui envoie.
    await _pushProfileUpdate();
  }

  /// Profile switch: opt in/out of the scholarship newsletter. The backend
  /// stamps the consent timestamp on the opt-in transition and syncs Mautic.
  void setNewsletterOptIn(bool optIn) {
    final current = profile;
    if (current == null) return;
    unawaited(
        updateProfile(current.copyWith(wantsScholarshipNewsletter: optIn)));
  }

  /// « Recevoir par e-mail les nouvelles et offres de KPB » (correctifs 57).
  /// Le serveur horodate le consentement au passage à `true`. Sans effet tant
  /// que le serveur n'a pas annoncé le champ ([UserProfile.serverKnowsPromotions]).
  void setPromotionsEmailOptIn(bool optIn) {
    final current = profile;
    if (current == null || !current.serverKnowsPromotions) return;
    unawaited(updateProfile(current.copyWith(promotionsEmailOptIn: optIn)));
  }

  /// KPB-169: opt out of (or back into) ONE recurring notification family.
  /// Persisted via the profile PATCH; the other families are untouched, and a
  /// key this build doesn't know about is preserved rather than cleared.
  void setNotificationTypeOptOut(String type, bool optOut) {
    final current = profile;
    if (current == null) return;
    final next = applyOptOut(
      current.disabledNotificationTypes,
      type,
      optOut: optOut,
    );
    unawaited(updateProfile(current.copyWith(disabledNotificationTypes: next)));
  }

  @override
  Future<void> _pushProfileUpdate() async {
    if (!AppConfig.enableRemoteSync) {
      _profileNeedsPush = false;
      return;
    }
    if (profile == null) return;
    if (!await _apiClient.hasAuthSession()) {
      _profileNeedsPush = false;
      _persist();
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      _profileNeedsPush = true;
      _persist();
      return;
    }
    try {
      await _apiClient.updateProfile(_userProfilePayload(profile!));
      _profileNeedsPush = false;
      _persist();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'pushProfileUpdate',
        domain: CrashlyticsObsDomain.profile,
        operation: 'push_profile_update',
      );
      _profileNeedsPush = true;
      _persist();
    }
  }

  @override
  Map<String, dynamic> _userProfilePayload(UserProfile profile) {
    return <String, dynamic>{
      'fullName': profile.fullName,
      // Pas d'`email` : c'est l'identité d'authentification, le serveur ne
      // l'écrit jamais. L'envoyer ne servait à rien et, validé `@IsEmail()`
      // côté serveur, un email vide (profil créé par « Passer ») ou mal tapé
      // faisait échouer le PATCH ENTIER en 400 — le patch restait en attente
      // et `syncRemoteData` sautait à jamais le rapatriement du profil, donc
      // l'email du compte n'était jamais restauré.
      // Téléphone et WhatsApp ne sont PAS persistés localement (RGPD) : après
      // un redémarrage à froid ils valent '' jusqu'au premier GET du profil.
      // Les envoyer vides effaçait le numéro côté serveur.
      if (profile.phone.isNotEmpty) 'phone': profile.phone,
      if (profile.whatsApp.isNotEmpty) 'whatsApp': profile.whatsApp,
      'countryOfResidence': profile.countryOfResidence,
      'preferredLanguage': profile.preferredLanguage,
      'currentLevel': profile.currentLevel,
      'targetLevel': profile.targetLevel,
      'languageLevel': profile.languageLevel,
      'fieldIds': profile.fieldIds,
      'targetCountryIds': profile.targetCountryIds,
      // Deux champs, deux clés. Cette ligne valait
      // `profile.bacSeries ?? profile.gradeRange` : faute de colonne
      // `bacSeries` côté serveur, la série du bac voyageait DANS la moyenne
      // académique. Choisir « D » écrivait donc `gradeRange = 'D'`, et la
      // synchronisation suivante rapatriait « D » comme moyenne — la vraie
      // valeur était perdue sans que rien ne le signale. La colonne existe
      // depuis la migration 20260829140000_profile_bac_series.
      'gradeRange': profile.gradeRange,
      'bacSeries': profile.bacSeries,
      'annualTuitionBudgetEur': profile.annualTuitionBudgetEur,
      'preferredCurrency': profile.preferredCurrency,
      'wantsScholarshipSupport': profile.wantsScholarshipSupport,
      'scholarshipNewsletterOptIn': profile.wantsScholarshipNewsletter,
      // Seulement si le serveur l'a annoncé : un serveur antérieur refuserait
      // le PATCH entier (`forbidNonWhitelisted`).
      if (profile.promotionsEmailOptIn != null)
        'promotionsEmailOptIn': profile.promotionsEmailOptIn,
      'disabledNotificationTypes': profile.disabledNotificationTypes,
      'availableDocuments': profile.availableDocuments,
      if (profile.monthlyBudgetEur != null)
        'monthlyBudgetEur': profile.monthlyBudgetEur,
      if (profile.aiConsentedAt != null)
        'aiConsentedAt': profile.aiConsentedAt!.toIso8601String(),
      if (profile.birthDate != null)
        'birthDate': profile.birthDate!.toIso8601String(),
      if (profile.guardianName != null) 'guardianName': profile.guardianName,
      if (profile.guardianContact != null)
        'guardianContact': profile.guardianContact,
      if (profile.guardianConsentedAt != null)
        'guardianConsentedAt': profile.guardianConsentedAt!.toIso8601String(),
    };
  }
}
