import 'package:supabase_flutter/supabase_flutter.dart';

import 'kpb_secure_storage.dart';

/// Persists the Supabase auth session (which contains the long-lived refresh
/// token) in the platform secure store (iOS Keychain / Android Keystore-backed)
/// instead of the default SharedPreferences/NSUserDefaults, where it would sit
/// in plain text.
///
/// Note: `accessToken()` returns the whole persisted session string, matching
/// the contract of the SDK's [LocalStorage] (the name is historical).
class KpbSecureLocalStorage extends LocalStorage {
  const KpbSecureLocalStorage();

  static const _sessionKey = 'kpb-supabase-session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _readSession()) != null;

  @override
  Future<String?> accessToken() => _readSession();

  /// Lit la session, ou rend `null` si le magasin sécurisé est illisible.
  ///
  /// Sur Android, la clé du Keystore qui chiffre ce magasin peut être perdue
  /// (restauration d'une sauvegarde sur un autre téléphone, mise à jour du
  /// système) : la lecture lève alors à CHAQUE lancement. Comme
  /// `Supabase.initialize` la lit au démarrage, l'app restait bloquée sur
  /// l'écran d'erreur, sans autre issue qu'effacer ses données (audit avant
  /// la 59). Une lecture qui lève vaut maintenant « pas de session » : l'app
  /// s'ouvre, et l'élève se reconnecte.
  ///
  /// L'entrée n'est PAS effacée. La panne peut n'être que passagère — sur
  /// iOS, le trousseau est illisible tant que le téléphone n'a pas été
  /// déverrouillé une fois après un redémarrage, et l'app peut être lancée en
  /// arrière-plan à ce moment-là. Effacer la session là déconnecterait pour de
  /// bon un élève qui n'avait rien perdu. Si l'entrée est vraiment morte, la
  /// prochaine connexion la remplace.
  Future<String?> _readSession() async {
    try {
      return await kpbFlutterSecureStorage.read(key: _sessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() =>
      kpbFlutterSecureStorage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      kpbFlutterSecureStorage.write(
        key: _sessionKey,
        value: persistSessionString,
      );
}
