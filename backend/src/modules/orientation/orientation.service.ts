import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ORIENTATION_FIELD_BY_ID,
  ORIENTATION_FIELDS,
} from './orientation-fields.data';
import { ORIENTATION_QUESTIONS } from './orientation-questions.data';
import {
  compareScoredFields,
  matchPercentByField,
  normalizeStoredScore,
  prioritizesIaResilience,
  scoreOrientationAnswers,
} from './orientation-scorer';

type Answers = Record<string, string[]>;

type RecommendationDto = {
  fieldId: string;
  score: number;
  explanation: { fr: string; en: string };
  jobs: { fr: string[]; en: string[] };
  iaResilience: 'high' | 'medium' | 'low';
  partnerCountryIds: string[];
};

type OrientationSessionDto = {
  id: string;
  completedAt: string;
  answers: Answers;
  recommendations: RecommendationDto[];
  iaModelUsed: string;
  nextActions: { fr: string; en: string };
};

type StoredOrientationSession = OrientationSessionDto & {
  userId: string | null;
};

/** Longueur maximale d'une explication rendue par le modèle. */
const MAX_LLM_EXPLANATION_LENGTH = 1000;

/** Texte non vide et tronqué, sinon `undefined`. */
function llmText(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, MAX_LLM_EXPLANATION_LENGTH) : undefined;
}

/**
 * Valide et normalise la sortie JSON du modèle (audit 22/11/2026, constat 32).
 *
 * `completeJson` garantit seulement un objet JSON, pas sa forme. Avant :
 * un `recommendations` non tableau (ou un élément `null`) levait une
 * TypeError, donc une 500 avec le quota consommé ; une `explanationFr` non
 * chaîne (tableau, objet, nombre) était recopiée telle quelle, enregistrée,
 * et rendait la session illisible pour l'app (cast `as String?`) à chaque
 * relecture.
 *
 * Rend l'explication `{ fr, en }` de chaque filière que le modèle a
 * correctement décrite : un élément mal formé est ignoré (la filière garde son
 * explication déterministe), une `explanationEn` invalide reprend le texte
 * français. Rend `undefined` quand la sortie n'est pas exploitable du tout
 * (pas de tableau `recommendations`).
 */
export function parseOrientationLlmOutput(
  value: unknown,
): Map<string, { fr: string; en: string }> | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }
  const recommendations = (value as Record<string, unknown>).recommendations;
  if (!Array.isArray(recommendations)) return undefined;

  const byField = new Map<string, { fr: string; en: string }>();
  for (const item of recommendations) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    const record = item as Record<string, unknown>;
    if (typeof record.fieldId !== 'string') continue;
    const fieldId = record.fieldId.trim();
    const fr = llmText(record.explanationFr);
    if (!fieldId || !fr || byField.has(fieldId)) continue;
    byField.set(fieldId, { fr, en: llmText(record.explanationEn) ?? fr });
  }
  return byField;
}

/** Modèle enregistré quand aucune explication du modèle n'est retenue. */
const LOCAL_FALLBACK_MODEL = 'local-fallback';

/** Field ids declared in a client-supplied profile, ignoring anything else. */
function readFieldIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string');
}

function readAnswers(value: unknown): Answers {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const answers: Answers = {};
  for (const [questionId, selected] of Object.entries(value)) {
    if (!Array.isArray(selected)) continue;
    answers[questionId] = selected.filter(
      (item): item is string => typeof item === 'string',
    );
  }
  return answers;
}

/**
 * `{ fr, en }` en chaînes pour une explication relue en base. Une session
 * enregistrée avant la validation de la sortie du modèle (constat 32) peut
 * porter un tableau ou un objet dans `explanation.fr` : l'app installée le lit
 * avec un cast `as String?` et ne pouvait plus jamais rouvrir la session.
 * Une valeur non chaîne devient une chaîne vide (l'app affiche alors la
 * carte sans paragraphe) ; rien n'est réécrit en base.
 */
function sanitizeStoredExplanation(value: unknown): { fr: string; en: string } {
  const record =
    value && typeof value === 'object' && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  const fr = typeof record.fr === 'string' ? record.fr : '';
  const en = typeof record.en === 'string' ? record.en : fr;
  return { fr, en };
}

/**
 * Re-scores a session read back from storage so its percentages are on the
 * current normalised scale.
 *
 * Sessions written before the fix hold `rawPoints * 10` floored at 55 — up to
 * 260, which is how a result card ended up reading "160 %". Recomputing from the
 * stored answers is idempotent for sessions written after the fix, needs no
 * migration, and never rewrites what is in the database.
 *
 * They are also re-ranked: the old ordering put AI resilience before the score,
 * so the first recommendation — the one the app badges "best match" — was not
 * necessarily the highest scoring one.
 */
