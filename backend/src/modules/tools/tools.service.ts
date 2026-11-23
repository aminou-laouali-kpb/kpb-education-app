// ─────────────────────────────────────────────────────────────────────────────
// ToolsService — student productivity tools powered by the LLM provider via LlmService.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { LlmService } from '../ai/llm.service';

export interface CvSummaryDto {
  name: string;
  studyLevel: string;
  fieldOfStudy: string;
  targetCountry?: string;
  skills?: string[];
  languages?: string[];
  experience?: string;
  /// Degree the student is aiming for (e.g. "Master"), when declared.
  targetLevel?: string;
  /// Where the student currently lives — a recruiter reads mobility into it.
  countryOfResidence?: string;
  /// The student's own career-objective sentence, so the summary echoes it
  /// instead of inventing a different ambition.
  objective?: string;
}

export interface LetterPersonalizeDto {
  templateKey: string;
  templateBody: string;
  /// Ignored. Older app builds still send it; it never reaches the prompt.
  name?: string;
  fieldOfStudy: string;
  targetCountry?: string;
  targetInstitution?: string;
  targetScholarship?: string;
  strengths?: string;
  keyEvent?: string;
}

export interface InterviewQuestionsDto {
  type: 'visa' | 'admission' | 'scholarship';
  fieldOfStudy?: string;
  targetCountry?: string;
  language?: 'fr' | 'en';
}

export interface InterviewFeedbackDto {
  type: 'visa' | 'admission' | 'scholarship';
  question: string;
  answer: string;
  language?: 'fr' | 'en';
}

export interface InterviewFeedback {
  score: number; // 0-100
  strengths: string[];
  improvements: string[];
  modelAnswer: string;
}

/// Per-attempt provider timeout for the FR+EN letter. Measured on prod with
/// reasoning disabled: 5–19 s depending on the routed endpoint, so the 18 s env
/// default aborted healthy generations. Two attempts ⇒ 80 s worst case, under
/// the app's 90 s AI receive timeout.
export const LETTER_TIMEOUT_MS = 40_000;

/**
 * Erreur rendue quand le modèle n'a rien produit d'exploitable (panne, 429,
 * réponse tronquée, JSON de la mauvaise forme). Une 503 : l'app installée
 * l'affiche déjà (« service IA indisponible ») et le contrôleur rend l'unité
 * de quota (audit 22/11/2026, constat 16).
 */
function generationFailed(): ServiceUnavailableException {
  return new ServiceUnavailableException('AI generation failed.');
}

/** Texte non vide, sinon `undefined`. */
function nonEmptyString(value: unknown, max = 8000): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, max) : undefined;
}

/** Liste de textes non vides ; une chaîne seule est acceptée comme liste. */
function stringList(value: unknown, maxItems: number): string[] | undefined {
  const items = typeof value === 'string' ? [value] : value;
  if (!Array.isArray(items)) return undefined;
  return items
    .map((item) => nonEmptyString(item, 1000))
    .filter((item): item is string => item !== undefined)
    .slice(0, maxItems);
}

/** `{ fr, en }` avec deux textes non vides, sinon `undefined`. */
export function parseBilingualText(
  value: unknown,
): { fr: string; en: string } | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const fr = nonEmptyString((value as Record<string, unknown>).fr);
  const en = nonEmptyString((value as Record<string, unknown>).en);
  return fr && en ? { fr, en } : undefined;
}

/**
 * Valide et normalise l'évaluation rendue par le modèle : note entière bornée
 * à 0-100 (une note `"85"` en texte est convertie), listes de textes. Rend
 * `undefined` si la note manque : pas de note inventée.
 */
export function parseInterviewFeedback(
  value: unknown,
): InterviewFeedback | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const raw = value as Record<string, unknown>;
  const score =
    typeof raw.score === 'number'
      ? raw.score
      : typeof raw.score === 'string' && raw.score.trim() !== ''
        ? Number(raw.score)
        : Number.NaN;
  if (!Number.isFinite(score)) return undefined;
  const strengths = stringList(raw.strengths, 8);
  const improvements = stringList(raw.improvements, 8);
  if (!strengths || !improvements) return undefined;
  return {
    score: Math.min(100, Math.max(0, Math.round(score))),
    strengths,
    improvements,
    modelAnswer: nonEmptyString(raw.modelAnswer) ?? '',
  };
}

