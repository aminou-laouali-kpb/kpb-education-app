import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Communauté KPB (C1 + C2) — modèles de l'app.
//
// Source de vérité : docs/community-api-contract.md (community-api v1). Le
// contrat est ADDITIF : un champ nouveau est ignoré, une valeur d'énumération
// inconnue est tolérée (badge ignoré, segment rendu comme texte, type de
// publication lu comme « question »…). Rien ici ne lève sur une charge
// inattendue : un élément illisible est écarté, jamais deviné, et ne fait pas
// perdre les autres.
// ─────────────────────────────────────────────────────────────────────────────

String? _string(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? raw) {
  if (raw is int) return raw < 0 ? 0 : raw;
  if (raw is num) return raw < 0 ? 0 : raw.toInt();
  return 0;
}

bool _bool(Object? raw) => raw == true;

DateTime? _date(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw.trim());
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<T> _list<T>(Object? raw, T? Function(Map<String, dynamic>) parse) {
  if (raw is! List) return <T>[];
  final out = <T>[];
  for (final entry in raw) {
    final map = _map(entry);
    if (map == null) continue;
    final parsed = parse(map);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

// ── Énumérations ────────────────────────────────────────────────────────────

/// Les trois types de publication.
enum CommunityPostType {
  question('question'),
  experience('experience'),
  advice('advice');

  const CommunityPostType(this.wire);

  final String wire;

  /// Un type inconnu (contrat futur) se lit comme une question : c'est le type
  /// le plus neutre, et la carte reste lisible.
  static CommunityPostType fromWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return CommunityPostType.question;
  }

  static CommunityPostType? tryWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Les quatre familles d'entités mentionnables (bourse, pays, école,
/// formation).
enum CommunityEntityType {
  scholarship('scholarship'),
  country('country'),
  institution('institution'),
  program('program');

  const CommunityEntityType(this.wire);

  final String wire;

  static CommunityEntityType? tryWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Les badges de rôle, dans l'ordre stable du contrat.
enum CommunityBadge {
  kpbTeam('kpb_team'),
  kpbAdvisor('kpb_advisor'),
  verifiedAlumni('verified_alumni'),
  ambassador('ambassador');

  const CommunityBadge(this.wire);

  final String wire;

  static CommunityBadge? tryWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Qui parle : un membre, l'équipe KPB, un conseiller KPB.
enum CommunityAuthorKind { member, kpbTeam, kpbAdvisor }

/// Les fils de l'accueil.
enum CommunityFeedTab {
  forYou('for_you'),
  recent('recent'),
  unanswered('unanswered');

  const CommunityFeedTab(this.wire);

  final String wire;
}

/// Les motifs de signalement.
enum CommunityReportReason {
  scam('scam'),
  harassment('harassment'),
  inappropriate('inappropriate'),
  spam('spam'),
  personalInfo('personal_info'),
  misinformation('misinformation'),
  other('other');

  const CommunityReportReason(this.wire);

  final String wire;
}

/// Ce qu'on signale.
enum CommunityReportTarget {
  post('post'),
  reply('reply'),
  member('member');

  const CommunityReportTarget(this.wire);

  final String wire;
}

/// Pourquoi un contenu de l'auteur n'est pas (encore) visible des autres.
enum CommunityModerationReason {
  autoFilter('auto_filter'),
  reportsThreshold('reports_threshold'),
  newAccountReview('new_account_review'),
  moderation('moderation'),
  unknown('unknown');

  const CommunityModerationReason(this.wire);

  final String wire;

  static CommunityModerationReason fromWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return CommunityModerationReason.unknown;
  }
}

// ── Auteur, mentions, segments ──────────────────────────────────────────────

@immutable
class CommunityAuthor {
  const CommunityAuthor({
    required this.kind,
    required this.displayName,
    this.memberId,
    this.countryName,
    this.badges = const <CommunityBadge>[],
  });

  final CommunityAuthorKind kind;
  final String? memberId;
  final String displayName;
  final String? countryName;
  final List<CommunityBadge> badges;

  bool get isTeam =>
      kind == CommunityAuthorKind.kpbTeam ||
      kind == CommunityAuthorKind.kpbAdvisor;

  /// Les badges à afficher, dédoublonnés, dans l'ordre stable du contrat.
  List<CommunityBadge> get orderedBadges {
    final set = badges.toSet();
    if (kind == CommunityAuthorKind.kpbTeam) set.add(CommunityBadge.kpbTeam);
    if (kind == CommunityAuthorKind.kpbAdvisor) {
      set.add(CommunityBadge.kpbAdvisor);
    }
    return CommunityBadge.values.where(set.contains).toList(growable: false);
  }

  /// Initiales pour l'avatar (« Aïcha K. » → « AK »).
  String get initials {
    final parts = displayName
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String head(String s) => String.fromCharCode(s.runes.first);
    final first = head(parts.first);
    if (parts.length == 1) return first.toUpperCase();
    return (first + head(parts[1])).toUpperCase();
  }

  static CommunityAuthor fromJson(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final kind = switch (json['kind']) {
      'kpb_team' => CommunityAuthorKind.kpbTeam,
      'kpb_advisor' => CommunityAuthorKind.kpbAdvisor,
      _ => CommunityAuthorKind.member,
    };
    final badges = <CommunityBadge>[];
    final rawBadges = json['badges'];
    if (rawBadges is List) {
      for (final b in rawBadges) {
        final badge = CommunityBadge.tryWire(b);
        if (badge != null && !badges.contains(badge)) badges.add(badge);
      }
    }
    return CommunityAuthor(
      kind: kind,
      memberId: _string(json['memberId']),
      displayName: _string(json['displayName']) ?? '—',
      countryName: _string(json['countryName']),
      badges: List<CommunityBadge>.unmodifiable(badges),
    );
  }
}

/// Une entité du catalogue mentionnée (libellé figé à la publication).
@immutable
class CommunityMention {
  const CommunityMention({
    required this.type,
    required this.id,
    required this.label,
    this.countryId,
  });

  final CommunityEntityType type;
  final String id;
  final String label;
  final String? countryId;

  String get ref => '${type.wire}:$id';

  /// Un type inconnu ou un identifiant absent : écarté (rien à ouvrir).
  static CommunityMention? fromJson(Map<String, dynamic> json) {
    final type = CommunityEntityType.tryWire(json['type']);
    final id = _string(json['id']);
    if (type == null || id == null) return null;
    return CommunityMention(
      type: type,
      id: id,
      label: _string(json['label']) ?? id,
      countryId: _string(json['countryId']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CommunityMention && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Un hashtag : la clé normalisée et la forme saisie.
@immutable
class CommunityHashtag {
  const CommunityHashtag({required this.tag, required this.display});

  final String tag;
  final String display;

  static CommunityHashtag? fromJson(Map<String, dynamic> json) {
    final tag = _string(json['tag']);
    if (tag == null) return null;
    return CommunityHashtag(tag: tag, display: _string(json['display']) ?? tag);
  }
}

/// Un morceau du corps déjà découpé par le serveur.
sealed class CommunitySegment {
  const CommunitySegment();

  /// `kind` inconnu : rendu comme texte s'il a un champ `text`, sinon ignoré.
  static CommunitySegment? fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'mention':
        final mention = CommunityMention.fromJson(json);
        if (mention != null) return CommunityMentionSegment(mention);
        final label = _string(json['label']);
        return label == null ? null : CommunityTextSegment('@$label');
      case 'hashtag':
        final tag = _string(json['tag']);
        if (tag == null) return null;
        return CommunityHashtagSegment(
          CommunityHashtag(tag: tag, display: _string(json['display']) ?? tag),
        );
      case 'link':
        final url = _string(json['url']);
        final text = json['text'] is String ? json['text'] as String : url;
        final uri = url == null ? null : Uri.tryParse(url);
        // Un lien ne s'ouvre qu'en http(s) : toute autre forme reste du texte.
        if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
          return text == null ? null : CommunityTextSegment(text);
        }
        return CommunityLinkSegment(url: url!, text: text ?? url);
      default:
        final text = json['text'];
        return text is String ? CommunityTextSegment(text) : null;
    }
  }
}

class CommunityTextSegment extends CommunitySegment {
  const CommunityTextSegment(this.text);
  final String text;
}

class CommunityMentionSegment extends CommunitySegment {
  const CommunityMentionSegment(this.mention);
  final CommunityMention mention;
}

class CommunityHashtagSegment extends CommunitySegment {
  const CommunityHashtagSegment(this.hashtag);
  final CommunityHashtag hashtag;
}

class CommunityLinkSegment extends CommunitySegment {
  const CommunityLinkSegment({required this.url, required this.text});
  final String url;
  final String text;
}

// ── Contenus ────────────────────────────────────────────────────────────────

@immutable
class CommunityViewer {
  const CommunityViewer({
    this.isAuthor = false,
    this.hasMarkedHelpful = false,
    this.isFollowing = false,
    this.canEdit = false,
    this.canDelete = false,
    this.editableUntil,
  });

  final bool isAuthor;
  final bool hasMarkedHelpful;
  final bool isFollowing;
  final bool canEdit;
  final bool canDelete;
  final DateTime? editableUntil;

  /// La fenêtre de 15 min est-elle encore ouverte à [now] ?
  bool canEditAt(DateTime now) {
    if (!canEdit) return false;
    final until = editableUntil;
    return until == null || now.isBefore(until);
  }

  CommunityViewer copyWith({bool? hasMarkedHelpful, bool? isFollowing}) =>
      CommunityViewer(
        isAuthor: isAuthor,
        hasMarkedHelpful: hasMarkedHelpful ?? this.hasMarkedHelpful,
        isFollowing: isFollowing ?? this.isFollowing,
        canEdit: canEdit,
        canDelete: canDelete,
        editableUntil: editableUntil,
      );

  static CommunityViewer fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return const CommunityViewer();
    return CommunityViewer(
      isAuthor: _bool(json['isAuthor']),
      hasMarkedHelpful: _bool(json['hasMarkedHelpful']),
      isFollowing: _bool(json['isFollowing']),
      canEdit: _bool(json['canEdit']),
      canDelete: _bool(json['canDelete']),
      editableUntil: _date(json['editableUntil']),
    );
  }
}

/// `moderation` : servi à l'auteur seul pour un contenu non visible.
@immutable
class CommunityModeration {
  const CommunityModeration({
    required this.pending,
    required this.reason,
    this.since,
  });

  /// Vrai : « en attente de revue » ; faux : masqué par la modération.
  final bool pending;
  final CommunityModerationReason reason;
  final DateTime? since;

  static CommunityModeration? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    return CommunityModeration(
      // Un statut inconnu se lit « en attente » : le message le plus doux.
      pending: json['status'] != 'hidden',
      reason: CommunityModerationReason.fromWire(json['reason']),
      since: _date(json['since']),
    );
  }
}

/// Une publication telle qu'une liste la sert ; [body] et [segments] ne sont
/// renseignés qu'au détail.
@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    this.excerpt = '',
    this.createdAt,
    this.editedAt,
    this.lastActivityAt,
    this.replyCount = 0,
    this.helpfulCount = 0,
    this.hasVerifiedAnswer = false,
    this.isPinned = false,
    this.mentions = const <CommunityMention>[],
    this.hashtags = const <CommunityHashtag>[],
    this.viewer = const CommunityViewer(),
    this.moderation,
    this.forYouReasons = const <String>[],
    this.body,
    this.segments,
  });

  final String id;
  final CommunityPostType type;
  final String title;
  final String excerpt;
  final CommunityAuthor author;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? lastActivityAt;
  final int replyCount;
  final int helpfulCount;
  final bool hasVerifiedAnswer;
  final bool isPinned;
  final List<CommunityMention> mentions;
  final List<CommunityHashtag> hashtags;
  final CommunityViewer viewer;
  final CommunityModeration? moderation;
  final List<String> forYouReasons;

  /// Détail seulement : texte brut avec jetons canoniques.
  final String? body;

  /// Détail seulement : le corps déjà découpé.
  final List<CommunitySegment>? segments;

  bool get isDetail => body != null;

  CommunityPost copyWith({
    int? replyCount,
    int? helpfulCount,
    CommunityViewer? viewer,
  }) =>
      CommunityPost(
        id: id,
        type: type,
        title: title,
        excerpt: excerpt,
        author: author,
        createdAt: createdAt,
        editedAt: editedAt,
        lastActivityAt: lastActivityAt,
        replyCount: replyCount ?? this.replyCount,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        hasVerifiedAnswer: hasVerifiedAnswer,
        isPinned: isPinned,
        mentions: mentions,
        hashtags: hashtags,
        viewer: viewer ?? this.viewer,
        moderation: moderation,
        forYouReasons: forYouReasons,
        body: body,
        segments: segments,
      );

  static CommunityPost? fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    if (id == null) return null;
    final rawSegments = json['segments'];
    final reasons = json['forYouReasons'];
    return CommunityPost(
      id: id,
      type: CommunityPostType.fromWire(json['type']),
      title: _string(json['title']) ?? '',
      excerpt: json['excerpt'] is String ? (json['excerpt'] as String) : '',
      author: CommunityAuthor.fromJson(json['author']),
      createdAt: _date(json['createdAt']),
      editedAt: _date(json['editedAt']),
      lastActivityAt: _date(json['lastActivityAt']),
      replyCount: _int(json['replyCount']),
      helpfulCount: _int(json['helpfulCount']),
      hasVerifiedAnswer: _bool(json['hasVerifiedAnswer']),
      isPinned: _bool(json['isPinned']),
      mentions: List<CommunityMention>.unmodifiable(
          _list(json['mentions'], CommunityMention.fromJson)),
      hashtags: List<CommunityHashtag>.unmodifiable(
          _list(json['hashtags'], CommunityHashtag.fromJson)),
      viewer: CommunityViewer.fromJson(json['viewer']),
      moderation: CommunityModeration.fromJson(json['moderation']),
      forYouReasons: reasons is List
          ? List<String>.unmodifiable(reasons.whereType<String>())
          : const <String>[],
      body: json['body'] is String ? json['body'] as String : null,
      segments: rawSegments is List
          ? List<CommunitySegment>.unmodifiable(
              _list(rawSegments, CommunitySegment.fromJson))
          : null,
    );
  }
}

