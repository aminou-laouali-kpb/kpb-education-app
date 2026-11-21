import { apiFetch } from './api-client';
import type {
  AcademyCourse,
  AcademyCourseDetail,
  AcademyCourseInput,
  AcademyImportCourse,
  AcademyImportReport,
  AcademyLesson,
  AcademyLessonInput,
} from './academy';

/**
 * Client des cours Academy pour le back-office : `/admin/academy/*`, derrière
 * AdminAuthGuard + RolesGuard (Admin, SuperAdmin, ContentManager).
 *
 * L'app, elle, lit `/academy/courses` : seuls les cours publiés ayant au moins
 * une leçon publiée y figurent.
 */

const BASE = '/admin/academy/courses';

export async function fetchAcademyCourses(): Promise<AcademyCourse[]> {
  const response = await apiFetch<{ items: AcademyCourse[] }>(BASE);
  return response?.items ?? [];
}

export function fetchAcademyCourse(id: string): Promise<AcademyCourseDetail> {
  return apiFetch<AcademyCourseDetail>(`${BASE}/${encodeURIComponent(id)}`);
}

export function createAcademyCourse(
  input: AcademyCourseInput,
): Promise<AcademyCourseDetail> {
  return apiFetch<AcademyCourseDetail>(BASE, { method: 'POST', body: input });
}

export function updateAcademyCourse(
  id: string,
  input: AcademyCourseInput,
): Promise<AcademyCourseDetail> {
  return apiFetch<AcademyCourseDetail>(`${BASE}/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: input,
  });
}

export async function deleteAcademyCourse(id: string): Promise<void> {
  await apiFetch(`${BASE}/${encodeURIComponent(id)}`, { method: 'DELETE' });
}

export function importAcademyCourse(
  course: AcademyImportCourse,
): Promise<AcademyImportReport> {
  return apiFetch<AcademyImportReport>(`${BASE}/import`, {
    method: 'POST',
    body: course,
  });
}

export function createAcademyLesson(
  courseId: string,
  input: AcademyLessonInput,
): Promise<AcademyLesson> {
  return apiFetch<AcademyLesson>(
    `${BASE}/${encodeURIComponent(courseId)}/lessons`,
    { method: 'POST', body: input },
  );
}

export function updateAcademyLesson(
  courseId: string,
  lessonId: string,
  input: AcademyLessonInput,
): Promise<AcademyLesson> {
  return apiFetch<AcademyLesson>(
    `${BASE}/${encodeURIComponent(courseId)}/lessons/${encodeURIComponent(lessonId)}`,
    { method: 'PATCH', body: input },
  );
}

export async function deleteAcademyLesson(
  courseId: string,
  lessonId: string,
): Promise<void> {
  await apiFetch(
    `${BASE}/${encodeURIComponent(courseId)}/lessons/${encodeURIComponent(lessonId)}`,
    { method: 'DELETE' },
  );
}

export function reorderAcademyLessons(
  courseId: string,
  lessonIds: string[],
): Promise<AcademyCourseDetail> {
  return apiFetch<AcademyCourseDetail>(
    `${BASE}/${encodeURIComponent(courseId)}/lessons/order`,
    { method: 'PUT', body: { lessonIds } },
  );
}
