import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_async_view.dart';
import '../../../core/ui/components/kpb_toast.dart';
import '../../../core/ui/kpb_haptics.dart';
import '../../../core/utils/community_mention_tokens.dart';
import 'community_charter_sheet.dart';
import 'community_composer_screen.dart';
import 'community_entity_navigation.dart';
import 'community_format.dart';
import 'community_hub_screen.dart';
import 'community_member_screen.dart';
import 'community_mention_field.dart';
import 'community_report_sheet.dart';
import 'community_search_screen.dart';
import 'widgets/community_widgets.dart';

/// Ce que le détail rend à la liste qui l'a ouvert.
@immutable
class CommunityPostOutcome {
  const CommunityPostOutcome({this.post, this.deleted = false});

  /// La publication à jour (compteurs, « utile », suivi), ou `null`.
  final CommunityPost? post;
  final bool deleted;
}

/// Une discussion : la publication, les entités citées (cartes cliquables
/// vers leurs fiches), la réponse vérifiée épinglée en tête, les réponses,
/// « utile », suivre, répondre, et le menu ⋯ (signaler, bloquer, modifier,
/// supprimer).
class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.source = 'feed',
  });

  final String postId;
  final CommunityPost? initialPost;
  final String source;

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final CommunityStore _store = CommunityStore.instance;
  CommunityPost? _post;
  List<CommunityReply> _replies = <CommunityReply>[];
  String? _repliesCursor;
  bool _loading = true;
  bool _loadingMore = false;
  CommunityException? _failure;
  DateTime? _cachedAt;
  bool _deleted = false;
  bool _logged = false;

  final CommunityMentionController _reply = CommunityMentionController();
  final FocusNode _replyFocus = FocusNode();
  bool _sendingReply = false;

  String get _cacheKey =>
      'post::${_store.accountKey}::${_store.lang}::${widget.postId}';

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _reply.addListener(() => setState(() {}));
    _store.addListener(_onStore);
    if (_store.enabled) unawaited(_load());
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    if (_post == null || !_post!.isDetail) {
      final cached = await _store.cache.read(_cacheKey);
      final detail =
          cached == null ? null : CommunityPostDetail.fromJson(cached.json);
      if (detail != null && mounted) {
        setState(() {
          _post = detail.post;
          _replies = List<CommunityReply>.of(detail.replies.items);
          _repliesCursor = null;
          _cachedAt = cached!.fetchedAt;
        });
      }
    }
    try {
      final result =
          await _store.api.fetchCommunityPost(widget.postId, lang: _store.lang);
      if (!mounted) return;
      setState(() {
        _post = result.detail.post;
        _replies = List<CommunityReply>.of(result.detail.replies.items);
        _repliesCursor = result.detail.replies.nextCursor;
        _cachedAt = null;
        _loading = false;
      });
      unawaited(_store.cache.writePost(_cacheKey, result.raw));
      _logOpen();
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      setState(() {
        _failure = error;
        _loading = false;
      });
    }
  }

  void _logOpen() {
    final post = _post;
    if (_logged || post == null) return;
    _logged = true;
    unawaited(AnalyticsService.instance.logCommunityPostOpened(
      source: widget.source,
      postType: post.type.wire,
      hasVerified: post.hasVerifiedAnswer,
    ));
  }

  Future<void> _loadMoreReplies() async {
    final cursor = _repliesCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _store.api.fetchCommunityReplies(
        widget.postId,
        cursor: cursor,
        lang: _store.lang,
      );
      if (!mounted) return;
      final known = _replies.map((r) => r.id).toSet();
      setState(() {
        _replies = <CommunityReply>[
          ..._replies,
          ...page.items.where((r) => !known.contains(r.id)),
        ];
        _repliesCursor = page.nextCursor;
      });
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      KpbToast.error(communityFailureMessage(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _close() {
    Navigator.of(context).pop(
      CommunityPostOutcome(post: _deleted ? null : _post, deleted: _deleted),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _togglePostHelpful() async {
    final post = _post;
    if (post == null) return;
    if (post.viewer.isAuthor) {
      KpbToast.info('comm_err_react_own'.tr);
      return;
    }
    if (!await ensureCommunityCanWrite(context)) return;
    final wanted = !post.viewer.hasMarkedHelpful;
    // Optimiste : l'élève voit sa réaction tout de suite ; le serveur fait foi.
    setState(() => _post = post.copyWith(
          helpfulCount:
              (post.helpfulCount + (wanted ? 1 : -1)).clamp(0, 1 << 30),
          viewer: post.viewer.copyWith(hasMarkedHelpful: wanted),
        ));
    unawaited(KpbHaptics.selection());
    try {
      final result = await _store.api.setCommunityHelpful(
        isReply: false,
        id: post.id,
        helpful: wanted,
      );
      if (!mounted) return;
      setState(() => _post = _post!.copyWith(
            helpfulCount: result.helpfulCount,
            viewer: _post!.viewer.copyWith(
              hasMarkedHelpful: result.hasMarkedHelpful,
            ),
          ));
      unawaited(AnalyticsService.instance
          .logCommunityHelpfulToggled(target: 'post', enabled: wanted));
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      setState(() => _post = post);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _toggleReplyHelpful(CommunityReply reply) async {
    if (reply.viewer.isAuthor) {
      KpbToast.info('comm_err_react_own'.tr);
      return;
    }
    if (!await ensureCommunityCanWrite(context)) return;
    final wanted = !reply.viewer.hasMarkedHelpful;
    void put(CommunityReply next) => setState(() {
          _replies = [for (final r in _replies) r.id == next.id ? next : r];
        });
    put(reply.copyWith(
      helpfulCount: (reply.helpfulCount + (wanted ? 1 : -1)).clamp(0, 1 << 30),
      viewer: reply.viewer.copyWith(hasMarkedHelpful: wanted),
    ));
    unawaited(KpbHaptics.selection());
    try {
      final result = await _store.api.setCommunityHelpful(
        isReply: true,
        id: reply.id,
        helpful: wanted,
      );
      if (!mounted) return;
      put(reply.copyWith(
        helpfulCount: result.helpfulCount,
        viewer:
            reply.viewer.copyWith(hasMarkedHelpful: result.hasMarkedHelpful),
      ));
      unawaited(AnalyticsService.instance
          .logCommunityHelpfulToggled(target: 'reply', enabled: wanted));
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      put(reply);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _toggleFollow() async {
    final post = _post;
    if (post == null) return;
    final wanted = !post.viewer.isFollowing;
    setState(() => _post =
        post.copyWith(viewer: post.viewer.copyWith(isFollowing: wanted)));
    unawaited(KpbHaptics.selection());
    try {
      final following =
          await _store.api.setCommunityFollow(postId: post.id, follow: wanted);
      if (!mounted) return;
      setState(() => _post = _post!
          .copyWith(viewer: _post!.viewer.copyWith(isFollowing: following)));
      unawaited(AnalyticsService.instance
          .logCommunityFollowToggled(enabled: following));
      KpbToast.info(
        following ? 'comm_follow_on'.tr : 'comm_follow_off'.tr,
      );
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      setState(() => _post = post);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _sendReply() async {
    final post = _post;
    final body = _reply.serializedText.trim();
    if (post == null || _sendingReply) return;
    if (_reply.text.trim().length < CommunityLimitsSpec.replyBodyMin) return;
    if (!await ensureCommunityCanWrite(context)) return;
    setState(() => _sendingReply = true);
    try {
      final reply = await _store.api.createCommunityReply(
        postId: post.id,
        body: body,
        lang: _store.lang,
      );
      if (!mounted) return;
      final pending = reply.moderation != null;
      unawaited(AnalyticsService.instance.logCommunityReplyCreated(
        pendingReview: pending,
        mentionCount: _reply.draft.distinctMentionCount,
      ));
      setState(() {
        _replies = <CommunityReply>[..._replies, reply];
        if (!pending) {
          _post = post.copyWith(
            replyCount: post.replyCount + 1,
            viewer: post.viewer.copyWith(isFollowing: true),
          );
        }
        _reply.clear();
        _sendingReply = false;
      });
      FocusScope.of(context).unfocus();
      if (pending) {
        await showCommunityPendingReviewSheet(context);
      } else {
        unawaited(KpbHaptics.success());
        KpbToast.success('comm_reply_sent'.tr);
      }
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      unawaited(AnalyticsService.instance.logCommunityPostFailed(
        reason: error.failure.name,
        target: 'reply',
      ));
      if (!mounted) return;
      setState(() => _sendingReply = false);
      if (error.failure == CommunityFailure.charterRequired) {
        await _store.invalidateCharter();
        if (!mounted) return;
        if (await showCommunityCharterSheet(context)) unawaited(_sendReply());
        return;
      }
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) return;
    final updated = await openCommunityComposer(
      context,
      source: 'edit',
      editing: post,
    );
    if (updated != null && mounted) {
      setState(() => _post = updated);
      unawaited(_load());
    }
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) return;
    final ok = await _confirmDelete('comm_delete_post_title'.tr);
    if (!ok) return;
    try {
      await _store.api.deleteCommunityPost(post.id);
      _store.invalidateCounts(post.mentions.map((m) => m.ref));
      if (!mounted) return;
      KpbToast.success('comm_deleted'.tr);
      _deleted = true;
      _close();
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _editReply(CommunityReply reply) async {
    final controller = CommunityMentionController(initialBody: reply.body);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('comm_edit_reply_title'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: CommunityLimitsSpec.replyBodyMax,
                ),
                CommunitySuggestionPanel(controller: controller),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.serializedText),
            child: Text('comm_composer_save'.tr),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null ||
        saved.trim().length < CommunityLimitsSpec.replyBodyMin) {
      return;
    }
    if (!mounted || !await ensureCommunityCanWrite(context)) return;
    try {
      final updated = await _store.api.updateCommunityReply(
        replyId: reply.id,
        body: saved,
        lang: _store.lang,
      );
      if (!mounted) return;
      setState(() {
        _replies = [for (final r in _replies) r.id == reply.id ? updated : r];
      });
      if (updated.moderation != null) {
        await showCommunityPendingReviewSheet(context);
      } else {
        KpbToast.success('comm_reply_updated'.tr);
      }
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<void> _deleteReply(CommunityReply reply) async {
    final ok = await _confirmDelete('comm_delete_reply_title'.tr);
    if (!ok) return;
    try {
      await _store.api.deleteCommunityReply(reply.id);
      if (!mounted) return;
      final post = _post;
      setState(() {
        _replies = _replies.where((r) => r.id != reply.id).toList();
        if (post != null && reply.moderation == null) {
          _post = post.copyWith(
              replyCount: (post.replyCount - 1).clamp(0, 1 << 30));
        }
      });
      KpbToast.success('comm_deleted'.tr);
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  Future<bool> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text('comm_delete_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            key: const ValueKey<String>('comm-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('comm_delete_action'.tr),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _block(CommunityAuthor author) async {
    final blocked = await confirmAndBlockCommunityMember(context, author);
    if (!blocked || !mounted) return;
    if (_post?.author.memberId == author.memberId) {
      // On ne voit plus ses contenus : la discussion se referme.
      _close();
      return;
    }
    setState(() {});
  }

  void _openMember(CommunityAuthor author) {
    final id = author.memberId;
    if (id == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => CommunityMemberScreen(memberId: id),
    ));
  }

  void _openHashtag(CommunityHashtag hashtag) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) =>
          CommunitySearchScreen(initialQuery: '#${hashtag.display}'),
    ));
  }

  // ── Menus ────────────────────────────────────────────────────────────────

  Future<void> _showPostMenu() async {
    final post = _post;
    if (post == null) return;
    final action = await _showMenuSheet(<_MenuEntry>[
      if (post.viewer.canEditAt(DateTime.now()))
        _MenuEntry('edit', Icons.edit_outlined, 'comm_menu_edit'.tr),
      if (post.viewer.isAuthor || post.viewer.canDelete)
        _MenuEntry(
            'delete', Icons.delete_outline_rounded, 'comm_menu_delete'.tr,
            destructive: true),
      if (!post.viewer.isAuthor) ...[
        _MenuEntry('report', Icons.flag_outlined, 'comm_menu_report_post'.tr),
        if (post.author.memberId != null && !post.author.isTeam) ...[
          _MenuEntry('report_member', Icons.person_off_outlined,
              'comm_menu_report_member'.tr),
          _MenuEntry('block', Icons.block_rounded,
              'comm_menu_block'.trParams({'name': post.author.displayName}),
              destructive: true),
        ],
      ],
    ]);
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editPost();
      case 'delete':
        await _deletePost();
      case 'report':
        await showCommunityReportSheet(context,
            target: CommunityReportTarget.post, targetId: post.id);
      case 'report_member':
        await showCommunityReportSheet(context,
            target: CommunityReportTarget.member,
            targetId: post.author.memberId!);
      case 'block':
        await _block(post.author);
    }
  }

  Future<void> _showReplyMenu(CommunityReply reply) async {
    final action = await _showMenuSheet(<_MenuEntry>[
      if (reply.viewer.canEditAt(DateTime.now()))
        _MenuEntry('edit', Icons.edit_outlined, 'comm_menu_edit'.tr),
      if (reply.viewer.isAuthor || reply.viewer.canDelete)
        _MenuEntry(
            'delete', Icons.delete_outline_rounded, 'comm_menu_delete'.tr,
            destructive: true),
      if (!reply.viewer.isAuthor) ...[
        _MenuEntry('report', Icons.flag_outlined, 'comm_menu_report_reply'.tr),
        if (reply.author.memberId != null && !reply.author.isTeam)
          _MenuEntry('block', Icons.block_rounded,
              'comm_menu_block'.trParams({'name': reply.author.displayName}),
              destructive: true),
      ],
    ]);
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editReply(reply);
      case 'delete':
        await _deleteReply(reply);
      case 'report':
        await showCommunityReportSheet(context,
            target: CommunityReportTarget.reply, targetId: reply.id);
      case 'block':
        await _block(reply.author);
    }
  }

  Future<String?> _showMenuSheet(List<_MenuEntry> entries) {
    if (entries.isEmpty) return Future.value();
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: KpbColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries)
                ListTile(
                  key: ValueKey<String>('comm-menu-${entry.id}'),
                  leading: Icon(entry.icon,
                      color: entry.destructive
                          ? KpbColors.error
                          : KpbColors.textSecondary),
                  title: Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: KpbFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: entry.destructive
                          ? KpbColors.error
                          : KpbColors.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(entry.id),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rendu ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Lien profond ou notification avec le drapeau fermé : message honnête.
    if (!_store.enabled) return const CommunityUnavailableScreen();
    final post = _post;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: KpbColors.canvas,
        appBar: AppBar(
          backgroundColor: KpbColors.canvas,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'a11y_back'.tr,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _close,
          ),
          title: Text(
            post == null
                ? 'comm_discussion'.tr
                : communityPostTypeLabel(post.type),
            style: KpbTextStyles.titleLg,
          ),
          actions: [
            if (post != null && post.moderation == null)
              IconButton(
                key: const ValueKey<String>('comm-post-follow'),
                tooltip: post.viewer.isFollowing
                    ? 'comm_unfollow_tooltip'.tr
                    : 'comm_follow_tooltip'.tr,
                isSelected: post.viewer.isFollowing,
                icon: Icon(post.viewer.isFollowing
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded),
                onPressed: _toggleFollow,
              ),
            if (post != null)
              IconButton(
                key: const ValueKey<String>('comm-post-menu'),
                tooltip: 'comm_menu_tooltip'.tr,
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: _showPostMenu,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(child: _buildBody()),
              if (post != null && post.isDetail) _buildReplyBar(post),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final post = _post;
    if (post == null || (!post.isDetail && _loading)) {
      if (_failure != null && post == null) {
        final notFound = _failure!.failure == CommunityFailure.notFound;
        return CommunityInlineMessage(
          icon: notFound ? Icons.search_off_rounded : Icons.wifi_off_rounded,
          title:
              notFound ? 'comm_err_not_found'.tr : 'comm_load_failed_title'.tr,
          body: notFound ? null : communityFailureMessage(_failure!),
          actionLabel: notFound ? null : 'retry'.tr,
          onAction: notFound ? null : _load,
        );
      }
      return const SingleChildScrollView(
        padding: EdgeInsets.all(KpbSpacing.md),
        child: CommunityFeedSkeleton(count: 2),
      );
    }
    final blocked = _store.isBlockedLocally(post.author.memberId);
    final replies = _replies
        .where((r) => !_store.isBlockedLocally(r.author.memberId))
        .toList(growable: false);
    // La réponse vérifiée en tête (le serveur l'y met déjà ; on le garantit).
    replies.sort((a, b) {
      if (a.isVerified == b.isVerified) return 0;
      return a.isVerified ? -1 : 1;
    });
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
        children: [
          if (_cachedAt != null)
            KpbCacheStamp(
              updatedAt: _cachedAt!,
              offline: _failure?.failure == CommunityFailure.offline,
              onRetry: _loading ? null : _load,
            ),
          if (blocked)
            CommunityInlineMessage(
              icon: Icons.block_rounded,
              title: 'comm_blocked_content'.tr,
            )
          else
            _PostHeader(
              post: post,
              onMember: _openMember,
              onMention: openCommunityEntity,
              onHashtag: _openHashtag,
              onHelpful: _togglePostHelpful,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KpbSpacing.md, KpbSpacing.md, KpbSpacing.md, KpbSpacing.sm),
            child: Semantics(
              header: true,
              child: Text(
                communityReplyCountLabel(post.replyCount),
                style: KpbTextStyles.titleMd,
              ),
            ),
          ),
          if (replies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.md),
              child: Text(
                post.viewer.isAuthor
                    ? 'comm_no_replies_author'.tr
                    : 'comm_no_replies'.tr,
                style: KpbTextStyles.bodySm,
              ),
            ),
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.md, 0, KpbSpacing.md, KpbSpacing.sm + 2),
              child: _ReplyTile(
                key: ValueKey<String>('comm-reply-${reply.id}'),
                reply: reply,
                onMember: _openMember,
                onMention: openCommunityEntity,
                onHashtag: _openHashtag,
                onHelpful: () => _toggleReplyHelpful(reply),
                onMenu: () => _showReplyMenu(reply),
              ),
            ),
          if (_repliesCursor != null)
            Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(KpbSpacing.sm),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _loadMoreReplies,
                      child: Text('comm_load_more_replies'.tr),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBar(CommunityPost post) {
    final me = _store.me;
    if (me?.restriction != null) {
      return _BarNotice(
        icon: Icons.lock_clock_outlined,
        text: me!.restriction!.isBan
            ? 'comm_err_banned'.tr
            : 'comm_err_read_only'.tr,
      );
    }
    if (post.moderation != null) {
      return _BarNotice(
        icon: Icons.hourglass_top_rounded,
        text: 'comm_err_post_not_open'.tr,
      );
    }
    if (_store.isBlockedLocally(post.author.memberId)) {
      return const SizedBox.shrink();
    }
    final canSend = !_sendingReply &&
        _reply.text.trim().length >= CommunityLimitsSpec.replyBodyMin &&
        _reply.serializedText.length <= CommunityLimitsSpec.replyBodyMax;
    return Container(
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
          KpbSpacing.md, KpbSpacing.sm, KpbSpacing.sm, KpbSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.3,
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: CommunitySuggestionPanel(controller: _reply),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('comm-reply-field'),
                  controller: _reply,
                  focusNode: _replyFocus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'comm_reply_hint'.tr,
                    isDense: true,
                  ),
                  onTap: () async {
                    // La charte s'affiche AVANT la première réponse, pas après
                    // un message long tapé pour rien.
                    if (_store.charterRequired) {
                      _replyFocus.unfocus();
                      final ok = await ensureCommunityCanWrite(context);
                      if (ok && mounted) _replyFocus.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey<String>('comm-reply-send'),
                tooltip: 'comm_reply_send'.tr,
                onPressed: canSend ? _sendReply : null,
                icon: _sendingReply
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                color: KpbColors.actionPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.id, this.icon, this.label, {this.destructive = false});

  final String id;
  final IconData icon;
  final String label;
  final bool destructive;
}

class _BarNotice extends StatelessWidget {
  const _BarNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: KpbColors.surfaceMuted,
      padding: const EdgeInsets.all(KpbSpacing.sm + 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KpbColors.textSecondary),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: KpbFontSize.sm,
                color: KpbColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onMember,
    required this.onMention,
    required this.onHashtag,
    required this.onHelpful,
  });

  final CommunityPost post;
  final ValueChanged<CommunityAuthor> onMember;
  final ValueChanged<CommunityMention> onMention;
  final ValueChanged<CommunityHashtag> onHashtag;
  final VoidCallback onHelpful;

  @override
  Widget build(BuildContext context) {
    final segments = post.segments ??
        (post.body == null
            ? const <CommunitySegment>[]
            : parseCommunityBody(post.body!));
    final edited = post.editedAt != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          KpbSpacing.md, KpbSpacing.sm, KpbSpacing.md, 0),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CommunityTypeChip(type: post.type),
              if (post.hasVerifiedAnswer) const CommunityVerifiedPill(),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          Semantics(
            header: true,
            child: Text(post.title, style: KpbTextStyles.title),
          ),
          const SizedBox(height: KpbSpacing.sm + 2),
          CommunityAuthorLine(
            author: post.author,
            trailing: [
              communityRelativeTime(post.createdAt),
              if (edited) 'comm_edited'.tr,
            ].where((s) => s.isNotEmpty).join(' · '),
            onTap: post.author.memberId == null || post.viewer.isAuthor
                ? null
                : () => onMember(post.author),
          ),
          if (post.moderation != null) ...[
            const SizedBox(height: KpbSpacing.sm + 2),
            CommunityModerationNotice(moderation: post.moderation!),
          ],
          const SizedBox(height: KpbSpacing.sm + 4),
          CommunitySegmentsText(
            segments: segments,
            onMention: onMention,
            onHashtag: onHashtag,
          ),
          if (post.mentions.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            Text('comm_mentioned_title'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.sm),
            for (final mention in post.mentions)
              Padding(
                padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
                child: _EntityCard(mention: mention, onTap: onMention),
              ),
          ],
          const SizedBox(height: KpbSpacing.sm),
          _HelpfulButton(
            count: post.helpfulCount,
            marked: post.viewer.hasMarkedHelpful,
            enabled: !post.viewer.isAuthor && post.moderation == null,
            onTap: onHelpful,
          ),
        ],
      ),
    );
  }
}

/// Carte cliquable d'une entité citée : ouvre sa fiche.
class _EntityCard extends StatelessWidget {
  const _EntityCard({required this.mention, required this.onTap});

  final CommunityMention mention;
  final ValueChanged<CommunityMention> onTap;

  @override
  Widget build(BuildContext context) {
    final type = communityEntityTypeLabel(mention.type);
    return Semantics(
      button: true,
      label: 'comm_a11y_open_entity'
          .trParams({'type': type, 'label': mention.label}),
      excludeSemantics: true,
      child: Material(
        color: KpbColors.actionPrimarySoft,
        borderRadius: KpbRadius.smBr,
        child: InkWell(
          key: ValueKey<String>(
              'comm-entity-${mention.type.wire}-${mention.id}'),
          onTap: () => onTap(mention),
          borderRadius: KpbRadius.smBr,
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.sm + 4),
            child: Row(
              children: [
                Icon(communityEntityIcon(mention.type),
                    color: KpbColors.actionPrimary),
                const SizedBox(width: KpbSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mention.label,
                        style: const TextStyle(
                          fontSize: KpbFontSize.sm,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.textPrimary,
                        ),
                      ),
                      Text(
                        'comm_entity_open'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          color: KpbColors.actionPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: KpbColors.actionPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({
    required this.count,
    required this.marked,
    required this.enabled,
    required this.onTap,
  });

  final int count;
  final bool marked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 0
        ? '${'comm_helpful_action'.tr} · $count'
        : 'comm_helpful_action'.tr;
    final semantics = [
      marked ? 'comm_a11y_helpful_marked'.tr : 'comm_helpful_action'.tr,
      if (count > 0) communityHelpfulCountLabel(count),
    ].join(', ');
    return Semantics(
      button: true,
      toggled: marked,
      enabled: enabled,
      label: semantics,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              marked ? KpbColors.actionPrimary : KpbColors.textSecondary,
          backgroundColor:
              marked ? KpbColors.actionPrimarySoft : Colors.transparent,
          side: BorderSide(
            color: marked ? KpbColors.actionPrimary : KpbColors.border,
          ),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onTap,
        icon: Icon(
          marked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
          size: 16,
        ),
        label: Text(label),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    super.key,
    required this.reply,
    required this.onMember,
    required this.onMention,
    required this.onHashtag,
    required this.onHelpful,
    required this.onMenu,
  });

  final CommunityReply reply;
  final ValueChanged<CommunityAuthor> onMember;
  final ValueChanged<CommunityMention> onMention;
  final ValueChanged<CommunityHashtag> onHashtag;
  final VoidCallback onHelpful;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final verified = reply.isVerified;
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.sm + 6),
      decoration: BoxDecoration(
        color: verified ? KpbColors.successLight : KpbColors.surface,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(
          color: verified
              ? KpbColors.success.withValues(alpha: 0.4)
              : KpbColors.border,
          width: verified ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (verified) ...[
            const CommunityVerifiedPill(long: true),
            const SizedBox(height: KpbSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CommunityAuthorLine(
                  author: reply.author,
                  trailing: [
                    communityRelativeTime(reply.createdAt),
                    if (reply.editedAt != null) 'comm_edited'.tr,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  onTap: reply.author.memberId == null || reply.viewer.isAuthor
                      ? null
                      : () => onMember(reply.author),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: 'comm_menu_tooltip'.tr,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onPressed: onMenu,
                ),
              ),
            ],
          ),
          if (reply.author.isAssistant || reply.assistant != null) ...[
            const SizedBox(height: KpbSpacing.sm),
            CommunityAssistantNotice(
                sourceVerifiedAt: reply.assistant?.sourceVerifiedAt),
          ],
          if (reply.moderation != null) ...[
            const SizedBox(height: KpbSpacing.sm),
            CommunityModerationNotice(moderation: reply.moderation!),
          ],
          const SizedBox(height: KpbSpacing.sm),
          CommunitySegmentsText(
            segments: reply.segments,
            onMention: onMention,
            onHashtag: onHashtag,
            style: const TextStyle(
              fontSize: KpbFontSize.md,
              height: 1.5,
              color: KpbColors.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          _HelpfulButton(
            count: reply.helpfulCount,
            marked: reply.viewer.hasMarkedHelpful,
            enabled: !reply.viewer.isAuthor && reply.moderation == null,
            onTap: onHelpful,
          ),
        ],
      ),
    );
  }
}
