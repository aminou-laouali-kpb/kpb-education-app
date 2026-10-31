import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/community_store.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/study_level.dart';
import '../../core/utils/share_origin.dart';
import '../community/community_screen.dart';
import '../community/hub/community_entry.dart';
import '../community/hub/community_member_screen.dart';
import '../eligibility/eligibility_simulator_screen.dart';
import '../explore/program_detail_screen.dart';
import '../parcours/parcours_screen.dart';
import '../premium/premium_screen.dart';
import '../referral/ambassador_screen.dart';
import '../referral/referral_screen.dart';
import '../legal/legal_links.dart';
import '../legal/legal_pages.dart';
import '../onboarding/onboarding_m2_constants.dart';
import '../orientation/orientation_screen.dart';
import '../budget/budget_calculator_screen.dart';
import '../travel/flight_estimator_screen.dart';
import '../housing/housing_estimator_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../parent/parent_surface_screen.dart';
import '../saved/saved_screen.dart';
import '../scholarship_match/scholarship_match_actions.dart';
import '../scholarship_match/scholarship_match_results_screen.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
import '../services/service_packages_screen.dart';
import '../alumni/alumni_directory_screen.dart';
import '../alumni/alumni_apply_screen.dart';
import '../salon/salon_screen.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/shell_chrome.dart';
import 'profile_avatar.dart';
import '../../core/ui/components/kpb_toast.dart';

part 'profile_screen/widgets.dart';
part 'profile_screen/header.dart';
part 'profile_screen/settings.dart';
part 'profile_screen/info.dart';
part 'profile_screen/quick_access.dart';
part 'profile_screen/guidance.dart';
part 'profile_screen/edit_sheet.dart';

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
                      _HeaderCard(profile: profile),
                      const SizedBox(height: 12),
                      _ProfileCompletionGuide(
                        profile: profile,
                        completion: completion,
                        onEdit: () => _openEditSheet(context, controller),
                      ),
                      const SizedBox(height: 12),
                      _TargetUniversitiesCard(controller: controller),
                      const SizedBox(height: 12),
                      _PreferencesCard(controller: controller),
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
                        onExport: (origin) => _exportData(origin, controller),
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

  /// [origin] : la ligne « Exporter mes données », où la feuille de partage
  /// s'ancre sur iPad (audit 57, F12).
  Future<void> _exportData(
      BuildContext origin, AppController controller) async {
    final String text;
    try {
      final data = await controller.exportData();
      const encoder = JsonEncoder.withIndent('  ');
      text = encoder.convert(data);
    } catch (_) {
      KpbToast.error('export_data_error'.tr);
      return;
    }
    if (!origin.mounted) return;
    await kpbShare(
      origin,
      text: text,
      subject: 'export_data_subject'.tr,
      errorMessage: 'export_data_error'.tr,
    );
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
                KpbToast.error('delete_account_error'.tr);
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
