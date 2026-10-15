import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import type { EligibilityCoverageResponse } from '../../lib/scholarship-eligibility-types';
import { LocaleProvider } from '../locale-provider';
import { EligibilityCoverageCard } from './EligibilityCoverageCard';
import { MatchPreviewDrawer } from './MatchPreviewDrawer';
import { ScholarshipEligibilityEditor } from './ScholarshipEligibilityEditor';
import type { ScholarshipEntry } from './types';

// Rendu serveur (react-dom/server) : premier rendu seulement, sans effets
// (la liste des pays n'est pas chargée). Les règles sont couvertes par les
// fonctions pures de `lib/scholarship-eligibility.ts`.

function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};

const ENTRY: ScholarshipEntry = {
  id: 'sch-eiffel',
  nameFr: 'Bourse Eiffel',
  nameEn: 'Eiffel Scholarship',
  countryId: 'fra',
  sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
  applicationUrl: '',
  deadlineAt: null,
  moderationStatus: 'approved',
  lastVerifiedAt: '2026-10-01T00:00:00.000Z',
  tags: ['catalog:v1'],
  applicationRequirement: 'separate_application',
  applicationSteps: [],
  currentCycle: null,
  eligibleLevels: ['master'],
  fieldsScope: 'all',
  eligibilityCriteria: [
    {
      type: 'nationality',
      key: 'pas-francais',
      impact: 'hard',
      appliesTo: 'nationality',
      mode: 'exclude',
      countries: ['fra'],
      officialTextFr: 'Les candidats de nationalité française ne sont pas éligibles.',
      officialTextEn: 'French nationals are not eligible.',
      sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
    },
  ],
  eligibilityStructuredAt: new Date().toISOString(),
  eligibilityStructuredBy: 'Aïcha Relectrice',
};

describe('ScholarshipEligibilityEditor (rendu serveur)', () => {
  it('montre l’état, qui a vérifié, les niveaux cochés et chaque critère', () => {
    const html = render(<ScholarshipEligibilityEditor entry={ENTRY} onSaved={noop} />);
    expect(html).toContain('Éligibilité structurée');
    expect(html).toContain('Conditions vérifiées');
    expect(html).toContain('par Aïcha Relectrice');
    expect(html).toMatch(/<input type="checkbox" checked=""\/>Master/);
    expect(html).toMatch(/<input type="checkbox"\/>Doctorat/);
    expect(html).toContain('1. Nationalité / résidence');
    expect(html).toContain('Fermée à ces pays');
    // Citations et source obligatoires, visibles dans la carte.
    expect(html).toContain('Citation officielle (FR)');
    expect(html).toContain('URL de la source officielle');
    // La sémantique « une des nationalités » est expliquée.
    expect(html).toContain('UNE des nationalités');
    expect(html).toContain('Retirer la vérification');
  });

  it('avertit que le dépôt fait foi sur une fiche du catalogue, pas ailleurs', () => {
    expect(render(<ScholarshipEligibilityEditor entry={ENTRY} onSaved={noop} />)).toContain(
      'le dépôt fait foi',
    );
    expect(
      render(<ScholarshipEligibilityEditor entry={{ ...ENTRY, tags: [] }} onSaved={noop} />),
    ).not.toContain('le dépôt fait foi');
  });

  it('une fiche sans niveau est « non analysée », jamais vérifiée', () => {
    const html = render(
      <ScholarshipEligibilityEditor
        entry={{
          ...ENTRY,
          eligibleLevels: [],
          eligibilityCriteria: [],
          eligibilityStructuredAt: null,
          eligibilityStructuredBy: null,
        }}
        onSaved={noop}
      />,
    );
    expect(html).toContain('Non analysée');
    expect(html).toContain('Conditions jamais vérifiées');
    expect(html).not.toContain('Retirer la vérification');
  });
});

describe('EligibilityCoverageCard (rendu serveur)', () => {
  const coverage: EligibilityCoverageResponse = {
    generatedAt: '2026-10-15T12:00:00.000Z',
    freshnessDays: 400,
    launchGatePercent: 90,
    total: 36,
    structuredFresh: 31,
    stale: 1,
    unstructured: 3,
    notAnalyzed: 1,
    invalidCriteria: 0,
    coveragePercent: 86.1,
    launchReady: false,
    toStructure: [],
    toStructureIds: [],
    truncated: false,
  };

  it('affiche le compteur, la porte et le rappel sur la modération', () => {
    const html = render(
      <EligibilityCoverageCard
        coverage={coverage}
        failed={false}
        filterActive={false}
        onToggleFilter={noop}
        onOpenPreview={noop}
      />,
    );
    expect(html).toContain('31 / 36 bourses publiques structurées et vérifiées (86,1 %)');
    expect(html).toContain('Porte non atteinte');
    expect(html).toContain('1 périmées (≥ 400 j) · 3 brouillons · 1 non analysées.');
    expect(html).toContain('invisible au test');
    expect(html).toContain('aria-pressed="false"');
  });

  it('reste utilisable sans couverture', () => {
    const html = render(
      <EligibilityCoverageCard
        coverage={null}
        failed
        filterActive
        onToggleFilter={noop}
        onOpenPreview={noop}
      />,
    );
    expect(html).toContain('Couverture indisponible');
    expect(html).toContain('aria-pressed="true"');
  });
});

describe('MatchPreviewDrawer (rendu serveur)', () => {
  it('ne rend rien fermé', () => {
    expect(render(<MatchPreviewDrawer open={false} onClose={noop} />)).toBe('');
  });
});
