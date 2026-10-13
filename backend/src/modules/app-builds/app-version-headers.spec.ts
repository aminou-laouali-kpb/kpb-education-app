import {
  APP_BUILD_HEADER,
  APP_VERSION_HEADER,
  parseAppBuild,
  parseAppVersion,
  parseAppVersionHeaders,
} from './app-version-headers';

/**
 * Les en-têtes viennent d'un client : tout ce qui n'est pas une version ou un
 * numéro de build propre vaut « inconnu », sans jamais jeter.
 */
describe('parseAppVersionHeaders', () => {
  it('lit les deux en-têtes tels que la build 54 les envoie', () => {
    // Node expose les noms en minuscules, quel que soit l'envoi
    // (`X-KPB-App-Version` côté Dart).
    expect(
      parseAppVersionHeaders({
        [APP_VERSION_HEADER]: '2.3.0',
        [APP_BUILD_HEADER]: '54',
      }),
    ).toEqual({ version: '2.3.0', build: 54 });
  });

  it('vaut inconnu partout pour une build 53, qui n’envoie rien', () => {
    expect(parseAppVersionHeaders({ authorization: 'Bearer x' })).toEqual({
      version: null,
      build: null,
    });
    expect(parseAppVersionHeaders(undefined)).toEqual({
      version: null,
      build: null,
    });
  });

  it('lit chaque en-tête indépendamment', () => {
    expect(
      parseAppVersionHeaders({
        [APP_VERSION_HEADER]: 'n’importe quoi',
        [APP_BUILD_HEADER]: '56',
      }),
    ).toEqual({ version: null, build: 56 });
    expect(
      parseAppVersionHeaders({
        [APP_VERSION_HEADER]: '2.3.0',
        [APP_BUILD_HEADER]: 'abc',
      }),
    ).toEqual({ version: '2.3.0', build: null });
  });
});

describe('parseAppVersion', () => {
  it.each(['2.3.0', '2.3', '10', '2.3.0-beta.1', '2.3.0+56', ' 2.3.0 '])(
    'accepte %p',
    (raw) => {
      expect(parseAppVersion(raw)).toBe(raw.trim());
    },
  );

  it.each([
    undefined,
    '',
    '   ',
    'v2.3.0',
    '2.3.0 beta',
    '2..3',
    '.2.3',
    '2.3.0.1.5',
    'jean.dupont@example.com',
    '<script>',
    '2.3.0, 2.3.0',
    '1.' + '0'.repeat(31),
  ])('refuse %p', (raw) => {
    expect(parseAppVersion(raw)).toBeNull();
  });

  it('refuse au-delà de 32 caractères, même bien formé', () => {
    const at32 = '1.0.0-' + 'a'.repeat(26);
    expect(at32).toHaveLength(32);
    expect(parseAppVersion(at32)).toBe(at32);
    expect(parseAppVersion(at32 + 'a')).toBeNull();
  });

  it('refuse un en-tête répété (tableau)', () => {
    expect(parseAppVersion(['2.3.0', '2.3.0'])).toBeNull();
  });
});

describe('parseAppBuild', () => {
  it.each([
    ['54', 54],
    [' 56 ', 56],
    ['1', 1],
    ['9999999', 9_999_999],
    ['0054', 54],
  ])('accepte %p', (raw, expected) => {
    expect(parseAppBuild(raw)).toBe(expected);
  });

  it.each([
    undefined,
    '',
    '0',
    '0000',
    '-54',
    '+54',
    '54.0',
    '5e1',
    '0x36',
    '10000000',
    '99999999999999999999',
    '54, 54',
    'Infinity',
    'NaN',
  ])('refuse %p', (raw) => {
    expect(parseAppBuild(raw)).toBeNull();
  });

  it('refuse un en-tête répété (tableau)', () => {
    expect(parseAppBuild(['54', '55'])).toBeNull();
  });
});
