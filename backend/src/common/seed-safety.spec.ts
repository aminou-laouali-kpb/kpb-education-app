import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  checkProductionSeed,
  classifySeedTarget,
  decideSeedRun,
  linkedProgramIds,
  PRODUCTION_SEED_OVERRIDE_ENV,
} from './seed-safety';

const LOCAL_URL = 'postgresql://kpb:kpb@localhost:5432/kpb_ci?schema=public';
// L'URL que docker-compose.yml donne au conteneur `api`.
const COMPOSE_URL = 'postgresql://kpb:secret@db:5432/kpb?schema=public';

describe('classifySeedTarget', () => {
  it('NODE_ENV=production suffit, même sur un hôte local', () => {
    expect(
      classifySeedTarget({ NODE_ENV: 'production', DATABASE_URL: LOCAL_URL }),
    ).toEqual({ production: true, reason: 'NODE_ENV=production' });
  });

  // C'est la configuration exacte de la CI (`backend-ci.yml`) : si elle
  // basculait en production, `prisma:seed` y serait refusé.
  it('la base de CI (localhost, sans NODE_ENV) n’est pas la production', () => {
    expect(classifySeedTarget({ DATABASE_URL: LOCAL_URL }).production).toBe(
      false,
    );
  });

  it.each([
    'postgresql://u:p@127.0.0.1:5432/kpb',
    'postgresql://u:p@[::1]:5432/kpb',
    'postgresql://u:p@postgres-test:5432/kpb',
    'postgresql://u:p@LOCALHOST:5432/kpb',
  ])('hôte local : %s', (url) => {
    expect(classifySeedTarget({ DATABASE_URL: url }).production).toBe(false);
  });

  // Le seed lancé depuis un poste avec un `.env` qui vise la vraie base n'a
  // pas NODE_ENV : l'hôte doit suffire à refuser.
  it.each([
    COMPOSE_URL,
    'postgresql://u:p@api.kpbeducation.cloud:5432/kpb',
    'postgresql://u:p@10.0.0.12:5432/kpb',
  ])('hôte non local sans NODE_ENV : %s', (url) => {
    const target = classifySeedTarget({ NODE_ENV: 'development', DATABASE_URL: url });
    expect(target.production).toBe(true);
    expect(target.reason).toContain('non-local');
  });

  it.each([undefined, '', '   ', 'pas une url'])(
    'DATABASE_URL absente ou illisible (%p) : on refuse dans le doute',
    (url) => {
      expect(classifySeedTarget({ DATABASE_URL: url }).production).toBe(true);
    },
  );
});

