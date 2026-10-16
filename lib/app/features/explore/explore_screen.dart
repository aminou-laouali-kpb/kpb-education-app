import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/commons_logo.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/external_link.dart';
import '../cases/case_composer_sheet.dart';
import 'country_detail_screen.dart';
import 'program_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Country flag lookup (shared with home)
// ─────────────────────────────────────────────────────────────────────────────
String _flag(String id) => countryFlag(id);

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Pays — grille avec drapeaux
// ─────────────────────────────────────────────────────────────────────────────
class CountriesCatalogGrid extends StatelessWidget {
  const CountriesCatalogGrid({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final countries = controller.countries;

    if (countries.isEmpty) {
      return KpbEmptyState(
        icon: Icons.public_outlined,
        title: 'explore_no_countries_title'.tr,
        subtitle: 'explore_no_countries_body'.tr,
      );
    }

    // "Onglet pays" (handoff): a subtitle, a vertical list of dark navy country
    // guide cards, and a closing "more coming" tip card.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: countries.length + 2,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 11 : 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'dest_list_subtitle'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: KpbColors.textMuted,
            ),
          );
        }
        if (index == countries.length + 1) {
          return const _MoreDestinationsTip();
        }

        final country = countries[index - 1];
        final intake = controller.resolve(country.nextIntakeLabel);
        final tuition = controller.resolve(country.tuitionRange);
        final popularFields = country.popularFieldIds.take(2).map((id) {
          try {
            return controller.resolve(controller.fieldById(id).name);
          } catch (_) {
            return id;
          }
        }).toList();
        // Bind the most useful real field available as the card subtitle.
        final subtitle = intake.isNotEmpty
            ? intake
            : tuition.isNotEmpty
                ? tuition
                : popularFields.join(' · ');

        return _CountryGuideCard(
          flag:
              displayCountryFlag(id: country.id, flagEmoji: country.flagEmoji),
          name: controller.resolve(country.name),
          subtitle: subtitle,
          onTap: () => Get.to(() => CountryDetailScreen(countryId: country.id)),
        );
      },
    );
  }
}

