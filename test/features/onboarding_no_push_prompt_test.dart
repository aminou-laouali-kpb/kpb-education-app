// L'onboarding ne demande plus l'autorisation des notifications (chantier G) :
// elle arrivait avant toute valeur et grillait l'invite unique d'iOS. Elle est
// faite au premier « Suivre », derrière une feuille d'explication.
//
// Garde de source, et pas de widget : `PushService.requestPermission()` est un
// no-op en test (service non initialisé), donc compter ses appels depuis
// l'écran ne prouverait rien (voir onboarding_submit_busy_test.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding_screen.dart ne touche plus au push', () {
    final source = File('lib/app/features/onboarding/onboarding_screen.dart')
        .readAsStringSync();
    expect(source.contains('PushService.instance'), isFalse);
    expect(source.contains('PushPermission'), isFalse);
    expect(source.contains('push_service.dart'), isFalse);
  });

  test('le seul déclencheur d\'office de la demande est le premier « Suivre »',
      () {
    final callers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains(
            RegExp(r'(PushPermission\.instance|permission)\.request\(\)')))
        .map((f) => f.path.replaceAll('\\', '/'))
        .toSet();
    expect(callers, {
      'lib/app/features/scholarships/widgets/follow_push_primer.dart',
      // Geste explicite de l'élève : la ligne « Activer » des préférences.
      'lib/app/features/notifications/notifications_screen.dart',
    });
  });
}
