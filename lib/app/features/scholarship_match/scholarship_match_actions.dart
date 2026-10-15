import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/success_lab_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/models/scholarship_match.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/pending_intent_store.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/ui/components/kpb_toast.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_composer_sheet.dart';

/// La route du test (PAS sous `/scholarships/` : `/scholarships/match` y serait
/// lu comme l'identifiant d'une bourse).
const String scholarshipMatchRoute = AppRoutes.scholarshipMatch;

/// D'où vient l'invité qui veut faire le test (`guest_to_signup`).
const String scholarshipMatchGuestSource = 'scholarship_match_gate';

/// L'identifiant de compte qui range le cache : l'utilisateur Supabase, sinon
/// l'identifiant du profil (compte créé par « Passer »).
String scholarshipMatchUserId(AppController controller) {
  final authId = Get.isRegistered<AuthService>()
      ? Get.find<AuthService>().userId?.trim()
      : null;
  if (authId != null && authId.isNotEmpty) return authId;
  return controller.profile?.id ?? 'anonymous';
}

String scholarshipMatchLang(AppController controller) =>
    controller.localeCode == 'en' ? 'en' : 'fr';

/// Les formes de la carte d'entrée.
enum ScholarshipMatchEntryVariant {
  /// Drapeau fermé, compte parent / partenaire / commercial, ou serveur coupé.
  hidden,

  /// Invité : la carte invite à créer un compte.
  guest,

  /// Élève sans run : « Faire le test ».
  noRun,

  /// Élève avec un run : résumé et « Voir ».
  hasRun,

  /// Run périmé : résumé, « Voir » et « Mettre à jour ».
  stale,
}

/// Quelle carte montrer. Les parents (et les autres comptes non élèves) ne
/// voient JAMAIS le test en v1.
ScholarshipMatchEntryVariant scholarshipMatchEntryVariant(
  AppController controller, {
  ScholarshipMatchStore? store,
}) {
  final s = store ?? ScholarshipMatchStore.instance;
  if (!RemoteFeatureFlags.instance.scholarshipMatchEnabled) {
    return ScholarshipMatchEntryVariant.hidden;
  }
  if (controller.isGuestMode) return ScholarshipMatchEntryVariant.guest;
  if (controller.profile == null) return ScholarshipMatchEntryVariant.hidden;
  if (!controller.isStudent) return ScholarshipMatchEntryVariant.hidden;
  if (!s.enabled) return ScholarshipMatchEntryVariant.hidden;
  if (s.latestRun == null) return ScholarshipMatchEntryVariant.noRun;
  if (s.isStale) return ScholarshipMatchEntryVariant.stale;
  return ScholarshipMatchEntryVariant.hasRun;
}

/// L'invité veut faire le test : on garde l'intention (24 h), puis la porte
/// d'inscription habituelle (`guest_to_signup`, source dédiée).
Future<void> startScholarshipMatchAsGuest() async {
  await PendingIntentStore.save(
    route: scholarshipMatchRoute,
    source: scholarshipMatchGuestSource,
  );
  Get.find<AppController>()
      .leaveGuestForSignup(source: scholarshipMatchGuestSource);
  unawaited(Get.offAll<void>(() => const AppBootScreen()));
}

/// Lit l'intention en attente au premier rendu de l'accueil d'un ÉLÈVE
/// connecté (après l'onboarding ou « Passer » — jamais pendant l'écran des
/// premiers résultats, qui n'est pas l'accueil). Une intention expirée est
/// effacée sans rien ouvrir.
///
/// Rend la route ouverte, ou `null`.
Future<String?> consumeScholarshipMatchPendingIntent(
  AppController controller, {
  DateTime? now,
  void Function(String route)? navigate,
}) async {
  if (controller.isGuestMode ||
      controller.profile == null ||
      !controller.hasCompletedOnboarding) {
    // Pas encore de compte : l'intention attend (ou expire).
    return null;
  }
  final intent = await PendingIntentStore.consume(now: now);
  if (intent == null || intent.route != scholarshipMatchRoute) return null;
  if (!controller.isStudent ||
      !RemoteFeatureFlags.instance.scholarshipMatchEnabled) {
    // Test fermé (ou compte parent) : l'onglet Bourses, comme le lien profond.
    if (controller.isStudent) controller.goToTab(StudentShellTab.scholarships);
    return null;
  }
  (navigate ?? (route) => unawaited(Get.toNamed<void>(route)))(intent.route);
  return intent.route;
}

/// Le texte prérempli de WhatsApp pour une bourse du test.
String scholarshipMatchWhatsAppPrefill(String scholarshipName) =>
    kpbWhatsAppPrefill(
      custom: 'scholarship_match_whatsapp_prefill'
          .trParams({'title': scholarshipName}),
    );

Future<void> openScholarshipMatchWhatsApp({
  required String prefill,
  required String source,
}) =>
    openWhatsAppOrToast(
      prefill: prefill,
      source: source,
      contextType: 'scholarship_match',
    );

