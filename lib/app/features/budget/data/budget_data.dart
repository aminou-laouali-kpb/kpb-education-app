// Living-cost model for the budget simulator.
//
// Launch scope = the locked destination countries (France, Canada, USA,
// Morocco, Turkey, United Kingdom, Germany, Spain, UAE, China).
// Each profile carries the same nine spending categories, in the same order,
// so the UI can map a category index to a fixed icon/colour palette.

import 'package:get/get.dart';

class BudgetCategory {
  const BudgetCategory({
    required this.nameKey,
    required this.typical,
    this.noteKey,
  });

  /// Translation key for the category name; resolved via [name].
  final String nameKey;
  final double typical;

  /// Translation key for the optional note; resolved via [note].
  final String? noteKey;

  /// Localized category name for display.
  String get name => nameKey.tr;

  /// Localized note for display, or null when absent.
  String? get note => noteKey?.tr;
}

class LivingBudgetProfile {
  const LivingBudgetProfile({
    required this.country,
    required this.currency,
    required this.monthlyMin,
    required this.monthlyMax,
    required this.categories,
  });

  final String country;
  final String currency;
  final double monthlyMin;
  final double monthlyMax;

  /// Always nine entries, in canonical order:
  /// 0 Loyer · 1 Charges & énergie · 2 Alimentation · 3 Transport ·
  /// 4 Santé & assurance · 5 Forfait & Internet · 6 Fournitures & livres ·
  /// 7 Vêtements & hygiène · 8 Loisirs & divers
  final List<BudgetCategory> categories;

  double get totalTypical => categories.fold(0.0, (sum, c) => sum + c.typical);
}

// ── Nine MVP destination profiles · nine categories each ─────────────────────
final List<LivingBudgetProfile> mockBudgetProfiles = [
  LivingBudgetProfile(
    country: 'France',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    categories: [
      BudgetCategory(
          nameKey: 'budget_category_rent',
          typical: 400,
          noteKey: 'budget_note_fr_rent'),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 60),
      BudgetCategory(nameKey: 'budget_category_food', typical: 230),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 40),
      BudgetCategory(nameKey: 'budget_category_health', typical: 35),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 30),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 30),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 40),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 90),
    ],
  ),
  LivingBudgetProfile(
    country: 'Canada',
    currency: 'CAD',
    monthlyMin: 1200,
    monthlyMax: 1500,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 700),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 80),
      BudgetCategory(nameKey: 'budget_category_food', typical: 300),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 100),
      BudgetCategory(nameKey: 'budget_category_health', typical: 60),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 70),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 40),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 50),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 90),
    ],
  ),
  LivingBudgetProfile(
    country: 'USA',
    currency: 'USD',
    monthlyMin: 1500,
    monthlyMax: 2000,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 900),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 120),
      BudgetCategory(nameKey: 'budget_category_food', typical: 400),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 90),
      BudgetCategory(nameKey: 'budget_category_health', typical: 150),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 70),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 60),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 70),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 130),
    ],
  ),
  LivingBudgetProfile(
    country: 'Morocco',
    currency: 'MAD',
    monthlyMin: 4000,
    monthlyMax: 7000,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 2500),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 350),
      BudgetCategory(nameKey: 'budget_category_food', typical: 1200),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 400),
      BudgetCategory(nameKey: 'budget_category_health', typical: 250),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 200),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 250),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 300),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 500),
    ],
  ),
  LivingBudgetProfile(
    country: 'Turkey',
    currency: 'TRY',
    monthlyMin: 12000,
    monthlyMax: 18000,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 6000),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 900),
      BudgetCategory(nameKey: 'budget_category_food', typical: 4000),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 600),
      BudgetCategory(nameKey: 'budget_category_health', typical: 1000),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 700),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 600),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 800),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 1800),
    ],
  ),
  LivingBudgetProfile(
    country: 'United Kingdom',
    currency: 'GBP',
    monthlyMin: 1000,
    monthlyMax: 1300,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 550),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 90),
      BudgetCategory(nameKey: 'budget_category_food', typical: 180),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 60),
      BudgetCategory(
          nameKey: 'budget_category_health',
          typical: 65,
          noteKey: 'budget_note_uk_health'),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 35),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 40),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 50),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 110),
    ],
  ),
  LivingBudgetProfile(
    country: 'Germany',
    currency: 'EUR',
    monthlyMin: 1000,
    monthlyMax: 1200,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 450),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 90),
      BudgetCategory(nameKey: 'budget_category_food', typical: 200),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 40),
      BudgetCategory(
          nameKey: 'budget_category_health',
          typical: 120,
          noteKey: 'budget_note_de_health'),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 35),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 40),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 50),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 110),
    ],
  ),
  // Belgique francophone — estimation officielle Study in Belgium (WBI),
  // relevée le 12/11/2026 : 1 000 à 1 300 €/mois ; logement 575 € charges
  // comprises, alimentation 300 €, études 50 €, assurance 30 €, transport
  // 50 €, activités 50 €, autres 170 €.
  LivingBudgetProfile(
    country: 'Belgium',
    currency: 'EUR',
    monthlyMin: 1000,
    monthlyMax: 1300,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 500),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 75),
      BudgetCategory(nameKey: 'budget_category_food', typical: 300),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 50),
      BudgetCategory(nameKey: 'budget_category_health', typical: 30),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 30),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 50),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 50),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 140),
    ],
  ),
  LivingBudgetProfile(
    country: 'Spain',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 400),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 70),
      BudgetCategory(nameKey: 'budget_category_food', typical: 250),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 40),
      BudgetCategory(nameKey: 'budget_category_health', typical: 40),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 30),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 30),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 40),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 100),
    ],
  ),
  LivingBudgetProfile(
    country: 'United Arab Emirates',
    currency: 'AED',
    monthlyMin: 4500,
    monthlyMax: 6500,
    categories: [
      BudgetCategory(nameKey: 'budget_category_rent', typical: 3500),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 300),
      BudgetCategory(nameKey: 'budget_category_food', typical: 600),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 300),
      BudgetCategory(nameKey: 'budget_category_health', typical: 350),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 250),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 200),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 250),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 400),
    ],
  ),
  LivingBudgetProfile(
    country: 'China',
    currency: 'CNY',
    monthlyMin: 2000,
    monthlyMax: 4000,
    categories: [
      BudgetCategory(
          nameKey: 'budget_category_rent',
          typical: 1200,
          noteKey: 'budget_note_cn_rent'),
      BudgetCategory(nameKey: 'budget_category_utilities', typical: 150),
      BudgetCategory(nameKey: 'budget_category_food', typical: 800),
      BudgetCategory(nameKey: 'budget_category_transport', typical: 150),
      BudgetCategory(
          nameKey: 'budget_category_health',
          typical: 50,
          noteKey: 'budget_note_cn_health'),
      BudgetCategory(nameKey: 'budget_category_phone_internet', typical: 100),
      BudgetCategory(nameKey: 'budget_category_supplies', typical: 100),
      BudgetCategory(nameKey: 'budget_category_clothing_hygiene', typical: 150),
      BudgetCategory(nameKey: 'budget_category_leisure', typical: 300),
    ],
  ),
];
