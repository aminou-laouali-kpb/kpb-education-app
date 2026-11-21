'use client';

import { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';

import { CourseForm } from '../../components/academy/CourseForm';
import { ImportPanel } from '../../components/academy/ImportPanel';
import { LessonsEditor } from '../../components/academy/LessonsEditor';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  ConfirmDialog,
  EmptyState,
  type BadgeVariant,
} from '../../components/ui';
import {
  AcademyDraftError,
  EMPTY_COURSE_DRAFT,
  courseToDraft,
  formatDuration,
  toCourseInput,
  type AcademyCourse,
  type AcademyCourseDetail,
  type AcademyStatus,
  type CourseDraft,
} from '../../lib/academy';
import {
  createAcademyCourse,
  deleteAcademyCourse,
  fetchAcademyCourse,
  fetchAcademyCourses,
  updateAcademyCourse,
} from '../../lib/academy-api';
import { fill } from '../../lib/scholarship-opening';

const barStyle: CSSProperties = {
  display: 'flex',
  gap: 8,
  flexWrap: 'wrap',
  alignItems: 'center',
  marginBottom: 16,
};

const detailStyle: CSSProperties = {
  display: 'grid',
  gap: 16,
  marginTop: 24,
  paddingTop: 24,
  borderTop: '1px solid var(--border)',
};

const STATUS_BADGE: Record<AcademyStatus, BadgeVariant> = {
  draft: 'neutral',
  published: 'success',
  archived: 'warning',
};

function messageOf(error: unknown, fallback: string): string {
  if (error instanceof AcademyDraftError) return error.message;
  if (error instanceof Error) return error.message;
  return fallback;
}

