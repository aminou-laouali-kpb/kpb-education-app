import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/services/remote_feature_flags.dart';
import '../../../core/ui/app_tokens.dart';
import 'community_composer_screen.dart';
import 'community_entity_space_screen.dart';
import 'community_open.dart';
import 'widgets/community_widgets.dart';

/// « Discussions (N) » sur une fiche bourse, pays ou formation.
///
/// Légère : un compteur (`/entities/counts`, regroupé et mémorisé 5 min), puis les trois
/// dernières discussions seulement s'il y en a. Drapeau fermé, compte non
/// élève, ou serveur muet : la section se REPLIE (hauteur nulle), jamais
/// d'erreur au milieu d'une fiche.
class CommunityEntitySection extends StatelessWidget {
  const CommunityEntitySection({
    super.key,
    required this.entity,
    this.extraPrefill = const <CommunityMention>[],
    this.padding = const EdgeInsets.fromLTRB(
        KpbSpacing.md, KpbSpacing.md, KpbSpacing.md, 0),
  });

  /// L'entité de la fiche (type, identifiant, libellé affiché).
  final CommunityMention entity;

  /// Mentions ajoutées au préremplissage de « Poser une question ».
  final List<CommunityMention> extraPrefill;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        RemoteFeatureFlags.instance.flagsVersion,
        CommunityStore.instance,
      ]),
      builder: (context, _) {
        if (!CommunityStore.instance.enabled) return const SizedBox.shrink();
        return _CommunityEntitySectionBody(
          key: ValueKey<String>('comm-section-${entity.ref}'),
          entity: entity,
          extraPrefill: extraPrefill,
          padding: padding,
        );
      },
    );
  }
}

class _CommunityEntitySectionBody extends StatefulWidget {
  const _CommunityEntitySectionBody({
    super.key,
    required this.entity,
    required this.extraPrefill,
    required this.padding,
  });

  final CommunityMention entity;
  final List<CommunityMention> extraPrefill;
  final EdgeInsets padding;

  @override
  State<_CommunityEntitySectionBody> createState() =>
      _CommunityEntitySectionBodyState();
}

class _CommunityEntitySectionBodyState
    extends State<_CommunityEntitySectionBody> {
  final CommunityStore _store = CommunityStore.instance;
  int? _count;
  List<CommunityPost> _latest = const <CommunityPost>[];
  bool _failed = false;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final type = widget.entity.type;
    final id = widget.entity.id;
    int? count;
    try {
      count = await _store.countFor(type, id);
      if (!mounted) return;
      setState(() => _count = count);
      _log(count);
      if (count > 0) {
        final space = await _store.api.fetchCommunityEntitySpace(
          type: type,
          id: id,
          limit: 3,
          lang: _store.lang,
        );
        if (!mounted) return;
        setState(() {
          _latest = space.page.items.take(3).toList(growable: false);
          _count = space.discussionCount;
        });
      }
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      // Un compteur sans liste reste utile ; sans compteur, on se replie.
      setState(() => _failed = _count == null);
    }
  }

  void _log(int count) {
    if (_logged) return;
    _logged = true;
    unawaited(AnalyticsService.instance.logCommunityEntitySectionViewed(
      entityType: widget.entity.type.wire,
      discussionCount: count,
    ));
  }

  Future<void> _ask() async {
    final created = await openCommunityComposer(
      context,
      source: 'entity_section',
      prefill: <CommunityMention>[widget.entity, ...widget.extraPrefill],
    );
    if (created != null && mounted) {
      setState(() {
        if (created.moderation == null) {
          _latest = <CommunityPost>[created, ..._latest].take(3).toList();
          _count = (_count ?? 0) + 1;
        }
      });
    }
  }

  void _seeAll() {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => CommunityEntitySpaceScreen(
        entity: widget.entity,
        extraPrefill: widget.extraPrefill,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (_failed || count == null) return const SizedBox.shrink();
    final latest = _latest
        .where((p) => !_store.isBlockedLocally(p.author.memberId))
        .toList(growable: false);
    final label = widget.entity.label;
    return Padding(
      padding: widget.padding,
      child: Container(
        key: const ValueKey<String>('comm-entity-section'),
        padding: const EdgeInsets.all(KpbSpacing.md - 2),
        decoration: BoxDecoration(
          color: KpbColors.surface,
          borderRadius: KpbRadius.mdBr,
          border: Border.all(color: KpbColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined,
                    size: 20, color: KpbColors.actionPrimary),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'comm_section_title'.trParams({'n': '$count'}),
                      style: KpbTextStyles.titleMd,
                    ),
                  ),
                ),
                if (count > 0)
                  TextButton(
                    key: const ValueKey<String>('comm-section-see-all'),
                    onPressed: _seeAll,
                    child: Text('see_all'.tr),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count == 0
                  ? 'comm_section_empty'.trParams({'label': label})
                  : 'comm_section_intro'.trParams({'label': label}),
              style: KpbTextStyles.bodySm,
            ),
            if (latest.isNotEmpty) ...[
              const SizedBox(height: KpbSpacing.sm + 4),
              for (final post in latest)
                Padding(
                  padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
                  child: CommunityPostCard(
                    post: post,
                    dense: true,
                    onTap: () => openCommunityPost(
                      context,
                      post: post,
                      source: 'entity_section',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: KpbSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey<String>('comm-section-ask'),
              onPressed: _ask,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'comm_section_ask'.trParams({'label': label}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
