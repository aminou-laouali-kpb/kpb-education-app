// ─────────────────────────────────────────────────────────────────────────────
// Bot « Vérif » (C3) — DÉTECTION d'une question de vérification factuelle.
//
// Fonctions PURES (aucune base, aucune horloge) : la publication arrive avec
// son type, son texte et ses mentions déjà résolues ; on dit si c'est une
// question que les données du catalogue peuvent trancher, et lesquelles.
//
// Signaux, tous nécessaires :
//   1. type `question` — un retour d'expérience ou un conseil n'appelle pas de
//      vérification, même s'il cite une date ;
//   2. au moins un MOTIF de vérification FR/EN (« ouvert », « date limite »,
//      « deadline », « c'est vrai », « arnaque », « frais », « gratuit »,
//      « partenaire », « documents »…) ;
//   3. au moins une ENTITÉ du catalogue : mentionnée (`@Eiffel`), sinon
//      retrouvée dans le texte par le service (seuil strict, unique) — sans
//      entité sûre, pas de brouillon.
// ─────────────────────────────────────────────────────────────────────────────

import { normalizeSearchText } from '../etudes-en-france/catalog/eef-search-text';

export type VerifIntent =
  | 'status'
  | 'deadline'
  | 'truth'
  | 'scam'
  | 'fees'
  | 'partner'
  | 'exists'
  | 'documents'
  | 'intake'
  | 'visa';

export const VERIF_INTENTS: readonly VerifIntent[] = [
  'status',
  'deadline',
  'truth',
  'scam',
  'fees',
  'partner',
  'exists',
  'documents',
  'intake',
  'visa',
];

/**
 * Motifs sur le texte NORMALISÉ (`normalizeSearchText` : minuscules, sans
 * accents, ponctuation = espace), mots entiers. Un motif = un intérêt ; une
 * question peut en porter plusieurs (« c'est vrai que la bourse est ouverte ? »
 * = truth + status).
 */
const INTENT_PATTERNS: Record<VerifIntent, RegExp> = {
  status:
    /\b(ouverte?s?|ouvre|ouvrent|ouverture|fermee?s?|ferme|cloturee?s?|cloture|encore possible|toujours possible|candidatures? (sont|est)|inscriptions? (sont|est)|open|opens|opened|closed|still accepting|accepting applications|applications? (are|is) open)\b/,
  deadline:
    /\b(date limite|dates limites|deadline|deadlines|jusqu a quand|quand (est|se termine|finit|ferme|ferment|ouvre|ouvrent|commence|commencent)|date de cloture|derniere date|closing date|due date|until when|when (is|does|do|will))\b/,
  truth:
    /\b(c est vrai|est ce vrai|vrai que|rumeur|fiable|legitime|serieux|serieuse|is it true|true that|legit|legitimate|real or fake)\b/,
  scam:
    /\b(arnaque|arnaques|arnaquer|escroc|escrocs|escroquerie|fraude|faux site|agent|agents|frais d agent|payer|paie|paye|scam|scams|scammer|fraud|fake)\b/,
  fees:
    /\b(frais|gratuite?s?|cout|couts|coute|coutent|prix|payant|payante|payants|scolarite|fee|fees|free|cost|costs|tuition|price)\b/,
  partner: /\b(partenaire|partenaires|partenariat|partner|partners|partnership)\b/,
  exists:
    /\b(existe|existent|reconnue?s?|officielle?s?|accreditee?s?|agreee?s?|exist|exists|recognized|recognised|accredited|official)\b/,
  documents:
    /\b(documents?|pieces?|pieces a fournir|papiers|justificatifs?|required documents|paperwork|requirements?)\b/,
  intake: /\b(rentree|rentrees|intake|intakes|semestre|prochaine session|next session)\b/,
  visa: /\b(visa|visas)\b/,
};

export function detectIntents(text: string): VerifIntent[] {
  const norm = normalizeSearchText(text);
  if (!norm) return [];
  return VERIF_INTENTS.filter((intent) => INTENT_PATTERNS[intent].test(norm));
}

/** Indices d'arnaque dans la question : la réponse porte la phrase de prudence. */
export function mentionsScam(intents: readonly VerifIntent[]): boolean {
  return intents.includes('scam');
}

// Mots outils fréquents, comptés en mots entiers sur le texte normalisé.
const FR_MARKERS = new Set([
  'le', 'la', 'les', 'est', 'sont', 'je', 'tu', 'des', 'une', 'pour', 'que', 'qui', 'quand', 'bourse',
  'bourses', 'ouverte', 'ouvert', 'avec', 'dans', 'pas', 'mon', 'ma', 'vous', 'nous', 'quelle', 'quels',
  'comment', 'ce', 'cette', 'du', 'au', 'aux', 'et', 'ou', 'merci', 'bonjour', 'svp',
]);
const EN_MARKERS = new Set([
  'the', 'is', 'are', 'i', 'you', 'what', 'when', 'which', 'scholarship', 'scholarships', 'open', 'with',
  'in', 'not', 'my', 'we', 'how', 'this', 'that', 'of', 'and', 'or', 'thanks', 'hello', 'please', 'does',
  'do', 'for', 'it', 'still', 'any',
]);

/** FR ou EN : la réponse suit la langue de la question (égalité → FR). */
export function detectLang(text: string): 'fr' | 'en' {
  let fr = 0;
  let en = 0;
  for (const word of normalizeSearchText(text).split(' ')) {
    if (FR_MARKERS.has(word)) fr += 1;
    if (EN_MARKERS.has(word)) en += 1;
  }
  return en > fr ? 'en' : 'fr';
}

export interface DetectionInput {
  type: string;
  authorKind: string;
  title: string;
  /** Corps avec jetons ; les jetons sont retirés avant l'analyse. */
  body: string;
}

export type DetectionSkip = 'team_post' | 'not_question' | 'no_intent';

export interface DetectionResult {
  candidate: boolean;
  skip: DetectionSkip | null;
  intents: VerifIntent[];
  lang: 'fr' | 'en';
  scamCaution: boolean;
  /** Texte de la question sans jetons de mention (pour la résolution par nom). */
  plain: string;
}

const MENTION_TOKEN_RE =
  /@\[([^\]\n]{1,80})\]\((?:scholarship|country|institution|program):[A-Za-z0-9_-]{1,64}\)/g;

/** `@[Bourse Eiffel](scholarship:x)` → `Bourse Eiffel` (le libellé reste lisible). */
export function stripMentionTokens(body: string): string {
  return body.replace(MENTION_TOKEN_RE, (_whole, label: string) => label);
}

/**
 * Première moitié de la détection : type, auteur, motifs, langue. L'entité est
 * cherchée ensuite (mentions, puis résolution par nom côté service).
 */
export function detectVerificationQuestion(input: DetectionInput): DetectionResult {
  const plain = `${input.title}\n${stripMentionTokens(input.body)}`;
  const lang = detectLang(plain);
  const intents = detectIntents(plain);
  const base = { intents, lang, scamCaution: mentionsScam(intents), plain };
  // Jamais sur un contenu de l'équipe (ni du bot lui-même).
  if (input.authorKind !== 'member') return { ...base, candidate: false, skip: 'team_post' };
  if (input.type !== 'question') return { ...base, candidate: false, skip: 'not_question' };
  if (intents.length === 0) return { ...base, candidate: false, skip: 'no_intent' };
  return { ...base, candidate: true, skip: null };
}
