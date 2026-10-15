'use client';

import { CSSProperties, useEffect, useMemo, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
import { useLocale } from '../locale-provider';
import { Alert, Button, Field, Input, Textarea } from '../ui';
import { ScholarshipEligibilityEditor } from './ScholarshipEligibilityEditor';
import type { ScholarshipEntry } from './types';

type EditableKey =
  | 'nameFr'
  | 'nameEn'
  | 'countryId'
  | 'countryNameFr'
  | 'countryNameEn'
  | 'levelEligibleFr'
  | 'levelEligibleEn'
  | 'typeOfFundingFr'
  | 'typeOfFundingEn'
  | 'descriptionFr'
  | 'descriptionEn'
  | 'advantagesFr'
  | 'advantagesEn'
  | 'eligibilityFr'
  | 'eligibilityEn'
  | 'applicationUrl'
  | 'sourceUrl'
  | 'tags'
  | 'relatedFieldIds';

type Draft = Record<EditableKey, string>;

function joinLines(value: string[] | undefined): string {
  return (value ?? []).join('\n');
}

function splitLines(value: string): string[] {
  return value
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function draftFrom(entry: ScholarshipEntry): Draft {
  return {
    nameFr: entry.nameFr ?? '',
    nameEn: entry.nameEn ?? '',
    countryId: entry.countryId ?? '',
    countryNameFr: entry.countryNameFr ?? '',
    countryNameEn: entry.countryNameEn ?? '',
    levelEligibleFr: entry.levelEligibleFr ?? '',
    levelEligibleEn: entry.levelEligibleEn ?? '',
    typeOfFundingFr: entry.typeOfFundingFr ?? '',
    typeOfFundingEn: entry.typeOfFundingEn ?? '',
    descriptionFr: entry.descriptionFr ?? '',
    descriptionEn: entry.descriptionEn ?? '',
    advantagesFr: joinLines(entry.advantagesFr),
    advantagesEn: joinLines(entry.advantagesEn),
    eligibilityFr: joinLines(entry.eligibilityFr),
    eligibilityEn: joinLines(entry.eligibilityEn),
    applicationUrl: entry.applicationUrl ?? '',
    sourceUrl: entry.sourceUrl ?? '',
    tags: joinLines(entry.tags),
    relatedFieldIds: joinLines(entry.relatedFieldIds),
  };
}

const ARRAY_KEYS = new Set<EditableKey>([
  'advantagesFr',
  'advantagesEn',
  'eligibilityFr',
  'eligibilityEn',
  'tags',
  'relatedFieldIds',
]);

export function ScholarshipContentEditor({
  entry,
  onSaved,
}: {
  entry: ScholarshipEntry;
  onSaved: (patch: Partial<ScholarshipEntry>) => void;
}) {
  const { t } = useLocale();
  const [draft, setDraft] = useState<Draft>(() => draftFrom(entry));
  const [dirty, setDirty] = useState<Set<EditableKey>>(new Set());
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const contentHydrated = useMemo(
    () => Object.prototype.hasOwnProperty.call(entry, 'descriptionFr'),
    [entry],
  );

  // Réinitialise le brouillon quand la fiche ou SES champs changent — pas
  // quand une autre partie de la fiche est modifiée (éligibilité structurée,
  // vidéos…) : une saisie en cours ne doit pas disparaître pour autant.
  const draftKey = JSON.stringify([entry.id, draftFrom(entry)]);
  useEffect(() => {
    setDraft(draftFrom(entry));
    setDirty(new Set());
    setMessage(null);
    setError(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draftKey]);

  function patch(key: EditableKey, value: string) {
    setDraft((current) => ({ ...current, [key]: value }));
    setDirty((current) => new Set(current).add(key));
  }

  async function save() {
    if (dirty.size === 0) return;
    const body: Record<string, unknown> = {};
    for (const key of dirty) {
      body[key] = ARRAY_KEYS.has(key) ? splitLines(draft[key]) : draft[key].trim();
    }
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      await apiFetch(`/admin/catalog/scholarships/${entry.id}`, {
        method: 'PATCH',
        body,
      });
      onSaved(body as Partial<ScholarshipEntry>);
      setDirty(new Set());
      setMessage(t('scholarships.editorSaved'));
    } catch (exception) {
      setError(
        exception instanceof Error
          ? exception.message
          : t('scholarships.editorSaveError'),
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <section style={{ display: 'grid', gap: 12 }}>
      <h4 style={{ margin: 0 }}>{t('scholarships.editorTitle')}</h4>
      {!contentHydrated ? (
        <Alert variant="warning">
          {t('scholarships.editorPartialDataWarning')}
        </Alert>
      ) : null}
      {message ? <Alert variant="success">{message}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}

      <div style={twoColumns}>
        <TextField label={t('scholarships.nameFrLabel')} value={draft.nameFr} onChange={(v) => patch('nameFr', v)} />
        <TextField label={t('scholarships.nameEnLabel')} value={draft.nameEn} onChange={(v) => patch('nameEn', v)} />
        <TextField label={t('scholarships.countryIdLabel')} value={draft.countryId} onChange={(v) => patch('countryId', v)} />
        <TextField label={t('scholarships.countryNameFrLabel')} value={draft.countryNameFr} onChange={(v) => patch('countryNameFr', v)} />
        <TextField label={t('scholarships.countryNameEnLabel')} value={draft.countryNameEn} onChange={(v) => patch('countryNameEn', v)} />
        <TextField label={t('scholarships.levelFrLabel')} value={draft.levelEligibleFr} onChange={(v) => patch('levelEligibleFr', v)} />
        <TextField label={t('scholarships.levelEnLabel')} value={draft.levelEligibleEn} onChange={(v) => patch('levelEligibleEn', v)} />
        <TextField label={t('scholarships.fundingFrLabel')} value={draft.typeOfFundingFr} onChange={(v) => patch('typeOfFundingFr', v)} />
        <TextField label={t('scholarships.fundingEnLabel')} value={draft.typeOfFundingEn} onChange={(v) => patch('typeOfFundingEn', v)} />
      </div>

      <div style={twoColumns}>
        <LongField label={t('scholarships.descriptionFrLabel')} value={draft.descriptionFr} onChange={(v) => patch('descriptionFr', v)} />
        <LongField label={t('scholarships.descriptionEnLabel')} value={draft.descriptionEn} onChange={(v) => patch('descriptionEn', v)} />
        <LongField label={t('scholarships.eligibilityFrLabel')} value={draft.eligibilityFr} onChange={(v) => patch('eligibilityFr', v)} hint={t('scholarships.onePerLineHint')} />
        <LongField label={t('scholarships.eligibilityEnLabel')} value={draft.eligibilityEn} onChange={(v) => patch('eligibilityEn', v)} hint={t('scholarships.onePerLineHint')} />
      </div>

      {/* L'éligibilité structurée vit à côté de sa version en texte libre :
          le test « Mes 10 bourses » lit celle-ci, l'élève lit celle-là. */}
      <ScholarshipEligibilityEditor entry={entry} onSaved={onSaved} />

      <div style={twoColumns}>
        <LongField label={t('scholarships.advantagesFrLabel')} value={draft.advantagesFr} onChange={(v) => patch('advantagesFr', v)} hint={t('scholarships.onePerLineHint')} />
        <LongField label={t('scholarships.advantagesEnLabel')} value={draft.advantagesEn} onChange={(v) => patch('advantagesEn', v)} hint={t('scholarships.onePerLineHint')} />
      </div>

      <div style={twoColumns}>
        <TextField type="url" label={t('scholarships.applicationUrlLabel')} value={draft.applicationUrl} onChange={(v) => patch('applicationUrl', v)} />
        <TextField type="url" label={t('scholarships.sourceLabel')} value={draft.sourceUrl} onChange={(v) => patch('sourceUrl', v)} />
        <LongField label={t('scholarships.tagsLabel')} value={draft.tags} onChange={(v) => patch('tags', v)} hint={t('scholarships.onePerLineHint')} />
        <LongField label={t('scholarships.fieldsLabel')} value={draft.relatedFieldIds} onChange={(v) => patch('relatedFieldIds', v)} hint={t('scholarships.onePerLineHint')} />
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <Button onClick={save} loading={saving} disabled={dirty.size === 0}>
          {t('scholarships.saveContentCta')}
        </Button>
      </div>
    </section>
  );
}

const twoColumns: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
  gap: 10,
};

function TextField({
  label,
  value,
  onChange,
  type,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
}) {
  return (
    <Field label={label}>
      {({ id }) => (
        <Input id={id} type={type} value={value} onChange={(event) => onChange(event.target.value)} />
      )}
    </Field>
  );
}

function LongField({
  label,
  value,
  onChange,
  hint,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  hint?: string;
}) {
  return (
    <div style={{ display: 'grid', gap: 4 }}>
      <Field label={label}>
        {({ id }) => (
          <Textarea id={id} rows={5} value={value} onChange={(event) => onChange(event.target.value)} />
        )}
      </Field>
      {hint ? (
        <span style={{ color: 'var(--text-muted)', fontSize: 'var(--text-xs)' }}>
          {hint}
        </span>
      ) : null}
    </div>
  );
}
