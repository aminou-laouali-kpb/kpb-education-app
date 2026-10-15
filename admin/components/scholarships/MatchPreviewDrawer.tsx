'use client';

import { CSSProperties, useEffect, useRef, useState } from 'react';

import { fill } from '../../lib/scholarship-opening';
import {
  EMPTY_PREVIEW_FORM,
  previewBody,
  type PreviewForm,
} from '../../lib/scholarship-eligibility';
import {
  loadEligibilityOptionsOnce,
  postMatchPreview,
} from '../../lib/scholarship-eligibility-api';
import {
  DIPLOMAS,
  ELIGIBLE_LEVELS,
  EXPERIENCE_BANDS,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  LANGUAGE_TEST_TYPES,
  type EligibilityCountryOption,
  type MatchPreviewEntry,
  type MatchPreviewPoint,
  type MatchPreviewResponse,
  type MatchStatus,
} from '../../lib/scholarship-eligibility-types';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, Field, Input, Modal, Select } from '../ui';
import type { BadgeVariant } from '../ui';

const P = 'scholarships.eligibility.preview';

const STATUS_VARIANT: Record<MatchStatus, BadgeVariant> = {
  eligible: 'success',
  to_verify: 'warning',
  not_eligible: 'danger',
  suspended: 'danger',
  not_analyzed: 'neutral',
};

type Translate = (key: string) => string;

/**
 * « Tester un profil » : un profil saisi par l'équipe, passé au moteur du test
 * « Mes 10 bourses » (`POST /admin/scholarships/match-preview`). Rien n'est
 * enregistré. Les résultats montrent ce que l'élève verrait (jusqu'à 10
 * bourses), puis ce qu'il ne verrait pas : exclusions avec leurs motifs et
 * fiches non analysées.
 */
