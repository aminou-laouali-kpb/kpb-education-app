import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_toast.dart';
import '../../../core/ui/kpb_haptics.dart';
import '../../../core/utils/community_mention_tokens.dart';
import 'community_charter_sheet.dart';
import 'community_format.dart';
import 'community_mention_field.dart';
import 'widgets/community_widgets.dart';

/// Ouvre le compositeur après la charte (et la vérification d'une
/// restriction). Rend la publication créée ou modifiée, ou `null`.
Future<CommunityPost?> openCommunityComposer(
  BuildContext context, {
  required String source,
  List<CommunityMention> prefill = const <CommunityMention>[],
  CommunityPost? editing,
}) async {
  final canWrite = await ensureCommunityCanWrite(context);
  if (!canWrite || !context.mounted) return null;
  unawaited(AnalyticsService.instance.logCommunityComposerOpened(
    source: source,
    hasPrefill: prefill.isNotEmpty,
  ));
  return Navigator.of(context).push<CommunityPost>(
    MaterialPageRoute<CommunityPost>(
      builder: (_) =>
          CommunityComposerScreen(prefill: prefill, editing: editing),
    ),
  );
}

/// Poser une question / partager une expérience / un conseil.
///
/// Type, titre, corps ; `@` propose des bourses, pays, écoles et formations
/// (insérées comme puces, envoyées comme jetons structurés), `#` des
/// hashtags. Une prévisualisation montre le rendu final. Si le filtre
/// anti-arnaque met la publication en attente de revue, un message clair le
/// dit, sans accuser l'élève.
class CommunityComposerScreen extends StatefulWidget {
  const CommunityComposerScreen({
    super.key,
    this.prefill = const <CommunityMention>[],
    this.editing,
  });

  final List<CommunityMention> prefill;
  final CommunityPost? editing;

  @override
  State<CommunityComposerScreen> createState() =>
      _CommunityComposerScreenState();
}

