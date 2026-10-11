import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/models/premium_waitlist.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';

/// L'identifiant du texte affiché au moment du tap.
///
/// ## À incrémenter dès que le texte change
///
/// Cette chaîne est enregistrée avec chaque inscription. Elle répond à la seule
/// question qu'un horodatage laisse ouverte : **à quoi l'étudiant s'est-il
/// inscrit ?** Ce texte décrit un service qui n'existe pas encore, donc il
/// changera ; le jour où quelqu'un demande, une date ne suffira pas.
///
/// `premium_waitlist_consent_version_test.dart` verrouille l'appariement : il
/// calcule une empreinte des textes FR et EN affichés et rougit si l'un change
/// sans que cette constante bouge. Sans ce cliquet, la version désignerait un
/// texte qui n'existe plus — c'est-à-dire rien.
const kPremiumWaitlistConsentVersion = 'premium-waitlist-v1';

/// Où en est l'inscription, du point de vue de l'écran.
enum PremiumWaitlistPhase { initial, loading, ready, submitting, failed }

/// Pourquoi une inscription a échoué — grossier, exprès.
///
/// Trois causes, parce que l'écran n'a que trois choses différentes à dire :
/// « vérifie ta connexion », « reconnecte-toi », « réessaie plus tard ». Un
/// catalogue plus fin produirait des messages que personne ne sait traduire en
/// geste.
enum PremiumWaitlistFailure { network, unauthorized, server }

/// L'état de la liste d'attente, séparé de son rendu.
///
/// ## Pourquoi un contrôleur et pas du `setState`
///
/// Parce que la règle qui compte est testable sans peindre un pixel : **un
/// échec d'envoi ne doit JAMAIS produire un état de succès.** Le masquage
/// `documentUploadEnabled` existe parce qu'un écran cochait « fourni ✓ » avant
/// l'appel réseau puis avalait l'échec ; l'étudiant croyait avoir envoyé un
/// dossier que personne n'a reçu. Ici la faute serait pire dans son silence :
/// un étudiant persuadé d'être sur la liste attendrait une notification qui ne
/// viendrait jamais, et rien, jamais, ne le détromperait.
///
/// La transition est donc explicite : `submitting` va vers `ready` avec
/// `registered == true` UNIQUEMENT quand le serveur l'a confirmé dans le CORPS
/// de sa réponse, et vers `failed` sinon.
class PremiumWaitlistController extends ChangeNotifier {
  PremiumWaitlistController({
    required AppApiClient apiClient,
    AnalyticsService? analytics,
  })  : _apiClient = apiClient,
        _analytics = analytics ?? AnalyticsService.instance;

  final AppApiClient _apiClient;
  final AnalyticsService _analytics;

  PremiumWaitlistPhase _phase = PremiumWaitlistPhase.initial;
  PremiumWaitlistEntry _entry = PremiumWaitlistEntry.notRegistered;
  PremiumWaitlistFailure? _failure;

  PremiumWaitlistPhase get phase => _phase;
  PremiumWaitlistEntry get entry => _entry;
  PremiumWaitlistFailure? get failure => _failure;

  /// La langue du texte RÉELLEMENT affiché au moment du tap.
  ///
  /// Lue sur `Get.locale`, c'est-à-dire la même source que `.tr`, qui a rendu
  /// le texte à l'écran. La dériver d'ailleurs — la locale du système, la
  /// préférence enregistrée au profil — aurait pu désigner une langue que
  /// l'étudiant n'a pas lue.
  ///
  /// Repli sur `fr` : c'est la seule langue livrée aujourd'hui
  /// (`kShippedLocale`), et le serveur n'accepte que `fr` ou `en`. Envoyer une
  /// locale exotique ferait refuser l'inscription pour une raison que
  /// l'étudiant ne peut ni comprendre ni corriger.
  @visibleForTesting
  String get consentLocale => Get.locale?.languageCode == 'en' ? 'en' : 'fr';

