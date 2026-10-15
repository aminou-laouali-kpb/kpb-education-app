import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { CreateMatchRunDto } from './dto/create-match-run.dto';
import {
  MATCH_ANSWER_KEYS,
  parseBirthDate,
  parseLang,
  parseMatchAnswers,
  parseTrigger,
  residenceLabel,
} from './match-answers';
import { NOW } from './testing/match-fixtures';

describe('parseMatchAnswers — tolérant : on abandonne, on ne refuse jamais', () => {
  it('garde les jetons connus et normalise les pays', () => {
    const { patch, ignored } = parseMatchAnswers(
      {
        nationalityCode: 'NER',
        secondNationalityCode: 'France',
        residence: 'sen',
        birthDate: '2006-05-10',
        highestDiploma: 'licence',
        scholarshipTargetLevel: 'master',
        fieldIds: ['d01', 'd03'],
        targetCountryIds: ['FRA', 'int'],
        gradeBandOn20: '14_16',
        englishLevel: 'b2',
        frenchLevel: 'c1_c2',
        workExperienceBand: '12_24',
        languageTests: [{ type: 'ielts', score: '6,5', takenAt: '2026-01-10' }],
      },
      NOW,
      'Niger',
    );

    expect(ignored).toEqual([]);
    expect(patch).toEqual({
      nationalityCode: 'ner',
      secondNationalityCode: 'fra',
      countryOfResidence: 'Sénégal',
      birthDate: new Date('2006-05-10T00:00:00.000Z'),
      highestDiploma: 'licence',
      scholarshipTargetLevel: 'master',
      fieldIds: ['d01', 'd03'],
      targetCountryIds: ['fra', 'int'],
      gradeBandOn20: '14_16',
      englishLevel: 'b2',
      frenchLevel: 'c1_c2',
      workExperienceBand: '12_24',
      languageTests: [{ type: 'ielts', score: 6.5, takenAt: '2026-01-10' }],
      // b2 n'a pas d'ancien équivalent univoque ; 14_16 non plus.
    });
  });

  it('abandonne clés inconnues, jetons inconnus et types inattendus', () => {
    const { patch, ignored } = parseMatchAnswers(
      {
        englishLevel: 'c3',
        gradeBandOn20: 12,
        nationalityCode: 'atlantis',
        fieldIds: 'd01',
        workExperienceBand: null,
        futureKey: { nested: true },
        budgetEur: 2000,
        guardianConsent: 'yes',
      },
      NOW,
    );

    expect(patch).toEqual({});
    expect(ignored.sort()).toEqual(
      [
        'budgetEur',
        'englishLevel',
        'fieldIds',
        'futureKey',
        'gradeBandOn20',
        'guardianConsent',
        'nationalityCode',
        'workExperienceBand',
      ].sort(),
    );
  });

  it('ne lève jamais, même sur un corps absurde', () => {
    for (const raw of [undefined, null, 'answers', 42, [], [{ englishLevel: 'b1' }]]) {
      expect(parseMatchAnswers(raw, NOW)).toEqual({ patch: {}, ignored: [] });
    }
  });

  it('écrit les anciens champs seulement quand la correspondance est univoque', () => {
    expect(parseMatchAnswers({ englishLevel: 'b1', gradeBandOn20: '12_14' }, NOW).patch).toMatchObject({
      languageLevel: 'Intermediate',
      gradeRange: '12 - 14/20',
    });
    const ambiguous = parseMatchAnswers({ englishLevel: 'b2', gradeBandOn20: '14_16' }, NOW).patch;
    expect(ambiguous).not.toHaveProperty('languageLevel');
    expect(ambiguous).not.toHaveProperty('gradeRange');
  });

  it('domaines : « pas encore décidé » ([]) est une réponse ; au plus trois, inconnus retirés', () => {
    expect(parseMatchAnswers({ fieldIds: [] }, NOW).patch).toEqual({ fieldIds: [] });
    expect(parseMatchAnswers({ fieldIds: ['d01', 'x', 'd02', 'd01', 'd03', 'd04'] }, NOW).patch).toEqual({
      fieldIds: ['d01', 'd02', 'd03'],
    });
    expect(parseMatchAnswers({ fieldIds: ['x', 'y'] }, NOW)).toEqual({ patch: {}, ignored: ['fieldIds'] });
  });

  it('les valeurs facultatives s’effacent par null ou []', () => {
    expect(
      parseMatchAnswers({ secondNationalityCode: null, frenchLevel: null, languageTests: [], targetCountryIds: [] }, NOW)
        .patch,
    ).toEqual({ secondNationalityCode: null, frenchLevel: null, languageTests: [], targetCountryIds: [] });
  });

  it('une résidence équivalente à l’actuelle n’est pas réécrite', () => {
    expect(parseMatchAnswers({ residence: 'ner' }, NOW, 'Niger').patch).toEqual({});
    expect(parseMatchAnswers({ residence: 'civ' }, NOW, 'Niger').patch).toEqual({
      countryOfResidence: "Côte d'Ivoire",
    });
  });

  it('accord parental : seulement `true`', () => {
    expect(
      parseMatchAnswers({ guardianConsent: true, guardianName: ' Mariama ', guardianContact: '' }, NOW),
    ).toEqual({ patch: { guardianConsent: true, guardianName: 'Mariama' }, ignored: ['guardianContact'] });
  });

  it('chaque clé comprise est listée', () => {
    expect(MATCH_ANSWER_KEYS).toContain('residence');
    expect(MATCH_ANSWER_KEYS).not.toContain('countryOfResidence');
  });
});

