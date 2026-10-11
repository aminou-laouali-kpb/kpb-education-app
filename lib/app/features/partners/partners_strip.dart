import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
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
  const PartnersStrip({super.key, this.height = 80});

  final double height;

  @override
  State<PartnersStrip> createState() => _PartnersStripState();
}

class _PartnersStripState extends State<PartnersStrip> {
  final AppApiClient _api = AppApiClient();
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
    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_partners.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
