import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/study_level.dart';
import '../community/community_screen.dart';
import '../eligibility/eligibility_simulator_screen.dart';
import '../explore/program_detail_screen.dart';
import '../parcours/parcours_screen.dart';
import '../premium/premium_screen.dart';
import '../referral/ambassador_screen.dart';
import '../referral/referral_screen.dart';
import '../legal/legal_pages.dart';
import '../onboarding/onboarding_m2_constants.dart';
import '../orientation/orientation_screen.dart';
import '../budget/budget_calculator_screen.dart';
import '../travel/flight_estimator_screen.dart';
import '../housing/housing_estimator_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../parent/parent_surface_screen.dart';
import '../saved/saved_screen.dart';
import '../search/search_screen.dart';
import '../services/service_packages_screen.dart';
import '../alumni/alumni_directory_screen.dart';
import '../alumni/alumni_apply_screen.dart';
import '../salon/salon_screen.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/shell_chrome.dart';
import 'profile_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Student Profile — App-engagement handoff restyle (navy/blue).
//
// HONEST-DATA NOTES (design mock depicts several fabricated elements that have
// no backend — they are deliberately OMITTED here):
//   • Streak ("🔥 … best 23 d")            → no streak model exists.
//   • "Karatou ID" copy row                → profile.id is an opaque backend id,
//                                            never surfaced as a shareable ID.
//   • "12 visited pages available offline" → no per-visit offline counter.
//   • Parent "invite code + Share"         → the STUDENT accepts a parent's code
//     + 4 permission toggles                 (does not generate one); the only
//                                            real per-parent control is per-case
//                                            `parentCanView`, managed in a case.
//   • Premium price / checkout             → no in-app payment (see PremiumScreen).
// Everything rendered below is bound to REAL profile/controller data.
// ─────────────────────────────────────────────────────────────────────────────

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _premiumIconGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    KpbColors.gold,
    Color(0xFFFDE68A), // kpb-allow-color: dégradé premium (gold → amber-200)
  ],
);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final profile = controller.profile;
        if (profile == null) {
          return _GuestProfilePrompt(controller: controller);
        }

        final completion = (profile.completionScore * 100).round();

        return Scaffold(
          backgroundColor: KpbColors.canvas,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: KpbColors.canvas,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'profile'.tr,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: KpbColors.brandNavy,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: () => _openEditSheet(context, controller),
                      style: TextButton.styleFrom(
                        foregroundColor: KpbColors.actionPrimary,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                        'profile_edit'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(profile: profile, completion: completion),
                      const SizedBox(height: 12),
                      _ProfileCompletionGuide(
                        profile: profile,
                        completion: completion,
                        onEdit: () => _openEditSheet(context, controller),
                      ),
                      const SizedBox(height: 12),
                      _TargetUniversitiesCard(controller: controller),
                      const SizedBox(height: 12),
                      _PreferencesCard(
                        controller: controller,
                        onReplay: () => _replayOnboarding(context, controller),
                      ),
                      const SizedBox(height: 12),
                      if (!controller.isParent) ...[
                        _ParentAccessCard(),
                        const SizedBox(height: 12),
                      ],
                      _PremiumCard(
                        onTap: () => Get.to(() => const PremiumScreen()),
                      ),
                      const SizedBox(height: 12),
                      _AcademicInfoCard(profile: profile),
                      const SizedBox(height: 12),
                      _ContactCard(profile: profile),
                      if (profile.availableDocuments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DocumentsCard(profile: profile),
                      ],
                      const SizedBox(height: 12),
                      _QuickAccessCard(controller: controller),
                      const SizedBox(height: 12),
                      _LegalCard(),
                      const SizedBox(height: 12),
                      _DataRightsCard(
                        onExport: () => _exportData(context, controller),
                        onDelete: () =>
                            _confirmDeleteAccount(context, controller),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context, controller),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KpbColors.error,
                            side: const BorderSide(color: KpbColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'logout'.tr,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      // 100 pt laissaient « Se déconnecter » sous la pastille
                      // copilote (bande 92→140 depuis le bas de l'écran).
                      const KpbShellBottomSpacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AppController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('logout_confirm_title'.tr),
        content: Text('logout_redirect_notice'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.logout();
              unawaited(Get.offAll(() => const AppBootScreen()));
            },
            style: FilledButton.styleFrom(backgroundColor: KpbColors.error),
            child: Text('logout'.tr),
          ),
        ],
      ),
    );
  }

  /// Replays the getting-started experience. There is no dedicated coach-mark
  /// tutorial in the app; the real mechanism is re-entering onboarding by
  /// clearing the completion flag and rebooting (profile data is preserved).
  void _replayOnboarding(BuildContext context, AppController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_replay_confirm_title'.tr),
        content: Text('profile_replay_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.hasCompletedOnboarding = false;
              controller.update();
              Get.offAll(() => const AppBootScreen());
            },
            child: Text('profile_replay_confirm_cta'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(
      BuildContext context, AppController controller) async {
    try {
      final data = await controller.exportData();
      const encoder = JsonEncoder.withIndent('  ');
      await SharePlus.instance.share(
        ShareParams(
          text: encoder.convert(data),
          subject: 'export_data_subject'.tr,
        ),
      );
    } catch (_) {
      Get.snackbar(
        'data_rights_section'.tr,
        'export_data_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmDeleteAccount(BuildContext context, AppController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_account_confirm_title'.tr),
        content: Text('delete_account_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await controller.deleteAccount();
                unawaited(Get.offAll(() => const AppBootScreen()));
              } catch (_) {
                Get.snackbar(
                  'delete_account'.tr,
                  'delete_account_error'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: KpbColors.error),
            child: Text('delete_account_cta'.tr),
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, AppController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProfileEditSheet(controller: controller),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable primitives
// ─────────────────────────────────────────────────────────────────────────────

String _initials(String fullName) {
  final parts =
      fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.length >= 2) {
    return '${list[0][0]}${list[1][0]}'.toUpperCase();
  } else if (list.isNotEmpty && list[0].isNotEmpty) {
    return list[0][0].toUpperCase();
  }
  return '?';
}

String _accountTypeLabel(AccountType type) {
  switch (type) {
    case AccountType.student:
      return 'account_type_student'.tr;
    case AccountType.parent:
      return 'account_type_parent_short'.tr;
    case AccountType.partner:
      return 'badge_partner'.tr;
    case AccountType.commercial:
      return 'account_type_commercial_2'.tr;
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: const [
          BoxShadow(
            color: KpbShadow.softNavy,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: KpbColors.brandNavy,
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 48),
      child: Divider(height: 1, thickness: 1, color: KpbColors.surfaceMuted),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile, required this.completion});
  final UserProfile profile;
  final int completion;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (profile.currentLevel != null) studentLevelLabel(profile.currentLevel),
      if ((profile.gradeRange ?? '').trim().isNotEmpty) profile.gradeRange!,
    ].join(' · ');

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo de profil : la photo remplace les initiales quand elle
          // existe, les initiales restent le repli (pas de photo, chargement,
          // échec de chargement). Tout le parcours ajout/remplacement/
          // suppression vit dans ProfileAvatar.
          ProfileAvatar(
            profile: profile,
            initials: _initials(profile.fullName),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: KpbColors.textMuted,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: KpbColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimarySoft,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _accountTypeLabel(profile.accountType),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.actionPrimaryPressed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CompletionPill(completion: completion),
        ],
      ),
    );
  }
}

