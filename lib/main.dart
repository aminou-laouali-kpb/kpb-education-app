import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/core/config/app_config.dart';
import 'app/core/config/kpb_supabase_local_storage.dart';
import 'app/core/controllers/app_controller.dart';
import 'app/core/config/app_routes.dart';
import 'app/core/repositories/app_api_client.dart';
import 'app/core/repositories/local_app_repository.dart';
import 'app/core/services/analytics_service.dart';
import 'app/core/services/app_version_gate.dart';
import 'app/core/services/case_message_outbox.dart';
import 'app/core/services/catalog_cache_service.dart';
import 'app/core/services/connectivity_service.dart';
import 'app/core/translations/app_translations.dart';
import 'app/core/ui/app_theme.dart';
import 'app/core/ui/components/kpb_offline_banner.dart';
import 'app/core/ui/portrait_lock.dart';
import 'app/core/navigation/app_boot_screen.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/navigation/shell_tabs.dart';
import 'app/core/services/remote_feature_flags.dart';
import 'app/core/services/security_service.dart';
import 'app/core/services/notification_router.dart';
import 'app/core/services/push_service.dart';
import 'app/core/services/deep_link_service.dart';
import 'package:quick_actions/quick_actions.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPortraitOrientation();

  bool firebaseInitialized = false;

  try {
    // ── Safe Firebase Booting ────────────────────────────────────────────────
    // Les deux SDK Firebase démarrent DÉSACTIVÉS par défaut : la valeur par
    // défaut est posée dans la configuration NATIVE, pas ici.
    //   Android : méta-données `firebase_analytics_collection_enabled` et
    //             `firebase_crashlytics_collection_enabled` à false.
    //   iOS     : clés `FIREBASE_ANALYTICS_COLLECTION_ENABLED` et
    //             `FirebaseCrashlyticsCollectionEnabled` à false.
    // POURQUOI PAS EN DART. Le choix persisté de l'utilisateur n'est connu
    // qu'après `controller.hydrate()`, une trentaine de lignes plus bas :
    // Supabase, Hive, le cache catalogue, l'outbox et le dépôt local passent
    // avant. Tout ce qui serait collecté dans cet intervalle le serait sans
    // consentement. Et pour Crashlytics c'est structurellement pire : la file
    // de rapports non envoyés survit aux lancements, et le SDK natif peut la
    // téléverser au démarrage du processus, avant que la moindre ligne de Dart
    // ne tourne — aucun `setCrashlyticsCollectionEnabled` côté Dart n'arrive
    // à temps. Seule la valeur par défaut native est lue assez tôt.
    //
    // Ce n'est pas une coupure définitive : les deux SDK gardent en
    // SharedPreferences / NSUserDefaults le dernier état posé par
    // `AnalyticsService.setCollectionEnabled`, et cet état PRIME sur la valeur
    // par défaut native. Qui a accepté redémarre donc en collectant, dès le
    // démarrage du processus, sans rien perdre.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Les gestionnaires sont posés tout de suite, avant que le consentement
      // soit lu, et c'est volontaire : ce ne sont pas eux qui décident de la
      // collecte. `recordError` passe par le DataCollectionArbiter du SDK, que
      // la valeur par défaut native ci-dessus laisse à « désactivé ». Les
      // retarder ne protégerait personne et laisserait au contraire les
      // plantages de démarrage non capturés pour qui a accepté.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      firebaseInitialized = true;
    } catch (firebaseError) {
      debugPrint(
          'Firebase/Crashlytics boot skipped (running offline/local-only): $firebaseError');
    }

    // ── PostHog product analytics + session replay ─────────────────────────────
    // Set up early so the "Application Opened" lifecycle event is captured.
    // Inert unless POSTHOG_API_KEY is provided (--dart-define); never blocks
    // boot. Session replay masks all text and images by default — the app shows
    // passports, transcripts and personal data, which must never be recorded.
    //
    // Ce `setup` tourne AVANT `controller.hydrate()`, donc avant que le choix
    // persisté soit connu : `optOut = true` est ce qui empêche la collecte dans
    // cet intervalle (voir le commentaire sur le champ, plus bas).
    if (AppConfig.posthogEnabled) {
      try {
        final phConfig = PostHogConfig(AppConfig.posthogApiKey)
          ..host = AppConfig.posthogHost
          ..captureApplicationLifecycleEvents = true
          ..sessionReplay = true
          // Le SDK démarre OPTÉ DEHORS. Nom vérifié dans le paquet installé
          // (~/.pub-cache/…/posthog_flutter-5.32.0/lib/src/posthog_config.dart,
          // champ `optOut`, transmis au natif par PosthogFlutterPlugin.kt et
          // PosthogFlutterPlugin.swift) — pas recopié de mémoire : une clé
          // inexistante serait ignorée sans erreur.
          //
          // POURQUOI CE CHAMP ET PAS UN DÉPLACEMENT DU `setup` APRÈS hydrate().
          // C'est la solution la plus simple qui ferme VRAIMENT la fenêtre :
          // dans PostHogSDK.setup, `installIntegrations()` (cycle de vie,
          // rejeu de session, capture automatique) est sous `if (!config.optOut)`
          // — rien n'est branché, donc rien n'est capté ni enregistré.
          // Et l'état persisté (`posthog.optOut` dans le stockage du SDK, écrit
          // par `Posthog().enable()/disable()` depuis notre entonnoir de
          // consentement) PRIME sur cette valeur : `config.optOut = stocké ??
          // config.optOut`. Qui a accepté repart donc en collectant dès le
          // `setup`, y compris l'événement « Application Opened ».
          // Déplacer le `setup` après hydrate() aurait au contraire fait perdre
          // cet événement à TOUS les lancements, y compris pour qui a accepté.
          ..optOut = true
          ..debug = kDebugMode;
        phConfig.sessionReplayConfig
          ..maskAllTexts = true
          ..maskAllImages = true;
        await Posthog().setup(phConfig);
      } catch (posthogError) {
        debugPrint('PostHog setup skipped: $posthogError');
      }
    }

    // ── Supabase Auth ────────────────────────────────────────────────────────
    // Store the session (incl. refresh token) in the platform secure store
    // rather than the default plain-text SharedPreferences/NSUserDefaults.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: KpbSecureLocalStorage(),
      ),
    );

    // ── Offline catalog cache (Hive) ─────────────────────────────────────────
    await Hive.initFlutter();
    await CatalogCacheService.init();
    await CaseMessageOutbox.init();

    // ── App bootstrap ────────────────────────────────────────────────────────
    final repository = await LocalAppRepository.create();
    final apiClient = AppApiClient();
    final controller = AppController(
      repository: repository,
      apiClient: apiClient,
    );
    // Si le SDK perd la session pendant l'hydratation (refresh refusé), le
    // contrôleur n'est pas encore enregistré et personne ne réagit : l'app
    // restait dans le shell sans session. On le détecte juste après.
    final hadSessionAtBoot =
        Supabase.instance.client.auth.currentSession != null;
    await controller.hydrate();
    Get.put(controller, permanent: true);
    // PREMIER point du démarrage où le choix persisté est connu — et donc le
    // premier où un collecteur peut légitimement être allumé. Les trois
    // démarrent désactivés (méta-données Android, clés Info.plist, `optOut`
    // PostHog) ; cet appel est ce qui les rallume pour qui a accepté, et ce qui
    // reconduit le refus pour qui a refusé.
    //
    // PAS ATTENDU, volontairement. `AppController.applyAnalyticsConsent` est
    // `void` (elle fait elle-même `unawaited`) : l'attendre demanderait de
    // changer sa signature dans app_controller.dart, hors du périmètre de ce
    // lot. Et l'attendre n'apporterait rien : l'état au démarrage du processus
    // est déjà le bon, puisque la valeur par défaut native est « désactivé » et
    // que l'état persisté du SDK — écrit par ce même appel au lancement
    // précédent — prime dessus. Attendre ne ferait que retarder la première
    // image pour rejouer une décision déjà en vigueur.
    controller.applyAnalyticsConsent();

    final authService = await AuthService.create(apiClient);
    Get.put(authService, permanent: true);
    if (authService.isLoggedIn) {
      if (controller.profile != null) {
        // Profil en cache : l'app s'ouvre tout de suite, la session se
        // termine en arrière-plan (synchro, jeton push, PostHog).
        unawaited(controller.finishAuthSession());
      } else {
        // Sans profil local, il faut le rapatrier avant de router : sinon un
        // compte existant atterrirait sur l'onboarding.
        await controller.finishAuthSession();
      }
    } else if (hadSessionAtBoot) {
      await controller.handleSessionLost();
    }
    // Session perdue plus tard (refresh refusé par le serveur d'auth) : même
    // traitement, une seule fois. Une déconnexion volontaire passe aussi ici,
    // mais `logout()` a déjà vidé le profil, donc c'est sans effet.
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        unawaited(controller.handleSessionLost());
      }
    });

    Get.put(SecurityService());
    // ── Push notifications (FCM) ─────────────────────────────────────────────
    // FCM vit dans Firebase : sans lui (démarrage hors ligne), le push reste
    // inerte et chaque appel du service est un no-op.
    // Le routeur des taps est branché AVANT le push : un tap de démarrage à
    // froid y entre en file, et n'est rejoué qu'après la première image.
    NotificationRouter.instance.attach(apiClient);
    if (firebaseInitialized) {
      await PushService.instance.initialize(backend: apiClient);
    }
    // NB : la demande système d'autorisation n'est faite NI au démarrage NI à
    // l'onboarding, mais au premier « Suivre », derrière une feuille qui dit à
    // quoi elles servent (FollowPushPrimer) — l'invite iOS ne se repose pas.
    // Re-register an already-signed-in user's device token on cold start.
    if (controller.profile != null) {
      unawaited(controller.syncPushIdentity());
    }

    // Force-update gate: async so an unreachable backend never delays boot;
    // replaces the stack with the update screen once the app has mounted.
    unawaited(AppVersionGate.check(apiClient));

    // Drapeaux de fonctionnalité pilotés serveur. Sans attente, comme la garde
    // de version : un backend injoignable ne doit pas retarder le démarrage, et
    // le service échoue fermé sur les constantes de compilation. C'est ce qui
    // permet d'ouvrir l'espace « Études en France » le jour de la campagne en
    // basculant une variable d'environnement, sans soumission App Store.
    unawaited(RemoteFeatureFlags.instance.refresh(apiClient));

    ConnectivityService.instance.startMonitoring();
    ConnectivityService.instance.bindReconnectSync(() async {
      await controller.flushPendingCaseMessages();
      await controller.syncRemoteData(silent: true);
    });

    // ── Quick Actions ────────────────────────────────────────────────────────
    const QuickActions quickActions = QuickActions();
    unawaited(quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_cases') {
        // Reset stack to shell + Dossiers tab (named `/cases` was never registered).
        Get.offAllNamed(AppRoutes.home);
        Future.microtask(
          () => Get.find<AppController>().goToTab(StudentShellTab.cases),
        );
      } else if (shortcutType == 'action_search') {
        Get.toNamed(AppRoutes.search);
      }
    }));

    unawaited(quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_cases',
        localizedTitle: 'Mes Dossiers',
        icon: 'icon_cases',
      ),
      const ShortcutItem(
        type: 'action_search',
        localizedTitle: 'Nouvelle Recherche',
        icon: 'icon_search',
      ),
    ]));

    // ── Deep links (kpb://) ────────────────────────────────────────────────────
    // The scheme is declared natively (iOS Info.plist + Android intent-filter)
    // but nothing consumed the inbound URLs. Start the listener so cold-start
    // and in-flight `kpb://…` links route to the matching screen. It subscribes
    // on the first frame internally, so this never delays boot.
    DeepLinkService.instance.initialize();

    // PostHogWidget wraps the tree so autocapture (taps) and session-replay
    // screenshotting can observe it. Only mount it when PostHog is configured.
    const Widget app = KpbEducationApp();
    runApp(AppConfig.posthogEnabled ? const PostHogWidget(child: app) : app);
    // Première image rendue : le navigateur existe, les taps de notification
    // gardés en file (démarrage à froid) peuvent être rejoués.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationRouter.instance.markReady(),
    );
  } catch (error, stack) {
    if (firebaseInitialized) {
      unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
    } else {
      debugPrint('Boot critical error: $error\n$stack');
    }
    runApp(BootstrapErrorApp(error: error));
  }
}

