import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import 'community_list_controller.dart';
import 'community_open.dart';
import 'widgets/community_post_list.dart';
import 'widgets/community_widgets.dart';

/// Recherche plein texte (2 à 100 caractères) ; `#tag` cherche un hashtag
/// exact. La mesure ne garde que le nombre de résultats, jamais le texte.
class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  late final TextEditingController _query;
  CommunityListController? _results;
  String? _submitted;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery ?? '');
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.length >= 2) _submit(initial);
  }

  @override
  void dispose() {
    _query.dispose();
    _results?.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final q = raw.trim();
    if (q.length < 2) return;
    final query = q.length > 100 ? q.substring(0, 100) : q;
    if (query == _submitted) return;
    _submitted = query;
    final store = CommunityStore.instance;
    final controller = CommunityListController(
      fetch: (cursor) async => (
        page: await store.api
            .searchCommunity(query: query, cursor: cursor, lang: store.lang),
        raw: null,
      ),
    );
    final previous = _results;
    setState(() => _results = controller);
    previous?.dispose();
    unawaited(controller.load().then((_) {
      if (controller.failure == null) {
        unawaited(AnalyticsService.instance.logCommunitySearched(
          resultCount: controller.items.length,
          isHashtag: query.startsWith('#'),
        ));
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey<String>('comm-search-field'),
          controller: _query,
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: 'comm_search_hint'.tr,
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onSubmitted: _submit,
        ),
        actions: [
          IconButton(
            tooltip: 'comm_search_action'.tr,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _submit(_query.text),
          ),
        ],
      ),
      body: results == null
          ? CommunityInlineMessage(
              icon: Icons.manage_search_rounded,
              title: 'comm_search_intro_title'.tr,
              body: 'comm_search_intro_body'.tr,
            )
          : CommunityPostList(
              controller: results,
              bottomPadding: KpbSpacing.lg,
              onOpen: (post) => openCommunityPost(
                context,
                post: post,
                list: results,
                source: 'search',
              ),
              empty: CommunityInlineMessage(
                icon: Icons.search_off_rounded,
                title: 'comm_search_empty_title'.tr,
                body: 'comm_search_empty_body'.tr,
              ),
            ),
    );
  }
}
