import 'dart:async';
import 'dart:developer' as dev;

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import '../config/app_routes.dart';
import '../navigation/app_navigation.dart';
import '../navigation/entry_wall.dart';

/// Bridges inbound `kpb://` deep links to in-app navigation.
///
/// The iOS URL scheme (`ios/Runner/Info.plist`) and the Android intent-filter
/// (`android/app/src/main/AndroidManifest.xml`) both declare `kpb`, but nothing
/// consumed the resulting URLs — so `xcrun simctl openurl booted kpb://…` only
/// foregrounded the app without navigating. This service subscribes to
/// [AppLinks.uriLinkStream] — which delivers both the launch URL (replayed to
/// its first listener) and every link received while running — and routes each
/// through [AppRoutes.normalizeExternalRoute], the same untrusted-input gate
/// used by push notifications and quick actions. Anything that does not resolve
/// to a registered route is ignored, never navigated.
///
/// supabase_flutter already runs its own [AppLinks] listener for OAuth
/// redirects (`io.supabase.kpbeducation://…`); the two coexist because each
/// filters for its own scheme (a supabase URI resolves to null here).
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  /// Begin listening. Safe to call once from `main()`; idempotent thereafter.
  ///
  /// [AppLinks.uriLinkStream] replays the cold-start launch URL to its first
  /// listener and also emits every link received while running, so one
  /// subscription covers both — no separate `getInitialLink()` call, which would
  /// route the launch URL a second time. Subscribing is deferred to the first
  /// frame so that replayed launch link lands only once the GetX navigator
  /// exists (before it, `Get.toNamed` would no-op).
  void initialize() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    _subscription ??= _appLinks.uriLinkStream.listen(
      handleUri,
      onError: (Object error, StackTrace stack) {
        dev.log('Deep link stream error: $error', stackTrace: stack);
      },
    );
  }

  /// Stop listening. Primarily for tests / hot-restart hygiene.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Routes [uri] to the matching screen when it maps to a supported route.
  ///
  /// Public so the widget test can exercise the end-to-end flow; production code
  /// reaches it only through the [AppLinks] callbacks wired in [initialize].
  void handleUri(Uri uri) {
    final route = resolveRoute(uri);
    if (route == null) {
      dev.log('Deep link ignored (unsupported): $uri');
      return;
    }
    // A bare `kpb://` (or `kpb:///`) resolves to home. The shell is already on
    // screen, so pushing the home route would only stack a second shell — skip.
    if (route == AppRoutes.home) return;
    // Un élève qui n'a ni compte ni mode invité reste sur l'écran d'entrée :
    // pousser une fiche par-dessus l'emmènerait sur un écran vide ou un 401.
    if (!hasPassedEntryWall()) {
      dev.log('Deep link ignored (entry wall not passed): $uri');
      return;
    }
    AppNavigation.toExternalRoute(route);
  }

  /// Maps a `kpb://` [uri] to a normalized, registered app route, or null when
  /// the link targets nothing navigable. Pure and side-effect free — visible for
  /// testing.
  ///
  /// Custom-scheme URIs place the first path element in [Uri.host]
  /// (`kpb://scholarships/42` → host `scholarships`, segments `[42]`), whereas
  /// the triple-slash form leaves the host empty (`kpb:///scholarships/42`).
  /// Both are folded into a single `/`-prefixed path before normalization; query
  /// strings and fragments are dropped.
  static String? resolveRoute(Uri uri) {
    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
    final path = segments.isEmpty ? AppRoutes.home : '/${segments.join('/')}';
    return AppRoutes.normalizeExternalRoute(path);
  }
}
