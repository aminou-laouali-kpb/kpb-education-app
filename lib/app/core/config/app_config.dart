import 'package:flutter/foundation.dart';

/// Compile-time app environment and API settings (Flutter `--dart-define=...`).
///
/// See [`docs/phase8-release-operations.md`](../../../../docs/phase8-release-operations.md).
class AppConfig {
  /// One of `dev`, `staging`, `prod`. Drives default API host when [apiBaseUrlOverride] is empty.
  static const appEnv = String.fromEnvironment(
    'KPB_APP_ENV',
    defaultValue: 'prod',
  );

  /// When non-empty, used as the REST base URL and overrides [appEnv] defaults.
  static const apiBaseUrlOverride = String.fromEnvironment(
    'KPB_API_BASE_URL',
    defaultValue: '',
  );

  /// Resolved REST API prefix (includes trailing `/api` segment used by this client).
  static String get apiBaseUrl =>
      resolveApiBaseUrl(override: apiBaseUrlOverride, env: appEnv);

  static bool get enableRemoteSync =>
      _enableRemoteSyncOverride ??
      const bool.fromEnvironment(
        'KPB_ENABLE_REMOTE_SYNC',
        defaultValue: true,
      );

  static bool? _enableRemoteSyncOverride;

  @visibleForTesting
  static set enableRemoteSyncOverride(bool? value) =>
      _enableRemoteSyncOverride = value;

  static const requestTimeoutInSeconds = int.fromEnvironment(
    'KPB_REQUEST_TIMEOUT',
    defaultValue: 15,
  );

  /// Receive timeout for AI generation calls (`/tools/*`, `/document-review`,
  /// `/orientation/submit`, Success Lab diagnostic). [requestTimeoutInSeconds]
  /// fits ordinary calls; generations do not. Measured on prod (26/09/2026):
  /// a FR+EN letter takes 5–19 s per provider attempt, and the backend may
  /// make two attempts (40 s each for letters) before answering. At 15 s the
  /// app gave up on requests the server was still completing successfully and
  /// told the student to check their connection.
  static const aiRequestTimeoutInSeconds = int.fromEnvironment(
    'KPB_AI_REQUEST_TIMEOUT',
    defaultValue: 90,
  );

  /// Main KPB WhatsApp line (E.164 digits, with or without leading +).
  /// Defaults to the KPB advisor line so the "Discuter avec un conseiller" CTAs
  /// reach a real person even when no --dart-define is passed; override per
  /// environment with --dart-define=KPB_WHATSAPP_NUMBER=...
  static const whatsappNumber = String.fromEnvironment(
    'KPB_WHATSAPP_NUMBER',
    defaultValue: '+33768674292',
  );

  /// Optional WhatsApp group invite fallback.
  static const whatsappGroupInvite = String.fromEnvironment(
    'KPB_WHATSAPP_GROUP',
    defaultValue: 'https://chat.whatsapp.com/KPBEducation',
  );