function normalizeRecommendationScores(
  storedAnswers: unknown,
  storedRecommendations: unknown,
): unknown {
  if (!Array.isArray(storedRecommendations)) return storedRecommendations;

  const answers = readAnswers(storedAnswers);
  const percentByField = matchPercentByField(answers);

  const rescored = storedRecommendations.map((recommendation) => {
    const isObject =
      !!recommendation &&
      typeof recommendation === 'object' &&
      !Array.isArray(recommendation);
    const record = isObject
      ? (recommendation as Record<string, unknown>)
      : null;
    const fieldId = typeof record?.fieldId === 'string' ? record.fieldId : null;
    if (!record || fieldId === null) {
      return { fieldId: '', score: 0, recomputed: false, recommendation };
    }
    const score = normalizeStoredScore(fieldId, record.score, percentByField);
    return {
      fieldId,
      score,
      recomputed: percentByField.has(fieldId),
      recommendation: {
        ...record,
        score,
        explanation: sanitizeStoredExplanation(record.explanation),
      },
    };
  });

  // Re-rank only when every score came from the same (recomputed) scale —
  // mixing a recomputed percentage with a clamped legacy one would invent an
  // ordering. Sessions written after the fix are already in this order, so the
  // sort is a no-op for them.
  if (!rescored.every((entry) => entry.recomputed)) {
    return rescored.map((entry) => entry.recommendation);
  }
  return [...rescored]
    .sort(compareScoredFields(prioritizesIaResilience(answers)))
    .map((entry) => entry.recommendation);
}

@Injectable()
export class OrientationService {
  /**
   * In-memory store. Source of truth only when the database is unavailable
   * (no `DATABASE_URL`); otherwise sessions live in Postgres and this array is
   * a best-effort mirror.
   */
  private readonly sessions: StoredOrientationSession[] = [];
  private readonly logger = new Logger(OrientationService.name);

  constructor(
    private readonly llmService: LlmService,
    private readonly prisma: PrismaService,
  ) {}

  getQuestions() {
    return {
      count: ORIENTATION_QUESTIONS.length,
      fields: ORIENTATION_FIELDS,
      // Exposed so the questionnaire the server scores with can be diffed
      // against the one the app ships, instead of the two drifting silently.
      questions: ORIENTATION_QUESTIONS,
      note: 'Mobile app ships the full questionnaire (wording + translations) locally; backend scoring uses the answer option ids and the weights returned here.',
    };
  }

