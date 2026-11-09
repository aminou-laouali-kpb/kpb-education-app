import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { REPRISES, appliquer } from './legacy-english-copy';

/**
 * L'app est livrée en français uniquement (`kShippedLocale = 'fr'`), et le
 * client affiche ces champs TELS QUELS : `case_api_codec.dart` les passe par
 * `plainLocalized()`, qui recopie la chaîne du serveur dans `fr` ET dans `en`.
 * Une chaîne anglaise écrite ici arrive donc mot pour mot sous les yeux de
 * l'étudiant — c'est ainsi que « Your case is under review » s'est retrouvé
 * dans la liste des dossiers.
 *
 * Rien ne couvrait ces chaînes avant ce test. Il les épingle une par une
 * plutôt que par une heuristique d'accents : du français sans accent
 * (« Dossier transmis ») passerait une heuristique et raterait le but.
 */
/**
 * On n'inspecte que les littéraux de chaîne, jamais le fichier brut : un
 * commentaire qui explique l'algorithme (« round-robin across active
 * counsellors ») est légitime, et faire échouer le test dessus reviendrait à
 * interdire d'écrire des commentaires en anglais dans le code.
 */
const literals = (file: string): string => {
  const src = readFileSync(join(__dirname, file), 'utf8');
  const found = src.match(/'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`(?:[^`\\]|\\.)*`/g);
  return (found ?? []).join('\n');
};

const CASES_SERVICE = literals('cases.service.ts');
const REASSIGNMENT_CRON = literals('case-reassignment-cron.service.ts');

describe('copie des dossiers vue par l’étudiant', () => {
  describe('cases.service.ts', () => {
    const ANGLAIS_INTERDIT = [
      'Your case is under review',
      'The KPB team will review your request and assign a counselor.',
      'A counselor has been assigned',
      'has been assigned to your case and will contact you shortly.',
      'Case submitted',
      'The student created a new case from the mobile app.',
      'Counselor assigned',
      'was assigned automatically (round-robin).',
      'Thank you. Your request has been received by the KPB team.',
      'has been assigned to your request.',
      'Academic profile',
      'Case updated',
      'The case was updated by an admin or counselor.',
      'New message',
      'A new service message was added to the case.',
      'Document uploaded',
      'was uploaded to the case.',
      'Prepare for your scheduled session',
      'Confirm your availability and prepare your supporting documents.',
      'Your counselor will qualify your profile and contact you shortly.',
      'Case scheduled',
      'scheduled a follow-up on this case.',
      'is now the owner of this case.',
      'Task created',
      'was added to the case workflow.',
    ];

    it.each(ANGLAIS_INTERDIT)(
      'n’écrit plus %p en base',
      (phrase) => {
        expect(CASES_SERVICE).not.toContain(phrase);
      },
    );

    const FRANCAIS_ATTENDU = [
      'Ton dossier est en revue',
      'L’équipe KPB va examiner ta demande et t’attribuer un conseiller.',
      'Demande envoyée',
      'Ta demande a été créée depuis l’application.',
      'Conseiller attribué',
      'Un conseiller t’a été attribué',
      'Merci pour ta demande. L’équipe KPB l’a bien reçue.',
      'Dossier mis à jour',
      'Document ajouté',
      'Prépare ton rendez-vous',
      'Rendez-vous programmé',
      'Action ajoutée',
    ];

    it.each(FRANCAIS_ATTENDU)('écrit %p', (phrase) => {
      expect(CASES_SERVICE).toContain(phrase);
    });

    // Audit build 57, n° 5c : la pièce créée d'office ne pouvait jamais passer
    // à « fournie » et plafonnait la jauge de l'élève.
    it('ne crée plus de pièce « Profil académique » à la création', () => {
      expect(CASES_SERVICE).not.toMatch(/title:\s*'Profil académique'/);
      expect(CASES_SERVICE).not.toMatch(/title:\s*'Academic profile'/);
    });

    it('ne montre aucun détail d’implémentation à l’étudiant', () => {
      // « round-robin » décrit l'algorithme d'attribution, pas le dossier.
      expect(CASES_SERVICE).not.toContain('round-robin');
      // « admin or counselor » est du vocabulaire interne ; côté étudiant,
      // l'interlocuteur s'appelle « l'équipe KPB ».
      expect(CASES_SERVICE).not.toMatch(/admin or counselor/i);
    });
  });

  /**
   * Revue avant la 58, constat 5 : l'app tutoie (« Ton dossier est en revue »)
   * et le serveur vouvoyait, si bien que la même carte changeait de ton au
   * premier rafraîchissement. Le garde Flutter ne lit que les traductions de
   * l'app : c'est ici qu'on tient les textes du serveur.
   */
  describe('tutoiement', () => {
    // « rendez-vous » n'est pas un vouvoiement : le trait d'union l'exclut.
    const VOUVOIEMENT = /(^|[^\p{L}-])(votre|vos|vous)(?![\p{L}-])/giu;

    it.each([
      ['cases.service.ts', CASES_SERVICE],
      ['case-reassignment-cron.service.ts', REASSIGNMENT_CRON],
    ])('%s ne vouvoie pas l’élève', (_fichier, texte) => {
      expect(texte.match(VOUVOIEMENT) ?? []).toEqual([]);
    });

    it('reprend en base les phrases écrites au « vous »', () => {
      const reprendreValeur = (table: string, colonne: string, v: string) =>
        REPRISES.filter((r) => r.table === table && r.colonne === colonne).reduce(
          (acc, r) => appliquer(r, acc),
          v,
        );
      expect(
        reprendreValeur('Case', 'nextStepTitle', 'Votre dossier est en revue'),
      ).toBe('Ton dossier est en revue');
      expect(
        reprendreValeur(
          'Case',
          'nextStepDescription',
          'Awa Traoré suit votre dossier et vous contactera prochainement.',
        ),
      ).toBe('Awa Traoré suit ton dossier et te contactera bientôt.');
      expect(
        reprendreValeur(
          'CaseTimelineEvent',
          'description',
          'Votre dossier a été réattribué à Awa Traoré.',
        ),
      ).toBe('Ton dossier a été réattribué à Awa Traoré.');
      expect(
        reprendreValeur(
          'CaseMessage',
          'body',
          'Merci pour votre demande. Awa Traoré suit votre dossier.',
        ),
      ).toBe('Merci pour ta demande. Awa Traoré suit ton dossier.');
    });

    it('aucune cible de reprise ne vouvoie', () => {
      for (const r of REPRISES) {
        expect(r.francais.match(VOUVOIEMENT) ?? []).toEqual([]);
      }
    });
  });

  describe('case-reassignment-cron.service.ts', () => {
    it('n’écrit plus la réattribution en anglais', () => {
      expect(REASSIGNMENT_CRON).not.toContain('Case reassigned');
      expect(REASSIGNMENT_CRON).toContain('Dossier réattribué');
    });

    it('ne divulgue pas le délai interne de réattribution', () => {
      // Le seuil de 10 h est une règle d'exploitation : le jalon lu par
      // l'étudiant ne doit pas l'annoncer.
      expect(REASSIGNMENT_CRON).not.toMatch(/after 10h inactivity/i);
    });
  });
});

/**
 * La table de reprise des dossiers déjà en base (`legacy-english-copy.ts`) doit
 * rester collée au service : elle réécrit l'historique vers les MÊMES phrases
 * que celles écrites aujourd'hui. Si quelqu'un reformule une phrase du service
 * sans toucher la table, les anciens dossiers et les nouveaux diront deux
 * choses différentes — ces tests le font échouer ici plutôt qu'en production.
 */
describe('table de reprise des dossiers existants', () => {
  const SERVICES = `${CASES_SERVICE}\n${REASSIGNMENT_CRON}`;

  /** Le plus long fragment fixe d'un remplacement, hors segment capturé. */
  const fragmentFixe = (francais: string): string =>
    francais
      .split('\\1')
      .reduce((a, b) => (b.length > a.length ? b : a), '');

  /**
   * Phrases que le service n'écrit PLUS du tout (build 59 : un message ne crée
   * plus d'événement « Nouveau message » dans la chronologie). La reprise les
   * garde pour les anciennes lignes anglaises encore en base.
   */
  const RETIREES = new Set([
    'Nouveau message',
    'Un nouveau message a été ajouté au dossier.',
  ]);

  it.each(RETIREES.size ? [...RETIREES] : [])(
    'le service n’écrit plus %p (événement retiré)',
    (phrase) => {
      expect(CASES_SERVICE).not.toContain(`'${phrase}'`);
    },
  );

  it.each(
    REPRISES.filter((r) => !RETIREES.has(r.francais)).map(
      (r) => [`${r.table}.${r.colonne}`, r] as const,
    ),
  )(
    'la cible française de %s est encore celle du service : %p',
    (_cible, regle) => {
      expect(SERVICES).toContain(fragmentFixe(regle.francais));
    },
  );

  it.each(REPRISES.filter((r) => !r.motif).map((r) => [r.anglais, r] as const))(
    'le service n’écrit plus %p, que la reprise corrige en base',
    (_anglais, regle) => {
      expect(SERVICES).not.toContain(regle.anglais);
    },
  );

  it.each(REPRISES.filter((r) => r.motif).map((r) => [r.anglais, r] as const))(
    'la reprise de %p est rejouable',
    (_motif, regle) => {
      // Une reprise relancée par sécurité, ou rejouée sur une réplique, ne doit
      // pas retraiter ce qu'elle a déjà traduit : la sortie française ne doit
      // pas correspondre à son propre motif.
      const rendu = regle.francais.replace(/\\1/g, 'Awa Traoré');
      expect(appliquer(regle, rendu)).toBe(rendu);
    },
  );

  it('ne définit pas deux règles pour la même valeur', () => {
    const cles = REPRISES.map((r) => `${r.table}.${r.colonne}=${r.anglais}`);
    expect(new Set(cles).size).toBe(cles.length);
  });

  it('n’écrit jamais une cible française encore anglaise', () => {
    // Garde-fou bête mais utile : une règle dont la cible contient encore la
    // phrase anglaise signerait un copier-coller raté.
    for (const r of REPRISES) {
      expect(r.francais).not.toBe(r.anglais);
    }
  });
});