class BootstrapErrorApp extends StatelessWidget {
  final dynamic error;
  const BootstrapErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Une erreur critique est survenue au démarrage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KpbEducationApp extends StatelessWidget {
  const KpbEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        return GetMaterialApp(
          title: 'KPB Education',
          debugShowCheckedModeBanner: false,
          translations: AppTranslations(),
          // Locale is driven by the saved preference (default French). Runtime
          // switches go through AppController.switchLanguage → Get.updateLocale.
          // Light theme only remains the MVP launch lock.
          locale: Locale(controller.localeCode),
          fallbackLocale: const Locale('fr'),
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.buildTheme(),
          themeMode: ThemeMode.light,
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 280),
          getPages: AppRoutes.pages,
          navigatorObservers: AnalyticsService.instance.navigatorObservers,
          // Le verrou d'app est replacé si une navigation le retire ou passe
          // par-dessus avant le déverrouillage (raccourci, notification).
          routingCallback: (routing) {
            if (Get.isRegistered<SecurityService>()) {
              SecurityService.instance.onRouteChanged(routing?.current);
            }
          },
          // Accessibility: honor the user's OS font-size preference (older
          // parents and low-vision users on budget Android phones often crank
          // it up) but clamp it so extreme scales don't shatter fixed-size
          // chips/badges. Respect — never ignore — text scaling.
          //
          // Plafond 1,5 depuis la build 57 (1,3 avant) : à 1,3, les plus
          // grands réglages d'Android 14+ (jusqu'à 2,0) et les tailles
          // « accessibilité » d'iOS étaient tous ramenés au même cran. Les
          // 22 surfaces de test/core/ui/screen_matrix_test.dart ont été
          // éprouvées à 1,5 sur les deux téléphones : aucun débordement
          // (après correction du bouton de l'écran « aha »).
          //
          // Le bandeau hors ligne vit ICI, au-dessus du Navigator : il couvre
          // toutes les routes (onboarding, fiches, test, dossiers, feuilles),
          // pas seulement les onglets du shell. Il est placé SOUS le
          // MediaQuery borné, pour que son texte suive le même plafond.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scaled = mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.5,
            );
            return MediaQuery(
              data: mq.copyWith(textScaler: scaled),
              child: KpbOfflineBannerHost(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AppBootScreen(),
        );
      },
    );
  }
}
