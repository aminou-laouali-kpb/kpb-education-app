import { usVisaSuspensionConfig } from '../config/us-visa-suspension';
import {
  assessFacts,
  institutionFacts,
  scholarshipFacts,
  usVisaFact,
  type CycleRow,
  type FactSet,
} from './community-verif-bot-facts';
import { checkRewrite, composeText, formatDay, formatMonth, renderDraft } from './community-verif-bot-writer';
import type { VerifIntent } from './community-verif-bot-detect';

const NOW = new Date('2026-10-17T10:00:00.000Z');
const d = (iso: string) => new Date(iso);

const cycle = (over: Partial<CycleRow>): CycleRow => ({
  academicYear: '2027-2028',
  status: 'open',
  dateConfidence: 'confirmed',
  opensAt: null,
  closesAt: null,
  estimatedOpenAt: null,
  estimatedCloseAt: null,
  sourceUrl: null,
  verifiedAt: null,
  ...over,
});

function eiffel(cycles: CycleRow[], lastVerifiedAt = d('2026-10-01T00:00:00Z')) {
  return scholarshipFacts(
    {
      id: 'sch1',
      nameFr: 'Bourse Eiffel',
      nameEn: 'Eiffel Scholarship',
      countryId: 'fra',
      typeOfFundingFr: 'Complète',
      typeOfFundingEn: 'Full',
      keyRequirementsFr: ['CV', 'Lettre de motivation', 'Relevés de notes'],
      keyRequirementsEn: ['CV', 'Cover letter', 'Transcripts'],
      deadlineAt: null,
      applicationUrl: 'https://www.campusfrance.org/fr/eiffel',
      sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
      lastVerifiedAt,
      cycles,
    },
    { type: 'scholarship', id: 'sch1', labelFr: 'Bourse Eiffel', labelEn: 'Eiffel Scholarship', resolvedBy: 'mention' },
    NOW,
  );
}

const set = (entities: FactSet['entities'], usVisa: FactSet['usVisa'] = null): FactSet => ({
  version: 1,
  checkedAt: NOW.toISOString(),
  entities,
  usVisa,
});

function render(facts: FactSet, intents: VerifIntent[], lang: 'fr' | 'en' = 'fr', scamCaution = false) {
  const { unanswered } = assessFacts(facts, intents);
  return renderDraft({ facts, intents, unanswered, lang, scamCaution });
}

/** Les nombres d'un texte, zéros de tête retirés. */
const numbers = (text: string) => new Set([...text.matchAll(/\d+/g)].map((m) => String(Number(m[0]))));

