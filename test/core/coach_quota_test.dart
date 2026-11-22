import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/services/coach_service.dart';

void main() {
  group('CoachQuota.fromJson — API contract', () {
    test('reads quotaRemaining and quotaLimit from backend response', () {
      final quota = CoachQuota.fromJson({
        'quotaRemaining': 5,
        'quotaLimit': 5,
        'quotaResetAt': '2026-06-23',
      });
      expect(quota.remaining, 5);
      expect(quota.limit, 5);
      expect(quota.allowed, isTrue);
    });

    test('Pass Karatou : unlimited lu, absent = faux (backend plus ancien)', () {
      final pass = CoachQuota.fromJson({
        'quotaRemaining': 99,
        'quotaLimit': 100,
        'unlimited': true,
      });
      expect(pass.unlimited, isTrue);
      expect(pass.limit, 100);
      expect(CoachQuota.fromJson({'quotaRemaining': 5}).unlimited, isFalse);
    });

    test('allowed is false when quotaRemaining is 0', () {
      final quota = CoachQuota.fromJson({
        'quotaRemaining': 0,
        'quotaLimit': 5,
        'quotaResetAt': '2026-06-23',
      });
      expect(quota.remaining, 0);
      expect(quota.allowed, isFalse);
    });

    test(
        'gracefully defaults when keys are absent (legacy / unexpected payload)',
        () {
      final quota = CoachQuota.fromJson({});
      expect(quota.remaining, 0);
      expect(quota.limit, 5);
      expect(quota.allowed, isFalse);
    });
  });
}
