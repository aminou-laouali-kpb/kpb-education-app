// ─────────────────────────────────────────────────────────────────────────────
// Bot « Passerelle » (C3 bis) — CATALOGUE VERSIONNÉ des besoins et détection.
//
// Fonctions PURES (aucune base, aucune horloge, aucun LLM) : un texte écrit par
// l'élève entre, un besoin (ou une raison de ne rien faire) sort. Le texte est
// normalisé comme partout ailleurs (`normalizeSearchText` : minuscules, sans
// accents, ponctuation = espace), les motifs se lisent en mots entiers.
//
// Chaque besoin renvoie vers une fonction qui EXISTE dans l'app, vérifiée dans
// le code (voir `feature` et `route` de chaque entrée, et le §15 du contrat).
// Aucun besoin n'est ajouté sans sa fonction : un besoin sans porte d'entrée
// dans l'app enverrait l'élève nulle part.
//
// Changer un motif, un texte ou un besoin = monter `ASSIST_BRIDGE_RULES_VERSION`
// (elle est écrite sur chaque événement : la console sait quelle version a
// décidé).
// ─────────────────────────────────────────────────────────────────────────────

import { normalizeSearchText } from '../etudes-en-france/catalog/eef-search-text';

export const ASSIST_BRIDGE_RULES_VERSION = 'ab-1';

export type AssistNeedId =
  | 'document_review'
  | 'scholarship_match'
  | 'etudes_en_france'
  | 'accompaniment'
  | 'visa'
  | 'school_choice';

/**
 * La fonction cible, par CLÉ (l'app sait l'ouvrir) et par ROUTE (le repli des
 * builds qui ne connaissent pas la passerelle : elles suivent `route`).
 */
export type AssistFeatureKey =
  | 'document_review'
  | 'scholarship_match'
  | 'etudes_en_france'
  | 'new_case'
  | 'services'
  | 'orientation';

export interface AssistRule {
  /** Identifiant stable de la règle (`<besoin>.<motif>`), écrit sur l'événement. */
  id: string;
  pattern: RegExp;
  /**
   * La règle exprime-t-elle déjà une demande (« quelle bourse », « trouver une
   * école ») ? Sinon il faut, en plus, un signe de demande (`ASK`) ou un « ? ».
   */
  selfAsking: boolean;
}

export interface AssistNeed {
  id: AssistNeedId;
  feature: AssistFeatureKey;
  /** Route nommée de l'app (`lib/app/core/config/app_routes.dart`). */
  route: string;
  /** Libellé court pour la console (FR/EN). */
  label: { fr: string; en: string };
  /** Où la fonction vit, en clair (console, contrat). */
  featureLabel: { fr: string; en: string };
  rules: readonly AssistRule[];
  /** « J'ai déjà fait relire… » : ce besoin précis est déjà couvert. */
  alreadyDone?: RegExp;
  title: { fr: string; en: string };
  body: { fr: string; en: string };
}

// ── Motifs communs ───────────────────────────────────────────────────────────

/** Un signe de DEMANDE : envie, recherche, difficulté, question. */
const ASK =
  /\b(je cherche|je recherche|cherche|recherche|je veux|je voudrais|voudrais|j aimerais|aimerais|besoin|aide|aidez|aider|aidez moi|comment|qui peut|quelqu un|svp|s il vous plait|s il te plait|stp|perdu|perdue|perdus|galere|conseil|conseils|astuce|astuces|ou trouver|quel|quelle|quels|quelles|help|how|need|needs|want|looking for|lost|advice|tips|where can|which|any idea|anyone|someone|please|would like)\b/;

/**
 * Négations SIMPLES : l'élève dit qu'il n'a pas ce besoin. Volontairement
 * large — dans le doute, on se tait (une notification de trop coûte plus
 * qu'une de moins).
 */
const NEGATION =
  /\b(je ne cherche pas|je cherche pas|je ne veux pas|je veux pas|pas besoin|plus besoin|aucun besoin|n ai pas besoin|n ai plus besoin|ne recherche pas|don t need|do not need|dont need|no need|not looking for|i m not looking|not interested|pas interesse|pas interessee)\b/;

