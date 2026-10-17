import 'package:flutter/foundation.dart';

import '../models/community.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Jetons de mention et hashtags (contrat §5.3).
//
// À l'écriture, chaque mention part dans `body` sous la forme
//   @[<libellé>](<type>:<id>)
// — jamais comme simple texte. Le compositeur, lui, montre à l'élève une
// puce « @Eiffel » : le texte édité contient le libellé seul, et la liste des
// mentions garde, à côté, la plage de chaque puce et son entité. Les deux
// sont réunies en jetons à l'envoi ([CommunityDraft.serialize]) et séparées à
// la modification d'une publication ([CommunityDraft.fromBody]).
//
// Une puce est ATOMIQUE : une frappe qui en touche l'intérieur la retire
// entière (le texte qui reste redevient du texte ordinaire), pour qu'un
// libellé modifié ne parte jamais avec l'identifiant d'une autre entité.
// ─────────────────────────────────────────────────────────────────────────────

/// L'expression exacte du contrat.
final RegExp communityMentionTokenPattern = RegExp(
  r'@\[([^\]\n]{1,80})\]\((scholarship|country|institution|program):([A-Za-z0-9_-]{1,64})\)',
);

final RegExp _mentionIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Hashtag : `#` + 2 à 40 lettres, chiffres ou `_` (Unicode), précédé d'un
/// début de texte ou d'un caractère qui n'est ni lettre, ni chiffre, ni `_`,
/// `&`, `/` ; un mot plus long que 40 n'est pas un hashtag.
final RegExp communityHashtagPattern = RegExp(
  r'(?<![\p{L}\p{N}_&/])#([\p{L}\p{N}_]{2,40})(?![\p{L}\p{N}_])',
  unicode: true,
);

/// Plafonds du contrat (§4.2).
abstract final class CommunityLimitsSpec {
  static const titleMin = 8;
  static const titleMax = 120;
  static const postBodyMin = 20;
  static const postBodyMax = 5000;
  static const replyBodyMin = 2;
  static const replyBodyMax = 3000;
  static const reportDetailsMax = 500;
  static const maxMentions = 10;
  static const maxHashtags = 10;
  static const mentionLabelMax = 80;
}

