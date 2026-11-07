import { corrigerFrance, FRANCE_COPY_FIXES } from './france-copy-fix';

describe('texte du pays France (audit 57, T5-10)', () => {
  it('le nouveau texte ne parle plus de « Campus France » ni de « Bientôt »', () => {
    for (const f of FRANCE_COPY_FIXES) {
      expect(f.nouveau).not.toMatch(/Campus France|Bientôt|Coming soon|2026/);
      expect(f.nouveau).not.toBe(f.ancien);
    }
    const fr = FRANCE_COPY_FIXES.find(
      (f) => f.colonne === 'marketingDescriptionFr',
    );
    expect(fr?.nouveau).toContain('Études en France');
  });

  it('réécrit seulement là où l’ancien texte est encore en base, ligne fra', async () => {
    const calls: unknown[][] = [];
    const db = {
      $executeRawUnsafe: jest.fn(async (...args: unknown[]) => {
        calls.push(args);
        return 1;
      }),
    };
    const detail = await corrigerFrance(db);
    expect(detail).toHaveLength(4);
    for (const [sql, nouveau, ancien] of calls) {
      expect(sql).toMatch(/WHERE id = 'fra' AND "\w+" = \$2/);
      expect(
        FRANCE_COPY_FIXES.some(
          (f) => f.nouveau === nouveau && f.ancien === ancien,
        ),
      ).toBe(true);
    }
  });
});
