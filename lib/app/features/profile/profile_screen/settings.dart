part of '../profile_screen.dart';

// Préférences, accès parent et Premium.

// ─────────────────────────────────────────────────────────────────────────────
// Preferences (data saver + app lock + language)
// ─────────────────────────────────────────────────────────────────────────────
class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.controller});
  final AppController controller;

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
          // Nouvelles et offres de KPB par e-mail (correctifs 57, XC-06) :
          // consentement distinct, NON par défaut. Visible seulement si le
          // serveur connaît le champ.
          if (controller.profile?.serverKnowsPromotions ?? false) ...[
            const _RowDivider(),
            _SettingRow(
              icon: Icons.campaign_outlined,
              color: KpbColors.warning,
              title: 'profile_promotions_email'.tr,
              subtitle: 'profile_promotions_email_desc'.tr,
              trailing: Switch.adaptive(
                key: const ValueKey<String>('profile-promotions-email'),
                value: controller.profile?.promotionsEmailOptIn ?? false,
                activeTrackColor: KpbColors.warning,
                onChanged: controller.setPromotionsEmailOptIn,
              ),
            ),
          ],
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
          // Communauté : les membres bloqués se gèrent ici (exigence des
          // stores). Visible seulement drapeau `community` ouvert.
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              RemoteFeatureFlags.instance.flagsVersion,
              CommunityStore.instance,
            ]),
            builder: (context, _) {
              if (!CommunityStore.instance.enabled) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const _RowDivider(),
                  _NavRow(
                    key: const ValueKey<String>('profile-comm-blocked'),
                    icon: Icons.block_rounded,
                    color: KpbColors.textSecondary,
                    label: 'comm_blocked_title'.tr,
                    onTap: () =>
                        Get.to(() => const CommunityBlockedMembersScreen()),
                  ),
                ],
              );
            },
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
    final row = Padding(
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
    // Un interrupteur se lit avec son libellé et son explication, en un seul
    // nœud (audit 57, F14) : sinon « Interrupteur, désactivé », sans dire
    // lequel. Les autres commandes (choix de langue : deux boutons) gardent
    // leurs nœuds à elles.
    return trailing is Switch ? MergeSemantics(child: row) : row;
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
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
