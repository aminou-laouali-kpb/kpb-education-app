// ─────────────────────────────────────────────────────────────────────────────
// Garde-fous des seeds — la moitié pure.
//
// Vit sous src/ (pas scripts/) parce que jest est enraciné sur src/ : c'est ce
// qui rend la décision testable. Les seeds (scripts/seed-partner-schools.ts,
// scripts/seed-omnes-programs.ts, prisma/seed.ts) n'en sont que les appelants.
//
// Pourquoi : `seed:partners` et `seed:omnes` supprimaient puis recréaient tout
// leur espace d'identifiants, et `prisma:seed` réécrit chaque ligne qu'il
// connaît. Relancés sur la production, ils effaçaient Mundiapolis et
// Universiapolis (même préfixe `partner-`) et toutes les corrections faites
// dans l'admin, sans qu'aucune erreur ne le signale.
// ─────────────────────────────────────────────────────────────────────────────

type Environment = Record<string, string | undefined>;

/** Seule valeur qui lève le refus : un `1` posé à la main, pour ce lancement. */
export const PRODUCTION_SEED_OVERRIDE_ENV = 'KPB_ALLOW_PRODUCTION_SEED';

/**
 * Hôtes de base tenus pour locaux. `db` n'y est PAS : c'est le nom de la base
 * de production dans docker-compose.yml. La CI sème `localhost`.
 */
const LOCAL_DATABASE_HOSTS = new Set([
  'localhost',
  '127.0.0.1',
  '::1',
  'postgres-test',
]);

export interface SeedTarget {
  production: boolean;
  /** Ce qui a fait pencher la décision, repris tel quel dans les messages. */
  reason: string;
}

export interface SeedRunDecision {
  allowed: boolean;
  /**
   * À afficher : le refus (stderr) ou l'avertissement d'une exécution en
   * production. Nul quand il n'y a rien à dire (base locale).
   */
  message: string | null;
}

function databaseHost(databaseUrl: string | undefined): string | null {
  const raw = databaseUrl?.trim() ?? '';
  if (!raw) return null;
  try {
    const host = new URL(raw).hostname.toLowerCase();
    // `new URL` garde les crochets d'une adresse IPv6 (`[::1]`).
    return host.replace(/^\[(.*)\]$/, '$1') || null;
  } catch {
    return null;
  }
}

/**
 * La base visée est-elle la production ?
 *
 * Le conteneur `api` pose NODE_ENV=production (Dockerfile et
 * docker-compose.yml), mais un seed lancé depuis un poste avec un `.env` qui
 * pointe vers un hôte distant n'a souvent pas NODE_ENV. Un hôte de base non
 * local compte donc aussi comme production, et une URL absente ou illisible
 * aussi : dans le doute, on refuse.
 */
export function classifySeedTarget(env: Environment = process.env): SeedTarget {
  if (env.NODE_ENV === 'production') {
    return { production: true, reason: 'NODE_ENV=production' };
  }
  const host = databaseHost(env.DATABASE_URL);
  if (host === null) {
    return {
      production: true,
      reason: 'DATABASE_URL absente ou illisible / missing or unreadable',
    };
  }
  if (!LOCAL_DATABASE_HOSTS.has(host)) {
    return {
      production: true,
      reason: `hôte de base non local / non-local database host « ${host} »`,
    };
  }
  return { production: false, reason: `base locale / local database (${host})` };
}

export function isProductionSeedOverridden(
  env: Environment = process.env,
): boolean {
  return env[PRODUCTION_SEED_OVERRIDE_ENV] === '1';
}

/**
 * Décision pure : un seed tourne hors production, ou en production sur une
 * base qui ne contient encore AUCUNE des lignes qu'il écrirait (première
 * installation), ou sur dérogation explicite. Tout le reste est refusé.
 */
export function decideSeedRun(input: {
  seed: string;
  target: SeedTarget;
  overridden: boolean;
  existingRows: number;
}): SeedRunDecision {
  const { seed, target, overridden, existingRows } = input;
  if (!target.production) return { allowed: true, message: null };

  if (existingRows === 0) {
    return {
      allowed: true,
      message:
        `[${seed}] Production (${target.reason}) : aucune ligne de ce seed en base, première installation — exécution autorisée.\n` +
        `[${seed}] Production (${target.reason}): none of this seed's rows exist yet, first install — run allowed.`,
    };
  }

  if (overridden) {
    return {
      allowed: true,
      message:
        `[${seed}] ATTENTION : production (${target.reason}), ${existingRows} ligne(s) de ce seed déjà en base, ${PRODUCTION_SEED_OVERRIDE_ENV}=1 — exécution forcée.\n` +
        `[${seed}] WARNING: production (${target.reason}), ${existingRows} row(s) of this seed already exist, ${PRODUCTION_SEED_OVERRIDE_ENV}=1 — forced run.`,
    };
  }

  return {
    allowed: false,
    message: [
      `[${seed}] REFUS : base de production (${target.reason}) qui contient déjà ${existingRows} ligne(s) de ce seed.`,
      '  Relancer un seed sur une base vivante peut réécrire ou recréer des données corrigées dans l’admin.',
      `  Pour forcer en connaissance de cause : ${PRODUCTION_SEED_OVERRIDE_ENV}=1 npm run ${seed}`,
      `[${seed}] REFUSED: production database (${target.reason}) already holds ${existingRows} row(s) of this seed.`,
      '  Re-running a seed on a live database can overwrite or recreate data edited in the admin.',
      `  To force it deliberately: ${PRODUCTION_SEED_OVERRIDE_ENV}=1 npm run ${seed}`,
    ].join('\n'),
  };
}

/**
 * Ce que les seeds appellent. Ne compte les lignes existantes qu'en
 * production : hors production le comptage ne déciderait rien.
 */
export async function checkProductionSeed(options: {
  seed: string;
  countExistingRows: () => Promise<number>;
  env?: Environment;
}): Promise<SeedRunDecision> {
  const env = options.env ?? process.env;
  const target = classifySeedTarget(env);
  return decideSeedRun({
    seed: options.seed,
    target,
    overridden: isProductionSeedOverridden(env),
    existingRows: target.production ? await options.countExistingRows() : 0,
  });
}

/**
 * `programIds` d'un établissement que le seed vient de créer : les formations
 * qui lui sont réellement rattachées en base, dans l'ordre du seed (l'app
 * affiche les trois premières en aperçu), puis celles qu'il ne connaît pas.
 *
 * Une formation du seed déjà présente mais rattachée AILLEURS (déplacée dans
 * l'admin) n'est pas listée : la lister afficherait une formation d'un autre
 * établissement.
 */
export function linkedProgramIds(
  seedOrder: readonly string[],
  attachedIds: readonly string[],
): string[] {
  const attached = new Set(attachedIds);
  const seeded = new Set(seedOrder);
  return [
    ...seedOrder.filter((id) => attached.has(id)),
    ...[...attached].filter((id) => !seeded.has(id)).sort(),
  ];
}
