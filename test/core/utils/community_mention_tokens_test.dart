// Jetons de mention (contrat §5.3) : la forme exacte, les libellés nettoyés,
// le brouillon du compositeur (puces atomiques), la détection `@` / `#`, et
// les hashtags normalisés.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/utils/community_mention_tokens.dart';

void main() {
  group('buildMentionToken', () {
    test('forme exacte du contrat', () {
      expect(
        buildMentionToken(
            type: CommunityEntityType.scholarship,
            id: 'clx12ab',
            label: 'Eiffel'),
        '@[Eiffel](scholarship:clx12ab)',
      );
      final token = buildMentionToken(
          type: CommunityEntityType.institution, id: 'uqam_1', label: 'UQAM');
      expect(communityMentionTokenPattern.hasMatch(token!), isTrue);
    });

    test('libellé nettoyé : crochets, retours, 80 caractères', () {
      expect(sanitizeMentionLabel(' Bourse [Eiffel]\n2026 '),
          'Bourse Eiffel 2026');
      expect(sanitizeMentionLabel('x' * 120)!.length, 80);
      expect(sanitizeMentionLabel('  '), isNull);
    });

    test('identifiant hors contrat : pas de jeton', () {
      expect(
          buildMentionToken(
              type: CommunityEntityType.country, id: 'a b', label: 'X'),
          isNull);
      expect(
          buildMentionToken(
              type: CommunityEntityType.country, id: 'x' * 65, label: 'X'),
          isNull);
    });
  });

  group('CommunityDraft', () {
    test('fromBody / serialize : aller-retour sans perte', () {
      const body = 'Qui a eu @[Bourse Eiffel](scholarship:eiffel) en '
          '@[France](country:fra) ?';
      final draft = CommunityDraft.fromBody(body);
      expect(draft.text, 'Qui a eu @Bourse Eiffel en @France ?');
      expect(draft.mentions, hasLength(2));
      expect(draft.mentions.first.start, 9);
      expect(draft.serialize(), body);
      expect(draft.distinctMentionCount, 2);
    });

    test('insertMention remplace la saisie et place le curseur', () {
      const draft = CommunityDraft('Qui a eu @eif');
      final result = draft.insertMention(
        start: 9,
        end: 13,
        type: CommunityEntityType.scholarship,
        id: 'eiffel',
        label: 'Bourse Eiffel',
      );
      expect(result.draft.text, 'Qui a eu @Bourse Eiffel ');
      expect(result.cursor, result.draft.text.length);
      expect(result.draft.serialize(),
          'Qui a eu @[Bourse Eiffel](scholarship:eiffel) ');
    });

    test('une frappe AVANT une puce la décale ; APRÈS ne la touche pas', () {
      final draft = CommunityDraft.fromBody('@[Canada](country:can) ok');
      final before = draft.reconcile('Le @Canada ok');
      expect(before.mentions.single.start, 3);
      expect(before.serialize(), 'Le @[Canada](country:can) ok');
      final after = draft.reconcile('@Canada ok !');
      expect(after.mentions.single.start, 0);
    });

    test('une frappe DANS une puce la retire entière (texte gardé)', () {
      final draft = CommunityDraft.fromBody('Vers @[Canada](country:can) !');
      final edited = draft.reconcile('Vers @Canda !');
      expect(edited.mentions, isEmpty);
      expect(edited.serialize(), 'Vers @Canda !');
    });

    test('effacer tout le texte retire toutes les puces', () {
      final draft = CommunityDraft.fromBody('@[Canada](country:can)');
      expect(draft.reconcile('').mentions, isEmpty);
    });

    test('la même entité citée deux fois compte une fois', () {
      final draft = CommunityDraft.fromBody(
          '@[Eiffel](scholarship:e1) et encore @[Eiffel](scholarship:e1)');
      expect(draft.mentions, hasLength(2));
      expect(draft.distinctMentionCount, 1);
      expect(countDistinctMentionTokens(draft.serialize()), 1);
    });
  });

  group('activeCommunityTrigger', () {
    test('@ en cours, avec espaces (« @Université La »)', () {
      const draft = CommunityDraft('Qui connaît @Université La');
      final trigger = activeCommunityTrigger(draft, draft.text.length)!;
      expect(trigger.isMention, isTrue);
      expect(trigger.query, 'Université La');
      expect(trigger.start, 12);
    });

    test('une adresse e-mail n’est pas une mention', () {
      const draft = CommunityDraft('mon mail aicha@exemple');
      expect(activeCommunityTrigger(draft, draft.text.length), isNull);
    });

    test('# en cours, s’arrête au premier séparateur', () {
      const draft = CommunityDraft('Sujet #Campus');
      final trigger = activeCommunityTrigger(draft, draft.text.length)!;
      expect(trigger.symbol, '#');
      expect(trigger.query, 'Campus');
      expect(activeCommunityTrigger(const CommunityDraft('#Campus fini'), 12),
          isNull);
    });

    test('jamais à l’intérieur d’une puce', () {
      final draft = CommunityDraft.fromBody('@[Canada](country:can)');
      expect(activeCommunityTrigger(draft, 4), isNull);
    });
  });

  group('hashtags', () {
    test('règle du contrat : début de texte ou séparateur, 2 à 40', () {
      expect(extractCommunityHashtags('#CampusFrance et #CV'),
          ['campusfrance', 'cv']);
      expect(extractCommunityHashtags('a#b c&#tag /#tag #x'), isEmpty);
      expect(extractCommunityHashtags('#${'a' * 41}'), isEmpty);
      expect(extractCommunityHashtags('#Études #etudes'), ['etudes']);
    });

    test('parseCommunityBody : mentions, hashtags, texte', () {
      final segments = parseCommunityBody(
          'Qui a eu @[Eiffel](scholarship:e1) ? #CampusFrance');
      expect(segments, hasLength(4));
      expect(segments[1], isA<CommunityMentionSegment>());
      expect(
          (segments[3] as CommunityHashtagSegment).hashtag.tag, 'campusfrance');
      expect(plainTextOfCommunityBody('@[Eiffel](scholarship:e1) ok'),
          '@Eiffel ok');
    });
  });
}
