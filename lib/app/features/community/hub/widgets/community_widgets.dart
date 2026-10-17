import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/models/community.dart';
import '../../../../core/ui/app_tokens.dart';
import '../../../../core/ui/skeleton.dart';
import '../../../../core/utils/external_link.dart';
import '../community_format.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Briques visuelles de la communauté.
//
// Légères à dessein (téléphones modestes) : pas d'image réseau (l'avatar est
// fait d'initiales), pas d'ombre lourde, pas d'animation en cascade. Chaque
// carte se lit d'un seul libellé TalkBack complet.
// ─────────────────────────────────────────────────────────────────────────────

/// Avatar d'initiales : aucune photo ne voyage dans la communauté (profil
/// public minimal).
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.author, this.size = 32});

  final CommunityAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final team = author.isTeam;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: team ? KpbColors.brandNavy : KpbColors.actionPrimarySoft,
          shape: BoxShape.circle,
        ),
        child: team
            ? Icon(
                author.isAssistant
                    ? Icons.fact_check_rounded
                    : Icons.shield_rounded,
                size: size * 0.5,
                color: KpbColors.textOnDark)
            : Text(
                author.initials,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size <= 32 ? KpbFontSize.xs : KpbFontSize.lg,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.actionPrimary,
                ),
              ),
      ),
    );
  }
}

/// Un badge de rôle (« Conseiller KPB », « Alumni vérifié »…).
class CommunityRoleBadge extends StatelessWidget {
  const CommunityRoleBadge({super.key, required this.badge});

  final CommunityBadge badge;

  @override
  Widget build(BuildContext context) {
    final color = communityBadgeColor(badge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(communityBadgeIcon(badge), size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              communityBadgeLabel(badge),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: KpbFontSize.xs,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La mention sous une réponse de l'« Assistant KPB » (bot Vérif) : d'où
/// vient la réponse et quand les données citées ont été vérifiées. La date est
/// un JOUR du catalogue (minuit UTC) : lue en UTC, jamais décalée la veille.
class CommunityAssistantNotice extends StatelessWidget {
  const CommunityAssistantNotice({super.key, this.sourceVerifiedAt});

  final DateTime? sourceVerifiedAt;

  @override
  Widget build(BuildContext context) {
    final at = sourceVerifiedAt?.toUtc();
    final text = at == null
        ? 'comm_assistant_notice'.tr
        : 'comm_assistant_notice_dated'.trParams({
            'date': '${at.day.toString().padLeft(2, '0')}/'
                '${at.month.toString().padLeft(2, '0')}/${at.year}',
          });
    return Container(
      key: const ValueKey<String>('comm-assistant-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KpbColors.brandNavy.withValues(alpha: 0.06),
        borderRadius: KpbRadius.smBr,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.fact_check_rounded,
                size: 14, color: KpbColors.brandNavy),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                height: 1.35,
                color: KpbColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phrase TalkBack d'un auteur : « Aïcha K., Niger, Alumni vérifié ».
String communityAuthorSemantics(CommunityAuthor author) {
  final parts = <String>[
    author.displayName,
    if (author.countryName != null) author.countryName!,
    ...author.orderedBadges.map(communityBadgeLabel),
  ];
  return parts.join(', ');
}

/// Avatar, nom, pays et badges ; [trailing] (l'heure) à droite.
class CommunityAuthorLine extends StatelessWidget {
  const CommunityAuthorLine({
    super.key,
    required this.author,
    this.trailing,
    this.onTap,
    this.avatarSize = 28,
  });

  final CommunityAuthor author;
  final String? trailing;
  final VoidCallback? onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final badges = author.orderedBadges;
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityAvatar(author: author, size: avatarSize),
        const SizedBox(width: KpbSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    author.displayName,
                    style: const TextStyle(
                      fontSize: KpbFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: KpbColors.textPrimary,
                    ),
                  ),
                  if (author.countryName != null)
                    Text(
                      author.countryName!,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        color: KpbColors.textMuted,
                      ),
                    ),
                ],
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final badge in badges)
                      CommunityRoleBadge(badge: badge),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (trailing != null && trailing!.isNotEmpty) ...[
          const SizedBox(width: KpbSpacing.sm),
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: KpbFontSize.xs,
              color: KpbColors.textMuted,
            ),
          ),
        ],
      ],
    );
    if (onTap == null) return line;
    return Semantics(
      button: true,
      label: 'comm_a11y_open_member'
          .trParams({'name': communityAuthorSemantics(author)}),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: KpbRadius.smBr,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: line,
        ),
      ),
    );
  }
}

/// La puce du type de publication.
class CommunityTypeChip extends StatelessWidget {
  const CommunityTypeChip({super.key, required this.type});

  final CommunityPostType type;

