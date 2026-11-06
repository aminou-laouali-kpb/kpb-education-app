part of '../profile_screen.dart';

// Guide de complétion, invite invité et choix de langue.

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
                  const SizedBox(height: 12),
                  const LegalLinksRow(showContact: true),
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
