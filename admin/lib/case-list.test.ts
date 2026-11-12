import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  CASE_LIST_SUMMARY_PATH,
  CASE_SEARCH_MAX_LENGTH,
  EMPTY_CASE_LIST_FILTERS,
  UNASSIGNED_ADVISOR,
  appendCasePage,
  awaitingSignature,
  caseDetailPath,
  caseListPath,
  displayedAdvisorName,
  hasActiveCaseFilters,
  normalizeCaseListPage,
  normalizeCaseListSummary,
  patchCaseListItem,
  type AdminCaseDetail,
  type AdminCaseListItem,
} from './case-list';

describe('displayedAdvisorName — la colonne « Conseiller »', () => {
  it('un nom vide ou blanc compte comme « sans conseiller », comme le filtre serveur', () => {
    expect(displayedAdvisorName(null)).toBeNull();
    expect(displayedAdvisorName(undefined)).toBeNull();
    expect(displayedAdvisorName('')).toBeNull();
    expect(displayedAdvisorName('   ')).toBeNull();
  });

  it('un vrai nom est affiché sans ses espaces autour', () => {
    expect(displayedAdvisorName('  Moussa Diop ')).toBe('Moussa Diop');
  });

  it('la page passe par cette fonction (pas de `?? unassigned` qui laisse passer "")', () => {
    const page = readFileSync(join(__dirname, '../app/cases/page.tsx'), 'utf8');
    expect(page).not.toMatch(/assignedAdvisorName \?\? t\('cases\.unassigned'\)/);
    expect(page).toContain('displayedAdvisorName(item.assignedAdvisorName)');
  });
});

// La liste des dossiers (audit avant la 59). Avant : `GET /admin/cases` sans
// paramètre, tous les dossiers et toutes leurs relations, tri dans le
// navigateur. Ces tests tiennent ce que la page envoie au serveur et ce
// qu'elle fait de ses réponses.

const row = (id: string, overrides: Partial<AdminCaseListItem> = {}): AdminCaseListItem => ({
  id,
  referenceCode: `KPB-2026-${id}`,
  studentName: 'Awa Diallo',
  studentEmail: 'awa@example.test',
  preferredLanguage: 'fr',
  type: 'consultation',
  status: 'submitted',
  contextLabel: 'Licence',
  assignedAdvisorName: null,
  nextStepTitle: 'En revue',
  nextStepDescription: 'Un conseiller arrive.',
  ...overrides,
});

describe('caseListPath — les filtres partent au serveur', () => {
  it('sans filtre : la première page, sans paramètre', () => {
    expect(caseListPath(EMPTY_CASE_LIST_FILTERS)).toBe('/admin/cases');
  });

  it('statut, conseiller, recherche et « réponse attendue » sont des paramètres', () => {
    const path = caseListPath({
      status: 'under_review',
      advisor: 'Fatou Conseil',
      q: '  awa   diallo ',
      awaiting: true,
    });
    const params = new URLSearchParams(path.split('?')[1]);
    expect(path.startsWith('/admin/cases?')).toBe(true);
    expect(Object.fromEntries(params)).toEqual({
      status: 'under_review',
      advisor: 'Fatou Conseil',
      q: 'awa diallo',
      awaiting: 'true',
    });
  });

  it('« Sans conseiller » devient `unassigned=true`, jamais un nom', () => {
    const params = new URLSearchParams(
      caseListPath({ ...EMPTY_CASE_LIST_FILTERS, advisor: UNASSIGNED_ADVISOR }).split('?')[1],
    );
    expect(Object.fromEntries(params)).toEqual({ unassigned: 'true' });
  });

  it('la page suivante porte le curseur du serveur, encodé', () => {
    const path = caseListPath({ ...EMPTY_CASE_LIST_FILTERS, status: 'submitted' }, 'abc+/=');
    const params = new URLSearchParams(path.split('?')[1]);
    expect(params.get('cursor')).toBe('abc+/=');
    expect(params.get('status')).toBe('submitted');
  });

  it('n’envoie aucun paramètre que le serveur refuserait', () => {
    const allowed = new Set(['cursor', 'limit', 'status', 'advisor', 'unassigned', 'q', 'awaiting']);
    const path = caseListPath(
      { status: 'submitted', advisor: 'A', q: 'x'.repeat(500), awaiting: true },
      'c',
    );
    const params = new URLSearchParams(path.split('?')[1]);
    for (const key of params.keys()) expect(allowed.has(key)).toBe(true);
    expect(params.get('q')).toHaveLength(CASE_SEARCH_MAX_LENGTH);
  });

  it('un nom ou un caractère spécial reste un seul paramètre', () => {
    const path = caseListPath({ ...EMPTY_CASE_LIST_FILTERS, advisor: 'Jojo & Cie', q: 'a=b&c' });
    const params = new URLSearchParams(path.split('?')[1]);
    expect(params.get('advisor')).toBe('Jojo & Cie');
    expect(params.get('q')).toBe('a=b&c');
  });

  it('chemins du détail et du résumé', () => {
    expect(caseDetailPath('case/1')).toBe('/admin/cases/case%2F1');
    expect(CASE_LIST_SUMMARY_PATH).toBe('/admin/cases/summary');
  });
});