describe('decideSeedRun', () => {
  const production = { production: true, reason: 'NODE_ENV=production' };
  const local = { production: false, reason: 'base locale' };

  it('hors production : toujours autorisé, sans message', () => {
    expect(
      decideSeedRun({
        seed: 'seed:partners',
        target: local,
        overridden: false,
        existingRows: 500,
      }),
    ).toEqual({ allowed: true, message: null });
  });

  it('production vide de ces lignes : première installation, autorisée', () => {
    const decision = decideSeedRun({
      seed: 'seed:partners',
      target: production,
      overridden: false,
      existingRows: 0,
    });
    expect(decision.allowed).toBe(true);
    expect(decision.message).toContain('première installation');
    expect(decision.message).toContain('first install');
  });

  it('production peuplée sans dérogation : refus bilingue qui dit comment forcer', () => {
    const decision = decideSeedRun({
      seed: 'seed:omnes',
      target: production,
      overridden: false,
      existingRows: 211,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.message).toContain('REFUS');
    expect(decision.message).toContain('REFUSED');
    expect(decision.message).toContain('211');
    expect(decision.message).toContain(
      `${PRODUCTION_SEED_OVERRIDE_ENV}=1 npm run seed:omnes`,
    );
  });

  it('production peuplée avec dérogation : autorisée, mais le dit', () => {
    const decision = decideSeedRun({
      seed: 'prisma:seed',
      target: production,
      overridden: true,
      existingRows: 3,
    });
    expect(decision.allowed).toBe(true);
    expect(decision.message).toContain('ATTENTION');
    expect(decision.message).toContain('WARNING');
  });
});

describe('checkProductionSeed', () => {
  it('ne compte rien hors production', async () => {
    const count = jest.fn(async () => 42);
    const decision = await checkProductionSeed({
      seed: 'seed:partners',
      countExistingRows: count,
      env: { DATABASE_URL: LOCAL_URL },
    });
    expect(decision.allowed).toBe(true);
    expect(count).not.toHaveBeenCalled();
  });

  it('refuse le conteneur de production quand les lignes existent', async () => {
    const decision = await checkProductionSeed({
      seed: 'seed:partners',
      countExistingRows: async () => 128,
      env: { NODE_ENV: 'production', DATABASE_URL: COMPOSE_URL },
    });
    expect(decision.allowed).toBe(false);
  });

  it('autorise la première installation du conteneur de production', async () => {
    const decision = await checkProductionSeed({
      seed: 'seed:partners',
      countExistingRows: async () => 0,
      env: { NODE_ENV: 'production', DATABASE_URL: COMPOSE_URL },
    });
    expect(decision.allowed).toBe(true);
  });

  // La dérogation est un `1` explicite. « true », « yes » ou une valeur vide
  // ne lèvent pas un garde-fou qui protège des données réelles.
  it.each([
    ['1', true],
    ['true', false],
    ['yes', false],
    ['0', false],
    ['', false],
  ])('%s=%p', async (value, allowed) => {
    const decision = await checkProductionSeed({
      seed: 'seed:omnes',
      countExistingRows: async () => 10,
      env: {
        NODE_ENV: 'production',
        DATABASE_URL: COMPOSE_URL,
        [PRODUCTION_SEED_OVERRIDE_ENV]: value,
      },
    });
    expect(decision.allowed).toBe(allowed);
  });
});

describe('linkedProgramIds', () => {
  it('garde l’ordre du seed pour les formations rattachées', () => {
    expect(linkedProgramIds(['p-1', 'p-2', 'p-3'], ['p-3', 'p-1', 'p-2'])).toEqual(
      ['p-1', 'p-2', 'p-3'],
    );
  });

  it('ne liste pas une formation du seed rattachée ailleurs', () => {
    expect(linkedProgramIds(['p-1', 'p-2'], ['p-2'])).toEqual(['p-2']);
  });

  it('ajoute, triées, les formations rattachées que le seed ne connaît pas', () => {
    expect(linkedProgramIds(['p-1'], ['z-9', 'p-1', 'a-0'])).toEqual([
      'p-1',
      'a-0',
      'z-9',
    ]);
  });
});

// Une fonction pure ne protège rien tant que les seeds ne l'appellent pas, et
// un seed n'est sûr que s'il n'efface plus rien. Le code est lu sans ses
// commentaires : la documentation parle justement de `deleteMany`.
describe('les seeds appellent le garde-fou et ne suppriment plus rien', () => {
  const read = (relative: string) =>
    fs
      .readFileSync(path.join(__dirname, '../..', relative), 'utf8')
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/\/\/.*$/gm, '');

  it.each([
    ['scripts/seed-partner-schools.ts', 'seed:partners'],
    ['scripts/seed-omnes-programs.ts', 'seed:omnes'],
    ['prisma/seed.ts', 'prisma:seed'],
  ])('%s', (file, seed) => {
    const code = read(file);
    expect(code).toContain('checkProductionSeed(');
    expect(code).toContain(`seed: '${seed}'`);
    expect(code).not.toMatch(/(prisma|tx)\.\w+\.delete(Many)?\(/);
  });

  it.each(['scripts/seed-partner-schools.ts', 'scripts/seed-omnes-programs.ts'])(
    '%s ne modifie jamais une ligne existante',
    (file) => {
      const code = read(file);
      // `createHash(...).update(...)` n'écrit rien : seuls les appels Prisma comptent.
      expect(code).not.toMatch(/(prisma|tx)\.\w+\.update(Many)?\(/);
      // Un upsert n'est acceptable qu'avec une mise à jour vide.
      for (const match of code.matchAll(/\.upsert\(\{[\s\S]*?update:\s*([^,]+),/g)) {
        expect(match[1].trim()).toBe('{}');
      }
    },
  );
});

describe('seed:catalog', () => {
  // `seed:catalog` est la commande « tout le catalogue » documentée pour la
  // production : elle ne doit plus enchaîner les seeds partenaires et OMNES.
  it('n’enchaîne plus seed:omnes ni seed:partners, qui restent disponibles seuls', () => {
    const pkg = JSON.parse(
      fs.readFileSync(path.join(__dirname, '../../package.json'), 'utf8'),
    ) as { scripts: Record<string, string> };
    expect(pkg.scripts['seed:catalog']).not.toMatch(/seed:omnes|seed:partners/);
    expect(pkg.scripts['seed:omnes']).toBeDefined();
    expect(pkg.scripts['seed:partners']).toBeDefined();
  });
});
