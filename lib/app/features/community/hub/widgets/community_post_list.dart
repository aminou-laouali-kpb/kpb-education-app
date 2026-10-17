import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/models/community.dart';
import '../../../../core/services/community_store.dart';
import '../../../../core/ui/app_tokens.dart';
import '../../../../core/ui/components/kpb_async_view.dart';
import '../community_format.dart';
import '../community_list_controller.dart';
import 'community_widgets.dart';

/// Une liste de publications défilable, avec ses quatre états (squelette,
/// contenu, vide, erreur), le bandeau du cache, la page suivante au bas de la
/// liste et le tirer-pour-rafraîchir.
class CommunityPostList extends StatelessWidget {
  const CommunityPostList({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.empty,
    this.header = const <Widget>[],
    this.bottomPadding = 96,
  });

  final CommunityListController controller;
  final ValueChanged<CommunityPost> onOpen;

  /// L'état vide (déjà traduit).
  final Widget empty;

  /// Ce qui défile au-dessus de la liste (puces, hashtags…).
  final List<Widget> header;

  /// Réserve sous la dernière carte (bouton flottant).
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        CommunityStore.instance,
      ]),
      builder: (context, _) {
        final items = controller.visibleItems;
        final children = <Widget>[...header];
        if (items.isEmpty) {
          if (controller.loading || !controller.loadedOnce) {
            children.add(Semantics(
              label: 'async_loading'.tr,
              liveRegion: true,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
                child: CommunityFeedSkeleton(),
              ),
            ));
          } else if (controller.failure != null) {
            final offline =
                controller.failure!.failure == CommunityFailure.offline;
            children.add(CommunityInlineMessage(
              icon: offline ? Icons.wifi_off_rounded : Icons.error_outline,
              title: offline
                  ? 'comm_offline_title'.tr
                  : 'comm_load_failed_title'.tr,
              body: communityFailureMessage(controller.failure!),
              actionLabel: 'retry'.tr,
              onAction: controller.load,
            ));
          } else {
            children.add(empty);
          }
        } else {
          final cachedAt = controller.cachedAt;
          if (cachedAt != null) {
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
              child: KpbCacheStamp(
                updatedAt: cachedAt,
                offline: controller.showingStaleCache &&
                    controller.failure?.failure == CommunityFailure.offline,
                onRetry: controller.loading ? null : controller.load,
              ),
            ));
          }
          for (final post in items) {
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.md, 0, KpbSpacing.md, KpbSpacing.sm + 4),
              child: CommunityPostCard(
                key: ValueKey<String>('comm-post-${post.id}'),
                post: post,
                onTap: () => onOpen(post),
              ),
            ));
          }
          children.add(_Footer(controller: controller));
        }
        children.add(SizedBox(height: bottomPadding));

        return RefreshIndicator(
          onRefresh: controller.load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 600 &&
                  controller.hasMore &&
                  controller.moreFailure == null &&
                  !controller.loadingMore) {
                // Différé : une notification peut partir pendant la mise en
                // page, où notifier les écouteurs est interdit.
                Future.microtask(controller.loadMore);
              }
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: KpbSpacing.sm),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final CommunityListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return Semantics(
        label: 'async_loading'.tr,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
          child: CommunityFeedSkeleton(count: 1),
        ),
      );
    }
    final failure = controller.moreFailure;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          children: [
            Text(
              communityFailureMessage(failure),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KpbFontSize.sm,
                color: KpbColors.textSecondary,
              ),
            ),
            TextButton(
              onPressed: controller.loadMore,
              child: Text('comm_load_more'.tr),
            ),
          ],
        ),
      );
    }
    if (controller.hasMore) {
      return Center(
        child: TextButton(
          onPressed: controller.loadMore,
          child: Text('comm_load_more'.tr),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
