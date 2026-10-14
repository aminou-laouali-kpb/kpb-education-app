import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/ai_error_message.dart';
import '../../core/utils/study_level.dart';
import '../ai_advisor/ai_consent.dart';
import '../ai_advisor/ai_disclosure_banner.dart';
import '../etudes_en_france/eef_help_line.dart';
import 'pdf_text.dart';

/// CV Generator — pre-filled from profile, AI-enhanced summary, PDF export.
class CvGeneratorScreen extends StatefulWidget {
  const CvGeneratorScreen({super.key, this.fromEefHub = false});

  /// `true` UNIQUEMENT quand l'écran est ouvert depuis le hub de l'espace « Études
  /// en France » : il montre alors une ligne « Besoin d'aide pour rédiger ton CV ? »
  /// vers le conseiller. Cet écran sert aussi à la boîte à outils et au tiroir
  /// « Outils KPB » : là, rien ne change. Un paramètre explicite plutôt qu'un
  /// état global, pour que l'appelant — et lui seul — décide.
  final bool fromEefHub;

  @override
  State<CvGeneratorScreen> createState() => _CvGeneratorScreenState();
}

class _CvGeneratorScreenState extends State<CvGeneratorScreen> {
  final _ctrl = Get.find<AppController>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _levelCtrl;
  late final TextEditingController _fieldCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _residenceCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _languagesCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _objectiveCtrl;

  String _aiSummaryFr = '';
  String _aiSummaryEn = '';
  bool _isGenerating = false;
  bool _useEnglish = false;

  /// Profile facts that have no form field of their own but do belong on the
  /// CV (they are rendered in the Education block / contact sidebar).
  String _bacSeries = '';
  String _gradeRange = '';
  String _languageLevel = '';
  String _targetLevel = '';
  String _whatsApp = '';

  @override
  void initState() {
    super.initState();
    final p = _ctrl.profile;

    // A student's declared level is a *year of study* (axis 1 of
    // study_level.dart), so it must go through studentLevelLabel: the previous
    // programLevelLabel() call mapped "bachelor_3" to the degree "Bachelor"
    // and silently dropped the year.
    final level = studentLevelLabel(p?.currentLevel);
    // Every declared field / target country, not just the first one.
    final fields = _resolveNames(
      p?.fieldIds ?? const [],
      (id) => _ctrl.fields
          .where((f) => f.id == id)
          .map((f) => _ctrl.resolve(f.name))
          .firstOrNull,
    );
    final countries = _resolveNames(
      p?.targetCountryIds ?? const [],
      (id) => _ctrl.countries
          .where((c) => c.id == id)
          .map((c) => _ctrl.resolve(c.name))
          .firstOrNull,
    );

    _bacSeries = (p?.bacSeries ?? '').trim();
    _gradeRange = (p?.gradeRange ?? '').trim();
    _languageLevel = (p?.languageLevel ?? '').trim();
    _whatsApp = (p?.whatsApp ?? '').trim();
    final rawTargetLevel = (p?.targetLevel ?? '').trim();
    // programLevelLabel('') answers "Autre" — only label a real value.
    _targetLevel =
        rawTargetLevel.isEmpty ? '' : programLevelLabel(rawTargetLevel);

    // A francophone student gets the FR CV first, an anglophone the EN one.
    _useEnglish = !_ctrl.localeCode.toLowerCase().startsWith('fr');

    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    // Fall back to WhatsApp when no plain phone number was recorded — most of
    // our students only ever fill the WhatsApp field.
    _phoneCtrl = TextEditingController(
      text: (p?.phone ?? '').trim().isNotEmpty ? p!.phone : _whatsApp,
    );
    _levelCtrl = TextEditingController(text: level);
    _fieldCtrl = TextEditingController(text: fields.join(', '));
    _countryCtrl = TextEditingController(text: countries.join(', '));
    _residenceCtrl = TextEditingController(
      text: (p?.countryOfResidence ?? '').trim(),
    );
    _skillsCtrl = TextEditingController();
    _languagesCtrl = TextEditingController(text: _prefilledLanguages());
    _experienceCtrl = TextEditingController();
    _objectiveCtrl = TextEditingController(
      text: _prefilledObjective(
        level: _targetLevel.isNotEmpty ? _targetLevel : level,
        field: fields.isNotEmpty ? fields.first : '',
        country: countries.isNotEmpty ? countries.first : '',
      ),
    );
  }

