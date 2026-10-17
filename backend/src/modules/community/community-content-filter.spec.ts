import {
  BUILTIN_ALLOWED_DOMAINS,
  containsPhoneNumber,
  hostMatchesRules,
  linkedHosts,
  scanContent,
  type FilterContext,
} from './community-content-filter';

const ctx: FilterContext = {
  isAllowedHost: (host) =>
    hostMatchesRules(host, [...BUILTIN_ALLOWED_DOMAINS, 'univ-lyon1.fr']),
  blockedTerms: [],
};

const scan = (text: string, c: FilterContext = ctx) => scanContent(text, c);

describe('filtre anti-arnaque — ce qui DOIT partir en revue', () => {
  it.each([
    ['+227 90 12 34 56', 'phone'],
    ['Appelle le 0612345678 pour le dossier', 'phone'],
    ['mon numéro : 77-123-45-67', 'phone'],
    ['(+237) 6 96 12 34 56', 'phone'],
    ['00221771234567', 'phone'],
    ['écris-moi : aicha.konate@gmail.com', 'email'],
    ['contact : aicha [at] gmail point com', 'email'],
    ['Rejoins le groupe https://chat.whatsapp.com/AbCdEf', 'whatsapp'],
    ['wa.me/22790123456 pour les infos', 'whatsapp'],
    ['Ajoute-moi sur WhatsApp, je t’explique', 'whatsapp'],
    ['DM me on Telegram for the full list', 'whatsapp'],
    ["Je prends 50 000 de frais d'agent et je t'obtiens la bourse", 'money_request'],
    ['Envoie-moi l’argent par Western Union', 'money_request'],
    ['Bourse garantie à 100 %, places limitées', 'money_request'],
    ['Visa garanti en 2 semaines', 'money_request'],
    ['Je peux t’obtenir une bourse Eiffel', 'money_request'],
    ['Paie-moi et je fais ton dossier', 'money_request'],
    ['Send me the money and I handle your application', 'money_request'],
    ['Guaranteed scholarship, agent fee only', 'money_request'],
    ['Payment in USDT or bitcoin', 'money_request'],
    ['Envoie par Orange Money au plus vite', 'mobile_money'],
    ['Dépôt sur MTN Mobile Money accepté', 'mobile_money'],
    ['Paie par Wave et c’est réglé', 'mobile_money'],
    ['On accepte Flooz et T-Money', 'mobile_money'],
    ['Inscris-toi ici : https://bourses-faciles.xyz/inscription', 'external_link'],
    ['Va sur www.scam-bourses.com', 'external_link'],
    ['Tout est sur bourse-gratuite.top', 'external_link'],
    ['Espèce de connard', 'profanity'],
    ['Ferme-la, fils de pute', 'profanity'],
    ['You are such an asshole', 'profanity'],
  ])('« %s » → %s', (text, flag) => {
    expect(scan(text)).toContain(flag);
  });

  it('cumule les drapeaux dans l’ordre du contrat', () => {
    expect(
      scan('Paie par Orange Money au +227 90 12 34 56, frais d’agent 20 000 FCFA, voir arnaque.xyz'),
    ).toEqual(['phone', 'money_request', 'mobile_money', 'external_link']);
  });

  it('applique les termes bloqués par l’équipe, en mot entier et sans accents', () => {
    const custom: FilterContext = { ...ctx, blockedTerms: ['passeur'] };
    expect(scan('Un PASSEUR m’a contacté', custom)).toContain('blocked_term');
    expect(scan('Les passeurs de témoin', custom)).not.toContain('blocked_term');
  });
});

describe('filtre anti-arnaque — faux positifs raisonnables (ne doivent PAS partir en revue)', () => {
  it.each([
    'Les frais de dossier Campus France sont de 50 000 FCFA.',
    'J’ai payé les frais de visa à l’ambassade, 99 € en tout.',
    'La bourse Eiffel donne 1 181 € par mois.',
    'Il faut justifier 15 000 000 sur le compte bloqué.',
    'Il faut justifier 7 380 000 FCFA pour le visa.',
    'Calendrier 2026-2027 : la campagne ouvre en octobre.',
    'Date limite le 15/01/2027, réponse le 31/03/2027.',
    'Le site officiel : https://www.campusfrance.org/fr/procedure',
    'Toutes les infos sur https://france-visas.gouv.fr et service-public.fr',
    'Voir la page https://www.univ-lyon1.fr/formation',
    'Le groupe WhatsApp officiel de Campus France répond vite.',
    'A new wave of applications opens in March.',
    'I watched a documentary about Scunthorpe and Dickens.',
    'Ma moyenne est de 14,5/20 et j’ai le bac D.',
    'J’ai envoyé mon dossier, et toi ?',
    'Code postal 75005, Paris.',
    'Merci pour la réponse #CampusFrance #CV',
  ])('« %s » → aucun drapeau', (text) => {
    expect(scan(text)).toEqual([]);
  });
});

describe('détails du filtre', () => {
  it('un numéro international est un numéro même groupé par trois', () => {
    expect(containsPhoneNumber('+221 771 234 567')).toBe(true);
    expect(containsPhoneNumber('771 234 567')).toBe(false);
  });

  it('repère les hôtes des URL, des « www. » et des domaines nus, pas ceux des e-mails', () => {
    expect(linkedHosts('voir https://WWW.Example.org/x, www.foo.net et bar.xyz ; a@mail.com').sort()).toEqual([
      'bar.xyz',
      'example.org',
      'foo.net',
    ]);
  });

  it('règles de liste blanche : nue = elle-même, `*.x` = x et sous-domaines', () => {
    expect(hostMatchesRules('www.campusfrance.org', ['*.campusfrance.org'])).toBe(true);
    expect(hostMatchesRules('senegal.campusfrance.org', ['*.campusfrance.org'])).toBe(true);
    expect(hostMatchesRules('campusfrance.org.evil.xyz', ['*.campusfrance.org'])).toBe(false);
    expect(hostMatchesRules('sub.parcoursup.fr', ['parcoursup.fr'])).toBe(false);
    expect(hostMatchesRules('parcoursup.fr', ['parcoursup.fr'])).toBe(true);
  });
});