/// « Être accompagné par KPB » : rouvre le dossier OUVERT déjà lié à cette
/// bourse (local, puis `GET /cases?scholarshipId=`), sinon ouvre le
/// compositeur prérempli avec `scholarshipId`. Rend vrai quand un dossier
/// existant a été réutilisé.
Future<bool> startScholarshipMatchCase(
  BuildContext context, {
  required MatchItem item,
  AppController? controller,
}) async {
  final app = controller ?? Get.find<AppController>();
  final existing = await app.findOpenScholarshipCase(item.scholarshipId);
  unawaited(AnalyticsService.instance.logScholarshipMatchCaseStarted(
    itemId: item.scholarshipId,
    rank: item.rank,
    reusedExisting: existing != null,
  ));
  if (existing != null) {
    unawaited(Get.toNamed<void>('/cases/${Uri.encodeComponent(existing.id)}'));
    return true;
  }
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CaseComposerSheet(
      caseType: CaseType.scholarshipSupport,
      title: 'scholarship_match_case_title'.trParams({'title': item.name}),
      contextLabel: item.scholarship?.countryName ?? item.name,
      countryId: item.scholarship?.countryId,
      scholarshipId: item.scholarshipId,
    ),
  );
  return false;
}

/// L'accès Success Lab de l'élève (même vérification que la fiche bourse).
/// Fermé dès que le serveur ne peut pas confirmer.
Future<bool> scholarshipMatchSuccessLabAccess(AppController controller) async {
  try {
    final raw = await controller.apiClient.getSuccessLabAccess();
    return SuccessLabApiCodec.accessFromApi(raw).enabled;
  } catch (_) {
    return false;
  }
}

/// « Préparer avec Success Lab » : seulement pour une fenêtre ouverte ou
/// annoncée, avec un cycle connu.
bool scholarshipMatchCanPrepare(MatchItem item) {
  final cycleId = item.cycleId ?? item.window?.cycleId;
  final status = item.window?.status;
  return item.available &&
      cycleId != null &&
      (status == MatchWindowStatus.open ||
          status == MatchWindowStatus.forecast);
}

Future<void> startScholarshipMatchSuccessLab(MatchItem item) async {
  final app = Get.find<AppController>();
  final cycleId = item.cycleId ?? item.window?.cycleId;
  if (cycleId == null) return;
  try {
    if (!await scholarshipMatchSuccessLabAccess(app)) return;
    final repository = SuccessLabRepository.standard(
      apiClient: app.apiClient,
      userId: scholarshipMatchUserId(app),
    );
    final workspace = await repository.createWorkspace(
      scholarshipId: item.scholarshipId,
      cycleId: cycleId,
    );
    await Get.toNamed<void>(AppRoutes.successLabWorkspacePath(workspace.id));
  } catch (error) {
    final failure = SuccessLabRepository.normalizeFailure(error);
    KpbToast.error(
      switch (failure.kind) {
        SuccessLabFailureKind.offline => 'success_lab_start_offline'.tr,
        SuccessLabFailureKind.forbidden => 'success_lab_forbidden_body'.tr,
        SuccessLabFailureKind.featureDisabled => 'success_lab_disabled_body'.tr,
        SuccessLabFailureKind.conflict => 'success_lab_start_conflict'.tr,
        _ => 'success_lab_start_error_body'.tr,
      },
      title: 'success_lab_start_error_title'.tr,
    );
  }
}

/// Le message d'un échec du test, en langage simple.
String scholarshipMatchFailureMessage(ScholarshipMatchFailure failure) =>
    switch (failure) {
      ScholarshipMatchFailure.offline => 'scholarship_match_error_offline'.tr,
      ScholarshipMatchFailure.timeout => 'scholarship_match_error_timeout'.tr,
      ScholarshipMatchFailure.rateLimited =>
        'scholarship_match_error_rate_limited'.tr,
      ScholarshipMatchFailure.unauthorized =>
        'scholarship_match_error_session'.tr,
      ScholarshipMatchFailure.disabled ||
      ScholarshipMatchFailure.forbidden =>
        'scholarship_match_error_unavailable'.tr,
      ScholarshipMatchFailure.server ||
      ScholarshipMatchFailure.invalid =>
        'scholarship_match_error_server'.tr,
    };

/// Reconstruit [builder] quand le drapeau, le magasin du test ou
/// l'AppController changent.
class ScholarshipMatchListener extends StatelessWidget {
  const ScholarshipMatchListener({super.key, required this.builder});

  final Widget Function(BuildContext context, ScholarshipMatchEntryVariant)
      builder;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) => ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          ScholarshipMatchStore.instance,
          RemoteFeatureFlags.instance.flagsVersion,
        ]),
        builder: (context, _) =>
            builder(context, scholarshipMatchEntryVariant(controller)),
      ),
    );
  }
}
