'use client';

import { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';

import {
  AdminCapability,
  hasAdminCapability,
} from '../../lib/admin-capabilities';
import {
  activateErrorText,
  activateOutcome,
  activationDraftError,
  announcementRequest,
  buildActivateBody,
  buildForecastBody,
  cycleForYear,
  cycleOptions,
  draftForCycle,
  endOfDayIso,
  forecastDraftError,
  localFanoutDeadline,
  PREVIEW_DEBOUNCE_MS,
  previewQueryForDraft,
  previewQueryKey,
  previewSummaryText,
  primaryAction,
  recentEventLabel,
  scheduledCycle,
  showDatesOnlyAction,
  startOfDayIso,
  type AnnouncementRequest,
  type OpeningDraft,
} from '../../lib/scholarship-opening';
import {
  activateScholarshipCycle,
  fetchOpeningPreview,
  saveScholarshipForecast,
} from '../../lib/scholarship-opening-api';
import type {
  ActivateScholarshipResponse,
  OpeningPreviewQuery,
  OpeningPreviewResponse,
} from '../../lib/scholarship-opening-types';
import { useLocale } from '../locale-provider';
import { Alert, Button, Field, Input, Select } from '../ui';
import type { AlertVariant } from '../ui';
import { OpeningPreviewModal } from './OpeningPreviewModal';
import { OpeningScheduledCard } from './OpeningScheduledCard';
import type { ScholarshipEntry } from './types';

/**
 * Ouverture d'un cycle et annonce aux étudiants qui suivent la bourse
 * (chantier C). Remplace l'ancien éditeur « Ouvrir et notifier », qui
 * prévenait tout de suite, sans aperçu ni annulation possible.
 *
 * Déroulé : l'aperçu du serveur (cycle par défaut, audience, complétude) se
 * charge à la sélection et se recalcule 400 ms après chaque changement
 * d'année ou de date. [Ouvrir et prévenir les abonnés…] ouvre l'aperçu
 * détaillé, puis une confirmation (saisie du nombre au-delà du seuil). Le
 * serveur programme l'envoi 120 s plus tard : la carte de programmation
 * compte à rebours et permet d'annuler, puis affiche le rapport.
 * [Enregistrer les dates sans prévenir] corrige les dates sans rien envoyer.
 * Quand l'aperçu ne compte personne à prévenir, le bouton principal devient
 * [Ouvrir le cycle sans prévenir] : il envoie `notify: false`, jamais une
 * annonce que personne n'aurait confirmée (`announcementRequest`).
 */

const metaLabelStyle: CSSProperties = {
  fontSize: 9.5,
  fontWeight: 800,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  color: 'var(--text-faint)',
};

const hintStyle: CSSProperties = {
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
};

const twoColumns: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: '1fr 1fr',
  gap: 8,
};

interface ScheduledState {
  /** Clé React : une nouvelle programmation remet la carte à zéro. */
  key: string;
  cycleId: string;
  academicYear: string;
  fanoutAt: string | null;
  deadlineMs: number | null;
  toNotify: number | null;
}

type Pending = 'notify' | 'openOnly' | 'datesOnly' | 'forecast' | null;

/** La fiche après une ouverture, comme le reste de la page l'affiche. */
function entryPatchAfterActivate(
  draft: OpeningDraft,
  response: ActivateScholarshipResponse,
): Partial<ScholarshipEntry> {
  return {
    deadlineAt: endOfDayIso(draft.closesAt),
    currentCycle: {
      id: response.cycleId,
      academicYear: response.academicYear,
      status: 'open',
      dateConfidence: 'confirmed',
      estimatedOpenAt: draft.estimatedOpenAt
        ? startOfDayIso(draft.estimatedOpenAt)
        : null,
      estimatedCloseAt: draft.estimatedCloseAt
        ? endOfDayIso(draft.estimatedCloseAt)
        : null,
      opensAt: startOfDayIso(draft.opensAt),
      closesAt: endOfDayIso(draft.closesAt),
    },
  };
}

/** La fiche après l'enregistrement d'une estimation (inchangé depuis l'ancien éditeur). */
function entryPatchAfterForecast(
  entry: ScholarshipEntry,
  draft: OpeningDraft,
): Partial<ScholarshipEntry> {
  const open = entry.currentCycle?.status === 'open';
  return {
    currentCycle: {
      id: entry.currentCycle?.id ?? '',
      academicYear: draft.academicYear,
      status: open ? 'open' : 'forecast',
      dateConfidence: open ? 'confirmed' : 'estimated',
      estimatedOpenAt: startOfDayIso(draft.estimatedOpenAt),
      estimatedCloseAt: endOfDayIso(draft.estimatedCloseAt),
      opensAt: entry.currentCycle?.opensAt ?? null,
      closesAt: entry.currentCycle?.closesAt ?? null,
    },
  };
}

