'use client';

import { CSSProperties, useEffect, useMemo, useState } from 'react';

import { fill } from '../../lib/scholarship-opening';
import {
  emptyCriterionDraft,
  eligibilityDraftFrom,
  eligibilityStateOf,
  isCatalogManaged,
  readEligibilityError,
  sameEligibility,
  validateEligibilityDraft,
  type CriterionDraft,
  type DraftIssue,
  type EligibilityDraft,
  type ServerIssue,
} from '../../lib/scholarship-eligibility';
import {
  loadEligibilityOptionsOnce,
  saveEligibility,
  unstampEligibility,
} from '../../lib/scholarship-eligibility-api';
import {
  AGE_AS_OF_KINDS,
  CEFR_LEVELS,
  CRITERION_IMPACTS,
  CRITERION_TYPES,
  ELIGIBLE_LEVELS,
  EXCLUDING_TYPES,
  FIELDS_SCOPES,
  LANGUAGE_TEST_SCALES,
  LANGUAGE_TEST_TYPES,
  NATIONALITY_APPLIES_TO,
  NATIONALITY_MODES,
  type CriterionType,
  type EligibilityCountryOption,
  type EligibilityCoverageState,
} from '../../lib/scholarship-eligibility-types';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, Field, Input, Select, Textarea } from '../ui';
import type { BadgeVariant } from '../ui';
import type { ScholarshipEntry } from './types';

const E = 'scholarships.eligibility';

export const ELIGIBILITY_STATE_VARIANT: Record<EligibilityCoverageState, BadgeVariant> = {
  fresh: 'success',
  stale: 'warning',
  unstructured: 'neutral',
  not_analyzed: 'danger',
};

type Translate = (key: string) => string;

/** Les champs d'éligibilité d'une fiche, comme le serveur les renvoie. */
type EligibilityPatch = Pick<
  ScholarshipEntry,
  | 'eligibleLevels'
  | 'fieldsScope'
  | 'eligibilityCriteria'
  | 'eligibilityStructuredAt'
  | 'eligibilityStructuredBy'
>;

function formatDate(iso: string | null | undefined, locale: 'fr' | 'en'): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-GB', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

/**
 * Éditeur de l'éligibilité structurée d'une bourse (« Mes 10 bourses »),
 * à côté des champs d'éligibilité en texte libre.
 *
 * - niveaux (Lycée / Licence / Master / Doctorat) et portée des domaines ;
 * - un formulaire par type de critère ; citation officielle FR/EN et URL
 *   source OBLIGATOIRES pour chacun ;
 * - « Enregistrer » garde un brouillon (un contenu modifié perd son tampon) ;
 *   « Conditions vérifiées » enregistre ET tamponne (qui, quand), audité côté
 *   serveur.
 */
