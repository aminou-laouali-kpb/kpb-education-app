// Relecture de la PR #407 : la 57 a mis en cache les messages d'un dossier du
// plus récent au plus ancien (ordre du serveur d'alors). Hors ligne, après la
// mise à jour, c'est ce cache qui s'affiche : il doit être retrié à la
// relecture, pas seulement au décodage réseau.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/repositories/local_app_repository.dart';

import '../../widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le fil relu du cache local se lit du plus ancien au plus récent',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await LocalAppRepository.create();
    final t0 = DateTime(2026, 10, 20, 10);
    CaseMessage msg(String id, DateTime at) => CaseMessage(
          id: id,
          senderName: 'KPB',
          senderRole: 'system',
          body: LocalizedText(fr: id, en: id),
          createdAt: at,
        );

    await repository.saveSnapshot(AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
      cases: [
        StudentCase(
          id: 'srv-1',
          referenceCode: 'KPB-2026-001',
          type: CaseType.consultation,
          title: const LocalizedText(fr: 'T', en: 'T'),
          description: const LocalizedText(fr: 'D', en: 'D'),
          contextLabel: const LocalizedText(fr: 'C', en: 'C'),
          status: CaseStatus.counselorAssigned,
          preferredContactMethod: ContactMethod.whatsapp,
          createdAt: t0,
          updatedAt: t0,
          nextStepTitle: const LocalizedText(fr: '', en: ''),
          nextStepDescription: const LocalizedText(fr: '', en: ''),
          timeline: const [],
          // Ordre de la 57 : le plus récent d'abord.
          messages: [
            msg('recent', t0.add(const Duration(hours: 2))),
            msg('ancien', t0),
          ],
          documentRequests: const [],
        ),
      ],
    ));

    final snapshot = await repository.loadSnapshot();

    expect(
        snapshot.cases.single.messages.map((m) => m.id), ['ancien', 'recent']);
  });
}