export interface CycleOpeningPanelProps {
  entry: ScholarshipEntry;
  /** Rôle de l'équipier connecté (présentation seulement). */
  role: string | null | undefined;
  /** Année d'un cycle à annoncer, venue de la carte « À faire ». */
  autoOpenYear: string | null;
  onAutoOpenHandled: () => void;
  onEntryPatched: (patch: Partial<ScholarshipEntry>) => void;
  /** Une annonce a été programmée, annulée, arrêtée ou envoyée. */
  onOpeningChanged: () => void;
}

export function CycleOpeningPanel(props: CycleOpeningPanelProps) {
  const { t } = useLocale();
  if (props.entry.moderationStatus !== 'approved') {
    return (
      <Alert variant="warning">{t('scholarships.activationApprovalHint')}</Alert>
    );
  }
  return <ApprovedCycleOpeningPanel {...props} />;
}

function ApprovedCycleOpeningPanel({
  entry,
  role,
  autoOpenYear,
  onAutoOpenHandled,
  onEntryPatched,
  onOpeningChanged,
}: CycleOpeningPanelProps) {
  const { t } = useLocale();
  const panelRef = useRef<HTMLDivElement>(null);
  const [preview, setPreview] = useState<OpeningPreviewResponse | null>(null);
  // La requête (année + dates) à laquelle `preview` répond : si le brouillon
  // a changé depuis, l'aperçu est périmé et rien ne se confirme dessus.
  const [previewKey, setPreviewKey] = useState<string | null>(null);
  const [previewLoading, setPreviewLoading] = useState(true);
  // '' = erreur sans message lisible (le libellé générique est affiché).
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [draft, setDraft] = useState<OpeningDraft | null>(null);
  const [pending, setPending] = useState<Pending>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);
  const [notice, setNotice] = useState<{
    variant: AlertVariant;
    text: string;
  } | null>(null);
  const [scheduled, setScheduled] = useState<ScheduledState | null>(null);
  const [reportCycle, setReportCycle] = useState<{
    cycleId: string;
    academicYear: string;
  } | null>(null);
  const requestRef = useRef<{ seq: number; controller: AbortController | null }>(
    { seq: 0, controller: null },
  );

  /**
   * Charge un aperçu. Seule la dernière requête compte : la précédente est
   * abandonnée, et une réponse arrivée en retard est ignorée.
   */
  const loadPreview = useCallback(
    async (
      query: OpeningPreviewQuery,
      key: string | null,
    ): Promise<OpeningPreviewResponse | null> => {
      const request = requestRef.current;
      const seq = request.seq + 1;
      request.seq = seq;
      request.controller?.abort();
      const controller = new AbortController();
      request.controller = controller;
      setPreviewLoading(true);
      try {
        const next = await fetchOpeningPreview(entry.id, query, controller.signal);
        if (seq !== requestRef.current.seq) return null;
        setPreview(next);
        setPreviewError(null);
        if (key !== null) setPreviewKey(key);
        return next;
      } catch (error) {
        if (seq !== requestRef.current.seq || controller.signal.aborted) {
          return null;
        }
        setPreviewError(error instanceof Error ? error.message : '');
        return null;
      } finally {
        if (seq === requestRef.current.seq) setPreviewLoading(false);
      }
    },
    [entry.id],
  );

  const draftRef = useRef(draft);
  draftRef.current = draft;

  /** Recalcule tout de suite l'aperçu du brouillon courant. */
  const refreshNow = useCallback(async () => {
    const current = draftRef.current;
    if (!current) return null;
    const query = previewQueryForDraft(current);
    return loadPreview(query, previewQueryKey(query));
  }, [loadPreview]);

  // La source de la fiche peut changer pendant que le panneau est ouvert
  // (éditeur de contenu) : lue au moment du chargement, sans le relancer.
  const sourceUrlRef = useRef(entry.sourceUrl ?? '');
  sourceUrlRef.current = entry.sourceUrl ?? '';

  /** Premier aperçu, sans année : le serveur choisit le cycle à proposer. */
  const loadInitial = useCallback(
    async (isIgnored: () => boolean = () => false) => {
      const next = await loadPreview({}, null);
      if (!next || isIgnored()) return;
      const year = next.target.academicYear;
      const nextDraft = draftForCycle(
        year,
        cycleForYear(next, year),
        sourceUrlRef.current,
      );
      setDraft(nextDraft);
      // Les dates préremplies sont celles du cycle : l'aperçu y répond déjà.
      setPreviewKey(previewQueryKey(previewQueryForDraft(nextDraft)));
      const due = scheduledCycle(next);
      if (due?.openingFanoutDueAt) {
        setScheduled({
          key: `${due.id}:${due.openingFanoutDueAt}`,
          cycleId: due.id,
          academicYear: due.academicYear,
          fanoutAt: due.openingFanoutDueAt,
          deadlineMs: Date.parse(due.openingFanoutDueAt),
          toNotify: null,
        });
      }
    },
    [loadPreview],
  );

  useEffect(() => {
    let ignore = false;
    const request = requestRef.current;
    void loadInitial(() => ignore);
    return () => {
      ignore = true;
      request.controller?.abort();
    };
  }, [loadInitial]);

  const draftKey = draft ? previewQueryKey(previewQueryForDraft(draft)) : null;

  // Année ou date modifiée : aperçu recalculé après 400 ms de calme.
  useEffect(() => {
    if (draftKey === null || previewKey === null || draftKey === previewKey) {
      return;
    }
    const timer = setTimeout(() => void refreshNow(), PREVIEW_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [draftKey, previewKey, refreshNow]);

  const stale = previewLoading || draftKey === null || draftKey !== previewKey;
  const canSendAboveThreshold =
    Boolean(preview?.canSendAboveThreshold) &&
    hasAdminCapability(role, AdminCapability.SendLargeScholarshipOpening);
  const action = preview
    ? primaryAction(preview, { canSendAboveThreshold }, t)
    : null;

  // Les callbacks passés à la carte restent stables : son compte à rebours
  // ne doit pas redémarrer à chaque rendu de la page.
  const onOpeningChangedRef = useRef(onOpeningChanged);
  onOpeningChangedRef.current = onOpeningChanged;
  const handleOpeningChanged = useCallback(() => {
    onOpeningChangedRef.current();
    void refreshNow();
  }, [refreshNow]);

  // « Préparer l'annonce » depuis « À faire » : sélectionner l'année du cycle,
  // attendre son aperçu, puis ouvrir la fenêtre d'aperçu.
  useEffect(() => {
    if (!autoOpenYear || !preview || !draft) return;
    if (draft.academicYear !== autoOpenYear) {
      if (preview.cycles.some((cycle) => cycle.academicYear === autoOpenYear)) {
        setDraft((current) =>
          draftForCycle(
            autoOpenYear,
            cycleForYear(preview, autoOpenYear),
            current?.sourceUrl ?? entry.sourceUrl ?? '',
          ),
        );
      } else {
        onAutoOpenHandled();
      }
      return;
    }
    if (stale) return;
    onAutoOpenHandled();
    panelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    const invalid = activationDraftError(draft);
    if (invalid) {
      setNotice({ variant: 'warning', text: t(invalid) });
      return;
    }
    setModalError(null);
    setModalOpen(true);
  }, [autoOpenYear, preview, draft, stale, onAutoOpenHandled, entry.sourceUrl, t]);

  function updateDraft(patch: Partial<OpeningDraft>) {
    setDraft((current) => (current ? { ...current, ...patch } : current));
  }

  function changeYear(academicYear: string) {
    setNotice(null);
    setReportCycle(null);
    setDraft((current) =>
      draftForCycle(
        academicYear,
        cycleForYear(preview, academicYear),
        current?.sourceUrl ?? entry.sourceUrl ?? '',
      ),
    );
  }

  async function activate(
    request: AnnouncementRequest,
    surface: 'panel' | 'modal',
    pendingKind: Exclude<Pending, 'forecast' | null>,
  ): Promise<boolean> {
    if (!draft) return false;
    const showError = (text: string) =>
      surface === 'modal'
        ? setModalError(text)
        : setNotice({ variant: 'danger', text });
    const invalid = activationDraftError(draft);
    if (invalid) {
      showError(t(invalid));
      return false;
    }
    setPending(pendingKind);
    setNotice(null);
    setModalError(null);
    const requestStartedAt = Date.now();
    try {
      const response = await activateScholarshipCycle(
        entry.id,
        buildActivateBody(draft, request),
      );
      const outcome = activateOutcome(response, t);
      if (outcome.kind === 'scheduled') {
        setScheduled({
          key: `${outcome.cycleId}:${outcome.fanoutAt}`,
          cycleId: outcome.cycleId,
          academicYear: response.academicYear,
          fanoutAt: outcome.fanoutAt,
          deadlineMs: localFanoutDeadline({
            state: response.notification.state,
            fanoutAt: outcome.fanoutAt,
            holdSeconds: preview?.holdSeconds ?? 0,
            requestStartedAt,
          }),
          toNotify: outcome.toNotify,
        });
        setReportCycle(null);
      } else {
        setNotice({ variant: 'success', text: outcome.text });
      }
      onEntryPatched(entryPatchAfterActivate(draft, response));
      onOpeningChanged();
      void refreshNow();
      return true;
    } catch (error) {
      const { text, refreshPreview } = activateErrorText(
        error,
        t,
        t('scholarships.activationError'),
      );
      showError(text);
      if (refreshPreview) void refreshNow();
      return false;
    } finally {
      setPending(null);
    }
  }

  async function confirmFromModal(request: AnnouncementRequest): Promise<boolean> {
    const ok = await activate(request, 'modal', request.notify ? 'notify' : 'openOnly');
    if (ok) setModalOpen(false);
    return ok;
  }

  function startAnnouncement() {
    if (!draft || !action) return;
    const invalid = activationDraftError(draft);
    if (invalid) {
      setNotice({ variant: 'danger', text: t(invalid) });
      return;
    }
    setNotice(null);
    if (action.kind === 'open_only') {
      // Personne à prévenir : ouverture sans prévenir (`notify: false`).
      void activate(announcementRequest('open_only', 0), 'panel', 'openOnly');
      return;
    }
    setModalError(null);
    setModalOpen(true);
    // Chiffres frais avant de confirmer : l'aperçu affiché peut dater.
    void refreshNow();
  }

  async function saveForecast() {
    if (!draft) return;
    const invalid = forecastDraftError(draft);
    if (invalid) {
      setNotice({ variant: 'danger', text: t(invalid) });
      return;
    }
    setPending('forecast');
    setNotice(null);
    try {
      await saveScholarshipForecast(entry.id, buildForecastBody(draft));
      onEntryPatched(entryPatchAfterForecast(entry, draft));
      setNotice({ variant: 'success', text: t('scholarships.forecastSuccess') });
      void refreshNow();
    } catch (error) {
      setNotice({
        variant: 'danger',
        text:
          error instanceof Error && error.message
            ? error.message
            : t('scholarships.forecastError'),
      });
    } finally {
      setPending(null);
    }
  }

  const selectedCycle = draft ? cycleForYear(preview, draft.academicYear) : undefined;
  const canShowReport =
    selectedCycle !== undefined &&
    (selectedCycle.openingLastFanoutAt !== null ||
      selectedCycle.openingNotifiedAt !== null) &&
    scheduled?.cycleId !== selectedCycle.id &&
    reportCycle?.cycleId !== selectedCycle.id;

  return (
    <div
      ref={panelRef}
      style={{
        display: 'grid',
        gap: 10,
        padding: 14,
        borderRadius: 14,
        border: '1px solid var(--border)',
        background: 'var(--bg)',
      }}
    >
      <span style={metaLabelStyle}>{t('scholarships.activationTitle')}</span>

      {previewError !== null ? (
        <Alert variant="danger">
          {previewError || t('scholarships.opening.previewError')}{' '}
          <Button
            size="sm"
            variant="secondary"
            onClick={() => void (draft ? refreshNow() : loadInitial())}
          >
            {t('scholarships.opening.retryCta')}
          </Button>
        </Alert>
      ) : null}

      {!preview || !draft ? (
        previewError === null ? (
          <span style={hintStyle}>{t('scholarships.opening.previewLoading')}</span>
        ) : null
      ) : (
        <>
          <Field label={t('scholarships.opening.cycleLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={draft.academicYear}
                disabled={pending !== null}
                onChange={(event) => changeYear(event.target.value)}
              >
                {cycleOptions(preview, t).map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <span style={hintStyle} aria-live="polite">
            {stale
              ? t('scholarships.opening.previewLoading')
              : previewSummaryText(preview, t)}
          </span>

          <Field label={t('scholarships.sourceLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="url"
                value={draft.sourceUrl}
                onChange={(event) => updateDraft({ sourceUrl: event.target.value })}
              />
            )}
          </Field>
          <div style={twoColumns}>
            <Field label={t('scholarships.estimatedOpenAtLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="date"
                  value={draft.estimatedOpenAt}
                  onChange={(event) =>
                    updateDraft({ estimatedOpenAt: event.target.value })
                  }
                />
              )}
            </Field>
            <Field label={t('scholarships.estimatedCloseAtLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="date"
                  value={draft.estimatedCloseAt}
                  onChange={(event) =>
                    updateDraft({ estimatedCloseAt: event.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <Button
            variant="secondary"
            loading={pending === 'forecast'}
            disabled={pending !== null && pending !== 'forecast'}
            onClick={() => void saveForecast()}
          >
            {t('scholarships.saveForecastCta')}
          </Button>
          <span style={hintStyle}>{t('scholarships.forecastHint')}</span>

          <div style={twoColumns}>
            <Field label={t('scholarships.opensAtLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="date"
                  value={draft.opensAt}
                  onChange={(event) => updateDraft({ opensAt: event.target.value })}
                />
              )}
            </Field>
            <Field label={t('scholarships.closesAtLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="date"
                  value={draft.closesAt}
                  onChange={(event) => updateDraft({ closesAt: event.target.value })}
                />
              )}
            </Field>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Button
              variant="success"
              loading={(pending === 'notify' || pending === 'openOnly') && !modalOpen}
              disabled={
                !action ||
                stale ||
                pending !== null ||
                action.disabledReason !== null
              }
              onClick={startAnnouncement}
            >
              {action?.label ?? t('scholarships.opening.primaryCta')}
            </Button>
            {showDatesOnlyAction(action) ? (
              <Button
                variant="secondary"
                loading={pending === 'datesOnly'}
                disabled={pending !== null && pending !== 'datesOnly'}
                onClick={() => void activate({ notify: false }, 'panel', 'datesOnly')}
              >
                {t('scholarships.opening.saveDatesOnlyCta')}
              </Button>
            ) : null}
          </div>
          {action?.disabledReason && !stale ? (
            <span style={{ ...hintStyle, color: 'var(--warning-fg)' }}>
              {action.disabledReason}
            </span>
          ) : null}

          {notice ? <Alert variant={notice.variant}>{notice.text}</Alert> : null}

          {scheduled ? (
            <OpeningScheduledCard
              key={scheduled.key}
              scholarshipId={entry.id}
              cycleId={scheduled.cycleId}
              academicYear={scheduled.academicYear}
              fanoutAt={scheduled.fanoutAt}
              deadlineMs={scheduled.deadlineMs}
              holdSeconds={preview.holdSeconds}
              toNotify={scheduled.toNotify}
              recentEvents={preview.recentEvents}
              onChanged={handleOpeningChanged}
              onHide={() => setScheduled(null)}
            />
          ) : null}

          {reportCycle ? (
            <OpeningScheduledCard
              key={`report:${reportCycle.cycleId}`}
              scholarshipId={entry.id}
              cycleId={reportCycle.cycleId}
              academicYear={reportCycle.academicYear}
              fanoutAt={null}
              deadlineMs={null}
              holdSeconds={preview.holdSeconds}
              toNotify={null}
              onChanged={handleOpeningChanged}
              onHide={() => setReportCycle(null)}
            />
          ) : null}

          {canShowReport && selectedCycle ? (
            <div>
              <Button
                size="sm"
                variant="ghost"
                onClick={() =>
                  setReportCycle({
                    cycleId: selectedCycle.id,
                    academicYear: selectedCycle.academicYear,
                  })
                }
              >
                {t('scholarships.opening.reportShowCta')}
              </Button>
            </div>
          ) : null}

          {preview.recentEvents.length > 0 ? (
            <div style={{ display: 'grid', gap: 4 }}>
              <span style={metaLabelStyle}>
                {t('scholarships.opening.recentEventsTitle')}
              </span>
              <ul style={{ margin: 0, paddingLeft: 16, display: 'grid', gap: 2 }}>
                {preview.recentEvents.map((event) => (
                  <li
                    key={`${event.action}:${event.occurredAt}`}
                    style={{ ...hintStyle, color: 'var(--text)' }}
                  >
                    {recentEventLabel(event, t)}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </>
      )}

      <OpeningPreviewModal
        open={modalOpen}
        preview={preview}
        loading={stale}
        error={modalError}
        canSendAboveThreshold={canSendAboveThreshold}
        submitting={pending === 'notify' || pending === 'openOnly'}
        onClose={() => setModalOpen(false)}
        onConfirm={confirmFromModal}
      />
    </div>
  );
}
