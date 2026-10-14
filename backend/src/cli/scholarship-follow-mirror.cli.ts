/**
 * Bascule « Suivre » (chantier C) : chaque alerte « M'avertir » non mise en
 * sourdine devient aussi un favori.
 *
 * À lancer au passage en `KPB_SCHOLARSHIP_OPENING_MODE=outbox_followers`, où
 * « Suivre » = favori + alerte d'ouverture + rappels de date limite (décision
 * propriétaire). Effets acceptés : un élève qui n'avait que l'alerte reçoit
 * désormais les rappels J-30…J-0 et voit la bourse dans ses favoris et dans
 * le récapitulatif hebdomadaire.
 *
 *   npm run follow:mirror-alerts                    # --dry-run (défaut)
 *   npm run follow:mirror-alerts -- --apply         # mode outbox_followers exigé
 *   npm run follow:mirror-alerts -- --apply --force # hors de ce mode
 *
 * Idempotent : une seconde exécution n'insère rien. `impliedFollow` est posé
 * sur EXACTEMENT les couples insérés — « cloche coupée » défait alors ce que la
 * bascule a fait, sans toucher un favori que l'élève avait mis lui-même.
 *
 * Ce fichier vit sous `src/` : seule `dist` est livrée dans l'image
 * (`scholarships-catalog.cli.ts`). Il n'imprime que des comptes.
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  readScholarshipOpeningMode,
  type ScholarshipOpeningMode,
} from '../modules/scholarships-index/opening/scholarship-opening.contract';

const USAGE =
  'Usage: follow:mirror-alerts [--dry-run | --apply [--force]]  (défaut : --dry-run)';

export interface MirrorArgs {
  apply: boolean;
  force: boolean;
}

export function parseMirrorArgs(argv: readonly string[]): MirrorArgs | string {
  let apply = false;
  let dryRun = false;
  let force = false;
  for (const arg of argv) {
    if (arg === '--apply') apply = true;
    else if (arg === '--dry-run') dryRun = true;
    else if (arg === '--force') force = true;
    else return `Unknown argument "${arg.slice(0, 40)}". ${USAGE}`;
  }
  if (apply && dryRun) return `Choose one mode: --dry-run or --apply. ${USAGE}`;
  if (force && !apply) return `--force only applies with --apply. ${USAGE}`;
  return { apply, force };
}

export interface MirrorResult {
  mode: 'dry-run' | 'apply';
  openingMode: ScholarshipOpeningMode;
  /** Alertes non en sourdine d'une bourse existante, sans favori. */
  candidates: number;
  /** Favoris insérés (0 en --dry-run ou refus). */
  inserted: number;
  /** Alertes passées à `impliedFollow = true` (= couples insérés). */
  flagged: number;
  /** Pourquoi `--apply` n'a rien écrit ; `null` sinon. */
  refused: string | null;
}

/** Le client dont la bascule a besoin : un `$queryRaw`. */
export type MirrorClient = Pick<PrismaClient, '$queryRaw'>;

export async function runMirror(
  prisma: MirrorClient,
  options: {
    apply: boolean;
    force?: boolean;
    mode?: ScholarshipOpeningMode;
  },
): Promise<MirrorResult> {
  const openingMode = options.mode ?? readScholarshipOpeningMode();
  const [{ n: candidates }] = await prisma.$queryRaw<{ n: number }[]>`
    SELECT count(*)::int AS "n"
    FROM "ScholarshipAlertSubscription" a
    JOIN "Scholarship" s ON s."id" = a."scholarshipId"
    WHERE a."mutedAt" IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM "SavedItem" si
        WHERE si."userId" = a."userId"
          AND si."itemType" = 'scholarship'
          AND si."itemId" = a."scholarshipId"
      )
  `;
  const result: MirrorResult = {
    mode: options.apply ? 'apply' : 'dry-run',
    openingMode,
    candidates,
    inserted: 0,
    flagged: 0,
    refused: null,
  };
  if (!options.apply) return result;

  if (openingMode !== 'outbox_followers' && !options.force) {
    // Hors de ce mode, un favori de plus déclenche des rappels sans que la
    // bourse soit « suivie » au sens de l'annonce : on refuse sans --force.
    result.refused = `KPB_SCHOLARSHIP_OPENING_MODE is "${openingMode}", not "outbox_followers"; rerun with --force to mirror anyway.`;
    return result;
  }

  // Une seule instruction : l'insertion et le marquage ne peuvent pas se
  // séparer, et `impliedFollow` ne touche que les couples réellement insérés.
  const [counts] = await prisma.$queryRaw<{ inserted: number; flagged: number }[]>`
    WITH ins AS (
      INSERT INTO "SavedItem" ("id", "userId", "itemType", "itemId", "createdAt")
      SELECT gen_random_uuid()::text, a."userId", 'scholarship', a."scholarshipId", now()
      FROM "ScholarshipAlertSubscription" a
      JOIN "Scholarship" s ON s."id" = a."scholarshipId"
      WHERE a."mutedAt" IS NULL
      ON CONFLICT ("userId", "itemType", "itemId") DO NOTHING
      RETURNING "userId", "itemId"
    ),
    flagged AS (
      UPDATE "ScholarshipAlertSubscription" a
      SET "impliedFollow" = true, "updatedAt" = now()
      FROM ins
      WHERE a."userId" = ins."userId" AND a."scholarshipId" = ins."itemId"
      RETURNING a."id"
    )
    SELECT (SELECT count(*) FROM ins)::int AS "inserted",
           (SELECT count(*) FROM flagged)::int AS "flagged"
  `;
  result.inserted = counts?.inserted ?? 0;
  result.flagged = counts?.flagged ?? 0;
  return result;
}

async function main(): Promise<void> {
  const parsed = parseMirrorArgs(process.argv.slice(2));
  if (typeof parsed === 'string') {
    console.error(parsed);
    process.exitCode = 2;
    return;
  }
  if (!process.env.DATABASE_URL && existsSync('.env')) {
    loadEnvFile('.env');
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  const prisma = new PrismaClient();
  try {
    const result = await runMirror(prisma, parsed);
    console.log(JSON.stringify(result, null, 2));
    if (result.refused) {
      console.error(result.refused);
      process.exitCode = 2;
    } else if (!parsed.apply) {
      console.log('Mode --dry-run : aucune écriture. Relancer avec --apply.');
    }
  } finally {
    await prisma.$disconnect();
  }
}

// Garde d'exécution directe : sans elle, importer ce module depuis un test
// ouvrirait une connexion Prisma et lancerait la bascule.
if (require.main === module) {
  void main().catch((error: unknown) => {
    console.error(
      `follow:mirror-alerts a échoué : ${error instanceof Error ? error.message : String(error)}`,
    );
    process.exitCode = 1;
  });
}
