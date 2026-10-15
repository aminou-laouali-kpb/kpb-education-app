import { ELIGIBLE_LEVELS } from './eligibility-criteria';
import {
  excludedGroupLabel,
  levelCatalogLabel,
  notAnalyzedLabel,
  precisionLimitedBy,
  type StoredRunItem,
} from './match-presenter';
import { isHonestLabel, type ExclusionGroup } from './reasons';

const GROUPS: ExclusionGroup[] = ['level', 'nationality', 'age', 'experience', 'suspended'];

describe('libellés du résumé et des textes guidés par les données', () => {
  it('FR/EN, singulier/pluriel, jamais « % » ni « chance »', () => {
    const labels: string[] = [];
    for (const lang of ['fr', 'en'] as const) {
      for (const count of [0, 1, 2, 12]) {
        for (const group of GROUPS) labels.push(excludedGroupLabel(group, count, lang));
        const notAnalyzed = notAnalyzedLabel(count, lang);
        if (notAnalyzed) labels.push(notAnalyzed);
        for (const level of ELIGIBLE_LEVELS) {
          const label = levelCatalogLabel(level, count, lang, 10);
          if (label) labels.push(label);
        }
      }
    }
    expect(labels.length).toBeGreaterThan(50);
    for (const label of labels) expect(isHonestLabel(label)).toBe(true);
  });

  it('formes attendues', () => {
    expect(excludedGroupLabel('level', 12, 'fr')).toBe('12 visent un autre niveau');
    expect(excludedGroupLabel('nationality', 1, 'fr')).toBe(
      '1 est réservée à d’autres nationalités ou pays de résidence',
    );
    expect(notAnalyzedLabel(0, 'fr')).toBeNull();
    expect(notAnalyzedLabel(3, 'en')).toBe('3 recent scholarships not yet analysed by KPB');
    expect(levelCatalogLabel('doctorate', 1, 'fr', 10)).toBe(
      '1 bourse doctorale dans notre catalogue pour l’instant',
    );
    expect(levelCatalogLabel('doctorate', 0, 'fr', 10)).toBe(
      'Pas encore de bourse doctorale dans notre catalogue',
    );
    expect(levelCatalogLabel('master', 20, 'fr', 10)).toBeNull();
  });
});

describe('precisionLimitedBy', () => {
  const item = (status: 'eligible' | 'to_verify', toVerifyCodes: string[] = []): StoredRunItem =>
    ({ status, toVerifyCodes }) as unknown as StoredRunItem;

  it('null tant que moins de la moitié est « à vérifier »', () => {
    expect(precisionLimitedBy([])).toBeNull();
    expect(
      precisionLimitedBy([item('eligible'), item('eligible'), item('to_verify', ['eligibility_stale'])]),
    ).toBeNull();
  });

  it('dit si c’est l’analyse KPB ou les réponses qui limitent', () => {
    expect(
      precisionLimitedBy([item('eligible'), item('to_verify', ['eligibility_not_structured'])]),
    ).toBe('kpb');
    expect(
      precisionLimitedBy([item('to_verify', ['language_missing']), item('to_verify', ['age_missing'])]),
    ).toBe('answers');
    expect(precisionLimitedBy([item('to_verify', ['field_not_listed'])])).toBeNull();
  });
});
