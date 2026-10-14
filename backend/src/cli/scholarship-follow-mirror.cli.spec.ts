import {
  parseMirrorArgs,
  runMirror,
  type MirrorClient,
} from './scholarship-follow-mirror.cli';

/** Un `$queryRaw` qui rend, dans l'ordre, les réponses données et note le SQL. */
function fakeClient(responses: unknown[][], analyzeFails = false) {
  const statements: string[] = [];
  const executes: string[] = [];
  const client = {
    $queryRaw: jest.fn(async (strings: TemplateStringsArray) => {
      statements.push(strings.join('?'));
      return responses.shift() ?? [];
    }),
    $executeRaw: jest.fn(async (strings: TemplateStringsArray) => {
      executes.push(strings.join('?'));
      if (analyzeFails) throw new Error('must be owner of table');
      return 0;
    }),
  } as unknown as MirrorClient;
  return { client, statements, executes };
}

describe('follow:mirror-alerts', () => {
  describe('parseMirrorArgs', () => {
    it('--dry-run par défaut', () => {
      expect(parseMirrorArgs([])).toEqual({ apply: false, force: false });
      expect(parseMirrorArgs(['--dry-run'])).toEqual({ apply: false, force: false });
    });

    it('--apply, avec ou sans --force', () => {
      expect(parseMirrorArgs(['--apply'])).toEqual({ apply: true, force: false });
      expect(parseMirrorArgs(['--apply', '--force'])).toEqual({ apply: true, force: true });
    });

    it('refuse les combinaisons absurdes et les inconnus', () => {
      expect(parseMirrorArgs(['--apply', '--dry-run'])).toContain('Choose one mode');
      expect(parseMirrorArgs(['--force'])).toContain('--force only applies');
      expect(parseMirrorArgs(['--yes'])).toContain('Unknown argument');
    });
  });

  describe('runMirror', () => {
    it('--dry-run : compte les candidats, n’écrit rien', async () => {
      const { client, statements } = fakeClient([[{ n: 42 }]]);
      await expect(
        runMirror(client, { apply: false, mode: 'outbox_followers' }),
      ).resolves.toEqual({
        mode: 'dry-run',
        openingMode: 'outbox_followers',
        candidates: 42,
        inserted: 0,
        flagged: 0,
        refused: null,
        analyzed: false,
      });
      expect(statements).toHaveLength(1);
      expect(statements[0]).not.toMatch(/INSERT|UPDATE/);
    });

    it('--apply : une instruction, impliedFollow sur les seuls couples insérés', async () => {
      const { client, statements, executes } = fakeClient([
        [{ n: 3 }],
        [{ inserted: 3, flagged: 3 }],
      ]);
      await expect(
        runMirror(client, { apply: true, mode: 'outbox_followers' }),
      ).resolves.toMatchObject({
        mode: 'apply',
        candidates: 3,
        inserted: 3,
        flagged: 3,
        analyzed: true,
      });
      // Statistiques recalculées : sinon la requête « qui suit » d'une bourse
      // aux favoris tout neufs est planifiée en boucle quadratique.
      expect(executes).toEqual(['ANALYZE "SavedItem", "ScholarshipAlertSubscription"']);
      expect(statements).toHaveLength(2);
      expect(statements[1]).toContain('ON CONFLICT ("userId", "itemType", "itemId") DO NOTHING');
      expect(statements[1]).toContain('"impliedFollow" = true');
      expect(statements[1]).toContain('FROM ins');
      expect(statements[1]).toContain('"mutedAt" IS NULL');
    });

    it.each(['legacy', 'outbox_alerts'] as const)(
      '--apply hors outbox_followers (%s) : refusé sans --force, rien d’écrit',
      async (mode) => {
        const { client, statements } = fakeClient([[{ n: 5 }]]);
        const result = await runMirror(client, { apply: true, mode });
        expect(result.refused).toContain('outbox_followers');
        expect(result.inserted).toBe(0);
        expect(statements).toHaveLength(1);
      },
    );

    it('rien d’inséré : pas d’ANALYZE ; un ANALYZE refusé n’annule rien', async () => {
      const idle = fakeClient([[{ n: 0 }], [{ inserted: 0, flagged: 0 }]]);
      await runMirror(idle.client, { apply: true, mode: 'outbox_followers' });
      expect(idle.executes).toEqual([]);

      const denied = fakeClient([[{ n: 2 }], [{ inserted: 2, flagged: 2 }]], true);
      await expect(
        runMirror(denied.client, { apply: true, mode: 'outbox_followers' }),
      ).resolves.toMatchObject({ inserted: 2, analyzed: false });
    });

    it('--apply --force passe outre le mode', async () => {
      const { client } = fakeClient([[{ n: 1 }], [{ inserted: 1, flagged: 1 }]]);
      const result = await runMirror(client, { apply: true, force: true, mode: 'legacy' });
      expect(result).toMatchObject({ refused: null, inserted: 1 });
    });

    it('lit le mode dans l’environnement par défaut', async () => {
      const previous = process.env.KPB_SCHOLARSHIP_OPENING_MODE;
      process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
      try {
        const { client } = fakeClient([[{ n: 0 }]]);
        const result = await runMirror(client, { apply: false });
        expect(result.openingMode).toBe('outbox_alerts');
      } finally {
        if (previous === undefined) delete process.env.KPB_SCHOLARSHIP_OPENING_MODE;
        else process.env.KPB_SCHOLARSHIP_OPENING_MODE = previous;
      }
    });
  });
});
