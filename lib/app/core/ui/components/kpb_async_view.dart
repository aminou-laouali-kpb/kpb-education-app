import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';
import '../kpb_theme_ext.dart';
import '../skeleton.dart';
import 'kpb_empty_state.dart';
import 'kpb_error_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbAsyncView — les quatre états d'un écran qui charge, au même endroit.
//
//   squelette (jamais un spinner seul) → contenu
//                                       → vide
//                                       → erreur, avec « Réessayer »
//   + contenu servi depuis le cache : bandeau « Mis à jour il y a X ».
//
// L'écran garde son état (contrôleur, setState…) et dit seulement dans quelle
// phase il est :
//
//   KpbAsyncView(
//     phase: KpbAsyncView.phaseOf(
//       loading: _loading,
//       hasData: _items != null,
//       isEmpty: _items?.isEmpty ?? true,
//       failed: _error != null,
//     ),
//     onRetry: _load,
//     updatedAt: _fromCache ? _cachedAt : null,
//     empty: KpbEmptyState(icon: …, title: …),
//     builder: (context) => ListView(…),
//   )
//
// Avec `refreshable: true`, les états hors contenu restent défilables : un
// RefreshIndicator placé AU-DESSUS de KpbAsyncView fonctionne dans tous les
// états.
// ─────────────────────────────────────────────────────────────────────────────

/// Phase d'un écran asynchrone.
enum KpbAsyncPhase { loading, content, empty, error }

class KpbAsyncView extends StatelessWidget {
  const KpbAsyncView({
    super.key,
    required this.phase,
    required this.builder,
    this.skeleton,
    this.empty,
    this.error,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.updatedAt,
    this.refreshable = false,
  });

  final KpbAsyncPhase phase;

  /// Le contenu, construit seulement en phase [KpbAsyncPhase.content].
  final WidgetBuilder builder;

  /// Squelette affiché pendant le premier chargement. Nul : [KpbSkeletonList].
  final Widget? skeleton;

  /// État vide. Nul : un [KpbEmptyState] générique.
  final Widget? empty;

  /// État d'erreur entièrement personnalisé (prioritaire sur [errorTitle],
  /// [errorMessage] et [onRetry]).
  final Widget? error;

  final String? errorTitle;
  final String? errorMessage;

  /// Relance le chargement : bouton « Réessayer » de l'erreur et du bandeau
  /// de cache.
  final VoidCallback? onRetry;

  /// Non nul : le contenu vient du cache, daté de cet instant. Un bandeau
  /// « Mis à jour il y a X » s'affiche au-dessus du contenu (KpbAsyncView
  /// doit alors recevoir une hauteur bornée, comme un `body` de Scaffold).
  final DateTime? updatedAt;

  /// Vrai : les états hors contenu sont posés dans une liste toujours
  /// défilable, pour qu'un RefreshIndicator parent reste utilisable.
  final bool refreshable;

  /// Phase usuelle à partir des signaux d'un écran.
  ///
  /// * des données non vides à montrer → contenu (même pendant un
  ///   rafraîchissement ou après un échec : on garde ce qu'on a) ;
  /// * sinon, un chargement en cours → squelette ;
  /// * sinon, un échec → erreur ;
  /// * sinon → vide.
  static KpbAsyncPhase phaseOf({
    required bool loading,
    required bool hasData,
    bool isEmpty = false,
    bool failed = false,
  }) {
    if (hasData && !isEmpty) return KpbAsyncPhase.content;
    if (loading) return KpbAsyncPhase.loading;
    if (failed) return KpbAsyncPhase.error;
    return KpbAsyncPhase.empty;
  }

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case KpbAsyncPhase.content:
        final content = builder(context);
        final at = updatedAt;
        if (at == null) return content;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KpbCacheStamp(updatedAt: at, onRetry: onRetry),
            Expanded(child: content),
          ],
        );
      case KpbAsyncPhase.loading:
        return _frame(
          Semantics(
            label: 'async_loading'.tr,
            liveRegion: true,
            child: skeleton ?? const KpbSkeletonList(),
          ),
          center: false,
        );
      case KpbAsyncPhase.empty:
        return _frame(
          empty ??
              KpbEmptyState(
                icon: Icons.inbox_outlined,
                title: 'async_empty_title'.tr,
              ),
        );
      case KpbAsyncPhase.error:
        return _frame(
          error ??
              KpbErrorState(
                title: errorTitle,
                subtitle: errorMessage,
                onRetry: onRetry,
              ),
        );
    }
  }

  Widget _frame(Widget state, {bool center = true}) {
    if (!refreshable) return state;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: center ? Center(child: state) : state,
          ),
        ],
      ),
    );
  }
}

/// Libellé « Mis à jour il y a X » (ou « Mis à jour à l'instant »).
String kpbUpdatedAgoLabel(DateTime updatedAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(updatedAt);
  final String ago;
  if (diff.inMinutes < 1) {
    ago = 'time_ago_just_now'.tr;
  } else if (diff.inMinutes < 60) {
    ago = 'time_ago_minutes'.trParams({'n': '${diff.inMinutes}'});
  } else if (diff.inHours < 24) {
    ago = 'time_ago_hours'.trParams({'n': '${diff.inHours}'});
  } else if (diff.inDays < 7) {
    ago = 'time_ago_days'.trParams({'n': '${diff.inDays}'});
  } else if (diff.inDays < 30) {
    ago = 'time_ago_weeks'.trParams({'n': '${diff.inDays ~/ 7}'});
  } else {
    ago = 'time_ago_months'.trParams({'n': '${diff.inDays ~/ 30}'});
  }
  return 'async_updated_ago'.trParams({'ago': ago});
}

/// Bandeau discret « Mis à jour il y a X » pour un contenu servi depuis le
/// cache. Utilisable seul (en tête d'une liste) ou via
/// [KpbAsyncView.updatedAt].
class KpbCacheStamp extends StatelessWidget {
  const KpbCacheStamp({
    super.key,
    required this.updatedAt,
    this.onRetry,
    this.now,
  });

  final DateTime updatedAt;

  /// Non nul : un lien « Réessayer » relance le chargement.
  final VoidCallback? onRetry;

  /// Horloge injectée (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final label = kpbUpdatedAgoLabel(updatedAt.toLocal(), now: now);
    return Container(
      key: const ValueKey<String>('kpb-cache-stamp'),
      color: c.mutedBg,
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.page,
        vertical: KpbSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 16, color: c.textSecondary),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('retry'.tr),
            ),
        ],
      ),
    );
  }
}