  async createSession(body: Record<string, unknown>) {
    const answers = (body.answers as Answers | undefined) ?? {};
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const ranked = scoreOrientationAnswers(answers, {
      prioritizeIaResilience: prioritizesIaResilience(answers),
      declaredFieldIds: readFieldIds(profile.fieldIds),
    });
    const fallbackRecommendations = ranked.map((entry) =>
      this.buildRecommendation(entry.fieldId, entry.score, answers, profile),
    );

    // Ce qui part chez le tiers est une PROJECTION EXPLICITE, jamais l'objet
    // `profile` du client.
    //
    // Il l'était, et l'écran de consentement affiché juste avant affirmait le
    // contraire, mot pour mot : « Ton nom civil n'est pas recopié dans l'invite »
    // (app_translations.dart). Le lot 11 avait retiré `Nom : ${dto.name}` des
    // routes /tools et manqué celle-ci — or c'est ici que passe le questionnaire
    // d'orientation, la surface la plus utilisée de l'app. Le consentement était
    // donc recueilli sur une phrase fausse.
    //
    // La liste est CLOSE et le test la verrouille : un champ ajouté au corps de
    // la requête ne peut plus atteindre l'invite sans qu'une garde rougisse.
    // Les types sont contraints ici même, pour qu'un client ne puisse pas faire
    // passer un objet imbriqué dans un champ annoncé comme une chaîne.
    const promptProfile = {
      currentLevel:
        typeof profile.currentLevel === 'string' ? profile.currentLevel : null,
      targetCountryIds: Array.isArray(profile.targetCountryIds)
        ? profile.targetCountryIds.filter(
            (id): id is string => typeof id === 'string',
          )
        : [],
      fieldIds: readFieldIds(profile.fieldIds),
      preferredLanguage:
        typeof profile.preferredLanguage === 'string'
          ? profile.preferredLanguage
          : null,
    };

    // `unknown` : la forme rendue par le modèle est vérifiée juste après.
    const llmPayload = await this.llmService.completeJson<unknown>({
      system:
        'Tu es l\'orientation IA KPB. Réponds UNIQUEMENT en JSON valide avec recommendations[].fieldId (d01-d12), explanationFr, explanationEn (2 phrases max, personnalisées).',
      user: JSON.stringify({
        answers,
        profile: promptProfile,
        topFields: ranked.slice(0, 5),
      }),
      fallback: null,
    });

    // Panne du fournisseur, sortie inexploitable, ou aucun élément valide
    // pour une filière classée : la session déterministe est enregistrée
    // comme avant (`local-fallback`), en 2xx. Seules des explications
    // validées par `parseOrientationLlmOutput` sont reprises : aucune donnée
    // invalide n'atteint la base (constat 32).
    //
    // Pas de remboursement du quota dans ce cas, même quand l'appel n'a pas
    // été facturé : l'élève reçoit un résultat, et le quota borne aussi les
    // écritures en base (voir `OrientationController`). Le rembourser
    // rendrait les sessions illimitées pendant une panne ou quand l'IA n'est
    // pas configurée.
    const llmByField =
      llmPayload.fallbackReason === undefined
        ? parseOrientationLlmOutput(llmPayload.data)
        : undefined;
    const usedLlm =
      !!llmByField &&
      fallbackRecommendations.some((rec) => llmByField.has(rec.fieldId));
    if (!usedLlm && llmPayload.fallbackReason === undefined) {
      this.logger.warn(
        'Orientation: unusable model output, deterministic explanations kept.',
      );
    }
    const iaModelUsed = usedLlm ? llmPayload.model : LOCAL_FALLBACK_MODEL;

    const recommendations: RecommendationDto[] = fallbackRecommendations.map(
      (rec) => {
        const explanation = usedLlm ? llmByField.get(rec.fieldId) : undefined;
        return explanation ? { ...rec, explanation } : rec;
      },
    );

    const userId =
      typeof profile.id === 'string'
        ? profile.id
        : typeof body.userId === 'string'
          ? (body.userId as string)
          : null;
    const nextActions = {
      fr: 'Explore les écoles qui enseignent ces filières et demande un accompagnement KPB.',
      en: 'Explore schools teaching these fields and request KPB support.',
    };

    // ── Persist to Postgres when available ──────────────────────────────────
    const persisted = await this.prisma.tryExecute((client) =>
      client.orientationSession.create({
        data: {
          userId,
          answers: answers as unknown as Prisma.InputJsonValue,
          recommendations: recommendations as unknown as Prisma.InputJsonValue,
          iaModelUsed,
          nextActions: nextActions as unknown as Prisma.InputJsonValue,
        },
      }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        completedAt: persisted.completedAt.toISOString(),
        answers,
        recommendations,
        iaModelUsed: persisted.iaModelUsed,
        nextActions,
      };
    }

    // ── In-memory fallback ──────────────────────────────────────────────────
    const session = {
      id: `orientation-${Date.now()}`,
      userId,
      completedAt: new Date().toISOString(),
      answers,
      recommendations,
      iaModelUsed,
      nextActions,
    };

    this.sessions.unshift(session);
    return this.toPublicSession(session);
  }

  async getResults(id: string, userId: string) {
    const persisted = await this.prisma.tryExecute((client) =>
      client.orientationSession.findFirst({ where: { id, userId } }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        completedAt: persisted.completedAt.toISOString(),
        answers: persisted.answers,
        recommendations: normalizeRecommendationScores(
          persisted.answers,
          persisted.recommendations,
        ),
        iaModelUsed: persisted.iaModelUsed,
        nextActions: persisted.nextActions,
      };
    }

    const session = this.sessions.find(
      (item) => item.id === id && item.userId === userId,
    );
    if (!session) {
      throw new NotFoundException(`Orientation session ${id} not found.`);
    }
    return this.toPublicSession(session);
  }

  private toPublicSession(session: StoredOrientationSession): OrientationSessionDto {
    const { userId: _userId, ...publicSession } = session;
    return {
      ...publicSession,
      recommendations: normalizeRecommendationScores(
        publicSession.answers,
        publicSession.recommendations,
      ) as RecommendationDto[],
    };
  }

  private buildRecommendation(
    fieldId: string,
    score: number,
    answers: Answers,
    profile: Record<string, unknown>,
  ): RecommendationDto {
    const meta = ORIENTATION_FIELD_BY_ID.get(fieldId);
    const firstName = String(profile.fullName ?? '').split(' ')[0] || 'Ton profil';
    const fieldName = meta?.nameFr ?? fieldId;

    return {
      fieldId,
      // `score` is already the normalised percentage from the scorer. It used to
      // be floored at 55, which collapsed every weak match onto one value and
      // made two unrelated fields display the same number.
      score,
      explanation: {
        fr: `${firstName}, ${fieldName} ressort fortement d'après tes réponses. Ce domaine correspond à tes centres d'intérêt et ouvre des débouchés concrets chez nos écoles partenaires KPB.`,
        en: `${firstName}, ${meta?.nameEn ?? fieldId} stands out based on your answers. This field matches your interests and opens concrete pathways through KPB partner schools.`,
      },
      jobs: {
        fr: meta?.sampleJobsFr ?? [],
        en: meta?.sampleJobsEn ?? [],
      },
      iaResilience: meta?.iaResilience ?? 'medium',
      partnerCountryIds: meta?.partnerCountryIds ?? [],
    };
  }
}
