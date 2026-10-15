import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show NavigatorObserver;
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/app_config.dart';
import '../observability/analytics_event_contract.dart';
import '../observability/crashlytics_observability.dart';
import '../observability/posthog_screen_context_observer.dart';
import '../utils/app_logger.dart';

/// Applies one consent decision to one collector. See
/// [AnalyticsService.setCollectionEnabled].
typedef ConsentApplier = Future<void> Function(bool enabled);

Future<void> _applyFirebaseAnalyticsConsent(bool enabled) =>
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);

Future<void> _applyPosthogConsent(bool enabled) =>
    enabled ? Posthog().enable() : Posthog().disable();

/// Thin wrapper around FirebaseAnalytics with typed event helpers.
/// All calls are fire-and-forget — never throw to the caller.
///
/// Every event is mirrored to PostHog when [AppConfig.posthogEnabled] (see
/// [_mirror] / [_mirrorScreen]); when no PostHog key is configured the mirror
/// calls are cheap no-ops and only Firebase runs. PostHog is set up in
/// `main()` — this service only emits events, identifies the user, and exposes
/// the navigator observer used for automatic screen capture.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  // Lazily initialized so unit tests (where Firebase is not bootstrapped) can
  // call any analytics method safely — the LateInitializationError propagates
  // into the surrounding try-catch that every method already provides.
  late final _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Navigator observers to install on the app. Includes PostHog's
  /// [PosthogObserver] (screen views + survey triggers) only when configured.
  /// Built once and cached — GetX rebuilds the root app on every
  /// `controller.update()`, and a fresh observer per rebuild would re-subscribe
  /// the Navigator each time.
  late final List<NavigatorObserver> navigatorObservers = [
    observer,
    if (AppConfig.posthogEnabled) PosthogObserver(),
    // L'écran courant en super propriété, pour les événements natifs
    // (`$rageclick`) dont le `$screen_name` vaut sinon « Flutter ».
    if (AppConfig.posthogEnabled) PosthogScreenContextObserver(),
  ];

  /// Mirrors a Firebase event to PostHog. No-op when PostHog is not configured;
  /// fire-and-forget and never throws (a mirror failure must not break the
  /// Firebase path or the caller).
  void _mirror(String event, [Map<String, Object>? properties]) {
    if (!AppConfig.posthogEnabled) return;
    try {
      unawaited(Posthog().capture(eventName: event, properties: properties));
    } catch (e, s) {
      _logError('posthog.$event', e, s);
    }
  }

  void _mirrorScreen(String screenName) {
    if (!AppConfig.posthogEnabled) return;
    try {
      unawaited(Posthog().screen(screenName: screenName));
    } catch (e, s) {
      _logError('posthog.screen', e, s);
    }
  }

  // ── Identity ────────────────────────────────────────────────────────────

  /// Ties the current PostHog session (and any recorded replay) to the backend
  /// user id — a UUID, not PII. Call on login and on cold start when already
  /// signed in. No-op without PostHog. With `personProfiles: identifiedOnly`,
  /// no person profile is created until this runs.
  Future<void> identifyUser(String userId) async {
    if (!AppConfig.posthogEnabled || userId.trim().isEmpty) return;
    try {
      await Posthog().identify(userId: userId.trim());
    } catch (e, s) {
      _logError('identifyUser', e, s);
    }
  }

  /// Clears the PostHog identity so a subsequent user on the same device starts
  /// a fresh, unlinked session. Called from [logLogout].
  Future<void> _resetIdentity() async {
    if (!AppConfig.posthogEnabled) return;
    try {
      await Posthog().reset();
    } catch (e, s) {
      _logError('resetIdentity', e, s);
    }
  }

  // ── Event sink (test seam) ───────────────────────────────────────────────

  /// Où part un événement, REMPLAÇABLE par un test.
  ///
  /// Même raison que [firebaseAnalyticsConsent] : sans application Firebase par
  /// défaut, `FirebaseAnalytics.instance` lève en test, et le `catch` de chaque
  /// méthode avale l'erreur — un événement qui ne part pas, ou qui part sous un
  /// autre nom, resterait invisible. Quand il est posé, il reçoit le nom ET les
  /// paramètres EXACTS à la place de Firebase. Nul en production.
  @visibleForTesting
  Future<void> Function(String name, Map<String, Object> parameters)?
      logEventSink;

  /// Le seul point d'émission des événements de la bulle d'aide et du renvoi
  /// WhatsApp : le sink s'il est posé, Firebase sinon.
  Future<void> _logEvent(String name, Map<String, Object> parameters) {
    final sink = logEventSink;
    if (sink != null) return sink(name, parameters);
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  // ── Consent ──────────────────────────────────────────────────────────────

  /// The three collectors the "Analyse d'usage" switch governs, as replaceable
  /// fields rather than direct SDK calls.
  ///
  /// The seam exists because the SDK calls cannot be observed from a test: with
  /// no default Firebase app they throw, and the per-collector catch in
  /// [setCollectionEnabled] swallows the throw. A guard written against the
  /// real SDKs would therefore stay green while a collector kept collecting —
  /// which is exactly how crash diagnostics stayed on for months after the
  /// switch shipped.
  @visibleForTesting
  ConsentApplier firebaseAnalyticsConsent = _applyFirebaseAnalyticsConsent;

  @visibleForTesting
  ConsentApplier crashlyticsConsent = applyCrashlyticsConsent;

  @visibleForTesting
  ConsentApplier posthogConsent = _applyPosthogConsent;

  /// Whether the PostHog SDK is wired at all. A field, not a direct read of
  /// [AppConfig.posthogEnabled], because no PostHog key is defined in a test
  /// run: the PostHog branch below would be dead code under test and its
  /// polarity unguarded.
  @visibleForTesting
  bool posthogWired = AppConfig.posthogEnabled;

  /// Turns collection on/off at runtime for ALL THREE collectors the profile
  /// switch claims to govern: Firebase Analytics, Firebase Crashlytics (crash
  /// diagnostics) and PostHog (events + session replay).
  ///
  /// [enabled] false = the user REFUSED: every collector is cut, and pending
  /// crash reports are dropped ([applyCrashlyticsConsent]). true = accepted:
  /// every collector is turned back on.
  ///
  /// This is the single funnel: it is wired both to the profile toggle
  /// (`AppController.setAnalyticsAllowed`) and to the boot-time re-application
  /// of the persisted choice (`AppController.applyAnalyticsConsent`, called
  /// from `main()`), so a refusal survives restarts instead of being forgotten
  /// at the next launch. Never throws.
  Future<void> setCollectionEnabled(bool enabled) async {
    // One try/catch per collector: an SDK that is absent or throws must not
    // leave the remaining collectors still collecting after a refusal.
    await _applyConsent('firebase', firebaseAnalyticsConsent, enabled);
    await _applyConsent('crashlytics', crashlyticsConsent, enabled);
    if (!posthogWired) return;
    await _applyConsent('posthog', posthogConsent, enabled);
  }

  Future<void> _applyConsent(
    String collector,
    ConsentApplier apply,
    bool enabled,
  ) async {
    try {
      await apply(enabled);
    } catch (e, s) {
      _logError('setCollectionEnabled.$collector', e, s);
    }
  }

  static void _logError(String operation, Object error, StackTrace stackTrace) {
    if (error is FirebaseException &&
        error.plugin == 'core' &&
        error.code == 'no-app') {
      return;
    }
    AppLogger.error(
      operation,
      error: error,
      stackTrace: stackTrace,
      tag: 'analytics',
    );
  }

  // ── Screen tracking ────────────────────────────────────────────────────────

  Future<void> logScreen(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      _mirrorScreen(screenName);
    } catch (e, s) {
      _logError('logScreen', e, s);
    }
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      _mirror('login', {'method': method});
    } catch (e, s) {
      _logError('logLogin', e, s);
    }
  }

  Future<void> logRegister({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      _mirror('sign_up', {'method': method});
    } catch (e, s) {
      _logError('logRegister', e, s);
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.logout);
      _mirror(AnalyticsEventName.logout);
      // Unlink the device from the signed-out user so the next session (and any
      // replay) is not attributed to them.
      await _resetIdentity();
    } catch (e, s) {
      _logError('logLogout', e, s);
    }
  }

  // ── Guest / acquisition (KPB-156) ──────────────────────────────────────────

  /// A visitor chose "Explore without an account".
  Future<void> logGuestModeEntered() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.guestModeEntered);
      _mirror(AnalyticsEventName.guestModeEntered);
    } catch (e, s) {
      _logError('logGuestModeEntered', e, s);
    }
  }

  /// A guest chose to sign up. [source] is the gate that triggered it
  /// (e.g. 'cases_gate', 'profile').
  Future<void> logGuestToSignup({String source = 'unknown'}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.guestToSignup,
        parameters: {AnalyticsParamKey.source: source},
      );
      _mirror(
          AnalyticsEventName.guestToSignup, {AnalyticsParamKey.source: source});
    } catch (e, s) {
      _logError('logGuestToSignup', e, s);
    }
  }

  // ── Parcours stories (KPB-169) ──────────────────────────────────────────────

  /// A story became the one on screen. [source] is the surface ('feed',
  /// 'library', 'story_of_week') so completion can be read per surface.
  Future<void> logParcoursView({
    required String slug,
    required String kind,
    required String source,
  }) =>
      _logParcours(AnalyticsEventName.parcoursView, slug, kind, source);

  /// The story was actually consumed — video watched to the end, or written
  /// interview scrolled to the last answer. Paired with [logParcoursView],
  /// this is the completion rate; a view count alone would say nothing.
  Future<void> logParcoursComplete({
    required String slug,
    required String kind,
    required String source,
  }) =>
      _logParcours(AnalyticsEventName.parcoursComplete, slug, kind, source);

  Future<void> _logParcours(
    String name,
    String slug,
    String kind,
    String source,
  ) async {
    final parameters = <String, Object>{
      AnalyticsParamKey.slug: slug,
      AnalyticsParamKey.itemType: kind,
      AnalyticsParamKey.source: source,
    };
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      _mirror(name, parameters);
    } catch (e, s) {
      _logError(name, e, s);
    }
  }

  /// Home "récit de la semaine" card: shown, then tapped through.
  Future<void> logStoryOfWeekViewed(String slug) =>
      _logStoryOfWeek(AnalyticsEventName.storyOfWeekViewed, slug);

  Future<void> logStoryOfWeekOpened(String slug) =>
      _logStoryOfWeek(AnalyticsEventName.storyOfWeekOpened, slug);

  Future<void> _logStoryOfWeek(String name, String slug) async {
    final parameters = <String, Object>{AnalyticsParamKey.slug: slug};
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      _mirror(name, parameters);
    } catch (e, s) {
      _logError(name, e, s);
    }
  }

  // ── Suivre / push (chantier G) ──────────────────────────────────────────

  /// Les propriétés de `push_opened` : la seule clé `kind`, réduite à un
  /// identifiant fermé (lettres, chiffres, `_`, 40 caractères au plus).
  @visibleForTesting
  static Map<String, Object> pushOpenedParams(String kind) {
    final cleaned = kind.trim().toLowerCase();
    final safe =
        RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(cleaned) ? cleaned : 'unknown';
    return <String, Object>{AnalyticsParamKey.kind: safe};
  }

  /// Un tap sur une notification push. [kind] : le `kind` de la charge.
  Future<void> logPushOpened({required String kind}) async {
    final params = pushOpenedParams(kind);
    try {
      await _logEvent(AnalyticsEventName.pushOpened, params);
      _mirror(AnalyticsEventName.pushOpened, params);
    } catch (e, s) {
      _logError('logPushOpened', e, s);
    }
  }

  /// La feuille d'explication du premier « Suivre » s'est affichée.
  Future<void> logPermissionPrimerShown() async {
    try {
      await _logEvent(
          AnalyticsEventName.permissionPrimerShown, const <String, Object>{});
      _mirror(AnalyticsEventName.permissionPrimerShown);
    } catch (e, s) {
      _logError('logPermissionPrimerShown', e, s);
    }
  }

  /// Issue de la feuille : `granted`, `denied` ou `dismissed`.
  Future<void> logPermissionPrimerResult(String result) async {
    final params = <String, Object>{AnalyticsParamKey.result: result};
    try {
      await _logEvent(AnalyticsEventName.permissionPrimerGranted, params);
      _mirror(AnalyticsEventName.permissionPrimerGranted, params);
    } catch (e, s) {
      _logError('logPermissionPrimerResult', e, s);
    }
  }

  // ── Test « Mes 10 bourses » (chantier H) ───────────────────────────────────

  /// Les SEULES clés que les événements `scholarship_match_*` peuvent porter.
  /// Toute autre clé est retirée avant l'envoi : la nationalité, l'âge, la
  /// date de naissance, la moyenne et le niveau de langue ne peuvent donc pas
  /// partir, même par erreur d'un appelant.
  @visibleForTesting
  static const scholarshipMatchAllowedParams = <String>{
    AnalyticsParamKey.source,
    AnalyticsParamKey.missingCount,
    AnalyticsParamKey.isRerun,
    AnalyticsParamKey.matchStep,
    AnalyticsParamKey.index,
    AnalyticsParamKey.total,
    AnalyticsParamKey.changedPrefill,
    AnalyticsParamKey.lastStep,
    AnalyticsParamKey.eligibleCount,
    AnalyticsParamKey.toVerifyCount,
    AnalyticsParamKey.excludedCount,
    AnalyticsParamKey.durationS,
    AnalyticsParamKey.algorithmVersion,
    AnalyticsParamKey.reason,
    AnalyticsParamKey.itemId,
    AnalyticsParamKey.rank,
    AnalyticsParamKey.status,
    AnalyticsParamKey.bulk,
    AnalyticsParamKey.reusedExisting,
    AnalyticsParamKey.suggestion,
    AnalyticsParamKey.enabled,
  };

  /// Les paramètres réellement envoyés : clés autorisées seulement, booléens
  /// en 0/1 (Firebase n'accepte que String ou num), textes bornés à 100.
  @visibleForTesting
  static Map<String, Object> scholarshipMatchParams(
    Map<String, Object?> raw,
  ) {
    final out = <String, Object>{};
    raw.forEach((key, value) {
      if (!scholarshipMatchAllowedParams.contains(key) || value == null) {
        return;
      }
      if (value is bool) {
        out[key] = value ? 1 : 0;
      } else if (value is num) {
        out[key] = value;
      } else {
        final text = value.toString();
        out[key] = text.length > 100 ? text.substring(0, 100) : text;
      }
    });
    return out;
  }

  Future<void> _logScholarshipMatch(
    String name,
    Map<String, Object?> raw,
  ) async {
    final params = scholarshipMatchParams(raw);
    try {
      await _logEvent(name, params);
      _mirror(name, params);
    } catch (e, s) {
      _logError(name, e, s);
    }
  }

  Future<void> logScholarshipMatchEntryViewed({required String source}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchEntryViewed,
          {AnalyticsParamKey.source: source});

  Future<void> logScholarshipMatchStarted({
    required String source,
    required int missingCount,
    required bool isRerun,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchStarted, {
        AnalyticsParamKey.source: source,
        AnalyticsParamKey.missingCount: missingCount,
        AnalyticsParamKey.isRerun: isRerun,
      });

  Future<void> logScholarshipMatchStepViewed({
    required String step,
    required int index,
    required int total,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchStepViewed, {
        AnalyticsParamKey.matchStep: step,
        AnalyticsParamKey.index: index,
        AnalyticsParamKey.total: total,
      });

  Future<void> logScholarshipMatchStepCompleted({
    required String step,
    required bool changedPrefill,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchStepCompleted, {
        AnalyticsParamKey.matchStep: step,
        AnalyticsParamKey.changedPrefill: changedPrefill,
      });

  Future<void> logScholarshipMatchAbandoned({required String lastStep}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchAbandoned,
          {AnalyticsParamKey.lastStep: lastStep});

  Future<void> logScholarshipMatchCompleted({
    required int eligibleCount,
    required int toVerifyCount,
    required int excludedCount,
    required int durationS,
    required String algorithmVersion,
    required bool isRerun,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchCompleted, {
        AnalyticsParamKey.eligibleCount: eligibleCount,
        AnalyticsParamKey.toVerifyCount: toVerifyCount,
        AnalyticsParamKey.excludedCount: excludedCount,
        AnalyticsParamKey.durationS: durationS,
        AnalyticsParamKey.algorithmVersion: algorithmVersion,
        AnalyticsParamKey.isRerun: isRerun,
      });

  Future<void> logScholarshipMatchFailed({required String reason}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchFailed,
          {AnalyticsParamKey.reason: reason});

  Future<void> logScholarshipMatchResultOpened({
    required String itemId,
    required int rank,
    required String status,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchResultOpened, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.rank: rank,
        AnalyticsParamKey.status: status,
      });

  Future<void> logScholarshipMatchFollow({
    required String itemId,
    required int rank,
    required bool bulk,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchFollow, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.rank: rank,
        AnalyticsParamKey.bulk: bulk,
      });

  Future<void> logScholarshipMatchCaseStarted({
    required String itemId,
    required int rank,
    required bool reusedExisting,
  }) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchCaseStarted, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.rank: rank,
        AnalyticsParamKey.reusedExisting: reusedExisting,
      });

  Future<void> logScholarshipMatchBroadenTapped({required String suggestion}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchBroadenTapped,
          {AnalyticsParamKey.suggestion: suggestion});

  Future<void> logScholarshipMatchRerun({required String reason}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchRerun,
          {AnalyticsParamKey.reason: reason});

  Future<void> logScholarshipMatchAlertsToggled({required bool enabled}) =>
      _logScholarshipMatch(AnalyticsEventName.scholarshipMatchAlertsToggled,
          {AnalyticsParamKey.enabled: enabled});

  // ── Daily scholarship (KPB-162) ─────────────────────────────────────────────

  Future<void> logDailyScholarshipViewed(String scholarshipId) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.dailyScholarshipViewed,
        parameters: {AnalyticsParamKey.itemId: scholarshipId},
      );
      _mirror(AnalyticsEventName.dailyScholarshipViewed,
          {AnalyticsParamKey.itemId: scholarshipId});
    } catch (e, s) {
      _logError('logDailyScholarshipViewed', e, s);
    }
  }

  Future<void> logDailyScholarshipOpened(String scholarshipId) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.dailyScholarshipOpened,
        parameters: {AnalyticsParamKey.itemId: scholarshipId},
      );
      _mirror(AnalyticsEventName.dailyScholarshipOpened,
          {AnalyticsParamKey.itemId: scholarshipId});
    } catch (e, s) {
      _logError('logDailyScholarshipOpened', e, s);
    }
  }

  // ── Espace « Études en France » ─────────────────────────────────────────────

  /// La vitrine a été vue. [source] dit par quelle porte (accueil, tiroir,
  /// boîte à outils, lien profond), pour qu'on sache laquelle amène du monde.
  Future<void> logEefTeaserViewed(String source) async {
    final params = {AnalyticsParamKey.source: source};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefTeaserViewed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefTeaserViewed, params);
    } catch (e, s) {
      _logError('logEefTeaserViewed', e, s);
    }
  }

  /// L'espace réel (le hub) a été vu. [source] dit par quelle porte.
  Future<void> logEefSpaceViewed(String source) async {
    final params = <String, Object>{AnalyticsParamKey.source: source};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefSpaceViewed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefSpaceViewed, params);
    } catch (e, s) {
      _logError('logEefSpaceViewed', e, s);
    }
  }

  /// Une tuile du hub a été ouverte. [tile] est un identifiant fermé écrit dans
  /// le code, jamais un texte saisi.
  Future<void> logEefHubTileOpened(String tile) async {
    final params = <String, Object>{AnalyticsParamKey.tile: tile};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefHubTileOpened,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefHubTileOpened, params);
    } catch (e, s) {
      _logError('logEefHubTileOpened', e, s);
    }
  }

  /// Le catalogue a été ouvert. [source] dit par quelle porte.
  Future<void> logEefCatalogViewed(String source) async {
    final params = <String, Object>{AnalyticsParamKey.source: source};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefCatalogViewed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefCatalogViewed, params);
    } catch (e, s) {
      _logError('logEefCatalogViewed', e, s);
    }
  }

  /// Une recherche du catalogue a abouti. Des comptes et des drapeaux, JAMAIS le
  /// texte tapé (voir [AnalyticsEventName.eefCatalogSearched]).
  Future<void> logEefCatalogSearched({
    required bool hasQuery,
    required int filterCount,
    required int resultCount,
    required bool catalogPublished,
  }) async {
    // `? 1 : 0` et non le booléen brut : `FirebaseAnalytics.logEvent` n'accepte
    // que String ou num, et lève sinon — l'exception serait attrapée plus bas et
    // l'événement entier disparaîtrait (voir `logEefInterestDeclared`).
    final params = <String, Object>{
      AnalyticsParamKey.hasQuery: hasQuery ? 1 : 0,
      AnalyticsParamKey.filterCount: filterCount,
      AnalyticsParamKey.resultCount: resultCount,
      AnalyticsParamKey.catalogPublished: catalogPublished ? 1 : 0,
    };
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefCatalogSearched,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefCatalogSearched, params);
    } catch (e, s) {
      _logError('logEefCatalogSearched', e, s);
    }
  }

  /// Les propriétés des deux événements de la carte d'aide, en un seul endroit.
  ///
  /// Trois identifiants fermés écrits dans le code — l'étape (`hub`,
  /// `catalog_empty`…), l'écran porteur (`hub`/`catalog`) et la forme
  /// (`card`/`compact`). Exposée pour qu'un test lise la liste EXACTE des clés :
  /// une propriété ajoutée plus tard (un pays, un nom) fait rougir le test au
  /// lieu de partir en production.
  @visibleForTesting
  static Map<String, Object> eefHelpParams({
    required String step,
    required String surface,
    required String variant,
  }) =>
      <String, Object>{
        AnalyticsParamKey.helpStep: step,
        AnalyticsParamKey.surface: surface,
        AnalyticsParamKey.variant: variant,
      };

  /// La carte d'aide a été montée (une fois par instance).
  Future<void> logEefHelpCardShown({
    required String step,
    required String surface,
    required String variant,
  }) async {
    final params = eefHelpParams(
      step: step,
      surface: surface,
      variant: variant,
    );
    try {
      await _logEvent(AnalyticsEventName.eefHelpCardShown, params);
      _mirror(AnalyticsEventName.eefHelpCardShown, params);
    } catch (e, s) {
      _logError('logEefHelpCardShown', e, s);
    }
  }

  /// Un étudiant a tapé le bouton ou le lien de la carte d'aide. Part AVANT
  /// l'ouverture de WhatsApp : `whatsapp_handoff` dit ensuite si elle a réussi.
  Future<void> logEefHelpCtaTapped({
    required String step,
    required String surface,
    required String variant,
  }) async {
    final params = eefHelpParams(
      step: step,
      surface: surface,
      variant: variant,
    );
    try {
      await _logEvent(AnalyticsEventName.eefHelpCtaTapped, params);
      _mirror(AnalyticsEventName.eefHelpCtaTapped, params);
    } catch (e, s) {
      _logError('logEefHelpCtaTapped', e, s);
    }
  }

  /// Les propriétés de `eef_bubble_opened` : la seule clé `surface`. Exposée
  /// pour qu'un test lise la liste EXACTE des clés, comme [eefHelpParams].
  @visibleForTesting
  static Map<String, Object> eefBubbleOpenedParams({
    required String surface,
  }) =>
      <String, Object>{AnalyticsParamKey.surface: surface};

  /// Le menu de la bulle d'aide a été ouvert. [surface] : `hub` ou `catalog`.
  Future<void> logEefBubbleOpened({required String surface}) async {
    final params = eefBubbleOpenedParams(surface: surface);
    try {
      await _logEvent(AnalyticsEventName.eefBubbleOpened, params);
      _mirror(AnalyticsEventName.eefBubbleOpened, params);
    } catch (e, s) {
      _logError('logEefBubbleOpened', e, s);
    }
  }

  /// Les propriétés de `eef_private_info_opened` : la seule clé `entry`.
  /// Exposée pour qu'un test lise la liste EXACTE des clés.
  @visibleForTesting
  static Map<String, Object> eefPrivateInfoOpenedParams({
    required String entry,
  }) =>
      <String, Object>{AnalyticsParamKey.entry: entry};

  /// La feuille d'information des écoles privées a été ouverte. [entry] :
  /// `bubble` ou `catalog_empty`.
  Future<void> logEefPrivateInfoOpened({required String entry}) async {
    final params = eefPrivateInfoOpenedParams(entry: entry);
    try {
      await _logEvent(AnalyticsEventName.eefPrivateInfoOpened, params);
      _mirror(AnalyticsEventName.eefPrivateInfoOpened, params);
    } catch (e, s) {
      _logError('logEefPrivateInfoOpened', e, s);
    }
  }

  /// Les propriétés de `eef_tour_shown` : la seule clé `tour_trigger`. Exposée
  /// pour qu'un test lise la liste EXACTE des clés.
  @visibleForTesting
  static Map<String, Object> eefTourShownParams({required String trigger}) =>
      <String, Object>{AnalyticsParamKey.tourTrigger: trigger};

  /// La visite guidée du hub s'est affichée. [trigger] : `first_open` ou
  /// `replay`.
  Future<void> logEefTourShown({required String trigger}) async {
    final params = eefTourShownParams(trigger: trigger);
    try {
      await _logEvent(AnalyticsEventName.eefTourShown, params);
      _mirror(AnalyticsEventName.eefTourShown, params);
    } catch (e, s) {
      _logError('logEefTourShown', e, s);
    }
  }

  /// Les propriétés de `eef_tour_completed` : `tour_exit` (texte fermé) et
  /// `tour_cards_seen` (un ENTIER). Exposée pour qu'un test lise la liste
  /// EXACTE des clés.
  @visibleForTesting
  static Map<String, Object> eefTourCompletedParams({
    required String exit,
    required int cardsSeen,
  }) =>
      <String, Object>{
        AnalyticsParamKey.tourExit: exit,
        AnalyticsParamKey.tourCardsSeen: cardsSeen,
      };

  /// La visite guidée du hub s'est fermée. [exit] : `finished` ou `skipped` ;
  /// [cardsSeen] : le nombre de cartes atteintes.
  Future<void> logEefTourCompleted({
    required String exit,
    required int cardsSeen,
  }) async {
    final params = eefTourCompletedParams(exit: exit, cardsSeen: cardsSeen);
    try {
      await _logEvent(AnalyticsEventName.eefTourCompleted, params);
      _mirror(AnalyticsEventName.eefTourCompleted, params);
    } catch (e, s) {
      _logError('logEefTourCompleted', e, s);
    }
  }

  /// Le catalogue n'a pas pu répondre. [reason] : `network` ou `server`.
  Future<void> logEefCatalogFailed(String reason) async {
    final params = <String, Object>{AnalyticsParamKey.reason: reason};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefCatalogFailed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefCatalogFailed, params);
    } catch (e, s) {
      _logError('logEefCatalogFailed', e, s);
    }
  }

  /// Un étudiant a déclaré son intérêt — et dit s'il l'était pour le payant.
  ///
  /// `fieldCount` et non la liste des filières : un compte suffit à segmenter,
  /// et n'expose pas le détail du profil d'un mineur dans une charge analytique.
  Future<void> logEefInterestDeclared({
    required bool wantsPremium,
    required int fieldCount,
    String? currentLevel,
  }) async {
    final params = <String, Object>{
      // `? 1 : 0` et NON le booléen brut. `FirebaseAnalytics.logEvent` assert
      // `value is String || value is num` : un `bool` fait lever en debug,
      // l'exception est attrapée par le `try` plus bas, et c'est TOUT
      // l'événement qui disparaît — celui dont le contrat dit qu'il est « la
      // seule mesure directe de la demande pour le Premium ». Les six autres
      // booléens de ce fichier passent déjà par cette conversion ; celui-ci ne
      // le faisait pas.
      AnalyticsParamKey.wantsPremium: wantsPremium ? 1 : 0,
      AnalyticsParamKey.fieldCount: fieldCount,
      if (currentLevel != null && currentLevel.isNotEmpty)
        AnalyticsParamKey.currentLevel: currentLevel,
    };
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefInterestDeclared,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefInterestDeclared, params);
    } catch (e, s) {
      _logError('logEefInterestDeclared', e, s);
    }
  }

  /// Un étudiant s'est inscrit sur la liste d'attente Karatou Premium.
  ///
  /// La seule mesure directe de la demande pour le Pass. Émis UNIQUEMENT après
  /// confirmation du serveur : l'émettre au tap aurait compté des inscriptions
  /// que la base n'a jamais reçues, et gonflé précisément le chiffre qui doit
  /// décider d'un lancement.
  Future<void> logPremiumWaitlistJoined() async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.premiumWaitlistJoined,
      );
      _mirror(
          AnalyticsEventName.premiumWaitlistJoined, const <String, Object>{});
    } catch (e, s) {
      _logError('logPremiumWaitlistJoined', e, s);
    }
  }

  /// Une inscription à la liste d'attente a ÉCHOUÉ.
  ///
  /// La moitié qui manque toujours : sans elle, une panne du backend produit la
  /// même courbe plate que l'absence d'intérêt. [reason] reste grossier
  /// (`network`, `unauthorized`, `server`) — on cherche à distinguer une panne
  /// d'un désintérêt, pas à journaliser des messages d'erreur.
  Future<void> logPremiumWaitlistFailed(String reason) async {
    final params = <String, Object>{AnalyticsParamKey.reason: reason};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.premiumWaitlistFailed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.premiumWaitlistFailed, params);
    } catch (e, s) {
      _logError('logPremiumWaitlistFailed', e, s);
    }
  }

  /// Une déclaration d'intérêt a ÉCHOUÉ.
  ///
  /// Cet événement est la moitié qui manque toujours. Sans lui, un backend en
  /// panne le jour du lancement produit exactement la même courbe que
  /// « personne n'est intéressé » — et c'est la conclusion inverse de la
  /// vérité qu'on tirerait du tableau de bord. [reason] reste grossier
  /// (`network`, `unauthorized`, `server`) : on cherche à distinguer une panne
  /// d'un désintérêt, pas à journaliser des messages d'erreur.
  Future<void> logEefInterestFailed(String reason) async {
    final params = {AnalyticsParamKey.reason: reason};
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.eefInterestFailed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.eefInterestFailed, params);
    } catch (e, s) {
      _logError('logEefInterestFailed', e, s);
    }
  }

  // ── Shared result cards (KPB-165) ───────────────────────────────────────────

  /// A result card was shared. [withImage] is false when the PNG could not be
  /// rendered and only the text (with its invite link) went out.
  Future<void> logShareCard({
    required String source,
    required bool withImage,
    required bool success,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParamKey.source: source,
        AnalyticsParamKey.withImage: withImage ? 1 : 0,
        AnalyticsParamKey.success: success ? 1 : 0,
      };
      await _analytics.logEvent(
        name: AnalyticsEventName.shareCard,
        parameters: params,
      );
      _mirror(AnalyticsEventName.shareCard, params);
    } catch (e, s) {
      _logError('logShareCard', e, s);
    }
  }

  // ── "Mon plan" progress (KPB-164) ───────────────────────────────────────────

  /// Current unified progress + the action being proposed. One event per change,
  /// so retention analysis can chart progress over time per user.
  Future<void> logMyPlanProgress({
    required int percent,
    required String nextStep,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParamKey.percent: percent,
        AnalyticsParamKey.nextStep: nextStep,
      };
      await _analytics.logEvent(
        name: AnalyticsEventName.myPlanProgress,
        parameters: params,
      );
      _mirror(AnalyticsEventName.myPlanProgress, params);
    } catch (e, s) {
      _logError('logMyPlanProgress', e, s);
    }
  }

  // ── Onboarding funnel (KPB-158) ─────────────────────────────────────────────

  Future<void> logOnboardingStepViewed({
    required int step,
    required int stepCount,
    required String accountType,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParamKey.step: step,
        AnalyticsParamKey.stepCount: stepCount,
        AnalyticsParamKey.accountType: accountType,
      };
      await _analytics.logEvent(
        name: AnalyticsEventName.onboardingStepViewed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.onboardingStepViewed, params);
    } catch (e, s) {
      _logError('logOnboardingStepViewed', e, s);
    }
  }

  Future<void> logOnboardingCompleted({required String accountType}) async {
    try {
      final params = <String, Object>{
        AnalyticsParamKey.accountType: accountType,
      };
      await _analytics.logEvent(
        name: AnalyticsEventName.onboardingCompleted,
        parameters: params,
      );
      _mirror(AnalyticsEventName.onboardingCompleted, params);
    } catch (e, s) {
      _logError('logOnboardingCompleted', e, s);
    }
  }

  Future<void> logOnboardingSkipped({required int step}) async {
    try {
      final params = <String, Object>{AnalyticsParamKey.step: step};
      await _analytics.logEvent(
        name: AnalyticsEventName.onboardingSkipped,
        parameters: params,
      );
      _mirror(AnalyticsEventName.onboardingSkipped, params);
    } catch (e, s) {
      _logError('logOnboardingSkipped', e, s);
    }
  }

  /// Les raisons fermées d'un échec de contrôle de l'onboarding.
  static const onboardingValidationReasons = <String>{
    'required_fields',
    'consent_missing',
    'birth_date_missing',
    'under_minimum_age',
    'guardian_incomplete',
    'fields_missing',
    'countries_missing',
  };

  /// Les propriétés de `onboarding_validation_failed` : `step` et `reason`,
  /// rien d'autre. Exposée pour qu'un test lise la liste EXACTE des clés.
  @visibleForTesting
  static Map<String, Object> onboardingValidationParams({
    required int step,
    required String reason,
  }) =>
      <String, Object>{
        AnalyticsParamKey.step: step,
        AnalyticsParamKey.reason: reason,
      };

  /// « Continuer » tapé alors que la page ne passe pas le contrôle. [reason]
  /// est l'une de [onboardingValidationReasons] — jamais une valeur saisie.
  Future<void> logOnboardingValidationFailed({
    required int step,
    required String reason,
  }) async {
    final params = onboardingValidationParams(step: step, reason: reason);
    try {
      await _logEvent(AnalyticsEventName.onboardingValidationFailed, params);
      _mirror(AnalyticsEventName.onboardingValidationFailed, params);
    } catch (e, s) {
      _logError('logOnboardingValidationFailed', e, s);
    }
  }

  /// A sign-in / sign-up attempt failed. [method] is 'google' | 'email';
  /// [reason] a coarse code ('oauth_error', 'rate_limited', 'send_error',
  /// 'verify_error'). Makes auth drop-off attributable per method.
  Future<void> logAuthFailed({
    required String method,
    required String reason,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParamKey.method: method,
        AnalyticsParamKey.reason: reason,
      };
      await _analytics.logEvent(
        name: AnalyticsEventName.authFailed,
        parameters: params,
      );
      _mirror(AnalyticsEventName.authFailed, params);
    } catch (e, s) {
      _logError('logAuthFailed', e, s);
    }
  }

  // ── Orientation events ────────────────────────────────────────────────────

  Future<void> logOrientationStart() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.orientationStart);
      _mirror(AnalyticsEventName.orientationStart);
    } catch (e, s) {
      _logError('logOrientationStart', e, s);
    }
  }

  Future<void> logOrientationComplete({
    required int totalQuestions,
    required int matchCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.orientationComplete,
        parameters: {
          AnalyticsParamKey.totalQuestions: totalQuestions,
          AnalyticsParamKey.matchCount: matchCount,
        },
      );
      _mirror(AnalyticsEventName.orientationComplete, {
        AnalyticsParamKey.totalQuestions: totalQuestions,
        AnalyticsParamKey.matchCount: matchCount,
      });
    } catch (e, s) {
      _logError('logOrientationComplete', e, s);
    }
  }

  // ── Search events ─────────────────────────────────────────────────────────

  Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
      _mirror('search', {'search_term': query});
    } catch (e, s) {
      _logError('logSearch', e, s);
    }
  }

  // ── Referral loop (KPB-69) ──────────────────────────────────────────────────

  Future<void> logReferralInviteShared() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.referralInviteShared);
      _mirror(AnalyticsEventName.referralInviteShared);
    } catch (e, s) {
      _logError('logReferralInviteShared', e, s);
    }
  }

  Future<void> logReferralRedeemed() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.referralRedeemed);
      _mirror(AnalyticsEventName.referralRedeemed);
    } catch (e, s) {
      _logError('logReferralRedeemed', e, s);
    }
  }

  // ── Content events ────────────────────────────────────────────────────────

  Future<void> logSaveItem({
    required String itemId,
    required String itemType,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.saveItem,
        parameters: {
          AnalyticsParamKey.itemId: itemId,
          AnalyticsParamKey.itemType: itemType,
        },
      );
      _mirror(AnalyticsEventName.saveItem, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.itemType: itemType,
      });
    } catch (e, s) {
      _logError('logSaveItem', e, s);
    }
  }

  Future<void> logUnsaveItem({
    required String itemId,
    required String itemType,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.unsaveItem,
        parameters: {
          AnalyticsParamKey.itemId: itemId,
          AnalyticsParamKey.itemType: itemType,
        },
      );
      _mirror(AnalyticsEventName.unsaveItem, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.itemType: itemType,
      });
    } catch (e, s) {
      _logError('logUnsaveItem', e, s);
    }
  }

  /// `view_item` : un contenu du catalogue a été ouvert. [category] dit sa
  /// famille (`scholarship`, `program`, `country`, `institution`) — sans elle,
  /// seules les bourses étaient comptées, et les programmes et pays (les deux
  /// fiches les plus ouvertes après l'accueil) restaient invisibles.
  Future<void> _logViewItem(String itemId, String category) async {
    try {
      final sink = logEventSink;
      if (sink != null) {
        await sink('view_item', viewItemParams(itemId, category));
      } else {
        await _analytics.logViewItem(
          items: [AnalyticsEventItem(itemId: itemId, itemCategory: category)],
        );
      }
      _mirror('view_item', viewItemParams(itemId, category));
    } catch (e, s) {
      _logError('logViewItem.$category', e, s);
    }
  }

  /// Les propriétés de `view_item` côté PostHog : l'identifiant du contenu
  /// (un id de catalogue, pas une donnée personnelle) et sa famille.
  @visibleForTesting
  static Map<String, Object> viewItemParams(String itemId, String category) =>
      <String, Object>{
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.itemCategory: category,
      };

  Future<void> logViewInstitution(String institutionId) =>
      _logViewItem(institutionId, 'institution');

  Future<void> logViewScholarship(String scholarshipId) =>
      _logViewItem(scholarshipId, 'scholarship');

  Future<void> logViewProgram(String programId) =>
      _logViewItem(programId, 'program');

  Future<void> logViewCountry(String countryId) =>
      _logViewItem(countryId, 'country');

  // ── Coach IA ─────────────────────────────────────────────────────────────

  /// Les propriétés de `ai_coach_message_sent` : trois valeurs fermées ou
  /// numériques, JAMAIS le texte de la question. [quotaRemaining] vaut -1 quand
  /// le serveur ne l'a pas dit.
  @visibleForTesting
  static Map<String, Object> coachMessageParams({
    required String source,
    required String result,
    int? quotaRemaining,
  }) =>
      <String, Object>{
        AnalyticsParamKey.source: source,
        AnalyticsParamKey.result: result,
        AnalyticsParamKey.quotaRemaining: quotaRemaining ?? -1,
      };

  /// Un tour du coach s'est terminé. [source] : `input` ou `suggestion` ;
  /// [result] : `ok`, `quota_refused`, `error` ou `unreachable`.
  Future<void> logCoachMessageSent({
    required String source,
    required String result,
    int? quotaRemaining,
  }) async {
    final params = coachMessageParams(
      source: source,
      result: result,
      quotaRemaining: quotaRemaining,
    );
    try {
      await _logEvent(AnalyticsEventName.aiCoachMessageSent, params);
      _mirror(AnalyticsEventName.aiCoachMessageSent, params);
    } catch (e, s) {
      _logError('logCoachMessageSent', e, s);
    }
  }

  /// L'écran du coach n'a pas pu se charger (quota, suggestions, historique).
  Future<void> logCoachLoadFailed() async {
    try {
      await _logEvent(AnalyticsEventName.aiCoachLoadFailed, const {});
      _mirror(AnalyticsEventName.aiCoachLoadFailed);
    } catch (e, s) {
      _logError('logCoachLoadFailed', e, s);
    }
  }

  Future<void> logCompareInstitutions(List<String> ids) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.compareInstitutions,
        parameters: {
          AnalyticsParamKey.count: ids.length,
          AnalyticsParamKey.ids: ids.join(','),
        },
      );
      _mirror(AnalyticsEventName.compareInstitutions, {
        AnalyticsParamKey.count: ids.length,
        AnalyticsParamKey.ids: ids.join(','),
      });
    } catch (e, s) {
      _logError('logCompareInstitutions', e, s);
    }
  }

  // ── Cases events ──────────────────────────────────────────────────────────

  Future<void> logCaseCreated({required String caseType}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseCreated,
        parameters: {AnalyticsParamKey.caseType: caseType},
      );
      _mirror(AnalyticsEventName.caseCreated,
          {AnalyticsParamKey.caseType: caseType});
    } catch (e, s) {
      _logError('logCaseCreated', e, s);
    }
  }

  Future<void> logCaseViewed(String caseId) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseViewed,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(
          AnalyticsEventName.caseViewed, {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logCaseViewed', e, s);
    }
  }

  Future<void> logDocumentUploaded({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.documentUploaded,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(AnalyticsEventName.documentUploaded,
          {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logDocumentUploaded', e, s);
    }
  }

  Future<void> logMessageSent({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseMessageSent,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(AnalyticsEventName.caseMessageSent,
          {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logMessageSent', e, s);
    }
  }

  // ── Conversion events ─────────────────────────────────────────────────────

  /// Fired the instant a user is handed off to a KPB advisor on WhatsApp — the
  /// core lead→advisor-contact conversion step. [source] is the call site
  /// (e.g. 'case_detail', 'program_detail', 'service_packages') and
  /// [contextType] the kind of context attached (e.g. 'case', 'program',
  /// 'service', 'destination', 'fraud_report', 'unknown'). [success] is false
  /// when WhatsApp could not be opened — a lost conversion, which would
  /// otherwise be invisible in the funnel.
  Future<void> logWhatsAppHandoff({
    String source = 'unknown',
    String contextType = 'unknown',
    bool success = true,
  }) async {
    final params = <String, Object>{
      AnalyticsParamKey.source: source,
      AnalyticsParamKey.contextType: contextType,
      AnalyticsParamKey.success: success ? 1 : 0,
    };
    try {
      await _logEvent(AnalyticsEventName.whatsappHandoff, params);
      _mirror(AnalyticsEventName.whatsappHandoff, params);
    } catch (e, s) {
      _logError('logWhatsAppHandoff', e, s);
    }
  }

  // ── Profile events ────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.profileUpdated);
      _mirror(AnalyticsEventName.profileUpdated);
    } catch (e, s) {
      _logError('logProfileUpdated', e, s);
    }
  }

  Future<void> logThemeToggled(bool isDark) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.themeToggled,
        parameters: {AnalyticsParamKey.theme: isDark ? 'dark' : 'light'},
      );
      _mirror(AnalyticsEventName.themeToggled,
          {AnalyticsParamKey.theme: isDark ? 'dark' : 'light'});
    } catch (e, s) {
      _logError('logThemeToggled', e, s);
    }
  }

  // ── Sync telemetry (Phase 3 data reliability) ─────────────────────────────

  /// Les propriétés de `sync_full_complete`. Sur un échec, `failure_stage`
  /// (`account` : profil, dossiers ou favoris ; `catalog` : le catalogue n'a pu
  /// venir ni du serveur ni du cache) et `error_kind` (valeur fermée de
  /// [SyncErrorKind]) disent où et pourquoi. Jamais un message d'erreur brut :
  /// il peut contenir une URL avec un identifiant.
  @visibleForTesting
  static Map<String, Object> fullSyncParams({
    required bool success,
    required int elapsedMs,
    required int catalogHiveFallbackCount,
    String? failureStage,
    String? errorKind,
  }) =>
      <String, Object>{
        AnalyticsParamKey.success: success ? 1 : 0,
        AnalyticsParamKey.elapsedMs: elapsedMs,
        AnalyticsParamKey.catalogHiveFallbackCount: catalogHiveFallbackCount,
        if (failureStage != null) AnalyticsParamKey.failureStage: failureStage,
        if (errorKind != null) AnalyticsParamKey.errorKind: errorKind,
      };

  Future<void> logFullSyncResult({
    required bool success,
    required int elapsedMs,
    required int catalogHiveFallbackCount,
    String? failureStage,
    String? errorKind,
  }) async {
    final params = fullSyncParams(
      success: success,
      elapsedMs: elapsedMs,
      catalogHiveFallbackCount: catalogHiveFallbackCount,
      failureStage: failureStage,
      errorKind: errorKind,
    );
    try {
      await _logEvent(AnalyticsEventName.syncFullComplete, params);
      _mirror(AnalyticsEventName.syncFullComplete, params);
    } catch (e, s) {
      _logError('logFullSyncResult', e, s);
    }
  }

  Future<void> logSyncConflict({
    required String domain,
    required String resolution,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.syncConflictResolved,
        parameters: {
          AnalyticsParamKey.domain: domain,
          AnalyticsParamKey.resolution: resolution,
        },
      );
      _mirror(AnalyticsEventName.syncConflictResolved, {
        AnalyticsParamKey.domain: domain,
        AnalyticsParamKey.resolution: resolution,
      });
    } catch (e, s) {
      _logError('logSyncConflict', e, s);
    }
  }

  Future<void> logCatalogSyncFallback({
    required String resource,
    required int attempts,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.syncCatalogHiveFallback,
        parameters: {
          AnalyticsParamKey.resource: resource,
          AnalyticsParamKey.attempts: attempts,
        },
      );
      _mirror(AnalyticsEventName.syncCatalogHiveFallback, {
        AnalyticsParamKey.resource: resource,
        AnalyticsParamKey.attempts: attempts,
      });
    } catch (e, s) {
      _logError('logCatalogSyncFallback', e, s);
    }
  }
}