  @override
  Widget build(BuildContext context) {
    final color = communityPostTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(communityPostTypeIcon(type), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            communityPostTypeLabel(type),
            style: TextStyle(
              fontSize: KpbFontSize.xs,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Réponse vérifiée » (liste) ou « Réponse vérifiée par KPB » (détail).
class CommunityVerifiedPill extends StatelessWidget {
  const CommunityVerifiedPill({super.key, this.long = false});

  final bool long;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KpbColors.successLight,
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: KpbColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              size: 14, color: KpbColors.success),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              long ? 'comm_verified_answer_long'.tr : 'comm_verified_answer'.tr,
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                fontWeight: FontWeight.w800,
                color: KpbColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une puce de mention cliquable (dans le texte ou en carte).
class CommunityMentionChip extends StatelessWidget {
  const CommunityMentionChip({
    super.key,
    required this.mention,
    this.onTap,
  });

  final CommunityMention mention;
  final ValueChanged<CommunityMention>? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: KpbRadius.xsBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(communityEntityIcon(mention.type),
              size: 13, color: KpbColors.actionPrimary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              mention.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: KpbFontSize.sm,
                fontWeight: FontWeight.w700,
                color: KpbColors.actionPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    final label = 'comm_a11y_mention'.trParams({
      'type': communityEntityTypeLabel(mention.type),
      'label': mention.label,
    });
    if (onTap == null) {
      return Semantics(label: label, excludeSemantics: true, child: chip);
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap!(mention),
        borderRadius: KpbRadius.xsBr,
        child: chip,
      ),
    );
  }
}

/// Le corps d'un contenu, rendu depuis ses segments : texte, puces de
/// mention, hashtags et liens (liste blanche du serveur seulement).
class CommunitySegmentsText extends StatefulWidget {
  const CommunitySegmentsText({
    super.key,
    required this.segments,
    this.onMention,
    this.onHashtag,
    this.style,
  });

  final List<CommunitySegment> segments;
  final ValueChanged<CommunityMention>? onMention;
  final ValueChanged<CommunityHashtag>? onHashtag;
  final TextStyle? style;

  @override
  State<CommunitySegmentsText> createState() => _CommunitySegmentsTextState();
}

class _CommunitySegmentsTextState extends State<CommunitySegmentsText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = widget.style ??
        const TextStyle(
          fontSize: KpbFontSize.md,
          height: 1.5,
          color: KpbColors.textPrimary,
        );
    const linkStyle = TextStyle(
      color: KpbColors.actionPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final spans = <InlineSpan>[];
    for (final segment in widget.segments) {
      switch (segment) {
        case CommunityTextSegment(:final text):
          spans.add(TextSpan(text: text));
        case CommunityMentionSegment(:final mention):
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: CommunityMentionChip(
                mention: mention,
                onTap: widget.onMention,
              ),
            ),
          ));
        case CommunityHashtagSegment(:final hashtag):
          spans.add(TextSpan(
            text: '#${hashtag.display}',
            style: const TextStyle(
              color: KpbColors.actionPrimary,
              fontWeight: FontWeight.w600,
            ),
            recognizer: widget.onHashtag == null
                ? null
                : _tap(() => widget.onHashtag!(hashtag)),
          ));
        case CommunityLinkSegment(:final url, :final text):
          spans.add(TextSpan(
            text: text,
            style: linkStyle,
            recognizer: _tap(() => kpbOpenExternalUrlString(url)),
          ));
      }
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Le bandeau de l'auteur d'un contenu en attente de revue ou masqué. Le ton
/// n'accuse jamais : la revue protège la communauté, elle ne juge pas
/// l'élève.
class CommunityModerationNotice extends StatelessWidget {
  const CommunityModerationNotice({
    super.key,
    required this.moderation,
    this.compact = false,
  });

  final CommunityModeration moderation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pending = moderation.pending;
    final title = pending
        ? 'comm_moderation_pending_title'.tr
        : 'comm_moderation_hidden_title'.tr;
    final body = pending
        ? 'comm_moderation_pending_body'.tr
        : 'comm_moderation_hidden_body'.tr;
    final color = pending ? KpbColors.warning : KpbColors.textSecondary;
    return Semantics(
      container: true,
      label: compact ? title : '$title. $body',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KpbSpacing.sm + 2),
        decoration: BoxDecoration(
          color: pending ? KpbColors.warningLight : KpbColors.surfaceMuted,
          borderRadius: KpbRadius.smBr,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              pending
                  ? Icons.hourglass_top_rounded
                  : Icons.visibility_off_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: KpbSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: KpbFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        height: 1.4,
                        color: KpbColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phrase TalkBack d'une carte de publication.
String communityPostSemantics(CommunityPost post) {
  final parts = <String>[
    '${communityPostTypeLabel(post.type)} : ${post.title}',
    if (post.isPinned) 'comm_pinned'.tr,
    'comm_a11y_by'.trParams({'name': communityAuthorSemantics(post.author)}),
    communityRelativeTime(post.createdAt),
    communityReplyCountLabel(post.replyCount),
    if (post.helpfulCount > 0) communityHelpfulCountLabel(post.helpfulCount),
    if (post.hasVerifiedAnswer) 'comm_verified_answer_long'.tr,
    if (post.moderation != null)
      post.moderation!.pending
          ? 'comm_moderation_pending_title'.tr
          : 'comm_moderation_hidden_title'.tr,
  ];
  return parts.where((p) => p.isNotEmpty).join('. ');
}

/// Une publication dans une liste.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.dense = false,
  });

  final CommunityPost post;
  final VoidCallback onTap;

  /// Variante courte (sections des fiches) : sans extrait ni mentions.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final mentions = post.mentions.take(3).toList(growable: false);
    return Semantics(
      container: true,
      button: true,
      label: communityPostSemantics(post),
      excludeSemantics: true,
      child: Material(
        color: KpbColors.surface,
        borderRadius: KpbRadius.mdBr,
        child: InkWell(
          onTap: onTap,
          borderRadius: KpbRadius.mdBr,
          child: Container(
            padding: const EdgeInsets.all(KpbSpacing.md - 2),
            decoration: BoxDecoration(
              borderRadius: KpbRadius.mdBr,
              border: Border.all(
                color: post.isPinned
                    ? KpbColors.actionPrimary.withValues(alpha: 0.35)
                    : KpbColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CommunityTypeChip(type: post.type),
                    if (post.isPinned)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin_rounded,
                              size: 13, color: KpbColors.actionPrimary),
                          const SizedBox(width: 2),
                          Text(
                            'comm_pinned'.tr,
                            style: const TextStyle(
                              fontSize: KpbFontSize.xs,
                              fontWeight: FontWeight.w700,
                              color: KpbColors.actionPrimary,
                            ),
                          ),
                        ],
                      ),
                    if (post.hasVerifiedAnswer) const CommunityVerifiedPill(),
                  ],
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  post.title,
                  maxLines: dense ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: KpbFontSize.md,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: KpbColors.textPrimary,
                  ),
                ),
                if (!dense && post.excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    post.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: KpbFontSize.sm,
                      height: 1.45,
                      color: KpbColors.textSecondary,
                    ),
                  ),
                ],
                if (!dense && mentions.isNotEmpty) ...[
                  const SizedBox(height: KpbSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in mentions)
                        CommunityMentionChip(mention: m),
                    ],
                  ),
                ],
                if (post.moderation != null) ...[
                  const SizedBox(height: KpbSpacing.sm),
                  CommunityModerationNotice(
                    moderation: post.moderation!,
                    compact: true,
                  ),
                ],
                const SizedBox(height: KpbSpacing.sm + 2),
                CommunityAuthorLine(
                  author: post.author,
                  trailing: communityRelativeTime(post.createdAt),
                  avatarSize: 26,
                ),
                const SizedBox(height: KpbSpacing.sm),
                Wrap(
                  spacing: KpbSpacing.md,
                  runSpacing: 4,
                  children: [
                    _Counter(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: communityReplyCountLabel(post.replyCount),
                    ),
                    if (post.helpfulCount > 0)
                      _Counter(
                        icon: Icons.thumb_up_alt_outlined,
                        label: communityHelpfulCountLabel(post.helpfulCount),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: KpbColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: KpbFontSize.xs,
            fontWeight: FontWeight.w600,
            color: KpbColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Squelette d'une liste de publications (jamais un spinner seul).
class CommunityFeedSkeleton extends StatelessWidget {
  const CommunityFeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.only(bottom: KpbSpacing.sm + 4),
            padding: const EdgeInsets.all(KpbSpacing.md - 2),
            decoration: BoxDecoration(
              color: KpbColors.surface,
              borderRadius: KpbRadius.mdBr,
              border: Border.all(color: KpbColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KpbSkeletonBox(width: 90, height: 18, radius: KpbRadius.pill),
                SizedBox(height: KpbSpacing.sm + 2),
                KpbSkeletonBox(height: 16),
                SizedBox(height: 6),
                KpbSkeletonBox(width: 200, height: 14),
                SizedBox(height: KpbSpacing.sm + 4),
                Row(
                  children: [
                    KpbSkeletonBox(width: 26, height: 26, radius: 13),
                    SizedBox(width: KpbSpacing.sm),
                    KpbSkeletonBox(width: 110, height: 12),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un message inline (vide, erreur) dans une liste défilable.
class CommunityInlineMessage extends StatelessWidget {
  const CommunityInlineMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.md, vertical: KpbSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: KpbColors.actionPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: KpbColors.actionPrimary),
          ),
          const SizedBox(height: KpbSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KpbFontSize.md,
              fontWeight: FontWeight.w800,
              color: KpbColors.textPrimary,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KpbFontSize.sm,
                height: 1.45,
                color: KpbColors.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: KpbSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
