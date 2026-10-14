import {
  parseMirrorArgs,
  runMirror,
  type MirrorClient,
} from './scholarship-follow-mirror.cli';

/** Un `$queryRaw` qui rend, dans l'ordre, les réponses données et note le SQL. */
function fakeClient(responses: unknown[][]) {
  const statements: string[] = [];
  const client = {
    $queryRaw: jest.fn(async (strings: TemplateStringsArray) => {
      statements.push(strings.join('?'));
      return responses.shift() ?? [];
    }),
  } as unknown as MirrorClient;
  return { client, statements };
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
      });
      expect(statements).toHaveLength(1);
      expect(statements[0]).not.toMatch(/INSERT|UPDATE/);
    });

    it('--apply : une instruction, impliedFollow sur les seuls couples insérés', async () => {
      const { client, statements } = fakeClient([
        [{ n: 3 }],
        [{ inserted: 3, flagged: 3 }],
      ]);
      await expect(
        runMirror(client, { apply: true, mode: 'outbox_followers' }),
      ).resolves.toMatchObject({ mode: 'apply', candidates: 3, inserted: 3, flagged: 3 });
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
