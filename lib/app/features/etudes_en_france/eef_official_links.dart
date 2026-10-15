import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/data/eef_calendar.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/external_link.dart';

/// Un lien vers une source OFFICIELLE (plateforme de l'État, page d'ambassade).
///
/// ## Pourquoi ces liens existent
///
/// L'espace affirme que la plateforme ouvre à une date, et que le traitement
/// des dossiers est suspendu dans certains pays. Ce sont des affirmations
/// administratives : l'étudiant doit pouvoir aller vérifier lui-même, et savoir
/// où se trouve la plateforme officielle, qui est le vrai lieu de candidature.
/// Sans lien, la mention de non-affiliation renvoyait « aux plateformes de
/// l'État » sans dire lesquelles.
///
/// ## Pourquoi l'adresse est SERVIE
///
/// `/config/app` la fournit (`eefCampaign.platformUrl`,
/// `eefCampaign.suspendedSources`) : un hôte compilé dans le binaire est faux
/// dès que la plateforme change d'adresse, et cette build vit trois mois.
///
/// ## Ce que le composant s'interdit
///
/// Se montrer sans pouvoir marcher : une adresse absente ou non ouvrable le
/// masque — même règle que partout dans l'app (`KpbSourceLink`).
class EefOfficialLink extends StatelessWidget {
  const EefOfficialLink({
    super.key,
    required this.url,
    required this.labelKey,
    this.color,
  });

  final String? url;

  /// Clé de traduction du libellé, pas un texte : le composant n'a pas de
  /// langue.
  final String labelKey;

  /// Teinte du lien. Défaut : bleu de lien de l'app. Sur le fond sombre du
  /// bandeau de la vitrine, l'appelant passe une teinte lisible dessus.
  final Color? color;

  Future<void> _open() async {
    if (await kpbOpenExternalUrlString(url)) return;
    // Un lien officiel qui ne s'ouvre pas doit le DIRE (voir `KpbSourceLink`).
    KpbToast.error(
      'external_link_failed_body'.tr,
      title: labelKey.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isOpenableWebUrl(url)) return const SizedBox.shrink();
    final tint = color ?? KpbColors.blue;
    return Semantics(
      button: true,
      link: true,
      label: labelKey.tr,
      child: InkWell(
        onTap: _open,
        child: ConstrainedBox(
          // 44 pt : la cible tactile minimale, sur un lien qui fait une ligne.
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new_rounded, size: 14, color: tint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    labelKey.tr,
                    style: KpbTextStyles.labelSm.copyWith(
                      color: tint,
                      decoration: TextDecoration.underline,
                      decorationColor: tint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La mention de non-affiliation, avec le lien de la plateforme officielle.
///
/// Elle n'est pas une précaution juridique décorative : l'espace parle d'une
/// procédure opérée par un établissement public français, et un étudiant qui
/// croirait être sur un canal officiel prendrait pour parole d'État ce qui est
/// l'accompagnement d'une entreprise privée. Un seul composant pour la vitrine,
/// l'espace et le catalogue : trois copies finiraient par diverger.
class EefAffiliationNotice extends StatelessWidget {
  const EefAffiliationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.surfaceMuted,
        borderRadius: KpbRadius.mdBr,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: context.kpb.textMuted,
          ),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'eef_affiliation_notice'.tr,
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted),
                ),
                EefOfficialLink(
                  url: EefCalendar.platformUrl,
                  labelKey: 'eef_official_platform_link',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
