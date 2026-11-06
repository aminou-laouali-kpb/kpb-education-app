import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/components/anti_fraud_notice.dart';
import '../../core/ui/components/kpb_empty_state.dart';
import '../../core/ui/components/kpb_error_state.dart';
import '../../core/ui/components/verified_advisor_sheet.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/whatsapp_utils.dart';

/// "Dossier prêt" + scholarship / visa prep kits catalog (Phase 3).
///
/// Fixed-price bundles (10k–25k FCFA) where KPB reviews CV, motivation and
/// recommendation letters in FR + EN before submission.
///
/// The screen splits the catalog by category. There is no in-app checkout —
/// our (largely African) audience arranges payment directly with an advisor,
/// so each package's CTA opens WhatsApp pre-filled with that service's name.
class ServicePackagesScreen extends StatefulWidget {
  const ServicePackagesScreen({
    super.key,
    this.caseId,
    this.caseReference,
    this.apiClient,
  });

  final String? caseId;
  final String? caseReference;

  /// Pour les tests ; la production utilise [AppApiClient].
  final AppApiClient? apiClient;

  @override
  State<ServicePackagesScreen> createState() => _ServicePackagesScreenState();
}

class _ServicePackagesScreenState extends State<ServicePackagesScreen> {
  late final AppApiClient _api = widget.apiClient ?? AppApiClient();
  bool _loading = true;
  String? _error;
  List<dynamic> _packages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listServicePackages();
      if (!mounted) return;
      setState(() {
        _packages = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'service_packages_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _contactAdvisor(Map<String, dynamic> pkg) async {
    // No in-app checkout — route to a KPB advisor on WhatsApp, pre-filled with
    // the package name so they know which service the student is asking about.
    final name = (pkg['nameFr'] as String?)?.trim();
    final code = (pkg['code'] as String?)?.trim();
    if (code != null && code.isNotEmpty) {
      try {
        await _api.createWhatsAppServicePurchase(
          packageCode: code,
          caseId: widget.caseId,
          source: widget.caseId == null ? 'service_packages' : 'case_detail',
        );
      } catch (_) {
        // The WhatsApp handoff remains available offline / during transient API
        // failures; ops can still create the row manually from the conversation.
      }
    }
    await showVerifiedAdvisorThenWhatsApp(
      prefill: kpbWhatsAppPrefill(
        service: name,
        reference: widget.caseReference,
      ),
      source: widget.caseId == null ? 'service_packages' : 'case_detail',
      contextType: 'service',
    );
  }

  /// Sans pack à proposer, le conseiller reste joignable ; le message reprend la
  /// référence du dossier quand l'écran est ouvert depuis un dossier.
  Future<void> _contactAdvisorGeneric() => showVerifiedAdvisorThenWhatsApp(
        prefill: kpbWhatsAppPrefill(reference: widget.caseReference),
        source: widget.caseId == null ? 'service_packages' : 'case_detail',
        contextType: 'service_empty',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('service_packages_title'.tr)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Une erreur et un catalogue vide donnent chacun une ACTION : « Réessayer »,
    // ou le conseiller. Avant, un texte nu : l'élève ne pouvait rien en faire
    // (audit build 57, T4-05).
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: KpbErrorState(onRetry: _load),
          ),
        ],
      );
    }
    if (_packages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: KpbEmptyState(
              key: const ValueKey<String>('service-packages-empty'),
              icon: Icons.inventory_2_outlined,
              title: 'service_packages_empty'.tr,
              action: FilledButton.icon(
                onPressed: _contactAdvisorGeneric,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: Text('premium_advisor_cta'.tr),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _packages.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const KpbAntiFraudNotice(source: 'service_packages');
        }
        return _PackageCard(
          pkg: _packages[i - 1] as Map<String, dynamic>,
          onContact: _contactAdvisor,
        );
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg, required this.onContact});

  final Map<String, dynamic> pkg;
  final Future<void> Function(Map<String, dynamic>) onContact;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final en = ctrl.localeCode.startsWith('en');
    final name = ((en ? pkg['nameEn'] : pkg['nameFr']) as String?) ??
        (pkg['nameFr'] as String?) ??
        '';
    final summary = ((en ? pkg['summaryEn'] : pkg['summaryFr']) as String?) ??
        (pkg['summaryFr'] as String?) ??
        '';
    final price = (pkg['priceXOF'] as num?)?.toInt() ?? 0;
    final turnaround =
        ((en ? pkg['turnaroundEn'] : pkg['turnaroundFr']) as String?) ??
            (pkg['turnaroundFr'] as String?) ??
            '';
    final deliverables = ((en ? pkg['deliverablesEn'] : pkg['deliverablesFr'])
                as List<dynamic>? ??
            pkg['deliverablesFr'] as List<dynamic>? ??
            const [])
        .cast<String>();
    final category = (pkg['category'] as String?) ?? '';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_categoryLabel(category))),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              CurrencyUtils.formatXof(
                price,
                Get.find<AppController>().profile?.preferredCurrency,
                approximate: true,
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (turnaround.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${'turnaround_label'.tr} : $turnaround',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (deliverables.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...deliverables.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(d)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.chat_rounded),
                label: Text('contact_advisor'.tr),
                onPressed: () => onContact(pkg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(String raw) {
    switch (raw) {
      case 'dossier_pret':
        return 'service_packages_category_dossier_pret'.tr;
      case 'scholarship_kit':
        return 'service_packages_category_scholarship_kit'.tr;
      case 'visa_kit':
        return 'service_packages_category_visa_kit'.tr;
      case 'consultation':
        return 'case_type_filter_consultation'.tr;
      default:
        return 'service_packages_category_default'.tr;
    }
  }
}
