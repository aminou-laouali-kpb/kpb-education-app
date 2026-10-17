import {
  assessFacts,
  countryFacts,
  factsHash,
  institutionFacts,
  oldestVerifiedAt,
  programFacts,
  scholarshipFacts,
  scholarshipStatus,
  upcomingIntakes,
  usVisaFact,
  type CycleRow,
  type EntityRef,
  type FactSet,
  type InstitutionRow,
  type ScholarshipRow,
} from './community-verif-bot-facts';
import { usVisaSuspensionConfig } from '../config/us-visa-suspension';

const NOW = new Date('2026-10-17T10:00:00.000Z');
const d = (iso: string) => new Date(iso);

function cycle(over: Partial<CycleRow>): CycleRow {
  return {
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
  };
}

const ref = (type: EntityRef['type'], resolvedBy: EntityRef['resolvedBy'] = 'mention'): EntityRef => ({
  type,
  id: `${type}-1`,
  labelFr: `Libellé ${type}`,
  labelEn: `Label ${type}`,
  resolvedBy,
});

function scholarship(over: Partial<ScholarshipRow> = {}): ScholarshipRow {
  return {
    id: 'scholarship-1',
    nameFr: 'Bourse Eiffel',
    nameEn: 'Eiffel Scholarship',
    countryId: 'fra',
    typeOfFundingFr: 'Complète',
    typeOfFundingEn: 'Full',
    keyRequirementsFr: ['CV', 'Lettre de motivation'],
    keyRequirementsEn: ['CV', 'Cover letter'],
    deadlineAt: null,
    applicationUrl: 'https://www.campusfrance.org/fr/eiffel',
    sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
    lastVerifiedAt: d('2026-10-01T00:00:00Z'),
    cycles: [],
    ...over,
  };
}

describe('Bot Vérif — statut d’une bourse (règles honnêtes de l’app)', () => {
  it('ouverte, clôture confirmée lointaine → open', () => {
    const s = scholarshipStatus({ deadlineAt: null, cycles: [cycle({ opensAt: d('2026-09-01T00:00:00Z'), closesAt: d('2027-01-08T00:00:00Z') })] }, NOW);
    expect(s).toEqual({ kind: 'open', date: '2027-01-08T00:00:00.000Z', academicYear: '2027-2028' });
  });

  it('clôture confirmée dans 14 jours → closing_soon ; jamais sur une estimation', () => {
    expect(scholarshipStatus({ deadlineAt: null, cycles: [cycle({ closesAt: d('2026-10-25T00:00:00Z') })] }, NOW).kind).toBe('closing_soon');
    const estimated = scholarshipStatus(
      { deadlineAt: null, cycles: [cycle({ status: 'forecast', dateConfidence: 'estimated', estimatedOpenAt: d('2026-09-01T00:00:00Z'), estimatedCloseAt: d('2026-10-25T00:00:00Z') })] },
      NOW,
    );
    expect(estimated.kind).toBe('closing_estimated');
  });

  it('jamais « ouverte » avant opensAt : cycle open à ouverture future → opens_on', () => {
    const s = scholarshipStatus({ deadlineAt: null, cycles: [cycle({ opensAt: d('2026-11-02T00:00:00Z'), closesAt: d('2027-01-08T00:00:00Z') })] }, NOW);
    expect(s.kind).toBe('opens_on');
    expect(s.date).toBe('2026-11-02T00:00:00.000Z');
  });

  it('ouverture estimée à venir → opening_estimated (au mois près dans le texte)', () => {
    const s = scholarshipStatus(
      { deadlineAt: null, cycles: [cycle({ status: 'forecast', dateConfidence: 'estimated', estimatedOpenAt: d('2026-12-01T00:00:00Z') })] },
      NOW,
    );
    expect(s.kind).toBe('opening_estimated');
  });

  it('clôture CONFIRMÉE passée → closed', () => {
    const s = scholarshipStatus({ deadlineAt: null, cycles: [cycle({ closesAt: d('2026-10-01T00:00:00Z') })] }, NOW);
    expect(s.kind).toBe('closed');
  });

  it('clôture seulement ESTIMÉE passée → date_to_confirm, jamais « fermée »', () => {
    const s = scholarshipStatus(
      { deadlineAt: null, cycles: [cycle({ status: 'open', dateConfidence: 'estimated', estimatedCloseAt: d('2026-10-01T00:00:00Z') })] },
      NOW,
    );
    expect(s.kind).toBe('date_to_confirm');
  });

  it('cycle fermé par l’équipe (clôture confirmée à venir) → closed', () => {
    const s = scholarshipStatus({ deadlineAt: null, cycles: [cycle({ status: 'closed', closesAt: d('2027-01-08T00:00:00Z') })] }, NOW);
    expect(s.kind).toBe('closed');
  });

  it('fiche héritée sans cycle : date limite → open ; rien → date_to_confirm', () => {
    expect(scholarshipStatus({ deadlineAt: d('2027-02-01T00:00:00Z'), cycles: [] }, NOW).kind).toBe('open');
    expect(scholarshipStatus({ deadlineAt: null, cycles: [] }, NOW).kind).toBe('date_to_confirm');
  });

  it('cycle courant = ouvert d’abord, même si une prévision plus récente existe', () => {
    const s = scholarshipStatus(
      {
        deadlineAt: null,
        cycles: [
          cycle({ academicYear: '2028-2029', status: 'forecast', dateConfidence: 'estimated', estimatedOpenAt: d('2027-09-01T00:00:00Z') }),
          cycle({ academicYear: '2027-2028', closesAt: d('2027-01-08T00:00:00Z') }),
        ],
      },
      NOW,
    );
    expect(s).toMatchObject({ kind: 'open', academicYear: '2027-2028' });
  });
});

