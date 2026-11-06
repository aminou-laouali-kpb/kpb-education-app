import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../ui/components/kpb_toast.dart';

/// Lightweight connectivity checker — no extra package needed.
/// Tries to resolve a DNS lookup to determine online/offline status.
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
    _reconnectDebounce?.cancel();
    _reconnectSubscription?.cancel();
    _controller.close();
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      _setOnline(result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } on SocketException {
      _setOnline(false);
    } on TimeoutException {
      _setOnline(false);
    }
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
