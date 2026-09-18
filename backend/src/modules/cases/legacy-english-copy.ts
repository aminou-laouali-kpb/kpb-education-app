/**
 * Table de reprise des dossiers créés AVANT le correctif « l'app parle
 * français, le serveur écrivait en anglais ».
 *
 * Le correctif ne vaut que pour les dossiers à venir : les lignes déjà en base
 * gardent leur texte anglais, et le client les affiche telles quelles
 * (`case_api_codec.dart` les passe par `plainLocalized()`). Le texte anglais
 * ressort aussi dans les notifications push, où `milestone-reminder.service.ts`
 * recopie `nextStepTitle` à l'intérieur même de `bodyFr`.
 *
 * Chaque règle est la trace EXACTE d'une écriture de `cases.service.ts` ou de
 * `case-reassignment-cron.service.ts` avant le correctif. On ne réécrit donc
 * jamais qu'une valeur que ces deux services ont eux-mêmes produite : une
 * phrase saisie à la main par un conseiller ne correspond à aucune règle et
 * reste intacte. `cases-student-copy.spec.ts` vérifie en retour que chaque
 * `francais` ci-dessous existe encore dans le service — si quelqu'un y change
 * une formulation, la table doit suivre.
 *
 * Les règles marquées `motif` portent un segment variable (nom du conseiller,
 * titre du document) : c'est un motif ancré `^…$`, la valeur doit correspondre
 * en entier, et `\1` reporte le segment capturé. Ancré en entier + segment
 * reporté = la reprise est rejouable sans rien abîmer (aucun `francais` ne
 * correspond à son propre motif — `cases-student-copy.spec.ts` le vérifie).
 */
export type Reprise = {
  /** Table Postgres, telle que Prisma la nomme (guillemets requis en SQL). */
  readonly table: 'Case' | 'CaseTimelineEvent' | 'CaseMessage' | 'CaseDocument';
  readonly colonne: string;
  /** Valeur anglaise exacte, ou motif ancré `^…$` si `motif` est vrai. */
  readonly anglais: string;
  /** Remplacement français ; `\1` = segment capturé (règles `motif`). */
  readonly francais: string;
  readonly motif?: true;
};

export const REPRISES: readonly Reprise[] = [
  // ── Case.nextStepTitle — la ligne visible depuis la liste des dossiers ────
  {
    table: 'Case',
    colonne: 'nextStepTitle',
    anglais: 'Your case is under review',
    francais: 'Votre dossier est en revue',
  },
  {
    table: 'Case',
    colonne: 'nextStepTitle',
    anglais: 'A counselor has been assigned',
    francais: 'Un conseiller vous a été attribué',
  },
  {
    table: 'Case',
    colonne: 'nextStepTitle',
    anglais: 'Prepare for your scheduled session',
    francais: 'Préparez votre rendez-vous',
  },

  // ── Case.nextStepDescription ─────────────────────────────────────────────
  {
    table: 'Case',
    colonne: 'nextStepDescription',
    anglais: 'The KPB team will review your request and assign a counselor.',
    francais:
      'L’équipe KPB va examiner votre demande et vous attribuer un conseiller.',
  },
  {
    table: 'Case',
    colonne: 'nextStepDescription',
    motif: true,
    anglais: '^(.+) has been assigned to your case and will contact you shortly\\.$',
    francais: '\\1 suit votre dossier et vous contactera prochainement.',
  },
  {
    table: 'Case',
    colonne: 'nextStepDescription',
    anglais: 'Confirm your availability and prepare your supporting documents.',
    francais:
      'Confirmez votre disponibilité et préparez vos pièces justificatives.',
  },
  {
    table: 'Case',
    colonne: 'nextStepDescription',
    anglais: 'Your counselor will qualify your profile and contact you shortly.',
    francais:
      'Votre conseiller va étudier votre profil et vous contactera prochainement.',
  },

  // ── CaseTimelineEvent.title — les jalons de la frise ─────────────────────
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Case submitted',
    francais: 'Demande envoyée',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Counselor assigned',
    francais: 'Conseiller attribué',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Case updated',
    francais: 'Dossier mis à jour',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'New message',
    francais: 'Nouveau message',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Document uploaded',
    francais: 'Document ajouté',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Case scheduled',
    francais: 'Rendez-vous programmé',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Task created',
    francais: 'Action ajoutée',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'title',
    anglais: 'Case reassigned',
    francais: 'Dossier réattribué',
  },

  // ── CaseTimelineEvent.description ────────────────────────────────────────
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    anglais: 'The student created a new case from the mobile app.',
    francais: 'Votre demande a été créée depuis l’application.',
  },
  {
    // Fuite de vocabulaire interne : « round-robin » décrivait l'algorithme
    // d'attribution à l'étudiant qui lisait sa frise.
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^(.+) was assigned automatically \\(round-robin\\)\\.$',
    francais: 'Votre dossier a été attribué à \\1.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    anglais: 'The case was updated by an admin or counselor.',
    francais: 'Le dossier a été mis à jour par l’équipe KPB.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    anglais: 'A new service message was added to the case.',
    francais: 'Un nouveau message a été ajouté au dossier.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^(.+) was uploaded to the case\\.$',
    francais: 'Le document « \\1 » a été ajouté au dossier.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^(.+) scheduled a follow-up on this case\\.$',
    francais: '\\1 a programmé un point de suivi sur votre dossier.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^(.+) is now the owner of this case\\.$',
    francais: '\\1 suit désormais votre dossier.',
  },
  {
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^(.+) was added to the case workflow\\.$',
    francais: 'L’action « \\1 » a été ajoutée à votre dossier.',
  },
  {
    // Fuite de vocabulaire interne : le seuil de 10 h est une règle
    // d'exploitation, elle n'a rien à faire sous les yeux de l'étudiant.
    table: 'CaseTimelineEvent',
    colonne: 'description',
    motif: true,
    anglais: '^Auto-reassigned after 10h inactivity to (.+)\\.$',
    francais: 'Votre dossier a été réattribué à \\1.',
  },

  // ── CaseMessage.body — le message d'accueil du dossier ───────────────────
  {
    table: 'CaseMessage',
    colonne: 'body',
    motif: true,
    anglais: '^Thank you\\. (.+) has been assigned to your request\\.$',
    francais: 'Merci pour votre demande. \\1 suit votre dossier.',
  },
  {
    table: 'CaseMessage',
    colonne: 'body',
    anglais: 'Thank you. Your request has been received by the KPB team.',
    francais: 'Merci pour votre demande. L’équipe KPB l’a bien reçue.',
  },

  // ── CaseDocument.title — le document attendu créé à l'ouverture ──────────
  {
    table: 'CaseDocument',
    colonne: 'title',
    anglais: 'Academic profile',
    francais: 'Profil académique',
  },
];

