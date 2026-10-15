// KpbHaptics : une vibration par intention, et une surface tappable
// (KpbPressable) qui ne vibre plus à chaque appui.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/kpb_components.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Capture les appels `HapticFeedback.vibrate` envoyés à la plateforme.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String? ?? 'default');
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  group('KpbHaptics', () {
    testWidgets('chaque intention a sa vibration', (tester) async {
      final calls = _recordHaptics(tester);
      await KpbHaptics.selection();
      await KpbHaptics.confirm();
      await KpbHaptics.success();
      await KpbHaptics.error();
      expect(calls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    testWidgets('KpbPressable ne vibre pas à chaque tap', (tester) async {
      final calls = _recordHaptics(tester);
      var taps = 0;
      await tester.pumpWidget(_host(KpbPressable(
        onTap: () => taps++,
        child: const Text('appuie'),
      )));
      await tester.tap(find.text('appuie'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(calls, isEmpty);
    });

    testWidgets('KpbPressable(haptic: true) confirme', (tester) async {
      final calls = _recordHaptics(tester);
      await tester.pumpWidget(_host(KpbPressable(
        onTap: () {},
        haptic: true,
        child: const Text('valide'),
      )));
      await tester.tap(find.text('valide'));
      await tester.pumpAndSettle();
      expect(calls, ['HapticFeedbackType.lightImpact']);
    });
  });
}
