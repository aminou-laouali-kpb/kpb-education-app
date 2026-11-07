// Texte du pays France en base (audit de la 57, T5-10) : la fiche annonçait
// « Campus France (universités publiques) — Bientôt disponible · Septembre
// 2026 » alors que la procédure Études en France est ouverte, et que l'app
// (build 58) affiche juste en dessous la carte « Universités publiques ».
//
// On ne réécrit QUE les champs qui portent encore mot pour mot l'ancien texte
// du seed : une retouche faite dans l'admin reste intacte. La condition est
// portée par l'UPDATE lui-même. Rejouable : 0 la seconde fois.
//
// Le seed `seed-countries-m5.ts` n'est PAS utilisé : il réécrit tous les
// champs de tous les pays.

import { M5_COUNTRY_SEEDS } from './data/m5-countries.seed';

export type Executeur = {
  $executeRawUnsafe(query: string, ...values: unknown[]): Promise<number>;
};

const france = M5_COUNTRY_SEEDS.find((c) => c.id === 'fra');
if (!france) throw new Error('Pays « fra » absent du seed M5.');

export const FRANCE_COPY_FIXES: readonly {
  colonne: string;
  ancien: string;
  nouveau: string;
}[] = [
  {
    colonne: 'marketingDescriptionFr',
    ancien:
      "Au lancement, KPB se concentre sur l'admission dans les écoles privées françaises (OMNES, ICN, Schiller, IGENSIA). Campus France pour le public arrive en septembre 2026.",
    nouveau: france.marketingDescriptionFr,
  },
  {
    colonne: 'marketingDescriptionEn',
    ancien:
      'At launch, KPB focuses on private French schools (OMNES, ICN, Schiller, IGENSIA). Public Campus France path opens September 2026.',
    nouveau: france.marketingDescriptionEn,
  },
  {
    colonne: 'mvpNoteFr',
    ancien:
      'Campus France (universités publiques) — Bientôt disponible · Septembre 2026',
    nouveau: france.mvpNoteFr,
  },
  {
    colonne: 'mvpNoteEn',
    ancien:
      'Campus France (public universities) — Coming soon · September 2026',
    nouveau: france.mvpNoteEn,
  },
];

/** Réécrit chaque champ encore à l'ancien texte ; renvoie le détail. */
export async function corrigerFrance(
  db: Executeur,
): Promise<{ colonne: string; n: number }[]> {
  const out: { colonne: string; n: number }[] = [];
  for (const f of FRANCE_COPY_FIXES) {
    const n = await db.$executeRawUnsafe(
      `UPDATE "Country" SET "${f.colonne}" = $1
        WHERE id = 'fra' AND "${f.colonne}" = $2`,
      f.nouveau,
      f.ancien,
    );
    out.push({ colonne: f.colonne, n });
  }
  return out;
}
