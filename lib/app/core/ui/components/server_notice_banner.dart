import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/remote_feature_flags.dart';
import '../../utils/external_link.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';
import 'kpb_toast.dart';

/// L'avis servi par le serveur (`/config/app` → `notice`), en haut de
/// l'accueil : un message court, qu'on ferme.
///
/// ## Pourquoi il existe
///
/// Une build vit des mois, et pendant ce temps rien ne permettait de dire un
/// mot à tous les téléphones installés sans nouvelle build : ni une date
/// limite qui approche (le Maroc ferme sa campagne Études en France le
/// 15 novembre, l'app ne le disait pas), ni un incident, ni un changement de
/// contact. Les notifications ne touchent que ceux qui les ont acceptées.
///
/// ## Ce qu'il s'interdit
///
/// - **Bloquer.** Il se ferme toujours. Bloquer l'app est le rôle de la garde
///   de version, qui a sa propre clé.
/// - **Revenir.** Fermé, le même texte ne réapparaît pas, même après un
///   redémarrage. Un NOUVEAU texte, lui, s'affiche.
/// - **Ouvrir n'importe quoi.** Le lien est validé à la lecture de la charge ;
///   sans lien valide, pas de bouton.
class ServerNoticeBanner extends StatefulWidget {
  const ServerNoticeBanner({super.key, this.storage});

  /// Où le dernier avis fermé est gardé — injectable pour les tests.
  final ServerNoticeDismissalStorage? storage;

  @override
  State<ServerNoticeBanner> createState() => _ServerNoticeBannerState();
}

/// Mémoire du dernier avis fermé (son texte français).
abstract class ServerNoticeDismissalStorage {
  Future<String?> read();

  Future<void> write(String noticeText);
}

class SharedPreferencesNoticeDismissalStorage
    implements ServerNoticeDismissalStorage {
  const SharedPreferencesNoticeDismissalStorage();

  static const String storageKey = 'kpb.notice.dismissed.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(storageKey);

  @override
  Future<void> write(String noticeText) async {
    await (await SharedPreferences.getInstance())
        .setString(storageKey, noticeText);
  }
}

class _ServerNoticeBannerState extends State<ServerNoticeBanner> {
  /// Le texte du dernier avis fermé. `null` tant que la mémoire n'est pas lue.
  String? _dismissed;
  bool _resolved = false;

  ServerNoticeDismissalStorage get _storage =>
      widget.storage ?? const SharedPreferencesNoticeDismissalStorage();

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    String? dismissed;
    try {
      dismissed = await _storage.read();
    } catch (_) {
      // Mémoire illisible : on affiche l'avis plutôt que de le taire.
      dismissed = null;
    }
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _resolved = true;
    });
  }

  void _dismiss(String noticeText) {
    setState(() => _dismissed = noticeText);
    // L'écriture peut échouer sans conséquence : l'avis reviendrait au
    // prochain lancement, c'est tout.
    _storage.write(noticeText).catchError((Object _) {});
  }

  /// Un lien qui ne s'ouvre pas doit le DIRE : un bouton muet est
  /// indiscernable d'une app plantée.
  Future<void> _open(String url) async {
    if (await kpbOpenExternalUrlString(url)) return;
    KpbToast.error('external_link_failed_body'.tr);
  }

  @override
  Widget build(BuildContext context) {
    // Tant que la mémoire n'est pas lue, rien : afficher puis retirer un avis
    // déjà fermé ferait sauter l'accueil.
    if (!_resolved) return const SizedBox.shrink();
    final flags = RemoteFeatureFlags.instance;

    return ValueListenableBuilder<int>(
      valueListenable: flags.flagsVersion,
      builder: (context, _, __) {
        final notice = flags.notice;
        if (notice == null || notice.fr == _dismissed) {
          return const SizedBox.shrink();
        }
        final text = notice.textFor(Get.locale?.languageCode);
        final url = notice.url;

        return Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.md),
          child: Semantics(
            container: true,
            liveRegion: true,
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
                      Icons.campaign_outlined,
                      size: 20,
                      color: KpbColors.blue,
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(text, style: KpbTextStyles.bodySm),
                        ),
                        if (url != null)
                          TextButton(
                            onPressed: () => _open(url),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 44),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text('learn_more'.tr),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'close'.tr,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => _dismiss(notice.fr),
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
