import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/share_card_service.dart';
import '../../core/ui/components/log_once.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/ui/components/program_intake_line.dart';
import '../../core/ui/components/source_link.dart';
import '../../core/ui/components/verified_badge.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/share_link.dart';
import '../../core/utils/study_level.dart';
import '../../core/utils/tuition_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_tunnel_flow.dart';
import '../search/match_explanation_sheet.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/utils/external_link.dart';
import '../../core/utils/intake_label.dart';
import '../../core/ui/components/kpb_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · Student App.dc.html · "Fiche université").
// Local to this file — same pattern as Home/Onboarding.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  // Accent décoratif du cœur « favori » (red-300 du handoff) —
  // exception documentée dans docs/theme-color-allowlist.md.
  static const heartPink = Color(0xFFFCA5A5); // kpb-allow-color: accent favori
}

/// One-line description of a fit tier — describes the profile match, never
/// the odds of being admitted.
String _zoneLabel(ProfileFit? fit) => switch (fit) {
      ProfileFit.strong => 'match_zone_strong'.tr,
      ProfileFit.good => 'match_zone_good'.tr,
      ProfileFit.explore => 'match_zone_stretch'.tr,
      null => 'match_zone_no_profile'.tr,
    };

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final program = controller.programByIdOrNull(programId);
    if (program == null) {
      return Scaffold(
        backgroundColor: KpbColors.canvas,
        body: Center(child: Text('program_not_found'.tr)),
      );
    }

    final institution = controller.institutionByIdOrNull(program.institutionId);
    final country = controller.countryByIdOrNull(program.countryId);

    final level = programLevelLabel(controller.resolve(program.level));
    final city =
        institution != null ? controller.resolve(institution.location) : '';
    final tuition = controller.resolve(program.tuition);
    final displayedTuition = TuitionUtils.tuitionForDisplay(
      tuition,
      controller.profile?.preferredCurrency,
    );
    final language = controller.resolve(program.language);

    // No dedicated "deadline" field exists on the catalog → surface the real
    // intake instead (never fabricate a date).
    final intake =
        country != null ? controller.resolve(country.nextIntakeLabel) : '';
    final intakeValue = intake.isNotEmpty
        ? intake
        : (institution != null && institution.intakePeriods.isNotEmpty
            ? institution.intakePeriods.join(' · ')
            : 'school_intake_on_request'.tr);

    final description =
        institution != null ? controller.resolve(institution.overview) : '';
    // Une formation peut avoir deux offres sur le même campus (rentrée
    // d'automne et rentrée décalée) : on compte les CAMPUS, et on range les
    // offres par campus puis par date.
    final offerings = sortedOfferings(program.campusOfferings);
    final campusCount = distinctCampusCount(offerings);
    final recognition = program.recognition != null
        ? controller.resolve(program.recognition!)
        : '';
    final fit = controller.programFit(program);

    final applicationSteps = [
      'program_step_eligibility_choice'.tr,
      'program_step_build_file'.tr,
      'program_step_submission'.tr,
      'program_step_admission_letter'.tr,
      'program_step_visa_departure'.tr,
    ];

    // Une fois par ouverture de la fiche, pas à chaque reconstruction.
    return LogOnce(
      onFirstMount: () =>
          unawaited(AnalyticsService.instance.logViewProgram(programId)),
      child: Scaffold(
        backgroundColor: KpbColors.canvas,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              controller: controller,
              program: program,
              institution: institution,
              flag: countryFlag(program.countryId),
              name: controller.resolve(program.name),
              subtitle: city.isNotEmpty ? '$level · $city' : level,
              fit: fit,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2-col grid — real tuition + intake/language. IntrinsicHeight
                  // gives the stretch Row a bounded height inside the ListView.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'school_fees_per_year'.tr,
                            // `tuitionForDisplay` rend au minimum l'étiquette :
                            // le seul repli restant est l'étiquette VIDE.
                            value: displayedTuition.isNotEmpty
                                ? displayedTuition
                                : 'school_intake_on_request'.tr,
                            sub: '',
                            subColor: KpbColors.actionPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'school_intake'.tr,
                            value: intakeValue,
                            sub: language.isNotEmpty
                                ? '${'program_language'.tr}: $language'
                                : '',
                            subColor: KpbColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.65,
                              color: KpbColors.gray700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              VerifiedBadge(
                                  lastVerifiedAt: program.lastVerifiedAt),
                              KpbSourceLink(url: program.sourceUrl),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (recognition.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    _Section(
                      title: 'program_recognition'.tr,
                      icon: Icons.workspace_premium_outlined,
                      child: Text(
                        recognition,
                        style: const TextStyle(
                          fontSize: KpbFontSize.sm,
                          height: 1.55,
                          color: KpbColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (offerings.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    _Section(
                      title: campusCount == 1
                          ? 'program_available_on_one_campus'.tr
                          : 'program_available_on_campuses'
                              .trParams({'count': '$campusCount'}),
                      icon: Icons.location_city_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < offerings.length; i++) ...[
                            if (i > 0) const Divider(height: 18),
                            _CampusOfferingRow(
                              offering: offerings[i],
                              localeCode: controller.localeCode,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (program.requirements.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    _Section(
                      title: 'program_admission_requirements'.tr,
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: program.requirements
                            .map(
                              (req) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16, color: KpbColors.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        controller.resolve(req),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          height: 1.55,
                                          color: KpbColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  _Section(
                    title: 'program_application_process'.tr,
                    icon: Icons.route_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < applicationSteps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _StepRow(index: i + 1, text: applicationSteps[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Primary CTA — creates a KPB application case (dossier).
                  _PrimaryCta(
                    label: 'create_application'.tr,
                    icon: Icons.create_new_folder_rounded,
                    onTap: () => _openCaseTunnel(
                      context,
                      controller,
                      program,
                      institution,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Secondary CTA — WhatsApp hand-off to a KPB counselor.
                  // Deliberately NOT overridden by the country's catalog-level
                  // `whatsAppPrefill`: on a program sheet the advisor must see
                  // which program/school the student was reading, and the
                  // country-level copy is generic (owner video review, 08/2026).
                  _CounselorCta(
                    onTap: () => openWhatsAppOrToast(
                      prefill: kpbWhatsAppPrefill(
                        program: controller.resolve(program.name),
                        institution: institution != null
                            ? controller.resolve(institution.name)
                            : null,
                        country: country != null
                            ? controller.resolve(country.name)
                            : null,
                      ),
                      source: 'program_detail',
                      contextType: 'program',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark navy header — back / share / save, identity, and the match-explain card.
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.program,
    required this.institution,
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.fit,
  });

  final AppController controller;
  final ProgramModel program;
  final InstitutionModel? institution;
  final String flag;
  final String name;
  final String subtitle;

  /// Null without a student profile.
  final ProfileFit? fit;

  /// Present the shareable profile-match card (App-engagement handoff). Every
  /// value is real: the fit tier comes from the live
  /// [AppController.institutionFit] for the institution whose detail launched
  /// this (falling back to the program fit when no institution is attached),
  /// the name/flag from the real institution/country, the student first name
  /// from the real profile, and the brand line from [AppConfig].
  void _share(BuildContext context, ProfileFit shareFit) {
    final schoolName =
        institution != null ? controller.resolve(institution!.name) : name;
    final firstName = _firstName(controller.profile?.fullName);

    showDialog<void>(
      context: context,
      barrierColor: KpbColors.brandNavy.withValues(alpha: 0.65),
      builder: (_) => _ShareMatchCard(
        flag: flag,
        fit: shareFit,
        zoneLabel: _zoneLabel(shareFit),
        schoolName: schoolName,
        studentLine: 'match_card_applying_via'.trParams({'name': firstName}),
      ),
    );
  }

  /// First token of the profile's full name, or a neutral fallback (never a
  /// hardcoded placeholder name).
  static String _firstName(String? fullName) {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isEmpty) return 'match_card_student_fallback'.tr;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final saved = controller.isSaved(SavedItemType.program, program.id);
    final shareFit =
        institution != null ? controller.institutionFit(institution!) : fit;

    return Container(
      color: KpbColors.brandNavy,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Get.back(),
              ),
              const Spacer(),
              // Rien de personnel à partager sans profil : pas de carte.
              if (shareFit != null) ...[
                _RoundButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _share(context, shareFit),
                  semanticLabel: 'a11y_share'.tr,
                ),
                const SizedBox(width: 10),
              ],
              _RoundButton(
                icon: saved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: _Palette.heartPink,
                onTap: () =>
                    controller.toggleSaved(SavedItemType.program, program.id),
                semanticLabel: 'a11y_save'.tr,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: KpbColors.textFaint,
                      ),
                    ),
                    // Les rentrées disponibles de la formation, en résumé,
                    // avant le détail par campus plus bas.
                    const SizedBox(height: 6),
                    ProgramIntakeLine(
                      program: program,
                      institution: institution,
                      color: KpbColors.decorSky,
                      localeCode: controller.localeCode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showMatchExplanation(
              context,
              name,
              fit,
              controller.matchExplanation(SearchResultType.program, program.id),
              controller,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  if (fit != null) ...[
                    ProfileFitBadge(fit: fit!, fontSize: 13),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _zoneLabel(fit),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'match_zone_tap_hint'.tr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: KpbColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_less_rounded,
                      size: 18, color: KpbColors.decorSky),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable cards + rows.
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: KpbColors.actionPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: KpbColors.textFaint,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: subColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: KpbColors.actionPrimarySoft,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.actionPrimary,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: KpbColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CampusOfferingRow extends StatelessWidget {
  const _CampusOfferingRow({
    required this.offering,
    required this.localeCode,
  });

  final CampusOffering offering;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    // « Rentrée décalée · mars 2027 · Alternance » : la rentrée en toutes
    // lettres, puis le rythme quand la source le donne.
    final details = [
      offeringIntakeLabel(offering, localeCode),
      offeringRhythmLabel(offering),
    ].whereType<String>().join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined,
            size: 18, color: KpbColors.actionPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offering.campus,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
              if (details.isNotEmpty)
                Text(
                  details,
                  style:
                      const TextStyle(fontSize: 11, color: KpbColors.textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          offering.tuitionLabel(localeCode),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: KpbColors.actionPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTAs.
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: KpbColors.actionPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: KpbColors.actionPrimary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounselorCta extends StatelessWidget {
  const _CounselorCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: KpbColors.success.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_rounded, size: 17, color: KpbColors.whatsapp),
            const SizedBox(width: 8),
            Text(
              'ask_kpb_counselor'.tr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: KpbColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Case tunnel — creates a KPB application dossier (unchanged flow).
// ─────────────────────────────────────────────────────────────────────────────
void _openCaseTunnel(
  BuildContext context,
  AppController controller,
  ProgramModel program,
  InstitutionModel? institution,
) {
  final prefill = CaseTunnelPrefill(
    title: controller.resolve(program.name),
    contextLabel: institution != null
        ? controller.resolve(institution.name)
        : controller.resolve(program.name),
    initialType: CaseType.applicationSupport,
    countryId: program.countryId,
    institutionId: program.institutionId,
    programId: program.id,
  );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (_, __) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: CaseTunnelFlow(
          prefill: prefill,
          onClose: () => Navigator.pop(ctx),
          onSubmitted: () {
            Navigator.pop(ctx);
            KpbToast.success('request_submitted'.tr);
          },
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shareable match card (App-engagement handoff · "Carte de match partageable").
//
// A centered dark-gradient card over a dim scrim. The card is wrapped in a
// [RepaintBoundary] so "Download" can rasterise exactly what is shown to a PNG
// and hand it to the OS share sheet (reusing `share_plus`, no new packages).
// "Share on WhatsApp" routes real result copy through the same wa.me pattern the
// referral loop uses. All figures are real (see `_share`).
// ─────────────────────────────────────────────────────────────────────────────
class _ShareMatchCard extends StatefulWidget {
  const _ShareMatchCard({
    required this.flag,
    required this.fit,
    required this.zoneLabel,
    required this.schoolName,
    required this.studentLine,
  });

  final String flag;
  final ProfileFit fit;
  final String zoneLabel;
  final String schoolName;
  final String studentLine;

  @override
  State<_ShareMatchCard> createState() => _ShareMatchCardState();
}

class _ShareMatchCardState extends State<_ShareMatchCard> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  /// KPB-165: the caller's referral code, so a shared card credits them. Loaded
  /// best-effort — a card without it is still worth sharing, so a failure here
  /// never blocks the share (the link simply carries no `ref`).
  String? _referralCode;

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    try {
      final data = await Get.find<AppController>().apiClient.getMyReferral();
      final code = (data['code'] as String?)?.trim();
      if (mounted && (code ?? '').isNotEmpty) {
        setState(() => _referralCode = code);
      }
    } catch (_) {
      // No code available — share without attribution rather than not at all.
    }
  }

  String _shareText() {
    final link = buildInviteLink(
      source: ShareSource.match,
      referralCode: _referralCode,
    );
    return 'match_card_whatsapp_prefill'.trParams({
      'fit': widget.fit.labelKey.tr,
      'school': widget.schoolName,
      'domain': AppConfig.brandDomain,
      'link': link,
    });
  }

  Future<void> _shareWhatsApp() async {
    final text = _shareText();
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await kpbOpenExternalUrl(waUri)) {
      unawaited(AnalyticsService.instance.logShareCard(
        source: ShareSource.match.wireName,
        withImage: false,
        success: true,
      ));
    } else {
      // WhatsApp unavailable → OS share sheet with the same message.
      await SharePlus.instance.share(ShareParams(text: text));
      unawaited(AnalyticsService.instance.logShareCard(
        source: ShareSource.match.wireName,
        withImage: false,
        success: true,
      ));
    }
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // KPB-165: shared render + share + analytics, identical for every result
      // card. Falls back to a text-only share (still carrying the invite link)
      // when the PNG can't be produced, and reports that in the event.
      final withImage = await ShareCardService.instance.shareBoundary(
        boundaryKey: _cardKey,
        text: _shareText(),
        source: ShareSource.match,
      );
      if (!withImage && mounted) {
        KpbToast.error('match_card_share_error'.tr);
      }
      if (mounted) unawaited(Navigator.of(context).maybePop());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(key: _cardKey, child: _card()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 14,
                  child: _ActionButton(
                    bg: KpbColors.whatsapp,
                    fg: Colors.white,
                    icon: Icons.chat_rounded,
                    label: 'match_card_share_whatsapp'.tr,
                    onTap: _busy ? null : _shareWhatsApp,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: _ActionButton(
                    bg: Colors.white,
                    fg: KpbColors.brandNavy,
                    icon: Icons.download_rounded,
                    label: 'match_card_download'.tr,
                    busy: _busy,
                    onTap: _busy ? null : _download,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KpbColors.brandNavy, KpbColors.heroIndigo],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KpbColors.brandNavy.withValues(alpha: 0.5),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'match_card_eyebrow'.tr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: KpbColors.decorSky,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(widget.flag, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.fit.labelKey.tr,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.zoneLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.decorSky,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.schoolName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.studentLine,
            style: const TextStyle(fontSize: 11, color: KpbColors.textFaint),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            '${AppConfig.brandDomain} · ${'match_card_domain_tagline'.tr}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: KpbColors.decorSky,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: 16, color: fg),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