export function ScholarshipEligibilityEditor({
  entry,
  onSaved,
}: {
  entry: ScholarshipEntry;
  onSaved: (patch: Partial<ScholarshipEntry>) => void;
}) {
  const { t, locale } = useLocale();
  const initial = useMemo(() => eligibilityDraftFrom(entry), [entry]);
  const [draft, setDraft] = useState<EligibilityDraft>(initial);
  const [countries, setCountries] = useState<EligibilityCountryOption[] | null>(null);
  const [freshnessDays, setFreshnessDays] = useState<number | undefined>(undefined);
  const [optionsError, setOptionsError] = useState(false);
  const [showErrors, setShowErrors] = useState(false);
  const [busy, setBusy] = useState<'save' | 'stamp' | 'unstamp' | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [serverIssues, setServerIssues] = useState<ServerIssue[]>([]);
  const [newType, setNewType] = useState<CriterionType>('nationality');

  // Réinitialise le formulaire quand la fiche (ou son éligibilité stockée)
  // change — pas quand une autre partie de la fiche est modifiée.
  const storedKey = JSON.stringify([
    entry.id,
    entry.eligibleLevels ?? [],
    entry.fieldsScope ?? null,
    entry.eligibilityCriteria ?? [],
    entry.eligibilityStructuredAt ?? null,
  ]);
  useEffect(() => {
    setDraft(eligibilityDraftFrom(entry));
    setShowErrors(false);
    setServerIssues([]);
    setMessage(null);
    setError(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storedKey]);

  useEffect(() => {
    let cancelled = false;
    loadEligibilityOptionsOnce()
      .then((options) => {
        if (cancelled) return;
        setCountries(options.countries);
        setFreshnessDays(options.freshnessDays);
      })
      .catch(() => {
        if (!cancelled) setOptionsError(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const knownCountries = useMemo(
    () => (countries ? new Set(countries.map((country) => country.code)) : undefined),
    [countries],
  );
  const dirty = !sameEligibility(draft, initial);
  const state = eligibilityStateOf(entry, new Date(), freshnessDays);
  const catalog = isCatalogManaged(entry.tags);
  const stamped = Boolean(entry.eligibilityStructuredAt);

  function issuesFor(forStamp: boolean): DraftIssue[] {
    return validateEligibilityDraft(draft, { knownCountries, forStamp });
  }
  const visibleIssues = showErrors ? issuesFor(false) : [];

  function update(next: EligibilityDraft) {
    setDraft(next);
    setMessage(null);
  }

  function patchCriterion(index: number, patch: Partial<CriterionDraft>) {
    update({
      ...draft,
      criteria: draft.criteria.map((criterion, i) =>
        i === index ? { ...criterion, ...patch } : criterion,
      ),
    });
  }

  function addCriterion() {
    update({
      ...draft,
      criteria: [
        ...draft.criteria,
        emptyCriterionDraft(
          newType,
          draft.criteria.map((criterion) => criterion.key),
        ),
      ],
    });
  }

  function removeCriterion(index: number) {
    update({ ...draft, criteria: draft.criteria.filter((_, i) => i !== index) });
  }

  function toggleLevel(level: (typeof ELIGIBLE_LEVELS)[number]) {
    const levels = draft.eligibleLevels.includes(level)
      ? draft.eligibleLevels.filter((value) => value !== level)
      : [...draft.eligibleLevels, level];
    update({ ...draft, eligibleLevels: ELIGIBLE_LEVELS.filter((value) => levels.includes(value)) });
  }

  async function submit(mode: 'save' | 'stamp' | 'unstamp') {
    setMessage(null);
    setError(null);
    setServerIssues([]);
    if (mode !== 'unstamp') {
      const issues = issuesFor(mode === 'stamp');
      if (issues.length > 0) {
        setShowErrors(true);
        setError(
          issues.some((issue) => issue.code === 'levels_required')
            ? t(`${E}.error_levels_required`)
            : t(`${E}.formHasErrors`),
        );
        return;
      }
    }
    setBusy(mode);
    try {
      const saved =
        mode === 'unstamp'
          ? await unstampEligibility(entry.id)
          : await saveEligibility(entry.id, draft, mode === 'stamp' ? true : undefined);
      const patch: EligibilityPatch = {
        eligibleLevels: saved?.eligibleLevels ?? draft.eligibleLevels,
        fieldsScope: (saved?.fieldsScope as ScholarshipEntry['fieldsScope']) ?? draft.fieldsScope,
        eligibilityCriteria: saved?.eligibilityCriteria ?? entry.eligibilityCriteria,
        eligibilityStructuredAt: saved?.eligibilityStructuredAt ?? null,
        eligibilityStructuredBy: saved?.eligibilityStructuredBy ?? null,
      };
      onSaved(patch);
      setShowErrors(false);
      setMessage(
        t(
          mode === 'stamp'
            ? `${E}.stampSuccess`
            : mode === 'unstamp'
              ? `${E}.unstampSuccess`
              : `${E}.saveSuccess`,
        ),
      );
    } catch (exception) {
      const parsed = readEligibilityError(exception);
      if (parsed) setServerIssues(parsed.issues);
      setError(exception instanceof Error ? exception.message : t(`${E}.saveError`));
    } finally {
      setBusy(null);
    }
  }

  return (
    <section style={sectionStyle} aria-labelledby={`eligibility-${entry.id}`}>
      <div style={headerRow}>
        <h4 id={`eligibility-${entry.id}`} style={{ margin: 0 }}>
          {t(`${E}.title`)}
        </h4>
        <Badge variant={ELIGIBILITY_STATE_VARIANT[state]}>{t(`${E}.state_${state}`)}</Badge>
      </div>
      <p style={mutedText}>{t(`${E}.intro`)}</p>
      <p style={{ ...mutedText, color: 'var(--ink)' }}>
        {stamped
          ? fill(t(`${E}.stampedBy`), {
              date: formatDate(entry.eligibilityStructuredAt, locale),
              by: entry.eligibilityStructuredBy || '—',
            })
          : t(`${E}.neverStamped`)}
      </p>

      {catalog ? <Alert variant="warning">{t(`${E}.catalogWarning`)}</Alert> : null}
      {optionsError ? <Alert variant="warning">{t(`${E}.countriesLoadError`)}</Alert> : null}

      <fieldset style={fieldsetStyle}>
        <legend style={legendStyle}>{t(`${E}.levelsLabel`)}</legend>
        <div style={inlineRow}>
          {ELIGIBLE_LEVELS.map((level) => (
            <label key={level} style={checkLabel}>
              <input
                type="checkbox"
                checked={draft.eligibleLevels.includes(level)}
                onChange={() => toggleLevel(level)}
              />
              {t(`${E}.level_${level}`)}
            </label>
          ))}
        </div>
        {visibleIssues.some((issue) => issue.code === 'levels_required') ? (
          <span style={errorText}>{t(`${E}.error_levels_required`)}</span>
        ) : null}
      </fieldset>

      <fieldset style={fieldsetStyle}>
        <legend style={legendStyle}>{t(`${E}.fieldsScopeLabel`)}</legend>
        <div style={inlineRow}>
          {FIELDS_SCOPES.map((scope) => (
            <label key={scope} style={checkLabel}>
              <input
                type="radio"
                name={`fields-scope-${entry.id}`}
                checked={draft.fieldsScope === scope}
                onChange={() => update({ ...draft, fieldsScope: scope })}
              />
              {t(`${E}.fieldsScope_${scope}`)}
            </label>
          ))}
        </div>
        {draft.fieldsScope === 'listed' && (entry.relatedFieldIds ?? []).length === 0 ? (
          <span style={hintText}>{t(`${E}.fieldsListedEmptyHint`)}</span>
        ) : (
          <span style={hintText}>{t(`${E}.fieldsScopeHint`)}</span>
        )}
      </fieldset>

      <div style={{ display: 'grid', gap: 10 }}>
        <span style={legendStyle}>
          {fill(t(`${E}.criteriaTitle`), { count: draft.criteria.length })}
        </span>
        {draft.criteria.length === 0 ? (
          <span style={hintText}>{t(`${E}.criteriaEmpty`)}</span>
        ) : null}
        {draft.criteria.map((criterion, index) => (
          <CriterionCard
            key={criterion.uid}
            draft={criterion}
            index={index}
            issues={visibleIssues.filter((issue) => issue.index === index)}
            serverIssues={serverIssues.filter((issue) => issue.index === index)}
            countries={countries}
            locale={locale}
            t={t}
            onChange={(patch) => patchCriterion(index, patch)}
            onRemove={() => removeCriterion(index)}
          />
        ))}
        <div style={{ ...inlineRow, alignItems: 'flex-end' }}>
          <div style={{ minWidth: 220 }}>
            <Field label={t(`${E}.addTypeLabel`)}>
              {({ id }) => (
                <Select
                  id={id}
                  value={newType}
                  onChange={(event) => setNewType(event.target.value as CriterionType)}
                >
                  {CRITERION_TYPES.map((type) => (
                    <option key={type} value={type}>
                      {t(`${E}.type_${type}`)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          <Button size="sm" variant="secondary" onClick={addCriterion}>
            {t(`${E}.addCriterionCta`)}
          </Button>
        </div>
      </div>

      {message ? <Alert variant="success">{message}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {serverIssues.some((issue) => issue.index === null) ? (
        <Alert variant="danger">
          {serverIssues
            .filter((issue) => issue.index === null)
            .map((issue) => issue.message)
            .join(' ')}
        </Alert>
      ) : null}

      <div style={{ ...inlineRow, justifyContent: 'flex-end' }}>
        {stamped ? (
          <Button
            size="sm"
            variant="ghost"
            loading={busy === 'unstamp'}
            disabled={busy !== null}
            onClick={() => submit('unstamp')}
          >
            {t(`${E}.unstampCta`)}
          </Button>
        ) : null}
        <Button
          variant="secondary"
          loading={busy === 'save'}
          disabled={busy !== null || !dirty}
          onClick={() => submit('save')}
        >
          {t(`${E}.saveCta`)}
        </Button>
        <Button
          variant="success"
          loading={busy === 'stamp'}
          disabled={busy !== null}
          onClick={() => submit('stamp')}
        >
          {t(`${E}.stampCta`)}
        </Button>
      </div>
      <span style={hintText}>
        {dirty && stamped ? t(`${E}.dirtyStampedHint`) : t(`${E}.stampHint`)}
      </span>
    </section>
  );
}

// ── Carte d'un critère ──────────────────────────────────────────────────────

function CriterionCard({
  draft,
  index,
  issues,
  serverIssues,
  countries,
  locale,
  t,
  onChange,
  onRemove,
}: {
  draft: CriterionDraft;
  index: number;
  issues: DraftIssue[];
  serverIssues: ServerIssue[];
  countries: EligibilityCountryOption[] | null;
  locale: 'fr' | 'en';
  t: Translate;
  onChange: (patch: Partial<CriterionDraft>) => void;
  onRemove: () => void;
}) {
  const errorFor = (field: string) => {
    const issue = issues.find((item) => item.field === field || item.field.startsWith(`${field}[`));
    return issue ? t(`${E}.error_${issue.code}`) : undefined;
  };
  const canExclude = EXCLUDING_TYPES.includes(draft.type);

  return (
    <div style={cardStyle}>
      <div style={headerRow}>
        <strong style={{ fontSize: 'var(--text-sm)' }}>
          {index + 1}. {t(`${E}.type_${draft.type}`)}
        </strong>
        <Button size="sm" variant="dangerOutline" onClick={onRemove}>
          {t(`${E}.removeCriterionCta`)}
        </Button>
      </div>

      <div style={grid3}>
        <Field label={t(`${E}.keyLabel`)} error={errorFor('key')}>
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              value={draft.key}
              onChange={(event) => onChange({ key: event.target.value })}
            />
          )}
        </Field>
        <Field label={t(`${E}.impactLabel`)}>
          {({ id }) => (
            <Select
              id={id}
              value={draft.type === 'financial_need' ? 'informational' : draft.impact}
              disabled={draft.type === 'financial_need'}
              onChange={(event) =>
                onChange({ impact: event.target.value as CriterionDraft['impact'] })
              }
            >
              {CRITERION_IMPACTS.map((impact) => (
                <option key={impact} value={impact}>
                  {t(`${E}.impact_${impact}`)}
                </option>
              ))}
            </Select>
          )}
        </Field>
      </div>
      <span style={hintText}>
        {draft.impact === 'hard' && !canExclude
          ? t(`${E}.impactHardNeverExcludesHint`)
          : t(`${E}.impactHint`)}
      </span>

      {draft.type === 'nationality' ? (
        <>
          <div style={grid3}>
            <Field label={t(`${E}.appliesToLabel`)}>
              {({ id }) => (
                <Select
                  id={id}
                  value={draft.appliesTo}
                  onChange={(event) =>
                    onChange({ appliesTo: event.target.value as CriterionDraft['appliesTo'] })
                  }
                >
                  {NATIONALITY_APPLIES_TO.map((value) => (
                    <option key={value} value={value}>
                      {t(`${E}.appliesTo_${value}`)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <fieldset style={fieldsetStyle}>
              <legend style={legendStyle}>{t(`${E}.modeLabel`)}</legend>
              <div style={inlineRow}>
                {NATIONALITY_MODES.map((mode) => (
                  <label key={mode} style={checkLabel}>
                    <input
                      type="radio"
                      name={`mode-${draft.uid}`}
                      checked={draft.mode === mode}
                      onChange={() => onChange({ mode })}
                    />
                    {t(`${E}.mode_${mode}`)}
                  </label>
                ))}
              </div>
            </fieldset>
          </div>
          <CountryMultiSelect
            label={t(`${E}.countriesLabel`)}
            value={draft.countries}
            countries={countries}
            locale={locale}
            t={t}
            error={errorFor('countries')}
            onChange={(next) => onChange({ countries: next })}
          />
          <span style={hintText}>{t(`${E}.anyNationalityHint`)}</span>
        </>
      ) : null}

      {draft.type === 'age' ? (
        <>
          <div style={grid3}>
            <NumberField label={t(`${E}.ageMinLabel`)} value={draft.min} error={errorFor('min')} onChange={(min) => onChange({ min })} />
            <NumberField label={t(`${E}.ageMaxLabel`)} value={draft.max} error={errorFor('max')} onChange={(max) => onChange({ max })} />
            <LevelField t={t} value={draft.level} onChange={(level) => onChange({ level })} />
          </div>
          <label style={checkLabel}>
            <input
              type="checkbox"
              checked={draft.maxInclusive}
              onChange={(event) => onChange({ maxInclusive: event.target.checked })}
            />
            {t(`${E}.maxInclusiveLabel`)}
          </label>
          <span style={hintText}>{t(`${E}.maxInclusiveHint`)}</span>
          <div style={grid3}>
            <Field label={t(`${E}.asOfLabel`)}>
              {({ id }) => (
                <Select
                  id={id}
                  value={draft.asOfKind}
                  onChange={(event) =>
                    onChange({ asOfKind: event.target.value as CriterionDraft['asOfKind'] })
                  }
                >
                  {AGE_AS_OF_KINDS.map((kind) => (
                    <option key={kind} value={kind}>
                      {t(`${E}.asOf_${kind}`)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            {draft.asOfKind === 'date' ? (
              <Field label={t(`${E}.asOfDateLabel`)} error={errorFor('asOfDate')}>
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    type="date"
                    invalid={invalid}
                    value={draft.asOfDate}
                    onChange={(event) => onChange({ asOfDate: event.target.value })}
                  />
                )}
              </Field>
            ) : null}
          </div>
          <span style={hintText}>{t(`${E}.asOfHint`)}</span>
        </>
      ) : null}

      {draft.type === 'work_experience' ? (
        <div style={grid3}>
          <NumberField
            label={t(`${E}.minMonthsLabel`)}
            value={draft.minMonths}
            error={errorFor('minMonths')}
            onChange={(minMonths) => onChange({ minMonths })}
          />
          <LevelField t={t} value={draft.level} onChange={(level) => onChange({ level })} />
        </div>
      ) : null}

      {draft.type === 'language' ? (
        <>
          <div style={grid3}>
            <Field label={t(`${E}.langLabel`)} error={errorFor('lang')}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  maxLength={2}
                  value={draft.lang}
                  onChange={(event) => onChange({ lang: event.target.value.toLowerCase() })}
                />
              )}
            </Field>
            <Field label={t(`${E}.minCefrLabel`)} error={errorFor('minCefr')}>
              {({ id, invalid }) => (
                <Select
                  id={id}
                  invalid={invalid}
                  value={draft.minCefr}
                  onChange={(event) =>
                    onChange({ minCefr: event.target.value as CriterionDraft['minCefr'] })
                  }
                >
                  <option value="">{t(`${E}.none`)}</option>
                  {CEFR_LEVELS.map((level) => (
                    <option key={level} value={level}>
                      {level.toUpperCase()}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          {draft.tests.map((test, i) => (
            <div key={i} style={{ ...inlineRow, alignItems: 'flex-end' }}>
              <div style={{ minWidth: 160 }}>
                <Field label={t(`${E}.testTypeLabel`)}>
                  {({ id }) => (
                    <Select
                      id={id}
                      value={test.type}
                      onChange={(event) =>
                        onChange({
                          tests: draft.tests.map((item, j) =>
                            j === i
                              ? { ...item, type: event.target.value as typeof test.type }
                              : item,
                          ),
                        })
                      }
                    >
                      {LANGUAGE_TEST_TYPES.map((type) => (
                        <option key={type} value={type}>
                          {t(`${E}.test_${type}`)}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
              </div>
              <div style={{ width: 160 }}>
                <NumberField
                  label={fill(t(`${E}.testMinLabel`), {
                    min: LANGUAGE_TEST_SCALES[test.type].min,
                    max: LANGUAGE_TEST_SCALES[test.type].max,
                  })}
                  value={test.min}
                  error={errorFor(`tests[${i}]`)}
                  onChange={(min) =>
                    onChange({
                      tests: draft.tests.map((item, j) => (j === i ? { ...item, min } : item)),
                    })
                  }
                />
              </div>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => onChange({ tests: draft.tests.filter((_, j) => j !== i) })}
              >
                {t(`${E}.removeTestCta`)}
              </Button>
            </div>
          ))}
          <div style={inlineRow}>
            <Button
              size="sm"
              variant="secondary"
              onClick={() => onChange({ tests: [...draft.tests, { type: 'ielts', min: '' }] })}
            >
              {t(`${E}.addTestCta`)}
            </Button>
            <label style={checkLabel}>
              <input
                type="checkbox"
                checked={draft.waivable}
                onChange={(event) => onChange({ waivable: event.target.checked })}
              />
              {t(`${E}.waivableLabel`)}
            </label>
          </div>
          <span style={hintText}>{t(`${E}.languageHint`)}</span>
        </>
      ) : null}

      {draft.type === 'academic_grade' ? (
        <div style={grid3}>
          <NumberField
            label={t(`${E}.minOn20Label`)}
            value={draft.minOn20}
            error={errorFor('minOn20')}
            onChange={(minOn20) => onChange({ minOn20 })}
          />
          <Field label={t(`${E}.rawTextLabel`)} error={errorFor('rawText')}>
            {({ id, invalid }) => (
              <Input
                id={id}
                invalid={invalid}
                value={draft.rawText}
                onChange={(event) => onChange({ rawText: event.target.value })}
              />
            )}
          </Field>
        </div>
      ) : null}

      {draft.type === 'financial_need' ? (
        <span style={hintText}>{t(`${E}.financialNeedHint`)}</span>
      ) : null}
      {draft.type === 'other' ? <span style={hintText}>{t(`${E}.otherHint`)}</span> : null}

      <div style={grid2}>
        <Field label={t(`${E}.officialTextFrLabel`)} error={errorFor('officialTextFr')}>
          {({ id, invalid }) => (
            <Textarea
              id={id}
              rows={3}
              invalid={invalid}
              value={draft.officialTextFr}
              onChange={(event) => onChange({ officialTextFr: event.target.value })}
            />
          )}
        </Field>
        <Field label={t(`${E}.officialTextEnLabel`)} error={errorFor('officialTextEn')}>
          {({ id, invalid }) => (
            <Textarea
              id={id}
              rows={3}
              invalid={invalid}
              value={draft.officialTextEn}
              onChange={(event) => onChange({ officialTextEn: event.target.value })}
            />
          )}
        </Field>
      </div>
      <Field label={t(`${E}.sourceUrlLabel`)} error={errorFor('sourceUrl')}>
        {({ id, invalid }) => (
          <Input
            id={id}
            type="url"
            invalid={invalid}
            value={draft.sourceUrl}
            onChange={(event) => onChange({ sourceUrl: event.target.value })}
          />
        )}
      </Field>
      {serverIssues.length > 0 ? (
        <Alert variant="danger">{serverIssues.map((issue) => issue.message).join(' ')}</Alert>
      ) : null}
    </div>
  );
}

function NumberField({
  label,
  value,
  error,
  onChange,
}: {
  label: string;
  value: string;
  error?: string;
  onChange: (value: string) => void;
}) {
  return (
    <Field label={label} error={error}>
      {({ id, invalid }) => (
        <Input
          id={id}
          inputMode="decimal"
          invalid={invalid}
          value={value}
          onChange={(event) => onChange(event.target.value)}
        />
      )}
    </Field>
  );
}

function LevelField({
  t,
  value,
  onChange,
}: {
  t: Translate;
  value: CriterionDraft['level'];
  onChange: (value: CriterionDraft['level']) => void;
}) {
  return (
    <Field label={t(`${E}.criterionLevelLabel`)}>
      {({ id }) => (
        <Select
          id={id}
          value={value}
          onChange={(event) => onChange(event.target.value as CriterionDraft['level'])}
        >
          <option value="">{t(`${E}.allLevels`)}</option>
          {ELIGIBLE_LEVELS.map((level) => (
            <option key={level} value={level}>
              {t(`${E}.level_${level}`)}
            </option>
          ))}
        </Select>
      )}
    </Field>
  );
}

function fold(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
}

/** Multisélection de pays ISO3 : pastilles + recherche (nom FR/EN ou code). */
function CountryMultiSelect({
  label,
  value,
  countries,
  locale,
  t,
  error,
  onChange,
}: {
  label: string;
  value: string[];
  countries: EligibilityCountryOption[] | null;
  locale: 'fr' | 'en';
  t: Translate;
  error?: string;
  onChange: (value: string[]) => void;
}) {
  const [query, setQuery] = useState('');
  const byCode = useMemo(
    () => new Map((countries ?? []).map((country) => [country.code, country])),
    [countries],
  );
  const nameOf = (code: string) => {
    const country = byCode.get(code);
    if (!country) return code.toUpperCase();
    return locale === 'en' ? country.nameEn : country.nameFr;
  };
  const folded = fold(query.trim());
  const suggestions = folded
    ? (countries ?? [])
        .filter(
          (country) =>
            !value.includes(country.code) &&
            (country.code === folded ||
              fold(country.nameFr).includes(folded) ||
              fold(country.nameEn).includes(folded)),
        )
        .slice(0, 8)
    : [];

  function add(code: string) {
    if (!value.includes(code)) onChange([...value, code]);
    setQuery('');
  }

  return (
    <div style={{ display: 'grid', gap: 6 }}>
      <Field label={label} error={error}>
        {({ id, invalid }) => (
          <Input
            id={id}
            invalid={invalid}
            value={query}
            placeholder={countries ? t(`${E}.countrySearchPlaceholder`) : t(`${E}.countriesLoading`)}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter' && suggestions[0]) {
                event.preventDefault();
                add(suggestions[0].code);
              }
            }}
          />
        )}
      </Field>
      {suggestions.length > 0 ? (
        <div style={inlineRow} role="listbox" aria-label={label}>
          {suggestions.map((country) => (
            <Button key={country.code} size="sm" variant="ghost" onClick={() => add(country.code)}>
              + {locale === 'en' ? country.nameEn : country.nameFr} ({country.code})
            </Button>
          ))}
        </div>
      ) : null}
      <div style={inlineRow}>
        {value.length === 0 ? <span style={hintText}>{t(`${E}.noCountry`)}</span> : null}
        {value.map((code) => (
          <button
            key={code}
            type="button"
            style={chipStyle}
            aria-label={fill(t(`${E}.removeCountryAria`), { name: nameOf(code) })}
            onClick={() => onChange(value.filter((item) => item !== code))}
          >
            {nameOf(code)} <span style={{ opacity: 0.6 }}>({code})</span> ×
          </button>
        ))}
      </div>
    </div>
  );
}

const sectionStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 14,
  border: '1px solid var(--border)',
  borderRadius: 14,
  background: 'var(--bg)',
};

const cardStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  padding: 12,
  border: '1px solid var(--border-soft)',
  borderRadius: 12,
  background: 'var(--surface)',
};

const headerRow: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 12,
  flexWrap: 'wrap',
};

const inlineRow: CSSProperties = { display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' };

const grid2: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
  gap: 10,
};

const grid3: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
  gap: 10,
};

const fieldsetStyle: CSSProperties = {
  border: 'none',
  margin: 0,
  padding: 0,
  display: 'grid',
  gap: 6,
};

const legendStyle: CSSProperties = {
  fontSize: 'var(--text-xs)',
  fontWeight: 800,
  color: 'var(--text-muted)',
  padding: 0,
  marginBottom: 4,
};

const checkLabel: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  fontSize: 'var(--text-sm)',
};

const mutedText: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-sm)',
  color: 'var(--text-muted)',
};

const hintText: CSSProperties = { color: 'var(--text-muted)', fontSize: 'var(--text-xs)' };

const errorText: CSSProperties = { color: 'var(--danger, #b42318)', fontSize: 'var(--text-xs)' };

const chipStyle: CSSProperties = {
  border: '1px solid var(--border)',
  borderRadius: 999,
  padding: '2px 10px',
  background: 'var(--surface)',
  fontSize: 'var(--text-xs)',
  cursor: 'pointer',
};
