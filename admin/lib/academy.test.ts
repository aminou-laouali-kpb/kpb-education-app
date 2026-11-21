import { describe, expect, it } from 'vitest';

import {
  AcademyDraftError,
  EMPTY_COURSE_DRAFT,
  EMPTY_LESSON_DRAFT,
  formatDuration,
  moveLesson,
  parseDuration,
  parseManifest,
  parseYoutubeId,
  slugify,
  toCourseInput,
  toLessonInput,
} from './academy';

describe('slugify', () => {
  it.each([
    ['Préparation HSK 1', 'preparation-hsk-1'],
    ['  HSK 4 — Bourse CSC !  ', 'hsk-4-bourse-csc'],
    ['Œuvre déjà vue', 'oeuvre-deja-vue'],
    ['---', ''],
  ])('%s → %s', (input, expected) => {
    expect(slugify(input)).toBe(expected);
  });

  it('ne dépasse pas 80 caractères et ne finit pas par un tiret', () => {
    const slug = slugify(`${'a'.repeat(79)} b`);
    expect(slug.length).toBeLessThanOrEqual(80);
    expect(slug.endsWith('-')).toBe(false);
  });
});

describe('parseYoutubeId — mêmes formes que le serveur', () => {
  it.each([
    ['https://youtu.be/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://youtu.be/dQw4w9WgXcQ?si=abc', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30', 'dQw4w9WgXcQ'],
    ['https://m.youtube.com/watch?v=dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/embed/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/shorts/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/live/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['  dQw4w9WgXcQ  ', 'dQw4w9WgXcQ'],
  ])('lit %s', (input, expected) => {
    expect(parseYoutubeId(input)).toBe(expected);
  });

  it.each([
    'http://youtu.be/dQw4w9WgXcQ',
    'https://vimeo.com/123456789',
    'https://www.youtube.com/watch?v=court',
    'https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ',
    'pas un lien',
    '',
  ])('refuse %s', (input) => {
    expect(parseYoutubeId(input)).toBeNull();
  });
});

describe('durées', () => {
  it.each([
    ['4:05', 245],
    ['04:05', 245],
    ['1:02:03', 3723],
    ['245', 245],
    [' 0:59 ', 59],
  ])('%s → %i s', (input, expected) => {
    expect(parseDuration(input)).toBe(expected);
  });

  it.each(['', '0', '0:00', '4:60', '4:5:6:7', 'abc', '-3', '24:00:01'])(
    'refuse %s',
    (input) => {
      expect(parseDuration(input)).toBeNull();
    },
  );

  it.each([
    [245, '4:05'],
    [59, '0:59'],
    [3723, '1:02:03'],
    [0, '0:00'],
  ])('%i s → %s', (seconds, expected) => {
    expect(formatDuration(seconds)).toBe(expected);
  });
});

describe('toCourseInput', () => {
  const draft = {
    ...EMPTY_COURSE_DRAFT,
    slug: 'hsk-1',
    titleFr: '  Préparation HSK 1 ',
  };

  it('à la création, omet les champs vides (le serveur applique ses défauts)', () => {
    expect(toCourseInput(draft, 'create')).toEqual({
      slug: 'hsk-1',
      titleFr: 'Préparation HSK 1',
      status: 'draft',
      displayOrder: 0,
    });
  });

  it('à l’édition, envoie les champs vidés, et null pour retirer la couverture', () => {
    expect(toCourseInput(draft, 'edit')).toMatchObject({
      titleEn: '',
      descriptionFr: '',
      descriptionEn: '',
      coverImageUrl: null,
    });
  });

  it.each([
    [{ slug: 'HSK 1' }, /Identifiant invalide/],
    [{ slug: '' }, /Identifiant invalide/],
    [{ titleFr: '   ' }, /titre français/],
    [{ coverImageUrl: 'http://exemple.org/a.png' }, /https/],
    [{ displayOrder: '1.5' }, /position/],
  ])('refuse %o', (patch, message) => {
    expect(() => toCourseInput({ ...draft, ...patch }, 'create')).toThrow(message);
    expect(() => toCourseInput({ ...draft, ...patch }, 'create')).toThrow(
      AcademyDraftError,
    );
  });
});

describe('toLessonInput', () => {
  const draft = {
    ...EMPTY_LESSON_DRAFT,
    url: 'https://youtu.be/dQw4w9WgXcQ?si=partage',
    titleFr: 'Les tons',
    duration: '4:05',
  };

  it('envoie le lien canonique et la durée en secondes', () => {
    expect(toLessonInput(draft, 'create')).toEqual({
      youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      titleFr: 'Les tons',
      durationSeconds: 245,
      status: 'published',
    });
  });

  it('accepte un identifiant nu', () => {
    expect(toLessonInput({ ...draft, url: 'dQw4w9WgXcQ' }, 'create').youtubeUrl).toBe(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
  });

  it('à l’édition, un titre anglais vidé est envoyé vide (le serveur reprend le français)', () => {
    expect(toLessonInput(draft, 'edit')).toMatchObject({ titleEn: '' });
  });

  it.each([
    [{ url: 'https://vimeo.com/1' }, /YouTube/],
    [{ titleFr: '' }, /titre français/],
    [{ duration: '4:75' }, /Durée/],
  ])('refuse %o', (patch, message) => {
    expect(() => toLessonInput({ ...draft, ...patch }, 'create')).toThrow(message);
  });
});

describe('moveLesson', () => {
  it('échange avec la voisine', () => {
    expect(moveLesson(['a', 'b', 'c'], 1, -1)).toEqual(['b', 'a', 'c']);
    expect(moveLesson(['a', 'b', 'c'], 1, 1)).toEqual(['a', 'c', 'b']);
  });

  it('ne sort pas des bornes', () => {
    expect(moveLesson(['a', 'b'], 0, -1)).toBeNull();
    expect(moveLesson(['a', 'b'], 1, 1)).toBeNull();
  });
});

describe('parseManifest', () => {
  /** La forme demandée au prompt Antigravity, complétée des liens YouTube. */
  const hyperframesModule = {
    id: 'hsk-1',
    titleFr: 'Préparation HSK 1',
    titleEn: 'HSK 1 preparation',
    descriptionFr: 'Les bases.',
    descriptionEn: 'The basics.',
    lessons: [
      {
        order: 2,
        file: 'out/hsk1/02-grammar-shi.mp4',
        titleFr: 'Le verbe 是',
        titleEn: 'The verb 是',
        durationSeconds: 300,
        type: 'grammar',
        hskLevel: 1,
        youtubeUrl: 'https://youtu.be/bbbbbbbbbbb',
      },
      {
        order: 1,
        file: 'out/hsk1/01-vocab-salutations.mp4',
        titleFr: 'Salutations',
        titleEn: 'Greetings',
        durationSeconds: 245,
        type: 'vocab',
        hskLevel: 1,
        youtubeUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa&t=3',
      },
    ],
  };

  it('lit un module HyperFrames : id → slug, champs de rendu retirés, liens canoniques, ordre trié', () => {
    const { courses, problems } = parseManifest(JSON.stringify(hyperframesModule));
    expect(problems).toEqual([]);
    expect(courses).toEqual([
      {
        slug: 'hsk-1',
        titleFr: 'Préparation HSK 1',
        titleEn: 'HSK 1 preparation',
        descriptionFr: 'Les bases.',
        descriptionEn: 'The basics.',
        lessons: [
          {
            order: 1,
            youtubeUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
            titleFr: 'Salutations',
            titleEn: 'Greetings',
            durationSeconds: 245,
          },
          {
            order: 2,
            youtubeUrl: 'https://www.youtube.com/watch?v=bbbbbbbbbbb',
            titleFr: 'Le verbe 是',
            titleEn: 'The verb 是',
            durationSeconds: 300,
          },
        ],
      },
    ]);
  });

  it('accepte une liste de modules et { "modules": [...] }', () => {
    const second = { ...hyperframesModule, id: 'hsk-2' };
    expect(parseManifest(JSON.stringify([hyperframesModule, second])).courses).toHaveLength(2);
    expect(
      parseManifest(JSON.stringify({ modules: [hyperframesModule, second] })).courses.map(
        (course) => course.slug,
      ),
    ).toEqual(['hsk-1', 'hsk-2']);
  });

  it('nomme chaque leçon à corriger', () => {
    const broken = {
      ...hyperframesModule,
      lessons: [
        { order: 1, titleFr: 'Sans lien', durationSeconds: 100 },
        { order: 2, titleFr: 'Lien Vimeo', durationSeconds: 100, youtubeUrl: 'https://vimeo.com/1' },
        { order: 2, titleFr: 'Même position', durationSeconds: 100, youtubeUrl: 'https://youtu.be/ccccccccccc' },
        { order: 3, titleFr: 'Même vidéo', durationSeconds: 100, youtubeUrl: 'https://youtu.be/ccccccccccc' },
        { order: 4, titleFr: '', durationSeconds: 0, youtubeUrl: 'https://youtu.be/ddddddddddd' },
      ],
    };
    const { problems } = parseManifest(JSON.stringify(broken));
    expect(problems).toEqual([
      'hsk-1 · leçon 1 : lien YouTube manquant (ajouter « youtubeUrl »).',
      'hsk-1 · leçon 2 : lien YouTube illisible (https://vimeo.com/1).',
      'hsk-1 · leçon 2 : position déjà utilisée par une autre leçon.',
      'hsk-1 · leçon 3 : même vidéo que la leçon 2.',
      'hsk-1 · leçon 4 : « titleFr » manquant.',
      'hsk-1 · leçon 4 : « durationSeconds » doit être un nombre de secondes (ex. 245).',
    ]);
  });

  it.each([
    ['du texte', 'pas du json', /JSON valide/],
    ['une liste vide', '[]', /aucun module/],
    ['un identifiant invalide', JSON.stringify({ ...hyperframesModule, id: 'HSK 1' }), /identifiant/],
    ['deux fois le même module', JSON.stringify([hyperframesModule, hyperframesModule]), /deux fois/],
    ['un module sans leçon', JSON.stringify({ ...hyperframesModule, lessons: [] }), /aucune leçon/],
  ])('signale %s', (_label, raw, message) => {
    const { problems } = parseManifest(raw);
    expect(problems.length).toBeGreaterThan(0);
    expect(problems.join('\n')).toMatch(message);
  });
});