@immutable
class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.postId,
    required this.author,
    this.body = '',
    this.segments = const <CommunitySegment>[],
    this.mentions = const <CommunityMention>[],
    this.createdAt,
    this.editedAt,
    this.helpfulCount = 0,
    this.isVerified = false,
    this.verifiedAt,
    this.viewer = const CommunityViewer(),
    this.moderation,
  });

  final String id;
  final String postId;
  final String body;
  final List<CommunitySegment> segments;
  final List<CommunityMention> mentions;
  final CommunityAuthor author;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final int helpfulCount;
  final bool isVerified;
  final DateTime? verifiedAt;
  final CommunityViewer viewer;
  final CommunityModeration? moderation;

  CommunityReply copyWith({int? helpfulCount, CommunityViewer? viewer}) =>
      CommunityReply(
        id: id,
        postId: postId,
        body: body,
        segments: segments,
        mentions: mentions,
        author: author,
        createdAt: createdAt,
        editedAt: editedAt,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        isVerified: isVerified,
        verifiedAt: verifiedAt,
        viewer: viewer ?? this.viewer,
        moderation: moderation,
      );

  static CommunityReply? fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    if (id == null) return null;
    final body = json['body'] is String ? json['body'] as String : '';
    final segments = _list(json['segments'], CommunitySegment.fromJson);
    return CommunityReply(
      id: id,
      postId: _string(json['postId']) ?? '',
      body: body,
      // Un serveur qui n'aurait pas découpé : le corps brut, en texte.
      segments: List<CommunitySegment>.unmodifiable(
        segments.isEmpty && body.isNotEmpty
            ? <CommunitySegment>[CommunityTextSegment(body)]
            : segments,
      ),
      mentions: List<CommunityMention>.unmodifiable(
          _list(json['mentions'], CommunityMention.fromJson)),
      author: CommunityAuthor.fromJson(json['author']),
      createdAt: _date(json['createdAt']),
      editedAt: _date(json['editedAt']),
      helpfulCount: _int(json['helpfulCount']),
      isVerified: _bool(json['isVerified']),
      verifiedAt: _date(json['verifiedAt']),
      viewer: CommunityViewer.fromJson(json['viewer']),
      moderation: CommunityModeration.fromJson(json['moderation']),
    );
  }
}

