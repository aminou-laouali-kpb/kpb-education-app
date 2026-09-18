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
      'Votre dossier est en revue',
      'L’équipe KPB va examiner votre demande et vous attribuer un conseiller.',
      'Demande envoyée',
      'Votre demande a été créée depuis l’application.',
      'Conseiller attribué',
      'Un conseiller vous a été attribué',
      'Merci pour votre demande. L’équipe KPB l’a bien reçue.',
      'Profil académique',
      'Dossier mis à jour',
      'Nouveau message',
      'Document ajouté',
      'Préparez votre rendez-vous',
      'Rendez-vous programmé',
      'Action ajoutée',
    ];

    it.each(FRANCAIS_ATTENDU)('écrit %p', (phrase) => {
      expect(CASES_SERVICE).toContain(phrase);
    });

    it('ne montre aucun détail d’implémentation à l’étudiant', () => {
      // « round-robin » décrit l'algorithme d'attribution, pas le dossier.
      expect(CASES_SERVICE).not.toContain('round-robin');
      // « admin or counselor » est du vocabulaire interne ; côté étudiant,
      // l'interlocuteur s'appelle « l'équipe KPB ».
      expect(CASES_SERVICE).not.toMatch(/admin or counselor/i);
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

  it.each(REPRISES.map((r) => [`${r.table}.${r.colonne}`, r] as const))(
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
