import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/utils/ai_error_message.dart';
import '../../core/utils/share_origin.dart';
import '../ai_advisor/ai_consent.dart';
import '../ai_advisor/ai_disclosure_banner.dart';
import '../etudes_en_france/eef_help_line.dart';
import 'motivation_letter_templates.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

/// Motivation Letters — browse templates, personalise with AI (FR + EN).
class MotivationLettersScreen extends StatefulWidget {
  const MotivationLettersScreen({super.key, this.fromEefHub = false});

  /// `true` UNIQUEMENT quand l'écran est ouvert depuis le hub de l'espace « Études
  /// en France » : une ligne « Besoin d'aide pour ta lettre de motivation ? »
  /// ouvre alors WhatsApp vers le conseiller, en tête de la liste des modèles.
  /// Ailleurs (boîte à outils, tiroir, coach), rien ne change. Un paramètre
  /// explicite plutôt qu'un état global.
  final bool fromEefHub;

  @override
  State<MotivationLettersScreen> createState() =>
      _MotivationLettersScreenState();
}

class _MotivationLettersScreenState extends State<MotivationLettersScreen> {
  String _selectedCategory = 'all';

  List<LetterTemplate> get _filtered => _selectedCategory == 'all'
      ? kLetterTemplates
      : kLetterTemplates.where((t) => t.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: KpbColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: KpbColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 19, color: KpbColors.brandNavy),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'letters_title'.tr,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: KpbColors.brandNavy,
                          ),
                        ),
                        Text(
                          'letters_header_subtitle'.tr,
                          style: const TextStyle(
                              fontSize: 11.5, color: KpbColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AiDisclosureBanner(),
            ),

            // ── Category chips ────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _chip('all', 'letters_filter_all'.tr),
                  ...kLetterCategories.map(
                    (c) => _chip(c, categoryLabelFr(c)),
                  ),
                ],
              ),
            ),

            // ── Templates list ────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                // La ligne d'aide est le PREMIER élément de la liste, pas une
                // bande fixe au-dessus : elle défile avec les modèles au lieu de
                // manger de la hauteur en permanence.
                itemCount: _filtered.length + (widget.fromEefHub ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  if (widget.fromEefHub) {
                    if (i == 0) {
                      return const EefHelpLine(
                        trigger: EefHelpTrigger.toolLetters,
                      );
                    }
                    return _LetterCard(template: _filtered[i - 1]);
                  }
                  return _LetterCard(template: _filtered[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? KpbColors.actionPrimarySoft : KpbColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected
                  ? KpbColors.actionPrimary.withValues(alpha: 0.3)
                  : KpbColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? KpbColors.actionPrimary : KpbColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single letter card — expand to preview, personalise with AI
// ─────────────────────────────────────────────────────────────────────────────

class _LetterCard extends StatefulWidget {
  const _LetterCard({required this.template});
  final LetterTemplate template;

  @override
  State<_LetterCard> createState() => _LetterCardState();
}

class _LetterCardState extends State<_LetterCard> {
  final _ctrl = Get.find<AppController>();
  final _strengthsCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  bool _expanded = false;
  bool _isPersonalizing = false;
  String _personalizedFr = '';
  String _personalizedEn = '';
  bool _showEnglish = false;

  bool get _hasPersonalized =>
      _personalizedFr.isNotEmpty || _personalizedEn.isNotEmpty;

  @override
  void dispose() {
    _strengthsCtrl.dispose();
    _eventCtrl.dispose();
    super.dispose();
  }

  IconData get _categoryIcon {
    switch (widget.template.category) {
      case 'admission':
        return Icons.school_rounded;
      case 'scholarship':
        return Icons.emoji_events_rounded;
      case 'visa':
        return Icons.flight_takeoff_rounded;
      case 'internship':
        return Icons.work_outline_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Future<void> _personalize() async {
    setState(() => _isPersonalizing = true);
    try {
      final p = _ctrl.profile;
      final fieldId = p?.fieldIds.isNotEmpty == true ? p!.fieldIds.first : '';
      final field = _ctrl.fields
              .where((f) => f.id == fieldId)
              .map((f) => _ctrl.resolve(f.name))
              .firstOrNull ??
          '';
      final targetId = p?.targetCountryIds.isNotEmpty == true
          ? p!.targetCountryIds.first
          : '';
      final country = _ctrl.countries
              .where((c) => c.id == targetId)
              .map((c) => _ctrl.resolve(c.name))
              .firstOrNull ??
          '';

      // Leading slash required: Dio concatenates `baseUrl + path`, and the base
      // ends with `/api`, so 'tools/…' resolved to `/apitools/…` → 404.
      final result = await _ctrl.apiClient.postAi('/tools/personalize-letter', {
        'templateKey': widget.template.key,
        'templateBody': widget.template.bodyFr,
        // No `name`: the server never put it in the prompt (IA-T2) and has no
        // other use for it, so it no longer leaves the device at all.
        'fieldOfStudy': field,
        'targetCountry': country,
        'strengths': _strengthsCtrl.text.trim(),
        'keyEvent': _eventCtrl.text.trim(),
      });

      if (mounted) {
        setState(() {
          _personalizedFr = result['fr'] as String? ?? '';
          _personalizedEn = result['en'] as String? ?? '';
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (isAiConsentRequiredError(error)) {
        final granted = await ensureAiConsent(context, _ctrl);
        if (granted && mounted) {
          return _personalize();
        }
        return;
      }
      if (mounted) {
        KpbToast.error(aiErrorMessage(error), context: context);
      }
    } finally {
      if (mounted) setState(() => _isPersonalizing = false);
    }
  }

  String get _displayText {
    if (_hasPersonalized) {
      return _showEnglish
          ? (_personalizedEn.isNotEmpty ? _personalizedEn : _personalizedFr)
          : (_personalizedFr.isNotEmpty ? _personalizedFr : _personalizedEn);
    }
    return widget.template.bodyFr;
  }

  @override
  Widget build(BuildContext context) {
    final titlePrimary = _ctrl.localeCode == 'en'
        ? widget.template.titleEn
        : widget.template.titleFr;
    final titleSecondary = _ctrl.localeCode == 'en'
        ? widget.template.titleFr
        : widget.template.titleEn;

    return Container(
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon,
                      color: KpbColors.actionPrimary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titlePrimary,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                      Text(
                        titleSecondary,
                        style: const TextStyle(
                            fontSize: 11.5, color: KpbColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: KpbColors.textFaint,
                ),
              ],
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            const SizedBox(height: 12),

            // Language toggle + personalized badge (only if personalised)
            if (_hasPersonalized) ...[
              Row(
                children: [
                  _langChip('FR', !_showEnglish,
                      () => setState(() => _showEnglish = false)),
                  const SizedBox(width: 8),
                  _langChip('EN', _showEnglish,
                      () => setState(() => _showEnglish = true)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KpbColors.actionPrimarySoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'letters_personalized_badge'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: KpbColors.actionPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Letter body — the "editor" card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KpbColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KpbColors.border),
              ),
              child: SelectableText(
                _displayText,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: KpbColors.gray700,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Guided inputs — fed to the AI personalize call ────────────────
            _guidedField(
              controller: _strengthsCtrl,
              label: 'letters_field_strengths'.tr,
              hint: 'letters_field_strengths_hint'.tr,
            ),
            const SizedBox(height: 12),
            _guidedField(
              controller: _eventCtrl,
              label: 'letters_field_event'.tr,
              hint: 'letters_field_event_hint'.tr,
            ),

            const SizedBox(height: 14),

            // Action row — real generate/regenerate + real copy + real share
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isPersonalizing ? null : _personalize,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _isPersonalizing
                            ? KpbColors.actionPrimary.withValues(alpha: 0.6)
                            : KpbColors.actionPrimary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isPersonalizing
                                  ? 'letters_personalizing'.tr
                                  : (_hasPersonalized
                                      ? 'letters_regenerate'.tr
                                      : 'letters_adapt_to_profile'.tr),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _iconSquare(
                  icon: Icons.copy_rounded,
                  tooltip: 'letters_copy_tooltip'.tr,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _displayText));
                    KpbToast.success(
                      'letters_copied_snackbar'.tr,
                      context: context,
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Design's dark "Export" pill → the REAL share sheet.
                Semantics(
                  button: true,
                  label: 'letters_share_tooltip'.tr,
                  child: GestureDetector(
                    onTap: () => kpbShare(context, text: _displayText),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: KpbColors.brandNavy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.ios_share_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'letters_export'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _guidedField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: KpbColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 12.5, color: KpbColors.gray700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: KpbColors.textFaint),
            filled: true,
            fillColor: KpbColors.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KpbColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KpbColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: KpbColors.actionPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _langChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? KpbColors.actionPrimary : KpbColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? KpbColors.actionPrimary : KpbColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : KpbColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: KpbColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: KpbColors.textMuted, size: 19),
        ),
      ),
    );
  }
}