/// Une page d'une liste à curseur (`{items, nextCursor}`).
@immutable
class CommunityPage<T> {
  const CommunityPage({
    required this.items,
    this.nextCursor,
    this.pinned = const [],
  });

  final List<T> items;

  /// Opaque : renvoyé tel quel, jamais interprété. `null` = fin de liste.
  final String? nextCursor;

  /// Fil seulement, première page : les épinglées (≤ 3).
  final List<T> pinned;

  bool get hasMore => nextCursor != null;

  static CommunityPage<T> fromJson<T>(
    Object? raw,
    T? Function(Map<String, dynamic>) parse, {
    String itemsKey = 'items',
  }) {
    final json = _map(raw) ?? const <String, dynamic>{};
    return CommunityPage<T>(
      items: List<T>.unmodifiable(_list(json[itemsKey], parse)),
      nextCursor: _string(json['nextCursor']),
      pinned: List<T>.unmodifiable(_list(json['pinned'], parse)),
    );
  }
}

/// `GET /community/posts/:id` : la publication et la première page des
/// réponses.
@immutable
class CommunityPostDetail {
  const CommunityPostDetail({required this.post, required this.replies});

  final CommunityPost post;
  final CommunityPage<CommunityReply> replies;

  static CommunityPostDetail? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final postJson = _map(json['post']);
    final post = postJson == null ? null : CommunityPost.fromJson(postJson);
    if (post == null) return null;
    return CommunityPostDetail(
      post: post,
      replies: CommunityPage.fromJson(json['replies'], CommunityReply.fromJson),
    );
  }
}

