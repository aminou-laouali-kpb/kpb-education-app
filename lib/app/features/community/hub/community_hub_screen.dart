import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/services/remote_feature_flags.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/kpb_haptics.dart';
import '../community_screen.dart';
import 'community_charter_sheet.dart';
import 'community_composer_screen.dart';
import 'community_format.dart';
import 'community_list_controller.dart';
import 'community_open.dart';
import 'community_search_screen.dart';
import 'widgets/community_post_list.dart';
import 'widgets/community_widgets.dart';

/// L'accueil de la communauté : « Pour toi », « Récents », « Sans réponse »,
/// puces de type, hashtags tendance, recherche, et « Poser une question ».
///
/// Drapeau distant fermé (ou compte non élève) : un écran d'attente honnête,
/// jamais un fil vide qui ferait croire à une communauté morte.
class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key, this.source = 'deep_link'});

  /// La porte d'entrée, pour la mesure.
  final String source;

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  final CommunityStore _store = CommunityStore.instance;
  late final TabController _tabs;
  CommunityPostType? _type;
  String? _hashtag;
  final Map<CommunityFeedTab, CommunityListController> _lists =
      <CommunityFeedTab, CommunityListController>{};
  List<CommunityHashtagSuggestion> _trending =
      const <CommunityHashtagSuggestion>[];
  bool _viewLogged = false;

  /// Les tendances, gardées pour la session (un appel par ouverture suffit).
  static List<CommunityHashtagSuggestion>? _trendingCache;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: CommunityFeedTab.values.length, vsync: this);
    _tabs.addListener(_onTab);
    _trending = _trendingCache ?? const <CommunityHashtagSuggestion>[];
    if (_store.enabled) _start();
  }

  void _start() {
    if (!_viewLogged) {
      _viewLogged = true;
      unawaited(
          AnalyticsService.instance.logCommunityViewed(source: widget.source));
    }
    unawaited(_store.loadMe());
    unawaited(_loadTrending());
    _ensureLoaded(_currentTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final list in _lists.values) {
      list.dispose();
    }
    super.dispose();
  }

  CommunityFeedTab get _currentTab => CommunityFeedTab.values[_tabs.index];

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    _ensureLoaded(_currentTab);
    setState(() {});
  }

  Future<void> _loadTrending() async {
    try {
      final items = await _store.api.suggestCommunityHashtags(limit: 8);
      _trendingCache = items;
      if (mounted) setState(() => _trending = items);
    } on CommunityException catch (error) {
      _store.noteFailure(error);
    }
  }

  CommunityListController _listFor(CommunityFeedTab tab) {
    return _lists.putIfAbsent(tab, () {
      final type = tab == CommunityFeedTab.unanswered ? null : _type;
      final hashtag = _hashtag;
      final filtered = type != null || hashtag != null;
      return CommunityListController(
        // Seule la première page du fil sans filtre va au disque : c'est
        // celle qu'on rouvre hors ligne.
        cacheKey: filtered
            ? null
            : 'feed::${_store.accountKey}::${_store.lang}::${tab.wire}',
        fetch: (cursor) async {
          final result = await _store.api.fetchCommunityFeed(
            tab: tab,
            type: type,
            hashtag: hashtag,
            cursor: cursor,
            lang: _store.lang,
          );
          return (page: result.page, raw: cursor == null ? result.raw : null);
        },
      );
    });
  }

  void _ensureLoaded(CommunityFeedTab tab) {
    final list = _listFor(tab);
    if (!list.loadedOnce && !list.loading) {
      unawaited(list.load());
      unawaited(AnalyticsService.instance.logCommunityFeedViewed(
        tab: tab.wire,
        postType: tab == CommunityFeedTab.unanswered ? null : _type?.wire,
        hasHashtag: _hashtag != null,
      ));
    }
  }

  void _resetLists() {
    final old = _lists.values.toList();
    _lists.clear();
    for (final list in old) {
      list.dispose();
    }
    _ensureLoaded(_currentTab);
  }

  void _setType(CommunityPostType? type) {
    if (type == _type) return;
    KpbHaptics.selection();
    setState(() {
      _type = type;
      _resetLists();
    });
  }

  void _setHashtag(String? tag) {
    if (tag == _hashtag) return;
    KpbHaptics.selection();
    setState(() {
      _hashtag = tag;
      _resetLists();
    });
  }

  Future<void> _compose() async {
    final created = await openCommunityComposer(context, source: 'hub');
    if (created == null || !mounted) return;
    // Visible tout de suite dans « Récents » (et en attente pour l'auteur).
    _listFor(CommunityFeedTab.recent).prepend(created);
    await openCommunityPost(context, post: created, source: 'composer');
  }

  Future<void> _menu(String action) async {
    switch (action) {
      case 'mine':
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => CommunityPostListScreen(
            title: 'comm_my_posts'.tr,
            emptyTitle: 'comm_my_posts_empty'.tr,
            source: 'my_posts',
            fetch: (cursor) async => (
              page: await _store.api
                  .fetchCommunityMyPosts(cursor: cursor, lang: _store.lang),
              raw: null,
            ),
          ),
        ));
      case 'following':
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => CommunityPostListScreen(
            title: 'comm_following'.tr,
            emptyTitle: 'comm_following_empty'.tr,
            source: 'following',
            fetch: (cursor) async => (
              page: await _store.api
                  .fetchCommunityFollowing(cursor: cursor, lang: _store.lang),
              raw: null,
            ),
          ),
        ));
      case 'charter':
        await _store.loadMe();
        if (!mounted) return;
        await showCommunityCharterSheet(context);
      case 'articles':
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const CommunityScreen(),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        RemoteFeatureFlags.instance.flagsVersion,
        _store,
      ]),
      builder: (context, _) {
        if (!_store.enabled) return const CommunityUnavailableScreen();
        if (!_viewLogged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _store.enabled) _start();
          });
        }
        return _buildHub(context);
      },
    );
  }

  Widget _buildHub(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('comm_title'.tr, style: KpbTextStyles.titleLg),
        actions: [
          IconButton(
            key: const ValueKey<String>('comm-hub-search'),
            tooltip: 'comm_search_action'.tr,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CommunitySearchScreen(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: const ValueKey<String>('comm-hub-menu'),
            tooltip: 'comm_menu_tooltip'.tr,
            onSelected: _menu,
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'mine', child: Text('comm_my_posts'.tr)),
              PopupMenuItem(
                  value: 'following', child: Text('comm_following'.tr)),
              PopupMenuItem(
                  value: 'charter', child: Text('comm_charter_title'.tr)),
              // L'ancien contenu (articles, groupe WhatsApp) reste
              // joignable là où il l'était : hors build MVP.
              if (!AppConfig.mvpOnly)
                PopupMenuItem(
                    value: 'articles', child: Text('comm_articles'.tr)),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final tab in CommunityFeedTab.values)
              Tab(
                key: ValueKey<String>('comm-tab-${tab.wire}'),
                text: communityTabLabel(tab),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('comm-hub-ask'),
        onPressed: _compose,
        icon: const Icon(Icons.edit_outlined),
        label: Text('comm_ask_question'.tr),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final tab in CommunityFeedTab.values) _buildTab(tab),
        ],
      ),
    );
  }

  Widget _buildTab(CommunityFeedTab tab) {
    final list = _listFor(tab);
    return CommunityPostList(
      key: PageStorageKey<String>('comm-feed-${tab.wire}'),
      controller: list,
      onOpen: (post) =>
          openCommunityPost(context, post: post, list: list, source: tab.wire),
      header: [
        _FilterHeader(
          showTypes: tab != CommunityFeedTab.unanswered,
          type: _type,
          hashtag: _hashtag,
          trending: _trending,
          onType: _setType,
          onHashtag: _setHashtag,
          intro:
              tab == CommunityFeedTab.forYou ? 'comm_for_you_intro'.tr : null,
        )
      ],
      empty: _emptyFor(tab),
    );
  }

  Widget _emptyFor(CommunityFeedTab tab) {
    final filtered = _type != null || _hashtag != null;
    if (filtered) {
      return CommunityInlineMessage(
        icon: Icons.filter_alt_off_outlined,
        title: 'comm_empty_filtered_title'.tr,
        actionLabel: 'comm_clear_filters'.tr,
        onAction: () => setState(() {
          _type = null;
          _hashtag = null;
          _resetLists();
        }),
      );
    }
    return switch (tab) {
      CommunityFeedTab.unanswered => CommunityInlineMessage(
          icon: Icons.task_alt_rounded,
          title: 'comm_empty_unanswered_title'.tr,
          body: 'comm_empty_unanswered_body'.tr,
        ),
      _ => CommunityInlineMessage(
          icon: Icons.forum_outlined,
          title: 'comm_empty_title'.tr,
          body: 'comm_empty_body'.tr,
          actionLabel: 'comm_ask_question'.tr,
          onAction: _compose,
        ),
    };
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.showTypes,
    required this.type,
    required this.hashtag,
    required this.trending,
    required this.onType,
    required this.onHashtag,
    this.intro,
  });

  final bool showTypes;
  final CommunityPostType? type;
  final String? hashtag;
  final List<CommunityHashtagSuggestion> trending;
  final ValueChanged<CommunityPostType?> onType;
  final ValueChanged<String?> onHashtag;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final tags = <CommunityHashtagSuggestion>[
      if (hashtag != null && !trending.any((t) => t.tag == hashtag))
        CommunityHashtagSuggestion(tag: hashtag!, display: hashtag!),
      ...trending,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.md, 0, KpbSpacing.md, KpbSpacing.sm),
              child: Text(intro!, style: KpbTextStyles.caption),
            ),
          if (showTypes)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.md),
              child: Row(
                children: [
                  ChoiceChip(
                    key: const ValueKey<String>('comm-type-all'),
                    selected: type == null,
                    label: Text('comm_type_all'.tr),
                    onSelected: (_) => onType(null),
                  ),
                  for (final t in CommunityPostType.values) ...[
                    const SizedBox(width: KpbSpacing.sm),
                    ChoiceChip(
                      key: ValueKey<String>('comm-type-${t.wire}'),
                      selected: type == t,
                      avatar: Icon(communityPostTypeIcon(t), size: 16),
                      label: Text(communityPostTypeLabel(t)),
                      onSelected: (_) => onType(type == t ? null : t),
                    ),
                  ],
                ],
              ),
            ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.md),
              child: Text('comm_trending'.tr, style: KpbTextStyles.caption),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.md),
              child: Row(
                children: [
                  for (final tag in tags) ...[
                    FilterChip(
                      key: ValueKey<String>('comm-tag-${tag.tag}'),
                      selected: hashtag == tag.tag,
                      label: Text('#${tag.display}'),
                      tooltip: hashtag == tag.tag
                          ? 'comm_hashtag_clear'.trParams({'tag': tag.display})
                          : 'comm_hashtag_filter'
                              .trParams({'tag': tag.display}),
                      onSelected: (_) =>
                          onHashtag(hashtag == tag.tag ? null : tag.tag),
                    ),
                    const SizedBox(width: KpbSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une liste simple de publications (mes publications, discussions suivies).
class CommunityPostListScreen extends StatefulWidget {
  const CommunityPostListScreen({
    super.key,
    required this.title,
    required this.emptyTitle,
    required this.fetch,
    required this.source,
  });

  final String title;
  final String emptyTitle;
  final CommunityPageFetcher fetch;
  final String source;

  @override
  State<CommunityPostListScreen> createState() =>
      _CommunityPostListScreenState();
}

class _CommunityPostListScreenState extends State<CommunityPostListScreen> {
  late final CommunityListController _list =
      CommunityListController(fetch: widget.fetch);

  @override
  void initState() {
    super.initState();
    unawaited(_list.load());
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title, style: KpbTextStyles.titleLg),
      ),
      body: CommunityPostList(
        controller: _list,
        bottomPadding: KpbSpacing.lg,
        onOpen: (post) => openCommunityPost(context,
            post: post, list: _list, source: widget.source),
        empty: CommunityInlineMessage(
          icon: Icons.inbox_outlined,
          title: widget.emptyTitle,
        ),
      ),
    );
  }
}

/// Drapeau fermé, compte non élève, ou serveur qui a coupé la fonction :
/// un message honnête et un retour.
class CommunityUnavailableScreen extends StatelessWidget {
  const CommunityUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('comm_title'.tr, style: KpbTextStyles.titleLg),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: CommunityInlineMessage(
            icon: Icons.forum_outlined,
            title: 'comm_unavailable_title'.tr,
            body: 'comm_unavailable_body'.tr,
          ),
        ),
      ),
    );
  }
}
