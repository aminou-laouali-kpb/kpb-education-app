// FollowScholarshipButton + FollowPushPrimer (chantier G) :
//   · « Suivre » / « Suivie », cible ≥ 48 dp dans les trois formes ;
//   · passe par le favori local (marche hors ligne) ;
//   · au PREMIER « Suivre », la feuille d'explication précède la demande
//     système — seulement si l'autorisation n'est pas déjà accordée ;
//   · refus → « Notifications coupées » + bouton vers les réglages de l'app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/push_permission.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/scholarships/widgets/follow_push_primer.dart';
import 'package:karatou/app/features/scholarships/widgets/follow_scholarship_button.dart';

import '../../widget_test_helpers.dart';

class _FakePermission implements PushPermission {
  _FakePermission(this.current, {this.answer = PushPermissionStatus.granted});

  PushPermissionStatus current;
  final PushPermissionStatus answer;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<PushPermissionStatus> status() async => current;

  @override
  Future<PushPermissionStatus> request() async {
    requests++;
    current = answer;
    return answer;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class _MemoryPrimerStore implements FollowPrimerStore {
  bool shown = false;

  @override
  Future<bool> hasBeenShown() async => shown;

  @override
  Future<void> markShown() async => shown = true;
}

Future<void> _pump(
  WidgetTester tester, {
  FollowButtonVariant variant = FollowButtonVariant.compact,
  bool guest = false,
}) {
  return pumpTestApp(
    tester,
    child: Center(
      child: FollowScholarshipButton(
        scholarshipId: 'chevening',
        scholarshipTitle: 'Chevening',
        variant: variant,
      ),
    ),
    initialSnapshot: AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      isGuestMode: guest,
      profile: guest ? null : createTestProfile(),
    ),
  );
}

void main() {
  late _MemoryPrimerStore store;

  setUp(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
    store = _MemoryPrimerStore();
    FollowPushPrimer.debugStore = store;
  });

  tearDown(() {
    PushPermission.debugOverride = null;
    FollowPushPrimer.debugStore = null;
    RemoteFeatureFlags.resetForTest();
    resetGetxSingleton();
  });

  for (final variant in FollowButtonVariant.values) {
    testWidgets('cible tactile ≥ 48 dp (${variant.name})', (tester) async {
      PushPermission.debugOverride =
          _FakePermission(PushPermissionStatus.unavailable);
      await _pump(tester, variant: variant);
      final size =
          tester.getSize(find.byKey(const ValueKey('follow-chevening')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('« Suivre » passe par le favori local et devient « Suivie »',
      (tester) async {
    PushPermission.debugOverride =
        _FakePermission(PushPermissionStatus.unavailable);
    await _pump(tester);
    final controller = Get.find<AppController>();

    expect(find.text('follow_scholarship_follow'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.text('follow_scholarship_following'), findsOneWidget);
    expect(controller.isSaved(SavedItemType.scholarship, 'chevening'), isTrue);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('follow-chevening'))),
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();
    expect(find.text('follow_scholarship_follow'), findsOneWidget);
    expect(controller.isSaved(SavedItemType.scholarship, 'chevening'), isFalse);
  });

  testWidgets(
      'premier « Suivre » : la feuille d\'explication AVANT la demande système',
      (tester) async {
    final permission = _FakePermission(PushPermissionStatus.notDetermined);
    PushPermission.debugOverride = permission;
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-primer-sheet')), findsOneWidget);
    expect(permission.requests, 0,
        reason: 'la demande système ne part qu\'après l\'explication');

    await tester.tap(find.text('push_primer_enable'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.byKey(const ValueKey('push-denied-sheet')), findsNothing);
    expect(store.shown, isTrue);
  });

  testWidgets('refus : « Notifications coupées » et lien vers les réglages',
      (tester) async {
    final permission = _FakePermission(
      PushPermissionStatus.notDetermined,
      answer: PushPermissionStatus.denied,
    );
    PushPermission.debugOverride = permission;
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('push_primer_enable'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-denied-sheet')), findsOneWidget);
    expect(find.text('push_denied_title'), findsOneWidget);
    await tester.tap(find.text('push_denied_open_settings'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
  });

  testWidgets('« Plus tard » : aucune demande, et plus jamais de feuille',
      (tester) async {
    final permission = _FakePermission(PushPermissionStatus.notDetermined);
    PushPermission.debugOverride = permission;
    await _pump(tester);
    final finder = find.byKey(const ValueKey('follow-chevening'));

    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('push_primer_later'));
    await tester.pumpAndSettle();
    expect(permission.requests, 0);

    // Ne plus suivre puis suivre de nouveau : ce n'est plus le PREMIER suivi.
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('push-primer-sheet')), findsNothing);
  });

  testWidgets('autorisation déjà accordée : aucune feuille', (tester) async {
    final permission = _FakePermission(PushPermissionStatus.granted);
    PushPermission.debugOverride = permission;
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-primer-sheet')), findsNothing);
    expect(permission.requests, 0);
  });

  testWidgets('déjà refusée : directement « Notifications coupées »',
      (tester) async {
    final permission = _FakePermission(PushPermissionStatus.denied);
    PushPermission.debugOverride = permission;
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-primer-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('push-denied-sheet')), findsOneWidget);
    expect(permission.requests, 0,
        reason: 'le système ne reposerait pas la question');
  });

  testWidgets('invité : le suivi est local, aucune feuille', (tester) async {
    final permission = _FakePermission(PushPermissionStatus.notDetermined);
    PushPermission.debugOverride = permission;
    await _pump(tester, guest: true);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-primer-sheet')), findsNothing);
    expect(permission.requests, 0);
  });

  testWidgets(
      'drapeau followPushPrimer coupé : demande directe, sans feuille '
      '(jamais à l\'onboarding)', (tester) async {
    RemoteFeatureFlags.instance
        .debugSetFeaturesForTest(const {'followPushPrimer': false});
    final permission = _FakePermission(PushPermissionStatus.notDetermined);
    PushPermission.debugOverride = permission;
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('follow-chevening')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-primer-sheet')), findsNothing);
    expect(permission.requests, 1);
  });
}
