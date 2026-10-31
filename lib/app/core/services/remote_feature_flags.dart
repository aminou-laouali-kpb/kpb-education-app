import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/eef_catalog_attribution.dart';
import '../models/us_visa_suspension.dart';
import '../repositories/app_api_client.dart';
import '../utils/external_link.dart';
import '../utils/app_logger.dart';

/// Une fenêtre de campagne telle que `/config/app` la sert.
///
/// Les deux bornes sont indépendamment nullables : une campagne peut avoir une
/// date d'ouverture annoncée sans date de clôture connue, et l'inverse arrive
/// aussi. Un modèle qui aurait exigé les deux pour être valide aurait forcé
/// l'exploitation à inventer la borne manquante.
@immutable
class EefCampaignWindow {
  const EefCampaignWindow({
    this.opensAt,
    this.closesAt,
    this.suspendedCountries = const <String>[],
    this.platformUrl,
    this.suspendedSources = const <String, String>{},
  });

  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Pays où la procédure est SUSPENDUE, tels que l'exploitation les a écrits.
  ///
  /// Ce ne sont ni des codes ISO garantis ni des noms garantis : le champ
  /// `countryOfResidence` d'un profil porte un nom français, saisi au clavier
  /// depuis l'écran de profil. La comparaison passe donc par
  /// [isSuspendedForCountry], qui normalise les deux côtés.
  final List<String> suspendedCountries;

  /// La plateforme officielle, servie. `null` quand le serveur est plus ancien
  /// ou que la valeur n'est pas une adresse web ouvrable : l'app n'affiche alors
  /// aucun lien plutôt qu'un lien qui ne marche pas.
  final String? platformUrl;

  /// La page officielle qui justifie la suspension, par pays — clé normalisée
  /// par [normalizeCountry]. Servie avec la liste des pays suspendus : une
  /// suspension annoncée sans sa source est une affirmation invérifiable.
  final Map<String, String> suspendedSources;

  static const empty = EefCampaignWindow();

  bool get hasAnyDate => opensAt != null || closesAt != null;

  /// La procédure est-elle suspendue pour [country] ?
  ///
  /// ## Pourquoi cette comparaison est tolérante, et pourquoi elle doit l'être
  ///
  /// `countryOfResidence` n'est pas un identifiant : l'onboarding le choisit
  /// dans une liste de noms français (« Niger », « Côte d'Ivoire »), mais
  /// l'écran de profil le laisse en TEXTE LIBRE. Une comparaison stricte aurait
  /// donc raté « NIGER », « niger » et « Côte d’Ivoire » écrit avec l'apostrophe
  /// typographique — c'est-à-dire précisément les cas réels.
  ///
  /// On normalise donc les deux côtés : minuscules, accents retirés,
  /// apostrophes unifiées, espaces réduits. L'exploitation peut alors écrire
  /// « Niger » ou « NE » indifféremment.
  ///
  /// **Le sens de l'échec est choisi.** Un pays vide, inconnu ou mal orthographié
  /// rend `false` — donc l'app affiche la date d'ouverture nationale, qui est
  /// exacte pour la plateforme. Le cas inverse (afficher une suspension à qui
  /// n'est pas concerné) découragerait une candidature parfaitement possible.
  bool isSuspendedForCountry(String? country) {
    final needle = normalizeCountry(country);
    if (needle.isEmpty || suspendedCountries.isEmpty) return false;
    return suspendedCountries.any(
      (entry) => normalizeCountry(entry) == needle,
    );
  }

  /// La source officielle de la suspension pour [country], ou `null`.
  ///
  /// Rend `null` quand le pays n'est pas suspendu : la source d'une suspension
  /// ne doit jamais voyager vers quelqu'un qui n'est pas concerné.
  String? suspensionSourceFor(String? country) {
    if (!isSuspendedForCountry(country)) return null;
    return suspendedSources[normalizeCountry(country)];
  }

