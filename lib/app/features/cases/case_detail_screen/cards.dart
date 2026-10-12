part of '../case_detail_screen.dart';

// Cartes de navigation, conseiller, documents, partage parent, avis, hors-ligne.

// ─────────────────────────────────────────────────────────────────────────────
// Navigation card (interview simulator · AI review · prepare package)
// ─────────────────────────────────────────────────────────────────────────────
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: KpbColors.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advisor card
// ─────────────────────────────────────────────────────────────────────────────
class _AdvisorCard extends StatelessWidget {
  const _AdvisorCard({required this.name, required this.onWhatsapp});
  final String name;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KpbColors.actionPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              (name.isNotEmpty ? name[0] : 'K').toUpperCase(),
              style: const TextStyle(
                color: KpbColors.actionPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'case_advisor_role'.tr,
                  style: const TextStyle(
                      fontSize: 11.5, color: KpbColors.textMuted),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'a11y_whatsapp_advisor'.tr,
            child: GestureDetector(
              onTap: onWhatsapp,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KpbColors.whatsapp.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_rounded,
                    color: KpbColors.whatsapp, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Documents card
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.docs,
    required this.ctrl,
    required this.onUpload,
    required this.uploadEnabled,
  });

  final List<DocumentRequest> docs;
  final AppController ctrl;
  final void Function(DocumentRequest) onUpload;

  /// Faux pendant le masquage M2 : l'action reste, sa destination devient le
  /// conseiller WhatsApp et son libellé le dit.
  final bool uploadEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == docs.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: KpbColors.canvas)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: docs[i].isProvided
                          ? KpbColors.successLight
                          : KpbColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      docs[i].isProvided
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 18,
                      color: docs[i].isProvided
                          ? KpbColors.success
                          : KpbColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ctrl.resolve(docs[i].title),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                  ),
                  if (!docs[i].isProvided)
                    GestureDetector(
                      onTap: () => onUpload(docs[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: uploadEnabled
                              ? KpbColors.actionPrimarySoft
                              : KpbColors.successLight,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          uploadEnabled
                              ? 'case_document_send'.tr
                              : 'case_document_send_whatsapp'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: uploadEnabled
                                ? KpbColors.actionPrimary
                                : KpbColors.success,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: KpbColors.successLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'case_document_received'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.success,
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
// Parent-share toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ParentShareCard extends StatelessWidget {
  const _ParentShareCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KpbColors.warningLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.family_restroom_rounded,
                size: 20, color: KpbColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'parent_share_case_title'.tr,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'parent_share_case_subtitle'.tr,
                  style:
                      const TextStyle(fontSize: 11, color: KpbColors.textMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review prompt card (KPB-75)
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewPromptCard extends StatelessWidget {
  const _ReviewPromptCard({required this.onLater, required this.onReview});
  final VoidCallback onLater;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: KpbColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'review_prompt_title'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('review_prompt_body'.tr,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: KpbColors.gray700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLater,
                  child: Text('review_prompt_later'.tr),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: KpbColors.actionPrimary),
                  onPressed: onReview,
                  child: Text('review_prompt_cta'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline banner
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: KpbColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: KpbColors.warning, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'offline_cache_notice'.tr,
              style: const TextStyle(
                color: KpbColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
