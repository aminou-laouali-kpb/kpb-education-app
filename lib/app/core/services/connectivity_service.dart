import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../ui/components/kpb_toast.dart';

/// Lightweight connectivity checker — no extra package needed.
/// Tries to resolve a DNS lookup to determine online/offline status.
///
/// ## Ce qui a changé à la 59 (audit avant l'archive)
///
/// La sonde résolvait `dns.google`, une seule fois, avec 5 s de délai : un
/// échec et l'app se déclarait « hors ligne ». Sur une 2G/3G lente, ou un
/// réseau qui filtre les domaines Google, elle affichait donc « Mode
/// hors-ligne » alors que l'API de KPB répondait — et mettait en file des
/// mises à jour de profil qui pouvaient partir.
///
/// - Elle sonde d'abord **l'hôte de l'API de KPB**, celui qui compte, puis
///   `dns.google` en second avis. Un seul qui répond suffit.
/// - Il faut **deux échecs de suite** pour passer hors ligne. Le second essai
///   suit de quelques secondes, pour ne pas retarder une vraie coupure.
/// - Le retour en ligne, lui, reste immédiat.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  Timer? _reconnectDebounce;
  StreamSubscription<bool>? _reconnectSubscription;
  bool _monitoring = false;
  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Start periodic checks every 30s.
  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    _check();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// Registers the reconnect sync handler (replaces any previous binding).
  void bindReconnectSync(Future<void> Function() onReconnect) {
    _reconnectSubscription?.cancel();
    _reconnectSubscription = onConnectivityChanged.listen((online) {
      if (online) {
        _reconnectDebounce?.cancel();
        _reconnectDebounce = Timer(const Duration(seconds: 3), () async {
          if (_isOnline) {
            await onReconnect();
          }
        });
      } else {
        _reconnectDebounce?.cancel();
      }
    });
  }

  /// Couture de test : pose l'état réseau et le diffuse, SANS le toast de
  /// `_setOnline` (il demande un Overlay) ni sonde DNS. Un test qui l'appelle
  /// remet `true` dans son tearDown : le service est un singleton.
  @visibleForTesting
  void debugSetOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(online);
  }

  void dispose() {
    _timer?.cancel();
    _recheck?.cancel();
    _reconnectDebounce?.cancel();
    _reconnectSubscription?.cancel();
    _controller.close();
  }

  /// Échecs de suite avant de se déclarer hors ligne.
  static const int offlineAfterFailures = 2;

  /// Attente avant le second essai, après un premier échec.
  static const Duration recheckDelay = Duration(seconds: 5);

  static const Duration _probeTimeout = Duration(seconds: 5);

  int _consecutiveFailures = 0;
  Timer? _recheck;

  /// Les hôtes sondés, dans l'ordre : l'API de KPB, puis un second avis.
  @visibleForTesting
  static List<String> probeHosts() => <String>{
        Uri.tryParse(AppConfig.apiBaseUrl)?.host ?? '',
        'dns.google',
      }.where((host) => host.isNotEmpty).toList();

  /// La résolution d'un hôte, injectable pour les tests.
  @visibleForTesting
  Future<bool> Function(String host) resolver = _resolve;

  static Future<bool> _resolve(String host) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(_probeTimeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Remet le service dans son état de départ, entre deux tests.
  @visibleForTesting
  void debugReset() {
    _recheck?.cancel();
    _recheck = null;
    _consecutiveFailures = 0;
    _isOnline = true;
    resolver = _resolve;
  }

  /// Lance une sonde tout de suite — pour les tests.
  @visibleForTesting
  Future<void> debugCheckNow() => _check();

  Future<void> _check() async {
    var reachable = false;
    for (final host in probeHosts()) {
      if (await resolver(host)) {
        reachable = true;
        break;
      }
    }
    if (reachable) {
      _consecutiveFailures = 0;
      _recheck?.cancel();
      _setOnline(true);
      return;
    }
    _consecutiveFailures++;
    if (_consecutiveFailures >= offlineAfterFailures) {
      _setOnline(false);
      return;
    }
    // Premier échec : on ne conclut pas, mais on n'attend pas non plus les
    // 30 s du prochain passage pour confirmer une vraie coupure.
    _recheck?.cancel();
    _recheck = Timer(recheckDelay, _check);
  }

  void _setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(online);

    // Pas de bandeau flottant à la coupure : le bandeau « Mode hors-ligne » au
    // sommet de l'app le dit déjà, et deux signaux pour un même état se
    // doublaient (audit build 57, T7-07). Seul le retour du réseau a son toast.
    if (online) {
      KpbToast.success(
        'online_body'.tr,
        title: 'online_title'.tr,
        atTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