  /// Minuscules, sans accents, apostrophes unifiées, espaces réduits.
  @visibleForTesting
  static String normalizeCountry(String? raw) {
    final trimmed = raw?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return '';

    const accents = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';

    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      // Les deux apostrophes que produisent les claviers réels.
      if (char == '’' || char == "'") {
        buffer.write("'");
        continue;
      }
      final index = accents.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Décode `{ "opensAt": "...", "closesAt": "..." }`.
  ///
  /// Toute valeur illisible devient `null` — jamais une date de repli. Le
  /// serveur envoie déjà `null` pour une variable mal configurée ; ceci est la
  /// bretelle à cette ceinture, pour le cas d'un backend plus ancien ou d'une
  /// charge inattendue.
  factory EefCampaignWindow.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    return EefCampaignWindow(
      opensAt: _parseCampaignDay(raw['opensAt']),
      closesAt: _parseCampaignDay(raw['closesAt']),
      suspendedCountries: _parseStringList(raw['suspendedCountries']),
      platformUrl: _parseWebUrl(raw['platformUrl']),
      suspendedSources: _parseSources(raw['suspendedSources']),
    );
  }

  /// Une adresse que l'app peut réellement ouvrir, ou `null`. Même règle que
  /// partout ailleurs : un bouton qui ne peut pas marcher n'est pas affiché.
  ///
  /// **https SEULEMENT.** Ces liens sont des sources officielles : le serveur
  /// n'en sert jamais d'autres, et un `http://` ne doit pas atteindre un bouton
  /// parce qu'un serveur plus ancien (ou mal configuré) l'aurait laissé passer.
  static String? _parseWebUrl(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (!isOpenableWebUrl(trimmed)) return null;
    return Uri.parse(trimmed).scheme.toLowerCase() == 'https' ? trimmed : null;
  }