@Injectable()
export class ToolsService {
  private readonly logger = new Logger(ToolsService.name);

  constructor(private readonly llm: LlmService) {}

  // ── 1. CV summary (FR + EN) ───────────────────────────────────────────────

  async generateCvSummary(
    dto: CvSummaryDto,
  ): Promise<{ fr: string; en: string }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    // The student's civil name is intentionally omitted. The DTO still
    // accepts `name` (the client form has a name field for the PDF) but it
    // must not reach the LLM provider — that was the leak the consent copy
    // used to deny.
    const context = [
      `Niveau d'études : ${dto.studyLevel}`,
      `Domaine : ${dto.fieldOfStudy}`,
      dto.countryOfResidence
        ? `Pays de résidence : ${dto.countryOfResidence}`
        : '',
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.targetLevel ? `Diplôme visé : ${dto.targetLevel}` : '',
      dto.skills?.length ? `Compétences : ${dto.skills.join(', ')}` : '',
      dto.languages?.length ? `Langues : ${dto.languages.join(', ')}` : '',
      dto.experience ? `Expérience : ${dto.experience}` : '',
      dto.objective ? `Objectif professionnel : ${dto.objective}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    // `unknown` : la forme rendue par le modèle est vérifiée plus bas.
    const result = await this.llm.completeJson<unknown>({
      system:
        'Tu es un expert en rédaction de CV pour étudiants internationaux. ' +
        'Rédige un paragraphe de présentation professionnelle (5-7 phrases) ' +
        'en français ET en anglais, percutant et adapté au recrutement international. ' +
        'Ne commence pas par "Je suis" / "I am". ' +
        // The client renders this text into a PDF whose built-in Helvetica has
        // no glyph above U+00FF: emoji and typographic dashes/quotes come out as
        // empty boxes. The client sanitises defensively, but not emitting them
        // in the first place keeps the on-screen preview and the PDF identical.
        'N\'utilise AUCUN emoji, pictogramme, puce décorative ni caractère ' +
        'spécial (pas de —, ’, “ ”, …) : uniquement du texte simple avec la ' +
        'ponctuation ASCII et les accents français. ' +
        'Retourne un JSON { "fr": "...", "en": "..." }.',
      user: context,
      maxTokens: 600,
      // Jamais rendu : une phrase générique insérée dans le PDF comme si elle
      // avait été rédigée pour l'élève était un faux résultat.
      fallback: null,
    });

    const summary =
      result.model === 'local-fallback'
        ? undefined
        : parseBilingualText(result.data);
    if (!summary) throw generationFailed();
    return summary;
  }

  // ── 2. Letter personalisation (FR + EN) ───────────────────────────────────

  async personalizeLetters(
    dto: LetterPersonalizeDto,
  ): Promise<{ fr: string; en: string }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    // Civil name is accepted on the DTO (the letter PDF prints it) but must
    // not be copied into the LLM prompt — same IA-T2 rule as cv-summary.
    const context = [
      `Domaine : ${dto.fieldOfStudy}`,
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.targetInstitution ? `Établissement : ${dto.targetInstitution}` : '',
      dto.targetScholarship ? `Bourse visée : ${dto.targetScholarship}` : '',
      dto.strengths ? `Points forts : ${dto.strengths}` : '',
      dto.keyEvent ? `Événement marquant : ${dto.keyEvent}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    const result = await this.llm.completeJson<unknown>({
      system:
        'Tu es un expert en rédaction de lettres de motivation pour étudiants internationaux. ' +
        'Personnalise le modèle fourni avec les informations de l\'étudiant. ' +
        'Garde la structure, améliore la formulation, rends-la authentique. ' +
        'Fournis la version française ET une traduction/adaptation anglaise. ' +
        'Retourne un JSON { "fr": "...", "en": "..." }.',
      user: `Informations étudiant :\n${context}\n\nModèle à personnaliser :\n${dto.templateBody}`,
      maxTokens: 1500,
      timeoutMs: LETTER_TIMEOUT_MS,
      fallback: { fr: dto.templateBody, en: dto.templateBody },
    });

    // The fallback IS the untouched template: returning it as if it were the
    // personalised letter showed students their own blank model under a
    // « personnalisée » label. Say the generation failed instead.
    const letters =
      result.model === 'local-fallback'
        ? undefined
        : parseBilingualText(result.data);
    if (!letters) throw generationFailed();
    return letters;
  }