/// Dark navy "country guide" row (App-engagement handoff). Flag + name +
/// real-data subtitle + a GUIDE → affordance; opens the full country guide.
class _CountryGuideCard extends StatelessWidget {
  const _CountryGuideCard({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: KpbColors.textFaint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'guide_short'.tr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.decorSky,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: KpbColors.decorSky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Closing tip card: honest "more destinations coming" note (no fabricated
/// countries), matching the handoff's "Onglet pays" footer.
class _MoreDestinationsTip extends StatelessWidget {
  const _MoreDestinationsTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              size: 18, color: KpbColors.actionPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'dest_more_coming_tip'.tr,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: KpbColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the institution detail sheet. Public so other surfaces (e.g. the
/// post-decision plan B list) can deep-link into the same real detail view.
void openInstitutionDetail(
  BuildContext context,
  InstitutionModel institution,
  AppController controller,
) {
  unawaited(AnalyticsService.instance.logViewInstitution(institution.id));
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _InstitutionDetailSheet(
      institution: institution,
      controller: controller,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers for detail sheets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: KpbColors.blue),
        const SizedBox(width: 8),
        Text(title, style: KpbTextStyles.titleMd),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Institution Detail Sheet — Conversion Funnel
// ─────────────────────────────────────────────────────────────────────────────
class _InstitutionDetailSheet extends StatelessWidget {
  const _InstitutionDetailSheet({
    required this.institution,
    required this.controller,
  });

  final InstitutionModel institution;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final fit = controller.institutionFit(institution);
    final logoUrl = commonsRasterDisplayUrl(institution.logoUrl);
    final showLogoCredit = logoRequiresAttribution(institution.logoLicence) &&
        isOpenableWebUrl(institution.logoSourceUrl);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.kpb.pageBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kpb.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
                children: [
                  // Hero Card
                  GradientHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (logoUrl != null) ...[
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: KpbNetworkImage(
                                  imageUrl: logoUrl,
                                  fit: BoxFit.contain,
                                  width: 32,
                                  height: 32,
                                  targetWidth: 40,
                                  decorative: false,
                                  errorIcon: Icons.account_balance_outlined,
                                ),
                              ),
                            ],
                            Text(_flag(institution.countryId),
                                style: const TextStyle(fontSize: 32)),
                            const Spacer(),
                            if (institution.isPartner)
                              KpbBadge(
                                label: 'badge_official_partner'.tr,
                                color: Colors.white.withValues(alpha: 0.2),
                                icon: Icons.verified_rounded,
                                small: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.resolve(institution.name),
                          style: KpbTextStyles.displaySm
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.resolve(institution.location),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                        if (showLogoCredit) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => kpbOpenExternalUrlString(
                              institution.logoSourceUrl,
                            ),
                            child: Text(
                              'Logo · ${institution.logoLicence} · Wikimedia Commons',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.lg),

                  // Profile fit — was a hard-coded « 85 % » gauge.
                  if (fit != null) ...[
                    ProfileFitBadge(fit: fit, fontSize: 14),
                    const SizedBox(height: KpbSpacing.lg),
                  ],

                  // Overview
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                            title: 'institution_overview'.tr,
                            icon: Icons.info_outline_rounded),
                        const SizedBox(height: 8),
                        Text(
                          controller.resolve(institution.overview),
                          style: KpbTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.md),

                  // Details
                  Row(
                    children: [
                      Expanded(
                        child: KpbCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('fees_per_year'.tr,
                                  style: KpbTextStyles.label),
                              const SizedBox(height: 4),
                              Text(controller.resolve(institution.tuitionLabel),
                                  style: KpbTextStyles.titleMd),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpbCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('levels'.tr, style: KpbTextStyles.label),
                              const SizedBox(height: 4),
                              Text(institution.studyLevels.join(', '),
                                  style: KpbTextStyles.titleMd),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KpbSpacing.md),

                  // Programs
                  _SectionTitle(
                      title: 'institution_popular_programs'.tr,
                      icon: Icons.list_alt_rounded),
                  const SizedBox(height: 12),
                  ...institution.programIds.take(3).map((id) {
                    try {
                      final prog = controller.programById(id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KpbCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => Get.to(
                            () => ProgramDetailScreen(programId: prog.id),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(controller.resolve(prog.name),
                                        style: KpbTextStyles.titleMd),
                                    Text(controller.resolve(prog.level),
                                        style: KpbTextStyles.caption),
                                    const SizedBox(height: 4),
                                    ProgramIntakeLine(
                                      program: prog,
                                      institution: institution,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: KpbColors.blue),
                            ],
                          ),
                        ),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  }),

                  if (institution.isPartner) ...[
                    const SizedBox(height: KpbSpacing.lg),
                    const _IncentiveSection(),
                  ],

                  const SizedBox(height: KpbSpacing.xxl),
                ],
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  KpbSpacing.lg,
                  KpbSpacing.md,
                  KpbSpacing.lg,
                  KpbSpacing.xl + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.consultation,
                          title: 'institution_kpb_expert'.tr,
                          contextLabel: controller.resolve(institution.name),
                        ),
                      ),
                      child: Text('talk_to_expert'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: KpbButton(
                      label: institution.isPartner
                          ? 'institution_enroll_via_kpb'.tr
                          : 'learn_more'.tr,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.applicationSupport,
                          title: controller.resolve(institution.name),
                          contextLabel: institution.isPartner
                              ? 'institution_premium_support_guaranteed'.tr
                              : 'institution_premium_support'.tr,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncentiveSection extends StatelessWidget {
  const _IncentiveSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(KpbSpacing.md),
          decoration: BoxDecoration(
            color: KpbColors.blue.withValues(alpha: 0.05),
            borderRadius: KpbRadius.lgBr,
            border: Border.all(color: KpbColors.blue.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: KpbColors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'institution_kpb_benefits'.tr,
                    style:
                        KpbTextStyles.titleMd.copyWith(color: KpbColors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildIncentiveRow(
                icon: Icons.verified_user_rounded,
                title: 'institution_priority_admission'.tr,
                subtitle: 'institution_priority_admission_desc'.tr,
              ),
              const SizedBox(height: 12),
              _buildIncentiveRow(
                icon: Icons.support_agent_rounded,
                title: 'institution_dedicated_coach'.tr,
                subtitle: 'institution_dedicated_coach_desc'.tr,
              ),
              const SizedBox(height: 12),
              _buildIncentiveRow(
                icon: Icons.account_balance_rounded,
                title: 'institution_exclusive_scholarships'.tr,
                subtitle: 'institution_exclusive_scholarships_desc'.tr,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncentiveRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: KpbRadius.smBr,
          ),
          child: Icon(icon, color: KpbColors.blue, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KpbTextStyles.titleMd),
              Text(subtitle, style: KpbTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
