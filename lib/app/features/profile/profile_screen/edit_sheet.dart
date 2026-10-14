part of '../profile_screen.dart';

// Feuille d'édition du profil.

// ─────────────────────────────────────────────────────────────────────────────
// Profile Edit Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.controller});
  final AppController controller;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

/// Documents the student can flag as available, in display order.
/// Keys match `_docLabel` and the `availableDocuments` payload field.
const _kEditableDocuments = <String>[
  'Passport',
  'CV',
  'Transcripts',
  'Test score'
];

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _countryCtrl;
  // Email du compte, en LECTURE SEULE. La carte de complétion le réclame, mais
  // cette feuille n'avait aucun champ email : quiconque avait un profil local
  // sans email (créé par « Passer » l'onboarding) voyait « Email » dans ses
  // manques sans pouvoir rien y faire. Ce n'est pas un champ modifiable :
  // c'est l'identité de connexion, que le serveur n'écrit jamais via le PATCH.
  // On l'affiche, et on recopie celui de la session si le profil l'a perdu.
  late TextEditingController _emailCtrl;
  String? _currentLevel;
  String? _bacSeries;
  // ── Les quatre champs qui n'étaient réglables qu'à l'inscription ─────────
  // Revue du build 49 : « certaines options ne peuvent pas être complétées ou
  // modifiées sur le profil après (comme le budget) ». Le budget en était le
  // cas le plus net — `annualTuitionBudgetEur` n'avait qu'UN écrivain dans
  // tout lib/ (onboarding_screen.dart), et le seul chemin de retour vers ce
  // menu était « Revoir le tutoriel de démarrage », qui efface
  // `hasCompletedOnboarding` et relance l'entonnoir en trois pages.
  //
  // Les trois autres bloquaient le 100 % de la même façon : la carte de
  // complétion les réclamait sans qu'aucun écran ne sache les fournir.
  String? _targetLevel;
  String? _languageLevel;
  String? _gradeRange;
  int? _annualBudgetEur;
  // La date de naissance n'avait AUCUN éditeur après l'inscription, et ce
  // manque est devenu bloquant en build 51 : le serveur refuse tout appel IA
  // tant qu'elle est absente (`age_verification_required`), et le message
  // renvoie l'étudiant vers son profil. Sans ce champ, l'instruction était un
  // cul-de-sac — le seul chemin restant était de rejouer tout l'onboarding.
  DateTime? _birthDate;
  late Set<String> _countryIds;
  late Set<String> _fieldIds;
  late Set<String> _documents;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.controller.profile!;
    _nameCtrl = TextEditingController(text: p.fullName);
    _phoneCtrl = TextEditingController(text: p.phone);
    _whatsappCtrl = TextEditingController(text: p.whatsApp);
    _countryCtrl = TextEditingController(text: p.countryOfResidence);
    _emailCtrl = TextEditingController(
      text: p.email.trim().isNotEmpty ? p.email : _sessionEmail() ?? '',
    );
    // Normalise legacy/raw levels ("L1", "M1"…) to a canonical label so the
    // dropdown selects the right item instead of resetting to null.
    _currentLevel = normalizeStudentLevel(p.currentLevel)?.labelFr;
    _bacSeries = onboardingBacSeries.contains(p.bacSeries) ? p.bacSeries : null;
    // Chaque valeur est confrontée à sa liste avant d'être posée. Un jeton
    // inconnu (profil ancien, valeur venue du serveur) rend `null` et le menu
    // s'ouvre vide, au lieu de faire planter `DropdownButtonFormField`, qui
    // exige que la valeur initiale figure EXACTEMENT une fois dans ses items.
    _targetLevel = onboardingTargetLevels.any((e) => e.$1 == p.targetLevel)
        ? p.targetLevel
        : null;
    _languageLevel =
        onboardingLanguageLevels.any((e) => e.$1 == p.languageLevel)
            ? p.languageLevel
            : null;
    _gradeRange =
        onboardingGradeRanges.contains(p.gradeRange) ? p.gradeRange : null;
    _annualBudgetEur =
        onboardingBudgetRanges.any((e) => e.$1 == p.annualTuitionBudgetEur)
            ? p.annualTuitionBudgetEur
            : null;
    _birthDate = p.birthDate;
    _countryIds = p.targetCountryIds.toSet();
    _fieldIds = p.fieldIds.toSet();
    _documents = p.availableDocuments.toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _countryCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  static String? _sessionEmail() => Get.isRegistered<AuthService>()
      ? Get.find<AuthService>().sessionEmail
      : null;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: KpbColors.borderStrong,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                'profile_edit_title'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 24),
              _EditField(
                label: 'profile_field_full_name'.tr,
                controller: _nameCtrl,
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'required'.tr : null,
              ),
              const SizedBox(height: 16),
              if (_emailCtrl.text.isNotEmpty) ...[
                _EditField(
                  label: 'email'.tr,
                  controller: _emailCtrl,
                  icon: Icons.mail_outline_rounded,
                  readOnly: true,
                  helperText: 'profile_field_email_helper'.tr,
                ),
                const SizedBox(height: 16),
              ],
              _EditField(
                label: 'profile_field_phone'.tr,
                controller: _phoneCtrl,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _EditField(
                label: 'WhatsApp',
                controller: _whatsappCtrl,
                icon: Icons.chat_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _EditField(
                label: 'profile_field_country_of_residence'.tr,
                controller: _countryCtrl,
                icon: Icons.public_outlined,
              ),
              const SizedBox(height: 32),
              Text(
                'profile_my_journey'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currentLevel,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  'profile_field_current_study_level'.tr,
                  Icons.school_outlined,
                ),
                items: onboardingStudyLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _currentLevel = v;
                  if (v == null || !studyLevelNeedsBacSeries(v)) {
                    _bacSeries = null;
                  }
                }),
              ),
              if (_currentLevel != null &&
                  studyLevelNeedsBacSeries(_currentLevel!)) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _bacSeries,
                  isExpanded: true,
                  decoration: _dropdownDecoration(
                    'profile_field_bac_series'.tr,
                    Icons.workspace_premium_outlined,
                  ),
                  items: onboardingBacSeries
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _bacSeries = v),
                ),
              ],
              const SizedBox(height: 16),
              // Niveau visé — jeton stocké, libellé français affiché.
              DropdownButtonFormField<String>(
                initialValue: _targetLevel,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  'target_level'.tr,
                  Icons.trending_up_rounded,
                ),
                // Libellé via l'aide localisée : le menu ne doit pas afficher
                // du français dans une interface anglaise.
                items: onboardingTargetLevels
                    .map((l) => DropdownMenuItem(
                          value: l.$1,
                          child: Text(targetLevelLabel(l.$1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _targetLevel = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _languageLevel,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  'language_level'.tr,
                  Icons.translate_outlined,
                ),
                items: onboardingLanguageLevels
                    .map((l) => DropdownMenuItem(
                          value: l.$1,
                          child: Text(languageLevelLabel(l.$1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _languageLevel = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gradeRange,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  'grade_range'.tr,
                  Icons.grade_outlined,
                ),
                items: onboardingGradeRanges
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gradeRange = v),
              ),
              const SizedBox(height: 16),
              // Mêmes bornes que l'onboarding (16 ans minimum, 80 ans max) :
              // deux sélecteurs qui accepteraient des dates différentes pour le
              // même champ finiraient par diverger.
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final lastDate = DateTime(now.year - 16, now.month, now.day);
                  var initial =
                      _birthDate ?? DateTime(now.year - 18, now.month, now.day);
                  if (initial.isAfter(lastDate)) initial = lastDate;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(now.year - 80),
                    lastDate: lastDate,
                    helpText: 'birth_date'.tr,
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
                child: InputDecorator(
                  decoration: _dropdownDecoration(
                    'birth_date'.tr,
                    Icons.cake_outlined,
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'birth_date_hint'.tr
                        : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                            '${_birthDate!.month.toString().padLeft(2, '0')}/'
                            '${_birthDate!.year}',
                    style: _birthDate == null
                        ? const TextStyle(color: KpbColors.textMuted)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // LE budget du signalement. Les montants s'affichent dans la
              // devise choisie par l'étudiant, comme à l'inscription, mais la
              // valeur stockée reste l'euro canonique — c'est lui qui sert au
              // rapprochement des programmes.
              DropdownButtonFormField<int>(
                initialValue: _annualBudgetEur,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  'tuition_budget_annual'.tr,
                  Icons.savings_outlined,
                ),
                items: onboardingBudgetRanges
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.$1,
                        child: Text(
                          CurrencyUtils.formatEur(
                            r.$1,
                            widget.controller.profile!.preferredCurrency,
                            perYear: true,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _annualBudgetEur = v),
              ),
              const SizedBox(height: 24),
              Text(
                'profile_target_countries'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: onboardingDestinations.map((d) {
                  final selected = _countryIds.contains(d.id);
                  return FilterChip(
                    label: Text('${d.flag} ${d.labelFr}'),
                    selected: selected,
                    onSelected: (on) => setState(() {
                      if (on) {
                        _countryIds.add(d.id);
                      } else {
                        _countryIds.remove(d.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Les filières n'étaient modifiables qu'à l'onboarding (et
              // l'orientation ne faisait qu'en ajouter) : un choix fait une
              // fois biaisait le matching et les bourses pour toujours.
              Text(
                'profile_fields_of_interest'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.controller.fields.map((f) {
                  final selected = _fieldIds.contains(f.id);
                  return FilterChip(
                    label: Text(widget.controller.resolve(f.name)),
                    selected: selected,
                    onSelected: (on) => setState(() {
                      if (on) {
                        _fieldIds.add(f.id);
                      } else {
                        _fieldIds.remove(f.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'available_documents'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kEditableDocuments.map((doc) {
                  final selected = _documents.contains(doc);
                  return FilterChip(
                    label: Text(_docLabel(doc)),
                    selected: selected,
                    onSelected: (on) => setState(() {
                      if (on) {
                        _documents.add(doc);
                      } else {
                        _documents.remove(doc);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: KpbColors.actionPrimary),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('save_changes'.tr),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = widget.controller.profile!.copyWith(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsApp: _whatsappCtrl.text.trim(),
      countryOfResidence: _countryCtrl.text.trim(),
      currentLevel: _currentLevel,
      bacSeries: _bacSeries,
      // Le menu disparaît pour les niveaux sans série de bac, et `_bacSeries`
      // passe alors à `null` : il faut le dire explicitement, sinon l'ancienne
      // série reste.
      clearBacSeries: _bacSeries == null,
      targetLevel: _targetLevel,
      languageLevel: _languageLevel,
      gradeRange: _gradeRange,
      annualTuitionBudgetEur: _annualBudgetEur,
      birthDate: _birthDate,
      targetCountryIds: _countryIds.toList(),
      fieldIds: _fieldIds.toList(),
      availableDocuments: _documents.toList(),
    );
    unawaited(widget.controller.updateProfile(updated));
    Navigator.pop(context);
    KpbToast.success(
      'profile_updated_body'.tr,
      title: 'profile_updated_title'.tr,
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KpbColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KpbColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KpbColors.actionPrimary, width: 2),
      ),
      filled: true,
      fillColor: KpbColors.canvas,
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: readOnly ? const TextStyle(color: KpbColors.textMuted) : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KpbColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KpbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: KpbColors.actionPrimary, width: 2),
        ),
        filled: true,
        fillColor: KpbColors.canvas,
      ),
    );
  }
}
