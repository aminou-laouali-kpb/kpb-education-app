import type { ThrottlerOptions } from '@nestjs/throttler';

/**
 * Le nom du SEUL limiteur déclaré dans `ThrottlerModule.forRoot`.
 *
 * ## Pourquoi un seul, et pourquoi son nom compte
 *
 * Avec `@nestjs/throttler` 6.x, TOUT limiteur nommé déclaré dans `forRoot`
 * s'applique à TOUTES les routes : `@Throttle` ne l'active pas, il en change
 * seulement la valeur. Un second limiteur `auth` (10 req/min) déclaré à côté de
 * `global` ne protégeait donc pas la connexion admin — il plafonnait à 10 par
 * minute et par IP chaque route de l'API, `GET /config/app` et la recherche
 * publique `GET /etudes-en-france/search` comprises (429 à la 11e requête, mesuré
 * le 02/10/2026). Le compteur est par route et par IP : la clé est
 * `sha256(Classe-handler-limiteur-IP)`.
 *
 * Le surcoût d'une route sensible se règle donc EN SURCHARGEANT ce limiteur
 * (voir `ADMIN_LOGIN_THROTTLE`), pas en en déclarant un second.
 *
 * `@Throttle` retrouve le limiteur par son NOM. Il s'appelle `global` ici : un
 * `@Throttle({ default: … })` serait ignoré sans erreur et la route retomberait
 * à la limite globale. `throttler-options.spec.ts` le garde.
 */
export const GLOBAL_THROTTLER = 'global';

/** 60 req/min/IP/route en production, 600 ailleurs (dev, tests, CI). */
export function buildThrottlerOptions(
  nodeEnv: string | undefined = process.env.NODE_ENV,
): ThrottlerOptions[] {
  return [
    {
      name: GLOBAL_THROTTLER,
      ttl: 60_000,
      limit: nodeEnv === 'production' ? 60 : 600,
    },
  ];
}

/**
 * Connexion admin : 10 tentatives par minute et par IP, quel que soit
 * l'environnement. C'est la protection contre le bourrage d'identifiants sur le
 * seul POST public qui vérifie un mot de passe.
 */
export const ADMIN_LOGIN_THROTTLE = {
  [GLOBAL_THROTTLER]: { limit: 10, ttl: 60_000 },
};

/**
 * « Mes 10 bourses » : `POST /scholarships/match/runs` écrit le profil et un run
 * dans une transaction qui évalue jusqu'à 500 fiches. 10 calculs par minute et
 * par IP suffisent largement à un élève (le test, un « Refaire », une mise à
 * jour) ; au-delà, c'est une boucle côté client.
 */
export const SCHOLARSHIP_MATCH_RUN_THROTTLE = {
  [GLOBAL_THROTTLER]: { limit: 10, ttl: 60_000 },
};
