import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/eligibility/eligibility_simulator_data.dart';

void main() {
  const engine = EligibilityEngine();

  test('returns a result for each MVP destination', () {
    final results = engine.evaluate(const EligibilityInput());
    expect(results.length, kEligibilityRules.length);
    expect(kEligibilityRules.length, 10);
  });

  test('results are sorted by score descending', () {
    final results = engine.evaluate(const EligibilityInput(
      monthlyBudgetEur: 1000,
      frenchLevel: LangLevel.bon,
      englishLevel: LangLevel.bon,
      studyLevel: 'M1',
    ));
    for (var i = 1; i < results.length; i++) {
      expect(results[i - 1].score >= results[i].score, isTrue);
    }
  });

  test('strong profile is green for affordable francophone destinations', () {
    final results = engine.evaluate(const EligibilityInput(
      studyLevel: 'M1',
      monthlyBudgetEur: 1200,
      frenchLevel: LangLevel.bon,
      englishLevel: LangLevel.bon,
    ));
    final morocco = results.firstWhere((r) => r.rule.countryId == 'mar');
    final france = results.firstWhere((r) => r.rule.countryId == 'fra');
    expect(morocco.verdict, EligibilityVerdict.eligible);
    expect(france.verdict, EligibilityVerdict.eligible);
  });

  test('budget below the country minimum forces a red verdict', () {
    final results = engine.evaluate(const EligibilityInput(
      studyLevel: 'L3',
      monthlyBudgetEur: 200, // below every country minimum
      frenchLevel: LangLevel.bon,
      englishLevel: LangLevel.bon,
    ));
    final usa = results.firstWhere((r) => r.rule.countryId == 'usa');
    expect(usa.verdict, EligibilityVerdict.notEligible);
  });

  test('zero language ability forces a red verdict on language', () {
    final results = engine.evaluate(const EligibilityInput(
      studyLevel: 'M2',
      monthlyBudgetEur: 2000,
      frenchLevel: LangLevel.faible,
      englishLevel: LangLevel.faible,
    ));
    // Every country requires at least one usable language.
    expect(
      results.every((r) => r.verdict == EligibilityVerdict.notEligible),
      isTrue,
    );
  });

  test('every result carries reasons and an advice string', () {
    final results = engine.evaluate(const EligibilityInput(
      studyLevel: 'M1',
      monthlyBudgetEur: 900,
    ));
    for (final r in results) {
      expect(r.reasons, isNotEmpty);
      expect(r.advice.trim(), isNotEmpty);
      expect(r.score, inInclusiveRange(0, 100));
    }
  });

  test('fromProfile prefills the five inputs', () {
    const profile = UserProfile(
      id: 'u1',
      accountType: AccountType.student,
      fullName: 'Awa Diallo',
      email: 'awa@example.com',
      phone: '',
      whatsApp: '',
      countryOfResidence: 'sen',
      preferredLanguage: 'fr',
      currentLevel: 'M1',
      bacSeries: 'C',
      monthlyBudgetEur: 850,
    );
    final input = EligibilityInput.fromProfile(profile);
    expect(input.studyLevel, 'M1');
    expect(input.bacSeries, 'C');
    expect(input.monthlyBudgetEur, 850);
  });
}