// ── Membre, charte ──────────────────────────────────────────────────────────

@immutable
class CommunityCharterRule {
  const CommunityCharterRule({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  static CommunityCharterRule? fromJson(Map<String, dynamic> json) {
    final title = _string(json['title']);
    if (title == null) return null;
    return CommunityCharterRule(
      id: _string(json['id']) ?? title,
      title: title,
      body: _string(json['body']) ?? '',
    );
  }
}

@immutable
class CommunityCharter {
  const CommunityCharter({
    required this.currentVersion,
    this.acceptedVersion,
    this.acceptedAt,
    this.required = true,
    this.title,
    this.rules = const <CommunityCharterRule>[],
  });

  final String currentVersion;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  /// Vrai tant que la version acceptée n'est pas la courante.
  final bool required;
  final String? title;
  final List<CommunityCharterRule> rules;

  CommunityCharter accepted(String version, DateTime? at) => CommunityCharter(
        currentVersion: currentVersion,
        acceptedVersion: version,
        acceptedAt: at,
        required: version != currentVersion,
        title: title,
        rules: rules,
      );

  static CommunityCharter? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final current = _string(json['currentVersion']);
    if (current == null) return null;
    final accepted = _string(json['acceptedVersion']);
    return CommunityCharter(
      currentVersion: current,
      acceptedVersion: accepted,
      acceptedAt: _date(json['acceptedAt']),
      // `required` absent : déduit des deux versions (prudent : on demande).
      required: json['required'] is bool
          ? json['required'] as bool
          : accepted != current,
      title: _string(json['title']),
      rules: List<CommunityCharterRule>.unmodifiable(
          _list(json['rules'], CommunityCharterRule.fromJson)),
    );
  }
}

@immutable
class CommunityRestriction {
  const CommunityRestriction({
    required this.isBan,
    this.until,
    this.reason,
  });