  /// `[{country, url}]` → `{pays normalisé: url}`. Une entrée illisible est
  /// ignorée, jamais devinée, et ne fait pas perdre les autres.
  static Map<String, String> _parseSources(Object? value) {
    if (value is! List) return const <String, String>{};
    final out = <String, String>{};
    for (final entry in value) {
      if (entry is! Map) continue;
      final country = entry['country'];
      final url = _parseWebUrl(entry['url']);
      if (country is! String || url == null) continue;
      final key = normalizeCountry(country);
      if (key.isNotEmpty) out[key] = url;
    }
    return Map.unmodifiable(out);
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  /// Le JOUR CALENDAIRE que l'exploitation a écrit, jamais un instant reprojeté.
  ///
  /// ## Pourquoi ce n'est pas `DateTime.tryParse(...).toLocal()`
  ///
  /// Parce que « la campagne ouvre le 1er octobre » est une date d'HORLOGE
  /// MURALE, pas un instant. C'était pourtant un instant, et le reprojeter dans
  /// le fuseau de l'appareil produisait deux mensonges symétriques — le second
  /// bien pire que le premier :
  ///
  /// | Valeur servie | Fuseau du téléphone | Ce qui s'affichait |
  /// |---|---|---|
  /// | `2026-10-01T00:00:00Z` | UTC+0 / +1 (Dakar, Niamey) | 1er octobre ✓ |
  /// | `2026-10-01T00:00:00Z` | UTC−1 / −4 (Cabo Verde, diaspora) | **30 septembre** ✗ |
  /// | `2026-10-01T00:00:00+02:00` (heure de Paris) | UTC+0 / +1 | **30 septembre** ✗ |
  ///
  /// On extrait donc les composantes `AAAA-MM-JJ` **telles qu'écrites**, avant
  /// toute conversion, et on en fait un `DateTime` naïf. Plus de fuseau ici,
  /// donc plus de décalage introduit ici.
  ///
  /// ## Ce que ce décodage ne peut PAS réparer, et où c'est réparé
  ///
  /// La troisième ligne du tableau — l'heure de Paris, réflexe naturel pour une
  /// procédure française — ne se corrige pas de ce côté. Le serveur faisait
  /// `new Date(raw).toISOString()` : `2026-10-01T00:00:00+02:00` arrivait ici
  /// déjà transformé en `2026-09-30T22:00:00.000Z`, et lire les composantes de
  /// ce texte donne correctement le 30 septembre d'une valeur déjà fausse. Le
  /// jour était perdu sur le fil.
  ///
  /// `/config/app` sert donc désormais un JOUR NU `AAAA-MM-JJ`
  /// (`app-config.controller.ts`, `campaignDay`). Ce décodage-ci reste, comme
  /// seconde ligne : il neutralise le fuseau de l'appareil, et il tolère un
  /// ancien serveur qui servirait encore un instant.
  ///
  /// L'heure du jour est délibérément ignorée. Une échéance administrative se
  /// compte en jours — « à partir du 1er octobre » veut dire « dès le 1er
  /// octobre », pas « à partir de minuit UTC ce jour-là ». Voir
  /// [EefCalendar.phase], qui compare donc des jours et non des instants.
  static DateTime? _parseCampaignDay(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    // On valide par le parseur standard — une chaîne illisible doit rester
    // `null`, jamais une date devinée — puis on lit les composantes du TEXTE.
    if (DateTime.tryParse(trimmed) == null) return null;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    // `DateTime` normalise silencieusement un 32 janvier en 1er février. Ce
    // serait une date inventée à partir d'une saisie fautive — exactement ce que
    // ce module refuse de faire — donc on rend `null` et l'app n'annonce rien.
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}

/// Les drapeaux de fonctionnalité servis par `/config/app`.
///
/// ## Pourquoi ce service existe
///
/// Parce que sans lui, ouvrir l'espace « Études en France » le jour de la
/// campagne exigerait une nouvelle build au store. Une revue App Store prend un
/// à trois jours et peut refuser ; adosser une date de campagne à ce calendrier,
/// c'est parier la campagne sur Apple. Le backend sert déjà des drapeaux pilotés
/// par variables d'environnement — il ne manquait que le côté client pour les
/// lire.
///
/// ## Comment il échoue
///
/// **Fermé, toujours.** Réseau injoignable, charge malformée, backend plus
/// ancien qui ne connaît pas la clé : on retombe sur les constantes de
/// compilation d'[AppConfig], qui valent `false` par défaut. Le raisonnement
/// n'est pas symétrique dans les deux sens : montrer par défaut une vitrine
/// qu'on ne saurait plus éteindre à distance est un mauvais échec, ne rien
/// montrer est un échec réparable.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne bloque pas le démarrage. [refresh] est lancé sans attente au boot, et
/// tant qu'il n'a pas répondu, [eefTeaserEnabled] rend le repli local. Un écran
/// qui dépend d'un drapeau doit donc se reconstruire quand il arrive — d'où
/// [flagsVersion], un compteur qu'un `ValueListenableBuilder` peut écouter.
class RemoteFeatureFlags {
  RemoteFeatureFlags._();

  static final instance = RemoteFeatureFlags._();

  /// Remis à zéro entre les tests.
  @visibleForTesting
  static void resetForTest() {
    instance._features = const <String, bool>{};
    instance._campaign = EefCampaignWindow.empty;
    instance._recommendedVersion = null;
    instance._iosStoreUrl = null;
    instance._androidStoreUrl = null;
    instance._catalogAttribution = null;
    instance._usVisaSuspension = UsVisaSuspension.fallback;
    instance._loaded = false;
    instance._featuresServed = false;
    instance.flagsVersion.value = 0;
    retryDelays = const <Duration>[Duration(seconds: 5), Duration(seconds: 30)];
  }

  Map<String, bool> _features = const <String, bool>{};
  EefCampaignWindow _campaign = EefCampaignWindow.empty;
  String? _recommendedVersion;
  String? _iosStoreUrl;
  String? _androidStoreUrl;
  EefCatalogAttribution? _catalogAttribution;
  UsVisaSuspension _usVisaSuspension = UsVisaSuspension.fallback;
  bool _loaded = false;
  bool _featuresServed = false;

  /// Incrémenté à chaque rafraîchissement réussi. Les écrans qui dépendent d'un
  /// drapeau écoutent ce compteur pour se reconstruire une fois la réponse
  /// arrivée, au lieu de rester sur le repli jusqu'au prochain démarrage.
  final flagsVersion = ValueNotifier<int>(0);

  /// True quand une réponse serveur a été lue avec succès au moins une fois.
  bool get loaded => _loaded;

  /// Les drapeaux `features` viennent-ils du serveur (ou d'un test) ? Faux
  /// tant que `/config/app` n'a pas répondu : un drapeau fermé veut alors dire
  /// « pas encore su », pas « fermé ». Un écran ouvert par une notification au
  /// démarrage à froid attend cette réponse avant de conclure (audit 57, F10).
  bool get featuresServed => _featuresServed;

  /// La fenêtre de campagne servie, ou [EefCampaignWindow.empty].
  EefCampaignWindow get eefCampaign => _campaign;

  /// La version à partir de laquelle l'app cesse d'inviter à mettre à jour, ou
  /// `null` (aucun bandeau). À ne pas confondre avec `minVersion`, que lit
  /// `AppVersionGate` : en dessous de celle-ci l'app est bloquée, en dessous de
  /// [recommendedVersion] elle l'invite — et se laisse fermer.
  String? get recommendedVersion => _recommendedVersion;

  /// Le lien de la fiche du store pour CETTE plateforme, ou `null`.
  String? get storeUrl => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosStoreUrl
      : _androidStoreUrl;

  /// La mention de paternité du catalogue, ou `null` si le serveur ne la sert
  /// pas (plus ancien, ou charge incomplète).
  EefCatalogAttribution? get catalogAttribution => _catalogAttribution;

  /// La suspension des visas étudiants américains (avis des fiches
  /// États-Unis). [UsVisaSuspension.fallback] — la liste vérifiée embarquée —
  /// tant que le serveur n'a pas répondu, ou s'il ne sert pas la clé.
  UsVisaSuspension get usVisaSuspension => _usVisaSuspension;

  /// Pose la suspension sans passer par `refresh`, pour un test d'écran.
  @visibleForTesting
  void debugSetUsVisaSuspensionForTest(UsVisaSuspension value) {
    _usVisaSuspension = value;
    flagsVersion.value++;
  }

  /// Pose la mention de paternité sans passer par `refresh` — pour qu'un test
  /// d'écran n'ait pas besoin de simuler tout `/config/app`.
  @visibleForTesting
  void debugSetCatalogAttributionForTest(EefCatalogAttribution? value) {
    _catalogAttribution = value;
    flagsVersion.value++;
  }

  /// La vitrine « Études en France » est-elle visible ?
  bool get eefTeaserEnabled => _flag('eefTeaser', AppConfig.eefTeaserEnabled);

  /// L'ANCIEN commutateur de l'espace réel. Les builds 49 à 53 le lisent, et
  /// pour elles `true` veut dire « montre l'espace » ET « retire la vitrine ».
  /// Cette build l'honore encore (un serveur qui le pose ouvre l'espace partout)
  /// mais ne s'y fie plus : voir [eefSpaceEnabled].
  bool get eefEnabled => _flag('eef', AppConfig.eefEnabled);

  /// L'espace « Études en France » réel est-il ouvert POUR CETTE BUILD ?
  ///
  /// C'est la clé que le serveur pose pour ouvrir l'espace à la build 54 sans
  /// toucher à la vitrine des builds plus anciennes (qui ignorent cette clé et
  /// continuent de lire `eef`). L'ancien commutateur l'allume aussi : un serveur
  /// plus ancien, qui ne connaît pas `eefSpace` mais pose `eef`, ouvre l'espace
  /// ici comme ailleurs.
  bool get eefSpaceEnabled =>
      _flag('eefSpace', AppConfig.eefSpaceEnabled) || eefEnabled;

  /// La bulle « Une question ? » (contact WhatsApp trié par sujet) est-elle
  /// autorisée par le serveur ?
  ///
  /// Clé NOUVELLE (build 56) : absente d'un backend plus ancien, donc FAUSSE
  /// dans ce cas, comme quand le serveur est injoignable. Elle ne dérive
  /// d'aucun autre drapeau, pas même de l'ancien commutateur `eef` — et à
  /// l'inverse elle n'ouvre rien seule : les écrans exigent aussi
  /// [eefSpaceEnabled].
  bool get eefHelpBubbleEnabled =>
      _flag('eefHelpBubble', AppConfig.eefHelpBubbleEnabled);

  /// La mention des écoles privées est-elle autorisée par le serveur ?
  ///
  /// Mêmes règles que [eefHelpBubbleEnabled] : clé nouvelle, absente = fausse,
  /// indépendante de tout autre drapeau. Ouverte seulement après validation
  /// juridique, par une action d'exploitation dédiée.
  bool get eefPrivateSchoolsEnabled =>
      _flag('eefPrivateSchools', AppConfig.eefPrivateSchoolsEnabled);

  /// Le test « Mes 10 bourses » (carte de l'onglet Bourses, assistant,
  /// résultats) est-il ouvert ?
  ///
  /// Clé `scholarshipMatch`, FERMÉE par défaut : absente (backend plus ancien),
  /// illisible ou serveur injoignable, elle vaut `false`. Indépendante de tout
  /// autre drapeau. Le serveur coupe aussi ses routes avec la même variable
  /// (404 `{disabled: true}`), que l'app lit comme ce drapeau fermé.
  bool get scholarshipMatchEnabled =>
      _flag('scholarshipMatch', AppConfig.scholarshipMatchEnabled);

  /// L'onboarding « la valeur d'abord » (chantier I3) est-il ouvert ?
  ///
  /// Clé `onboardingV2`, FERMÉE par défaut : absente (backend plus ancien),
  /// illisible ou serveur injoignable, elle vaut `false` et l'ancien parcours
  /// reste servi, inchangé. Ouverte : aucun champ pré-rempli sans choix de
  /// l'élève, « Passer » dès la page 1, erreurs dans le champ. L'écran la lit
  /// UNE fois, à son ouverture : un rafraîchissement en cours de saisie ne
  /// change pas le formulaire sous les doigts de l'élève.
  bool get onboardingV2Enabled => _flag('onboardingV2', false);

  /// La nouvelle communauté d'entraide (C1 + C2) est-elle ouverte ?
  ///
  /// Clé `community`, FERMÉE par défaut : absente (backend plus ancien),
  /// illisible ou serveur injoignable, elle vaut `false` et l'entrée actuelle
  /// reste servie, inchangée. Aucun repli de compilation : pas même
  /// `KPB_MVP_ONLY`, qui ne garde que l'ANCIEN écran (articles, groupe
  /// WhatsApp). Le serveur coupe aussi ses routes `/community/*` avec la même
  /// variable (404 `community_disabled`), que l'app lit comme ce drapeau
  /// fermé.
  bool get communityEnabled => _flag('community', false);

  /// Le bot « Passerelle » envoie-t-il ses suggestions privées ?
  ///
  /// Clé `assistBridge`, FERMÉE par défaut : vraie seulement quand le serveur
  /// est en mode `on` (en `shadow`, rien n'est envoyé). Elle ne sert qu'à
  /// afficher l'interrupteur « Suggestions de l'équipe KPB » des préférences :
  /// un backend plus ancien ne connaît pas la clé `assist_bridge` et la
  /// retirerait à l'écriture. Une notification `assist_bridge` reçue s'ouvre
  /// quel que soit ce drapeau.
  bool get assistBridgeEnabled => _flag('assistBridge', false);

  // ── Parrainage côté app (build 57, compétition ambassadeurs) ─────────────
  //
  // Trois clés FERMÉES par défaut et INDÉPENDANTES : absentes (backend plus
  // ancien), illisibles ou serveur injoignable, elles valent `false`. Aucun
  // repli de compilation, et aucune ne dérive d'une autre : ouvrir l'écran de
  // la compétition ne lit pas le referrer, et inversement.

  /// Lecture du Play Install Referrer (Android, une fois par installation)
  /// pour PRÉREMPLIR le code du parrain. Fermée : aucune lecture.
  bool get referralInstallReferrerEnabled =>
      _flag('referralInstallReferrer', false);

  /// L'étape facultative « code de ton parrain » en fin d'onboarding élève.
  bool get referralOnboardingCodeEnabled =>
      _flag('referralOnboardingCode', false);

  /// Les statistiques d'impact publiques (`GET /impact/stats`). Fermées côté
  /// serveur par défaut : tant qu'elles le sont, aucune porte ne mène à
  /// « Tableau d'impact » (audit build 57, T5-15 et T6-09 : impasse permanente).
  bool get publicImpactStatsEnabled => _flag('publicImpactStats', false);

  /// L'écran « Compétition ambassadeurs » (rang, compteurs, compte à rebours).
  bool get referralLeaderboardEnabled => _flag('referralLeaderboard', false);

  // ── « Suivre » une bourse et notifications (chantier G) ───────────────────
  //
  // Des INTERRUPTEURS D'URGENCE : chaque clé vaut `true` tant que le serveur ne
  // la sert pas, parce que chacune de ces fonctions se dégrade déjà toute seule
  // face à un backend sans les routes du chantier C (404 → section masquée,
  // interrupteur caché, badge serveur ignoré). La build est gelée deux à trois
  // mois : servir `false` sous `features` dans `/config/app` coupe la fonction
  // sur les téléphones déjà installés, sans soumission.

  /// Feuille d'explication avant la demande système, au premier « Suivre ».
  /// Coupé : le premier « Suivre » demande directement (jamais l'onboarding).
  bool get followPushPrimerEnabled => _flag('followPushPrimer', true);

  /// « Suivre » pose aussi l'alerte d'ouverture (`POST /me/scholarship-alerts`)
  /// — indispensable tant que le serveur tourne en mode `legacy`, où seul un
  /// abonné à l'alerte reçoit le push d'ouverture.
  bool get followSetsOpeningAlert => _flag('followOpeningAlert', true);

  /// Interrupteur « Me prévenir à l'ouverture » sur la fiche (PATCH).
  bool get openingAlertToggleEnabled => _flag('openingAlertToggle', true);

  /// Section « Bourses suivies » de Mes suivis (GET /me/followed-scholarships).
  bool get followedScholarshipsEnabled => _flag('followedScholarships', true);

  /// Point de la cloche de l'accueil allumé aussi par les non-lus serveur.
  bool get serverUnreadBadgeEnabled => _flag('notificationsUnreadCount', true);

  /// Ligne « Bourses que je suis : ouverture » des préférences.
  bool get followedOptOutEnabled => _flag('followedScholarshipOptOut', true);

  /// Bouton « Mes suivis » de l'en-tête de l'accueil (à la place du raccourci
  /// Profil, déjà présent dans la barre d'onglets).
  bool get homeFollowedEntryEnabled => _flag('homeFollowedEntry', true);

  /// Blocs de l'accueil « Ta prochaine étape » (chantier K) : un
  /// interrupteur d'urgence par bloc — `homeNextStep`, `homeScholarships`,
  /// `homeDeadlines`, `homePartners`, `homeIntelligence`, `homeParcours`,
  /// `homeCounselor`. Ouverts tant que le serveur ne les sert pas : chaque
  /// bloc se replie déjà tout seul quand son appel réseau échoue ; servir
  /// `false` sous `features` en retire un des téléphones installés.
  bool homeBlockEnabled(String key) => _flag(key, true);

  /// Pose des drapeaux servis, pour qu'un test d'écran n'ait pas besoin de
  /// simuler tout `/config/app`.
  @visibleForTesting
  void debugSetFeaturesForTest(Map<String, bool> features) {
    _features = Map<String, bool>.unmodifiable(features);
    _featuresServed = true;
    flagsVersion.value++;
  }

  /// La valeur servie, ou le repli de compilation quand elle est absente.
  bool _flag(String key, bool fallback) => _features[key] ?? fallback;

  /// Attentes avant les nouveaux essais d'un [refresh] qui a échoué. Une API qui
  /// ne répond pas n'entraîne pas forcément une bascule « hors ligne » : sans
  /// nouvel essai, un échec au lancement masquait Études en France et la
  /// Communauté pour toute la session (audit build 57, T2-06 et T7-07).
  @visibleForTesting
  static List<Duration> retryDelays = const <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
  ];

  /// Lit `/config/app` et mémorise les drapeaux. Ne lève jamais.
  ///
  /// Avec [retryOnFailure], un échec programme deux nouveaux essais (5 s puis
  /// 30 s) sans retarder l'appelant.
  Future<void> refresh(AppApiClient apiClient,
      {bool retryOnFailure = false}) async {
    final ok = await _attemptRefresh(apiClient);
    if (!ok && retryOnFailure) unawaited(_retryRefresh(apiClient));
  }

  Future<void> _retryRefresh(AppApiClient apiClient) async {
    for (final delay in retryDelays) {
      await Future<void>.delayed(delay);
      if (_loaded) return;
      if (await _attemptRefresh(apiClient)) return;
    }
  }

  Future<bool> _attemptRefresh(AppApiClient apiClient) async {
    try {
      final config = await apiClient.getAppConfig();
      _features = _readFeatures(config['features']);
      _campaign = EefCampaignWindow.fromJson(config['eefCampaign']);
      _recommendedVersion = _readVersion(config['recommendedVersion']);
      _iosStoreUrl = _readWebUrl(config['iosStoreUrl']);
      _androidStoreUrl = _readWebUrl(config['androidStoreUrl']);
      _catalogAttribution =
          EefCatalogAttribution.fromJson(config['eefCatalog']);
      _usVisaSuspension = UsVisaSuspension.fromJson(config['usVisaSuspension']);
      _loaded = true;
      _featuresServed = true;
      flagsVersion.value++;
      return true;
    } catch (error) {
      // Fail closed : on garde les replis de compilation. Volontairement pas
      // remonté à Crashlytics — un téléphone hors réseau n'est pas un incident,
      // et cette route est appelée à chaque démarrage.
      AppLogger.warning(
        'Remote feature flags unavailable: $error',
        tag: 'RemoteFeatureFlags',
      );
      return false;
    }
  }

  /// Une version nue `x.y.z`, ou `null`. Le serveur filtre déjà ; ceci est la
  /// bretelle : une valeur illisible vaut « pas de bandeau », jamais « bandeau
  /// pour tous ».
  static String? _readVersion(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(trimmed) ? trimmed : null;
  }

  static String? _readWebUrl(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return isOpenableWebUrl(trimmed) ? trimmed : null;
  }

  /// Ne retient que les entrées booléennes.
  ///
  /// `features` est une charge que l'app ne contrôle pas : une clé dont la
  /// valeur n'est pas un booléen (un objet `{enabled: true}` d'une version
  /// future, une chaîne « true » d'un mauvais sérialiseur) est IGNORÉE plutôt
  /// que devinée. Une lecture laxiste ici allumerait une fonctionnalité sur la
  /// foi d'une chaîne non vide — c'est-à-dire sur rien.
  static Map<String, bool> _readFeatures(Object? raw) {
    if (raw is! Map) return const <String, bool>{};
    final parsed = <String, bool>{};
    raw.forEach((key, value) {
      if (key is String && value is bool) parsed[key] = value;
    });
    return parsed;
  }
}