/**
 * Les colonnes que la reprise touche — sert au relevé du reliquat : ce qui
 * reste en anglais après coup doit être montré, pas deviné.
 */
export const COLONNES_ETUDIANT: readonly { table: string; colonne: string }[] = [
  { table: 'Case', colonne: 'nextStepTitle' },
  { table: 'Case', colonne: 'nextStepDescription' },
  { table: 'CaseTimelineEvent', colonne: 'title' },
  { table: 'CaseTimelineEvent', colonne: 'description' },
  { table: 'CaseMessage', colonne: 'body' },
  { table: 'CaseDocument', colonne: 'title' },
];

/**
 * Traduction JS du motif Postgres, pour les tests. Les deux moteurs ne sont pas
 * le même (ARE côté Postgres, ECMAScript ici) : sur ces motifs — ancres,
 * groupe unique, littéraux échappés — ils coïncident, et c'est
 * `cases-legacy-copy.postgres.spec.ts` qui fait foi sur le comportement réel.
 */
export const appliquer = (regle: Reprise, valeur: string): string => {
  if (!regle.motif) {
    return valeur === regle.anglais ? regle.francais : valeur;
  }
  const re = new RegExp(regle.anglais, 's');
  return re.test(valeur)
    ? valeur.replace(re, regle.francais.replace(/\\1/g, '$1'))
    : valeur;
};

/**
 * Le strict nécessaire d'un client Prisma : le `PrismaClient` comme le client
 * de transaction le satisfont, si bien que le script de reprise et son test
 * d'intégration exécutent le MÊME SQL. Un test qui rejouerait une copie des
 * requêtes ne prouverait rien de ce que le script fait vraiment.
 */
export type Executeur = {
  $queryRawUnsafe<T = unknown>(requete: string, ...valeurs: unknown[]): Promise<T>;
  $executeRawUnsafe(requete: string, ...valeurs: unknown[]): Promise<number>;
};

/**
 * La condition d'une règle — la MÊME au relevé et à l'écriture. C'est l'UPDATE
 * lui-même qui la porte : une valeur modifiée à la main entre les deux n'est
 * jamais écrasée (leçon de #272).
 */
export const conditionSql = (regle: Reprise): string =>
  regle.motif ? `"${regle.colonne}" ~ $1` : `"${regle.colonne}" = $1`;

/** Combien de lignes cette règle reprendrait, sans rien écrire. */
export const compterLignes = async (
  db: Executeur,
  regle: Reprise,
): Promise<number> => {
  const rows = await db.$queryRawUnsafe<{ n: bigint }[]>(
    `SELECT count(*)::bigint AS n FROM "${regle.table}" WHERE ${conditionSql(regle)}`,
    regle.anglais,
  );
  return Number(rows[0]?.n ?? 0);
};

/** Réécrit les lignes d'une règle. Renvoie le nombre de lignes touchées. */
export const reecrire = (db: Executeur, regle: Reprise): Promise<number> =>
  regle.motif
    ? db.$executeRawUnsafe(
        `UPDATE "${regle.table}" SET "${regle.colonne}" = regexp_replace("${regle.colonne}", $1, $2) WHERE "${regle.colonne}" ~ $1`,
        regle.anglais,
        regle.francais,
      )
    : db.$executeRawUnsafe(
        `UPDATE "${regle.table}" SET "${regle.colonne}" = $2 WHERE "${regle.colonne}" = $1`,
        regle.anglais,
        regle.francais,
      );

/** Applique toute la table. À appeler dans une transaction : tout ou rien. */
export const reprendre = async (db: Executeur): Promise<number> => {
  let n = 0;
  for (const regle of REPRISES) n += await reecrire(db, regle);
  return n;
};