/// Un libellé utilisable dans un jeton : sans crochet ni retour à la ligne,
/// espaces de bord retirés, 80 caractères au plus. Vide → `null`.
String? sanitizeMentionLabel(String raw) {
  var label = raw
      .replaceAll(RegExp(r'[\[\]\n\r]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (label.isEmpty) return null;
  if (label.runes.length > CommunityLimitsSpec.mentionLabelMax) {
    label = String.fromCharCodes(
            label.runes.take(CommunityLimitsSpec.mentionLabelMax))
        .trim();
  }
  return label;
}

/// `@[libellé](type:id)`, ou `null` si l'identifiant ne respecte pas le
/// contrat (le texte n'enverrait alors qu'un `@` ordinaire, refusé nulle part
/// mais trompeur).
String? buildMentionToken({
  required CommunityEntityType type,
  required String id,
  required String label,
}) {
  final clean = sanitizeMentionLabel(label);
  if (clean == null || !_mentionIdPattern.hasMatch(id)) return null;
  return '@[$clean](${type.wire}:$id)';
}

/// Clé normalisée d'un hashtag : minuscules sans accents.
String normalizeHashtagKey(String raw) =>
    foldCommunityAccents(raw.replaceFirst(RegExp(r'^#'), '').toLowerCase());

/// Minuscules sans accents (la règle du serveur pour les hashtags et la
/// recherche, côté affichage seulement).
String foldCommunityAccents(String input) {
  const from = 'àáâäãåāèéêëēìíîïīòóôöõōùúûüūçñÿœæ';
  const to = 'aaaaaaaeeeeeiiiiioooooouuuuucnyoa';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    if (index == -1) {
      buffer.write(char);
    } else if (char == 'œ') {
      buffer.write('oe');
    } else if (char == 'æ') {
      buffer.write('ae');
    } else {
      buffer.write(to[index]);
    }
  }
  return buffer.toString();
}

/// Les hashtags d'un texte (clés normalisées, sans doublon, dans l'ordre).
List<String> extractCommunityHashtags(String text) {
  final out = <String>[];
  for (final match in communityHashtagPattern.allMatches(text)) {
    final key = normalizeHashtagKey(match.group(1)!);
    if (!out.contains(key)) out.add(key);
  }
  return out;
}

/// Les mentions DISTINCTES d'un corps sérialisé (une entité citée deux fois
/// compte une fois, comme au serveur).
int countDistinctMentionTokens(String body) {
  final refs = <String>{};
  for (final m in communityMentionTokenPattern.allMatches(body)) {
    refs.add('${m.group(2)}:${m.group(3)}');
  }
  return refs.length;
}

/// Découpe un corps sérialisé en segments, pour la PRÉVISUALISATION (le
/// serveur sert ses propres segments à la lecture : on ne les recalcule pas).
/// Les liens restent du texte : seul le serveur connaît la liste blanche.
List<CommunitySegment> parseCommunityBody(String body) {
  final segments = <CommunitySegment>[];
  void addText(String text) {
    if (text.isEmpty) return;
    var cursor = 0;
    for (final match in communityHashtagPattern.allMatches(text)) {
      if (match.start > cursor) {
        segments.add(CommunityTextSegment(text.substring(cursor, match.start)));
      }
      final display = match.group(1)!;
      segments.add(CommunityHashtagSegment(CommunityHashtag(
        tag: normalizeHashtagKey(display),
        display: display,
      )));
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.add(CommunityTextSegment(text.substring(cursor)));
    }
  }

  var cursor = 0;
  for (final match in communityMentionTokenPattern.allMatches(body)) {
    addText(body.substring(cursor, match.start));
    final type = CommunityEntityType.tryWire(match.group(2));
    if (type == null) {
      addText(match.group(0)!);
    } else {
      segments.add(CommunityMentionSegment(CommunityMention(
        type: type,
        id: match.group(3)!,
        label: match.group(1)!,
      )));
    }
    cursor = match.end;
  }
  addText(body.substring(cursor));
  return segments;
}

/// Texte brut d'un corps sérialisé : chaque jeton devient `@libellé`.
String plainTextOfCommunityBody(String body) => body.replaceAllMapped(
      communityMentionTokenPattern,
      (m) => '@${m.group(1)}',
    );

// ── Le brouillon du compositeur ─────────────────────────────────────────────

/// Une puce de mention dans le texte affiché : `[start, end)` couvre
/// `@libellé`.
@immutable
class CommunityDraftMention {
  const CommunityDraftMention({
    required this.start,
    required this.type,
    required this.id,
    required this.label,
  });

  final int start;
  final CommunityEntityType type;
  final String id;
  final String label;

  /// Le texte affiché de la puce.
  String get display => '@$label';
  int get end => start + display.length;
  String get ref => '${type.wire}:$id';

  CommunityDraftMention shift(int delta) => CommunityDraftMention(
        start: start + delta,
        type: type,
        id: id,
        label: label,
      );

  @override
  bool operator ==(Object other) =>
      other is CommunityDraftMention &&
      other.start == start &&
      other.type == type &&
      other.id == id &&
      other.label == label;

  @override
  int get hashCode => Object.hash(start, type, id, label);
}

/// Le texte du compositeur : ce que l'élève voit + les puces.
@immutable
class CommunityDraft {
  const CommunityDraft(this.text, [this.mentions = const []]);

  final String text;
  final List<CommunityDraftMention> mentions;

  /// Sépare un corps sérialisé (modification d'une publication) en texte
  /// affiché + puces.
  factory CommunityDraft.fromBody(String body) {
    final buffer = StringBuffer();
    final mentions = <CommunityDraftMention>[];
    var cursor = 0;
    for (final match in communityMentionTokenPattern.allMatches(body)) {
      buffer.write(body.substring(cursor, match.start));
      final type = CommunityEntityType.tryWire(match.group(2));
      final label = match.group(1)!;
      if (type == null) {
        buffer.write(match.group(0));
      } else {
        mentions.add(CommunityDraftMention(
          start: buffer.length,
          type: type,
          id: match.group(3)!,
          label: label,
        ));
        buffer.write('@$label');
      }
      cursor = match.end;
    }
    buffer.write(body.substring(cursor));
    return CommunityDraft(buffer.toString(), List.unmodifiable(mentions));
  }

  /// Le corps à envoyer : chaque puce redevient un jeton.
  String serialize() {
    final sorted = List<CommunityDraftMention>.of(mentions)
      ..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final mention in sorted) {
      if (mention.start < cursor || mention.end > text.length) continue;
      buffer.write(text.substring(cursor, mention.start));
      final token = buildMentionToken(
        type: mention.type,
        id: mention.id,
        label: mention.label,
      );
      buffer.write(token ?? mention.display);
      cursor = mention.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  /// Nombre d'entités distinctes citées.
  int get distinctMentionCount => mentions.map((m) => m.ref).toSet().length;

  /// Remplace `[start, end)` (le `@requête` en cours de saisie) par une puce
  /// suivie d'une espace. Rend le brouillon et la position du curseur.
  ({CommunityDraft draft, int cursor}) insertMention({
    required int start,
    required int end,
    required CommunityEntityType type,
    required String id,
    required String label,
  }) {
    final clean = sanitizeMentionLabel(label) ?? label;
    final display = '@$clean';
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(safeStart, text.length);
    final next =
        '${text.substring(0, safeStart)}$display ${text.substring(safeEnd)}';
    final delta = display.length + 1 - (safeEnd - safeStart);
    final kept = <CommunityDraftMention>[
      for (final m in mentions)
        if (m.end <= safeStart) m else if (m.start >= safeEnd) m.shift(delta),
      CommunityDraftMention(start: safeStart, type: type, id: id, label: clean),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return (
      draft: CommunityDraft(next, List.unmodifiable(kept)),
      cursor: safeStart + display.length + 1,
    );
  }

  /// Le brouillon après une frappe qui a transformé [text] en [next].
  ///
  /// La modification est localisée par préfixe et suffixe communs (un seul
  /// intervalle modifié, ce que produit toute frappe, collage ou
  /// suppression). Une puce entièrement avant est gardée, entièrement après
  /// est décalée, et une puce TOUCHÉE disparaît — son texte reste, comme
  /// texte ordinaire.
  CommunityDraft reconcile(String next) {
    if (next == text) return this;
    if (mentions.isEmpty) return CommunityDraft(next);
    var prefix = 0;
    final maxPrefix = text.length < next.length ? text.length : next.length;
    while (prefix < maxPrefix &&
        text.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < text.length - prefix &&
        suffix < next.length - prefix &&
        text.codeUnitAt(text.length - 1 - suffix) ==
            next.codeUnitAt(next.length - 1 - suffix)) {
      suffix++;
    }
    final oldEnd = text.length - suffix; // fin de la zone remplacée (ancien)
    final delta = next.length - text.length;
    final kept = <CommunityDraftMention>[];
    for (final m in mentions) {
      if (m.end <= prefix) {
        kept.add(m);
      } else if (m.start >= oldEnd) {
        kept.add(m.shift(delta));
      }
      // Sinon la puce chevauche la zone modifiée : elle est retirée.
    }
    // Garde-fou : une puce dont le texte ne correspond plus est retirée.
    final valid = kept.where((m) {
      if (m.start < 0 || m.end > next.length) return false;
      return next.substring(m.start, m.end) == m.display;
    }).toList(growable: false);
    return CommunityDraft(next, List.unmodifiable(valid));
  }
}

/// Une saisie d'autocomplétion en cours : `@eif` ou `#camp` juste avant le
/// curseur.
@immutable
class CommunityTrigger {
  const CommunityTrigger({
    required this.symbol,
    required this.start,
    required this.query,
  });

  /// `@` ou `#`.
  final String symbol;

  /// Position du symbole dans le texte affiché.
  final int start;

  /// Ce qui suit le symbole, jusqu'au curseur.
  final String query;

  bool get isMention => symbol == '@';
  int get end => start + 1 + query.length;
}

/// La saisie `@…` / `#…` qui se termine au curseur, ou `null`.
///
/// Une mention se cherche sur 1 à 60 caractères et peut contenir des espaces
/// (« @Université Laval ») mais pas de retour à la ligne ; un hashtag s'arrête
/// au premier caractère qui n'est ni lettre, ni chiffre, ni `_`. Le symbole
/// doit être en début de texte ou après un séparateur, et jamais à
/// l'intérieur d'une puce.
CommunityTrigger? activeCommunityTrigger(
  CommunityDraft draft,
  int cursor,
) {
  final text = draft.text;
  if (cursor < 0 || cursor > text.length) return null;
  for (final m in draft.mentions) {
    if (cursor > m.start && cursor <= m.end) return null;
  }
  final before = text.substring(0, cursor);
  final lastLine = before.lastIndexOf('\n');
  final lineStart = lastLine + 1;
  final line = before.substring(lineStart);

  // Hashtag : le mot courant.
  final hash =
      RegExp(r'(?<![\p{L}\p{N}_&/])#([\p{L}\p{N}_]{0,40})$', unicode: true)
          .firstMatch(line);
  if (hash != null) {
    return CommunityTrigger(
      symbol: '#',
      start: lineStart + hash.start,
      query: hash.group(1)!,
    );
  }

  // Mention : le dernier `@` de la ligne, hors puce, précédé d'un séparateur.
  final at = line.lastIndexOf('@');
  if (at == -1) return null;
  final absolute = lineStart + at;
  if (draft.mentions.any((m) => absolute >= m.start && absolute < m.end)) {
    return null;
  }
  if (at > 0 &&
      RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(line[at - 1])) {
    return null; // une adresse e-mail, pas une mention
  }
  final query = line.substring(at + 1);
  if (query.length > 60 || query.startsWith(' ')) return null;
  // Plus de deux espaces consécutifs : l'élève a fini sa phrase.
  if (query.contains('  ')) return null;
  return CommunityTrigger(symbol: '@', start: absolute, query: query);
}
