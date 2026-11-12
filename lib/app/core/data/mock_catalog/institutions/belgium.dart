// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

// Catalogue de repli (hors ligne). Frais 2026-2027 de la Fédération
// Wallonie-Bruxelles (circulaire ARES 2026-001) : 1 194 EUR pour les pays des
// annexes 1 à 3, 5 369 EUR pour les autres hors UE. Les établissements
// flamands (UGent, VUB), non vérifiés, sont retirés depuis que la Belgique est
// une destination visible (12/11/2026).
const kInstitutionsBelgium = <InstitutionModel>[
  InstitutionModel(
    id: 'ulb',
    name: LocalizedText(fr: 'Université Libre de Bruxelles (ULB)', en: 'ULB'),
    countryId: 'belgium',
    location: LocalizedText(fr: 'Bruxelles', en: 'Brussels'),
    overview: LocalizedText(
        fr: 'Top 200 mondial. Droit, médecine, économie. Très forte communauté africaine. En plein cœur de Bruxelles (EU).',
        en: 'Top 200 globally. Law, medicine, economics. Very strong African community. In the heart of Brussels (EU).'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: '1 194–5 369 EUR/an', en: '1 194–5 369 EUR/yr'),
    languageRequirements: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_be001', 'prog_be002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'uclouvain',
    name: LocalizedText(
        fr: 'UCLouvain (Université catholique de Louvain)', en: 'UCLouvain'),
    countryId: 'belgium',
    location: LocalizedText(fr: 'Louvain-la-Neuve', en: 'Louvain-la-Neuve'),
    overview: LocalizedText(
        fr: 'Top 200 mondial. Excellence en médecine, ingénierie et sciences humaines. Très forte tradition de coopération avec l\'Afrique.',
        en: 'Top 200 globally. Excellence in medicine, engineering and humanities. Strong tradition of cooperation with Africa.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: '1 194–5 369 EUR/an', en: '1 194–5 369 EUR/yr'),
    languageRequirements:
        LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_be003'],
    isPartner: false,
  ),
];
