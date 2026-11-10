import type { ExecutionContext } from '@nestjs/common';
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

/** Lectures (GET, HEAD) en production : par minute, par IP et par route. */
export const PRODUCTION_READ_LIMIT = 300;

/** Écritures (tout le reste) en production : par minute, par IP et par route. */
export const PRODUCTION_WRITE_LIMIT = 60;

/**
 * La limite de production, selon que la requête lit ou écrit.
 *
 * ## Pourquoi les lectures ont un plafond plus haut (audit avant la 59)
 *
 * Le compteur est par adresse IP. Or les opérateurs mobiles d'Afrique de
 * l'Ouest font sortir des milliers d'abonnés par la même adresse publique
 * (CGNAT) : pour le serveur, tous les élèves d'un opérateur sont UN client.
 * Chaque ouverture de l'app lit `/config/app` et plusieurs pages du catalogue.
 * À 60 par minute, quelques dizaines d'ouvertures dans la même minute — après
 * une vidéo ou une notification — suffisaient à faire refuser les suivantes en
 * 429 : l'app retombait sur ses replis et l'espace Études en France
 * disparaissait.
 *
 * Les lectures ne coûtent qu'une requête en base et ne changent rien : on
 * leur donne 300. Les écritures (créer un dossier, envoyer un message,
 * s'inscrire) restent à 60 : c'est elles qu'une boucle ou un abus peut rendre
 * coûteuses. Les lectures publiques qui appellent un service payant gardent
 * 60 par un `@Throttle` explicite ([COSTLY_READ_THROTTLE]).
 *
 * Une référence de fonction STABLE (et non une fermeture créée à chaque
 * appel) : `throttler-options.spec.ts` compare la configuration d'`AppModule`
 * à celle-ci par égalité.
 */
export function productionLimit(context: ExecutionContext): number {
  const method = (
    context.switchToHttp().getRequest<{ method?: string }>()?.method ?? ''
  ).toUpperCase();
  return method === 'GET' || method === 'HEAD'
    ? PRODUCTION_READ_LIMIT
    : PRODUCTION_WRITE_LIMIT;
}

/**
 * En production : 300 lectures et 60 écritures par minute, par IP et par
 * route. Ailleurs (dev, tests, CI) : 600 pour tout.
 */
export function buildThrottlerOptions(
  nodeEnv: string | undefined = process.env.NODE_ENV,
): ThrottlerOptions[] {
  return [
    {
      name: GLOBAL_THROTTLER,
      ttl: 60_000,
      limit: nodeEnv === 'production' ? productionLimit : 600,
    },
  ];
}

/**
 * Lectures PUBLIQUES qui appellent un service payant ou limité (prix des
 * vols) : elles gardent le plafond des écritures, 60 par minute et par IP, au
 * lieu des 300 des lectures ordinaires. Comme les autres plafonds de ce
 * fichier, il vaut dans tous les environnements.
 *
 * Le flux du coach IA n'en fait pas partie : il est authentifié et borné par
 * élève (cinq messages par semaine), ce qu'un plafond par IP ne ferait que
 * dégrader pour les élèves d'un même opérateur.
 */
export const COSTLY_READ_THROTTLE = {
  [GLOBAL_THROTTLER]: { limit: PRODUCTION_WRITE_LIMIT, ttl: 60_000 },
};

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

/**
 * Classement public d'une campagne de parrainage (`GET
 * /public/campaigns/:slug/leaderboard`, sans authentification) : 30 lectures
 * par minute et par IP. La page publique rafraîchit toutes les 60 s ; la
 * réponse est de toute façon mise en cache 30 s côté serveur.
 */
export const PUBLIC_LEADERBOARD_THROTTLE = {
  [GLOBAL_THROTTLER]: { limit: 30, ttl: 60_000 },
};

/**
 * Communauté : toutes les écritures élève (publier, répondre, modifier,
 * supprimer, « utile », signaler) — 20 par minute, par IP et par route. Les
 * quotas métier (publications par jour, réponses par heure) sont comptés par
 * membre dans `CommunityAccessService` ; ce plafond arrête une boucle client.
 */
export const COMMUNITY_WRITE_THROTTLE = {
  [GLOBAL_THROTTLER]: { limit: 20, ttl: 60_000 },
};
