import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../ai_advisor/ai_consent.dart';
import '../cases/document_review_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bot « Passerelle » (C3 bis) — la notification privée `assist_bridge`.
//
// Le serveur a repéré un besoin dans ce que l'élève a écrit (« je cherche à
// faire relire mon CV », « Campus France, je suis perdu »…). Un tap sur la
// notification (push ou centre de notifications) ouvre CETTE feuille : « Tu
// peux le faire directement dans l'app » → bouton vers la fonction, bouton
// WhatsApp, « Plus tard ». Chaque geste est mesuré (`POST
// /me/assist-bridge/events/:id`), sans jamais bloquer la navigation.
//
// La charge (`data`) est EXTERNE : tout est relu prudemment, un besoin ou une
// fonction inconnus (serveur plus récent) retombent sur un texte générique et
// sur la route servie, si elle est connue de cette build.
// ─────────────────────────────────────────────────────────────────────────────

/// `kind` de la notification passerelle (contrat communauté §15.4).
const String assistBridgeKind = 'assist_bridge';

/// Les besoins du catalogue `ab-1` que cette build sait présenter.
const List<String> assistBridgeKnownNeeds = <String>[
  'document_review',
  'scholarship_match',
  'etudes_en_france',
  'accompaniment',
  'visa',
  'school_choice',
];

/// Ce que l'élève a fait de la feuille — la valeur envoyée au serveur.
enum AssistBridgeChoice {
  openedFeature('opened_feature'),
  openedWhatsapp('opened_whatsapp'),
  dismissed('dismissed');

  const AssistBridgeChoice(this.wire);

  final String wire;
}

/// La charge d'une notification passerelle, relue sans confiance.
@immutable
class AssistBridgePayload {
  const AssistBridgePayload({
    required this.needId,
    required this.feature,
    this.eventId,
    this.route,
    this.whatsapp = false,
  });

  factory AssistBridgePayload.fromData(Map<String, dynamic> data) {
    String? text(String key) {
      final value = data[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty || trimmed.length > 120 ? null : trimmed;
    }

    final eventId = text('eventId');
    return AssistBridgePayload(
      needId: text('needId') ?? 'unknown',
      feature: text('feature') ?? 'unknown',
      eventId:
          eventId != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(eventId)
              ? eventId
              : null,
      route: text('route'),
      // `whatsapp: "kpb"` : la ligne KPB de la configuration de l'app — le
      // serveur n'envoie jamais de numéro.
      whatsapp: text('whatsapp') == 'kpb',
    );
  }

  final String needId;
  final String feature;
  final String? eventId;
  final String? route;
  final bool whatsapp;

  bool get knownNeed => assistBridgeKnownNeeds.contains(needId);
}

/// La fonction cible peut-elle s'ouvrir dans CETTE build ?
///
/// La relecture de document suit le masque des outils IA ; une fonction
/// inconnue n'est proposée que si sa route est connue de cette build.
bool assistBridgeFeatureAvailable(AssistBridgePayload payload) {
  switch (payload.feature) {
    case 'document_review':
      return AppConfig.aiToolsEnabled;
    case 'scholarship_match':
    case 'etudes_en_france':
    case 'new_case':
    case 'services':
    case 'orientation':
      return true;
    default:
      return AppRoutes.normalizeExternalRoute(payload.route) != null;
  }
}

/// Le bouton WhatsApp est-il proposé ? Seulement si la charge le demande ET
/// que la build a une ligne KPB configurée.
bool assistBridgeWhatsAppAvailable(AssistBridgePayload payload) =>
    payload.whatsapp && AppConfig.whatsappNumber.trim().isNotEmpty;

String _needKey(String prefix, AssistBridgePayload payload) =>
    payload.knownNeed ? '${prefix}_${payload.needId}' : '${prefix}_generic';

/// Le message WhatsApp pré-rempli (l'élève écrit à KPB) : `*_prefill`.
@visibleForTesting
String assistBridgePrefillKey(AssistBridgePayload payload) => payload.knownNeed
    ? 'assist_bridge_${payload.needId}_prefill'
    : 'assist_bridge_generic_prefill';

/// Les gestes de la feuille, remplaçables dans les tests.
class AssistBridgeHandlers {
  const AssistBridgeHandlers({
    this.report,
    this.openFeature,
    this.openWhatsApp,
  });

  final Future<void> Function(String eventId, String action)? report;
  final Future<void> Function(AssistBridgePayload payload)? openFeature;
  final Future<void> Function(AssistBridgePayload payload)? openWhatsApp;

