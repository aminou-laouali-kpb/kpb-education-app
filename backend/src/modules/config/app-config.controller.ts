import { Controller, Get } from '@nestjs/common';

import { EEF_CATALOG_ATTRIBUTION } from '../etudes-en-france/catalog/eef-catalog-attribution';

function enabled(value: string | undefined, defaultValue = false): boolean {
  if (value === undefined) return defaultValue;
  return value.trim().toLowerCase() === 'true';
}

/**
 * Interrupteur OUVERT par défaut : seule la valeur `false` (casse et espaces
 * tolérés) le ferme. Sert aux fonctions déjà livrées dans la build, qu'on veut
 * pouvoir couper à distance sans qu'une variable absente, vide ou mal tapée ne
 * les éteigne par accident.
 */
function notDisabled(value: string | undefined): boolean {
  return value?.trim().toLowerCase() !== 'false';
}

function rolloutPercent(value: string | undefined): number {
  const parsed = Number(value ?? '0');
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(100, Math.round(parsed)));
}

/**
 * A comma-separated env list, trimmed, de-duplicated, blanks dropped.
 *
 * Deliberately NOT upper-cased, unlike the Success Lab country codes just
 * below: this list is matched against a mobile profile's `countryOfResidence`,
 * which holds a French display name ("Niger", "Côte d'Ivoire") and not an ISO
 * code. Normalisation is the client's job — it is the side that knows what it
 * is comparing against — so the wire keeps whatever operators typed, and both
 * `NE` and `Niger` are accepted spellings.
 */
function nameList(value: string | undefined): string[] {
  const seen = new Set<string>();
  for (const entry of (value ?? '').split(',')) {
    const trimmed = entry.trim();
    if (trimmed) seen.add(trimmed);
  }
  return [...seen];
}

/**
 * Le JOUR de campagne écrit par l'exploitation, servi tel quel — jamais un
 * instant.
 *
 * ## Le défaut que cette fonction remplace
 *
 * Elle s'appelait `isoInstant` et faisait `new Date(raw).toISOString()`. Sur
 * une valeur portant un décalage explicite, cette seule ligne détruisait le
 * jour :
 *
 * ```
 * KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01T00:00:00+02:00   (l'heure de Paris)
 *   → servi « 2026-09-30T22:00:00.000Z »
 *   → tout client lit le 30 septembre, quel que soit son fuseau
 * ```
 *
 * Écrire l'heure de Paris est le réflexe naturel pour une procédure française,
 * et le client ne pouvait rien y faire : l'information était déjà perdue sur le
 * fil. Un correctif côté mobile — extraire `AAAA-MM-JJ` du texte reçu — ne
 * réparait donc que la moitié du problème, celle du fuseau de l'appareil.
 *
 * ## Ce qu'elle fait
 *
 * « La campagne ouvre le 1er octobre » est une date d'HORLOGE MURALE, pas un
 * instant : elle ne désigne pas le même moment à Dakar et à Montréal, et c'est
 * voulu. On lit donc les composantes du TEXTE, avant toute conversion, et on
 * sert un jour nu `AAAA-MM-JJ`. Aucun fuseau n'entre dans l'équation, donc
 * aucun décalage n'en sort.
 *
 * L'heure éventuellement écrite par l'exploitation est ignorée, pas honorée :
 * une échéance administrative se compte en jours. Voir `EefCalendar.phase`
 * côté mobile, qui compare des jours avec des bornes inclusives.
 *
 * Null plutôt qu'une approximation, sur une valeur illisible : ce jour pilote
 * la fenêtre qu'imprime la vitrine « Études en France », et une faute de frappe
 * dans une variable de déploiement doit faire taire l'app — pas afficher
 * « Invalid Date », pas retomber sur aujourd'hui, ce qui annoncerait une
 * campagne s'ouvrant à l'instant où l'écran s'ouvre.
 */