describe('hasActiveCaseFilters', () => {
  it('faux sans filtre, vrai dès qu’un filtre est posé', () => {
    expect(hasActiveCaseFilters(EMPTY_CASE_LIST_FILTERS)).toBe(false);
    expect(hasActiveCaseFilters({ ...EMPTY_CASE_LIST_FILTERS, q: '   ' })).toBe(false);
    expect(hasActiveCaseFilters({ ...EMPTY_CASE_LIST_FILTERS, q: 'awa' })).toBe(true);
    expect(hasActiveCaseFilters({ ...EMPTY_CASE_LIST_FILTERS, awaiting: true })).toBe(true);
    expect(hasActiveCaseFilters({ ...EMPTY_CASE_LIST_FILTERS, status: 'submitted' })).toBe(true);
    expect(hasActiveCaseFilters({ ...EMPTY_CASE_LIST_FILTERS, advisor: UNASSIGNED_ADVISOR })).toBe(true);
  });
});

describe('normalizeCaseListPage', () => {
  it('lit une page `{ items, nextCursor }`', () => {
    expect(normalizeCaseListPage({ items: [row('1')], nextCursor: 'suite' })).toEqual({
      items: [row('1')],
      nextCursor: 'suite',
    });
    expect(normalizeCaseListPage({ items: [], nextCursor: null })).toEqual({
      items: [],
      nextCursor: null,
    });
  });

  it('un backend antérieur (tableau nu) s’affiche, sans page suivante', () => {
    expect(normalizeCaseListPage([row('1'), row('2')])).toEqual({
      items: [row('1'), row('2')],
      nextCursor: null,
    });
  });

  it('une réponse illisible vaut une liste vide, pas une page plantée', () => {
    for (const bad of [undefined, null, 'x', 3, {}, { items: 'x', nextCursor: 4 }]) {
      expect(normalizeCaseListPage(bad)).toEqual({ items: [], nextCursor: null });
    }
  });
});

describe('appendCasePage', () => {
  it('ajoute la page à la suite, dans l’ordre du serveur', () => {
    const merged = appendCasePage([row('3'), row('2')], [row('1'), row('0')]);
    expect(merged.map((c) => c.id)).toEqual(['3', '2', '1', '0']);
  });

  it('ne répète pas un dossier déjà affiché, et garde sa valeur la plus récente', () => {
    const merged = appendCasePage(
      [row('3'), row('2', { status: 'submitted' })],
      [row('2', { status: 'under_review' }), row('1')],
    );
    expect(merged.map((c) => c.id)).toEqual(['3', '2', '1']);
    expect(merged[1].status).toBe('under_review');
  });

  it('ne modifie pas la liste reçue', () => {
    const current = [row('1')];
    appendCasePage(current, [row('0')]);
    expect(current).toHaveLength(1);
  });
});

