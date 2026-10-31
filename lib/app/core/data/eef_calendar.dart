import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../services/remote_feature_flags.dart';

/// Où en est la campagne « Études en France », maintenant.
enum EefCampaignPhase {
  /// Aucune date servie : on n'annonce rien. Ce n'est pas une erreur — c'est
  /// l'état normal avant que l'exploitation ait posé les variables.
  unknown,

  /// L'ouverture est annoncée, elle n'a pas eu lieu.
  beforeOpening,

  /// La campagne accepte les candidatures.
  open,

  /// La clôture est passée.
  closed,
}

/// La fenêtre de campagne, telle que l'app la DIT.
///
/// ## Le défaut que ce fichier interdit
///
/// `IntakeCalendar`, juste à côté, existe parce que « rentrée septembre 2026 »
/// était écrit en dur dans quatre clés de traduction : une build vit environ
/// quatre-vingt-dix jours, donc au 1er octobre 2026 chacune de ces chaînes
/// devenait un mensonge que nulle mise à jour de contenu ne pouvait corriger,
/// puisque le texte vivait dans le binaire.
///
/// Une campagne Campus France a le même piège en pire : ses dates changent
/// d'une année sur l'autre ET peuvent être décalées en cours de campagne. Elles
/// ne sont donc NI compilées, NI calculées par une règle maison — elles sont
/// **servies** par `/config/app`, et ce fichier ne fait que les lire, les
/// situer dans le temps et les formater.
///
/// ## Ce qu'il refuse de faire
///
/// Deviner. Sans date servie, [phase] rend [EefCampaignPhase.unknown] et
/// [rangeLabel] rend `null` : l'écran n'affiche alors aucune date, plutôt
/// qu'une date plausible. Un « ouverture le 26 août » inventé par un repli
/// serait indistinguable d'une information, et c'est précisément ce qu'un
/// étudiant utiliserait pour organiser son dossier.
abstract final class EefCalendar {
  /// L'horloge, INJECTABLE — c'est ce qui rend l'expiration vérifiable. Un
  /// `DateTime.now()` en dur aurait rendu [phase] intestable : aucun test ne
  /// peut attendre la date de clôture. Le dépôt a déjà fait cette erreur une
  /// fois, et `IntakeCalendar` porte la même couture pour la même raison.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// La source des dates, INJECTABLE elle aussi, pour que les tests n'aient pas
  /// besoin d'un serveur.
  @visibleForTesting
  static EefCampaignWindow Function() windowSource =
      () => RemoteFeatureFlags.instance.eefCampaign;

  /// Remet les coutures de test à leur valeur de production.
  @visibleForTesting
  static void resetForTest() {
    clock = DateTime.now;
    windowSource = () => RemoteFeatureFlags.instance.eefCampaign;
  }

  static EefCampaignWindow get window => windowSource();

  /// La procédure est-elle suspendue dans [country] ?
  ///
  /// Passe par la fenêtre servie, donc la liste se corrige côté exploitation.
  /// Voir [EefCampaignWindow.isSuspendedForCountry] pour le sens de l'échec :
  /// un pays inconnu rend `false`, donc l'app annonce la date nationale — qui
  /// est exacte — plutôt qu'une suspension qui découragerait à tort.
  static bool isSuspendedFor(String? country) =>
      window.isSuspendedForCountry(country);

  /// La plateforme officielle servie, ou `null` (serveur plus ancien, adresse
  /// illisible) — l'écran n'affiche alors aucun lien.
  static String? get platformUrl => window.platformUrl;

  /// La page officielle qui justifie la suspension dans [country], ou `null`.
  /// `null` aussi quand le pays n'est pas suspendu : la source d'une suspension
  /// ne voyage pas vers quelqu'un qui n'est pas concerné.
  static String? suspensionSourceFor(String? country) =>
      window.suspensionSourceFor(country);

