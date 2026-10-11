import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/eef.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';

/// L'identifiant du texte de consentement actuellement affiché.
///
/// ## À incrémenter dès que le texte change
///
/// Cette chaîne est enregistrée avec chaque déclaration. Elle répond à la seule
/// question qu'un horodatage laisse ouverte : **qu'est-ce que l'étudiant a
/// accepté ?** Le jour où quelqu'un demande sur quelle base on l'a rappelé, une
/// date ne suffit pas — il faut la phrase.
///
/// `eef_consent_version_test.dart` verrouille l'appariement : il calcule une
/// empreinte des textes FR et EN de `eef_consent_notice` et rougit si l'un
/// change sans que cette constante bouge. Sans ce cliquet, la version aurait
/// désigné un texte qui n'existe plus — c'est-à-dire rien.
const kEefConsentVersion = 'eef-consent-v1';

/// Où en est la déclaration d'intérêt, du point de vue de l'écran.
enum EefInterestPhase { initial, loading, ready, submitting, failed }

/// Pourquoi une déclaration a échoué — grossier, exprès.
///
/// Trois causes seulement, parce que l'écran n'a que trois choses différentes à
/// dire : « vérifie ta connexion », « reconnecte-toi », « réessaie plus tard ».
/// Un catalogue plus fin aurait produit des messages que personne ne sait
/// traduire en geste.
enum EefInterestFailure { network, unauthorized, server }

/// L'état de la vitrine, séparé de son rendu.
///
/// ## Pourquoi un contrôleur et pas du `setState` dans l'écran
///
/// Parce que la règle qui compte ici est testable sans peindre un pixel : **un
/// échec d'envoi ne doit JAMAIS produire un état de succès**. Le masquage
/// `documentUploadEnabled` existe parce qu'un écran cochait « fourni ✓ » avant
/// l'appel réseau puis avalait l'échec dans Crashlytics ; l'étudiant voyait un
/// document envoyé que le conseiller n'a jamais reçu.
///
/// Ici la transition est explicite : `submitting` va vers `ready` avec
/// `interest.declared == true` UNIQUEMENT quand le serveur a répondu, et vers
/// `failed` sinon. Il n'existe aucun chemin de code qui marque `declared` sans
/// réponse — et un test le vérifie plutôt que de faire confiance à la lecture.
class EefInterestController extends ChangeNotifier {
  EefInterestController(
      {required AppApiClient apiClient, AnalyticsService? analytics})
      : _apiClient = apiClient,
        _analytics = analytics ?? AnalyticsService.instance;

  final AppApiClient _apiClient;
  final AnalyticsService _analytics;

  EefInterestPhase _phase = EefInterestPhase.initial;
  EefInterest _interest = EefInterest.notDeclared;
  EefInterestFailure? _failure;
  bool _readFailed = false;

  EefInterestPhase get phase => _phase;

  /// La dernière LECTURE de la déclaration a échoué : l'état « pas déclaré » est
  /// alors un repli, pas un fait. Le hub l'utilise pour ne pas proposer
  /// « Compléter mon profil » — et cacher « Me retirer » — à quelqu'un dont la
  /// déclaration existe peut-être : le consentement promet un retrait « depuis cet
  /// écran ».
  bool get readFailed => _readFailed;
  EefInterest get interest => _interest;
  EefInterestFailure? get failure => _failure;

  bool get declared => _interest.declared;
  bool get busy =>
      _phase == EefInterestPhase.loading ||
      _phase == EefInterestPhase.submitting;

  /// Oublie un échec ANCIEN : [failure] redevient `null` et la phase `failed`
  /// repasse à `ready`. La déclaration, elle, n'est pas touchée.
  ///
  /// ## Pourquoi la feuille l'appelle à l'ouverture
  ///
  /// [failure] et la phase `failed` décrivent le DERNIER envoi, et la feuille de
  /// déclaration les affiche comme « Envoi impossible… Rien n'a été enregistré » en
  /// remplaçant « Valider » par « Réessayer ». Or un RETRAIT en échec (depuis le
  /// lien de la feuille ou le bouton du hub) les laisse posés : rouvrir « Modifier
  /// mon profil » annonçait alors l'échec d'un envoi que personne n'avait tenté.
  /// L'erreur d'une feuille ne vit que tant que cette feuille est ouverte ; la
  /// suivante repart d'un état propre.
  ///
  /// Sans effet pendant un envoi ou une lecture : couper la phase `submitting`
  /// laisserait un second tap relancer un appel déjà en vol.
  void clearFailure() {
    if (busy) return;
    if (_failure == null && _phase != EefInterestPhase.failed) return;
    _failure = null;
    if (_phase == EefInterestPhase.failed) _phase = EefInterestPhase.ready;
    notifyListeners();
  }

  /// Lit l'état existant, pour ne pas reposer la question à qui a déjà répondu.
  ///
  /// Un échec de LECTURE n'est pas un échec d'envoi : on retombe silencieusement
  /// sur « pas déclaré ». Au pire on repose la question à quelqu'un qui avait
  /// répondu — coût réel mais réparable, à comparer au cas inverse, qui serait
  /// de masquer le bouton et de perdre la déclaration.
  Future<void> load() async {
    if (_phase == EefInterestPhase.loading) return;
    _phase = EefInterestPhase.loading;
    notifyListeners();

    try {
      final raw = await _apiClient.getEefInterest();
      _interest = EefInterest.fromJson(raw);
      _readFailed = false;
    } catch (_) {
      _interest = EefInterest.notDeclared;
      _readFailed = true;
    }

    _failure = null;
    _phase = EefInterestPhase.ready;
    notifyListeners();
  }

