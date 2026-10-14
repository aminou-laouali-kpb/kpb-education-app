import { resolveRequestId } from './request-id';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe('resolveRequestId', () => {
  it('reprend un identifiant sûr fourni par le client', () => {
    expect(resolveRequestId('admin-web:4f2c.9_a')).toBe('admin-web:4f2c.9_a');
    expect(resolveRequestId('  req-42  ')).toBe('req-42');
  });

  it('prend la première valeur d’un en-tête répété', () => {
    expect(resolveRequestId(['req-1', 'req-2'])).toBe('req-1');
  });

  it.each([
    ['absent', undefined],
    ['vide', '   '],
    ['tableau vide', []],
    ['avec espace', 'req 42'],
    ['deux valeurs jointes par Node', 'req-1, req-2'],
    ['retour à la ligne (injection de journal)', 'req-1\nfaux=1'],
    ['trop long', 'a'.repeat(129)],
  ])('génère un UUID quand l’en-tête est %s', (_label, header) => {
    const resolved = resolveRequestId(header);
    expect(resolved).toMatch(UUID);
  });

  it('accepte exactement 128 caractères', () => {
    const id = 'a'.repeat(128);
    expect(resolveRequestId(id)).toBe(id);
  });
});
