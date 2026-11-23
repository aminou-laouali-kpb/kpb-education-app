import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/salon/salon_screen.dart';

import '../widget_test_helpers.dart';

class _MockApi extends Mock implements AppApiClient {}

void main() {
  late _MockApi mock;

  setUp(() {
    mock = _MockApi();
    // Salon event cards resolve the active locale via AppController; register a
    // minimal one (defaults to locale 'fr') so the widget can build in tests.
    Get.put<AppController>(
      AppController(repository: FakeRepository()),
      permanent: true,
    );
  });

  tearDown(Get.reset);

  testWidgets('shows KpbErrorState when listSalonEvents throws',
      (tester) async {
    when(() => mock.listSalonEvents()).thenThrow(Exception('network'));

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbErrorState), findsOneWidget);
    expect(find.text('salon_unavailable_title'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
  });

  testWidgets('shows KpbEmptyState when list returns empty', (tester) async {
    when(() => mock.listSalonEvents()).thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbEmptyState), findsOneWidget);
    expect(find.text('salon_no_edition_title'), findsOneWidget);
  });

  testWidgets('shows event row when list returns data', (tester) async {
    when(() => mock.listSalonEvents()).thenAnswer((_) async => [
          <String, dynamic>{
            'slug': 'spring-2026',
            'nameFr': 'Salon Printemps',
            'year': 2026,
            'startAt': '2026-06-01T10:00:00.000Z',
            'endAt': '2026-06-02T18:00:00.000Z',
            'descriptionFr': 'Universités invitées',
            'status': 'scheduled',
          },
        ]);

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Salon Printemps'), findsWidgets);
    expect(find.text('salon_view_sessions'), findsOneWidget);
  });

  testWidgets('retry calls listSalonEvents again after failure',
      (tester) async {
    var calls = 0;
    when(() => mock.listSalonEvents()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('fail');
      return <dynamic>[];
    });

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbErrorState), findsOneWidget);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();

    expect(find.byType(KpbEmptyState), findsOneWidget);
    expect(calls, 2);
  });

  group('inscription à une session', () {
    const event = <String, dynamic>{
      'slug': 'spring-2026',
      'nameFr': 'Salon Printemps',
      'year': 2026,
      'startAt': '2026-06-01T10:00:00.000Z',
      'endAt': '2026-06-02T18:00:00.000Z',
      'status': 'live',
    };
    Map<String, dynamic> edition({String? joinUrl}) => <String, dynamic>{
          ...event,
          'sessions': [
            <String, dynamic>{
              'id': 's1',
              'titleFr': 'Études au Canada',
              'status': 'live',
              if (joinUrl != null) 'joinUrl': joinUrl,
            },
          ],
        };

    Future<void> openEdition(WidgetTester tester) async {
      when(() => mock.listSalonEvents()).thenAnswer((_) async => [event]);
      await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('salon_view_sessions'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'le lien « Rejoindre » apparaît après l\'inscription, sans geste de '
        'l\'élève', (tester) async {
      // Le serveur ne sert `joinUrl` qu'aux élèves inscrits.
      var registered = false;
      when(() => mock.getSalonEvent('spring-2026')).thenAnswer((_) async =>
          edition(joinUrl: registered ? 'https://meet.example/s1' : null));
      when(() => mock.listMySalonRegistrations())
          .thenAnswer((_) async => registered
              ? [
                  <String, dynamic>{'sessionId': 's1'}
                ]
              : <dynamic>[]);
      when(() => mock.registerForSalonSession('s1')).thenAnswer((_) async {
        registered = true;
        return <String, dynamic>{'sessionId': 's1'};
      });

      await openEdition(tester);
      expect(find.text('salon_join'), findsNothing);
      verify(() => mock.getSalonEvent('spring-2026')).called(1);

      await tester.tap(find.text('salon_register'));
      await tester.pumpAndSettle();

      verify(() => mock.registerForSalonSession('s1')).called(1);
      // UNE relecture de l'édition, pas d'écran de chargement entre-temps.
      verify(() => mock.getSalonEvent('spring-2026')).called(1);
      expect(find.text('salon_join'), findsOneWidget);
      expect(find.text('salon_registration_confirmed'), findsNothing);
    });

    testWidgets('l\'annulation relit aussi l\'édition', (tester) async {
      var registered = true;
      when(() => mock.listMySalonRegistrations())
          .thenAnswer((_) async => registered
              ? [
                  <String, dynamic>{'sessionId': 's1'}
                ]
              : <dynamic>[]);
      when(() => mock.cancelSalonRegistration('s1')).thenAnswer((_) async {
        registered = false;
      });
      // Session programmée (pas encore en direct) : le bouton d'inscription
      // reste affiché, et c'est lui qui annule.
      when(() => mock.getSalonEvent('spring-2026')).thenAnswer((_) async {
        final e =
            edition(joinUrl: registered ? 'https://meet.example/s1' : null);
        ((e['sessions'] as List).first as Map<String, dynamic>)['status'] =
            'scheduled';
        return e;
      });

      await openEdition(tester);
      expect(find.text('salon_registration_confirmed'), findsOneWidget);
      verify(() => mock.getSalonEvent('spring-2026')).called(1);

      await tester.tap(find.text('salon_registration_confirmed'));
      await tester.pumpAndSettle();

      verify(() => mock.cancelSalonRegistration('s1')).called(1);
      verify(() => mock.getSalonEvent('spring-2026')).called(1);
      expect(find.text('salon_register'), findsOneWidget);
    });

    testWidgets('inscription en échec : pas de relecture, toast d\'erreur',
        (tester) async {
      when(() => mock.getSalonEvent('spring-2026'))
          .thenAnswer((_) async => edition());
      when(() => mock.listMySalonRegistrations())
          .thenAnswer((_) async => <dynamic>[]);
      when(() => mock.registerForSalonSession('s1'))
          .thenThrow(Exception('network'));

      await openEdition(tester);
      verify(() => mock.getSalonEvent('spring-2026')).called(1);

      await tester.tap(find.text('salon_register'));
      await tester.pumpAndSettle();

      verifyNever(() => mock.getSalonEvent('spring-2026'));
      expect(find.text('salon_register'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
