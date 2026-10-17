import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/community_mention_tokens.dart';
import 'community_format.dart';

/// Contrôleur de saisie qui affiche les mentions comme des puces.
///
/// Le texte édité est ce que l'élève voit (« Qui a eu @Eiffel ? ») ; le
/// [draft] garde, à côté, la plage et l'entité de chaque puce. Chaque frappe
/// passe par [CommunityDraft.reconcile] : une puce touchée disparaît entière
/// (son texte reste, ordinaire). [serializedText] rend le corps à envoyer,
/// avec les jetons `@[libellé](type:id)`.
class CommunityMentionController extends TextEditingController {
  CommunityMentionController({String initialBody = ''})
      : _draft = CommunityDraft.fromBody(initialBody),
        super() {
    super.value = TextEditingValue(
      text: _draft.text,
      selection: TextSelection.collapsed(offset: _draft.text.length),
    );
  }

  CommunityDraft _draft;

  CommunityDraft get draft => _draft;

  /// Le corps à envoyer (jetons de mention compris).
  String get serializedText => _draft.serialize();

  @override
  set value(TextEditingValue newValue) {
    _draft = _draft.reconcile(newValue.text);
    super.value = newValue;
  }

  /// La saisie `@…` / `#…` en cours au curseur, ou `null`.
  CommunityTrigger? get trigger {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    return activeCommunityTrigger(_draft, selection.baseOffset);
  }

  /// Remplace la saisie `@requête` par une puce.
  void insertMention(CommunityTrigger trigger, CommunityMentionSuggestion s) {
    final result = _draft.insertMention(
      start: trigger.start,
      end: trigger.end,
      type: s.type,
      id: s.id,
      label: s.label,
    );
    _draft = result.draft;
    super.value = TextEditingValue(
      text: result.draft.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
  }

  /// Ajoute une puce en fin de texte (« Poser une question sur X »).
  void appendMention(CommunityMention mention) {
    final base = text;
    final needsSpace = base.isNotEmpty && !base.endsWith(' ');
    final start = base.length + (needsSpace ? 1 : 0);
    final prefixed = needsSpace ? '$base ' : base;
    final interim = CommunityDraft(prefixed, _draft.mentions);
    final result = interim.insertMention(
      start: start,
      end: start,
      type: mention.type,
      id: mention.id,
      label: mention.label,
    );
    _draft = result.draft;
    super.value = TextEditingValue(
      text: result.draft.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
  }

  /// Remplace la saisie `#requête` par `#Affichage `.
  void insertHashtag(CommunityTrigger trigger, String display) {
    final t = text;
    final start = trigger.start.clamp(0, t.length);
    final end = trigger.end.clamp(start, t.length);
    final next = '${t.substring(0, start)}#$display ${t.substring(end)}';
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + display.length + 2),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_draft.mentions.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final chip = (style ?? const TextStyle()).copyWith(
      color: KpbColors.actionPrimary,
      fontWeight: FontWeight.w700,
      background: Paint()..color = KpbColors.actionPrimarySoft,
    );
    final children = <InlineSpan>[];
    var cursor = 0;
    final t = text;
    for (final m in _draft.mentions) {
      if (m.start < cursor || m.end > t.length) continue;
      if (m.start > cursor) {
        children.add(TextSpan(text: t.substring(cursor, m.start)));
      }
      children.add(TextSpan(text: t.substring(m.start, m.end), style: chip));
      cursor = m.end;
    }
    if (cursor < t.length) children.add(TextSpan(text: t.substring(cursor)));
    return TextSpan(style: style, children: children);
  }
}

/// Les suggestions d'autocomplétion sous un champ : entités du catalogue
/// pour `@`, hashtags pour `#`. Une requête à la fois, après une courte
/// pause de frappe (réseau lent : on n'envoie pas une requête par lettre).
class CommunitySuggestionPanel extends StatefulWidget {
  const CommunitySuggestionPanel({
    super.key,
    required this.controller,
    this.maxMentionsReached = false,
  });

  final CommunityMentionController controller;

  /// 10 entités déjà citées : on n'en propose plus.
  final bool maxMentionsReached;