  /// Resolves ids to labels while preserving the profile's own order and
  /// dropping ids the catalogue does not know about.
  List<String> _resolveNames(
    List<String> ids,
    String? Function(String id) lookup,
  ) =>
      ids
          .map((id) => (lookup(id) ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);

  /// Default languages, plus the declared language level when there is one
  /// (e.g. "Français, Anglais (B2)").
  String _prefilledLanguages() {
    final base = 'cv_default_languages'.tr;
    if (_languageLevel.isEmpty) return base;
    final parts = base.split(',').map((s) => s.trim()).toList();
    if (parts.length < 2) return '$base ($_languageLevel)';
    parts[parts.length - 1] = '${parts.last} ($_languageLevel)';
    return parts.join(', ');
  }

  /// Seeds the career-objective field from the profile so the exported CV is
  /// not almost empty. The student can still edit or clear it.
  String _prefilledObjective({
    required String level,
    required String field,
    required String country,
  }) {
    if (level.isEmpty || field.isEmpty) return '';
    final goal = _trOrNull(
      'cv_objective_prefill',
      params: {'level': level, 'field': field},
    );
    if (goal == null) return '';
    if (country.isEmpty) return goal;
    final destination =
        _trOrNull('cv_objective_destination', params: {'country': country});
    return destination == null ? goal : '$goal $destination';
  }

  /// GetX echoes the key back when a translation is missing. New keys land in
  /// `app_translations.dart`, which this change does not own, so never show a
  /// raw key to a student: answer null and let the caller degrade.
  String? _trOrNull(String key, {Map<String, String>? params}) {
    final value = params == null ? key.tr : key.trParams(params);
    return value == key ? null : value;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _levelCtrl,
      _fieldCtrl,
      _countryCtrl,
      _residenceCtrl,
      _skillsCtrl,
      _languagesCtrl,
      _experienceCtrl,
      _objectiveCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() => _isGenerating = true);
    try {
      // The path MUST keep its leading slash. Dio concatenates
      // `baseUrl + path` verbatim (RequestOptions.uri), and the base URL ends
      // with `/api` and no trailing slash — so 'tools/cv-summary' was posted to
      // `https://api.kpbeducation.cloud/apitools/cv-summary`, i.e. a 404 on
      // every single tap. The coach chat never hit this because it calls
      // '/coach/…' with the slash.
      final result = await _ctrl.apiClient.postAi('/tools/cv-summary', {
        'name': _nameCtrl.text.trim(),
        'studyLevel': _levelCtrl.text.trim(),
        'fieldOfStudy': _fieldCtrl.text.trim(),
        'targetCountry': _countryCtrl.text.trim(),
        'skills': _splitCsv(_skillsCtrl.text),
        'languages': _splitCsv(_languagesCtrl.text),
        'experience': _experienceCtrl.text.trim(),
        // Extra profile context so the summary reflects the whole dossier.
        if (_targetLevel.isNotEmpty) 'targetLevel': _targetLevel,
        if (_residenceCtrl.text.trim().isNotEmpty)
          'countryOfResidence': _residenceCtrl.text.trim(),
        if (_objectiveCtrl.text.trim().isNotEmpty)
          'objective': _objectiveCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _aiSummaryFr = result['fr'] as String? ?? '';
          _aiSummaryEn = result['en'] as String? ?? '';
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (isAiConsentRequiredError(error)) {
        final granted = await ensureAiConsent(context, _ctrl);
        if (granted && mounted) {
          return _generateSummary();
        }
        return;
      }
      if (mounted) {
        KpbToast.error(aiErrorMessage(error), context: context);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<String> _splitCsv(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // ── KPB brand colours for the PDF ──────────────────────────────────────────
  static const _kpbBlue = PdfColor.fromInt(0xFF004AAD);
  static const _kpbBlueBg = PdfColor.fromInt(0xFFE8F0FA);
  static const _darkText = PdfColor.fromInt(0xFF111827);
  static const _mutedText = PdfColor.fromInt(0xFF6B7280);

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final en = _useEnglish;

    // Everything below goes through pdfSafe*: the built-in Helvetica has no
    // glyph above U+00FF, so emoji (from translations, catalogue labels, text
    // typed by the student or the AI summary) and typographic punctuation would
    // be drawn as empty boxes. See pdf_text.dart.
    final summary = pdfSafeText(_useEnglish
        ? (_aiSummaryEn.isNotEmpty ? _aiSummaryEn : _aiSummaryFr)
        : (_aiSummaryFr.isNotEmpty ? _aiSummaryFr : _aiSummaryEn));

    final name = pdfSafeText(_nameCtrl.text);
    final email = pdfSafeText(_emailCtrl.text);
    final phone = pdfSafeText(_phoneCtrl.text);
    final whatsApp = pdfSafeText(_whatsApp);
    final residence = pdfSafeText(_residenceCtrl.text);
    final targetCountry = pdfSafeText(_countryCtrl.text);
    final headline = pdfSafeJoin([_levelCtrl.text, _fieldCtrl.text]);
    final objective = pdfSafeText(_objectiveCtrl.text);

    final skills = pdfSafeCsv(_skillsCtrl.text);
    final languages = pdfSafeCsv(_languagesCtrl.text);
    final experiences = pdfSafeLines(_experienceCtrl.text);

    // Education details that live on the profile but have no form field.
    final educationDetails = <String>[
      if (_bacSeries.isNotEmpty)
        '${en ? "Bac series" : "Série du bac"} : ${pdfSafeText(_bacSeries)}',
      if (_gradeRange.isNotEmpty)
        '${en ? "Academic results" : "Résultats"} : '
            '${pdfSafeText(_gradeRange)}',
      if (_languageLevel.isNotEmpty)
        '${en ? "Language level" : "Niveau de langue"} : '
            '${pdfSafeText(_languageLevel)}',
      if (targetCountry.isNotEmpty)
        '${en ? "Target country" : "Pays cible"} : $targetCountry',
      if (_targetLevel.isNotEmpty)
        '${en ? "Target degree" : "Diplôme visé"} : '
            '${pdfSafeText(_targetLevel)}',
    ];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── LEFT SIDEBAR (blue) ──────────────────────────────────────────
            pw.Container(
              width: 190,
              height: double.infinity,
              color: _kpbBlue,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Initials circle
                  pw.Center(
                    child: pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _initials(name),
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: _kpbBlue,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // Contact
                  _sidebarSection('CONTACT'),
                  if (email.isNotEmpty) _sidebarItem(email),
                  if (phone.isNotEmpty) _sidebarItem(phone),
                  if (whatsApp.isNotEmpty && whatsApp != phone)
                    _sidebarItem('WhatsApp : $whatsApp'),
                  // A CV states where the candidate lives; the target country
                  // belongs to the education/objective block below.
                  if (residence.isNotEmpty) _sidebarItem(residence),
                  pw.SizedBox(height: 16),

                  // Languages
                  if (languages.isNotEmpty) ...[
                    _sidebarSection(en ? 'LANGUAGES' : 'LANGUES'),
                    ...languages.map((l) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(children: [
                            pw.Container(
                              width: 6,
                              height: 6,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.white,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Expanded(
                              child: pw.Text(
                                l,
                                style: const pw.TextStyle(
                                    fontSize: 9, color: PdfColors.white),
                              ),
                            ),
                          ]),
                        )),
                    pw.SizedBox(height: 16),
                  ],

                  // Skills as tags
                  if (skills.isNotEmpty) ...[
                    _sidebarSection(en ? 'SKILLS' : 'COMPÉTENCES'),
                    pw.Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: skills
                          .map((s) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(10),
                                ),
                                child: pw.Text(
                                  s,
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: _kpbBlue,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // ── RIGHT MAIN CONTENT ───────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Name & title
                    pw.Text(
                      name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      headline,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: _kpbBlue,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(height: 3, width: 50, color: _kpbBlue),
                    pw.SizedBox(height: 18),

                    // Summary
                    if (summary.isNotEmpty) ...[
                      _mainSection(en ? 'PROFESSIONAL SUMMARY' : 'PROFIL'),
                      pw.Text(
                        summary,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: _darkText,
                          lineSpacing: 4,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                    ],

                    // Education — skipped entirely rather than printing an
                    // empty blue box when the profile has nothing to say.
                    if (headline.isNotEmpty || educationDetails.isNotEmpty) ...[
                      _mainSection(en ? 'EDUCATION' : 'FORMATION'),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: _kpbBlueBg,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (headline.isNotEmpty)
                              pw.Text(
                                headline,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _darkText,
                                ),
                              ),
                            ...educationDetails.map(
                              (detail) => pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  detail,
                                  style: const pw.TextStyle(
                                    fontSize: 9,
                                    color: _mutedText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 16),
                    ],

                    // Experience
                    if (experiences.isNotEmpty) ...[
                      _mainSection(en ? 'EXPERIENCE' : 'EXPÉRIENCE'),
                      ...experiences.map((exp) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  width: 6,
                                  height: 6,
                                  margin: const pw.EdgeInsets.only(top: 3),
                                  decoration: pw.BoxDecoration(
                                    color: _kpbBlue,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Expanded(
                                  child: pw.Text(
                                    exp,
                                    style: const pw.TextStyle(
                                      fontSize: 9.5,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      pw.SizedBox(height: 16),
                    ],

                    // Objective
                    if (objective.isNotEmpty) ...[
                      _mainSection(
                          en ? 'CAREER OBJECTIVE' : 'OBJECTIF PROFESSIONNEL'),
                      pw.Text(
                        objective,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: _darkText,
                          lineSpacing: 4,
                        ),
                      ),
                    ],

                    pw.Spacer(),

                    // Footer
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        // "Généré" is safe now: é is WinAnsi 0xE9. Only code
                        // points above U+00FF are unrenderable.
                        en
                            ? 'Generated with KPB Education'
                            : 'Généré avec KPB Education',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: _mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: _pdfFileName(name),
    );
  }

  /// ASCII-only, emoji-free file name — a share sheet / mail client should
  /// never receive `CV_🎓.pdf`, and an empty name must not yield `CV_.pdf`.
  String _pdfFileName(String sanitizedName) {
    final slug = sanitizedName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'CV_KPB.pdf' : 'CV_$slug.pdf';
  }

  /// Initials for the avatar circle. [name] is already PDF-sanitized, so it can
  /// be empty (or emoji-only before sanitising) — never index blindly.
  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  pw.Widget _sidebarSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1, width: 30, color: PdfColors.white),
          ],
        ),
      );

  pw.Widget _sidebarItem(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
          maxLines: 2,
        ),
      );

  pw.Widget _mainSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 14, color: _kpbBlue),
          pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _kpbBlue,
              letterSpacing: 1,
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('cv_generator_title'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          // ── Intro ──────────────────────────────────────────────────────────
          Text(
            'cv_generator_intro'.tr,
            style: TextStyle(
              fontSize: 14,
              color: context.kpb.textMuted,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          const AiDisclosureBanner(),
          if (widget.fromEefHub) ...[
            const SizedBox(height: KpbSpacing.sm),
            const EefHelpLine(trigger: EefHelpTrigger.toolCv),
          ],
          const SizedBox(height: KpbSpacing.lg),

          // ── Form fields ────────────────────────────────────────────────────
          _field('cv_field_full_name'.tr, _nameCtrl),
          _field('Email', _emailCtrl),
          _field('cv_field_phone'.tr, _phoneCtrl),
          _field('cv_field_study_level'.tr, _levelCtrl),
          _field('cv_field_field_of_study'.tr, _fieldCtrl),
          // Prefilled from the profile; editable because it is printed in the
          // CV contact block.
          // 'Residence' is the accent-free, FR/EN-readable fallback used until
          // the `cv_field_residence` key lands in app_translations.dart.
          _field(
              _trOrNull('cv_field_residence') ?? 'Residence', _residenceCtrl),
          _field('cv_field_target_country'.tr, _countryCtrl),
          _field('cv_field_skills'.tr, _skillsCtrl),
          _field('cv_field_languages'.tr, _languagesCtrl),
          _field('cv_field_experience'.tr, _experienceCtrl, maxLines: 3),
          _field('cv_field_objective'.tr, _objectiveCtrl, maxLines: 2),

          const SizedBox(height: KpbSpacing.lg),

          // ── AI summary button ──────────────────────────────────────────────
          KpbButton(
            label: _isGenerating ? 'cv_generating'.tr : 'cv_enhance_with_ai'.tr,
            icon: Icons.auto_awesome_rounded,
            onTap: _isGenerating ? null : _generateSummary,
          ),

          // ── AI result preview ──────────────────────────────────────────────
          if (_aiSummaryFr.isNotEmpty || _aiSummaryEn.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.lg),
            Row(
              children: [
                Text(
                  'cv_ai_summary_heading'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text('FR'),
                  selected: !_useEnglish,
                  onSelected: (_) => setState(() => _useEnglish = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('EN'),
                  selected: _useEnglish,
                  onSelected: (_) => setState(() => _useEnglish = true),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                borderRadius: KpbRadius.lgBr,
                border:
                    Border.all(color: KpbColors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                _useEnglish
                    ? (_aiSummaryEn.isNotEmpty ? _aiSummaryEn : _aiSummaryFr)
                    : (_aiSummaryFr.isNotEmpty ? _aiSummaryFr : _aiSummaryEn),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: context.kpb.textPrimary,
                ),
              ),
            ),
          ],

          const SizedBox(height: KpbSpacing.xl),

          // ── Export PDF button ───────────────────────────────────────────────
          KpbButton(
            label: 'cv_export_pdf'.tr,
            icon: Icons.picture_as_pdf_rounded,
            secondary: true,
            onTap: _exportPdf,
          ),

          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
