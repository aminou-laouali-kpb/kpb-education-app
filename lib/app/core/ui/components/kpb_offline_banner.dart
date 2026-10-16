import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/catalog_cache_service.dart';
import '../../services/connectivity_service.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

/// Localized relative label describing how fresh the cached catalog is.
///
/// Pure and with an injectable [now] so it is unit-testable. Strings resolve
/// against the active GetX locale (`.tr`), so the banner is bilingual. The
/// "older than a week" case uses a numeric `d/m` date to avoid month-name
/// localization. Examples: `aujourd'hui`, `hier`, `il y a 3 jours`, `du 14/6`.
String kpbFreshnessLabel(DateTime? lastSynced, {DateTime? now}) {
  if (lastSynced == null) return 'freshness_saved'.tr;
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final then = DateTime(lastSynced.year, lastSynced.month, lastSynced.day);
  final days = today.difference(then).inDays;
  if (days <= 0) return 'freshness_today'.tr;
  if (days == 1) return 'freshness_yesterday'.tr;
  if (days < 7) return 'freshness_days'.trParams({'n': '$days'});
  return 'freshness_date'
      .trParams({'date': '${lastSynced.day}/${lastSynced.month}'});
}

/// Monte [KpbOfflineBanner] AU-DESSUS de toutes les routes de l'app.
///
/// Posé dans le `builder:` de `GetMaterialApp` (lib/main.dart), donc au-dessus
/// du Navigator : le bandeau couvre l'onboarding, les fiches, le test, les
/// dossiers, les feuilles et les boîtes de dialogue — pas seulement les onglets
/// du shell, où il vivait jusqu'à la build 56. Une seule instance pour toute
/// l'app : le shell ne le monte plus.
///
/// La structure de l'arbre est la MÊME en ligne et hors ligne (une `Column`
/// dont le bandeau se réduit à rien en ligne) : basculer d'une structure à
/// l'autre reparenterait le Navigator à chaque coupure réseau.
///
/// Quand le bandeau est visible, il absorbe lui-même l'encoche (son
/// `SafeArea`) : on retire donc le haut du `padding` pour les routes en
/// dessous, sinon chaque AppBar redescendrait d'une barre de statut entière.
class KpbOfflineBannerHost extends StatelessWidget {
  const KpbOfflineBannerHost({super.key, required this.child});

  /// Le Navigator de l'app (le `child` du `builder:`).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService.instance;
    return StreamBuilder<bool>(
      stream: connectivity.onConnectivityChanged,
      initialData: connectivity.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return Column(
          children: [
            const KpbOfflineBanner(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !online,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Slim, reactive "you are offline" banner, mounted once for the whole app by
/// [KpbOfflineBannerHost].
///
/// Renders nothing when online (zero layout impact), so it can sit above the
/// page body in a [Column] without affecting the online experience. When
/// offline it reassures the user that cached content is still usable and how
/// fresh it is — important for airtime-sensitive users who lose connection
/// mid-session.
class KpbOfflineBanner extends StatelessWidget {
  const KpbOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService.instance;
    return StreamBuilder<bool>(
      stream: connectivity.onConnectivityChanged,
      initialData: connectivity.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();

        final lastSync = CatalogCacheService.isInitialized
            ? CatalogCacheService.instance.lastSyncedAt
            : null;

        return Material(
          color: context.kpb.warningLight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 16, color: KpbColors.warning),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${'offline_mode'.tr} · ${kpbFreshnessLabel(lastSync)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KpbColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
