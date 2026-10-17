import {
  ASSIST_BRIDGE_RULES_VERSION,
  ASSIST_NEEDS,
  catalogJson,
  detectNeed,
  needById,
  type AssistNeedId,
} from './assist-bridge.rules';

function need(text: string): AssistNeedId | null {
  const d = detectNeed(text);
  return d.detected ? d.needId : null;
}

function skip(text: string): string | null {
  const d = detectNeed(text);
  return d.detected ? null : d.skip;
}

/**
 * Bot « Passerelle » — le catalogue versionné et la détection (fonctions
 * pures). Exemples réalistes FR/EN par besoin, et surtout les NON-détections :
 * négations, « j'ai déjà… », messages trop courts, sujets voisins.
 */
describe('Passerelle — détection des besoins', () => {
  describe.each<[AssistNeedId, string[]]>([
    [
      'document_review',
      [
        'Bonjour, je cherche quelqu’un pour relire mon CV avant de postuler',
        'Quelqu’un peut corriger ma lettre de motivation ? Je ne suis pas sûr du ton',
        'Je cherche à faire relire mon CV',
        'Comment rédiger une bonne lettre de motivation pour un master ?',
        'Can someone review my CV before I apply?',
        'I need feedback on my cover letter please',
      ],
    ],
    [
      'scholarship_match',
      [
        'Quelle bourse pour moi ? J’ai un bac D avec 14 de moyenne',
        'Je cherche une bourse pour faire un master en France',
        'Quelles bourses pour un étudiant nigérien en licence ?',
        'Which scholarships can I apply for with a bachelor degree?',
        'I am looking for a scholarship to study engineering abroad',
      ],
    ],
    [
      'etudes_en_france',
      [
        'Campus France, je suis perdu, je ne sais pas par où commencer',
        'Comment ça marche la procédure Campus France ?',
        'Besoin d’aide pour mon dossier Études en France',
        'How does Campus France work? I am lost',
      ],
    ],
    [
      'accompaniment',
      [
        'Je voudrais être accompagné pour monter mon dossier de candidature',
        'Comment parler à un conseiller pour préparer mon dossier ?',
        'I need help with my application, is there a counselor?',
      ],
    ],
    [
      'visa',
      [
        'Comment préparer ma demande de visa étudiant pour le Canada ?',
        'J’ai besoin d’aide pour le visa, quels documents ?',
        'How do I apply for a student visa for the USA?',
      ],
    ],
    [
      'school_choice',
      [
        'Je ne sais pas quelle école choisir après mon bac',
        'Quelle formation faire pour devenir data analyst ?',
        'Which university should I choose for computer science?',
      ],
    ],
  ])('%s', (id, samples) => {
    it.each(samples)('« %s »', (text) => {
      const d = detectNeed(text);
      expect(d).toMatchObject({ detected: true, needId: id, ruleVersion: ASSIST_BRIDGE_RULES_VERSION });
      if (d.detected) expect(d.ruleId.startsWith(`${id}.`)).toBe(true);
    });
  });

  it('accents, casse et apostrophes typographiques sont normalisés', () => {
    expect(need('QUI PEUT RELIRE MA LETTRE DE MOTIVATION ?')).toBe('document_review');
    expect(need('qui peut relire ma lettre de motivation ?')).toBe('document_review');
    expect(need('ÉTUDES EN FRANCE : je suis perdue')).toBe('etudes_en_france');
  });

  it('jetons de mention lus comme leur libellé', () => {
    expect(need('Je suis perdu avec @[Campus France](country:fr) , qui peut m’aider ?')).toBe('etudes_en_france');
  });

  describe('non-détections', () => {
    it.each([
      ['négation', 'Je ne cherche pas de bourse, juste des avis sur Paris', 'negation'],
      ['négation', 'Pas besoin de relire mon CV, merci, je voulais juste partager', 'negation'],
      ['négation EN', "I don't need a scholarship, just tips about housing", 'negation'],
      ['j’ai déjà', 'J’ai déjà fait relire mon CV par un ami, quelqu’un a un avis sur Lyon ?', 'already_done'],
      ['déjà relu', 'Mon CV a été déjà relu, comment préparer l’entretien ?', 'already_done'],
      ['already', 'I already reviewed my CV with a friend, any tips?', 'already_done'],
      ['trop court', 'cv ?', 'too_short'],
      ['trop court', 'visa svp', 'too_short'],
      ['sujet voisin', 'Retour d’expérience : mon premier mois à Lyon, le logement était cher', 'no_need'],
      ['récit sans demande', 'Mon CV et ma lettre de motivation sont partis hier, fin du stress.', 'no_need'],
    ])('%s : « %s »', (_label, text, reason) => {
      expect(skip(text)).toBe(reason);
    });

    it('un sujet sans signe de demande ne déclenche pas (visa, Campus France)', () => {
      expect(need('J’ai reçu mon visa hier après trois semaines d’attente.')).toBeNull();
      expect(need('Retour d’expérience sur Campus France : l’entretien s’est bien passé.')).toBeNull();
    });
  });

  it('priorité : le besoin le plus précis d’abord (catalogue ordonné)', () => {
    // Études en France passe avant l'accompagnement générique.
    expect(need('Comment monter mon dossier Campus France ? Je suis perdu')).toBe('etudes_en_france');
    // La relecture passe avant tout.
    expect(need('Qui peut relire ma lettre de motivation pour Campus France ?')).toBe('document_review');
  });

  it('catalogue : ids stables, routes de l’app, textes FR/EN tutoyés, sans promesse ni %', () => {
    const ids = ASSIST_NEEDS.map((n) => n.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids).toEqual(['document_review', 'scholarship_match', 'etudes_en_france', 'accompaniment', 'visa', 'school_choice']);
    const routes = Object.fromEntries(ASSIST_NEEDS.map((n) => [n.id, n.route]));
    expect(routes).toEqual({
      document_review: '/document-review',
      scholarship_match: '/scholarship-match',
      etudes_en_france: '/etudes-en-france',
      accompaniment: '/new-case',
      visa: '/services',
      school_choice: '/orientation',
    });
    for (const n of ASSIST_NEEDS) {
      for (const text of [n.title.fr, n.body.fr, n.title.en, n.body.en]) {
        expect(text).not.toMatch(/%|chances?|garanti|guarantee|odds|bot\b/i);
      }
      expect(n.body.fr).not.toMatch(/\b(vous|votre|vos)\b/i);
      expect(n.body.fr).toContain('WhatsApp');
      expect(n.body.en).toContain('WhatsApp');
      // Aucun numéro dans les textes : la ligne vient de la config de l'app.
      expect(`${n.body.fr} ${n.body.en}`).not.toMatch(/\+?\d[\d\s]{6,}/);
    }
    expect(needById('visa')?.feature).toBe('services');
    expect(needById('inconnu')).toBeNull();
    expect(catalogJson()).toMatchObject({ version: ASSIST_BRIDGE_RULES_VERSION, needs: expect.any(Array) });
  });
});
