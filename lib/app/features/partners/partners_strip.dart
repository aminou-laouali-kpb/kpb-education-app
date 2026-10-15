import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_network_image.dart';

import '../../core/repositories/app_api_client.dart';
import '../../core/utils/external_link.dart';

/// Horizontal "Ils nous font confiance" strip (Phase 3).
///
/// Renders the featured partners (Campus France, AUF, Moroccan / Tunisian
/// universities, UBA / Ecobank / Orabank) on the landing screen. Each logo
/// is worth ~1000 cold users in a trust-driven market — this widget is
/// deliberately small so it can sit above-the-fold on the home tab.
///
/// Loads lazily on first build and caches in memory; we don't persist the
/// list to Hive because partners rotate infrequently enough that a fresh
/// fetch every cold start is fine.
class PartnersStrip extends StatefulWidget {
  const PartnersStrip({
    super.key,
    this.height = 80,
    this.api,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final double height;

  /// Le client à interroger ; nul : celui de l'app (en-têtes et
  /// intercepteurs communs), à défaut un client neuf.
  final AppApiClient? api;

  /// Marges du bandeau quand il a des partenaires à montrer (rien sinon).
  final EdgeInsets padding;

  @override
  State<PartnersStrip> createState() => _PartnersStripState();
}

class _PartnersStripState extends State<PartnersStrip> {
  late final AppApiClient _api = widget.api ??
      (Get.isRegistered<AppController>()
          ? Get.find<AppController>().apiClient
          : AppApiClient());
  List<dynamic> _partners = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.listFeaturedPartners(limit: 12);
      if (!mounted) return;
      setState(() {
        _partners = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rien tant qu'il n'y a pas de partenaire à montrer : ni spinner seul
    // pendant le chargement, ni trou quand l'appel échoue ou rend vide.
    if (_loading || _partners.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'partners_strip_trust_title'.tr,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: widget.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _partners.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _PartnerTile(p: _partners[i] as Map<String, dynamic>),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({required this.p});

  final Map<String, dynamic> p;

  // Lien venu du serveur : schéma validé, pas d'exception sur URL invalide.
  Future<void> _open() async {
    await kpbOpenExternalUrlString(p['websiteUrl'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final name = (ctrl.localeCode == 'en'
            ? (p['nameEn'] as String?) ?? (p['nameFr'] as String?)
            : (p['nameFr'] as String?)) ??
        '';
    final logo = (p['logoUrl'] as String?) ?? '';
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: KpbNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                targetWidth: 116,
                placeholderIcon: Icons.business,
                errorIcon: Icons.business,
                iconSize: 32,
                fallbackColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: KpbFontSize.xs),
            ),
          ],
        ),
      ),
    );
  }
}