  /// Où en est la campagne.
  ///
  /// Une fenêtre incohérente (clôture avant ouverture) est traitée comme
  /// inconnue : c'est une faute de configuration, et en tirer une phase
  /// afficherait une campagne « close avant d'être ouverte ».
  static EefCampaignPhase phase() {
    final w = window;
    final opensAt = w.opensAt;
    final closesAt = w.closesAt;

    if (opensAt == null && closesAt == null) return EefCampaignPhase.unknown;
    if (opensAt != null && closesAt != null && closesAt.isBefore(opensAt)) {
      return EefCampaignPhase.unknown;
    }

    // Comparaison de JOURS, pas d'instants — et la clôture est INCLUSIVE.
    //
    // Deux défauts réparés d'un coup :
    //
    // **1. Le fuseau.** Comparer `clock()` (local) à une borne reprojetée
    // faisait basculer la phase à un moment qui dépendait du fuseau de
    // l'appareil. Les bornes sont désormais des jours naïfs
    // (`EefCampaignWindow._parseCampaignDay`) et « aujourd'hui » est réduit au
    // jour local : deux dates nues, aucune arithmétique de fuseau, donc le même
    // verdict partout dans le monde.
    //
    // **2. La clôture excluait son propre jour.** `now.isAfter(closesAt)` avec
    // `closesAt = 15 novembre 00:00` rendait la campagne CLOSE dès la première
    // seconde du 15 — alors que « jusqu'au 15 novembre » inclut le 15. Un
    // étudiant marocain ouvrant l'app le matin de sa date limite aurait lu que
    // la campagne était terminée, et il aurait renoncé. On compare donc
    // strictement après le jour de clôture.
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);

