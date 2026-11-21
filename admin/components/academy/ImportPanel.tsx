'use client';

import { CSSProperties, useState } from 'react';

import {
  formatDuration,
  parseManifest,
  type AcademyImportReport,
  type ParsedManifest,
} from '../../lib/academy';
import { importAcademyCourse } from '../../lib/academy-api';
import { fill } from '../../lib/scholarship-opening';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, Field, Textarea } from '../ui';

const panelStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 16,
  border: '1px solid var(--border)',
  borderRadius: 12,
  background: 'var(--surface)',
  marginBottom: 16,
};

const listStyle: CSSProperties = {
  margin: 0,
  paddingLeft: 18,
  display: 'grid',
  gap: 4,
  fontSize: 'var(--text-sm)',
};

type ImportOutcome =
  | { slug: string; report: AcademyImportReport }
  | { slug: string; error: string };

/**
 * Import du `manifest.json` (HyperFrames) complété des liens YouTube.
 *
 * Deux temps : « Vérifier » lit le JSON dans le navigateur et liste tout ce qui
 * bloquerait ; « Importer » n'apparaît que si rien ne bloque, et envoie les
 * modules un par un (un module = un cours, une transaction côté serveur).
 */
export function ImportPanel({
  onImported,
  onClose,
}: {
  onImported: () => Promise<void>;
  onClose: () => void;
}) {
  const { t } = useLocale();
  const [raw, setRaw] = useState('');
  const [parsed, setParsed] = useState<ParsedManifest | null>(null);
  const [pending, setPending] = useState(false);
  const [outcomes, setOutcomes] = useState<ImportOutcome[]>([]);

  const ready = parsed !== null && parsed.problems.length === 0 && parsed.courses.length > 0;

  async function runImport() {
    if (!parsed || !ready) return;
    setPending(true);
    const results: ImportOutcome[] = [];
    // Séquentiel : un rapport par cours, dans l'ordre du manifeste ; un échec
    // n'empêche pas les modules suivants (chacun est sa propre transaction).
    for (const course of parsed.courses) {
      try {
        results.push({ slug: course.slug, report: await importAcademyCourse(course) });
      } catch (error) {
        results.push({
          slug: course.slug,
          error: error instanceof Error ? error.message : t('academy.saveError'),
        });
      }
      setOutcomes([...results]);
    }
    setPending(false);
    await onImported();
  }

  return (
    <section style={panelStyle} aria-labelledby="academy-import-title">
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'baseline' }}>
        <h3 id="academy-import-title" style={{ margin: 0 }}>
          {t('academy.import.title')}
        </h3>
        <Button variant="ghost" size="sm" disabled={pending} onClick={onClose}>
          {t('academy.closeCta')}
        </Button>
      </div>
      <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
        {t('academy.import.hint')}
      </p>
      <Field label={t('academy.import.jsonLabel')}>
        {({ id }) => (
          <Textarea
            id={id}
            rows={12}
            spellCheck={false}
            value={raw}
            placeholder={t('academy.import.placeholder')}
            style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 'var(--text-xs)' }}
            onChange={(event) => {
              setRaw(event.target.value);
              setParsed(null);
              setOutcomes([]);
            }}
          />
        )}
      </Field>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <Button
          variant="secondary"
          disabled={pending || raw.trim() === ''}
          onClick={() => {
            setParsed(parseManifest(raw));
            setOutcomes([]);
          }}
        >
          {t('academy.import.checkCta')}
        </Button>
        {ready ? (
          <Button loading={pending} onClick={() => void runImport()}>
            {fill(t('academy.import.runCta'), { n: parsed.courses.length })}
          </Button>
        ) : null}
      </div>

      {parsed && parsed.problems.length > 0 ? (
        <Alert variant="danger">
          <strong>{fill(t('academy.import.problemsTitle'), { n: parsed.problems.length })}</strong>
          <ul style={listStyle}>
            {parsed.problems.map((problem) => (
              <li key={problem}>{problem}</li>
            ))}
          </ul>
        </Alert>
      ) : null}

      {ready && outcomes.length === 0 ? (
        <div style={{ display: 'grid', gap: 6 }}>
          <strong>{t('academy.import.previewTitle')}</strong>
          <ul style={listStyle}>
            {parsed.courses.map((course) => (
              <li key={course.slug}>
                <code>{course.slug}</code> — {course.titleFr} ·{' '}
                {fill(t('academy.import.lessonsCount'), {
                  n: course.lessons.length,
                  duration: formatDuration(
                    course.lessons.reduce((total, lesson) => total + lesson.durationSeconds, 0),
                  ),
                })}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {outcomes.length > 0 ? (
        <div style={{ display: 'grid', gap: 8 }}>
          <strong>{t('academy.import.reportTitle')}</strong>
          {outcomes.map((outcome) =>
            'error' in outcome ? (
              <Alert key={outcome.slug} variant="danger">
                <code>{outcome.slug}</code> — {outcome.error}
              </Alert>
            ) : (
              <div key={outcome.slug} style={{ display: 'grid', gap: 4 }}>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                  <code>{outcome.slug}</code>
                  <Badge variant={outcome.report.course.created ? 'info' : 'neutral'}>
                    {outcome.report.course.created
                      ? t('academy.import.courseCreated')
                      : outcome.report.course.updated
                        ? t('academy.import.courseUpdated')
                        : t('academy.import.courseUnchanged')}
                  </Badge>
                  <span style={{ fontSize: 'var(--text-sm)' }}>
                    {fill(t('academy.import.lessonsReport'), outcome.report.lessons)}
                  </span>
                </div>
                {outcome.report.notInManifest.length > 0 ? (
                  <Alert variant="warning">
                    {fill(t('academy.import.notInManifest'), {
                      n: outcome.report.notInManifest.length,
                    })}
                    <ul style={listStyle}>
                      {outcome.report.notInManifest.map((lesson) => (
                        <li key={lesson.id}>
                          #{lesson.order} {lesson.titleFr} ({t(`academy.status.${lesson.status}`)})
                        </li>
                      ))}
                    </ul>
                  </Alert>
                ) : null}
              </div>
            ),
          )}
          {outcomes.some((outcome) => 'report' in outcome && outcome.report.course.status !== 'published') ? (
            <Alert variant="info">{t('academy.import.draftReminder')}</Alert>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