/** Cours Academy : liste, création, import de manifeste, leçons. */
export default function AcademyPage() {
  const { t } = useLocale();
  const [courses, setCourses] = useState<AcademyCourse[]>([]);
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);

  const [creating, setCreating] = useState<CourseDraft | null>(null);
  const [importOpen, setImportOpen] = useState(false);
  const [selected, setSelected] = useState<AcademyCourseDetail | null>(null);
  const [editDraft, setEditDraft] = useState<CourseDraft | null>(null);
  const [confirming, setConfirming] = useState<AcademyCourse | null>(null);

  // Seule la réponse du DERNIER cours ouvert compte : un clic rapide sur un
  // autre cours ne doit pas être écrasé par la réponse du précédent.
  const openRequest = useRef<string | null>(null);

  const loadCourses = useCallback(async () => {
    setCourses(await fetchAcademyCourses());
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await loadCourses();
      } catch (exception) {
        if (!cancelled) setError(messageOf(exception, t('academy.loadError')));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [loadCourses, t]);

  function showCourse(detail: AcademyCourseDetail) {
    setSelected(detail);
    setEditDraft(courseToDraft(detail));
  }

  async function openCourse(id: string) {
    openRequest.current = id;
    setError(null);
    try {
      const detail = await fetchAcademyCourse(id);
      if (openRequest.current === id) showCourse(detail);
    } catch (exception) {
      setError(messageOf(exception, t('academy.loadError')));
    }
  }

  const reloadSelected = useCallback(async () => {
    if (!selected) return;
    const [detail] = await Promise.all([
      fetchAcademyCourse(selected.id),
      loadCourses(),
    ]);
    setSelected(detail);
  }, [selected, loadCourses]);

  async function run(action: () => Promise<void>, ok: string) {
    setPending(true);
    setError(null);
    setStatus(null);
    try {
      await action();
      setStatus(ok);
    } catch (exception) {
      setError(messageOf(exception, t('academy.saveError')));
    } finally {
      setPending(false);
    }
  }

  function visibility(course: AcademyCourse): { variant: BadgeVariant; label: string } {
    if (course.visibleInApp) {
      return { variant: 'info', label: t('academy.visibleBadge') };
    }
    if (course.status === 'published') {
      return { variant: 'warning', label: t('academy.publishedEmptyBadge') };
    }
    return { variant: 'neutral', label: t('academy.hiddenBadge') };
  }

  return (
    <DashboardShell title={t('academy.title')} subtitle={t('academy.subtitle')}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {status ? <Alert variant="success">{status}</Alert> : null}

      <div style={barStyle}>
        <Button
          onClick={() => {
            setImportOpen(false);
            setCreating({ ...EMPTY_COURSE_DRAFT });
          }}
        >
          {t('academy.newCourseCta')}
        </Button>
        <Button
          variant="secondary"
          onClick={() => {
            setCreating(null);
            setImportOpen(true);
          }}
        >
          {t('academy.importCta')}
        </Button>
      </div>

      {importOpen ? (
        <ImportPanel
          onImported={async () => {
            await loadCourses();
            if (selected) await reloadSelected();
          }}
          onClose={() => setImportOpen(false)}
        />
      ) : null}

      {creating ? (
        <CourseForm
          key="create"
          draft={creating}
          mode="create"
          pending={pending}
          onChange={(patch) => setCreating((draft) => (draft ? { ...draft, ...patch } : draft))}
          onCancel={() => setCreating(null)}
          onSubmit={() =>
            void run(async () => {
              const created = await createAcademyCourse(toCourseInput(creating, 'create'));
              setCreating(null);
              await loadCourses();
              showCourse(created);
            }, t('academy.courseCreated'))
          }
        />
      ) : null}

      <p style={{ margin: '0 0 12px', color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
        {t('academy.visibilityHelp')}
      </p>

      {loading ? (
        <EmptyState title={t('academy.loading')} />
      ) : courses.length === 0 ? (
        <EmptyState title={t('academy.empty')} />
      ) : (
        <AdminTable
          columns={[
            t('academy.columns.course'),
            t('academy.columns.status'),
            t('academy.columns.lessons'),
            t('academy.columns.duration'),
            t('academy.columns.actions'),
          ]}
          cols="2fr 1.4fr 1fr 1fr auto"
        >
          {courses.map((course) => {
            const seen = visibility(course);
            return (
              <AdminTableRow key={course.id}>
                <CellText primary={course.titleFr} sub={course.slug ?? '—'} />
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <Badge variant={STATUS_BADGE[course.status]}>
                    {t(`academy.status.${course.status}`)}
                  </Badge>
                  <Badge variant={seen.variant}>{seen.label}</Badge>
                  {course.requiresPass ? (
                    <Badge variant="brand">{t('academy.passOnlyBadge')}</Badge>
                  ) : null}
                </div>
                <CellText
                  primary={fill(t('academy.lessonsCount'), {
                    published: course.publishedLessonCount,
                    total: course.lessonCount,
                  })}
                />
                <CellText primary={formatDuration(course.publishedDurationSeconds)} />
                <div style={{ display: 'flex', gap: 6 }}>
                  <Button
                    size="sm"
                    variant={selected?.id === course.id ? 'secondary' : 'ghost'}
                    onClick={() => void openCourse(course.id)}
                  >
                    {t('academy.openCta')}
                  </Button>
                  <Button
                    size="sm"
                    variant="dangerOutline"
                    disabled={pending}
                    onClick={() => setConfirming(course)}
                  >
                    {t('academy.deleteCta')}
                  </Button>
                </div>
              </AdminTableRow>
            );
          })}
        </AdminTable>
      )}

      {selected && editDraft ? (
        <section style={detailStyle} aria-labelledby="academy-course-title">
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'baseline', flexWrap: 'wrap' }}>
            <h2 id="academy-course-title" style={{ margin: 0 }}>
              {selected.titleFr}
            </h2>
            <Button variant="ghost" size="sm" onClick={() => setSelected(null)}>
              {t('academy.closeCta')}
            </Button>
          </div>
          {selected.visibleInApp ? (
            <Alert variant="success">
              {fill(t('academy.visibleDetail'), { n: selected.publishedLessonCount })}
            </Alert>
          ) : selected.status === 'published' ? (
            <Alert variant="warning">{t('academy.publishedEmptyDetail')}</Alert>
          ) : (
            <Alert variant="info">{t('academy.hiddenDetail')}</Alert>
          )}
          <CourseForm
            key={selected.id}
            draft={editDraft}
            mode="edit"
            pending={pending}
            onChange={(patch) => setEditDraft((draft) => (draft ? { ...draft, ...patch } : draft))}
            onCancel={() => setEditDraft(courseToDraft(selected))}
            onSubmit={() =>
              void run(async () => {
                const saved = await updateAcademyCourse(
                  selected.id,
                  toCourseInput(editDraft, 'edit'),
                );
                showCourse(saved);
                await loadCourses();
              }, t('academy.courseSaved'))
            }
          />
          <LessonsEditor
            course={selected}
            onCourseChanged={(detail) => {
              setSelected(detail);
              void loadCourses();
            }}
            onReload={reloadSelected}
            onStatus={(message) => {
              setError(null);
              setStatus(message);
            }}
          />
        </section>
      ) : null}

      {confirming ? (
        <ConfirmDialog
          open
          title={fill(t('academy.confirmDeleteCourseTitle'), { name: confirming.titleFr })}
          description={fill(t('academy.confirmDeleteCourseBody'), { n: confirming.lessonCount })}
          confirmLabel={t('academy.deleteCta')}
          cancelLabel={t('academy.cancelCta')}
          onCancel={() => setConfirming(null)}
          onConfirm={() => {
            const target = confirming;
            setConfirming(null);
            void run(async () => {
              await deleteAcademyCourse(target.id);
              if (selected?.id === target.id) setSelected(null);
              await loadCourses();
            }, t('academy.courseDeleted'));
          }}
        />
      ) : null}
    </DashboardShell>
  );
}
