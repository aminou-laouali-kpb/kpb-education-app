import {
  buildSegments,
  canonicalizeMentionTokens,
  communitySearchText,
  excerptOf,
  extractHashtags,
  extractMentionRefs,
  hashtagKey,
  plainText,
  searchTerms,
} from './community-text';

const labels = new Map([
  ['scholarship:clx12ab', { labelFr: 'Bourse Eiffel', labelEn: 'Eiffel Scholarship' }],
  ['country:fra', { labelFr: 'France', labelEn: 'France' }],
]);
const allowAll = () => true;
const allowNone = () => false;

describe('jetons de mention', () => {
  it('extrait les mentions dans l’ordre, sans doublon', () => {
    const body = 'Qui a eu @[Eiffel](scholarship:clx12ab) pour la @[France](country:fra) ? @[Eiffel](scholarship:clx12ab)';
    expect(extractMentionRefs(body)).toEqual([
      { type: 'scholarship', id: 'clx12ab', label: 'Eiffel' },
      { type: 'country', id: 'fra', label: 'France' },
    ]);
  });

  it('ignore ce qui n’est pas un jeton complet', () => {
    expect(extractMentionRefs('@Eiffel, @[x](user:1), @[y](country:)')).toEqual([]);
  });

  it('réécrit le libellé avec celui du catalogue', () => {
    expect(
      canonicalizeMentionTokens('Merci @[eifel](scholarship:clx12ab) !', new Map([['scholarship:clx12ab', 'Bourse Eiffel']])),
    ).toBe('Merci @[Bourse Eiffel](scholarship:clx12ab) !');
  });
});

describe('hashtags', () => {
  it('normalise la clé sans accents ni casse', () => {
    expect(hashtagKey('CampusFrance')).toBe('campusfrance');
    expect(hashtagKey('Études')).toBe('etudes');
  });

  it('extrait hors URL et hors jetons, refuse les nombres seuls', () => {
    expect(
      extractHashtags('#CV et #CampusFrance, voir https://x.org/#ancre, #2026, #cv, a#b, @[x](country:fra)'),
    ).toEqual([
      { tag: 'cv', display: 'CV' },
      { tag: 'campusfrance', display: 'CampusFrance' },
    ]);
  });
});

describe('segments', () => {
  it('découpe texte, mention, hashtag et lien autorisé', () => {
    const body = 'Qui a eu @[Bourse Eiffel](scholarship:clx12ab) ? #CampusFrance https://www.campusfrance.org/fr.';
    expect(buildSegments(body, labels, 'fr', allowAll)).toEqual([
      { kind: 'text', text: 'Qui a eu ' },
      { kind: 'mention', type: 'scholarship', id: 'clx12ab', label: 'Bourse Eiffel' },
      { kind: 'text', text: ' ? ' },
      { kind: 'hashtag', tag: 'campusfrance', display: 'CampusFrance' },
      { kind: 'text', text: ' ' },
      { kind: 'link', url: 'https://www.campusfrance.org/fr', text: 'https://www.campusfrance.org/fr' },
      { kind: 'text', text: '.' },
    ]);
  });

  it('localise le libellé de la mention et laisse en texte un lien hors liste', () => {
    const segments = buildSegments('@[Bourse Eiffel](scholarship:clx12ab) https://evil.xyz', labels, 'en', allowNone);
    expect(segments[0]).toEqual({ kind: 'mention', type: 'scholarship', id: 'clx12ab', label: 'Eiffel Scholarship' });
    expect(segments[1]).toEqual({ kind: 'text', text: ' https://evil.xyz' });
  });
});

describe('extrait et recherche', () => {
  it('rend les mentions en « @libellé » et coupe au mot', () => {
    expect(plainText('Merci @[Bourse Eiffel](scholarship:clx12ab)', labels, 'fr')).toBe('Merci @Bourse Eiffel');
    const long = `${'mot '.repeat(80)}fin`;
    const excerpt = excerptOf(long, labels, 'fr');
    expect(excerpt.length).toBeLessThanOrEqual(240);
    expect(excerpt.endsWith('…')).toBe(true);
    expect(excerpt).not.toMatch(/\s…$/);
  });

  it('texte cherchable : titre, corps, hashtags, libellés FR et EN, sans accents', () => {
    const text = communitySearchText({
      title: 'Délai Campus France',
      body: 'Réponse @[Bourse Eiffel](scholarship:clx12ab) ?',
      hashtags: [{ tag: 'visa', display: 'Visa' }],
      mentionLabels: [{ labelFr: 'Bourse Eiffel', labelEn: 'Eiffel Scholarship' }],
    });
    expect(text).toContain('delai campus france');
    expect(text).toContain('reponse');
    expect(text).toContain('visa');
    expect(text).toContain('eiffel scholarship');
    expect(text).not.toContain('scholarship:clx12ab');
  });

  it('les termes de recherche sont normalisés et dédoublonnés', () => {
    expect(searchTerms('Délai  délai Campus-France')).toEqual(['delai', 'campus', 'france']);
  });
});