describe('parseBirthDate', () => {
  it.each([
    ['2006-05-10', '2006-05-10T00:00:00.000Z'],
    ['2006-05-10T23:00:00.000Z', '2006-05-10T00:00:00.000Z'],
    ['2008-02-29', '2008-02-29T00:00:00.000Z'],
  ])('%s → %s', (input, expected) => {
    expect(parseBirthDate(input, NOW)?.toISOString()).toBe(expected);
  });

  it.each([
    ['30 février', '2007-02-30'],
    ['moins de 16 ans', '2012-01-01'],
    ['dans le futur', '2030-01-01'],
    ['pas une date', 'hier'],
    ['un nombre', 20060510],
  ])('abandonne %s', (_label, input) => {
    expect(parseBirthDate(input, NOW)).toBeNull();
  });
});

describe('lang, trigger, résidence', () => {
  it('normalise sans refuser', () => {
    expect(parseLang('en')).toBe('en');
    expect(parseLang('EN-gb')).toBe('en');
    expect(parseLang('wo')).toBe('fr');
    expect(parseLang(undefined)).toBe('fr');
    expect(parseTrigger('rerun')).toBe('rerun');
    expect(parseTrigger('recompute')).toBe('other');
    expect(parseTrigger(undefined)).toBe('other');
    expect(residenceLabel('civ')).toBe("Côte d'Ivoire");
  });
});

describe('CreateMatchRunDto sous la ValidationPipe de main.ts', () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  const validate = (value: unknown) => pipe.transform(value, { type: 'body', metatype: CreateMatchRunDto });

  it('`answers` est un objet libre : ses clés inconnues ne déclenchent PAS forbidNonWhitelisted', async () => {
    const answers = { englishLevel: 'c3', unknownKey: { deep: [1, 2] }, fieldIds: ['d01'] };
    await expect(validate({ lang: 'xx', trigger: 'future', answers, confirm: true })).resolves.toMatchObject({
      answers,
      confirm: true,
    });
    await expect(validate({})).resolves.toEqual({});
  });

  it.each([
    ['une clé inconnue de premier niveau', { userId: 'x' }],
    ['answers qui n’est pas un objet', { answers: 'b1' }],
    ['confirm qui n’est pas un booléen', { confirm: 'true' }],
  ])('refuse %s', async (_label, value) => {
    await expect(validate(value)).rejects.toBeInstanceOf(BadRequestException);
  });
});