    if (closesAt != null) {
      final closeDay = DateTime(closesAt.year, closesAt.month, closesAt.day);
      if (today.isAfter(closeDay)) return EefCampaignPhase.closed;
    }
    if (opensAt != null) {
      final openDay = DateTime(opensAt.year, opensAt.month, opensAt.day);
      if (today.isBefore(openDay)) return EefCampaignPhase.beforeOpening;
    }
    return EefCampaignPhase.open;
  }

  /// Jours entiers restants avant l'ouverture, ou `null` hors de ce cas.
  ///
  /// Compté sur les JOURS CALENDAIRES, pas sur `Duration.inDays`. La division
  /// entière d'une durée aurait rendu 0 pour une ouverture le lendemain matin à
  /// 8 h — « dans 0 jour » pour quelque chose qui n'a pas eu lieu.
  static int? daysUntilOpening() {
    if (phase() != EefCampaignPhase.beforeOpening) return null;
    final opensAt = window.opensAt;
    if (opensAt == null) return null;

    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final openDay = DateTime(opensAt.year, opensAt.month, opensAt.day);
    return openDay.difference(today).inDays;
  }

  static bool get _isEnglish => Get.locale?.languageCode == 'en';

  /// « 26 août 2026 » / « 26 August 2026 », dans la langue active.
  ///
  /// ## Pourquoi ce `try`/`catch`, et pourquoi il n'est pas de la superstition
  ///
  /// `DateFormat` avec une locale EXPLICITE exige que les données de cette
  /// locale soient chargées, sinon il lève `LocaleDataException`. En production
  /// elles le sont : `GlobalMaterialLocalizations.delegate` les initialise en
  /// chargeant la locale de l'app. Mais cette méthode est statique et
  /// atteignable hors de tout `MaterialApp` — un test unitaire, un isolate, ou
  /// simplement un appel plus tôt qu'un délégué. Mesuré : le premier test
  /// unitaire écrit sur cette classe a levé exactement ça.
  ///
  /// Un utilitaire d'affichage n'a pas le droit de faire tomber l'écran qui
  /// l'appelle. Le repli est une date NUMÉRIQUE : elle ne dépend d'aucune donnée
  /// de locale, elle ne peut pas lever, et elle reste exacte — moins jolie, mais
  /// jamais fausse. `jj/mm/aaaa` est la convention du public de cette app.
  static String? dayLabel(DateTime? date) {
    if (date == null) return null;
    try {
      // « 1er octobre », jamais « 1 octobre ». `DateFormat` français ne pose pas
      // l'ordinal du premier du mois : il rend « 1 octobre 2026 », qui est une
      // faute de français. Or la date d'ouverture de la campagne EST un premier
      // du mois, donc c'est la chaîne que tout le monde verra — et toutes les
      // sources officielles écrivent « 1er octobre ». Un test l'a attrapée.
      if (!_isEnglish && date.day == 1) {
        final monthYear = DateFormat('MMMM yyyy', 'fr').format(date);
        return '1er $monthYear';
      }
      return DateFormat('d MMMM yyyy', _isEnglish ? 'en' : 'fr').format(date);
    } catch (_) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year}';
    }
  }

  /// La fenêtre en une ligne, ou `null` quand rien n'est servi.
  ///
  /// Les trois formes correspondent aux trois configurations réellement
  /// possibles : deux bornes, une ouverture seule, une clôture seule.
  static String? rangeLabel() {
    // Une fenêtre incohérente est TAIRE, pas imprimée. `phase()` la traite
    // déjà comme inconnue — mais rendre malgré tout « du 15 décembre au
    // 26 août » annulait cette garde : la classe se donnait pour règle de ne
    // rien dire, et disait quand même. Deux variables inversées dans un `.env`
    // suffisaient à l'obtenir.
    if (phase() == EefCampaignPhase.unknown) return null;

    final opens = dayLabel(window.opensAt);
    final closes = dayLabel(window.closesAt);

    if (opens != null && closes != null) {
      return _isEnglish ? '$opens → $closes' : 'du $opens au $closes';
    }
    if (opens != null) {
      // Ouverture passée, aucune clôture servie : « À partir du » plaçait en
      // tête une date déjà passée et laissait croire qu'une date limite
      // suivrait. Les clôtures varient selon le pays (audit build 57, T5-08).
      if (phase() == EefCampaignPhase.open) {
        return _isEnglish
            ? 'Open since $opens · the deadline depends on your country'
            : 'Ouverte depuis le $opens · la date limite dépend de ton pays';
      }
      return _isEnglish ? 'From $opens' : 'À partir du $opens';
    }
    if (closes != null) {
      return _isEnglish ? 'Until $closes' : "Jusqu'au $closes";
    }
    return null;
  }

  /// La ligne temporelle à afficher, ou `null` quand il n'y a rien d'honnête à
  /// dire.
  ///
  /// ## Pourquoi ce point unique existe
  ///
  /// Parce que la règle « la suspension REMPLACE les dates » n'était appliquée
  /// que par la vitrine. La carte d'accueil, elle, calculait le compte à rebours
  /// et l'affichait sans consulter la suspension : un étudiant nigérien lisait
  /// donc « ouverture dans 41 jours » sur l'écran le plus vu de l'app, alors que
  /// la vitrine refuse précisément de lui donner une date — parce que la source
  /// officielle dit que son dossier ne sera pas traité.
  ///
  /// C'est le défaut PARC-05 : une garde sur certaines portes. Le correctif
  /// n'est pas de la recopier sur la carte — c'est de faire en sorte qu'une
  /// troisième surface ne puisse pas l'oublier. Toute surface qui parle de
  /// temps passe désormais par ici.
  ///
  /// [country] est le pays de résidence du profil, tel qu'il est saisi — la
  /// normalisation est faite par [EefCampaignWindow.isSuspendedForCountry].
  static String? timingLabel({String? country}) {
    if (isSuspendedFor(country)) return null;

    final range = rangeLabel();
    if (range == null) return null;

    final days = daysUntilOpening();
    if (days == null || days <= 0) return range;

    // « dans 1 jours » était affiché à tout le monde la veille de l'ouverture —
    // le seul jour où cette ligne est lue avec attention.
    final suffix = days == 1
        ? 'eef_opens_tomorrow'.tr
        : 'eef_opens_in_days'.trParams({'days': '$days'});
    return '$range · $suffix';
  }
}