  // ── 3. Interview simulator ──────────────────────────────────────────────────

  async getInterviewQuestions(
    dto: InterviewQuestionsDto,
  ): Promise<{ questions: string[] }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const en = dto.language === 'en';
    const typeLabel = {
      visa: en ? 'student visa interview' : 'entretien de visa étudiant',
      admission: en ? 'university admission interview' : 'entretien d\'admission universitaire',
      scholarship: en ? 'scholarship interview' : 'entretien de bourse d\'études',
    }[dto.type];

    const fallbackQuestions = en
      ? [
          'Why did you choose this country for your studies?',
          'How will you finance your studies and living costs?',
          'What are your plans after graduation?',
          'Why this specific programme and university?',
          'What ties do you have to your home country?',
          'How does this fit your long-term career goals?',
        ]
      : [
          'Pourquoi avoir choisi ce pays pour vos études ?',
          'Comment financerez-vous vos études et votre séjour ?',
          'Quels sont vos projets après l\'obtention du diplôme ?',
          'Pourquoi ce programme et cette université précisément ?',
          'Quels liens conservez-vous avec votre pays d\'origine ?',
          'En quoi cela s\'inscrit-il dans votre projet professionnel ?',
        ];

    const result = await this.llm.completeJson<unknown>({
      system: en
        ? `You are an experienced interviewer conducting a ${typeLabel}. ` +
          'Generate 6 realistic, progressively harder interview questions. ' +
          'Return JSON { "questions": ["...", ...] }.'
        : `Tu es un examinateur expérimenté qui mène un ${typeLabel}. ` +
          'Génère 6 questions réalistes, de difficulté progressive. ' +
          'Retourne un JSON { "questions": ["...", ...] }.',
      user: [
        dto.fieldOfStudy ? `Domaine : ${dto.fieldOfStudy}` : '',
        dto.targetCountry ? `Pays : ${dto.targetCountry}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
      maxTokens: 600,
      // Repli gardé ici : ce sont de vraies questions types d'entretien, pas un
      // résultat qui prétend juger l'élève.
      fallback: { questions: fallbackQuestions },
    });

    // Forme vérifiée : une liste de questions non vides, sinon la liste type.
    const rawQuestions = (
      result.data as { questions?: unknown } | null | undefined
    )?.questions;
    const questions = Array.isArray(rawQuestions)
      ? stringList(rawQuestions, 10)
      : undefined;
    if (result.model !== 'local-fallback' && (!questions || !questions.length)) {
      this.logger.warn('Interview questions had an invalid shape; using the default set.');
    }
    return { questions: questions?.length ? questions : fallbackQuestions };
  }

  async evaluateInterviewAnswer(
    dto: InterviewFeedbackDto,
  ): Promise<InterviewFeedback> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const en = dto.language === 'en';

    const result = await this.llm.completeJson<unknown>({
      system: en
        ? 'You are a strict but supportive interview coach. Evaluate the candidate answer. ' +
          'Return JSON { "score": 0-100, "strengths": ["..."], "improvements": ["..."], "modelAnswer": "..." }.'
        : 'Tu es un coach d\'entretien exigeant mais bienveillant. Évalue la réponse du candidat. ' +
          'Retourne un JSON { "score": 0-100, "strengths": ["..."], "improvements": ["..."], "modelAnswer": "..." }.',
      user: `Question : ${dto.question}\n\nRéponse du candidat : ${dto.answer}`,
      maxTokens: 700,
      // Plus de note de repli : un « 70/100 – Réponse claire » rendu quelle
      // que soit la réponse était une fausse évaluation (constat 16).
      fallback: null,
    });

    const feedback =
      result.model === 'local-fallback'
        ? undefined
        : parseInterviewFeedback(result.data);
    if (!feedback) throw generationFailed();
    return feedback;
  }
}