function campaignDay(value: string | undefined): string | null {
  const raw = value?.trim();
  if (!raw) return null;

  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (!match) return null;

  const [year, month, day] = match.slice(1).map(Number);

  // `new Date(Date.UTC(2026, 12, 1))` vaut janvier 2027, et un 30 février
  // devient le 2 mars : normaliser une saisie fautive fabriquerait une date que
  // personne n'a écrite. On la refuse, et l'app n'annonce rien.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() !== month - 1 ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }

  return match[0];
}

/**
 * Une URL que l'app va OUVRIR : https uniquement, sans identifiants.
 *
 * Ces liens sont servis par une variable d'exploitation, donc écrits à la main
 * par quelqu'un pressé. `javascript:` ou `http:` ne doivent jamais atteindre un
 * bouton « ouvrir ». **Ce que ce filtre NE garantit PAS :** qu'un hôte `https`
 * syntaxiquement valide soit le bon — une faute de frappe dans le nom de domaine
 * passe. C'est la relecture de la variable (et le `curl /config/app` du runbook)
 * qui l'attrape, pas ce code.
 */
function httpsUrl(value: string | undefined): string | null {
  const raw = value?.trim();
  if (!raw) return null;
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:' || url.username || url.password) return null;
    return url.toString();
  } catch {
    return null;
  }
}

/** « Côte d'Ivoire » et « cote d’ivoire » doivent désigner le même pays. */
function countryKey(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’]/g, "'")
    .trim()
    .toLowerCase();
}

/**
 * La plateforme officielle, quand l'exploitation n'en désigne pas une autre.
 * Un repli publié et vérifié (réponse 200 au 01/10/2026) plutôt qu'un lien
 * absent : la mention de non-affiliation de l'app renvoie « aux plateformes de
 * l'État », et sans lien l'étudiant ne sait pas où elles sont.
 */
const OFFICIAL_PLATFORM_URL = 'https://www.campusfrance.org/fr';

/**
 * Les pages officielles qui justifient une suspension, par pays. Ce sont les
 * sources citées par `docs/eef-campaign-calendar-2027-2028-research.md` : une
 * suspension annoncée sans sa source est une affirmation que l'étudiant ne peut
 * pas vérifier. `KPB_EEF_SUSPENDED_SOURCES` complète ou remplace ces entrées.
 */
const KNOWN_SUSPENSION_SOURCES: ReadonlyMap<string, string> = new Map([
  ['niger', 'https://ne.diplomatie.gouv.fr/informations-visas'],
  // Le code que l'exploitation écrit à côté du nom (`Niger,NE`) : sans cet alias,
  // un profil saisi « NE » verrait la suspension SANS son lien. Une `Map` et non
  // un objet : `KNOWN_SUSPENSION_SOURCES['__proto__']` lisait la chaîne de
  // prototypes.
  ['ne', 'https://ne.diplomatie.gouv.fr/informations-visas'],
]);

/**
 * `Pays|https://…;Autre pays|https://…`.
 *
 * `;` sépare les entrées et `|` le pays de son lien, parce que ni l'un ni
 * l'autre n'apparaît dans une URL de page ordinaire — une virgule le ferait
 * (`?a=1,2`), et le `=` d'un format clé=valeur aussi.
 *
 * **Limite :** une URL qui contient elle-même un `;` (paramètre de chemin du type
 * `;jsessionid=…`) est COUPÉE à ce point et servie tronquée, sans erreur. Les
 * pages de sources officielles n'en portent pas ; si l'une en portait un, il
 * faudrait changer de format (JSON) et non l'échapper.
 */
function suspensionSourceOverrides(
  value: string | undefined,
): Map<string, string> {
  const out = new Map<string, string>();
  for (const entry of (value ?? '').split(';')) {
    const separator = entry.indexOf('|');
    if (separator < 0) continue;
    const country = countryKey(entry.slice(0, separator));
    const url = httpsUrl(entry.slice(separator + 1));
    if (country && url) out.set(country, url);
  }
  return out;
}

