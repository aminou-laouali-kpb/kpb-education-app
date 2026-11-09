import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/features/ai_advisor/coach_quota_handoff.dart';

void main() {
  group('clipCoachHandoffTopic — topic line of the WhatsApp prefill', () {
    test('returns null when there is no user message yet', () {
      expect(clipCoachHandoffTopic(null), isNull);
      expect(clipCoachHandoffTopic(''), isNull);
      expect(clipCoachHandoffTopic('   '), isNull);
    });

    test('returns the trimmed message when short enough', () {
      expect(
        clipCoachHandoffTopic('  Quel budget pour le Canada ?  '),
        'Quel budget pour le Canada ?',
      );
    });

    test('clips long messages and appends an ellipsis', () {
      final long = 'a' * 500;
      final clipped = clipCoachHandoffTopic(long);
      expect(clipped, isNotNull);
      expect(clipped!.endsWith('…'), isTrue);
      // Clipped body + 1 ellipsis char, never longer than max + 1.
      expect(clipped.length, lessThanOrEqualTo(kCoachHandoffTopicMaxChars + 1));
    });

    test('does not leave a dangling space before the ellipsis', () {
      final long = '${'mot ' * 60}fin'; // spaces likely at the cut point
      final clipped = clipCoachHandoffTopic(long)!;
      expect(clipped.contains(' …'), isFalse);
    });
  });

  group('looksLikeCoachQuotaError — server-side quota refusal in the stream',
      () {
    test('matches the real backend refusal message', () {
      expect(
        looksLikeCoachQuotaError(
          'Quota hebdomadaire atteint (5 messages). '
          'Le Pass Karatou arrive bientôt.',
        ),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(looksLikeCoachQuotaError('weekly QUOTA reached'), isTrue);
    });

    test('does not match unrelated errors or null', () {
      expect(looksLikeCoachQuotaError('Groq timeout'), isFalse);
      expect(looksLikeCoachQuotaError(null), isFalse);
      expect(looksLikeCoachQuotaError(''), isFalse);
    });
  });
}
