part of '../profile_screen.dart';

// En-tête du profil et universités visées.

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile});
  final UserProfile profile;

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
