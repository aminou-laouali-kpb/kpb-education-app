import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../controllers/app_controller.dart';
import 'analytics_service.dart';

/// `kind` du push groupé « {n} bourses que tu suis sont ouvertes » (contrat
/// chantier C) : jamais une ligne d'inbox, et sans `scholarshipId` — un tap
/// ouvre « Mes suivis », où toutes ces bourses sont listées.
const String scholarshipOpenedBundleKind = 'scholarship_opened_bundle';

/// Ce que le routeur attend du backend. [AppApiClient] l'implémente.
abstract class NotificationRouterBackend {
  /// `POST /me/notifications/read-by-ref`. Peut lever (404 sur un backend
  /// plus ancien) : le routeur avale l'erreur, la navigation passe d'abord.
  Future<int> markNotificationsReadByRef(List<String> refs);
}

/// Le `kind` d'une charge push (`kind`, sinon `type`), ou `unknown`.
String notificationKindOf(Map<String, dynamic> data) {
  for (final key in const ['kind', 'type']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return 'unknown';
}

/// Destination d'un tap, depuis la charge `data` du message.
///
/// La charge est EXTERNE : on la normalise, et on rend `null` (→ accueil) quand
/// elle ne désigne rien de navigable, pour qu'un tap ne meure jamais en
/// silence. Les anciennes activations de bourse routaient vers la liste et
/// portaient l'identifiant à part : on les promeut vers la fiche.
String? resolvePushRoute(Map<String, dynamic> data) {
  final raw = data['route'];
  var route = raw is String ? AppRoutes.normalizeExternalRoute(raw) : null;
  final scholarshipId = data['scholarshipId'];
  if (route == AppRoutes.scholarships &&
      scholarshipId is String &&
      scholarshipId.trim().isNotEmpty) {
    route = AppRoutes.normalizeExternalRoute(
      AppRoutes.scholarshipDetailPath(scholarshipId.trim()),
    );
  }
  return route;
}

/// La destination RÉELLE d'un tap de notification (push ou centre in-app).
///
/// Le push groupé porte `route: /deadlines` pour les builds qui ne le
/// connaissent pas ; cette build l'ouvre sur « Mes suivis », la liste des
/// bourses suivies — le calendrier ne les montre pas toutes.
String? resolveNotificationRoute(Map<String, dynamic> data) {
  final kind = notificationKindOf(data);
  if (kind == scholarshipOpenedBundleKind || kind == 'bundle') {
    return AppRoutes.saved;
  }
  return resolvePushRoute(data);
}

/// Les références d'inbox d'une charge (`ref`, et `refs` du push groupé —
/// chaîne séparée par des virgules ou liste).
List<String> notificationRefsOf(Map<String, dynamic> data) {
  final refs = <String>[];
  void addAll(Object? raw) {
    if (raw is String) {
      refs.addAll(raw.split(',').map((ref) => ref.trim()));
    } else if (raw is List) {
      refs.addAll(raw.whereType<String>().map((ref) => ref.trim()));
    }
  }

  addAll(data['ref']);
  addAll(data['refs']);
  return refs.where((ref) => ref.isNotEmpty).toSet().toList();
}

/// Ce que l'app renvoie au backend quand l'élève ouvre une notification :
/// l'identifiant de campagne et/ou la clé du rappel — rien d'autre.
Map<String, String> pushOpenedPayload(Map<String, dynamic> data) {
  final payload = <String, String>{};
  for (final key in const ['campaignId', 'notificationKey']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      payload[key] = value.trim();
    }
  }
  return payload;
}

/// Routeur des taps de notification, indépendant du fournisseur de push.
///
/// Trois garanties :
/// 1. **Démarrage à froid.** Un tap qui lance l'app arrive avant que le
///    navigateur existe (le service push démarre avant `runApp`). Il est gardé
///    en FILE jusqu'à [markReady] — appelé après la première image — puis
///    rejoué ; si le navigateur n'est toujours pas monté, on réessaie à l'image
///    suivante au lieu de perdre le tap.
/// 2. **La bonne destination** ([resolveNotificationRoute]) : la fiche de la
///    bourse, « Mes suivis » pour le push groupé, l'accueil sinon.
/// 3. **Lu au tap** : les références d'inbox de la charge sont marquées lues
///    (`read-by-ref`), et `push_opened {kind}` est mesuré.
class NotificationRouter {
  NotificationRouter._();