  final bool isBan;
  final DateTime? until;
  final String? reason;

  static CommunityRestriction? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    return CommunityRestriction(
      isBan: json['kind'] == 'ban',
      until: _date(json['until']),
      reason: _string(json['reason']),
    );
  }
}

@immutable
class CommunityStats {
  const CommunityStats({
    this.helpfulAnswersCount = 0,
    this.postsCount = 0,
    this.repliesCount = 0,
  });

  final int helpfulAnswersCount;
  final int postsCount;
  final int repliesCount;

  static CommunityStats fromJson(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    return CommunityStats(
      helpfulAnswersCount: _int(json['helpfulAnswersCount']),
      postsCount: _int(json['postsCount']),
      repliesCount: _int(json['repliesCount']),
    );
  }
}

@immutable
class CommunityLimits {
  const CommunityLimits({
    this.newAccount = false,
    this.postsPerDay = 0,
    this.postsToday = 0,
    this.repliesPerHour = 0,
    this.repliesThisHour = 0,
  });

  final bool newAccount;
  final int postsPerDay;
  final int postsToday;
  final int repliesPerHour;
  final int repliesThisHour;

  /// Le quota de publications du jour est-il atteint ? (0 = inconnu → non.)
  bool get postsExhausted => postsPerDay > 0 && postsToday >= postsPerDay;

