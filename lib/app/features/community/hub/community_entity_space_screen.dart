import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import 'community_composer_screen.dart';
import 'community_format.dart';
import 'community_list_controller.dart';
import 'community_open.dart';
import 'widgets/community_post_list.dart';
import 'widgets/community_widgets.dart';

/// L'espace de discussion d'une entité (« Voir tout » d'une fiche) : les
/// publications qui la mentionnent, récentes ou sans réponse, et « Poser une
/// question sur X », qui préremplit la mention.
class CommunityEntitySpaceScreen extends StatefulWidget {
  const CommunityEntitySpaceScreen({
    super.key,
    required this.entity,
    this.extraPrefill = const <CommunityMention>[],
  });

  final CommunityMention entity;

  /// Mentions ajoutées au préremplissage (l'école d'une formation…).
  final List<CommunityMention> extraPrefill;

  @override
  State<CommunityEntitySpaceScreen> createState() =>
      _CommunityEntitySpaceScreenState();
}

class _CommunityEntitySpaceScreenState
    extends State<CommunityEntitySpaceScreen> {
  bool _unanswered = false;
  late CommunityListController _list;
  int? _count;
  String? _label;

  @override
  void initState() {
    super.initState();
    _list = _build();
    _list.load();
  }

  CommunityListController _build() {
    final store = CommunityStore.instance;
    final unanswered = _unanswered;
    return CommunityListController(
      fetch: (cursor) async {
        final space = await store.api.fetchCommunityEntitySpace(
          type: widget.entity.type,
          id: widget.entity.id,
          unanswered: unanswered,
          cursor: cursor,
          lang: store.lang,
        );
        if (mounted && cursor == null) {
          setState(() {
            _count = space.discussionCount;
            _label = space.entity.label;
          });
          store.rememberCount(
              widget.entity.type, widget.entity.id, space.discussionCount);
        }
        return (page: space.page, raw: null);
      },
    );
  }

  void _setUnanswered(bool value) {
    if (value == _unanswered) return;
    final previous = _list;
    setState(() {
      _unanswered = value;
      _list = _build();
    });
    previous.dispose();
    _list.load();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final created = await openCommunityComposer(
      context,
      source: 'entity_space',
      prefill: <CommunityMention>[widget.entity, ...widget.extraPrefill],
    );
    if (created != null && mounted) {
      _list.prepend(created);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label ?? widget.entity.label;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KpbTextStyles.titleLg,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('comm-space-ask'),
        onPressed: _ask,
        icon: const Icon(Icons.edit_outlined),
        label: Text('comm_ask_question'.tr),
      ),
      body: CommunityPostList(
        controller: _list,
        onOpen: (post) => openCommunityPost(
          context,
          post: post,
          list: _list,
          source: 'entity_space',
        ),
        header: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KpbSpacing.md, KpbSpacing.xs, KpbSpacing.md, KpbSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(communityEntityIcon(widget.entity.type),
                        size: 18, color: KpbColors.actionPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _count == null
                            ? communityEntityTypeLabel(widget.entity.type)
                            : '${communityEntityTypeLabel(widget.entity.type)} · '
                                '${'comm_discussions_count'.trParams({
                                    'n': '$_count'
                                  })}',
                        style: KpbTextStyles.bodySm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KpbSpacing.sm),
                Wrap(
                  spacing: KpbSpacing.sm,
                  children: [
                    ChoiceChip(
                      selected: !_unanswered,
                      label: Text('comm_tab_recent'.tr),
                      onSelected: (_) => _setUnanswered(false),
                    ),
                    ChoiceChip(
                      selected: _unanswered,
                      label: Text('comm_tab_unanswered'.tr),
                      onSelected: (_) => _setUnanswered(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        empty: CommunityInlineMessage(
          icon: Icons.forum_outlined,
          title: 'comm_space_empty_title'.trParams({'label': label}),
          body: 'comm_space_empty_body'.tr,
          actionLabel: 'comm_ask_question'.tr,
          onAction: _ask,
        ),
      ),
    );
  }
}
