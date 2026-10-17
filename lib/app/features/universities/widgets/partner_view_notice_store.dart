import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// Ce que l'appareil retient de l'avis « vue Partenaires » de l'écran
/// Universités.
class PartnerViewNoticeMemory {
  const PartnerViewNoticeMemory({
    required this.dismissed,
    required this.allViewOpened,
  });

  /// L'élève a fermé l'avis complet.
  final bool dismissed;

  /// L'élève a ouvert au moins une fois la vue « Tous ».
  final bool allViewOpened;

  static const fresh =
      PartnerViewNoticeMemory(dismissed: false, allViewOpened: false);
}

/// Les deux drapeaux, LOCAUX (aucun envoi au serveur, aucune mesure). Interface
/// pour qu'un test puisse les poser — et les faire tomber en panne.
abstract interface class PartnerViewNoticeStore {
  /// Peut LEVER : l'écran montre alors l'avis complet (le cas d'une première
  /// ouverture), ce qui ne bloque rien.
  Future<PartnerViewNoticeMemory> read();

  Future<void> markDismissed();

  Future<void> markAllViewOpened();
}

/// Les drapeaux dans `SharedPreferences`, sous des clés versionnées : passer à
/// `_v2` remontrerait l'avis à tout le monde (texte refondu, par exemple).
class SharedPreferencesPartnerViewNoticeStore
    implements PartnerViewNoticeStore {
  const SharedPreferencesPartnerViewNoticeStore();

  static const dismissedKey =
      '${AppConfig.storageNamespace}.uni_partner_notice_dismissed_v1';
  static const allViewOpenedKey =
      '${AppConfig.storageNamespace}.uni_all_view_opened_v1';

  @override
  Future<PartnerViewNoticeMemory> read() async {
    final prefs = await SharedPreferences.getInstance();
    return PartnerViewNoticeMemory(
      dismissed: prefs.getBool(dismissedKey) ?? false,
      allViewOpened: prefs.getBool(allViewOpenedKey) ?? false,
    );
  }

  @override
  Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dismissedKey, true);
  }

  @override
  Future<void> markAllViewOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(allViewOpenedKey, true);
  }
}

/// Un magasin en mémoire, pour les tests.
class MemoryPartnerViewNoticeStore implements PartnerViewNoticeStore {
  MemoryPartnerViewNoticeStore({
    this.dismissed = false,
    this.allViewOpened = false,
    this.failReads = false,
  });

  bool dismissed;
  bool allViewOpened;
  bool failReads;

  @override
  Future<PartnerViewNoticeMemory> read() async {
    if (failReads) throw StateError('stockage indisponible');
    return PartnerViewNoticeMemory(
      dismissed: dismissed,
      allViewOpened: allViewOpened,
    );
  }

  @override
  Future<void> markDismissed() async => dismissed = true;

  @override
  Future<void> markAllViewOpened() async => allViewOpened = true;
}
