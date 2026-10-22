part of '../profile_screen.dart';

// Accès rapides, mentions légales et droits sur les données.

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
      // Test « Mes 10 bourses » : élèves seulement, drapeau ouvert (sans run,
      // l'écran des résultats propose de faire le test).
      if (scholarshipMatchEntryVariant(controller) !=
          ScholarshipMatchEntryVariant.hidden) {
        add(
            Icons.emoji_events_outlined,
            KpbColors.actionPrimary,
            'profile_quick_scholarship_match'.tr,
            () => Get.to(
                () => const ScholarshipMatchResultsScreen(source: 'profile')));
      }
      // Le simulateur d'éligibilité juge des PAYS d'études (budget, langue,
      // niveau), pas une bourse : il reste à côté du test.
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
      // Nouvelle communauté (drapeau distant `community`) : élèves seulement.
      if (CommunityStore.instance.enabled) {
        add(Icons.forum_rounded, KpbColors.actionPrimary, 'comm_title'.tr,
            () => openCommunityHub(source: 'profile'));
      }
      add(Icons.bookmarks_outlined, KpbColors.decorSky, 'followed_title'.tr,
          () => Get.to(() => const SavedScreen()));
      // Les préférences de notification à deux taps du Profil : jusqu'ici, on
      // ne les trouvait que par la cloche de l'accueil.
      add(
          Icons.notifications_none_rounded,
          KpbColors.actionPrimary,
          'notifications_title'.tr,
          () => Get.to(() => const NotificationsScreen()));
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

  /// Reçoit le contexte de la ligne touchée : la feuille de partage s'y ancre
  /// sur iPad (audit 57, F12).
  final ValueChanged<BuildContext> onExport;
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
              Builder(
                builder: (tile) => _QuickAccessTile(
                  icon: Icons.download_outlined,
                  color: KpbColors.textMuted,
                  label: 'export_data'.tr,
                  onTap: () => onExport(tile),
                ),
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
