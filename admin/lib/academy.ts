/**
 * Cours Academy : types de l'API d'administration et règles de saisie.
 *
 * Tout ce qui se décide sans le serveur vit ici, pur et testé
 * (`academy.test.ts`) : la page ne fait qu'afficher et envoyer. Les règles
 * reprennent celles du backend (`backend/src/modules/academy/dto/*`) pour
 * refuser AVANT l'envoi ce que le serveur refuserait — le serveur reste juge.
 */

export type AcademyStatus = 'draft' | 'published' | 'archived';

export const ACADEMY_STATUSES: readonly AcademyStatus[] = [
  'draft',
  'published',
  'archived',
];

export interface AcademyLesson {
  id: string;
  courseId: string;
  titleFr: string;
  titleEn: string;
  videoUrl: string;
  youtubeVideoId: string | null;
  thumbnailUrl: string | null;
  watchUrl: string;
  durationSeconds: number;
  order: number;
  status: AcademyStatus;
}

export interface AcademyCourse {
  id: string;
  slug: string | null;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  coverImageUrl: string | null;
  priceXOF: number;
  priceEUR: number;
  status: AcademyStatus;
  displayOrder: number;
  lessonCount: number;
  publishedLessonCount: number;
  publishedDurationSeconds: number;
  purchaseCount: number;
  /** Cours publié ET au moins une leçon publiée : ce que l'app affiche. */
  visibleInApp: boolean;
}

export interface AcademyCourseDetail extends AcademyCourse {
  lessons: AcademyLesson[];
}

export interface AcademyCourseInput {
  slug?: string;
  titleFr?: string;
  titleEn?: string;
  descriptionFr?: string;
  descriptionEn?: string;
  coverImageUrl?: string | null;
  status?: AcademyStatus;
  displayOrder?: number;
}

export interface AcademyLessonInput {
  youtubeUrl?: string;
  titleFr?: string;
  titleEn?: string;
  durationSeconds?: number;
  status?: AcademyStatus;
}

/** Ce que `POST /admin/academy/courses/import` accepte, champ pour champ. */
export interface AcademyImportLesson {
  order: number;
  youtubeUrl: string;
  titleFr: string;
  titleEn?: string;
  durationSeconds: number;
  status?: AcademyStatus;
}

export interface AcademyImportCourse {
  slug: string;
  titleFr: string;
  titleEn?: string;
  descriptionFr?: string;
  descriptionEn?: string;
  coverImageUrl?: string;
  displayOrder?: number;
  lessons: AcademyImportLesson[];
}

export interface AcademyImportReport {
  course: {
    id: string;
    slug: string;
    status: AcademyStatus;
    created: boolean;
    updated: boolean;
  };
  lessons: { created: number; updated: number; unchanged: number };
  notInManifest: Array<{
    id: string;
    titleFr: string;
    order: number;
    status: AcademyStatus;
  }>;
}

/** Miroir de `ACADEMY_SLUG_PATTERN` (backend). */
export const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const SLUG_MAX = 80;
const TITLE_MAX = 200;
const DESCRIPTION_MAX = 4000;
const MAX_DURATION = 86_400;

/** « Préparation HSK 1 — Bourse CSC » → `preparation-hsk-1-bourse-csc`. */
export function slugify(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    // Ligatures que NFD ne décompose pas.
    .replace(/œ/g, 'oe')
    .replace(/æ/g, 'ae')
    .replace(/ß/g, 'ss')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, SLUG_MAX)
    .replace(/-+$/g, '');
}

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;
const YOUTUBE_HOSTS = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
  'www.youtu.be',
]);

/**
 * Identifiant YouTube d'un lien collé (watch, youtu.be, embed, shorts, live)
 * ou d'un identifiant nu. Même liste d'hôtes que le serveur : un lien qu'il
 * refuserait est refusé ici, avant l'envoi.
 */
export function parseYoutubeId(value: string): string | null {
  const raw = value.trim();
  if (YOUTUBE_ID.test(raw)) return raw;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || !YOUTUBE_HOSTS.has(url.hostname)) return null;
  let candidate: string | null = null;
  if (url.hostname.endsWith('youtu.be')) {
    candidate = url.pathname.split('/').filter(Boolean)[0] ?? null;
  } else if (url.pathname === '/watch') {
    candidate = url.searchParams.get('v');
  } else {
    const segments = url.pathname.split('/').filter(Boolean);
    if (['embed', 'shorts', 'live'].includes(segments[0] ?? '')) {
      candidate = segments[1] ?? null;
    }
  }
  return candidate && YOUTUBE_ID.test(candidate) ? candidate : null;
}

