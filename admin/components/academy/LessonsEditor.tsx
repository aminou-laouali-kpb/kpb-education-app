'use client';
/* eslint-disable @next/next/no-img-element -- YouTube thumbnails are remote admin previews. */

import { CSSProperties, FormEvent, useEffect, useMemo, useState } from 'react';

import {
  ACADEMY_STATUSES,
  AcademyDraftError,
  EMPTY_LESSON_DRAFT,
  formatDuration,
  lessonToDraft,
  moveLesson,
  parseDuration,
  parseYoutubeId,
  toLessonInput,
  type AcademyCourseDetail,
  type AcademyLesson,
  type AcademyStatus,
  type LessonDraft,
} from '../../lib/academy';
import {
  createAcademyLesson,
  deleteAcademyLesson,
  reorderAcademyLessons,
  updateAcademyLesson,
} from '../../lib/academy-api';
import { fill } from '../../lib/scholarship-opening';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, ConfirmDialog, Field, Input, Select } from '../ui';

const rowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: 10,
  border: '1px solid var(--border-soft)',
  borderRadius: 12,
  background: 'var(--bg)',
  flexWrap: 'wrap',
};

const formStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  padding: 12,
  border: '1px solid var(--border)',
  borderRadius: 12,
};

function messageOf(error: unknown, fallback: string): string {
  if (error instanceof AcademyDraftError) return error.message;
  if (error instanceof Error) return error.message;
  return fallback;
}

/**
 * Leçons d'un cours : liste ordonnée (ordre = ordre de lecture dans l'app),
 * statut en ligne, déplacement d'un cran, ajout et modification.
 */