describe('Bot Vérif — rentrées (règle de program_intakes)', () => {
  it('masque les dates passées, dédoublonne par mois, trie, marque décalée et à confirmer', () => {
    const intakes = upcomingIntakes(
      [
        { campus: 'Paris', intake: '01/10/2026 · 15/09/2026' },
        { campus: 'Lyon', intake: '01/10/2027', intakeEstimated: true, rolledFromIntake: '01/10/2026' },
        { campus: 'Paris', intake: '03/2027', session: 'spring' },
        { campus: 'Lyon', intake: '20/10/2027' },
      ],
      [],
      NOW,
    );
    expect(intakes.fromSchool).toBe(false);
    expect(intakes.dates).toEqual([
      { year: 2027, month: 3, spring: true, estimated: false },
      // Octobre 2027 : une offre confirmée du même mois l'emporte sur la reconduction.
      { year: 2027, month: 10, spring: false, estimated: false },
    ]);
  });

  it('une date au jour reste valable le jour même ; au mois jusqu’à la fin du mois', () => {
    expect(upcomingIntakes([{ campus: 'A', intake: '17/10/2026' }], [], NOW).dates).toHaveLength(1);
    expect(upcomingIntakes([{ campus: 'A', intake: '10/2026' }], [], NOW).dates).toHaveLength(1);
    expect(upcomingIntakes([{ campus: 'A', intake: '16/10/2026' }], [], NOW).dates).toHaveLength(0);
  });

  it('toutes passées → allPast ; sans offre → rentrées de l’école ; aucun repli inventé', () => {
    expect(upcomingIntakes([{ campus: 'A', intake: '01/09/2026' }], ['Septembre'], NOW)).toMatchObject({ dates: [], allPast: true, fromSchool: false });
    expect(upcomingIntakes(null, ['Septembre', 'Janvier'], NOW)).toEqual({ dates: [], labels: ['Septembre', 'Janvier'], fromSchool: true, allPast: false });
    expect(upcomingIntakes(null, [], NOW)).toEqual({ dates: [], labels: [], fromSchool: true, allPast: false });
  });
});