  static CommunityLimits fromJson(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    return CommunityLimits(
      newAccount: _bool(json['newAccount']),
      postsPerDay: _int(json['postsPerDay']),
      postsToday: _int(json['postsToday']),
      repliesPerHour: _int(json['repliesPerHour']),
      repliesThisHour: _int(json['repliesThisHour']),
    );
  }
}

/// `GET /community/me`.
@immutable
class CommunityMe {
  const CommunityMe({
    required this.member,
    this.charter,
    this.restriction,
    this.limits = const CommunityLimits(),
    this.stats = const CommunityStats(),
    this.notificationsOptedOut = false,
  });

  final CommunityAuthor member;
  final CommunityCharter? charter;
  final CommunityRestriction? restriction;
  final CommunityLimits limits;
  final CommunityStats stats;
  final bool notificationsOptedOut;

  /// La charte doit-elle être (ré)acceptée avant d'écrire ?
  bool get charterRequired => charter?.required ?? true;

  CommunityMe withCharter(CommunityCharter charter) => CommunityMe(
        member: member,
        charter: charter,
        restriction: restriction,
        limits: limits,
        stats: stats,
        notificationsOptedOut: notificationsOptedOut,
      );

  static CommunityMe? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    return CommunityMe(
      member: CommunityAuthor.fromJson(json['member']),
      charter: CommunityCharter.fromJson(json['charter']),
      restriction: CommunityRestriction.fromJson(json['restriction']),
      limits: CommunityLimits.fromJson(json['limits']),
      stats: CommunityStats.fromJson(json['stats']),
      notificationsOptedOut: _bool(json['notificationsOptedOut']),
    );
  }
}

/// `GET /community/members/:memberId`.
@immutable
class CommunityMemberProfile {
  const CommunityMemberProfile({
    required this.member,
    this.stats = const CommunityStats(),
    this.memberSince,
    this.isMe = false,
    this.isBlocked = false,
  });

  final CommunityAuthor member;
  final CommunityStats stats;

  /// Mois `AAAA-MM` (jamais la date exacte).
  final String? memberSince;
  final bool isMe;
  final bool isBlocked;

  CommunityMemberProfile withBlocked(bool blocked) => CommunityMemberProfile(
        member: member,
        stats: stats,
        memberSince: memberSince,
        isMe: isMe,
        isBlocked: blocked,
      );

  static CommunityMemberProfile? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final viewer = _map(json['viewer']) ?? const <String, dynamic>{};
    final since = _string(json['memberSince']);
    return CommunityMemberProfile(
      member: CommunityAuthor.fromJson(json['member']),
      stats: CommunityStats.fromJson(json['stats']),
      memberSince: since != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(since)
          ? since
          : null,
      isMe: _bool(viewer['isMe']),
      isBlocked: _bool(viewer['isBlocked']),
    );
  }
}

/// Une ligne de `GET /community/blocks`.
@immutable
class CommunityBlockedMember {
  const CommunityBlockedMember({required this.member, this.blockedAt});

  final CommunityAuthor member;
  final DateTime? blockedAt;

  static CommunityBlockedMember? fromJson(Map<String, dynamic> json) {
    final member = CommunityAuthor.fromJson(json['member']);
    if (member.memberId == null) return null;
    return CommunityBlockedMember(
      member: member,
      blockedAt: _date(json['blockedAt']),
    );
  }
}

