part of '../onboarding_screen.dart';

// Pages de l'onboarding : identité, parcours, partenaire, intérêts.

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
    required this.showErrors,
    required this.isUnderMinimumAge,
    required this.guardianIncomplete,
    required this.birthDateKey,
    required this.guardianKey,
    required this.consentKey,
    required this.onGuardianChanged,
    this.requireCountry = false,
    this.showAgeErrorEagerly = false,
  });

  /// V2 : le pays de résidence n'est plus pré-rempli, il est donc exigé — et
  /// l'erreur s'écrit dans le champ.
  final bool requireCountry;

  /// V2 : une date de moins de 16 ans (restaurée d'un profil) est signalée
  /// dans le champ dès l'affichage, sans attendre un « Continuer » — c'est
  /// elle qui bloque aussi « Passer ».
  final bool showAgeErrorEagerly;

  /// Un « Continuer » a déjà échoué : les sections hors formulaire montrent
  /// leur erreur en place (et plus dans un bandeau posé sur le bouton).
  final bool showErrors;
  final bool isUnderMinimumAge, guardianIncomplete;
  final GlobalKey birthDateKey, guardianKey, consentKey;
  final VoidCallback onGuardianChanged;

  final AccountType accountType;
  final String language;
  final String? country;
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
          validator: requireCountry ? _req : null,
          items: _countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onCountry,
        ),
        const SizedBox(height: KpbSpacing.lg),

        // ── Âge + consentement tuteur (mineurs) ────────────────────
        if (accountType == AccountType.student) ...[
          Builder(builder: (context) {
            final birthError = birthDate == null
                ? (showErrors ? 'onboarding_birthdate_required'.tr : null)
                : isUnderMinimumAge && (showErrors || showAgeErrorEagerly)
                    ? 'onboarding_under_16_body'.tr
                    : null;
            return InkWell(
              key: birthDateKey,
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
                  suffixIcon:
                      const Icon(Icons.calendar_today_outlined, size: 18),
                  errorText: birthError,
                  errorMaxLines: 3,
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
            );
          }),
          if (isMinor) ...[
            const SizedBox(height: KpbSpacing.md),
            Container(
              key: guardianKey,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: guardianConsented
                    ? KpbColors.successLight
                    : KpbColors.surfaceMuted,
                borderRadius: KpbRadius.mdBr,
                border: Border.all(
                  color: showErrors && guardianIncomplete
                      ? KpbColors.error
                      : guardianConsented
                          ? KpbColors.success
                          : KpbColors.border,
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
                    onChanged: (_) => onGuardianChanged(),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  TextFormField(
                    controller: guardianContactCtrl,
                    decoration:
                        InputDecoration(labelText: 'guardian_contact'.tr),
                    onChanged: (_) => onGuardianChanged(),
                  ),
                  // Son propre Material : sans lui, la tuile peindrait son
                  // effet d'encre sous le fond coloré de la carte.
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: guardianConsented,
                      activeColor: KpbColors.success,
                      title: Text('guardian_consent_checkbox'.tr,
                          style: KpbTextStyles.bodySm),
                      onChanged: (v) => onGuardianConsent(v ?? false),
                    ),
                  ),
                  if (showErrors && guardianIncomplete)
                    _InlineError('guardian_consent_required'.tr),
                ],
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.lg),
        ],

        // ── GDPR Consent ──────────────────────────────────────────
        // Toute la carte coche la case : la case seule (24 px) était la cible
        // la plus petite de l'écran, et un appui sur la phrase ne faisait
        // rien. Les deux liens gardent leur propre geste (le plus profond
        // gagne).
        Material(
          key: consentKey,
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onConsent(!hasConsented),
            borderRadius: KpbRadius.mdBr,
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasConsented
                    ? KpbColors.successLight
                    : KpbColors.surfaceMuted,
                borderRadius: KpbRadius.mdBr,
                border: Border.all(
                  color: hasConsented
                      ? KpbColors.success
                      : showErrors
                          ? KpbColors.error
                          : KpbColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                              TextSpan(
                                  text: 'onboarding_consent_accept_prefix'.tr),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () =>
                                      Get.to(() => PrivacyPolicyScreen()),
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
                                  onTap: () => Get.to(
                                      () => const TermsOfServiceScreen()),
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
                  if (showErrors && !hasConsented)
                    _InlineError('onboarding_consent_required_body'.tr),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

/// Une erreur écrite SOUS la section qui bloque, dans la couleur des erreurs
/// de champ — là où l'œil la cherche, et pas dans un bandeau qui couvre le
/// bouton « Continuer ».
class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: KpbColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: KpbColors.error,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
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
    this.requireLevels = false,
  });

  /// V2 : niveau actuel et niveau visé ne sont plus pré-remplis ; ils sont
  /// exigés pour continuer, avec l'erreur dans le champ. La langue et la
  /// moyenne restent facultatives : non choisies, elles restent VIDES.
  final bool requireLevels;

  final String? currentLevel, targetLevel, languageLevel, gradeRange;
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
          required: requireLevels,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DD(
          label: 'target_level'.tr,
          value: targetLevel,
          items: _targetLevels,
          onChanged: onTargetLevel,
          required: requireLevels,
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
    this.showErrors = false,
    this.fieldsKey,
    this.countriesKey,
  });

  final AppController controller;
  final Set<String> fieldIds, countryIds, docs;
  final ValueChanged<String> onToggleField, onToggleCountry, onToggleDoc;

  /// V2 : un « Créer mon compte » a échoué — l'erreur s'écrit SOUS le groupe
  /// de puces vide (et plus dans un toast).
  final bool showErrors;
  final GlobalKey? fieldsKey, countriesKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('explore_fields'.tr, key: fieldsKey, style: KpbTextStyles.titleMd),
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
        if (showErrors && fieldIds.isEmpty)
          _InlineError('onboarding_fields_required_inline'.tr),
        const SizedBox(height: KpbSpacing.lg),
        Text('explore_countries'.tr,
            key: countriesKey, style: KpbTextStyles.titleMd),
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
        if (showErrors && countryIds.isEmpty)
          _InlineError('onboarding_countries_required_inline'.tr),
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