/** « J'ai déjà… » : la démarche est faite (ou en cours ailleurs). */
const ALREADY =
  /\b(j ai deja|deja fait|deja eu|deja trouve|deja obtenu|deja recu|deja relu|deja corrige|deja depose|deja inscrit|deja inscrite|i already|i ve already|already did|already done|already have|already got|already found|already received|already reviewed|already applied)\b/;

/** En dessous : trop court pour décider (« cv ? », « visa »). */
export const ASSIST_MIN_WORDS = 4;

// ── Catalogue (version `ab-1`) ───────────────────────────────────────────────
//
// Ordre = priorité : un message qui porte deux besoins reçoit le PREMIER
// (le plus précis d'abord : Études en France avant l'accompagnement générique).

const WA = {
  fr: "Besoin d'aide en plus ? Écris-nous sur WhatsApp.",
  en: 'Need more help? Message us on WhatsApp.',
};

export const ASSIST_NEEDS: readonly AssistNeed[] = [
  {
    id: 'document_review',
    feature: 'document_review',
    // Pas d'écran à route nommée : la relecture s'ouvre depuis le tiroir des
    // outils (`kpb_tools_drawer.dart`, `DocumentReviewScreen`, `POST
    // /document-review`). La build qui connaît la passerelle l'ouvre par sa
    // CLÉ ; une build plus ancienne ne reconnaît pas cette route et retombe
    // sur l'accueil (jamais d'écran cassé).
    route: '/document-review',
    label: { fr: 'Relecture CV / lettre de motivation', en: 'CV / cover letter review' },
    featureLabel: { fr: 'Outils → Relecture de document (IA)', en: 'Tools → Document review (AI)' },
    rules: [
      {
        id: 'document_review.review',
        pattern:
          /\b(relire|relise|relisent|relis|relu|relecture|corriger|corrige|correction|ameliorer|ameliore|verifier|verifie|avis sur|review|reviewed|proofread|proofreading|feedback|improve|check)\b.{0,60}\b(cv|curriculum|curriculum vitae|lettre de motivation|lettres de motivation|lettre motivation|cover letter|motivation letter|personal statement|statement of purpose)\b|\b(cv|curriculum|curriculum vitae|lettre de motivation|lettres de motivation|lettre motivation|cover letter|motivation letter|personal statement|statement of purpose)\b.{0,60}\b(relire|relise|relu|relecture|corriger|corrige|correction|ameliorer|verifier|avis|review|proofread|feedback|improve|check)\b/,
        selfAsking: false,
      },
      {
        id: 'document_review.write',
        pattern:
          /\b(rediger|redige|ecrire|faire|reussir|construire|write|writing|make)\b.{0,30}\b(mon |ma |un |une |le |la |my |a )?(cv|curriculum vitae|lettre de motivation|cover letter|motivation letter|personal statement)\b/,
        selfAsking: false,
      },
    ],
    alreadyDone:
      /\b(deja (fait )?relu|deja fait relire|deja corrige|deja ete relu|already reviewed|already proofread|already been reviewed)\b/,
    title: { fr: 'Ton CV ou ta lettre, relus dans l’app', en: 'Your CV or letter, reviewed in the app' },
    body: {
      fr: `Tu peux déjà faire relire ton CV ou ta lettre de motivation dans l’app : colle ton texte et reçois des conseils pour l’améliorer. ${WA.fr}`,
      en: `You can already get your CV or cover letter reviewed in the app: paste your text and get tips to improve it. ${WA.en}`,
    },
  },
  {
    id: 'scholarship_match',
    feature: 'scholarship_match',
    route: '/scholarship-match',
    label: { fr: 'Trouver une bourse', en: 'Find a scholarship' },
    featureLabel: { fr: 'Test « Mes 10 bourses »', en: '“My 10 scholarships” test' },
    rules: [
      {
        id: 'scholarship_match.which',
        pattern:
          /\b(quelles? bourses?|quels? financements?|a quelles? bourses?|trouver (une |des |la |ma )?bourses?|cherche (une |des )?bourses?|recherche (une |des )?bourses?|bourses? pour moi|bourses? (qui me correspond|qui me correspondent|adaptee|adaptees|faite pour moi)|eligible a (une |des |quelle )?bourses?|which scholarships?|what scholarships?|find (a |any )?scholarships?|looking for (a |any )?scholarships?|scholarships? for me|scholarships? i can apply|eligible for (a |any |which )?scholarships?)\b/,
        selfAsking: true,
      },
    ],
    alreadyDone: /\b(deja fait le test|already (did|took|done) the test)\b/,
    title: { fr: 'Trouve tes bourses dans l’app', en: 'Find your scholarships in the app' },
    body: {
      fr: `Le test « Mes 10 bourses » te montre les bourses qui correspondent à ton profil, d’après leurs conditions officielles. ${WA.fr}`,
      en: `The “My 10 scholarships” test shows the scholarships that match your profile, based on their official conditions. ${WA.en}`,
    },
  },
  {
    id: 'etudes_en_france',
    feature: 'etudes_en_france',
    route: '/etudes-en-france',
    label: { fr: 'Études en France / Campus France', en: 'Studying in France / Campus France' },
    featureLabel: { fr: 'Espace « Études en France »', en: '“Studying in France” space' },
    rules: [
      {
        id: 'etudes_en_france.procedure',
        pattern:
          /\b(campus france|etudes en france|etude en france|procedure eef|plateforme eef|dossier eef|eef|study in france|studying in france|studies in france)\b/,
        selfAsking: false,
      },
    ],
    title: { fr: 'Études en France : l’app t’aide', en: 'Studying in France: the app helps' },
    body: {
      fr: `L’espace « Études en France » de l’app t’aide à préparer ta procédure, avec le catalogue des formations. ${WA.fr}`,
      en: `The app’s “Studying in France” space helps you prepare your procedure, with the catalogue of programmes. ${WA.en}`,
    },
  },
  {
    id: 'accompaniment',
    feature: 'new_case',
    route: '/new-case',
    label: { fr: 'Être accompagné (dossier)', en: 'Get support (application file)' },
    featureLabel: { fr: 'Ouvrir un dossier avec un conseiller KPB', en: 'Open a file with a KPB advisor' },
    rules: [
      {
        id: 'accompaniment.support',
        pattern:
          /\b(accompagne|accompagnee|accompagnement|accompagner|un conseiller|une conseillere|parler a un conseiller|monter mon dossier|monter un dossier|monter mon dossier de candidature|preparer mon dossier|mon dossier de candidature|dossier de candidature|aide pour (ma|mon|mes) (candidature|candidatures|dossier|inscription)|counselor|counsellor|an advisor|an adviser|help with my application|application support|support for my application)\b/,
        selfAsking: false,
      },
    ],
    title: { fr: 'Un conseiller KPB peut t’aider', en: 'A KPB advisor can help you' },
    body: {
      fr: `Tu peux ouvrir un dossier dans l’app : un conseiller KPB t’aide à préparer ta candidature. ${WA.fr}`,
      en: `You can open a file in the app: a KPB advisor helps you prepare your application. ${WA.en}`,
    },
  },
  {
    id: 'visa',
    feature: 'services',
    route: '/services',
    label: { fr: 'Préparer son visa', en: 'Prepare a visa' },
    featureLabel: { fr: 'Services → aide visa (si une offre visa est active)', en: 'Services → visa help (when a visa offer is active)' },
    rules: [
      {
        id: 'visa.prepare',
        pattern: /\b(visa|visas)\b/,
        selfAsking: false,
      },
    ],
    title: { fr: 'Prépare ton visa avec KPB', en: 'Prepare your visa with KPB' },
    body: {
      fr: `Dans l’app, la page Services présente l’aide de KPB pour préparer ta demande de visa. ${WA.fr}`,
      en: `In the app, the Services page shows KPB’s help to prepare your visa application. ${WA.en}`,
    },
  },
  {
    id: 'school_choice',
    feature: 'orientation',
    route: '/orientation',
    label: { fr: 'Choisir une école / formation', en: 'Choose a school / programme' },
    featureLabel: { fr: 'Test d’orientation', en: 'Orientation test' },
    rules: [
      {
        id: 'school_choice.which',
        pattern:
          /\b(quelles? ecoles?|quelles? universites?|quelles? formations?|quelles? filieres?|quel master|quelle licence|choisir (une |mon |ma |la |le )?(ecole|universite|formation|filiere|master|licence|specialite)|trouver (une |des |mon |ma )?(ecoles?|universites?|formations?|filieres?)|m orienter|mon orientation|which (school|schools|university|universities|program|programs|programme|programmes|course|courses|major)|choose (a |my )?(school|university|program|programme|course|major)|find (a |my )?(school|university|program|programme|course))\b/,
        selfAsking: true,
      },
    ],
    title: { fr: 'Trouve ta formation avec l’orientation', en: 'Find your programme with the orientation test' },
    body: {
      fr: `Le test d’orientation de l’app t’aide à repérer les formations et les écoles qui vont avec ton profil. ${WA.fr}`,
      en: `The app’s orientation test helps you spot the programmes and schools that fit your profile. ${WA.en}`,
    },
  },
];