describe('patchCaseListItem', () => {
  const detail: AdminCaseDetail = {
    ...row('2', { status: 'counselor_assigned', assignedAdvisorName: 'Fatou' }),
    tasks: [{ id: 't', title: 'Relancer', assigneeName: null, status: 'open', dueAt: null }],
    internalNotes: [],
    timeline: [],
    timelineTruncated: false,
  };

  it('la ligne du dossier ouvert reprend son statut et son conseiller', () => {
    const patched = patchCaseListItem([row('3'), row('2'), row('1')], detail);
    expect(patched.map((c) => c.id)).toEqual(['3', '2', '1']);
    expect(patched[1]).toMatchObject({ status: 'counselor_assigned', assignedAdvisorName: 'Fatou' });
  });

  it('les tâches, notes et historique ne passent pas dans la liste', () => {
    const [patched] = patchCaseListItem([row('2')], detail);
    for (const key of ['tasks', 'internalNotes', 'timeline', 'timelineTruncated']) {
      expect(patched).not.toHaveProperty(key);
    }
  });

  it('les autres lignes sont les mêmes objets (pas de rendu inutile)', () => {
    const items = [row('3'), row('2')];
    const patched = patchCaseListItem(items, detail);
    expect(patched[0]).toBe(items[0]);
  });

  it('un dossier absent de la liste (autre page, autre filtre) ne l’y ajoute pas', () => {
    expect(patchCaseListItem([row('9')], detail).map((c) => c.id)).toEqual(['9']);
  });
});

describe('normalizeCaseListSummary', () => {
  it('lit le compteur et les conseillers', () => {
    expect(normalizeCaseListSummary({ awaitingCount: 4, advisors: ['Awa', 'Jojo'] })).toEqual({
      awaitingCount: 4,
      advisors: ['Awa', 'Jojo'],
    });
  });

  it('une réponse absente ou abîmée vaut zéro et aucun conseiller', () => {
    for (const bad of [undefined, null, [], { awaitingCount: 'x', advisors: 'y' }]) {
      expect(normalizeCaseListSummary(bad)).toEqual({ awaitingCount: 0, advisors: [] });
    }
    expect(normalizeCaseListSummary({ awaitingCount: -2, advisors: ['', 'Awa', 3] })).toEqual({
      awaitingCount: 0,
      advisors: ['Awa'],
    });
  });
});

describe('awaitingSignature', () => {
  it('ne change que si « réponse attendue » change pour un dossier', () => {
    const before = awaitingSignature({
      b: { awaitingReply: true, lastMessageAt: '2026-11-09T10:00:00Z' },
      a: { awaitingReply: false, lastMessageAt: '2026-11-09T09:00:00Z' },
    });
    // Nouveau message de l'élève dans un dossier déjà en attente : rien à relire.
    const sameState = awaitingSignature({
      a: { awaitingReply: false, lastMessageAt: '2026-11-09T09:00:00Z' },
      b: { awaitingReply: true, lastMessageAt: '2026-11-09T11:00:00Z' },
    });
    const replied = awaitingSignature({
      a: { awaitingReply: false, lastMessageAt: '2026-11-09T09:00:00Z' },
      b: { awaitingReply: false, lastMessageAt: '2026-11-09T12:00:00Z' },
    });
    expect(sameState).toBe(before);
    expect(replied).not.toBe(before);
    expect(awaitingSignature({})).toBe('');
  });
});

describe('la page des dossiers suit le contrat paginé', () => {
  const page = readFileSync(join(__dirname, '..', 'app', 'cases', 'page.tsx'), 'utf8');

  it('ne lit plus tous les dossiers d’un coup', () => {
    // L'appel d'avant : `apiFetch<AdminCaseItem[]>('/admin/cases')`.
    expect(page).not.toMatch(/apiFetch<[^>]*\[\]>\(\s*['"`]\/admin\/cases['"`]/);
    expect(page).toContain('caseListPath(');
    expect(page).toContain('normalizeCaseListPage');
  });

  it('charge les relations du seul dossier ouvert, et propose la page suivante', () => {
    expect(page).toContain('caseDetailPath(');
    expect(page).toContain('nextCursor');
    expect(page).toContain("t('cases.loadMore')");
  });

  it('ne trie ni ne filtre plus par statut, conseiller ou texte dans le navigateur', () => {
    expect(page).not.toMatch(/\.filter\(\s*\(?\s*\w+\s*\)?\s*=>\s*\w+\.(status|assignedAdvisorName|studentName)/);
  });
});
