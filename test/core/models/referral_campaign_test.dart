// La compétition vue par l'élève : lecture prudente, phase et compte à rebours
// à l'heure du SERVEUR, lien du règlement en https seulement.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/referral_campaign.dart';

Map<String, dynamic> standingJson({
  String phase = 'running',
  String status = 'live',
  bool provisional = true,
  Object? rank = 3,
  bool rankable = true,
  String serverTime = '2026-11-05T12:00:00.000Z',
}) =>
    {
      'participating': true,
      'campaign': {
        'slug': 'ambassadeurs-novembre-2026',
        'nameFr': 'Ambassadeurs — novembre 2026',
        'nameEn': 'Ambassadors — November 2026',
        'status': status,
        'phase': phase,
        'startsAt': '2026-10-31T23:00:00.000Z',
        'endsAt': '2026-11-10T23:00:00.000Z',
        'provisional': provisional,
      },
      'me': {
        'publicName': 'Aïcha K.',
        'city': 'Niamey',
        'code': 'KTOU-AK-1a2b3c',
        'rank': rank,
        'qualified': 12,
        'toReview': 2,
        'pending': 4,
        'rankable': rankable,
      },
      'serverTime': serverTime,
    };

void main() {
  group('lecture', () {
    test('un participant complet', () {
      final s = ReferralCampaignStanding.fromJson(standingJson());
      expect(s.participating, isTrue);
      expect(s.slug, 'ambassadeurs-novembre-2026');
      expect(s.name('fr'), 'Ambassadeurs — novembre 2026');
      expect(s.name('en'), 'Ambassadors — November 2026');
      expect(s.rank, 3);
      expect(s.qualified, 12);
      expect(s.toReview, 2);
      expect(s.pending, 4);
      expect(s.rankable, isTrue);
      expect(s.provisional, isTrue);
      expect(s.code, 'KTOU-AK-1a2b3c');
      expect(
        s.publicLeaderboardUrl,
        'https://kpbeducation.cloud/classement/?c=ambassadeurs-novembre-2026',
      );
    });

    test('non-participant, charge vide ou malformée : ne participe pas', () {
      for (final raw in <Object?>[
        null,
        <String, dynamic>{},
        {'participating': false},
        {'participating': 'true'},
        {'participating': true},
        {'participating': true, 'campaign': {}, 'me': {}},
        {
          'participating': true,
          'campaign': {'slug': ''},
          'me': {},
        },
      ]) {
        expect(ReferralCampaignStanding.fromJson(raw).participating, isFalse,
            reason: '$raw');
      }
    });

    test('rang 0 ou absent = pas classé ; compteurs négatifs = 0', () {
      final json = standingJson(rank: null);
      (json['me'] as Map)['qualified'] = -3;
      final s = ReferralCampaignStanding.fromJson(json);
      expect(s.rank, isNull);
      expect(s.qualified, 0);
      expect(ReferralCampaignStanding.fromJson(standingJson(rank: 0)).rank,
          isNull);
    });
  });

  group('phase et compte à rebours à l\'heure du serveur', () {
    // Le téléphone retarde de 2 h sur le serveur.
    final received = DateTime.utc(2026, 11, 5, 10);

    test('l\'écart d\'horloge est appliqué', () {
      final s = ReferralCampaignStanding.fromJson(standingJson(),
          receivedAt: received);
      expect(s.clockOffset, const Duration(hours: 2));
      expect(s.remainingAt(received), const Duration(days: 5, hours: 11));
    });

    test('à venir → en cours au début, sans rechargement', () {
      final s = ReferralCampaignStanding.fromJson(
        standingJson(phase: 'upcoming', serverTime: '2026-10-31T22:59:00.000Z'),
        receivedAt: DateTime.utc(2026, 10, 31, 22, 59),
      );
      final t0 = DateTime.utc(2026, 10, 31, 22, 59);
      expect(s.phaseAt(t0), ReferralCampaignPhase.upcoming);
      expect(s.remainingAt(t0), const Duration(minutes: 1));
      expect(s.phaseAt(t0.add(const Duration(minutes: 1))),
          ReferralCampaignPhase.running);
    });

    test('en cours → terminée à la fin', () {
      final s = ReferralCampaignStanding.fromJson(
        standingJson(serverTime: '2026-11-10T22:00:00.000Z'),
        receivedAt: DateTime.utc(2026, 11, 10, 22),
      );
      final end = DateTime.utc(2026, 11, 10, 23);
      expect(s.phaseAt(end.subtract(const Duration(seconds: 1))),
          ReferralCampaignPhase.running);
      expect(s.phaseAt(end), ReferralCampaignPhase.ended);
      expect(s.remainingAt(end), isNull);
    });

    test('close = terminée et non provisoire', () {
      final s = ReferralCampaignStanding.fromJson(
        standingJson(phase: 'ended', status: 'closed', provisional: false),
      );
      expect(s.phaseAt(DateTime.utc(2026, 11, 5)), ReferralCampaignPhase.ended);
      expect(s.provisional, isFalse);
    });

    test('CountdownParts arrondit à la minute supérieure', () {
      final p = CountdownParts.of(
          const Duration(days: 2, hours: 3, minutes: 4, seconds: 1));
      expect([p.days, p.hours, p.minutes], [2, 3, 5]);
      final z = CountdownParts.of(const Duration(seconds: -5));
      expect([z.days, z.hours, z.minutes], [0, 0, 0]);
    });
  });

  group('règlement (classement public)', () {
    test('https seulement, sinon pas de bouton', () {
      Map<String, dynamic> board(Object? url) => {
            'campaign': {'rulesUrl': url},
          };
      expect(referralRulesUrlFrom(board('https://kpbeducation.cloud/r')),
          'https://kpbeducation.cloud/r');
      for (final bad in <Object?>[
        null,
        '',
        'http://kpbeducation.cloud/r',
        'javascript:alert(1)',
        42,
      ]) {
        expect(referralRulesUrlFrom(board(bad)), isNull, reason: '$bad');
      }
      expect(referralRulesUrlFrom(null), isNull);
    });
  });
}
