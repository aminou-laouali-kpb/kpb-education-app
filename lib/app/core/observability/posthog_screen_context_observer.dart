import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Super propriété PostHog qui porte l'écran Flutter courant.
const kPosthogScreenProperty = 'kpb_screen';

/// Tient à jour [kPosthogScreenProperty] avec la route Flutter affichée.
///
/// POURQUOI. Les événements captés par le SDK NATIF — `$rageclick`, le cycle de
/// vie — ne voient qu'une seule vue native, celle de Flutter : leur
/// `$screen_name` vaut « Flutter » partout. En octobre 2026, 1 100 rage clicks
/// sur 30 jours (20 % des comptes) étaient ainsi impossibles à situer sans
/// reconstituer chaque session. Une super propriété, enregistrée via
/// `Posthog().register`, est transmise au natif et part avec TOUS les
/// événements suivants, natifs compris.
///
/// Même nommage que `PosthogObserver` (nom de la route, `/` écrit
/// `root ('/')`, seules les `PageRoute` comptent) : `kpb_screen` se lit donc
/// comme `$screen_name` des événements `$screen`.
class PosthogScreenContextObserver extends NavigatorObserver {
  PosthogScreenContextObserver({
    @visibleForTesting
    Future<void> Function(String key, Object value)? register,
  }) : _register = register ?? Posthog().register;

  final Future<void> Function(String key, Object value) _register;
  String? _current;

  /// Le nom publié pour [route], ou null quand la route ne compte pas.
  @visibleForTesting
  static String? screenNameFor(Route<dynamic>? route) {
    if (route is! PageRoute) return null;
    final name = route.settings.name?.trim();
    if (name == null || name.isEmpty) return null;
    return name == '/' ? "root ('/')" : name;
  }

  void _publish(Route<dynamic>? route) {
    final name = screenNameFor(route);
    if (name == null || name == _current) return;
    _current = name;
    try {
      unawaited(_register(kPosthogScreenProperty, name).catchError((_) {}));
    } catch (_) {
      // Une mesure ne casse jamais la navigation.
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _publish(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _publish(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _publish(previousRoute);

  // Pas de didRemove : `pushAndRemoveUntil` (le `offAll` de GetX) pousse
  // d'abord la nouvelle route, PUIS retire les anciennes — publier la route
  // « précédente » d'un retrait réécrirait un écran qui n'est plus affiché.
}
