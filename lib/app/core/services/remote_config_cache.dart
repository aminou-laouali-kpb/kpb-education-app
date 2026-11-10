import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// La dernière réponse de `/config/app`, avec l'instant où elle a été lue.
class RemoteConfigSnapshot {
  const RemoteConfigSnapshot({required this.savedAt, required this.config});

  final DateTime savedAt;
  final Map<String, dynamic> config;
}

/// Où la dernière réponse de `/config/app` est gardée d'un lancement à
/// l'autre. Interface pour les tests ; SharedPreferences en production.
///
/// ## Pourquoi la garder
///
/// Les interrupteurs échouent FERMÉS : sans réponse du serveur, l'app retombe
/// sur ses constantes de compilation, qui valent `false`. Sur un réseau lent
/// (une réponse de plus de 15 s, courante en 2G/3G), l'espace Études en France
/// disparaissait donc à chaque ouverture, parfois pour toute la session
/// (audit build 57, T2-06 ; audit avant la 59). Avec la dernière réponse en
/// mémoire, l'app démarre sur ce que le serveur a dit la dernière fois, puis
/// se corrige dès qu'il répond.
///
/// Ce n'est pas une donnée personnelle : la charge est publique et identique
/// pour tous les téléphones. Elle n'est donc effacée ni à la déconnexion ni à
/// la suppression du compte.
abstract class RemoteConfigCache {
  Future<RemoteConfigSnapshot?> read();

  Future<void> write(RemoteConfigSnapshot snapshot);
}

class SharedPreferencesRemoteConfigCache implements RemoteConfigCache {
  const SharedPreferencesRemoteConfigCache();

  static const String storageKey = 'kpb.remote_config.v1';

  @override
  Future<RemoteConfigSnapshot?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final savedAt = decoded['savedAt'];
    final config = decoded['config'];
    if (savedAt is! int || config is! Map) return null;
    return RemoteConfigSnapshot(
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
      config: Map<String, dynamic>.from(config),
    );
  }

  @override
  Future<void> write(RemoteConfigSnapshot snapshot) async {
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(<String, dynamic>{
        'savedAt': snapshot.savedAt.millisecondsSinceEpoch,
        'config': snapshot.config,
      }),
    );
  }
}