  // ── PostHog product analytics ──────────────────────────────────────────
  /// PostHog project API key (`phc_…`). Client-side keys are designed to ship
  /// in the app, but we keep it out of the repo and inject it per build with
  /// `--dart-define=POSTHOG_API_KEY=phc_…`. Empty (the default) disables
  /// PostHog entirely: the app runs normally on Firebase Analytics alone, so
  /// this is safe to ship before the KPB Education project key is provisioned.
  static const posthogApiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: '',
  );

  /// PostHog ingestion host. The KPB organization is on PostHog US cloud;
  /// override with --dart-define=POSTHOG_HOST=... for EU/self-hosted.
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// True when a PostHog key is configured (drives all PostHog wiring; when
  /// false, setup, the navigator observer, the replay wrapper and every mirror
  /// call are skipped).
  static bool get posthogEnabled => posthogApiKey.trim().isNotEmpty;

  /// MVP launch lock. When true, modules outside the M1–M14 MVP scope
  /// (community/forum, alumni, academy, salon, housing, travel, blog and the
  /// scraped live-scholarships aggregator) are hidden from navigation without
  /// removing their code, so they can be re-enabled for V1.1+.
  static const mvpOnly = bool.fromEnvironment(
    'KPB_MVP_ONLY',
    defaultValue: true,
  );

  /// KPB-160: the cash Ambassador programme (FCFA balances, city leaderboard,
  /// Wave withdrawals, self-activation) is OFF by default. It carries Play
  /// "incentivized behavior" exposure plus AML/KYC/tax duties on cross-border
  /// payouts (incl. minors) that need legal clearance first. While false, only
  /// users the backend already marks `activated` (an ops whitelist) reach the
  /// cash surface; everyone else sees an application screen. Flip to true at
  /// build time to open the programme to all once it is legally cleared.
  static const ambassadorCashEnabled = bool.fromEnvironment(
    'KPB_AMBASSADOR_CASH_ENABLED',
    defaultValue: false,
  );

  /// The flight price estimator ("Simulateur de Vols") is backed by the
  /// server-proxied Kayak Price-Insights API (KPB-94), which returns nothing
  /// until `KPB_KAYAK_API_KEY` is provisioned on the backend. That key has
  /// never been set in prod, so every estimate fails; while false, all entry
  /// points to the estimator are hidden from navigation without removing the
  /// code. Flip to true at build time once the Kayak key is live server-side.
  static const flightEstimatorEnabled = bool.fromEnvironment(
    'KPB_FLIGHT_ESTIMATOR_ENABLED',
    defaultValue: false,
  );

  // ── Les deux masquages du lot 7 ────────────────────────────────────────
  //
  // Masquer une fonctionnalité qu'on ne sait pas encore livrer honnêtement est
  // un choix éditorial, pas un aveu d'échec. La livrer en affirmant « fourni ✓ »
  // sur un document que personne n'a reçu, ou « jamais ton nom » pendant qu'on
  // envoie le nom, ce serait l'inverse.
  //
  // Les deux drapeaux qui suivent portent un `_override` de test, contrairement
  // à `ambassadorCashEnabled` et `flightEstimatorEnabled` au-dessus. Ce n'est
  // pas de la coquetterie : un `bool.fromEnvironment` est une constante de
  // compilation qu'aucun test ne peut basculer, donc un masquage bâti dessus
  // n'a pas de contre-épreuve — rien ne prouverait que le drapeau à VRAI
  // ramène bien les entrées, ni que le masquage tient à autre chose qu'à un
  // écran cassé. Le patron est celui d'[enableRemoteSync].

  /// **M1** — les quatre outils IA de la « boîte à outils » (générateur de CV,
  /// lettres de motivation, simulateur d'entretien, relecture de document) sont
  /// MASQUÉS par défaut.
  ///
  /// Motif historique (lot 7) : l'écran de consentement promettait « jamais
  /// ton nom » pendant que `/tools/cv-summary` et `/tools/personalize-letter`
  /// recopiaient `Nom : ${dto.name}` vers Groq, sans garde de consentement.
  /// Lot 11 a retiré le nom des invites et posé `AiConsentGuard` sur ces
  /// routes. Le masque restait **off** jusqu'à ce que la garde soit déployée
  /// **avec** la build 49 — la basculer avant aurait fait 403 les testeurs 48.
  ///
  /// ## OUVERT depuis la build 51 (30/08/2026)
  ///
  /// La condition posée ici était : « à basculer le jour où IA-T1 est en prod
  /// ET la 49 est chez les testeurs ; pas avant, et pas l'un sans l'autre ».
  /// Les deux moitiés sont vérifiées, pas supposées :
  ///
  ///   • `AiConsentGuard` protège `/tools/cv-summary`, `/tools/personalize-letter`,
  ///     `/tools/interview/*` et `/document-review`
  ///     (`tools.controller.ts:12-13`, `document-review.controller.ts:11-12`),
  ///     et ce code est dans le commit `6129309` déployé en production.
  ///   • Les builds 49 et 50 sont chez les testeurs.
  ///
  /// Le défaut passe à `true` plutôt que de vivre dans un `--dart-define` de
  /// release : sinon `flutter test` continuerait de mesurer la configuration
  /// MASQUÉE pendant qu'on livre la configuration ouverte — l'artefact ne
  /// serait exercé de bout en bout nulle part. Le `--dart-define` reste
  /// disponible pour refermer le masque sans toucher au code.
  ///
  /// Un porteur de la build 50 ne voit RIEN changer : c'est une constante de
  /// compilation, elle n'existe que dans un binaire neuf.
  static bool get aiToolsEnabled =>
      _aiToolsEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_AI_TOOLS_ENABLED',
        defaultValue: true,
      );

  static bool? _aiToolsEnabledOverride;

  @visibleForTesting
  static set aiToolsEnabledOverride(bool? value) =>
      _aiToolsEnabledOverride = value;

  /// **M2** — l'envoi de pièces jointes depuis l'app est MASQUÉ par défaut ; les
  /// documents passent par le conseiller WhatsApp.
  ///
  /// Motif, mesuré : aucun octet n'arrive aujourd'hui. Le tunnel de création de
  /// dossier ne garde qu'un CHEMIN LOCAL de fichier et écrit son nom dans la
  /// description du dossier (« Documents joints: • CV: IMG_1234.jpg ») sans rien
  /// téléverser — `submitCase` n'a aucun paramètre de pièce jointe. Et le seul
  /// chemin d'envoi réel, celui de l'écran de dossier, coche `isProvided: true`
  /// AVANT l'appel réseau, puis avale l'échec dans Crashlytics et fait
  /// disparaître le bouton « Envoyer ». Côté serveur, le conteneur d'analyse
  /// antivirale est en panne et la route échoue fermé : l'étudiant voit
  /// « fourni ✓ » sur un document que le conseiller n'a jamais reçu.
  ///
  /// Ce qui RESTE ouvert pendant le masquage : le scanner de documents (capture
  /// locale et assemblage en PDF, aucun appel réseau) — il produit précisément
  /// le fichier que l'étudiant envoie ensuite sur WhatsApp.
  ///
  /// À basculer à `true` quand la chaîne d'envoi est réparée de bout en bout :
  /// analyse antivirale vivante, échec visible à l'écran, et « fourni » coché
  /// par la réponse du serveur et non par optimisme local.
  static bool get documentUploadEnabled =>
      _documentUploadEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_DOCUMENT_UPLOAD_ENABLED',
        defaultValue: false,
      );

  static bool? _documentUploadEnabledOverride;

  @visibleForTesting
  static set documentUploadEnabledOverride(bool? value) =>
      _documentUploadEnabledOverride = value;

  // ── Espace « Études en France » ────────────────────────────────────────
  //
  // Deux surfaces, un seul module : la VITRINE (« voilà ce que ça fera, dis-nous
  // si ça t'intéresse ») et l'ESPACE réel. Les deux sont masquées par défaut.
  //
  // Ces constantes ne sont que le REPLI. La vérité vient du serveur
  // (`/config/app` → `features.eefTeaser` / `features.eef`), lue par
  // [RemoteFeatureFlags] : c'est ce qui permet d'ouvrir l'espace le jour de la
  // campagne en basculant une variable d'environnement, sans soumission App
  // Store. Une revue prend un à trois jours et peut refuser ; faire dépendre
  // une date de campagne d'Apple, c'est parier la campagne sur Apple.
  //
  // Le repli est donc `false` et non `true` : quand `/config/app` est
  // injoignable, on ne montre rien plutôt que de montrer une vitrine qu'on ne
  // saurait plus éteindre à distance.
  //
  // Le patron avec `_override` de test est celui d'[aiToolsEnabled], pour la
  // raison écrite plus haut : un `bool.fromEnvironment` nu est une constante de
  // compilation qu'aucun test ne peut basculer, donc un masquage bâti dessus n'a
  // pas de contre-épreuve — rien ne prouverait que le drapeau à VRAI ramène bien
  // les entrées de navigation.

  /// Repli local pour la vitrine « Études en France ».
  static bool get eefTeaserEnabled =>
      _eefTeaserEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_EEF_TEASER_ENABLED',
        defaultValue: false,
      );

  static bool? _eefTeaserEnabledOverride;

  @visibleForTesting
  static set eefTeaserEnabledOverride(bool? value) =>
      _eefTeaserEnabledOverride = value;

  /// Repli local pour l'espace « Études en France » réel.
  static bool get eefEnabled =>
      _eefEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_EEF_ENABLED',
        defaultValue: false,
      );

  static bool? _eefEnabledOverride;

  @visibleForTesting
  static set eefEnabledOverride(bool? value) => _eefEnabledOverride = value;

  /// Repli local pour l'ouverture de l'espace réel DANS CETTE BUILD.
  ///
  /// `eef` (ci-dessus) est l'ancien commutateur, que lisent aussi les builds 49
  /// à 53 : pour elles il retire la vitrine et montre une coquille vide. La
  /// clé `eefSpace` est lue par la seule build 54 et les suivantes, donc le
  /// serveur peut ouvrir l'espace réel sans rien changer à ce que voit une
  /// build plus ancienne. Fermée par défaut, pour la même raison que les deux
  /// autres : quand `/config/app` est injoignable, on ne montre rien plutôt
  /// qu'un espace qu'on ne saurait plus refermer à distance.
  static bool get eefSpaceEnabled =>
      _eefSpaceEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_EEF_SPACE_ENABLED',
        defaultValue: false,
      );

  static bool? _eefSpaceEnabledOverride;

  @visibleForTesting
  static set eefSpaceEnabledOverride(bool? value) =>
      _eefSpaceEnabledOverride = value;

  /// Repli local pour la bulle « Une question ? » du hub et du catalogue
  /// (build 56 et suivantes).
  ///
  /// FERMÉ par défaut, et le sens de l'échec est voulu : quand `/config/app`
  /// est injoignable, on ne montre pas un canal de contact qu'on ne saurait
  /// plus refermer à distance. Indépendant de [eefSpaceEnabled] : le serveur
  /// l'ouvre par sa propre action, et l'app exige l'espace ouvert EN PLUS.
  static bool get eefHelpBubbleEnabled =>
      _eefHelpBubbleEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_EEF_HELP_BUBBLE_ENABLED',
        defaultValue: false,
      );

  static bool? _eefHelpBubbleEnabledOverride;

  @visibleForTesting
  static set eefHelpBubbleEnabledOverride(bool? value) =>
      _eefHelpBubbleEnabledOverride = value;

  /// Repli local pour la mention des écoles privées (build 56 et suivantes).
  ///
  /// FERMÉ par défaut, pour la même raison que la bulle, et davantage : la
  /// mention n'est ouverte qu'après validation juridique. Un binaire livré ne
  /// doit jamais la porter allumée de naissance.
  static bool get eefPrivateSchoolsEnabled =>
      _eefPrivateSchoolsEnabledOverride ??
      const bool.fromEnvironment(
        'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
        defaultValue: false,
      );

  static bool? _eefPrivateSchoolsEnabledOverride;

  @visibleForTesting
  static set eefPrivateSchoolsEnabledOverride(bool? value) =>
      _eefPrivateSchoolsEnabledOverride = value;

  /// Repli local du test « Mes 10 bourses » (`features.scholarshipMatch`).
  ///
  /// FERMÉ par défaut : la collecte de la nationalité attend une validation
  /// juridique, et un binaire livré ne doit jamais porter le test allumé de
  /// naissance. Seul le serveur l'ouvre — volontairement AUCUNE variable de
  /// compilation : une build ne peut pas être livrée avec le test ouvert.
  static bool get scholarshipMatchEnabled =>
      _scholarshipMatchEnabledOverride ?? false;

  static bool? _scholarshipMatchEnabledOverride;

  @visibleForTesting
  static set scholarshipMatchEnabledOverride(bool? value) =>
      _scholarshipMatchEnabledOverride = value;

  // ── Supabase Auth ──────────────────────────────────────────────────────
  /// Supabase project URL (auth only — business data stays in Prisma/Postgres).
  static const supabaseUrl = String.fromEnvironment(
    'KPB_SUPABASE_URL',
    defaultValue: 'https://hijzqsljasbobjrjotjy.supabase.co',
  );

  /// Supabase anon (publishable) key.
  static const supabaseAnonKey = String.fromEnvironment(
    'KPB_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhpanpxc2xqYXNib2JqcmpvdGp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4MTkwODQsImV4cCI6MjA5MDM5NTA4NH0.Yib53B7tICNpnJWktCrc_JhtD06mAby4hbNWKXt3je0',
  );

  /// Deep-link redirect registered with the Supabase OAuth provider (Google).
  static const supabaseOAuthRedirect = String.fromEnvironment(
    'KPB_SUPABASE_OAUTH_REDIRECT',
    defaultValue: 'io.supabase.kpbeducation://login-callback/',
  );

  static const storageNamespace = 'kpb_relaunch_v1';

  // ── Brand identity ─────────────────────────────────────────────────────
  /// Public brand name, used in shareable artifacts (e.g. the match card).
  /// Kept as a single source of truth so shared copy stays truthful.
  static const brandName = 'KPB Education';

  /// Public brand domain (marketing site). Matches the `kpbeducation.cloud`
  /// API host; surfaced on shareable cards instead of any placeholder domain.
  static const brandDomain = 'kpbeducation.cloud';

  /// Smart download link appended to referral/ambassador share messages.
  /// The page (`web/public/app/index.html`) detects the visitor's phone and
  /// redirects to the App Store (iOS) or Play Store (Android), with both store
  /// links as a no-JS fallback — so a WhatsApp recipient always has something
  /// to tap instead of hunting for the app themselves.
  static const appDownloadUrl = 'https://$brandDomain/app';

  /// Pure resolver for tests and tooling.
  @visibleForTesting
  static String resolveApiBaseUrl({
    required String override,
    required String env,
  }) {
    final o = override.trim();
    if (o.isNotEmpty) return o;

    switch (env.toLowerCase()) {
      case 'dev':
        return 'http://127.0.0.1:4000/api';
      case 'staging':
        // Pre-production / CI-style host — override with KPB_API_BASE_URL if your stack differs.
        return 'https://api.vps-planethoster.com/api';
      case 'prod':
      default:
        return 'https://api.kpbeducation.cloud/api';
    }
  }
}