class _CommunityComposerScreenState extends State<CommunityComposerScreen> {
  late CommunityPostType _type;
  late final TextEditingController _title;
  late final CommunityMentionController _body;
  bool _preview = false;
  bool _sending = false;
  String? _error;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _type = editing?.type ?? CommunityPostType.question;
    _title = TextEditingController(text: editing?.title ?? '');
    _body = CommunityMentionController(initialBody: editing?.body ?? '');
    for (final mention in widget.prefill) {
      _body.appendMention(mention);
    }
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_error != null) _error = null;
    setState(() {});
  }

  String get _titleText => _title.text.trim();
  String get _serialized => _body.serializedText.trim();
  String get _plainBody => _body.text.trim();

  int get _hashtagCount =>
      extractCommunityHashtags('$_titleText $_plainBody').length;

  bool get _titleOk =>
      _titleText.length >= CommunityLimitsSpec.titleMin &&
      _titleText.length <= CommunityLimitsSpec.titleMax;

  bool get _bodyOk =>
      _plainBody.length >= CommunityLimitsSpec.postBodyMin &&
      _serialized.length <= CommunityLimitsSpec.postBodyMax;

  bool get _mentionsOk =>
      _body.draft.distinctMentionCount <= CommunityLimitsSpec.maxMentions;

  bool get _hashtagsOk => _hashtagCount <= CommunityLimitsSpec.maxHashtags;

  bool get _canSend =>
      !_sending && _titleOk && _bodyOk && _mentionsOk && _hashtagsOk;

  /// Un `@[` tapé à la main dans le titre ressemblerait à un jeton : le titre
  /// reste du texte brut (contrat : mentions interdites dans le titre).
  String get _safeTitle => _titleText.replaceAll('@[', '@ [');

  Future<void> _send() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final store = CommunityStore.instance;
    try {
      final CommunityPost post;
      if (_editing) {
        post = await store.api.updateCommunityPost(
          postId: widget.editing!.id,
          type: _type,
          title: _safeTitle,
          body: _serialized,
          lang: store.lang,
        );
      } else {
        post = await store.api.createCommunityPost(
          type: _type,
          title: _safeTitle,
          body: _serialized,
          lang: store.lang,
        );
      }
      final pending = post.moderation != null;
      unawaited(AnalyticsService.instance.logCommunityPostCreated(
        postType: _type.wire,
        mentionCount: _body.draft.distinctMentionCount,
        hashtagCount: _hashtagCount,
        pendingReview: pending,
        isEdit: _editing,
      ));
      store.invalidateCounts(_body.draft.mentions.map((m) => m.ref));
      unawaited(store.loadMe(force: true));
      if (!mounted) return;
      setState(() => _sending = false);
      if (pending) {
        await showCommunityPendingReviewSheet(context);
      } else {
        unawaited(KpbHaptics.success());
        KpbToast.success(
          _editing ? 'comm_post_updated'.tr : 'comm_post_published'.tr,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } on CommunityException catch (error) {
      store.noteFailure(error);
      unawaited(AnalyticsService.instance.logCommunityPostFailed(
        reason: error.failure.name,
        target: 'post',
      ));
      if (!mounted) return;
      setState(() => _sending = false);
      if (error.failure == CommunityFailure.charterRequired) {
        await store.invalidateCharter();
        if (!mounted) return;
        final accepted = await showCommunityCharterSheet(context);
        if (accepted && mounted) unawaited(_send());
        return;
      }
      unawaited(KpbHaptics.error());
      setState(() => _error = communityFailureMessage(error));
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_titleText.isEmpty && _plainBody.isEmpty) return true;
    if (_editing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('comm_discard_title'.tr),
        content: Text('comm_discard_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('comm_discard_keep'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('comm_discard_confirm'.tr),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final limits = CommunityStore.instance.me?.limits;
    final exhausted = !_editing && (limits?.postsExhausted ?? false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: KpbColors.canvas,
        appBar: AppBar(
          backgroundColor: KpbColors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _editing ? 'comm_composer_edit_title'.tr : 'comm_composer_title'.tr,
            style: KpbTextStyles.titleLg,
          ),
          actions: [
            TextButton.icon(
              key: const ValueKey<String>('comm-composer-preview'),
              onPressed: () => setState(() => _preview = !_preview),
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(
                _preview ? 'comm_composer_edit'.tr : 'comm_composer_preview'.tr,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _preview ? _buildPreview() : _buildForm(exhausted),
              ),
              _buildBottomBar(exhausted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool exhausted) {
    final mentionsCount = _body.draft.distinctMentionCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          KpbSpacing.md, KpbSpacing.sm, KpbSpacing.md, KpbSpacing.lg),
      children: [
        Semantics(
          header: true,
          child:
              Text('comm_composer_type_label'.tr, style: KpbTextStyles.titleSm),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Wrap(
          spacing: KpbSpacing.sm,
          runSpacing: KpbSpacing.sm,
          children: [
            for (final type in CommunityPostType.values)
              ChoiceChip(
                key: ValueKey<String>('comm-composer-type-${type.wire}'),
                selected: _type == type,
                avatar: Icon(communityPostTypeIcon(type), size: 16),
                label: Text(communityPostTypeLabel(type)),
                onSelected: (_) {
                  KpbHaptics.selection();
                  setState(() => _type = type);
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(communityPostTypeHint(_type), style: KpbTextStyles.caption),
        const SizedBox(height: KpbSpacing.md),
        TextField(
          key: const ValueKey<String>('comm-composer-title'),
          controller: _title,
          maxLength: CommunityLimitsSpec.titleMax,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'comm_composer_title_label'.tr,
            hintText: 'comm_composer_title_hint'.tr,
            helperText: _titleText.isNotEmpty && !_titleOk
                ? 'comm_composer_title_min'
                    .trParams({'n': '${CommunityLimitsSpec.titleMin}'})
                : null,
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        TextField(
          key: const ValueKey<String>('comm-composer-body'),
          controller: _body,
          minLines: 6,
          maxLines: 14,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'comm_composer_body_label'.tr,
            hintText: 'comm_composer_body_hint'.tr,
            alignLabelWithHint: true,
            helperText: 'comm_composer_body_helper'.tr,
            helperMaxLines: 3,
            counterText:
                '${_serialized.length}/${CommunityLimitsSpec.postBodyMax}',
          ),
        ),
        CommunitySuggestionPanel(
          controller: _body,
          maxMentionsReached: mentionsCount >= CommunityLimitsSpec.maxMentions,
        ),
        if (_plainBody.isNotEmpty && !_bodyOk) ...[
          const SizedBox(height: 4),
          Text(
            'comm_composer_body_min'
                .trParams({'n': '${CommunityLimitsSpec.postBodyMin}'}),
            style: const TextStyle(
              fontSize: KpbFontSize.xs,
              color: KpbColors.warning,
            ),
          ),
        ],
        if (!_mentionsOk) _InlineError(text: 'comm_err_too_many_mentions'.tr),
        if (!_hashtagsOk) _InlineError(text: 'comm_err_too_many_hashtags'.tr),
        if (_body.draft.mentions.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.sm),
          Text('comm_composer_mentions_label'.tr, style: KpbTextStyles.caption),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m
                  in {for (final d in _body.draft.mentions) d.ref: d}.values)
                CommunityMentionChip(
                  mention: CommunityMention(
                    type: m.type,
                    id: m.id,
                    label: m.label,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: KpbSpacing.md),
        const _SafetyReminder(),
        if (exhausted) ...[
          const SizedBox(height: KpbSpacing.sm),
          _InlineError(
            text: 'comm_err_rate_posts'.trParams({
              'limit': '${CommunityStore.instance.me?.limits.postsPerDay ?? 0}',
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    final segments = parseCommunityBody(_serialized);
    final me = CommunityStore.instance.me?.member;
    return ListView(
      key: const ValueKey<String>('comm-composer-preview-view'),
      padding: const EdgeInsets.all(KpbSpacing.md),
      children: [
        Text('comm_composer_preview_note'.tr, style: KpbTextStyles.caption),
        const SizedBox(height: KpbSpacing.sm),
        Container(
          padding: const EdgeInsets.all(KpbSpacing.md),
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(color: KpbColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityTypeChip(type: _type),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                _titleText.isEmpty
                    ? 'comm_composer_title_label'.tr
                    : _titleText,
                style: KpbTextStyles.title,
              ),
              const SizedBox(height: KpbSpacing.sm),
              if (me != null) ...[
                CommunityAuthorLine(author: me),
                const SizedBox(height: KpbSpacing.sm),
              ],
              if (segments.isEmpty)
                Text('comm_composer_body_label'.tr, style: KpbTextStyles.bodySm)
              else
                CommunitySegmentsText(segments: segments),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool exhausted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          KpbSpacing.md, KpbSpacing.sm, KpbSpacing.md, KpbSpacing.sm),
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const ValueKey<String>('comm-composer-error'),
                  style: const TextStyle(
                    fontSize: KpbFontSize.sm,
                    color: KpbColors.error,
                  ),
                ),
              ),
            ),
          FilledButton(
            key: const ValueKey<String>('comm-composer-send'),
            onPressed: _canSend && !exhausted ? _send : null,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_editing
                    ? 'comm_composer_save'.tr
                    : 'comm_composer_publish'.tr),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style:
            const TextStyle(fontSize: KpbFontSize.xs, color: KpbColors.error),
      ),
    );
  }
}

class _SafetyReminder extends StatelessWidget {
  const _SafetyReminder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.sm + 4),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: KpbRadius.smBr,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              size: 18, color: KpbColors.actionPrimary),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              'comm_composer_safety'.tr,
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                height: 1.45,
                color: KpbColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Ta publication est en cours de vérification » — après un 201 dont la
/// publication est née `pending_review`. Le message n'accuse pas : la revue
/// protège toute la communauté des arnaques, et le message n'est pas perdu.
Future<void> showCommunityPendingReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
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
        padding: const EdgeInsets.all(KpbSpacing.page),
        child: Column(
          key: const ValueKey<String>('comm-pending-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 36, color: KpbColors.warning),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              'comm_pending_title'.tr,
              textAlign: TextAlign.center,
              style: KpbTextStyles.title,
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              'comm_pending_body'.tr,
              textAlign: TextAlign.center,
              style: KpbTextStyles.body,
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              'comm_pending_tip'.tr,
              textAlign: TextAlign.center,
              style: KpbTextStyles.bodySm,
            ),
            const SizedBox(height: KpbSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text('comm_got_it'.tr),
            ),
          ],
        ),
      ),
    ),
  );
}