export function MatchPreviewDrawer({
  open,
  onClose,
  focusScholarshipId,
  focusName,
}: {
  open: boolean;
  onClose: () => void;
  /** La fiche en cours d'édition, évaluée à part (publique ou non). */
  focusScholarshipId?: string | null;
  focusName?: string | null;
}) {
  const { t, locale } = useLocale();
  const [form, setForm] = useState<PreviewForm>({ ...EMPTY_PREVIEW_FORM, lang: locale });
  const [countries, setCountries] = useState<EligibilityCountryOption[]>([]);
  const [useFocus, setUseFocus] = useState(true);
  const [result, setResult] = useState<MatchPreviewResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    loadEligibilityOptionsOnce()
      .then((options) => {
        if (!cancelled) setCountries(options.countries.filter((country) => country.selectable));
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [open]);

  useEffect(() => () => abortRef.current?.abort(), []);

  function patch(next: Partial<PreviewForm>) {
    setForm((current) => ({ ...current, ...next }));
  }

  async function run() {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;
    setLoading(true);
    setError(null);
    try {
      const response = await postMatchPreview(
        previewBody(form, useFocus ? focusScholarshipId : null),
        controller.signal,
      );
      setResult(response);
    } catch (exception) {
      if ((exception as { name?: string })?.name === 'AbortError') return;
      setError(exception instanceof Error ? exception.message : t(`${P}.error`));
    } finally {
      if (abortRef.current === controller) setLoading(false);
    }
  }

  const countryName = (country: EligibilityCountryOption) =>
    locale === 'en' ? country.nameEn : country.nameFr;

  const countrySelect = (key: keyof PreviewForm, label: string, optional = false) => (
    <Field label={label}>
      {({ id }) => (
        <Select
          id={id}
          value={String(form[key])}
          onChange={(event) => patch({ [key]: event.target.value } as Partial<PreviewForm>)}
        >
          <option value="">{optional ? t(`${P}.none`) : t(`${P}.choose`)}</option>
          {countries.map((country) => (
            <option key={country.code} value={country.code}>
              {countryName(country)}
            </option>
          ))}
        </Select>
      )}
    </Field>
  );

  const tokenSelect = (
    key: keyof PreviewForm,
    label: string,
    values: readonly string[],
    labelPrefix: string,
  ) => (
    <Field label={label}>
      {({ id }) => (
        <Select
          id={id}
          value={String(form[key])}
          onChange={(event) => patch({ [key]: event.target.value } as Partial<PreviewForm>)}
        >
          <option value="">{t(`${P}.choose`)}</option>
          {values.map((value) => (
            <option key={value} value={value}>
              {t(`${labelPrefix}${value}`)}
            </option>
          ))}
        </Select>
      )}
    </Field>
  );

  return (
    <Modal
      open={open}
      title={t(`${P}.title`)}
      onClose={onClose}
      size="lg"
      footer={
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <Button variant="secondary" onClick={onClose}>
            {t(`${P}.close`)}
          </Button>
          <Button loading={loading} onClick={() => void run()}>
            {t(`${P}.run`)}
          </Button>
        </div>
      }
    >
      <div style={{ display: 'grid', gap: 12 }}>
        <Alert variant="info">{t(`${P}.intro`)}</Alert>

        <div style={grid}>
          {countrySelect('nationalityCode', t(`${P}.nationality`))}
          {countrySelect('secondNationalityCode', t(`${P}.secondNationality`), true)}
          {countrySelect('countryOfResidence', t(`${P}.residence`))}
          <Field label={t(`${P}.birthDate`)}>
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={form.birthDate}
                onChange={(event) => patch({ birthDate: event.target.value })}
              />
            )}
          </Field>
          {tokenSelect(
            'scholarshipTargetLevel',
            t(`${P}.targetLevel`),
            ELIGIBLE_LEVELS,
            'scholarships.eligibility.level_',
          )}
          {tokenSelect('highestDiploma', t(`${P}.diploma`), DIPLOMAS, `${P}.diploma_`)}
          {tokenSelect('gradeBandOn20', t(`${P}.grade`), GRADE_BANDS, `${P}.grade_`)}
          {tokenSelect('englishLevel', t(`${P}.english`), LANGUAGE_BANDS, `${P}.languageBand_`)}
          {tokenSelect('frenchLevel', t(`${P}.french`), LANGUAGE_BANDS, `${P}.languageBand_`)}
          {tokenSelect(
            'workExperienceBand',
            t(`${P}.experience`),
            EXPERIENCE_BANDS,
            `${P}.experience_`,
          )}
          <Field label={t(`${P}.fields`)}>
            {({ id }) => (
              <Input
                id={id}
                value={form.fieldIds}
                placeholder="engineering, health"
                onChange={(event) => patch({ fieldIds: event.target.value })}
              />
            )}
          </Field>
          <Field label={t(`${P}.destinations`)}>
            {({ id }) => (
              <Input
                id={id}
                value={form.targetCountryIds}
                placeholder="fra, can"
                onChange={(event) => patch({ targetCountryIds: event.target.value })}
              />
            )}
          </Field>
          <Field label={t(`${P}.testType`)}>
            {({ id }) => (
              <Select
                id={id}
                value={form.languageTestType}
                onChange={(event) => patch({ languageTestType: event.target.value })}
              >
                <option value="">{t(`${P}.none`)}</option>
                {LANGUAGE_TEST_TYPES.map((type) => (
                  <option key={type} value={type}>
                    {t(`scholarships.eligibility.test_${type}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t(`${P}.testScore`)}>
            {({ id }) => (
              <Input
                id={id}
                inputMode="decimal"
                value={form.languageTestScore}
                onChange={(event) => patch({ languageTestScore: event.target.value })}
              />
            )}
          </Field>
          <Field label={t(`${P}.lang`)}>
            {({ id }) => (
              <Select
                id={id}
                value={form.lang}
                onChange={(event) => patch({ lang: event.target.value === 'en' ? 'en' : 'fr' })}
              >
                <option value="fr">Français</option>
                <option value="en">English</option>
              </Select>
            )}
          </Field>
        </div>

        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <label style={checkLabel}>
            <input
              type="checkbox"
              checked={form.confirmed}
              onChange={(event) => patch({ confirmed: event.target.checked })}
            />
            {t(`${P}.confirmed`)}
          </label>
          <label style={checkLabel}>
            <input
              type="checkbox"
              checked={form.guardianConsented}
              onChange={(event) => patch({ guardianConsented: event.target.checked })}
            />
            {t(`${P}.guardian`)}
          </label>
          {focusScholarshipId ? (
            <label style={checkLabel}>
              <input
                type="checkbox"
                checked={useFocus}
                onChange={(event) => setUseFocus(event.target.checked)}
              />
              {fill(t(`${P}.focusToggle`), { name: focusName ?? focusScholarshipId })}
            </label>
          ) : null}
        </div>

        {error ? <Alert variant="danger">{error}</Alert> : null}
        {result ? <PreviewResults result={result} t={t} /> : null}
      </div>
    </Modal>
  );
}

function PreviewResults({ result, t }: { result: MatchPreviewResponse; t: Translate }) {
  return (
    <div style={{ display: 'grid', gap: 12 }} aria-live="polite">
      <p style={summaryText}>
        {fill(t(`${P}.summary`), {
          candidates: result.counts.candidateCount,
          eligible: result.counts.eligibleCount,
          toVerify: result.counts.toVerifyCount,
          excluded: result.counts.excludedCount,
          notAnalyzed: result.counts.notAnalyzedCount,
        })}
      </p>
      <span style={hintText}>{t(`${P}.notPersisted`)}</span>
      {result.dropped.length > 0 ? (
        <Alert variant="warning">
          {fill(t(`${P}.dropped`), { keys: result.dropped.join(', ') })}
        </Alert>
      ) : null}
      {result.readiness.required.length > 0 ? (
        <Alert variant="info">
          {fill(t(`${P}.missing`), { keys: result.readiness.required.join(', ') })}
        </Alert>
      ) : null}

      {result.focus ? (
        <div style={{ display: 'grid', gap: 6 }}>
          <strong>
            {t(result.focus.public ? `${P}.focusPublic` : `${P}.focusNotPublic`)}
          </strong>
          <EntryCard entry={result.focus.entry} t={t} />
        </div>
      ) : null}

      <strong>{fill(t(`${P}.itemsTitle`), { count: result.items.length })}</strong>
      {result.items.length === 0 ? <span style={hintText}>{t(`${P}.noItems`)}</span> : null}
      {result.items.map((item) => (
        <EntryCard key={item.scholarshipId} entry={item} rank={item.rank} t={t} />
      ))}
      {result.beyondLimitCount > 0 ? (
        <span style={hintText}>
          {fill(t(`${P}.beyondLimit`), { count: result.beyondLimitCount })}
        </span>
      ) : null}

      {result.excluded.length > 0 ? (
        <details>
          <summary style={{ cursor: 'pointer', fontWeight: 700 }}>
            {fill(t(`${P}.excludedTitle`), { count: result.excluded.length })}
          </summary>
          <div style={{ display: 'grid', gap: 8, marginTop: 8 }}>
            {result.excluded.map((entry) => (
              <EntryCard key={entry.scholarshipId} entry={entry} t={t} />
            ))}
          </div>
        </details>
      ) : null}

      {result.notAnalyzed.length > 0 ? (
        <details>
          <summary style={{ cursor: 'pointer', fontWeight: 700 }}>
            {fill(t(`${P}.notAnalyzedTitle`), { count: result.notAnalyzed.length })}
          </summary>
          <ul style={{ margin: '8px 0 0', paddingLeft: 18, fontSize: 'var(--text-sm)' }}>
            {result.notAnalyzed.map((item) => (
              <li key={item.scholarshipId}>{item.name}</li>
            ))}
          </ul>
        </details>
      ) : null}
    </div>
  );
}

function EntryCard({
  entry,
  rank,
  t,
}: {
  entry: MatchPreviewEntry;
  rank?: number;
  t: Translate;
}) {
  return (
    <div style={cardStyle}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
        <strong style={{ fontSize: 'var(--text-sm)' }}>
          {rank ? `${rank}. ` : ''}
          {entry.name}
        </strong>
        <Badge variant={STATUS_VARIANT[entry.status]}>{t(`${P}.status_${entry.status}`)}</Badge>
      </div>
      <PointList points={entry.exclusions} marker="✗" />
      <PointList points={entry.reasons} marker="✓" />
      <PointList points={entry.toVerify} marker="⚠" />
      {entry.ignoredCriteria.length > 0 ? (
        <span style={hintText}>
          {fill(t(`${P}.ignoredCriteria`), { keys: entry.ignoredCriteria.join(', ') })}
        </span>
      ) : null}
    </div>
  );
}

function PointList({ points, marker }: { points: MatchPreviewPoint[]; marker: string }) {
  if (points.length === 0) return null;
  return (
    <ul style={{ margin: 0, paddingLeft: 0, listStyle: 'none', display: 'grid', gap: 4 }}>
      {points.map((point, index) => (
        <li key={`${point.code}-${point.criterionKey ?? ''}-${index}`} style={{ fontSize: 'var(--text-sm)' }}>
          <span aria-hidden="true">{marker} </span>
          {point.label}
          {point.officialText ? (
            <span style={quoteText}>
              {' '}
              « {point.officialText} »
              {point.sourceUrl ? (
                <>
                  {' '}
                  <a href={point.sourceUrl} target="_blank" rel="noreferrer">
                    ↗
                  </a>
                </>
              ) : null}
            </span>
          ) : null}
        </li>
      ))}
    </ul>
  );
}

const grid: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
  gap: 10,
};

const cardStyle: CSSProperties = {
  display: 'grid',
  gap: 6,
  padding: 10,
  border: '1px solid var(--border-soft)',
  borderRadius: 12,
  background: 'var(--bg)',
};

const checkLabel: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  fontSize: 'var(--text-sm)',
};

const summaryText: CSSProperties = { margin: 0, fontSize: 'var(--text-sm)', fontWeight: 700 };
const hintText: CSSProperties = { color: 'var(--text-muted)', fontSize: 'var(--text-xs)' };
const quoteText: CSSProperties = { color: 'var(--text-muted)', fontStyle: 'italic' };