  Future<void> _report(
    AssistBridgePayload payload,
    AssistBridgeChoice choice,
  ) async {
    final eventId = payload.eventId;
    if (eventId == null) return;
    try {
      final custom = report;
      if (custom != null) {
        await custom(eventId, choice.wire);
      } else if (Get.isRegistered<AppController>()) {
        await Get.find<AppController>().apiClient.reportAssistBridgeAction(
              eventId,
              choice.wire,
            );
      }
    } catch (error) {
      // Hors ligne, backend plus ancien (404) : la mesure se perd, le geste de
      // l'élève, lui, a déjà eu lieu.
      debugPrint('[AssistBridge] report skipped: $error');
    }
  }
}

/// Ouvre la fonction cible (clé d'abord, route servie ensuite).
Future<void> openAssistBridgeFeature(AssistBridgePayload payload) async {
  switch (payload.feature) {
    case 'document_review':
      final context = Get.context;
      if (context == null || !AppConfig.aiToolsEnabled) return;
      // Même porte que le tiroir des outils : consentement IA d'abord.
      await openAiToolIfConsented(context, () => const DocumentReviewScreen());
      return;
    case 'scholarship_match':
      unawaited(Get.toNamed<void>(AppRoutes.scholarshipMatch));
      return;
    case 'etudes_en_france':
      unawaited(Get.toNamed<void>(AppRoutes.etudesEnFrance));
      return;
    case 'new_case':
      unawaited(Get.toNamed<void>(AppRoutes.caseCreate));
      return;
    case 'services':
      unawaited(Get.toNamed<void>(AppRoutes.services));
      return;
    case 'orientation':
      unawaited(Get.toNamed<void>(AppRoutes.orientation));
      return;
    default:
      final route = AppRoutes.normalizeExternalRoute(payload.route);
      if (route != null) unawaited(Get.toNamed<void>(route));
  }
}

/// Ouvre WhatsApp vers la ligne KPB de l'app, message pré-rempli.
Future<void> openAssistBridgeWhatsApp(AssistBridgePayload payload) =>
    openWhatsAppOrToast(
      prefill: kpbWhatsAppPrefill(custom: assistBridgePrefillKey(payload).tr),
      source: 'assist_bridge',
      contextType: payload.knownNeed ? payload.needId : 'unknown',
    );

/// Le tap d'une notification `assist_bridge` : la feuille, puis le geste choisi.
///
/// Branché sur [NotificationRouter] (push) et sur le centre de notifications.
Future<void> showAssistBridgeSheet(
  Map<String, dynamic> data, {
  BuildContext? context,
  AssistBridgeHandlers handlers = const AssistBridgeHandlers(),
}) async {
  final payload = AssistBridgePayload.fromData(data);
  final ctx = context ?? Get.context;
  if (ctx == null) return;
  ModalRoute<dynamic>? route;
  final choice = await showModalBottomSheet<AssistBridgeChoice>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) {
      route ??= ModalRoute.of(sheetContext);
      return AssistBridgeSheet(payload: payload);
    },
  );
  final picked = choice ?? AssistBridgeChoice.dismissed;
  unawaited(handlers._report(payload, picked));
  // La feuille doit être fermée AVANT d'ouvrir une page ou WhatsApp.
  await route?.completed;
  switch (picked) {
    case AssistBridgeChoice.openedFeature:
      await (handlers.openFeature ?? openAssistBridgeFeature)(payload);
    case AssistBridgeChoice.openedWhatsapp:
      await (handlers.openWhatsApp ?? openAssistBridgeWhatsApp)(payload);
    case AssistBridgeChoice.dismissed:
      break;
  }
}

/// La feuille « Tu peux le faire directement dans l'app ».
class AssistBridgeSheet extends StatefulWidget {
  const AssistBridgeSheet({super.key, required this.payload});

  final AssistBridgePayload payload;

  @override
  State<AssistBridgeSheet> createState() => _AssistBridgeSheetState();
}

class _AssistBridgeSheetState extends State<AssistBridgeSheet> {
  /// Un seul choix : un second tap pendant la fermeture dépilerait l'écran
  /// qui est dessous.
  bool _picked = false;

  void _close(AssistBridgeChoice choice) {
    if (_picked) return;
    _picked = true;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final payload = widget.payload;
    final showFeature = assistBridgeFeatureAvailable(payload);
    final showWhatsApp = assistBridgeWhatsAppAvailable(payload);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('assist-bridge-sheet'),
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          0,
          KpbSpacing.pagePad,
          KpbSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expéditeur : l'équipe KPB, badge « Assistant KPB » (comme le bot
            // Vérif) — jamais le mot « bot ».
            Wrap(
              spacing: KpbSpacing.sm,
              runSpacing: KpbSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                KpbBadgeLight(
                  label: 'assist_bridge_badge'.tr,
                  icon: Icons.support_agent_rounded,
                ),
                Text(
                  'assist_bridge_from'.tr,
                  style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                'assist_bridge_sheet_title'.tr,
                style: KpbTextStyles.title.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              _needKey('assist_bridge_body', payload).tr,
              style: KpbTextStyles.body.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: KpbSpacing.md),
            if (showFeature) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('assist-bridge-feature'),
                  onPressed: () => _close(AssistBridgeChoice.openedFeature),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.md,
                      vertical: KpbSpacing.sm,
                    ),
                  ),
                  // Le libellé passe à la ligne (jamais coupé) à l'échelle 1,5.
                  child: Text(
                    _needKey('assist_bridge_cta', payload).tr,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
            ],
            if (showWhatsApp) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('assist-bridge-whatsapp'),
                  onPressed: () => _close(AssistBridgeChoice.openedWhatsapp),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.md,
                      vertical: KpbSpacing.sm,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.chat_rounded, size: 18),
                      ),
                      const SizedBox(width: KpbSpacing.sm),
                      Flexible(
                        child: Text(
                          'assist_bridge_whatsapp'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('assist-bridge-later'),
                onPressed: () => _close(AssistBridgeChoice.dismissed),
                child: Text('assist_bridge_later'.tr),
              ),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'assist_bridge_settings_hint'.tr,
              style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