  bool get registered => _entry.registered;
  bool get busy =>
      _phase == PremiumWaitlistPhase.loading ||
      _phase == PremiumWaitlistPhase.submitting;

  /// Lit l'état existant, pour ne pas reproposer le bouton à qui a déjà tapé.
  ///
  /// Un échec de LECTURE n'est pas un échec d'envoi : on retombe silencieusement
  /// sur « pas inscrit ». Au pire on repropose le bouton à quelqu'un d'inscrit,
  /// et un second tap est idempotent côté serveur. Masquer le bouton sur une
  /// lecture ratée, à l'inverse, perdrait l'inscription pour de bon.
  Future<void> load() async {
    if (_phase == PremiumWaitlistPhase.loading) return;
    _phase = PremiumWaitlistPhase.loading;
    notifyListeners();

    try {
      final raw = await _apiClient.getPremiumWaitlist();
      _entry = PremiumWaitlistEntry.fromJson(raw);
    } catch (_) {
      _entry = PremiumWaitlistEntry.notRegistered;
    }

    _failure = null;
    _phase = PremiumWaitlistPhase.ready;
    notifyListeners();
  }

  /// Inscrit l'étudiant. Rend `true` seulement si le SERVEUR a confirmé.
  Future<bool> join() async {
    if (_phase == PremiumWaitlistPhase.submitting) return false;

    _phase = PremiumWaitlistPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.joinPremiumWaitlist(
        consentVersion: kPremiumWaitlistConsentVersion,
        consentLocale: consentLocale,
      );
      final saved = PremiumWaitlistEntry.fromJson(raw);

      // Une réponse 2xx dont le corps ne dit PAS `registered: true` est un
      // échec. C'est le cas limite qui compte : le transport a réussi,
      // l'enregistrement non. Un 200 n'est pas une preuve d'écriture — le corps
      // l'est.
      if (!saved.registered) {
        return _fail(PremiumWaitlistFailure.server);
      }

      _entry = saved;
      _phase = PremiumWaitlistPhase.ready;
      notifyListeners();
      unawaited(_analytics.logPremiumWaitlistJoined());
      return true;
    } catch (error) {
      return _fail(classifyFailure(error));
    }
  }

  /// Retire l'étudiant de la liste. Rend `true` seulement si le SERVEUR a
  /// confirmé.
  ///
  /// Symétrique de [join] et pour la même raison : afficher « tu es retiré » sur
  /// une ligne toujours en base est le même mensonge que « c'est noté » sur une
  /// ligne jamais écrite.
  ///
  /// Aucun événement analytique, volontairement — voir le contrat d'événements.
  Future<bool> leave() async {
    if (_phase == PremiumWaitlistPhase.submitting) return false;

    _phase = PremiumWaitlistPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.leavePremiumWaitlist();
      final after = PremiumWaitlistEntry.fromJson(raw);

      // Le serveur rend l'état APRÈS retrait. S'il dit encore `registered:
      // true`, la suppression n'a pas eu lieu.
      if (after.registered) {
        return _fail(PremiumWaitlistFailure.server);
      }

      _entry = PremiumWaitlistEntry.notRegistered;
      _phase = PremiumWaitlistPhase.ready;
      notifyListeners();
      return true;
    } catch (error) {
      return _fail(classifyFailure(error));
    }
  }

  bool _fail(PremiumWaitlistFailure failure) {
    _failure = failure;
    _phase = PremiumWaitlistPhase.failed;
    notifyListeners();
    _analytics.logPremiumWaitlistFailed(failure.name);
    return false;
  }

  /// Range l'erreur dans l'une des trois cases que l'écran sait dire.
  @visibleForTesting
  static PremiumWaitlistFailure classifyFailure(Object error) {
    if (error is! DioException) return PremiumWaitlistFailure.server;

    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return PremiumWaitlistFailure.unauthorized;
    }
    if (status != null && status >= 400) return PremiumWaitlistFailure.server;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return PremiumWaitlistFailure.network;
      default:
        return PremiumWaitlistFailure.server;
    }
  }
}
