import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/core/config/app_config.dart';
import 'app/core/config/kpb_secure_storage.dart';
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
import 'app/core/navigation/entry_wall.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/navigation/shell_tabs.dart';
import 'app/core/services/remote_feature_flags.dart';
import 'app/core/services/referral_attribution.dart';
import 'app/core/services/security_service.dart';
import 'app/core/services/notification_router.dart';
import 'app/core/services/push_service.dart';
import 'app/core/services/deep_link_service.dart';
import 'app/features/assist_bridge/assist_bridge_sheet.dart';
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
    // Bot « Passerelle » : un tap `assist_bridge` ouvre sa feuille.
    NotificationRouter.instance.assistBridgeOpener = showAssistBridgeSheet;
    // Une réponse de l'équipe dans un dossier : on relit les dossiers aussitôt.
    PushService.onCaseReply =
        () => controller.syncRemoteData(silent: true, force: true);
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

    // Garde de mise à jour forcée : évaluée sur chaque réponse FRAÎCHE de
    // `/config/app` (démarrage, nouveaux essais, retour au premier plan), sans
    // second appel réseau. Elle remplace la pile par l'écran de mise à jour
    // une fois l'app montée, et échoue ouverte.
    RemoteFeatureFlags.instance.onFreshConfig =
        (config) => unawaited(AppVersionGate.evaluate(config));

    // La dernière réponse du serveur, gardée sur le téléphone : l'app démarre
    // sur elle au lieu de tout refermer en attendant le réseau (audit avant la
    // 59). Ne lève jamais et ne touche pas au réseau.
    await RemoteFeatureFlags.instance.restoreFromCache();

    // Drapeaux de fonctionnalité pilotés serveur. Sans attente, comme la garde
    // de version : un backend injoignable ne doit pas retarder le démarrage, et
    // le service échoue fermé sur les constantes de compilation. C'est ce qui
    // permet d'ouvrir l'espace « Études en France » le jour de la campagne en
    // basculant une variable d'environnement, sans soumission App Store.
    //
    // Le Play Install Referrer (parrainage, build 57) est lu APRÈS les
    // drapeaux : sa lecture dépend de `features.referralInstallReferrer`, et
    // elle n'a lieu qu'une fois par installation (Android seulement). Rien ne
    // part vers le serveur : le code trouvé ne fait que préremplir un champ.
    unawaited(RemoteFeatureFlags.instance
        .refresh(apiClient, retryOnFailure: true)
        .then(
          (_) => ReferralAttribution.instance.captureInstallReferrerOnce(
            enabled: RemoteFeatureFlags.instance.referralInstallReferrerEnabled,
          ),
        ));

    ConnectivityService.instance.startMonitoring();
    ConnectivityService.instance.bindReconnectSync(() async {
      // Un échec de /config/app au lancement ne doit pas masquer Études en
      // France et la Communauté jusqu'au prochain démarrage : au retour du
      // réseau on relit les drapeaux s'ils n'ont jamais été lus.
      if (!RemoteFeatureFlags.instance.loaded) {
        await RemoteFeatureFlags.instance.refresh(apiClient);
      }
      await controller.flushPendingCaseMessages();
      await controller.syncRemoteData(silent: true);
    });
    // Retour au premier plan : relance la file des messages de dossier, que
    // rien d'autre ne vidait sans transition de réseau (revue avant la 58), et
    // relit `/config/app` (au plus toutes les cinq minutes) : un interrupteur
    // ouvert ou refermé, une mise à jour devenue obligatoire, un numéro de
    // contact changé doivent atteindre l'app restée ouverte.
    AppLifecycleListener(onResume: () {
      controller.onAppResumed();
      unawaited(RemoteFeatureFlags.instance.refreshIfStale(apiClient));
    });

    // ── Quick Actions ────────────────────────────────────────────────────────
    const QuickActions quickActions = QuickActions();
    unawaited(quickActions.initialize((String shortcutType) {
      // Un raccourci de l'icône ne contourne pas l'écran d'entrée : sans
      // compte ni mode invité, on reste où le démarrage a mis l'élève.
      if (!hasPassedEntryWall()) return;
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

    // Les traductions de GetX ne sont chargées qu'au montage de l'app : on
    // choisit ici sur la langue gardée par le contrôleur. Les libellés
    // suivent donc la langue de l'app au lancement suivant.
    final shortcutsInEnglish = controller.localeCode == 'en';
    unawaited(quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'action_cases',
        localizedTitle: shortcutsInEnglish ? 'My cases' : 'Mes dossiers',
        icon: 'icon_cases',
      ),
      ShortcutItem(
        type: 'action_search',
        localizedTitle:
            shortcutsInEnglish ? 'New search' : 'Nouvelle recherche',
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

/// L'écran de dernier recours : l'app n'a pas pu démarrer.
///
/// ## Ce qui a changé à la 59 (audit avant l'archive)
///
/// Il n'avait qu'un texte brut et aucun bouton. Quand la cause était un
/// stockage local abîmé, il revenait à CHAQUE lancement, et la seule issue
/// était d'effacer les données de l'app depuis les réglages du téléphone — un
/// geste que peu d'élèves connaissent. Il propose maintenant de le faire
/// lui-même : effacer les données locales, puis rouvrir.
///
/// Les deux stockages qui pouvaient le provoquer se réparent désormais seuls
/// (cache du catalogue, file des messages, session illisible) ; cet écran est
/// la bretelle pour ce qui resterait.
///
/// Aucune traduction n'est chargée à ce stade (`GetMaterialApp` n'a jamais été
/// monté) : les deux langues sont écrites ici, choisies sur celle du téléphone.
class BootstrapErrorApp extends StatefulWidget {
  final dynamic error;

  /// L'effacement des données locales, injectable pour les tests.
  final Future<void> Function()? onReset;

  const BootstrapErrorApp({super.key, required this.error, this.onReset});

  @override
  State<BootstrapErrorApp> createState() => _BootstrapErrorAppState();
}

enum _BootResetStep { idle, confirming, working, done }

class _BootstrapErrorAppState extends State<BootstrapErrorApp> {
  _BootResetStep _step = _BootResetStep.idle;

  bool get _english =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en';

  String _t(String fr, String en) => _english ? en : fr;

  Future<void> _reset() async {
    setState(() => _step = _BootResetStep.working);
    try {
      await (widget.onReset ?? resetLocalAppData)();
    } catch (_) {
      // Chaque effacement est déjà isolé ; rien ne doit empêcher d'afficher la
      // suite, qui dit quoi faire.
    }
    if (!mounted) return;
    setState(() => _step = _BootResetStep.done);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Builder(builder: _content),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = _step == _BootResetStep.done;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle_outline : Icons.error_outline,
          color: done ? Colors.green : Colors.red,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          done
              ? _t('C\'est fait.', 'Done.')
              : _t(
                  'L\'application n\'a pas pu démarrer.',
                  'The app could not start.',
                ),
          textAlign: TextAlign.center,
          style: text.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          done
              ? _t(
                  'Ferme l\'application, puis rouvre-la. Tu devras te '
                      'reconnecter : ton compte et tes dossiers sont gardés '
                      'sur nos serveurs.',
                  'Close the app, then open it again. You will need to sign '
                      'in: your account and your cases are kept on our '
                      'servers.',
                )
              : _t(
                  'Ferme-la complètement, puis rouvre-la. Si ce message '
                      'revient, efface les données gardées sur ce téléphone.',
                  'Close it completely, then open it again. If this message '
                      'comes back, clear the data kept on this phone.',
                ),
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (_step == _BootResetStep.idle)
          OutlinedButton(
            onPressed: () => setState(() => _step = _BootResetStep.confirming),
            child: Text(_t(
              'Effacer les données de ce téléphone',
              'Clear the data on this phone',
            )),
          ),
        if (_step == _BootResetStep.confirming) ...[
          Text(
            _t(
              'Tu seras déconnecté. Les messages et les saisies pas encore '
                  'envoyés seront perdus. Ton compte n\'est pas supprimé.',
              'You will be signed out. Messages and entries not sent yet will '
                  'be lost. Your account is not deleted.',
            ),
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _reset,
            child: Text(_t('Oui, effacer', 'Yes, clear')),
          ),
          TextButton(
            onPressed: () => setState(() => _step = _BootResetStep.idle),
            child: Text(_t('Annuler', 'Cancel')),
          ),
        ],
        if (_step == _BootResetStep.working) const CircularProgressIndicator(),
        if (!done) ...[
          const SizedBox(height: 24),
          // Le détail technique, pour la personne de l'équipe à qui l'élève
          // enverra une capture. Aucune traduction ni journal distant n'est
          // garanti à ce stade : c'est la seule information qui existe.
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ],
    );
  }

  dynamic get error => widget.error;
}

/// Efface tout ce que l'app garde sur le téléphone : boîtes Hive, préférences,
/// magasin sécurisé (session). Chaque étape est isolée — l'une peut être la
/// cause de la panne, elle ne doit pas empêcher les autres.
Future<void> resetLocalAppData() async {
  try {
    await Hive.initFlutter();
    await Hive.deleteFromDisk();
  } catch (_) {}
  try {
    await (await SharedPreferences.getInstance()).clear();
  } catch (_) {}
  try {
    await kpbFlutterSecureStorage.deleteAll();
  } catch (_) {}
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