  static final NotificationRouter instance = NotificationRouter._();

  NotificationRouterBackend? _backend;
  bool _ready = false;
  final List<Map<String, dynamic>> _pending = <Map<String, dynamic>>[];

  /// Remplace la navigation GetX dans les tests.
  @visibleForTesting
  Future<void> Function(String? route)? navigateOverride;

  /// Remplace le test « le navigateur est-il monté ? » dans les tests.
  @visibleForTesting
  bool Function()? navigatorReadyOverride;

  bool get isReady => _ready;

  @visibleForTesting
  int get pendingCount => _pending.length;

  /// Branche le backend (lecture par références). Appelé une fois au démarrage.
  void attach(NotificationRouterBackend backend) => _backend = backend;

  /// La première image est rendue : la file est rejouée.
  void markReady() {
    _ready = true;
    _flush();
  }

  /// Un tap de notification (push au premier plan, en arrière-plan ou à
  /// froid). La mesure et la lecture partent tout de suite ; la navigation
  /// attend [markReady].
  Future<void> open(Map<String, dynamic> data) async {
    final kind = notificationKindOf(data);
    unawaited(AnalyticsService.instance.logPushOpened(kind: kind));
    final refs = notificationRefsOf(data);
    if (refs.isNotEmpty) unawaited(_markRead(refs));
    if (!_ready) {
      _pending.add(Map<String, dynamic>.of(data));
      return;
    }
    await _navigate(data);
  }

  @visibleForTesting
  void debugReset() {
    _backend = null;
    _ready = false;
    _pending.clear();
    navigateOverride = null;
    navigatorReadyOverride = null;
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _markRead(List<String> refs) async {
    try {
      await _backend?.markNotificationsReadByRef(refs);
    } catch (error) {
      // 404 sur un backend sans la route, hors ligne : le tap a déjà ouvert
      // la bonne page, l'entrée restera simplement non lue.
      debugPrint('[NotificationRouter] read-by-ref skipped: $error');
    }
  }

  void _flush({int attempt = 0}) {
    if (_pending.isEmpty) return;
    if (!_navigatorReady()) {
      if (attempt >= 20) {
        debugPrint('[NotificationRouter] navigator never mounted, tap dropped');
        _pending.clear();
        return;
      }
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _flush(attempt: attempt + 1));
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    final queued = List<Map<String, dynamic>>.of(_pending);
    _pending.clear();
    // Seul le DERNIER tap compte : deux taps en file ouvriraient deux pages
    // l'une sur l'autre.
    unawaited(_navigate(queued.last));
  }

  bool _navigatorReady() {
    final override = navigatorReadyOverride;
    if (override != null) return override();
    return Get.key.currentState != null;
  }

  Future<void> _navigate(Map<String, dynamic> data) async {
    final route = resolveNotificationRoute(data);
    // Un élève déconnecté ou en plein onboarding reste où le démarrage l'a
    // mis : pousser une fiche par-dessus l'écran de connexion l'emmènerait sur
    // un 401.
    if (Get.isRegistered<AppController>()) {
      final controller = Get.find<AppController>();
      if (!controller.hasCompletedOnboarding && !controller.isGuestMode) {
        return;
      }
    }
    final navigate = navigateOverride;
    if (navigate != null) {
      await navigate(route);
      return;
    }
    // Pas d'`await` sur la navigation : la future ne se termine qu'au retour
    // de la page ouverte.
    try {
      if (route == null) {
        unawaited(Get.offAllNamed<void>(AppRoutes.home));
      } else {
        unawaited(Get.toNamed<void>(route));
      }
    } catch (error) {
      debugPrint('[NotificationRouter] route "$route" not navigable: $error');
      try {
        unawaited(Get.offAllNamed<void>(AppRoutes.home));
      } catch (_) {}
    }
  }
}