// ── Espaces, compteurs, autocomplétion ──────────────────────────────────────

/// Une référence d'entité (`type:id`) et son nombre de discussions.
@immutable
class CommunityEntityCount {
  const CommunityEntityCount({
    required this.type,
    required this.id,
    required this.discussionCount,
  });

  final CommunityEntityType type;
  final String id;
  final int discussionCount;

  static CommunityEntityCount? fromJson(Map<String, dynamic> json) {
    final type = CommunityEntityType.tryWire(json['type']);
    final id = _string(json['id']);
    if (type == null || id == null) return null;
    return CommunityEntityCount(
      type: type,
      id: id,
      discussionCount: _int(json['discussionCount']),
    );
  }
}

/// `GET /community/entities/:type/:id`.
@immutable
class CommunityEntitySpace {
  const CommunityEntitySpace({
    required this.entity,
    required this.discussionCount,
    required this.page,
  });

  final CommunityMention entity;
  final int discussionCount;
  final CommunityPage<CommunityPost> page;

  static CommunityEntitySpace? fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final entityJson = _map(json['entity']);
    final entity =
        entityJson == null ? null : CommunityMention.fromJson(entityJson);
    if (entity == null) return null;
    return CommunityEntitySpace(
      entity: entity,
      discussionCount: _int(json['discussionCount']),
      page: CommunityPage.fromJson(json, CommunityPost.fromJson),
    );
  }
}

/// Une suggestion d'autocomplétion `@`.
@immutable
class CommunityMentionSuggestion {
  const CommunityMentionSuggestion({
    required this.type,
    required this.id,
    required this.label,
    this.subtitle,
    this.countryId,
  });

  final CommunityEntityType type;
  final String id;
  final String label;
  final String? subtitle;
  final String? countryId;

  static CommunityMentionSuggestion? fromJson(Map<String, dynamic> json) {
    final type = CommunityEntityType.tryWire(json['type']);
    final id = _string(json['id']);
    final label = _string(json['label']);
    if (type == null || id == null || label == null) return null;
    return CommunityMentionSuggestion(
      type: type,
      id: id,
      label: label,
      subtitle: _string(json['subtitle']),
      countryId: _string(json['countryId']),
    );
  }
}

/// Une suggestion d'autocomplétion `#` (et les hashtags tendance).
@immutable
class CommunityHashtagSuggestion {
  const CommunityHashtagSuggestion({
    required this.tag,
    required this.display,
    this.postCount = 0,
  });

  final String tag;
  final String display;
  final int postCount;

  static CommunityHashtagSuggestion? fromJson(Map<String, dynamic> json) {
    final tag = _string(json['tag']);
    if (tag == null) return null;
    return CommunityHashtagSuggestion(
      tag: tag,
      display: _string(json['display']) ?? tag,
      postCount: _int(json['postCount']),
    );
  }
}

// ── Échecs ──────────────────────────────────────────────────────────────────

/// Ce qu'un écran doit savoir d'un échec, sans le corps de la réponse.
enum CommunityFailure {
  /// Drapeau coupé côté serveur (404 `community_disabled`) ou routes absentes.
  disabled,
  offline,
  timeout,
  unauthorized,

  /// Compte parent / partenaire.
  studentsOnly,
  charterRequired,
  charterOutdated,
  readOnly,
  rateLimited,
  notFound,
  notAuthor,
  editWindowClosed,
  postNotOpen,
  invalidMention,
  tooManyMentions,
  tooManyHashtags,
  invalidCursor,
  cannotReactOwn,
  cannotBlockSelf,
  cannotReportSelf,
  cannotBlockTeam,

  /// 400 de validation de forme (longueurs…).
  validation,
  server,
  invalid,
}

class CommunityException implements Exception {
  const CommunityException(
    this.failure, {
    this.statusCode,
    this.code,
    this.details = const <String, dynamic>{},
    this.retryAfterSeconds,
  });

  final CommunityFailure failure;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic> details;
  final int? retryAfterSeconds;

  @override
  String toString() =>
      'CommunityException(${failure.name}, status: $statusCode, code: $code)';
}
