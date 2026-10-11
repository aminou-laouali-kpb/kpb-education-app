import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Origin of the Socket.IO server, derived from the REST base URL.
///
/// Only a trailing `/api` segment and trailing `/` characters are dropped.
/// Nest's `setGlobalPrefix('api')` applies to HTTP routes only: the `/cases`
/// gateway namespace lives at the host root, so the socket URL is
/// `<origin>/cases`.
///
/// Never use `replaceFirst('/api', '')` here: the first match in a production
/// base URL is the `//api.` that starts the host name, not the path suffix, so
/// the scheme and host come out mangled.
@visibleForTesting
String socketBaseUrl(String apiBaseUrl) =>
    apiBaseUrl.replaceFirst(RegExp(r'(?:/api)?/*$'), '');

class CaseSocketService {
  io.Socket? _socket;
  String? _currentCaseId;

  // Registered listeners are kept so they can be re-attached to a freshly
  // created socket whenever connect() runs again (disconnect() disposes the
  // previous socket and would otherwise drop them).
  void Function(Map<String, dynamic> data)? _onMessage;
  void Function(Map<String, dynamic> data)? _onCaseUpdated;
  void Function(Map<String, dynamic> data)? _onMessageAck;
  void Function(Map<String, dynamic> data)? _onTyping;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentCaseId => _currentCaseId;

  Future<void> connect(String caseId) async {
    await disconnect();
    _currentCaseId = caseId;

    final baseUrl = socketBaseUrl(AppConfig.apiBaseUrl);

    _socket = io.io(
      '$baseUrl/cases',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    // Socket.IO sends auth payload in the handshake body. Query strings are
    // routinely captured by proxies/access logs and must never carry bearer
    // tokens or user-controlled display names.
    //
    // Une FONCTION, relue à chaque (re)connexion : un jeton figé au premier
    // `connect` expirait au bout d'une heure, les reconnexions étaient alors
    // refusées par le serveur et le temps réel s'arrêtait sans rien dire.
    _socket!.auth = (void Function(Map<String, dynamic>) send) => send({
          'token':
              Supabase.instance.client.auth.currentSession?.accessToken ?? '',
        });

    // Re-attach any listeners registered before/after a previous connection.
    _bindHandlers();

    _socket!.onConnect((_) {
      debugPrint('[WS] Connected to case namespace');
      _socket!.emit('joinCase', {'caseId': caseId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WS] Disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('[WS] Connection error: $error');
    });

    _socket!.connect();
  }

  Future<void> disconnect() async {
    if (_socket != null && _currentCaseId != null) {
      _socket!.emit('leaveCase', {'caseId': _currentCaseId});
    }
    _socket?.dispose();
    _socket = null;
    _currentCaseId = null;
  }

  void sendMessage(String caseId, String body) {
    _socket?.emit('newMessage', {'caseId': caseId, 'body': body});
  }

  void sendTyping(String caseId, bool isTyping) {
    _socket?.emit('typing', {'caseId': caseId, 'isTyping': isTyping});
  }

  void onMessage(void Function(Map<String, dynamic> data) callback) {
    _onMessage = callback;
    _attach('message', callback);
  }

  void onCaseUpdated(void Function(Map<String, dynamic> data) callback) {
    _onCaseUpdated = callback;
    _attach('caseUpdated', callback);
  }

  void onMessageAck(void Function(Map<String, dynamic> data) callback) {
    _onMessageAck = callback;
    _attach('messageAck', callback);
  }

  void onTyping(void Function(Map<String, dynamic> data) callback) {
    _onTyping = callback;
    _attach('typing', callback);
  }

  /// Binds the stored listeners onto the current socket. Called from connect()
  /// so listeners registered before a (re)connection are not lost.
  void _bindHandlers() {
    if (_onMessage != null) _attach('message', _onMessage!);
    if (_onCaseUpdated != null) _attach('caseUpdated', _onCaseUpdated!);
    if (_onMessageAck != null) _attach('messageAck', _onMessageAck!);
    if (_onTyping != null) _attach('typing', _onTyping!);
  }

  void _attach(
    String event,
    void Function(Map<String, dynamic> data) callback,
  ) {
    final socket = _socket;
    if (socket == null) return;
    // Avoid stacking duplicate handlers if re-registered on the same socket.
    socket.off(event);
    socket.on(event, (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }
}