export function LessonsEditor({
  course,
  onCourseChanged,
  onReload,
  onStatus,
}: {
  course: AcademyCourseDetail;
  /** Le serveur a rendu le cours complet (réordonnancement). */
  onCourseChanged: (course: AcademyCourseDetail) => void;
  /** Recharger le cours et la liste après une écriture de leçon. */
  onReload: () => Promise<void>;
  onStatus: (message: string) => void;
}) {
  const { t } = useLocale();
  const [draft, setDraft] = useState<LessonDraft>(EMPTY_LESSON_DRAFT);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState<AcademyLesson | null>(null);
  const parsedId = useMemo(() => parseYoutubeId(draft.url), [draft.url]);
  const durationInvalid = draft.duration.trim() !== '' && parseDuration(draft.duration) === null;

  useEffect(() => {
    setDraft(EMPTY_LESSON_DRAFT);
    setEditingId(null);
    setError(null);
  }, [course.id]);

  function patch(next: Partial<LessonDraft>) {
    setDraft((current) => ({ ...current, ...next }));
  }

  async function run(action: () => Promise<void>, ok: string) {
    setPending(true);
    setError(null);
    try {
      await action();
      onStatus(ok);
    } catch (exception) {
      setError(messageOf(exception, t('academy.saveError')));
    } finally {
      setPending(false);
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    const editing = editingId;
    void run(async () => {
      const input = toLessonInput(draft, editing ? 'edit' : 'create');
      if (editing) await updateAcademyLesson(course.id, editing, input);
      else await createAcademyLesson(course.id, input);
      setDraft(EMPTY_LESSON_DRAFT);
      setEditingId(null);
      await onReload();
    }, editing ? t('academy.lessonSaved') : t('academy.lessonAdded'));
  }

  function changeStatus(lesson: AcademyLesson, status: AcademyStatus) {
    if (lesson.status === status) return;
    void run(async () => {
      await updateAcademyLesson(course.id, lesson.id, { status });
      await onReload();
    }, t('academy.lessonSaved'));
  }

  function move(index: number, delta: -1 | 1) {
    const next = moveLesson(
      course.lessons.map((lesson) => lesson.id),
      index,
      delta,
    );
    if (!next) return;
    void run(async () => {
      onCourseChanged(await reorderAcademyLessons(course.id, next));
    }, t('academy.orderSaved'));
  }

  return (
    <section style={{ display: 'grid', gap: 12 }}>
      <div>
        <h4 style={{ margin: 0 }}>
          {fill(t('academy.lessonsTitle'), { n: course.lessons.length })}
        </h4>
        <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
          {t('academy.lessonsHint')}
        </p>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}

      {course.lessons.length === 0 ? (
        <p style={{ margin: 0, color: 'var(--text-muted)' }}>{t('academy.noLessons')}</p>
      ) : null}

      {course.lessons.map((lesson, index) => (
        <div key={lesson.id} style={rowStyle}>
          <span style={{ fontVariantNumeric: 'tabular-nums', minWidth: 28, color: 'var(--text-muted)' }}>
            #{lesson.order}
          </span>
          {lesson.thumbnailUrl ? (
            <img
              src={lesson.thumbnailUrl}
              alt=""
              width={112}
              height={63}
              loading="lazy"
              style={{ objectFit: 'cover', borderRadius: 8 }}
            />
          ) : null}
          <div style={{ flex: 1, minWidth: 180 }}>
            <a href={lesson.watchUrl} target="_blank" rel="noreferrer" style={{ fontWeight: 600 }}>
              {lesson.titleFr}
            </a>
            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--text-xs)' }}>
              {lesson.titleEn !== lesson.titleFr ? `${lesson.titleEn} · ` : ''}
              {formatDuration(lesson.durationSeconds)}
              {lesson.youtubeVideoId ? null : ` · ${t('academy.legacyVideoUrl')}`}
            </div>
          </div>
          {lesson.status !== 'published' ? (
            <Badge variant="warning">{t('academy.lessonHiddenBadge')}</Badge>
          ) : null}
          {course.requiresPass ? (
            <Badge variant={lesson.isFreePreview ? 'success' : 'brand'}>
              {lesson.isFreePreview ? t('academy.freePreviewBadge') : t('academy.passOnlyBadge')}
            </Badge>
          ) : null}
          <Select
            aria-label={t('academy.statusLabel')}
            value={lesson.status}
            disabled={pending}
            onChange={(event) => changeStatus(lesson, event.target.value as AcademyStatus)}
            style={{ width: 130 }}
          >
            {ACADEMY_STATUSES.map((status) => (
              <option key={status} value={status}>
                {t(`academy.status.${status}`)}
              </option>
            ))}
          </Select>
          <div style={{ display: 'flex', gap: 4 }}>
            <Button
              size="sm"
              variant="ghost"
              aria-label={t('academy.moveUp')}
              title={t('academy.moveUp')}
              disabled={pending || index === 0}
              onClick={() => move(index, -1)}
            >
              ↑
            </Button>
            <Button
              size="sm"
              variant="ghost"
              aria-label={t('academy.moveDown')}
              title={t('academy.moveDown')}
              disabled={pending || index === course.lessons.length - 1}
              onClick={() => move(index, 1)}
            >
              ↓
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={pending}
              onClick={() => {
                setEditingId(lesson.id);
                setDraft(lessonToDraft(lesson));
                setError(null);
              }}
            >
              {t('academy.editCta')}
            </Button>
            <Button
              size="sm"
              variant="dangerOutline"
              disabled={pending}
              onClick={() => setConfirming(lesson)}
            >
              {t('academy.deleteCta')}
            </Button>
          </div>
        </div>
      ))}

      <form style={formStyle} onSubmit={submit}>
        <strong>
          {editingId ? t('academy.editLessonTitle') : t('academy.addLessonTitle')}
        </strong>
        <Field
          label={t('academy.youtubeUrlLabel')}
          error={draft.url.trim() && !parsedId ? t('academy.youtubeUrlInvalid') : undefined}
        >
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              required
              value={draft.url}
              placeholder="https://youtu.be/…"
              onChange={(event) => patch({ url: event.target.value })}
            />
          )}
        </Field>
        {parsedId ? (
          <iframe
            title={t('academy.previewTitle')}
            src={`https://www.youtube-nocookie.com/embed/${parsedId}`}
            loading="lazy"
            allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            style={{ width: '100%', maxWidth: 480, aspectRatio: '16 / 9', border: 0, borderRadius: 12 }}
          />
        ) : null}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
          <Field label={t('academy.lessonTitleFrLabel')}>
            {({ id }) => (
              <Input
                id={id}
                required
                maxLength={200}
                value={draft.titleFr}
                onChange={(event) => patch({ titleFr: event.target.value })}
              />
            )}
          </Field>
          <Field label={t('academy.lessonTitleEnLabel')}>
            {({ id }) => (
              <Input
                id={id}
                maxLength={200}
                value={draft.titleEn}
                onChange={(event) => patch({ titleEn: event.target.value })}
              />
            )}
          </Field>
          <Field
            label={t('academy.durationLabel')}
            error={durationInvalid ? t('academy.durationInvalid') : undefined}
          >
            {({ id, invalid }) => (
              <Input
                id={id}
                invalid={invalid}
                required
                value={draft.duration}
                placeholder="4:05"
                onChange={(event) => patch({ duration: event.target.value })}
              />
            )}
          </Field>
          <Field label={t('academy.statusLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={draft.status}
                onChange={(event) => patch({ status: event.target.value as AcademyStatus })}
              >
                {ACADEMY_STATUSES.map((status) => (
                  <option key={status} value={status}>
                    {t(`academy.status.${status}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </div>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.isFreePreview}
            onChange={(event) => patch({ isFreePreview: event.target.checked })}
          />
          {t('academy.freePreviewLabel')}
        </label>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button type="submit" loading={pending}>
            {editingId ? t('academy.updateLessonCta') : t('academy.addLessonCta')}
          </Button>
          {editingId ? (
            <Button
              type="button"
              variant="ghost"
              disabled={pending}
              onClick={() => {
                setEditingId(null);
                setDraft(EMPTY_LESSON_DRAFT);
              }}
            >
              {t('academy.cancelCta')}
            </Button>
          ) : null}
        </div>
      </form>

      {confirming ? (
        <ConfirmDialog
          open
          title={fill(t('academy.confirmDeleteLessonTitle'), { name: confirming.titleFr })}
          description={t('academy.confirmDeleteLessonBody')}
          confirmLabel={t('academy.deleteCta')}
          cancelLabel={t('academy.cancelCta')}
          onCancel={() => setConfirming(null)}
          onConfirm={() => {
            const target = confirming;
            setConfirming(null);
            void run(async () => {
              await deleteAcademyLesson(course.id, target.id);
              if (editingId === target.id) {
                setEditingId(null);
                setDraft(EMPTY_LESSON_DRAFT);
              }
              await onReload();
            }, t('academy.lessonDeleted'));
          }}
        />
      ) : null}
    </section>
  );
}
