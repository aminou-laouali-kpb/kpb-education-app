// Un seul bandeau éphémère dans l'app : KpbToast.
//
// `Get.snackbar` (53 appels à l'origine) affichait des titres « KPB Education »,
// des couleurs et des durées différentes à chaque écran ; les SnackBar Material
// posées à la main faisaient pareil. Tout passe désormais par
// lib/app/core/ui/components/kpb_toast.dart, seul fichier autorisé à parler à
// GetSnackBar ou à ScaffoldMessenger.showSnackBar.

import 'package:flutter_test/flutter_test.dart';

import '../../support/lib_scan.dart';

const _toastFile = 'lib/app/core/ui/components/kpb_toast.dart';

void main() {
  test('aucun Get.snackbar( dans lib/ — utilise KpbToast', () {
    final hits = countInLib(RegExp(r'Get\.(raw)?snackbar\('));
    expect(
      hits,
      isEmpty,
      reason: 'Get.snackbar est interdit : KpbToast.success / error / info / '
          'offlinePending (lib/app/core/ui/components/kpb_toast.dart).\n'
          '${hits.entries.map((e) => '  ${e.key} : ${e.value}').join('\n')}',
    );
  });

  test('GetSnackBar et showSnackBar ne vivent que dans KpbToast', () {
    final hits = countInLib(
      RegExp(r'Get\.showSnackbar\(|GetSnackBar\(|\.showSnackBar\('),
      exempt: {_toastFile},
    );
    expect(
      hits,
      isEmpty,
      reason: 'Bandeau posé hors de KpbToast :\n'
          '${hits.entries.map((e) => '  ${e.key} : ${e.value}').join('\n')}',
    );
  });

  test('aucun bandeau titré « KPB Education »', () {
    final hits = countInLib(
      RegExp(
          r"KpbToast\.\w+\([^)]*title:\s*(AppConfig\.brandName|'KPB Education')"),
    );
    expect(hits, isEmpty);
  });
}
