// Contrat « Suivre » (chantier C) lu par l'app (chantier G) : formes de
// `GET /me/followed-scholarships`, bloc `follow` de la fiche, et LA règle de la
// ligne de statut — jamais « Ouverte » avant la date d'ouverture.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);

  group('FollowedScholarshipsPage.fromJson', () {
    test('lit items, total et globalOptOut du contrat', () {
      final page = FollowedScholarshipsPage.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 'chevening',
            'title': 'Chevening',
            'countryId': 'gbr',
            'countryName': 'Royaume-Uni',
            'displayStatus': 'opening_confirmed',
            'academicYear': '2027-2028',
            'opensAt': '2026-11-01T00:00:00.000Z',
            'closesAt': '2027-01-06T00:00:00.000Z',
            'estimatedOpenAt': null,
            'estimatedCloseAt': null,
            'deadlineAt': '2027-01-06T00:00:00.000Z',
            'dateConfidence': 'confirmed',
            'viaFavorite': true,
            'viaAlert': false,
            'notifyOpening': false,
            'detailAvailable': false,
          },
          // Ligne sans identifiant : ignorée, pas de plantage.
          <String, dynamic>{'title': 'Orpheline'},
          'pas une ligne',
        ],
        'total': 7,
        'globalOptOut': true,
      });

      expect(page.items, hasLength(1));
      expect(page.total, 7);
      expect(page.globalOptOut, isTrue);
      final item = page.items.single;
      expect(item.displayStatus, FollowedDisplayStatus.openingConfirmed);
      expect(item.notifyOpening, isFalse);
      expect(item.detailAvailable, isFalse);
      expect(item.opensAt, DateTime.utc(2026, 11, 1));
    });

    test('aller-retour par le cache : toJson puis fromJson', () {
      final page = FollowedScholarshipsPage(
        items: <FollowedScholarship>[
          FollowedScholarship(
            id: 'daad',
            title: 'DAAD',
            countryId: 'deu',
            countryName: 'Allemagne',
            displayStatus: FollowedDisplayStatus.forecast,
            estimatedOpenAt: DateTime.utc(2027, 2, 1),
            dateConfidence: 'estimated',
          ),
        ],
        total: 1,
        globalOptOut: false,
        fetchedAt: DateTime.utc(2026, 10, 1),
      );
      final copy = FollowedScholarshipsPage.fromJson(page.toJson());
      expect(copy.items.single.id, 'daad');
      expect(copy.items.single.displayStatus, FollowedDisplayStatus.forecast);
      expect(copy.items.single.estimatedOpenAt, DateTime.utc(2027, 2, 1));
      expect(copy.fetchedAt, DateTime.utc(2026, 10, 1));
    });
  });

  group('ScholarshipFollowState.tryParse', () {
    test('backend antérieur : bloc absent → null', () {
      expect(ScholarshipFollowState.tryParse(null), isNull);
      expect(ScholarshipFollowState.tryParse(<String, dynamic>{}), isNull);
    });

    test('lit le bloc additif de la fiche', () {
      final state = ScholarshipFollowState.tryParse(<String, dynamic>{
        'following': true,
        'viaFavorite': true,
        'viaAlert': false,
        'notifyOpening': false,
        'globalOptOut': true,
      })!;
      expect(state.following, isTrue);
      expect(state.notifyOpening, isFalse);
      expect(state.globalOptOut, isTrue);
    });

    test('LiveScholarshipModel porte le bloc `follow`', () {
      final model = LiveScholarshipModel.fromJson(<String, dynamic>{
        'id': 'chevening',
        'title': 'Chevening',
        'follow': <String, dynamic>{'following': true, 'notifyOpening': true},
      });
      expect(model.follow?.following, isTrue);
      expect(
        LiveScholarshipModel.fromJson(<String, dynamic>{'id': 'x'}).follow,
        isNull,
      );
    });
  });

  group('resolveScholarshipStatusLine — jamais « Ouverte » avant opensAt', () {
    test('cycle `open` dont l\'ouverture est à venir → « Ouvre le … »', () {
      final opens = now.add(const Duration(days: 3));
      final line = resolveScholarshipStatusLine(
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: opens,
        closesAt: now.add(const Duration(days: 60)),
        now: now,
      );
      expect(line, ScholarshipStatusLine(ScholarshipStatusKind.opensOn, opens));
    });

    test('cycle ouvert pour de vrai → « Ouverte · clôture le … »', () {
      final closes = now.add(const Duration(days: 30));
      final line = resolveScholarshipStatusLine(
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: now.subtract(const Duration(days: 2)),
        closesAt: closes,
        now: now,
      );
      expect(line, ScholarshipStatusLine(ScholarshipStatusKind.open, closes));
    });

    test('ouverte sans clôture confirmée : date à confirmer', () {
      final line = resolveScholarshipStatusLine(
        status: 'open',
        dateConfidence: 'estimated',
        deadlineAt: now.add(const Duration(days: 30)),
        now: now,
      );
      expect(line.kind, ScholarshipStatusKind.open);
      expect(line.date, isNull,
          reason: 'une clôture ESTIMÉE ne s\'affirme pas au jour près');
    });

    test('clôture confirmée passée → « Clôturée », même saisie `open`', () {
      final line = resolveScholarshipStatusLine(
        status: 'open',
        dateConfidence: 'confirmed',
        closesAt: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(line.kind, ScholarshipStatusKind.closed);
    });

    test('prévision estimée → « Ouverture estimée » (jamais « Ouvre le »)', () {
      final estimated = DateTime.utc(2027, 2, 1);
      final line = resolveScholarshipStatusLine(
        status: 'forecast',
        dateConfidence: 'estimated',
        estimatedOpenAt: estimated,
        now: now,
      );
      expect(
        line,
        ScholarshipStatusLine(
            ScholarshipStatusKind.openingEstimated, estimated),
      );
    });

    test('ouverture confirmée à venir (liste des suivis) → « Ouvre le »', () {
      final opens = now.add(const Duration(days: 10));
      final item = FollowedScholarship(
        id: 'x',
        title: 'X',
        countryId: '',
        countryName: '',
        displayStatus: FollowedDisplayStatus.openingConfirmed,
        opensAt: opens,
        dateConfidence: 'confirmed',
      );
      expect(item.statusLine(now: now).kind, ScholarshipStatusKind.opensOn);
    });

    test('la fiche applique la même règle via son cycle', () {
      final model = LiveScholarshipModel.fromJson(<String, dynamic>{
        'id': 'x',
        'currentCycle': <String, dynamic>{
          'id': 'c1',
          'academicYear': '2027-2028',
          'status': 'open',
          'dateConfidence': 'confirmed',
          'opensAt': now.add(const Duration(days: 5)).toIso8601String(),
          'closesAt': now.add(const Duration(days: 50)).toIso8601String(),
        },
      });
      expect(model.statusLine(now: now)?.kind, ScholarshipStatusKind.opensOn);
    });
  });
}
