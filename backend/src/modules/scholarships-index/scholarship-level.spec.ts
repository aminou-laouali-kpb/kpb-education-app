import { levelsInText, scholarshipLevels } from './scholarship-level';

const sorted = (levels: Set<string>) => [...levels].sort();

describe('levelsInText', () => {
  it.each([
    // Les jetons que l'app envoie réellement (onboardingTargetLevels).
    ['Bachelor', ['bachelor']],
    ['Master', ['master']],
    ['PhD', ['doctorate']],
    // Synonymes FR/EN des libellés, accents ou non.
    ['Licence et Master', ['bachelor', 'master']],
    ['Undergraduate / Master’s', ['bachelor', 'master']],
    ['Mastère spécialisé', ['master']],
    ['MSc in Data Science', ['master']],
    ['Doctorat', ['doctorate']],
    ['Ph.D. programmes', ['doctorate']],
    ['Lycée — Seconde à Terminale', ['secondary']],
    ['Fin du secondaire — Form Four ou équivalent', ['secondary']],
    ['High school graduates', ['secondary']],
    // Mots entiers seulement, et pas les niveaux « post- ».
    ['Mastercard Foundation', []],
    ['Post-doctorat', []],
    ['Post-secondary diploma', []],
    // Un doctorat nié n'est pas un doctorat proposé.
    [
      'Secondaire, Licence ou Master selon le partenaire — pas de doctorat',
      ['bachelor', 'master', 'secondary'],
    ],
    [
      'Secondary, Bachelor or Master — no doctorate',
      ['bachelor', 'master', 'secondary'],
    ],
    ['Master, sans doctorat', ['master']],
    ['Master’s or PhD', ['doctorate', 'master']],
    ['Tous niveaux', []],
    ['', []],
  ])('%s → %j', (text, expected) => {
    expect(sorted(levelsInText(text))).toEqual(expected);
  });

  it('accepts a missing value', () => {
    expect(levelsInText(undefined).size).toBe(0);
    expect(levelsInText(null).size).toBe(0);
  });
});

describe('scholarshipLevels', () => {
  it('reads the level tags exactly, ignoring look-alike tags', () => {
    expect(
      sorted(
        scholarshipLevels({
          tags: ['Bachelor', 'mastercard-foundation', 'Doctorate', 'masterclass'],
          levelEligibleFr: '',
          levelEligibleEn: '',
        }),
      ),
    ).toEqual(['bachelor', 'doctorate']);
  });

  it("ignores the scrapers' heuristic tags and falls back to the labels", () => {
    // GreatYop pose `masters` dès que le titre contient « master »
    // (« Mastercard… ») et `phd` dès qu'il contient « doctoral »
    // (« Postdoctoral… ») : ces tags ne disent rien du niveau.
    expect(
      sorted(
        scholarshipLevels({
          tags: ['undergraduate', 'masters', 'phd', 'fully-funded'],
          levelEligibleFr: 'Licence',
          levelEligibleEn: 'undergraduate',
        }),
      ),
    ).toEqual(['bachelor']);
    expect(
      sorted(
        scholarshipLevels({
          tags: ['postdoctoral', 'phd'],
          levelEligibleFr: 'Post-doctorat',
          levelEligibleEn: 'postdoctoral',
        }),
      ),
    ).toEqual([]);
  });

  it('prefers the tags to the labels for secondary, bachelor and master', () => {
    expect(
      sorted(
        scholarshipLevels({
          tags: ['master'],
          levelEligibleFr: 'Études supérieures à temps plein à Oxford',
          levelEligibleEn: 'Full-time postgraduate study at Oxford',
        }),
      ),
    ).toEqual(['master']);
    expect(
      sorted(
        scholarshipLevels({
          tags: ['master'],
          levelEligibleFr: 'Licence ou Master',
          levelEligibleEn: 'Bachelor or Master',
        }),
      ),
    ).toEqual(['master']);
  });

  it('still reads a doctorate from the labels when the tags cannot say it', () => {
    // Le vocabulaire du catalogue vérifié s'arrête au master : Gates Cambridge
    // et UCT sont taggées `master` mais acceptent des doctorants.
    expect(
      sorted(
        scholarshipLevels({
          tags: ['master', 'uk', 'fully-funded'],
          levelEligibleFr:
            'Master de recherche ou d’un an à temps plein (MPhil, MRes, LLM, MLitt) ou doctorat — pas de MASt, MBA ni second BA',
          levelEligibleEn:
            'Full-time research or one-year Master (MPhil, MRes, LLM, MLitt) or PhD — no MASt, MBA or second BA',
        }),
      ),
    ).toEqual(['doctorate', 'master']);
    expect(
      sorted(
        scholarshipLevels({
          tags: ['master', 'south-africa'],
          levelEligibleFr: 'Postgrade uniquement : Honours, Master ou Doctorat',
          levelEligibleEn: 'Postgraduate only: Honours, Master’s or Doctoral',
        }),
      ),
    ).toEqual(['doctorate', 'master']);
  });

  it('does not read a negated doctorate as one', () => {
    expect(
      sorted(
        scholarshipLevels({
          tags: ['secondary', 'bachelor', 'master', 'mastercard-foundation'],
          levelEligibleFr:
            'Secondaire, Licence ou Master selon le partenaire — pas de doctorat',
          levelEligibleEn:
            'Secondary, Bachelor or Master depending on the partner — no doctorate',
        }),
      ),
    ).toEqual(['bachelor', 'master', 'secondary']);
    expect(
      sorted(
        scholarshipLevels({
          tags: ['master'],
          levelEligibleFr: 'Master — hors doctorat',
          levelEligibleEn: 'Master, excluding PhD',
        }),
      ),
    ).toEqual(['master']);
  });

  it('unions the FR and EN labels when no level tag exists', () => {
    expect(
      sorted(
        scholarshipLevels({
          tags: ['uk', 'constructor'],
          levelEligibleFr: 'Master / MPhil / Doctorat (DPhil)',
          levelEligibleEn: 'Master’s / MPhil / DPhil',
        }),
      ),
    ).toEqual(['doctorate', 'master']);
  });
});