  @override
  State<CommunitySuggestionPanel> createState() =>
      _CommunitySuggestionPanelState();
}

class _CommunitySuggestionPanelState extends State<CommunitySuggestionPanel> {
  static const _debounce =
      Duration(milliseconds: 280); // kpb-allow-duration: pause de frappe réseau

  Timer? _timer;
  CommunityTrigger? _trigger;
  String? _lastQuery;
  List<CommunityMentionSuggestion> _mentions = const [];
  List<CommunityHashtagSuggestion> _hashtags = const [];
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant CommunitySuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final trigger = widget.controller.trigger;
    final key = trigger == null ? null : '${trigger.symbol}${trigger.query}';
    if (key == _lastQuery) return;
    _lastQuery = key;
    _timer?.cancel();
    if (trigger == null || (trigger.isMention && trigger.query.isEmpty)) {
      setState(() {
        _trigger = trigger;
        _mentions = const [];
        _hashtags = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _trigger = trigger;
      _loading = true;
      _failed = false;
    });
    _timer = Timer(_debounce, () => _fetch(trigger));
  }

  Future<void> _fetch(CommunityTrigger trigger) async {
    final request = ++_request;
    final store = CommunityStore.instance;
    try {
      if (trigger.isMention) {
        final items = await store.api.suggestCommunityMentions(
          query: trigger.query,
          lang: store.lang,
        );
        if (!mounted || request != _request) return;
        setState(() {
          _mentions = items;
          _hashtags = const [];
          _loading = false;
        });
      } else {
        final items =
            await store.api.suggestCommunityHashtags(query: trigger.query);
        if (!mounted || request != _request) return;
        setState(() {
          _hashtags = items;
          _mentions = const [];
          _loading = false;
        });
      }
    } on CommunityException catch (error) {
      store.noteFailure(error);
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trigger = _trigger;
    if (trigger == null) return const SizedBox.shrink();
    if (trigger.isMention && trigger.query.isEmpty) {
      return _Hint(text: 'comm_mention_type_more'.tr);
    }
    if (trigger.isMention && widget.maxMentionsReached) {
      return _Hint(text: 'comm_err_too_many_mentions'.tr);
    }
    final Widget body;
    if (_loading && _mentions.isEmpty && _hashtags.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(KpbSpacing.sm + 4),
        child: Semantics(
          liveRegion: true,
          label: 'comm_suggest_loading'.tr,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else if (_failed) {
      body = _Hint(text: 'comm_suggest_failed'.tr);
    } else if (trigger.isMention && _mentions.isEmpty) {
      body = _Hint(text: 'comm_suggest_none'.tr);
    } else if (!trigger.isMention && _hashtags.isEmpty) {
      body = trigger.query.length >= 2
          ? _Hint(
              text: 'comm_hashtag_new'.trParams({'tag': trigger.query}),
            )
          : const SizedBox.shrink();
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trigger.isMention)
            for (final s in _mentions)
              _SuggestionTile(
                key: ValueKey<String>('comm-suggest-${s.type.wire}-${s.id}'),
                icon: communityEntityIcon(s.type),
                title: s.label,
                subtitle: [communityEntityTypeLabel(s.type), s.subtitle]
                    .whereType<String>()
                    .join(' · '),
                onTap: () => widget.controller.insertMention(trigger, s),
              )
          else
            for (final h in _hashtags)
              _SuggestionTile(
                key: ValueKey<String>('comm-suggest-tag-${h.tag}'),
                icon: Icons.tag_rounded,
                title: '#${h.display}',
                subtitle: h.postCount > 0
                    ? 'comm_hashtag_posts'.trParams({'n': '${h.postCount}'})
                    : null,
                onTap: () =>
                    widget.controller.insertHashtag(trigger, h.display),
              ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: KpbSpacing.xs),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: KpbRadius.smBr,
        border: Border.all(color: KpbColors.border),
        boxShadow: KpbShadow.soft,
      ),
      child: body,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.sm + 4, vertical: KpbSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: KpbFontSize.xs,
            color: KpbColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [title, subtitle].whereType<String>().join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.sm + 4, vertical: KpbSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: KpbColors.actionPrimary),
              const SizedBox(width: KpbSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KpbFontSize.sm,
                        fontWeight: FontWeight.w700,
                        color: KpbColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          color: KpbColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