/** Un lien par pays suspendu, et seulement pour les pays suspendus. */
function suspendedSources(
  suspended: readonly string[],
  overrides: string | undefined,
): { country: string; url: string }[] {
  const custom = suspensionSourceOverrides(overrides);
  const out: { country: string; url: string }[] = [];
  for (const country of suspended) {
    const key = countryKey(country);
    const url = custom.get(key) ?? KNOWN_SUSPENSION_SOURCES.get(key);
    if (url) out.push({ country, url });
  }
  return out;
}

/**
 * La version RECOMMANDÉE : celle à partir de laquelle l'app cesse d'inviter à
 * mettre à jour. Une version nue `x.y.z`, ou rien.
 *
 * Elle diffère de `minVersion` par sa conséquence : en dessous de `minVersion`
 * l'app est bloquée derrière un écran qu'on ne ferme pas ; en dessous de
 * celle-ci, un bandeau qu'on ferme. Une valeur illisible vaut « pas de
 * bandeau » — jamais « bandeau pour tous », ce qui enverrait chaque utilisateur
 * vers le store pour rien.
 */
function recommendedVersion(value: string | undefined): string | null {
  const raw = value?.trim();
  return raw && /^\d+\.\d+\.\d+$/.test(raw) ? raw : null;
}

/**
 * The listings actually published. These serve whenever the env vars are unset,
 * which makes them a fallback and not merely a default: the force-update screen
 * cannot be dismissed and its only button is disabled without a usable URL, so a
 * wrong fallback locks every user out of the app on the day
 * KPB_MIN_APP_VERSION is raised.
 */
const PUBLISHED_ANDROID_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.karatou.android';
const PUBLISHED_IOS_STORE_URL = 'https://apps.apple.com/app/id1128659292';

/**
 * Public, unauthenticated app configuration. The mobile client reads this at
 * boot to decide whether the installed build is still supported (force-update
 * gate). `minVersion` defaults to 0.0.0 — i.e. no build is ever blocked until
 * operators explicitly raise KPB_MIN_APP_VERSION.
 */
