part of '../profile_screen.dart';

// Informations académiques, contact et documents.

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