export function youtubeWatchUrl(youtubeVideoId: string): string {
  return `https://www.youtube.com/watch?v=${youtubeVideoId}`;
}

/** `4:05` → 245 ; `1:02:03` → 3723 ; `245` → 245. `null` si illisible ou nul. */
export function parseDuration(value: string): number | null {
  const raw = value.trim();
  if (!/^\d+(?::\d{1,2}){0,2}$/.test(raw)) return null;
  const parts = raw.split(':').map(Number);
  if (parts.slice(1).some((part) => part >= 60)) return null;
  const seconds = parts.reduce((total, part) => total * 60 + part, 0);
  return seconds >= 1 && seconds <= MAX_DURATION ? seconds : null;
}

/** 245 → `4:05` ; 3723 → `1:02:03`. */
export function formatDuration(totalSeconds: number): string {
  const safe = Math.max(0, Math.round(totalSeconds));
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  const seconds = safe % 60;
  const ss = String(seconds).padStart(2, '0');
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, '0')}:${ss}`;
  }
  return `${minutes}:${ss}`;
}

export class AcademyDraftError extends Error {}

export interface CourseDraft {
  slug: string;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  coverImageUrl: string;
  displayOrder: string;
  status: AcademyStatus;
}

export const EMPTY_COURSE_DRAFT: CourseDraft = {
  slug: '',
  titleFr: '',
  titleEn: '',
  descriptionFr: '',
  descriptionEn: '',
  coverImageUrl: '',
  displayOrder: '0',
  // Brouillon d'abord : on publie quand les leçons sont là et relues.
  status: 'draft',
};

export function courseToDraft(course: AcademyCourse): CourseDraft {
  return {
    slug: course.slug ?? '',
    titleFr: course.titleFr,
    titleEn: course.titleEn === course.titleFr ? '' : course.titleEn,
    descriptionFr: course.descriptionFr,
    descriptionEn:
      course.descriptionEn === course.descriptionFr ? '' : course.descriptionEn,
    coverImageUrl: course.coverImageUrl ?? '',
    displayOrder: String(course.displayOrder),
    status: course.status,
  };
}

function isHttpsUrl(value: string): boolean {
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Formulaire → payload. À la création, un champ vide est omis (le serveur
 * applique son défaut) ; à l'édition, il est envoyé vide pour être vidé — le
 * serveur reprend alors le français pour l'anglais, et `null` retire la
 * couverture.
 */
export function toCourseInput(
  draft: CourseDraft,
  mode: 'create' | 'edit',
): AcademyCourseInput {
  const slug = draft.slug.trim();
  const titleFr = draft.titleFr.trim();
  if (!titleFr) throw new AcademyDraftError('Le titre français est obligatoire.');
  if (titleFr.length > TITLE_MAX || draft.titleEn.trim().length > TITLE_MAX) {
    throw new AcademyDraftError(`Un titre ne dépasse pas ${TITLE_MAX} caractères.`);
  }
  if (!SLUG_PATTERN.test(slug) || slug.length > SLUG_MAX) {
    throw new AcademyDraftError(
      'Identifiant invalide : minuscules, chiffres et tirets (ex. hsk-1).',
    );
  }
  if (
    draft.descriptionFr.length > DESCRIPTION_MAX ||
    draft.descriptionEn.length > DESCRIPTION_MAX
  ) {
    throw new AcademyDraftError(
      `Une description ne dépasse pas ${DESCRIPTION_MAX} caractères.`,
    );
  }
  const cover = draft.coverImageUrl.trim();
  if (cover && !isHttpsUrl(cover)) {
    throw new AcademyDraftError('L’image de couverture doit être une adresse https://.');
  }
  const displayOrder = Number(draft.displayOrder.trim() || '0');
  if (!Number.isInteger(displayOrder) || displayOrder < 0 || displayOrder > 1000) {
    throw new AcademyDraftError('La position est un entier entre 0 et 1000.');
  }

  const input: AcademyCourseInput = {
    slug,
    titleFr,
    status: draft.status,
    displayOrder,
  };
  const titleEn = draft.titleEn.trim();
  const descriptionFr = draft.descriptionFr.trim();
  const descriptionEn = draft.descriptionEn.trim();
  if (mode === 'edit') {
    input.titleEn = titleEn;
    input.descriptionFr = descriptionFr;
    input.descriptionEn = descriptionEn;
    input.coverImageUrl = cover || null;
  } else {
    if (titleEn) input.titleEn = titleEn;
    if (descriptionFr) input.descriptionFr = descriptionFr;
    if (descriptionEn) input.descriptionEn = descriptionEn;
    if (cover) input.coverImageUrl = cover;
  }
  return input;
}

export interface LessonDraft {
  url: string;
  titleFr: string;
  titleEn: string;
  duration: string;
  status: AcademyStatus;
}

export const EMPTY_LESSON_DRAFT: LessonDraft = {
  url: '',
  titleFr: '',
  titleEn: '',
  duration: '',
  status: 'published',
};

export function lessonToDraft(lesson: AcademyLesson): LessonDraft {
  return {
    url: lesson.watchUrl,
    titleFr: lesson.titleFr,
    titleEn: lesson.titleEn === lesson.titleFr ? '' : lesson.titleEn,
    duration: formatDuration(lesson.durationSeconds),
    status: lesson.status,
  };
}

export function toLessonInput(
  draft: LessonDraft,
  mode: 'create' | 'edit',
): AcademyLessonInput {
  const youtubeVideoId = parseYoutubeId(draft.url);
  if (!youtubeVideoId) {
    throw new AcademyDraftError('Lien YouTube invalide.');
  }
  const titleFr = draft.titleFr.trim();
  if (!titleFr) throw new AcademyDraftError('Le titre français est obligatoire.');
  if (titleFr.length > TITLE_MAX || draft.titleEn.trim().length > TITLE_MAX) {
    throw new AcademyDraftError(`Un titre ne dépasse pas ${TITLE_MAX} caractères.`);
  }
  const durationSeconds = parseDuration(draft.duration);
  if (durationSeconds === null) {
    throw new AcademyDraftError('Durée invalide : écrire 4:05, 1:02:03 ou 245.');
  }
  const titleEn = draft.titleEn.trim();
  return {
    // Le serveur extrait lui-même l'identifiant ; on lui envoie la forme
    // canonique, que l'identifiant ait été collé nu ou dans un lien.
    youtubeUrl: youtubeWatchUrl(youtubeVideoId),
    titleFr,
    ...(mode === 'edit' || titleEn ? { titleEn } : {}),
    durationSeconds,
    status: draft.status,
  };
}

/** Nouvel ordre après un déplacement d'un cran ; `null` hors limites. */
export function moveLesson(
  ids: readonly string[],
  index: number,
  delta: -1 | 1,
): string[] | null {
  const target = index + delta;
  if (index < 0 || index >= ids.length || target < 0 || target >= ids.length) {
    return null;
  }
  const next = [...ids];
  [next[index], next[target]] = [next[target], next[index]];
  return next;
}

// ── Import de manifeste ───────────────────────────────────────────────────

export interface ParsedManifest {
  courses: AcademyImportCourse[];
  /** Problèmes bloquants, en français, un par ligne. Vide = importable. */
  problems: string[];
}

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function integer(value: unknown): number | null {
  if (typeof value === 'number' && Number.isInteger(value)) return value;
  if (typeof value === 'string' && /^\d+$/.test(value.trim())) {
    return Number(value.trim());
  }
  return null;
}

const LESSON_URL_KEYS = ['youtubeUrl', 'youtube', 'youtubeId', 'url', 'videoUrl'];

/**
 * Lit le `manifest.json` produit avec HyperFrames, complété des liens YouTube.
 *
 * Formes acceptées : un module seul, une liste de modules, ou un objet
 * `{ "modules": [...] }` (`courses` aussi). Pour chaque module, `slug` ou à
 * défaut `id` (« hsk-1 ») ; pour chaque leçon, le lien dans `youtubeUrl` (ou
 * `youtube`, `url`, `videoUrl`). Les champs propres au rendu (`file`, `type`,
 * `hskLevel`…) sont ignorés : le serveur refuserait toute clé inconnue.
 */
export function parseManifest(raw: string): ParsedManifest {
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch {
    return { courses: [], problems: ['Le texte collé n’est pas du JSON valide.'] };
  }

  const modules: unknown[] = Array.isArray(data)
    ? data
    : isObject(data) && Array.isArray(data.modules)
      ? data.modules
      : isObject(data) && Array.isArray(data.courses)
        ? data.courses
        : [data];

  const problems: string[] = [];
  const courses: AcademyImportCourse[] = [];
  const seenSlugs = new Set<string>();

  if (modules.length === 0) {
    return { courses: [], problems: ['Le manifeste ne contient aucun module.'] };
  }

  modules.forEach((module, moduleIndex) => {
    const where = `Module ${moduleIndex + 1}`;
    if (!isObject(module)) {
      problems.push(`${where} : ce n’est pas un objet JSON.`);
      return;
    }
    const slug = text(module.slug) || text(module.id);
    const label = slug || where;
    if (!SLUG_PATTERN.test(slug) || slug.length > SLUG_MAX) {
      problems.push(
        `${label} : identifiant (« slug » ou « id ») manquant ou invalide — minuscules, chiffres et tirets.`,
      );
    } else if (seenSlugs.has(slug)) {
      problems.push(`${label} : identifiant présent deux fois dans le manifeste.`);
    }
    seenSlugs.add(slug);

    const titleFr = text(module.titleFr);
    if (!titleFr) problems.push(`${label} : « titleFr » manquant.`);

    const course: AcademyImportCourse = { slug, titleFr, lessons: [] };
    const titleEn = text(module.titleEn);
    if (titleEn) course.titleEn = titleEn;
    const descriptionFr = text(module.descriptionFr);
    if (descriptionFr) course.descriptionFr = descriptionFr;
    const descriptionEn = text(module.descriptionEn);
    if (descriptionEn) course.descriptionEn = descriptionEn;
    const cover = text(module.coverImageUrl);
    if (cover) {
      if (isHttpsUrl(cover)) course.coverImageUrl = cover;
      else problems.push(`${label} : « coverImageUrl » doit commencer par https://.`);
    }
    if (module.displayOrder !== undefined) {
      const displayOrder = integer(module.displayOrder);
      if (displayOrder === null || displayOrder > 1000) {
        problems.push(`${label} : « displayOrder » doit être un entier entre 0 et 1000.`);
      } else {
        course.displayOrder = displayOrder;
      }
    }

    const lessons = Array.isArray(module.lessons) ? module.lessons : [];
    if (lessons.length === 0) {
      problems.push(`${label} : aucune leçon (« lessons » vide ou absent).`);
    }
    const seenOrders = new Map<number, number>();
    const seenVideos = new Map<string, number>();
    lessons.forEach((lesson, lessonIndex) => {
      if (!isObject(lesson)) {
        problems.push(`${label} · leçon ${lessonIndex + 1} : ce n’est pas un objet JSON.`);
        return;
      }
      const order = integer(lesson.order) ?? lessonIndex + 1;
      const at = `${label} · leçon ${order}`;
      if (order < 1 || order > 1000) {
        problems.push(`${at} : « order » doit être entre 1 et 1000.`);
      }
      if (seenOrders.has(order)) {
        problems.push(`${at} : position déjà utilisée par une autre leçon.`);
      }
      seenOrders.set(order, lessonIndex);

      const rawUrl = LESSON_URL_KEYS.map((key) => text(lesson[key])).find(Boolean) ?? '';
      const youtubeVideoId = rawUrl ? parseYoutubeId(rawUrl) : null;
      if (!rawUrl) {
        problems.push(`${at} : lien YouTube manquant (ajouter « youtubeUrl »).`);
      } else if (!youtubeVideoId) {
        problems.push(`${at} : lien YouTube illisible (${rawUrl}).`);
      } else if (seenVideos.has(youtubeVideoId)) {
        problems.push(
          `${at} : même vidéo que la leçon ${seenVideos.get(youtubeVideoId)}.`,
        );
      } else {
        seenVideos.set(youtubeVideoId, order);
      }

      const lessonTitleFr = text(lesson.titleFr);
      if (!lessonTitleFr) problems.push(`${at} : « titleFr » manquant.`);

      const durationSeconds = integer(lesson.durationSeconds);
      if (durationSeconds === null || durationSeconds < 1 || durationSeconds > MAX_DURATION) {
        problems.push(`${at} : « durationSeconds » doit être un nombre de secondes (ex. 245).`);
      }

      const status = text(lesson.status);
      if (status && !ACADEMY_STATUSES.includes(status as AcademyStatus)) {
        problems.push(`${at} : statut « ${status} » inconnu.`);
      }

      const parsed: AcademyImportLesson = {
        order,
        youtubeUrl: youtubeVideoId ? youtubeWatchUrl(youtubeVideoId) : rawUrl,
        titleFr: lessonTitleFr,
        durationSeconds: durationSeconds ?? 0,
      };
      const lessonTitleEn = text(lesson.titleEn);
      if (lessonTitleEn) parsed.titleEn = lessonTitleEn;
      if (status) parsed.status = status as AcademyStatus;
      course.lessons.push(parsed);
    });
    course.lessons.sort((a, b) => a.order - b.order);
    courses.push(course);
  });

  return { courses, problems };
}