@Controller('config')
export class AppConfigController {
  @Get('app')
  getAppConfig() {
    const competitionReadiness = enabled(
      process.env.KPB_COMPETITION_READINESS_ENABLED,
    );
    const successLab =
      competitionReadiness && enabled(process.env.KPB_SUCCESS_LAB_ENABLED);
    const aiDiagnostic =
      successLab &&
      enabled(process.env.KPB_AI_DIAGNOSTIC_ENABLED) &&
      !enabled(process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH, true);

    // ── Espace « Études en France » ────────────────────────────────────────
    //
    // Deux surfaces, UNE variable à basculer le jour J. Le teaser dit « en
    // préparation » ; l'espace réel dit le contraire par sa seule existence.
    // Les laisser s'allumer indépendamment garantissait qu'un jour de
    // lancement les afficherait tous les deux — « bientôt » à côté d'un espace
    // vivant. `eef` retire donc le teaser de lui-même : mettre KPB_EEF_ENABLED
    // à true suffit, et rien à désactiver dans un second temps (l'oubli
    // classique, celui qu'on ne voit pas depuis un tableau de bord).
    const eef = enabled(process.env.KPB_EEF_ENABLED);
    const eefTeaser = !eef && enabled(process.env.KPB_EEF_TEASER_ENABLED);

    // ── `eefSpace` : l'ouverture de l'espace RÉEL, pour la seule build 54 ──
    //
    // `eef` ne peut plus être ce commutateur. Les builds 49 à 53 le lisent
    // aussi, et pour elles `eef: true` veut dire « afficher l'espace » ET
    // « retirer la vitrine » : un espace qui n'a que trois badges « En
    // préparation ». Le poser pour ouvrir l'espace à la 54 dégraderait donc
    // tout le parc installé, sans passer par un store et sans retour arrière
    // par les utilisateurs.
    //
    // `eefSpace` est une clé NOUVELLE, ignorée des anciennes builds (elles
    // n'écoutent que les clés qu'elles connaissent — « tolerates-old »). Elle
    // ne touche PAS à `eefTeaser` : tant que KPB_EEF_ENABLED reste éteint, une
    // build 53 garde sa vitrine pendant que la 54 ouvre l'espace.
    //
    // `eef` (l'ancien commutateur) l'allume aussi : quelqu'un qui le poserait
    // par habitude ouvre l'espace partout, et la 54 ne doit alors pas rester
    // à la porte de ce que les autres builds montrent déjà.
    const eefSpace = eef || enabled(process.env.KPB_EEF_SPACE_ENABLED);

    // ── Build 56 : deux interrupteurs de plus, FERMÉS et INDÉPENDANTS ──────
    //
    // `eefHelpBubble` : la bulle « Une question ? » (contact WhatsApp trié par
    // sujet) dans le hub et le catalogue. `eefPrivateSchools` : la ligne et la
    // feuille d'information sur les écoles privées. Chacun est lu par la seule
    // build 56 et les suivantes ; une build plus ancienne ignore ces clés, et
    // une 56 devant un backend plus ancien (clé absente) les lit comme fausses.
    //
    // Ils ne dérivent d'AUCUN autre drapeau — ni `eef` (l'ancien commutateur,
    // qui ouvre `eefSpace` partout), ni `eefSpace`. Ouvrir l'espace ne doit
    // jamais, par ricochet, allumer un canal de contact ou une mention
    // d'établissements privés : chaque ouverture est une décision à part, avec
    // sa propre action d'exploitation (`eef-bubble-on`, `eef-private-schools-on`)
    // et son propre retour arrière. L'app, de son côté, exige `eefSpace` EN PLUS
    // pour montrer quoi que ce soit : ces clés seules n'ouvrent rien.
    const eefHelpBubble = enabled(process.env.KPB_EEF_HELP_BUBBLE_ENABLED);
    const eefPrivateSchools = enabled(
      process.env.KPB_EEF_PRIVATE_SCHOOLS_ENABLED,
    );

    const suspendedCountries = nameList(
      process.env.KPB_EEF_SUSPENDED_COUNTRIES,
    );

    return {
      minVersion: process.env.KPB_MIN_APP_VERSION?.trim() || '0.0.0',
      // Le bandeau doux, par opposition à l'écran bloquant ci-dessus : voir
      // [recommendedVersion]. C'est ce qui permet de faire passer les builds
      // 54 → 55 → forum sans relever `minVersion`, donc sans bloquer personne.
      recommendedVersion: recommendedVersion(
        process.env.KPB_RECOMMENDED_APP_VERSION,
      ),
      // Validés comme toute URL servie à un bouton « ouvrir » : une valeur
      // d'exploitation mal écrite retombe sur la fiche publiée, au lieu de
      // verrouiller l'écran de mise à jour sur un lien mort.
      androidStoreUrl:
        httpsUrl(process.env.KPB_ANDROID_STORE_URL) ||
        PUBLISHED_ANDROID_STORE_URL,
      iosStoreUrl:
        httpsUrl(process.env.KPB_IOS_STORE_URL) || PUBLISHED_IOS_STORE_URL,
      features: {
        competitionReadiness,
        successLab,
        aiDiagnostic,
        outcomeEvidence:
          competitionReadiness &&
          successLab &&
          enabled(process.env.KPB_OUTCOME_EVIDENCE_ENABLED),
        publicImpactStats:
          competitionReadiness &&
          enabled(process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED),
        eefTeaser,
        eef,
        eefSpace,
        eefHelpBubble,
        eefPrivateSchools,
        // « Suivre », Mes suivis et les notifications (chantier G). OUVERTS par
        // défaut, comme dans l'app : ces clés existent pour COUPER une
        // fonction sur les téléphones déjà installés, sans soumission store.
        followPushPrimer: notDisabled(process.env.KPB_FOLLOW_PUSH_PRIMER_ENABLED),
        followOpeningAlert: notDisabled(
          process.env.KPB_FOLLOW_OPENING_ALERT_ENABLED,
        ),
        openingAlertToggle: notDisabled(
          process.env.KPB_OPENING_ALERT_TOGGLE_ENABLED,
        ),
        followedScholarships: notDisabled(
          process.env.KPB_FOLLOWED_SCHOLARSHIPS_ENABLED,
        ),
        notificationsUnreadCount: notDisabled(
          process.env.KPB_NOTIFICATIONS_UNREAD_COUNT_ENABLED,
        ),
        followedScholarshipOptOut: notDisabled(
          process.env.KPB_FOLLOWED_SCHOLARSHIP_OPT_OUT_ENABLED,
        ),
        homeFollowedEntry: notDisabled(process.env.KPB_HOME_FOLLOWED_ENTRY_ENABLED),
        // « Mes 10 bourses » (chantier D) : le test d'éligibilité et ses
        // résultats. FERMÉ par défaut — livré éteint, ouvert à la bascule. La
        // même variable coupe les routes `/scholarships/match/*` (404
        // `{ disabled: true }`) : la carte et l'API s'allument ensemble.
        scholarshipMatch: enabled(process.env.KPB_SCHOLARSHIP_MATCH_ENABLED),
        // Onboarding « la valeur d'abord » (chantier I3) : aucun champ
        // pré-rempli sans choix de l'élève, « Passer » dès la page 1, erreurs
        // dans le champ. FERMÉ par défaut : l'ancien parcours reste le repli,
        // et seule `true` ouvre le nouveau.
        onboardingV2: enabled(process.env.KPB_ONBOARDING_V2_ENABLED),
      },
      // La fenêtre de campagne est SERVIE, jamais compilée. Une build vit ~90
      // jours ; une date d'ouverture écrite dans le binaire devient fausse
      // pendant sa vie utile et n'est plus corrigible sans passer par les
      // stores — c'est la leçon qu'IntakeCalendar porte déjà côté mobile.
      // Null quand ce n'est pas configuré : le client n'annonce alors aucune
      // date, plutôt qu'une date inventée.
      eefCampaign: {
        // Des JOURS nus `AAAA-MM-JJ`, pas des instants — voir [campaignDay].
        // Un instant sur le fil se reprojette dans le fuseau du lecteur, et
        // « le 1er octobre » devient « le 30 septembre » pour une moitié du
        // public.
        opensAt: campaignDay(process.env.KPB_EEF_CAMPAIGN_OPENS_AT),
        closesAt: campaignDay(process.env.KPB_EEF_CAMPAIGN_CLOSES_AT),
        // Pays où la procédure est SUSPENDUE — le service ne traite pas les
        // dossiers, quelle que soit la date d'ouverture de la plateforme.
        //
        // Au 21/08/2026 : le Niger, la page officielle de l'ambassade indiquant
        // que la dénonciation de la convention du centre qui hébergeait Campus
        // France rend impossible le traitement des dossiers d'étudiants
        // nigériens (voir docs/eef-campaign-calendar-2027-2028-research.md).
        // Annoncer une ouverture à ces étudiants les enverrait vers une
        // démarche que l'État français déclare inopérante.
        //
        // Servi et non compilé pour la même raison que tout le reste ici : une
        // réouverture ne doit pas attendre une soumission App Store.
        suspendedCountries,
        // Les sources OFFICIELLES de ce que l'app affirme. Servies, pas
        // compilées : elles évitent de figer un hôte dans le binaire (et de
        // grossir la liste des hôtes que le test de parité de confidentialité
        // surveille).
        platformUrl:
          httpsUrl(process.env.KPB_EEF_PLATFORM_URL) ?? OFFICIAL_PLATFORM_URL,
        suspendedSources: suspendedSources(
          suspendedCountries,
          process.env.KPB_EEF_SUSPENDED_SOURCES,
        ),
      },
      // La mention de paternité du catalogue (Licence Ouverte 2.0). Une
      // constante vérifiée contre le manifeste par son spec — voir
      // `eef-catalog-attribution.ts`.
      eefCatalog: EEF_CATALOG_ATTRIBUTION,
      successLabRollout: {
        countryCodes: (process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES ?? '')
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .filter(Boolean),
        percent: rolloutPercent(process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT),
      },
    };
  }
}