class _CompletionPill extends StatelessWidget {
  const _CompletionPill({required this.completion});
  final int completion;

  @override
  Widget build(BuildContext context) {
    final done = completion >= 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? KpbColors.successLight : KpbColors.actionPrimarySoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            const Icon(Icons.check_circle_rounded,
                size: 12, color: KpbColors.success),
            const SizedBox(width: 4),
          ],
          Text(
            '$completion%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: done ? KpbColors.success : KpbColors.actionPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My target universities (real saved institutions + real match %)
// ─────────────────────────────────────────────────────────────────────────────
class _TargetUniversitiesCard extends StatelessWidget {
  const _TargetUniversitiesCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final institutions = controller.savedItems
        .where((s) => s.type == SavedItemType.institution)
        .map((s) => controller.institutionByIdOrNull(s.itemId))
        .whereType<InstitutionModel>()
        .toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle('profile_target_universities'.tr),
              ),
              if (institutions.isNotEmpty)
                InkWell(
                  onTap: () => Get.to(() => const SavedScreen()),
                  child: Text(
                    'profile_universities_see_all'.tr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.actionPrimary,
                    ),
                  ),
                ),
            ],
          ),
          if (institutions.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'profile_universities_empty'.tr,
              style:
                  const TextStyle(fontSize: 12.5, color: KpbColors.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.to(() => const SearchScreen()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KpbColors.actionPrimary,
                  side: BorderSide(
                      color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'profile_explore_schools'.tr,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else
            ...institutions.take(4).map(
                  (inst) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _UniversityRow(
                      controller: controller,
                      institution: inst,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _UniversityRow extends StatelessWidget {
  const _UniversityRow({required this.controller, required this.institution});
  final AppController controller;
  final InstitutionModel institution;

  @override
  Widget build(BuildContext context) {
    final fit = controller.institutionFit(institution);
    final flag = displayCountryFlag(
      id: institution.countryId,
      flagEmoji: controller
              .countryByIdOrNull(institution.countryId)
              ?.flagEmoji
              .trim() ??
          '',
    );
    final programId =
        institution.programIds.isNotEmpty ? institution.programIds.first : null;

    return InkWell(
      onTap: programId == null
          ? null
          : () => Get.to(() => ProgramDetailScreen(programId: programId)),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              controller.resolve(institution.name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KpbColors.brandNavy,
              ),
            ),
          ),
          if (fit != null) ...[
            const SizedBox(width: 8),
            ProfileFitBadge(fit: fit, fontSize: 11),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preferences (replay onboarding + data saver + app lock + language)
// ─────────────────────────────────────────────────────────────────────────────
class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.controller, required this.onReplay});
  final AppController controller;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SectionTitle('profile_preferences'.tr),
            ),
          ),
          _NavRow(
            icon: Icons.school_outlined,
            color: KpbColors.actionPrimary,
            label: 'profile_replay_onboarding'.tr,
            onTap: onReplay,
          ),
          const _RowDivider(),
          _SettingRow(
            icon: Icons.data_saver_on_rounded,
            color: KpbColors.success,
            title: 'profile_data_saver'.tr,
            subtitle: 'profile_data_saver_desc'.tr,
            trailing: Switch.adaptive(
              value: controller.dataSaverEnabled,
              activeTrackColor: KpbColors.success,
              onChanged: controller.toggleDataSaver,
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            icon: Icons.insights_rounded,
            color: KpbColors.actionPrimary,
            title: 'profile_analytics'.tr,
            subtitle: 'profile_analytics_desc'.tr,
            trailing: Switch.adaptive(
              value: !controller.analyticsOptOut,
              activeTrackColor: KpbColors.actionPrimary,
              onChanged: (allowed) => controller.setAnalyticsAllowed(allowed),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            icon: Icons.mark_email_unread_outlined,
            color: KpbColors.warning,
            title: 'profile_newsletter'.tr,
            subtitle: 'profile_newsletter_desc'.tr,
            trailing: Switch.adaptive(
              value: controller.profile?.wantsScholarshipNewsletter ?? false,
              activeTrackColor: KpbColors.warning,
              onChanged: controller.profile == null
                  ? null
                  : controller.setNewsletterOptIn,
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            icon: Icons.fingerprint_rounded,
            color: KpbColors.actionPrimary,
            title: 'profile_biometric'.tr,
            subtitle: 'protect_app_access'.tr,
            trailing: Switch.adaptive(
              value: controller.isAppLockEnabled,
              activeTrackColor: KpbColors.actionPrimary,
              onChanged: controller.toggleAppLock,
            ),
          ),
          if (kLanguageSwitchVisible) ...[
            const _RowDivider(),
            _SettingRow(
              icon: Icons.translate_rounded,
              color: KpbColors.decorSky,
              title: 'app_language'.tr,
              subtitle: controller.localeCode.startsWith('en')
                  ? 'English'
                  : 'Français',
              trailing: _LanguageToggle(
                current: controller.localeCode,
                onChanged: controller.switchLanguage,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: KpbColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconChip(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: KpbColors.borderStrong),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parent access (student → accept a parent's invite code)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconChip(
                  icon: Icons.family_restroom_rounded, color: KpbColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: _SectionTitle('profile_parent_access'.tr),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'profile_parent_access_desc'.tr,
            style: const TextStyle(
                fontSize: 12, height: 1.45, color: KpbColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Get.to(() => const ParentDashboardScreen()),
              style: FilledButton.styleFrom(
                backgroundColor: KpbColors.actionPrimary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(
                'profile_parent_access_cta'.tr,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Karatou Premium entry (honest — no price, routes to the honest Premium screen)
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: _premiumIconGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: KpbColors.brandNavy, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'profile_premium_card_title'.tr,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'profile_premium_card_sub'.tr,
                    style: const TextStyle(
                        fontSize: 11, color: KpbColors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: KpbColors.gold),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Academic info / Contact / Documents
// ─────────────────────────────────────────────────────────────────────────────
class _AcademicInfoCard extends StatelessWidget {
  const _AcademicInfoCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoTile(
        icon: Icons.public_outlined,
        label: 'country'.tr,
        value: profile.countryOfResidence,
        iconColor: KpbColors.actionPrimary,
      ),
      if (profile.currentLevel != null)
        _InfoTile(
          icon: Icons.school_outlined,
          label: 'current_level'.tr,
          value: studentLevelLabel(profile.currentLevel),
          iconColor: KpbColors.decorSky,
        ),
      if (profile.targetLevel != null)
        _InfoTile(
          icon: Icons.trending_up_rounded,
          label: 'target_level'.tr,
          // Le JETON persisté est anglais (« Bachelor », « PhD ») ; il était
          // affiché tel quel dans une interface française. Même défaut, même
          // correctif, pour le niveau de langue juste en dessous
          // (« Intermediate »).
          value: targetLevelLabel(profile.targetLevel),
          iconColor: KpbColors.success,
        ),
      if (profile.languageLevel != null)
        _InfoTile(
          icon: Icons.translate_outlined,
          label: 'language_level'.tr,
          value: languageLevelLabel(profile.languageLevel),
          iconColor: KpbColors.gold,
        ),
      if ((profile.gradeRange ?? '').isNotEmpty)
        _InfoTile(
          icon: Icons.grade_outlined,
          label: 'grade_range'.tr,
          value: profile.gradeRange!,
          iconColor: KpbColors.medRed,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('profile_academic_info'.tr),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: _withDividers(rows)),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoTile(
        icon: Icons.phone_outlined,
        label: 'phone'.tr,
        value: profile.phone,
        iconColor: KpbColors.success,
      ),
      if (profile.whatsApp.isNotEmpty && profile.whatsApp != profile.phone)
        _InfoTile(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          value: profile.whatsApp,
          iconColor: KpbColors.success,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('profile_contact'.tr),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: _withDividers(rows)),
        ),
      ],
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('available_documents'.tr),
        const SizedBox(height: 8),
        _Card(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.availableDocuments
                .map(
                  (doc) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: KpbColors.successLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 13, color: KpbColors.success),
                        const SizedBox(width: 5),
                        Text(
                          _docLabel(doc),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: KpbColors.success,
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
    );
  }
}

String _docLabel(String doc) {
  final map = {
    'Passport': 'doc_passport'.tr,
    'CV': 'CV',
    'Transcripts': 'doc_transcripts'.tr,
    'Test score': 'doc_test_score'.tr,
  };
  return map[doc] ?? doc;
}

List<Widget> _withDividers(List<Widget> rows) {
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    out.add(rows[i]);
    if (i != rows.length - 1) out.add(const _RowDivider());
  }
  return out;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          _IconChip(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 11, color: KpbColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick access (all real, restyled) + Legal + Data rights
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    void add(IconData icon, Color color, String label, VoidCallback onTap) {
      tiles.add(_QuickAccessTile(
          icon: icon, color: color, label: label, onTap: onTap));
    }

    if (controller.isStudent) {
      add(Icons.card_giftcard_outlined, KpbColors.gold, 'referral_title'.tr,
          () => Get.to(() => const ReferralScreen()));
      add(
          Icons.diversity_3_outlined,
          KpbColors.actionPrimary,
          'referral_become_ambassador'.tr,
          () => Get.to(() => const AmbassadorScreen()));
      add(
          Icons.psychology_outlined,
          KpbColors.actionPrimary,
          'profile_quick_orientation_test'.tr,
          () => Get.to(() => const OrientationScreen()));
      add(
          Icons.fact_check_outlined,
          KpbColors.warning,
          'profile_quick_eligibility_simulator'.tr,
          () => Get.to(() => const EligibilitySimulatorScreen()));
      add(
          Icons.play_circle_outline_rounded,
          KpbColors.error,
          'profile_quick_journeys_testimonials'.tr,
          () => Get.to(() => const ParcoursScreen()));
      add(
          Icons.bookmark_outline_rounded,
          KpbColors.decorSky,
          'profile_quick_saved_items'.tr,
          () => Get.to(() => const SavedScreen()));
      add(
          Icons.account_balance_wallet_outlined,
          KpbColors.success,
          'profile_quick_budget_calculator'.tr,
          () => Get.to(() => const BudgetCalculatorScreen()));
      // Estimateur de vols : masqué tant que KPB_KAYAK_API_KEY n'est pas posée
      // côté serveur — l'outil renvoie toujours une erreur sinon (revue vidéo
      // du 08/08 : « ça ne sert à rien pour l'instant »). Même drapeau que
      // l'entrée du tiroir d'outils.
      if (AppConfig.flightEstimatorEnabled) {
        add(
            Icons.flight_takeoff_rounded,
            KpbColors.decorSky,
            'profile_quick_flight_simulator'.tr,
            () => Get.to(() => const FlightEstimatorScreen()));
      }
      // Housing estimator is a V1.1+ module.
      if (!AppConfig.mvpOnly) {
        add(
            Icons.holiday_village_rounded,
            KpbColors.actionPrimary,
            'profile_quick_student_housing'.tr,
            () => Get.to(() => const HousingEstimatorScreen()));
      }
    }
    // Community/forum is a V1.1+ module.
    if (!AppConfig.mvpOnly) {
      add(
          Icons.forum_outlined,
          KpbColors.decorSky,
          'profile_quick_community_articles'.tr,
          () => Get.to(() => const CommunityScreen()));
    }
    // Parent space (for parent accounts; students use the Parent access card).
    if (controller.isParent) {
      add(
          Icons.family_restroom,
          KpbColors.gold,
          'profile_quick_parent_space'.tr,
          () => Get.to(() => const ParentSurfaceScreen()));
    }
    // Phase 3 — Monetized bundles: "Dossier prêt", scholarship & visa kits.
    add(
        Icons.workspace_premium_outlined,
        KpbColors.brandNavy,
        'profile_quick_kpb_services'.tr,
        () => Get.to(() => const ServicePackagesScreen()));
    // Alumni mentors & virtual salon are V1.1+ modules.
    if (!AppConfig.mvpOnly) {
      add(
          Icons.school_outlined,
          KpbColors.actionPrimary,
          'profile_quick_verified_alumni_mentors'.tr,
          () => Get.to(() => const AlumniDirectoryScreen()));
      add(
          Icons.verified_outlined,
          KpbColors.actionPrimary,
          'profile_quick_become_alumni_mentor'.tr,
          () => Get.to(() => const AlumniApplyScreen()));
      add(
          Icons.event,
          KpbColors.actionPrimary,
          'profile_quick_virtual_salon'.tr,
          () => Get.to(() => const SalonScreen()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('profile_quick_access'.tr),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: _withDividers(tiles)),
        ),
      ],
    );
  }
}

class _LegalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('profile_legal_info'.tr),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: _withDividers([
              _QuickAccessTile(
                icon: Icons.privacy_tip_outlined,
                color: KpbColors.textMuted,
                label: 'profile_privacy_policy'.tr,
                onTap: () => Get.to(() => const PrivacyPolicyScreen()),
              ),
              _QuickAccessTile(
                icon: Icons.description_outlined,
                color: KpbColors.textMuted,
                label: 'profile_terms_of_service'.tr,
                onTap: () => Get.to(() => const TermsOfServiceScreen()),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DataRightsCard extends StatelessWidget {
  const _DataRightsCard({required this.onExport, required this.onDelete});
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('data_rights_section'.tr),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: _withDividers([
              _QuickAccessTile(
                icon: Icons.download_outlined,
                color: KpbColors.textMuted,
                label: 'export_data'.tr,
                onTap: onExport,
              ),
              _QuickAccessTile(
                icon: Icons.delete_outline_rounded,
                color: KpbColors.error,
                label: 'delete_account'.tr,
                onTap: onDelete,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconChip(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: KpbColors.borderStrong),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Completion Guide — contextual missing fields
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCompletionGuide extends StatelessWidget {
  const _ProfileCompletionGuide({
    required this.profile,
    required this.completion,
    required this.onEdit,
  });

  final UserProfile profile;
  final int completion;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final missing = _missingFields(profile);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SectionTitle('profile_completed'.tr)),
              Text(
                '$completion%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.actionPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: profile.completionScore,
              minHeight: 8,
              backgroundColor: KpbColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(
                completion >= 80 ? KpbColors.success : KpbColors.actionPrimary,
              ),
            ),
          ),
          // Les deux branches sont désormais PROVABLEMENT complémentaires :
          // elles testent la même liste, pas `completion >= 100` d'un côté et
          // `missing.isNotEmpty` de l'autre. C'est cette dissymétrie qui
          // produisait la carte muette — un troisième état, ni « complet » ni
          // « voici ce qui manque », que personne n'avait voulu.
          if (missing.isEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: KpbColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  'profile_complete_optimized'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.success,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            ...missing.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        size: 16, color: KpbColors.borderStrong),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.field,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: KpbColors.brandNavy,
                            ),
                          ),
                          Text(
                            m.impact,
                            style: const TextStyle(
                                fontSize: 12, color: KpbColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KpbColors.actionPrimary,
                  side: BorderSide(
                      color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('profile_complete_cta'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Les manques, dérivés de [UserProfile.missingCompletionItems].
  ///
  /// ## Ce que cette fonction ne fait plus
  ///
  /// Elle ne RE-CALCULE plus ce qui manque. L'ancienne version testait cinq
  /// champs à la main, avec ses propres prédicats (`p.currentLevel == null`
  /// alors que le score teste `.trim().isNotEmpty` — une chaîne vide comptait
  /// donc comme manquante pour le score et comme remplie pour la liste), puis
  /// tronquait à trois. Résultat : à qui il ne manquait que le budget, la carte
  /// affichait « 92 % », une barre, et RIEN d'autre — pas de liste, pas de
  /// bouton, parce que `missing` était vide et que tout le bloc vivait sous
  /// `else if (missing.isNotEmpty)`. Le cas se reproduit avec la propre fixture
  /// du dépôt (`createTestProfile`, sans budget : 12/13 = 92 %).
  ///
  /// Le `take(3)` est parti avec. La demande est de montrer ce qu'il manque
  /// POUR ATTEINDRE 100 % : en cacher la moitié rend le compte impossible à
  /// boucler, et c'est justement la plainte.
  List<({String field, String impact})> _missingFields(UserProfile p) {
    return p.missingCompletionItems.map(_labelFor).toList(growable: false);
  }

  /// Un libellé par item du score. Le `switch` est EXHAUSTIF sans `default` :
  /// ajouter un item à [ProfileCompletionItem] sans lui donner de libellé ne
  /// compile pas. C'est ce qui empêche la divergence de revenir.
  ({String field, String impact}) _labelFor(ProfileCompletionItem item) {
    switch (item) {
      case ProfileCompletionItem.fullName:
        return (
          field: 'profile_missing_full_name_field'.tr,
          impact: 'profile_missing_full_name_impact'.tr,
        );
      case ProfileCompletionItem.email:
        return (
          field: 'profile_missing_email_field'.tr,
          impact: 'profile_missing_email_impact'.tr,
        );
      case ProfileCompletionItem.phone:
        return (
          field: 'profile_missing_phone_field'.tr,
          impact: 'profile_missing_phone_impact'.tr,
        );
      case ProfileCompletionItem.countryOfResidence:
        return (
          field: 'profile_missing_country_field'.tr,
          impact: 'profile_missing_country_impact'.tr,
        );
      case ProfileCompletionItem.preferredLanguage:
        return (
          field: 'profile_missing_language_field'.tr,
          impact: 'profile_missing_language_impact'.tr,
        );
      case ProfileCompletionItem.currentLevel:
        return (
          field: 'profile_field_current_study_level'.tr,
          impact: 'profile_missing_current_level_impact'.tr,
        );
      case ProfileCompletionItem.targetLevel:
        return (
          field: 'profile_missing_target_level_field'.tr,
          impact: 'profile_missing_target_level_impact'.tr,
        );
      case ProfileCompletionItem.languageLevel:
        return (
          field: 'profile_missing_language_level_field'.tr,
          impact: 'profile_missing_language_level_impact'.tr,
        );
      case ProfileCompletionItem.fields:
        return (
          field: 'profile_missing_fields_field'.tr,
          impact: 'profile_missing_fields_impact'.tr,
        );
      case ProfileCompletionItem.targetCountries:
        return (
          field: 'profile_missing_target_countries_field'.tr,
          impact: 'profile_missing_target_countries_impact'.tr,
        );
      case ProfileCompletionItem.grade:
        return (
          field: 'profile_missing_grade_field'.tr,
          impact: 'profile_missing_grade_impact'.tr,
        );
      case ProfileCompletionItem.budget:
        return (
          field: 'profile_missing_budget_field'.tr,
          impact: 'profile_missing_budget_impact'.tr,
        );
      case ProfileCompletionItem.documents:
        return (
          field: 'profile_missing_documents_field'.tr,
          impact: 'profile_missing_documents_impact'.tr,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest prompt
// ─────────────────────────────────────────────────────────────────────────────
class _GuestProfilePrompt extends StatelessWidget {
  const _GuestProfilePrompt({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: KpbColors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'profile'.tr,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: KpbColors.brandNavy,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 64, color: KpbColors.borderStrong),
                  const SizedBox(height: 24),
                  Text(
                    'auth_guest_profile_title'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth_guest_profile_body'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: KpbColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      controller.leaveGuestForSignup(source: 'profile');
                      Get.offAll(() => const AppBootScreen());
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: KpbColors.actionPrimary,
                    ),
                    child: Text('auth_continue_email'.tr),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact FR | EN segmented control for the app display language.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment('FR', 'fr'),
        const SizedBox(width: 8),
        _segment('EN', 'en'),
      ],
    );
  }

  Widget _segment(String label, String code) {
    final selected = current.startsWith(code);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: selected ? null : () => onChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? KpbColors.actionPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? KpbColors.actionPrimary : KpbColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? Colors.white : KpbColors.textMuted,
          ),
        ),
      ),
    );
  }
}

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
    Get.snackbar(
      'profile_updated_title'.tr,
      'profile_updated_body'.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: KpbColors.successLight,
      colorText: KpbColors.success,
      duration: const Duration(seconds: 2),
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