  /// Déclare l'intérêt. Rend `true` seulement si le SERVEUR a confirmé.
  Future<bool> submit({
    String? currentLevel,
    String? targetLevel,
    List<String> fieldIds = const <String>[],
    bool wantsPremium = false,
  }) async {
    if (_phase == EefInterestPhase.submitting) return false;

    _phase = EefInterestPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.declareEefInterest(
        consentVersion: kEefConsentVersion,
        currentLevel: currentLevel,
        targetLevel: targetLevel,
        fieldIds: fieldIds,
        wantsPremium: wantsPremium,
      );

      final saved = EefInterest.fromJson(raw);

      // Une réponse 2xx dont le corps ne dit PAS `declared: true` est traitée
      // comme un échec. C'est le cas limite qui a produit le défaut d'origine :
      // le transport a réussi, l'enregistrement non, et l'app a affiché un
      // succès. Un 200 n'est pas une preuve d'écriture — le corps l'est.
      if (!saved.declared) {
        _failure = EefInterestFailure.server;
        _phase = EefInterestPhase.failed;
        notifyListeners();
        unawaited(_analytics.logEefInterestFailed(_failure!.name));
        return false;
      }

      _interest = saved;
      _phase = EefInterestPhase.ready;
      notifyListeners();

      unawaited(_analytics.logEefInterestDeclared(
        wantsPremium: saved.wantsPremium,
        fieldCount: saved.fieldIds.length,
        currentLevel: saved.currentLevel,
      ));
      return true;
    } catch (error) {
      _failure = classifyFailure(error);
      _phase = EefInterestPhase.failed;
      notifyListeners();
      unawaited(_analytics.logEefInterestFailed(_failure!.name));
      return false;
    }
  }

  /// Met à jour les niveaux et les domaines d'une déclaration EXISTANTE, sans
  /// redonner le consentement. Rend `true` seulement si le SERVEUR a confirmé.
  ///
  /// C'est la raison d'être de `PATCH` : modifier ses domaines ne doit ni
  /// refabriquer un consentement au rappel commercial que l'étudiant n'a pas
  /// redonné, ni effacer son intérêt Premium. Le corps de la réponse doit dire
  /// `declared: true` — un 200 qui ne le dit pas est un échec, comme pour
  /// [submit].
  ///
  /// Aucune mesure `eef_interest_declared` ici : ce n'est pas une nouvelle
  /// déclaration, et la compter fausserait le ratio que ce document garde pour
  /// les premières.
  Future<bool> updateProfile({
    String? currentLevel,
    String? targetLevel,
    List<String>? fieldIds,
  }) async {
    if (_phase == EefInterestPhase.submitting) return false;

    _phase = EefInterestPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.updateEefProfile(
        currentLevel: currentLevel,
        targetLevel: targetLevel,
        fieldIds: fieldIds,
      );
      final saved = EefInterest.fromJson(raw);
      if (!saved.declared) {
        _failure = EefInterestFailure.server;
        _phase = EefInterestPhase.failed;
        notifyListeners();
        unawaited(_analytics.logEefInterestFailed(_failure!.name));
        return false;
      }

      _interest = saved;
      _phase = EefInterestPhase.ready;
      notifyListeners();
      return true;
    } catch (error) {
      _failure = classifyFailure(error);
      _phase = EefInterestPhase.failed;
      notifyListeners();
      unawaited(_analytics.logEefInterestFailed(_failure!.name));
      return false;
    }
  }

  /// Retire la déclaration. Rend `true` seulement si le SERVEUR a confirmé.
  ///
  /// Symétrique de [submit], et pour la même raison : afficher « tu es retiré »
  /// sur une ligne toujours en base est le même mensonge que « c'est noté » sur
  /// une ligne jamais écrite. Le corps de la réponse doit dire `declared: false`.
  ///
  /// Aucun événement analytique n'est émis ici, volontairement. Mesurer les
  /// retraits demanderait de conserver une trace de quelqu'un qui vient de
  /// demander à ne plus en avoir — et le taux ne changerait aucune décision que
  /// le compteur de déclarations ne montre déjà.
  Future<bool> withdraw() async {
    if (_phase == EefInterestPhase.submitting) return false;

    _phase = EefInterestPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.withdrawEefInterest();
      final after = EefInterest.fromJson(raw);

      // Le serveur rend l'état APRÈS retrait. S'il dit encore `declared: true`,
      // la suppression n'a pas eu lieu et l'écran ne doit pas prétendre le
      // contraire.
      if (after.declared) {
        _failure = EefInterestFailure.server;
        _phase = EefInterestPhase.failed;
        notifyListeners();
        return false;
      }

      _interest = EefInterest.notDeclared;
      _phase = EefInterestPhase.ready;
      notifyListeners();
      return true;
    } catch (error) {
      _failure = classifyFailure(error);
      _phase = EefInterestPhase.failed;
      notifyListeners();
      return false;
    }
  }

  /// Range l'erreur dans l'une des trois cases que l'écran sait dire.
  @visibleForTesting
  static EefInterestFailure classifyFailure(Object error) {
    if (error is! DioException) return EefInterestFailure.server;

    final status = error.response?.statusCode;
    if (status == 401 || status == 403) return EefInterestFailure.unauthorized;
    if (status != null && status >= 400) return EefInterestFailure.server;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return EefInterestFailure.network;
      default:
        return EefInterestFailure.server;
    }
  }
}