export const ASSIST_NEED_IDS: readonly AssistNeedId[] = ASSIST_NEEDS.map((n) => n.id);

export function needById(id: string): AssistNeed | null {
  return ASSIST_NEEDS.find((n) => n.id === id) ?? null;
}

// ── Détection ────────────────────────────────────────────────────────────────

export type AssistSkip = 'too_short' | 'negation' | 'already_done' | 'no_need';

export type AssistDetection =
  | { detected: true; needId: AssistNeedId; ruleId: string; ruleVersion: string }
  | { detected: false; skip: AssistSkip };

const MENTION_TOKEN_RE =
  /@\[([^\]\n]{1,80})\]\((?:scholarship|country|institution|program):[A-Za-z0-9_-]{1,64}\)/g;

/** `@[Bourse Eiffel](scholarship:x)` → `Bourse Eiffel`. */
function stripMentions(text: string): string {
  return text.replace(MENTION_TOKEN_RE, (_whole, label: string) => label);
}

/**
 * Le besoin exprimé dans un texte DE L'ÉLÈVE (titre + corps d'une publication,
 * corps d'une réponse, message au coach). Rien de ce qui n'a pas été écrit par
 * lui ne doit arriver ici : c'est l'appelant qui le garantit.
 */
export function detectNeed(raw: string): AssistDetection {
  const text = stripMentions(raw ?? '');
  const norm = normalizeSearchText(text);
  const words = norm ? norm.split(' ').length : 0;
  if (words < ASSIST_MIN_WORDS) return { detected: false, skip: 'too_short' };
  if (NEGATION.test(norm)) return { detected: false, skip: 'negation' };
  const asks = ASK.test(norm) || text.includes('?');
  let sawAlreadyDone = false;
  for (const need of ASSIST_NEEDS) {
    for (const rule of need.rules) {
      if (!rule.pattern.test(norm)) continue;
      if (!rule.selfAsking && !asks) continue;
      if (ALREADY.test(norm) || need.alreadyDone?.test(norm)) {
        sawAlreadyDone = true;
        break;
      }
      return { detected: true, needId: need.id, ruleId: rule.id, ruleVersion: ASSIST_BRIDGE_RULES_VERSION };
    }
  }
  return { detected: false, skip: sawAlreadyDone ? 'already_done' : 'no_need' };
}

/** Le catalogue tel que la console le lit (lecture seule). */
export function catalogJson() {
  return {
    version: ASSIST_BRIDGE_RULES_VERSION,
    minWords: ASSIST_MIN_WORDS,
    needs: ASSIST_NEEDS.map((n) => ({
      id: n.id,
      label: n.label,
      feature: n.feature,
      featureLabel: n.featureLabel,
      route: n.route,
      rules: n.rules.map((r) => ({ id: r.id, selfAsking: r.selfAsking })),
      title: n.title,
      body: n.body,
    })),
  };
}
