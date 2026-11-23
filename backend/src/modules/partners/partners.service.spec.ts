import { PartnersService } from './partners.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Audit 21 : `GET /partners/featured?limit=abc` passait `take: NaN` à Prisma
 * (500 sur une route publique). Le service retombe désormais sur 12.
 */
describe('PartnersService.listFeatured — borne de `limit`', () => {
  function setup() {
    const findMany = jest.fn(async () => []);
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn({ partner: { findMany } }),
    } as unknown as PrismaService;
    const takeOf = () =>
      (findMany.mock.calls.at(-1) as unknown as [{ take: number }])[0].take;
    return { service: new PartnersService(prisma), takeOf };
  }

  it.each([
    ['NaN (?limit=abc)', Number('abc'), 12],
    ['Infinity (?limit=1e999)', Number('1e999'), 12],
    ['-Infinity', -Infinity, 12],
    ['absent', undefined, 12],
    ['0', 0, 1],
    ['négatif', -5, 1],
    ['trop grand', 500, 24],
    ['décimal', 7.9, 7],
    ['valide', 5, 5],
  ])('limit %s → take entier fini', async (_label, limit, expected) => {
    const { service, takeOf } = setup();
    await service.listFeatured(limit as number | undefined);
    expect(takeOf()).toBe(expected);
    expect(Number.isInteger(takeOf())).toBe(true);
  });
});
