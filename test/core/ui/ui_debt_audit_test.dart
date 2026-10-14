// Ratchet de la dette UI (sur le modèle de color_audit_test.dart) :
//
//  * `fontSize:` écrit en dur — l'échelle vit dans KpbFontSize / KpbTextStyles ;
//  * `Duration(` brut dans l'UI — le mouvement passe par KpbMotion.of(context),
//    qui sait se couper ;
//  * `HapticFeedback.` brut — les vibrations passent par KpbHaptics.
//
// Chaque fichier existant a un budget figé dans ui_debt_budget.dart. Un
// fichier ne peut pas dépasser son budget (zéro s'il n'y figure pas), et un
// budget trop haut doit être abaissé : les budgets ne font que descendre.
//
// Échappatoire documentée, ligne par ligne : `// kpb-allow-font-size: raison`
// ou `// kpb-allow-duration: raison` (minuteur réseau, délai métier…).

import 'package:flutter_test/flutter_test.dart';

import '../../support/lib_scan.dart';
import 'ui_debt_budget.dart';

const _tokens = 'lib/app/core/ui/app_tokens.dart';
const _haptics = 'lib/app/core/ui/kpb_haptics.dart';

bool _isUiFile(String path) =>
    path.startsWith('lib/app/features/') || path.startsWith('lib/app/core/ui/');

void _ratchet({
  required String name,
  required Map<String, int> actual,
  required Map<String, int> budget,
  required String hint,
}) {
  group(name, () {
    test('aucun fichier au-dessus de son budget', () {
      final violations = <String>[];
      actual.forEach((file, count) {
        final allowed = budget[file] ?? 0;
        if (count > allowed) {
          violations.add('  $file : $count (budget $allowed)');
        }
      });
      expect(violations, isEmpty, reason: '$hint\n${violations.join('\n')}');
    });

    test('les budgets ne peuvent que décroître (ratchet honnête)', () {
      final stale = <String>[];
      budget.forEach((file, allowed) {
        final count = actual[file] ?? 0;
        if (count < allowed) {
          stale.add('  $file : budget $allowed mais $count réels '
              '→ abaisse le budget à $count');
        }
      });
      expect(stale, isEmpty,
          reason: 'Progrès détecté : verrouille-le dans '
              'test/core/ui/ui_debt_budget.dart.\n${stale.join('\n')}');
    });
  });
}

void main() {
  _ratchet(
    name: 'fontSize écrit en dur',
    actual: countInLib(
      RegExp(r'fontSize:\s*\d'),
      allowMarker: 'kpb-allow-font-size',
      exempt: {_tokens},
    ),
    budget: fontSizeBudget,
    hint: 'Taille de police écrite en dur hors budget : utilise KpbFontSize '
        '(7 tailles, 12 à 28) ou un style de KpbTextStyles.',
  );

  _ratchet(
    name: 'Duration brute dans l\'UI',
    actual: countInLib(
      RegExp(r'\bDuration\('),
      allowMarker: 'kpb-allow-duration',
      exempt: {_tokens},
      include: _isUiFile,
    ),
    budget: durationBudget,
    hint: 'Durée brute hors budget dans lib/app/features ou lib/app/core/ui : '
        'utilise KpbMotion.of(context) (fast/base/page/reveal/scale), qui '
        'renvoie zéro quand l\'utilisateur coupe les animations.',
  );

  _ratchet(
    name: 'HapticFeedback brut',
    actual: countInLib(RegExp(r'HapticFeedback\.'), exempt: {_haptics}),
    budget: hapticBudget,
    hint: 'Vibration brute hors budget : utilise KpbHaptics.selection / '
        'confirm / success / error.',
  );
}
