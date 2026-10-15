part of '../app_controller.dart';

/// « Suivre » une bourse (chantier G) et badge serveur de la cloche.
///
/// Suivre = favori + alerte d'ouverture + rappels (décision propriétaire). Le
/// favori ([SavedItem] de type bourse) reste le support local : il marche hors
/// ligne et se resynchronise comme avant. Deux compléments :
///
/// - une bourse suivie CÔTÉ SERVEUR sans favori local (alerte posée par la
///   cloche d'une build précédente, favori d'un autre appareil pas encore
///   synchronisé) compte comme suivie — sinon « Suivre » afficherait « Suivre »
///   pour une bourse dont l'élève reçoit déjà les annonces, et un tap créerait
///   un doublon au lieu de l'arrêter ;
/// - « Suivre » pose aussi l'alerte d'ouverture côté serveur (drapeau
///   `followOpeningAlert`), APRÈS la création du favori : en mode `legacy`
///   (défaut du backend) seuls les abonnés à l'alerte reçoivent le push
///   d'ouverture, et deux écritures concurrentes du même favori se
///   marcheraient dessus en mode `outbox_followers`.
mixin _ScholarshipFollowMixin on _AppControllerBase {
  /// Suivies côté serveur (alerte, favori d'un autre appareil) sans favori
  /// local.
  final Set<String> _serverFollowedScholarshipIds = <String>{};

  /// Retirées par l'élève dans cette session : une liste serveur en retard ne
  /// les ressuscite pas.
  final Set<String> _unfollowedScholarshipIds = <String>{};

  /// Non-lus du centre de notifications serveur (`unread-count`).
  int serverUnreadNotifications = 0;

  /// Faux dès que le serveur répond 404 à `unread-count` : on cesse de
  /// demander jusqu'au prochain lancement.
  bool _unreadEndpointAvailable = true;
  DateTime? _lastUnreadFetchAt;

  /// Vrai quand le serveur a prouvé qu'il connaît les routes du suivi
  /// (chantier C) dans cette session. Conditionne ce qui serait silencieusement
  /// ignoré par un backend plus ancien (la préférence « ouverture »).
  bool serverSupportsFollow = false;

  bool isFollowingScholarship(String scholarshipId) {
    if (isSaved(SavedItemType.scholarship, scholarshipId)) return true;
    if (_unfollowedScholarshipIds.contains(scholarshipId)) return false;
    return _serverFollowedScholarshipIds.contains(scholarshipId);
  }

  /// Le serveur dit que ces bourses sont suivies (liste des alertes, bloc
  /// `follow` d'une fiche, page des suivis).
  void rememberServerFollowedScholarships(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || _unfollowedScholarshipIds.contains(trimmed)) {
        continue;
      }
      // Retirée hors ligne lors d'une session précédente, suppression pas
      // encore confirmée : la liste du serveur est en retard, pas l'élève.
      if (_savedItemTombstones
          .contains(_savedItemKey(SavedItemType.scholarship, trimmed))) {
        continue;
      }
      changed = _serverFollowedScholarshipIds.add(trimmed) || changed;
    }
    if (changed) update();
  }

  /// Bascule le suivi et rend le NOUVEL état.
  bool toggleScholarshipFollow(String scholarshipId) {
    final next = !isFollowingScholarship(scholarshipId);
    setScholarshipFollow(scholarshipId, following: next);
    return next;
  }

  /// Pose l'état de suivi (bouton « Suivre », glisser pour retirer, Annuler).
  /// Local d'abord — l'icône change tout de suite, même hors ligne — puis le
  /// serveur, en arrière-plan.
  void setScholarshipFollow(String scholarshipId, {required bool following}) {
    if (following) {
      _unfollowedScholarshipIds.remove(scholarshipId);
      final remote = ensureSaved(SavedItemType.scholarship, scholarshipId);
      unawaited(remote.then((_) => _mirrorOpeningAlert(scholarshipId, true)));
    } else {
      _serverFollowedScholarshipIds.remove(scholarshipId);
      _unfollowedScholarshipIds.add(scholarshipId);
      final wasSaved = isSaved(SavedItemType.scholarship, scholarshipId);
      final remote = ensureUnsaved(SavedItemType.scholarship, scholarshipId);
      if (!wasSaved) update();
      unawaited(remote.then((_) => _mirrorOpeningAlert(scholarshipId, false)));
    }
  }

  /// « Suivre les N compatibles » (test « Mes 10 bourses ») : suit chaque
  /// bourse comme le bouton « Suivre » — favori local par `ensureSaved`,
  /// JAMAIS une bascule, donc une bourse déjà suivie reste suivie — puis pose
  /// les alertes en UNE requête groupée (`POST /me/scholarship-alerts`).
  ///
  /// Rend les identifiants NOUVELLEMENT suivis : « Annuler » ne retire que
  /// ceux-là, jamais un suivi antérieur.
  List<String> followScholarships(Iterable<String> scholarshipIds) {
    final ids = <String>[];
    for (final raw in scholarshipIds) {
      final id = raw.trim();
      if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
    }
    final newlyFollowed =
        ids.where((id) => !isFollowingScholarship(id)).toList();
    final saves = <Future<void>>[];
    for (final id in ids) {
      _unfollowedScholarshipIds.remove(id);
      saves.add(ensureSaved(SavedItemType.scholarship, id));
    }
    update();
    // Les alertes APRÈS les favoris : deux écritures concurrentes du même
    // favori se marcheraient dessus côté serveur (mode `outbox_followers`).
    unawaited(Future.wait(saves).then((_) => _mirrorOpeningAlerts(ids)));
    return newlyFollowed;
  }

  Future<void> _mirrorOpeningAlerts(List<String> ids) async {
    if (ids.isEmpty) return;
    if (!RemoteFeatureFlags.instance.followSetsOpeningAlert) return;
    if (!AppConfig.enableRemoteSync || isGuestMode || profile == null) return;
    try {
      await _apiClient.subscribeScholarshipAlertsBulk(ids);
    } catch (error) {
      // Route groupée absente (backend plus ancien) : une alerte par bourse,
      // comme le bouton « Suivre ». Hors ligne : le favori se resynchronise.
      if (error is ScholarshipMatchException &&
          error.failure == ScholarshipMatchFailure.disabled) {
        for (final id in ids) {
          await _mirrorOpeningAlert(id, true);
        }
      }
    }
  }

  Future<void> _mirrorOpeningAlert(String scholarshipId, bool follow) async {
    if (!RemoteFeatureFlags.instance.followSetsOpeningAlert) return;
    if (!AppConfig.enableRemoteSync || isGuestMode || profile == null) return;
    try {
      if (follow) {
        await _apiClient.subscribeScholarshipAlert(scholarshipId);
      } else {
        await _apiClient.unsubscribeScholarshipAlert(scholarshipId);
      }
    } catch (_) {
      // Hors ligne ou alerte déjà absente : le favori, lui, se resynchronise.
    }
  }

  /// Rafraîchit le badge serveur de la cloche. Au plus une fois par minute
  /// sauf [force] ; ne lève jamais ; ne demande plus rien après un 404.
  Future<void> refreshServerUnreadCount({bool force = false}) async {
    if (!RemoteFeatureFlags.instance.serverUnreadBadgeEnabled) return;
    if (!AppConfig.enableRemoteSync || isGuestMode || profile == null) return;
    if (!_unreadEndpointAvailable) return;
    final last = _lastUnreadFetchAt;
    final now = DateTime.now();
    if (!force && last != null && now.difference(last).inSeconds < 60) return;
    _lastUnreadFetchAt = now;
    try {
      final count = await _apiClient.fetchUnreadNotificationCount();
      noteServerSupportsFollow();
      setServerUnreadNotifications(count);
    } catch (error) {
      if (isEndpointUnavailable(error)) {
        _unreadEndpointAvailable = false;
        setServerUnreadNotifications(0);
      }
    }
  }

  /// Une route du chantier C a répondu 200 : le backend connaît le suivi.
  void noteServerSupportsFollow() {
    if (serverSupportsFollow) return;
    serverSupportsFollow = true;
    update();
  }

  /// Le centre de notifications vient de lire le fil : son compte fait foi.
  void setServerUnreadNotifications(int count) {
    final next = count < 0 ? 0 : count;
    if (next == serverUnreadNotifications) return;
    serverUnreadNotifications = next;
    update();
  }

  @override
  void _resetScholarshipFollowState() {
    _serverFollowedScholarshipIds.clear();
    _unfollowedScholarshipIds.clear();
    serverUnreadNotifications = 0;
    _unreadEndpointAvailable = true;
    _lastUnreadFetchAt = null;
    serverSupportsFollow = false;
    unawaited(FollowedScholarshipsStore.instance.clear());
    // « Mes 10 bourses » : runs et brouillons appartiennent au compte.
    unawaited(ScholarshipMatchStore.instance.clear());
    // Bourses hors ligne (chantier I) : la liste porte l'état « suivie » et le
    // score du compte, les fiches son suivi.
    unawaited(ScholarshipsOfflineCache.instance.clear());
  }
}
