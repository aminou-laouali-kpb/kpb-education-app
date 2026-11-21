'use client';

import { CSSProperties, FormEvent, useState } from 'react';

import { ACADEMY_STATUSES, slugify, type AcademyStatus, type CourseDraft } from '../../lib/academy';
import { useLocale } from '../locale-provider';
import { Button, Field, Input, Select, Textarea } from '../ui';

const gridStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
  gap: 10,
};

const formStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 16,
  border: '1px solid var(--border)',
  borderRadius: 12,
  background: 'var(--surface)',
  marginBottom: 16,
};

const hintStyle: CSSProperties = {
  margin: 0,
  color: 'var(--text-muted)',
  fontSize: 'var(--text-sm)',
};

/**
 * Formulaire d'un cours. En création, l'identifiant suit le titre tant qu'on
 * ne l'a pas modifié à la main ; en édition il ne bouge que si on le touche
 * (il sert de clé aux imports suivants).
 */
export function CourseForm({
  draft,
  mode,
  pending,
  onChange,
  onSubmit,
  onCancel,
}: {
  draft: CourseDraft;
  mode: 'create' | 'edit';
  pending: boolean;
  onChange: (patch: Partial<CourseDraft>) => void;
  onSubmit: () => void;
  onCancel: () => void;
}) {
  const { t } = useLocale();
  const [slugTouched, setSlugTouched] = useState(mode === 'edit');

  function submit(event: FormEvent) {
    event.preventDefault();
    onSubmit();
  }

  return (
    <form style={formStyle} onSubmit={submit}>
      <h3 style={{ margin: 0 }}>
        {mode === 'create' ? t('academy.newCourseTitle') : t('academy.editCourseTitle')}
      </h3>
      <div style={gridStyle}>
        <Field label={t('academy.titleFrLabel')}>
          {({ id }) => (
            <Input
              id={id}
              required
              maxLength={200}
              value={draft.titleFr}
              onChange={(event) => {
                const titleFr = event.target.value;
                onChange(
                  slugTouched ? { titleFr } : { titleFr, slug: slugify(titleFr) },
                );
              }}
            />
          )}
        </Field>
        <Field label={t('academy.titleEnLabel')}>
          {({ id }) => (
            <Input
              id={id}
              maxLength={200}
              value={draft.titleEn}
              onChange={(event) => onChange({ titleEn: event.target.value })}
            />
          )}
        </Field>
        <Field label={t('academy.slugLabel')}>
          {({ id }) => (
            <Input
              id={id}
              required
              maxLength={80}
              value={draft.slug}
              placeholder="hsk-1"
              onChange={(event) => {
                setSlugTouched(true);
                onChange({ slug: event.target.value });
              }}
            />
          )}
        </Field>
        <Field label={t('academy.statusLabel')}>
          {({ id }) => (
            <Select
              id={id}
              value={draft.status}
              onChange={(event) =>
                onChange({ status: event.target.value as AcademyStatus })
              }
            >
              {ACADEMY_STATUSES.map((status) => (
                <option key={status} value={status}>
                  {t(`academy.status.${status}`)}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label={t('academy.displayOrderLabel')}>
          {({ id }) => (
            <Input
              id={id}
              type="number"
              min={0}
              max={1000}
              value={draft.displayOrder}
              onChange={(event) => onChange({ displayOrder: event.target.value })}
            />
          )}
        </Field>
        <Field label={t('academy.coverLabel')}>
          {({ id }) => (
            <Input
              id={id}
              type="url"
              value={draft.coverImageUrl}
              placeholder="https://…"
              onChange={(event) => onChange({ coverImageUrl: event.target.value })}
            />
          )}
        </Field>
      </div>
      <p style={hintStyle}>{t('academy.slugHint')}</p>
      <div style={{ ...gridStyle, gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))' }}>
        <Field label={t('academy.descriptionFrLabel')}>
          {({ id }) => (
            <Textarea
              id={id}
              rows={4}
              maxLength={4000}
              value={draft.descriptionFr}
              onChange={(event) => onChange({ descriptionFr: event.target.value })}
            />
          )}
        </Field>
        <Field label={t('academy.descriptionEnLabel')}>
          {({ id }) => (
            <Textarea
              id={id}
              rows={4}
              maxLength={4000}
              value={draft.descriptionEn}
              onChange={(event) => onChange({ descriptionEn: event.target.value })}
            />
          )}
        </Field>
      </div>
      <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <input
          type="checkbox"
          checked={draft.requiresPass}
          onChange={(event) => onChange({ requiresPass: event.target.checked })}
        />
        {t('academy.requiresPassLabel')}
      </label>
      <p style={hintStyle}>
        {t('academy.requiresPassHint')} {t('academy.coverHint')}
      </p>
      <div style={{ display: 'flex', gap: 8 }}>
        <Button type="submit" loading={pending}>
          {mode === 'create' ? t('academy.createCta') : t('academy.saveCta')}
        </Button>
        <Button type="button" variant="ghost" disabled={pending} onClick={onCancel}>
          {t('academy.cancelCta')}
        </Button>
      </div>
    </form>
  );
}