describe('Bot Vérif — rédaction déterministe', () => {
  const open = set([eiffel([cycle({ opensAt: d('2026-09-01T00:00:00Z'), closesAt: d('2027-01-08T00:00:00Z') })])]);

  it('FR : statut, date confirmée JJ/MM/AAAA, lien, « vérifié le », source, fiche, rappel', () => {
    const r = render(open, ['status', 'deadline']);
    const text = composeText(r.body, r.footer);
    expect(text).toContain('Bonjour !');
    expect(text).toContain('les candidatures sont ouvertes. Clôture confirmée : le 08/01/2027.');
    expect(text).toContain('Lien officiel : https://www.campusfrance.org/fr/eiffel');
    expect(r.footer).toContain(
      'Fiche @[Bourse Eiffel](scholarship:sch1) : vérifié le 01/10/2026, source : https://www.campusfrance.org/fr/eiffel',
    );
    expect(r.footer).toContain('confirme toujours sur le site officiel');
    expect(text).not.toContain('%');
    expect(text).not.toMatch(/garanti/i);
  });

  it('aucun chiffre hors des faits', () => {
    for (const facts of [open, set([eiffel([cycle({ status: 'forecast', dateConfidence: 'estimated', estimatedOpenAt: d('2026-12-01T00:00:00Z') })])])]) {
      const r = render(facts, ['status', 'fees', 'documents', 'truth']);
      const allowed = numbers(JSON.stringify(facts));
      for (const n of numbers(composeText(r.body, r.footer))) expect({ n, allowed: allowed.has(n) }).toEqual({ n, allowed: true });
    }
  });

  it('EN : la langue de la question, sans espace avant les deux-points', () => {
    const r = render(open, ['status'], 'en');
    expect(r.body).toContain('Hi!');
    expect(r.body).toContain('Status: applications are open. Confirmed closing date: 08/01/2027.');
    expect(r.footer).toContain('Page @[Bourse Eiffel](scholarship:sch1): checked on 01/10/2026');
  });

  it('date ESTIMÉE dite au mois près, jamais au jour', () => {
    const r = render(set([eiffel([cycle({ status: 'forecast', dateConfidence: 'estimated', estimatedOpenAt: d('2026-12-01T00:00:00Z') })])]), ['status']);
    expect(r.body).toContain('Ouverture estimée : décembre 2026 (date non confirmée)');
    expect(r.body).not.toContain('01/12/2026');
  });

  it('fermée, documents, financement selon la question', () => {
    const r = render(set([eiffel([cycle({ closesAt: d('2026-10-01T00:00:00Z') })])]), ['status', 'documents', 'fees']);
    expect(r.body).toContain('les candidatures sont fermées pour cette session');
    expect(r.body).toContain('Documents demandés : CV ; Lettre de motivation ; Relevés de notes.');
    expect(r.body).toContain('Financement : Complète.');
  });

  it('donnée manquante ou périmée : le dire', () => {
    const stale = eiffel([cycle({ closesAt: d('2027-01-08T00:00:00Z') })], d('2026-06-01T00:00:00Z'));
    const noDocs = { ...stale, documents: { fr: [], en: [] } };
    const r = render(set([noDocs]), ['documents']);
    expect(r.body).toContain("Attention : la fiche Bourse Eiffel n'a pas été revérifiée depuis le 01/06/2026.");
    expect(r.body).toContain('Les données de KPB ne précisent pas encore : les documents demandés.');
  });

  it('phrase de prudence standard si la question parle d’arnaque ou d’argent', () => {
    const r = render(open, ['scam'], 'fr', true);
    expect(r.footer).toContain('Prudence : une bourse ou une admission ne s\'achète jamais');
  });

  it('école non partenaire et avis visa USA', () => {
    const school = institutionFacts(
      {
        id: 'inst1',
        nameFr: 'Example University',
        nameEn: 'Example University',
        countryId: 'usa',
        isPartner: false,
        intakePeriods: [],
        tuitionLabelFr: '',
        tuitionLabelEn: '',
        websiteUrl: 'https://example.edu',
        sourceUrl: null,
        lastVerifiedAt: d('2026-09-01T00:00:00Z'),
      },
      { type: 'institution', id: 'inst1', labelFr: 'Example University', labelEn: 'Example University', resolvedBy: 'name' },
      NOW,
    );
    const r = render(set([school], usVisaFact(usVisaSuspensionConfig({}))), ['partner']);
    expect(r.body).toContain("Example University figure dans le catalogue de KPB, mais ce n'est pas un établissement partenaire.");
    expect(r.body).toContain('Avis visa : les demandes de visa étudiant (F, M, J)');
    expect(r.body).toContain('Avis vérifié le 17/10/2026');
  });

  it('formats', () => {
    expect(formatDay('2027-01-08T00:00:00.000Z')).toBe('08/01/2027');
    expect(formatMonth('2027-01-08T00:00:00.000Z', 'en')).toBe('January 2027');
  });
});

describe('Bot Vérif — contrôle d’une reformulation LLM', () => {
  const reference = render(set([eiffel([cycle({ closesAt: d('2027-01-08T00:00:00Z') })])]), ['status', 'deadline']);

  it('accepte une reformulation fidèle (même date, même lien)', () => {
    expect(
      checkRewrite(
        'Salut ! Bonne nouvelle : pour la Bourse Eiffel (session 2027-2028), les candidatures sont ouvertes jusqu’au 8 janvier 2027. Lien officiel : https://www.campusfrance.org/fr/eiffel',
        reference,
      ),
    ).toEqual({ ok: true });
  });

  it('refuse une date inventée (faux LLM) → repli', () => {
    expect(checkRewrite('Les candidatures ferment le 15/02/2027, dépêche-toi pour la Bourse Eiffel !', reference)).toEqual({
      ok: false,
      reason: 'unknown_number',
    });
    expect(checkRewrite('Les candidatures ferment le 8 février 2027, dépêche-toi pour la Bourse Eiffel cette année !', reference)).toEqual({
      ok: false,
      reason: 'unknown_month',
    });
  });

  it('refuse %, promesse, lien inconnu, mention, sortie vide', () => {
    expect(checkRewrite('Tu as 80 % de chances, la Bourse Eiffel est ouverte jusqu’au 08/01/2027.', reference)).toMatchObject({ ok: false });
    expect(checkRewrite('Ta bourse est garantie si tu candidates avant le 08/01/2027, vas-y !', reference)).toEqual({ ok: false, reason: 'promise' });
    expect(checkRewrite('Candidate ici : https://arnaque.example/eiffel avant le 08/01/2027 sans faute.', reference)).toEqual({
      ok: false,
      reason: 'unknown_link',
    });
    expect(checkRewrite('Voir @[Bourse Eiffel](scholarship:sch1), ouverte jusqu’au 08/01/2027, bonne chance.', reference)).toEqual({
      ok: false,
      reason: 'mention',
    });
    expect(checkRewrite('', reference)).toEqual({ ok: false, reason: 'length' });
    expect(checkRewrite({ text: 'x' }, reference)).toEqual({ ok: false, reason: 'not_text' });
  });
});
