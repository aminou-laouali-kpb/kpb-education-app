import {
  detectIntents,
  detectLang,
  detectVerificationQuestion,
  stripMentionTokens,
} from './community-verif-bot-detect';

const question = (title: string, body: string, type = 'question', authorKind = 'member') =>
  detectVerificationQuestion({ type, authorKind, title, body });

describe('Bot Vérif — détection', () => {
  it.each([
    ['La bourse Eiffel est-elle encore ouverte ?', 'Je voulais savoir si on peut encore candidater cette année.', ['status']],
    ['Date limite Eiffel ?', 'Quelle est la date limite pour envoyer le dossier ?', ['deadline']],
    ["C'est vrai que la bourse MEXT est gratuite ?", 'On m’a dit ça sur un groupe, merci.', ['truth', 'fees']],
    ['Cette école est-elle partenaire de KPB ?', 'Je vois son nom partout, elle existe vraiment ?', ['partner', 'exists']],
    ['Quels documents pour Chevening ?', 'Quelles pièces faut-il fournir ?', ['documents']],
    ['Arnaque ? Un agent me demande de payer', 'Il dit que la bourse est garantie si je paie.', ['scam']],
    ['Prochaine rentrée à l’UQAM ?', 'Pour la licence, la rentrée est en septembre ?', ['intake']],
  ])('FR : « %s » → question de vérification', (title, body, expected) => {
    const result = question(title, body);
    expect(result.candidate).toBe(true);
    expect(result.lang).toBe('fr');
    for (const intent of expected) expect(result.intents).toContain(intent);
  });

  it.each([
    ['Is the Fulbright scholarship still open?', 'I want to apply this year, what is the deadline?', ['status', 'deadline']],
    ['Is it true that Chevening is free?', 'Someone told me there are no fees.', ['truth', 'fees']],
    ['Required documents for DAAD', 'What documents do I need for the application?', ['documents']],
    ['Is this agent a scam?', 'He asks me to pay a fee to get the visa.', ['scam', 'visa', 'fees']],
  ])('EN : « %s » → question de vérification en anglais', (title, body, expected) => {
    const result = question(title, body);
    expect(result.candidate).toBe(true);
    expect(result.lang).toBe('en');
    for (const intent of expected) expect(result.intents).toContain(intent);
  });

  it('faux positif évité : un témoignage qui cite une date limite', () => {
    const result = question(
      'Mon parcours avec la bourse Eiffel',
      "J'ai envoyé mon dossier avant la date limite et j'ai été retenue, voici mon expérience.",
      'experience',
    );
    expect(result).toMatchObject({ candidate: false, skip: 'not_question' });
  });

  it('faux positif évité : un conseil', () => {
    const result = question('Conseil pour Campus France', 'Commence ton dossier tôt, les frais sont à payer en ligne.', 'advice');
    expect(result).toMatchObject({ candidate: false, skip: 'not_question' });
  });

  it('faux positif évité : une question sans motif de vérification', () => {
    const result = question('Qui a eu la bourse Eiffel en 2026 ?', 'Racontez-moi comment vous avez préparé l’entretien !');
    expect(result).toMatchObject({ candidate: false, skip: 'no_intent' });
  });

  it('jamais sur un contenu de l’équipe ni du bot lui-même', () => {
    expect(question('La bourse est-elle ouverte ?', 'Date limite ?', 'question', 'kpb_team').skip).toBe('team_post');
    expect(question('La bourse est-elle ouverte ?', 'Date limite ?', 'question', 'kpb_assistant').skip).toBe('team_post');
  });

  it('lit le libellé des mentions, pas le jeton', () => {
    const body = 'La @[Bourse Eiffel](scholarship:clx1) est-elle ouverte ?';
    expect(stripMentionTokens(body)).toBe('La Bourse Eiffel est-elle ouverte ?');
    expect(question('Statut ?', body).plain).toContain('Bourse Eiffel');
  });

  it('motifs en mots entiers : « opened » oui, « wave » / « agenda » non', () => {
    expect(detectIntents('a new wave of applications in my agenda')).toEqual([]);
    expect(detectIntents('Has the portal opened?')).toEqual(['status']);
  });

  it('langue : égalité → français', () => {
    expect(detectLang('Eiffel ?')).toBe('fr');
    expect(detectLang('What is the deadline for the scholarship?')).toBe('en');
  });
});
