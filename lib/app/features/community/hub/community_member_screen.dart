import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_toast.dart';
import 'community_format.dart';
import 'community_report_sheet.dart';
import 'widgets/community_widgets.dart';

/// Profil public minimal d'un membre : prénom + initiale, pays, badges,
/// réponses utiles, mois d'arrivée. Jamais e-mail, téléphone, âge ; aucun
/// message privé (il n'en existe pas). Bloquer et signaler depuis ici.
class CommunityMemberScreen extends StatefulWidget {
  const CommunityMemberScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<CommunityMemberScreen> createState() => _CommunityMemberScreenState();
}

class _CommunityMemberScreenState extends State<CommunityMemberScreen> {
  final CommunityStore _store = CommunityStore.instance;
  CommunityMemberProfile? _profile;
  CommunityException? _failure;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final profile = await _store.api
          .fetchCommunityMember(widget.memberId, lang: _store.lang);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      setState(() {
        _failure = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBlock() async {
    final profile = _profile;
    if (profile == null) return;
    if (!profile.isBlocked) {
      final blocked =
          await confirmAndBlockCommunityMember(context, profile.member);
      if (blocked && mounted) {
        setState(() => _profile = profile.withBlocked(true));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final blocked = await _store.setBlocked(widget.memberId, blocked: false);
      unawaited(
          AnalyticsService.instance.logCommunityBlockToggled(enabled: false));
      if (!mounted) return;
      setState(() => _profile = profile.withBlocked(blocked));
      KpbToast.success(
          'comm_unblock_done'.trParams({'name': profile.member.displayName}));
    } on CommunityException catch (error) {
      KpbToast.error(communityFailureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('comm_member_title'.tr, style: KpbTextStyles.titleLg),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final profile = _profile;
    if (profile == null) {
      if (_loading) {
        return const SingleChildScrollView(
          padding: EdgeInsets.all(KpbSpacing.md),
          child: CommunityFeedSkeleton(count: 1),
        );
      }
      final notFound = _failure?.failure == CommunityFailure.notFound;
      return CommunityInlineMessage(
        icon: notFound ? Icons.person_off_outlined : Icons.wifi_off_rounded,
        title:
            notFound ? 'comm_member_not_found'.tr : 'comm_load_failed_title'.tr,
        body: notFound || _failure == null
            ? null
            : communityFailureMessage(_failure!),
        actionLabel: notFound ? null : 'retry'.tr,
        onAction: notFound ? null : _load,
      );
    }
    final member = profile.member;
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(KpbSpacing.md),
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(color: KpbColors.border),
          ),
          child: Column(
            children: [
              CommunityAvatar(author: member, size: 64),
              const SizedBox(height: KpbSpacing.sm),
              Semantics(
                header: true,
                child: Text(
                  member.displayName,
                  textAlign: TextAlign.center,
                  style: KpbTextStyles.title,
                ),
              ),
              if (member.countryName != null) ...[
                const SizedBox(height: 2),
                Text(member.countryName!,
                    textAlign: TextAlign.center, style: KpbTextStyles.bodySm),
              ],
              if (member.orderedBadges.isNotEmpty) ...[
                const SizedBox(height: KpbSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final badge in member.orderedBadges)
                      CommunityRoleBadge(badge: badge),
                  ],
                ),
              ],
              if (profile.memberSince != null) ...[
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'comm_member_since'.trParams(
                      {'month': communityMonthLabel(profile.memberSince!)}),
                  style: KpbTextStyles.caption,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.sm + 4),
        Row(
          children: [
            _Stat(
              value: profile.stats.helpfulAnswersCount,
              label: 'comm_member_helpful'.tr,
            ),
            const SizedBox(width: KpbSpacing.sm),
            _Stat(
                value: profile.stats.postsCount, label: 'comm_member_posts'.tr),
            const SizedBox(width: KpbSpacing.sm),
            _Stat(
                value: profile.stats.repliesCount,
                label: 'comm_member_replies'.tr),
          ],
        ),
        const SizedBox(height: KpbSpacing.md),
        Text('comm_member_privacy'.tr, style: KpbTextStyles.caption),
        if (!profile.isMe && !member.isTeam) ...[
          const SizedBox(height: KpbSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey<String>('comm-member-block'),
            onPressed: _busy ? null : _toggleBlock,
            icon: Icon(profile.isBlocked
                ? Icons.lock_open_rounded
                : Icons.block_rounded),
            label: Text(profile.isBlocked
                ? 'comm_unblock_action'.tr
                : 'comm_block_action'.tr),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  profile.isBlocked ? KpbColors.actionPrimary : KpbColors.error,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          TextButton.icon(
            onPressed: () => showCommunityReportSheet(
              context,
              target: CommunityReportTarget.member,
              targetId: widget.memberId,
            ),
            icon: const Icon(Icons.flag_outlined),
            label: Text('comm_menu_report_member'.tr),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: KpbSpacing.sm + 4, horizontal: KpbSpacing.sm),
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: KpbRadius.smBr,
            border: Border.all(color: KpbColors.border),
          ),
          child: Column(
            children: [
              Text('$value', style: KpbTextStyles.title),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: KpbTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profil → Réglages → « Utilisateurs bloqués » : la liste, et « Débloquer ».
class CommunityBlockedMembersScreen extends StatefulWidget {
  const CommunityBlockedMembersScreen({super.key});

  @override
  State<CommunityBlockedMembersScreen> createState() =>
      _CommunityBlockedMembersScreenState();
}

class _CommunityBlockedMembersScreenState
    extends State<CommunityBlockedMembersScreen> {
  final CommunityStore _store = CommunityStore.instance;
  final List<CommunityBlockedMember> _items = <CommunityBlockedMember>[];
  String? _cursor;
  bool _loading = true;
  CommunityException? _failure;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page =
          await _store.api.fetchCommunityBlocks(cursor: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
    } on CommunityException catch (error) {
      _store.noteFailure(error);
      if (!mounted) return;
      setState(() {
        _failure = error;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(CommunityBlockedMember entry) async {
    final id = entry.member.memberId!;
    setState(() => _busy.add(id));
    try {
      await _store.setBlocked(id, blocked: false);
      unawaited(
          AnalyticsService.instance.logCommunityBlockToggled(enabled: false));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.member.memberId == id));
      KpbToast.success(
          'comm_unblock_done'.trParams({'name': entry.member.displayName}));
    } on CommunityException catch (error) {
      KpbToast.error(communityFailureMessage(error));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_items.isEmpty && _loading) {
      body = const SingleChildScrollView(
        padding: EdgeInsets.all(KpbSpacing.md),
        child: CommunityFeedSkeleton(count: 2),
      );
    } else if (_items.isEmpty && _failure != null) {
      body = CommunityInlineMessage(
        icon: Icons.wifi_off_rounded,
        title: 'comm_load_failed_title'.tr,
        body: communityFailureMessage(_failure!),
        actionLabel: 'retry'.tr,
        onAction: _load,
      );
    } else if (_items.isEmpty) {
      body = CommunityInlineMessage(
        icon: Icons.check_circle_outline_rounded,
        title: 'comm_blocked_empty_title'.tr,
        body: 'comm_blocked_empty_body'.tr,
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(KpbSpacing.md),
        children: [
          Text('comm_blocked_intro'.tr, style: KpbTextStyles.bodySm),
          const SizedBox(height: KpbSpacing.sm + 4),
          for (final entry in _items)
            Container(
              margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
              padding: const EdgeInsets.all(KpbSpacing.sm + 4),
              decoration: BoxDecoration(
                color: KpbColors.surface,
                borderRadius: KpbRadius.smBr,
                border: Border.all(color: KpbColors.border),
              ),
              child: Row(
                children: [
                  Expanded(child: CommunityAuthorLine(author: entry.member)),
                  const SizedBox(width: KpbSpacing.sm),
                  TextButton(
                    key: ValueKey<String>(
                        'comm-unblock-${entry.member.memberId}'),
                    onPressed: _busy.contains(entry.member.memberId)
                        ? null
                        : () => _unblock(entry),
                    child: Text('comm_unblock_action'.tr),
                  ),
                ],
              ),
            ),
          if (_cursor != null)
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => _load(more: true),
                child: Text('comm_load_more'.tr),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('comm_blocked_title'.tr, style: KpbTextStyles.titleLg),
      ),
      body: body,
    );
  }
}
