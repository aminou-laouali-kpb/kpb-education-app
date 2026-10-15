import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/remote_feature_flags.dart';
import '../../utils/external_link.dart';
import '../../utils/version_utils.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';
import 'kpb_toast.dart';

/// L'invitation DOUCE à mettre à jour : un bandeau qu'on ferme.
///
/// ## Pourquoi il existe à côté de l'écran de mise à jour forcée
///
/// `AppVersionGate` ne connaît qu'un levier, `minVersion`, et il bloque toute
/// l'app derrière un écran sans sortie. C'est le bon outil pour une build
/// cassée, et le mauvais pour « il y a du neuf ». Sans second levier, chaque
/// ouverture future (hub complet, forum) ne toucherait que ceux qui mettent à
/// jour d'eux-mêmes, sauf à enfermer tout le monde — décision qu'on ne prend pas
/// pour un hub.
///
/// Le serveur sert donc `recommendedVersion` ; en dessous, ce bandeau. Il se
/// ferme, et n'enferme jamais personne.
///
/// ## Ce qu'il s'interdit
///
/// - **S'afficher sans pouvoir agir.** Sans lien de store pour cette plateforme,
///   il est masqué : inviter à mettre à jour sans dire où est une instruction
///   sans geste.
/// - **Se tromper de sens.** Une version illisible, absente, ou égale/inférieure
///   à l'installée ne produit rien. [isVersionBelow] échoue ouvert exprès.
/// - **Revenir à chaque écran.** Fermé, il ne réapparaît pas avant le prochain
///   démarrage de l'app, et pas du tout pour la même version recommandée.
class UpdateRecommendedBanner extends StatefulWidget {
  const UpdateRecommendedBanner({super.key, this.installedVersion});

  /// La version installée — injectable pour les tests. Par défaut,
  /// `PackageInfo.fromPlatform`.
  final Future<String?> Function()? installedVersion;

  /// Les versions recommandées déjà fermées pendant CETTE session. En mémoire
  /// seulement : fermer est « pas maintenant », pas « jamais ».
  static final Set<String> _dismissed = <String>{};

  @visibleForTesting
  static void resetForTest() => _dismissed.clear();

  @override
  State<UpdateRecommendedBanner> createState() =>
      _UpdateRecommendedBannerState();
}

class _UpdateRecommendedBannerState extends State<UpdateRecommendedBanner> {
  String? _installed;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveInstalled();
  }

  Future<void> _resolveInstalled() async {
    String? version;
    try {
      version = await (widget.installedVersion?.call() ??
          PackageInfo.fromPlatform().then((info) => info.version));
    } catch (_) {
      // Pas de version lisible : on ne sait pas si on est en retard, donc on se tait.
      version = null;
    }
    if (!mounted) return;
    setState(() {
      _installed = version;
      _resolved = true;
    });
  }

  /// Un lien qui ne s'ouvre pas doit le DIRE : un bouton muet est indiscernable
  /// d'une app plantée (voir `kpbOpenExternalUrl`, `EefOfficialLink`).
  Future<void> _open(String url) async {
    if (await kpbOpenExternalUrlString(url)) return;
    KpbToast.error(
      'external_link_failed_body'.tr,
      title: 'update_recommended_title'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) return const SizedBox.shrink();
    final flags = RemoteFeatureFlags.instance;

    return ValueListenableBuilder<int>(
      valueListenable: flags.flagsVersion,
      builder: (context, _, __) {
        final recommended = flags.recommendedVersion;
        final installed = _installed;
        final storeUrl = flags.storeUrl;
        if (recommended == null ||
            installed == null ||
            !isOpenableWebUrl(storeUrl) ||
            !isVersionBelow(installed, recommended) ||
            UpdateRecommendedBanner._dismissed.contains(recommended)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.md),
          child: Semantics(
            container: true,
            label: 'update_recommended_title'.tr,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                KpbSpacing.md,
                KpbSpacing.sm,
                KpbSpacing.xs,
                KpbSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.kpb.skyLight,
                borderRadius: BorderRadius.circular(KpbRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      size: 20,
                      color: KpbColors.blue,
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'update_recommended_title'.tr,
                          style: KpbTextStyles.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'update_recommended_body'.tr,
                          style: KpbTextStyles.bodySm
                              .copyWith(color: context.kpb.textMuted),
                        ),
                        const SizedBox(height: KpbSpacing.xs),
                        TextButton(
                          onPressed: () => _open(storeUrl!),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 44),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text('update_recommended_cta'.tr),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'update_recommended_dismiss'.tr,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(
                      () => UpdateRecommendedBanner._dismissed.add(recommended),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