describe('Bot Vérif — faits par entité et fraîcheur', () => {
  it('bourse : statut, lien, documents, source du cycle d’abord, fraîche', () => {
    const facts = scholarshipFacts(
      scholarship({ cycles: [cycle({ closesAt: d('2027-01-08T00:00:00Z'), sourceUrl: 'https://www.campusfrance.org/fr/eiffel-2027' })] }),
      ref('scholarship'),
      NOW,
    );
    expect(facts.status.kind).toBe('open');
    expect(facts.source).toEqual({ url: 'https://www.campusfrance.org/fr/eiffel-2027', verifiedAt: '2026-10-01T00:00:00.000Z', stale: false });
    expect(facts.documents.fr).toEqual(['CV', 'Lettre de motivation']);
  });

  it('bourse vérifiée il y a plus de 30 jours → stale ; sans date → stale', () => {
    expect(scholarshipFacts(scholarship({ lastVerifiedAt: d('2026-08-01T00:00:00Z') }), ref('scholarship'), NOW).source.stale).toBe(true);
    expect(scholarshipFacts(scholarship({ lastVerifiedAt: null }), ref('scholarship'), NOW).source.stale).toBe(true);
  });

  const school = (over: Partial<InstitutionRow> = {}): InstitutionRow => ({
    id: 'institution-1',
    nameFr: 'Université du Québec à Montréal',
    nameEn: 'Université du Québec à Montréal',
    countryId: 'can',
    isPartner: true,
    intakePeriods: ['01/09/2027'],
    tuitionLabelFr: '8 000 CAD par an',
    tuitionLabelEn: 'CAD 8,000 per year',
    websiteUrl: 'https://uqam.ca',
    sourceUrl: null,
    lastVerifiedAt: d('2026-06-01T00:00:00Z'),
    ...over,
  });

  it('école partenaire / non partenaire ; 180 jours de fraîcheur ; source = site à défaut', () => {
    const partner = institutionFacts(school(), ref('institution'), NOW);
    expect(partner).toMatchObject({ isPartner: true, isUs: false, websiteUrl: 'https://uqam.ca/' });
    expect(partner.source).toMatchObject({ url: 'https://uqam.ca/', stale: false });
    expect(partner.intakes.dates).toEqual([{ year: 2027, month: 9, spring: false, estimated: false }]);
    const notPartner = institutionFacts(school({ isPartner: false, lastVerifiedAt: d('2026-01-01T00:00:00Z') }), ref('institution'), NOW);
    expect(notPartner.isPartner).toBe(false);
    expect(notPartner.source.stale).toBe(true);
  });

  it('formation aux USA : avis visa ; date limite passée signalée', () => {
    const program = programFacts(
      {
        id: 'program-1',
        nameFr: 'MSc Data',
        nameEn: 'MSc Data',
        countryId: 'usa',
        tuitionFr: '30 000 USD',
        tuitionEn: 'USD 30,000',
        applicationFeeEur: 80,
        applicationDeadline: d('2026-10-01T00:00:00Z'),
        requirementsFr: ['Relevés de notes'],
        requirementsEn: ['Transcripts'],
        campusOfferings: null,
        sourceUrl: 'https://example.edu/msc',
        lastVerifiedAt: d('2026-09-01T00:00:00Z'),
      },
      school({ countryId: 'usa', isPartner: false }),
      ref('program'),
      NOW,
    );
    expect(program.isUs).toBe(true);
    expect(program.applicationDeadline).toEqual({ date: '2026-10-01T00:00:00.000Z', passed: true });
    expect(program.institution?.isPartner).toBe(false);
  });

  it('pays : prochaine rentrée, détection USA par id ou code', () => {
    const usa = countryFacts(
      { id: 'usa', code: 'USA', nameFr: 'USA', nameEn: 'USA', nextIntakeLabelFr: 'Août 2027', nextIntakeLabelEn: 'August 2027', sourceUrl: 'https://educationusa.state.gov/', lastVerifiedAt: d('2026-06-26T00:00:00Z') },
      ref('country'),
      NOW,
    );
    expect(usa).toMatchObject({ isUs: true, nextIntake: { fr: 'Août 2027', en: 'August 2027' } });
    expect(usVisaFact(usVisaSuspensionConfig({ countries: 'none' }))).toBeNull();
    expect(usVisaFact(usVisaSuspensionConfig({}))?.countries.map((c) => c.code)).toContain('NE');
  });
});

describe('Bot Vérif — complétude, confiance, empreinte', () => {
  const fresh = scholarshipFacts(
    scholarship({ cycles: [cycle({ closesAt: d('2027-01-08T00:00:00Z') })] }),
    ref('scholarship'),
    NOW,
  );
  const set = (entities: FactSet['entities']): FactSet => ({ version: 1, checkedAt: NOW.toISOString(), entities, usVisa: null });

  it('mention + faits demandés présents et frais → complete, confiance haute', () => {
    expect(assessFacts(set([fresh]), ['status', 'deadline'])).toEqual({ unanswered: [], anyStale: false, complete: true, confidence: 'high' });
  });

  it('entité trouvée par son nom → moyenne même complète', () => {
    const byName = { ...fresh, ref: { ...fresh.ref, resolvedBy: 'name' as const } };
    expect(assessFacts(set([byName]), ['status']).confidence).toBe('medium');
  });

  it('fait demandé absent → incomplet (dit « non renseigné ») ; périmé → incomplet', () => {
    const noDocs = { ...fresh, documents: { fr: [], en: [] } };
    expect(assessFacts(set([noDocs]), ['documents'])).toMatchObject({ unanswered: ['documents'], complete: false, confidence: 'low' });
    const stale = { ...fresh, source: { ...fresh.source, stale: true } };
    expect(assessFacts(set([stale]), ['status'])).toMatchObject({ complete: false, anyStale: true, confidence: 'low' });
  });

  it('empreinte : stable à l’heure près, change avec un fait', () => {
    const a = set([fresh]);
    const b = { ...set([fresh]), checkedAt: '2030-01-01T00:00:00.000Z' };
    expect(factsHash(a)).toBe(factsHash(b));
    const moved = set([{ ...fresh, status: { ...fresh.status, date: '2027-01-15T00:00:00.000Z' } }]);
    expect(factsHash(moved)).not.toBe(factsHash(a));
    expect(oldestVerifiedAt(a)).toBe('2026-10-01T00:00:00.000Z');
  });
});
