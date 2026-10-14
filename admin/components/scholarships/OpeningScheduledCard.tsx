'use client';

import { CSSProperties, useEffect, useState } from 'react';

import {
  apiErrorCode,
  cancelConflictMessageKey,
  fill,
  formatCountdown,
  formatReportLine,
  formatTime,
  REPORT_POLL_INTERVAL_MS,
  reportDeferredDetail,
  reportProvidersLine,
  secondsUntil,
  shouldPollReport,
} from '../../lib/scholarship-opening';
import {
  cancelOpening,
  fetchOpeningReport,
  stopOpening,
} from '../../lib/scholarship-opening-api';
import type { OpeningReportResponse } from '../../lib/scholarship-opening-types';
import { useLocale } from '../locale-provider';
import { Alert, Button, ConfirmDialog } from '../ui';
import type { AlertVariant } from '../ui';

/**
 * L'annonce programmée d'un cycle, puis son rapport.
 *
 * Avant l'heure d'envoi : un compte à rebours et [Annuler l'envoi] — rien
 * n'est encore écrit pour les étudiants, annuler ne laisse aucune trace chez
 * eux. Après : le rapport, relu toutes les 5 s tant que des push attendent
 * (10 min au plus), et [Arrêter les envois restants], qui garde les entrées
 * d'inbox et ne retient que les push pas encore partis.
 */

type Phase = 'countdown' | 'cancelled' | 'gone' | 'report';

const cardStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  padding: 14,
  borderRadius: 14,
  border: '1px solid var(--border)',
  background: 'var(--surface)',
};

const lineStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-sm)',
  lineHeight: 1.5,
};

export interface OpeningScheduledCardProps {
  scholarshipId: string;
  cycleId: string;
  academicYear: string;
  /** Heure d'envoi donnée par le serveur ; `null` = rapport d'un envoi passé. */
  fanoutAt: string | null;
  /** La même échéance sur l'horloge du poste (`localFanoutDeadline`). */
  deadlineMs: number | null;
  holdSeconds: number;
  /** Le nombre annoncé à la programmation, s'il est connu. */
  toNotify: number | null;
  /** Annulé, arrêté ou parti : la page relit l'aperçu et les listes. */
  onChanged: () => void;
  onHide?: () => void;
}

export function OpeningScheduledCard({
  scholarshipId,
  cycleId,
  academicYear,
  fanoutAt,
  deadlineMs,
  holdSeconds,
  toNotify,
  onChanged,
  onHide,
}: OpeningScheduledCardProps) {
  const { t } = useLocale();
  const [now, setNow] = useState(() => Date.now());
  const [phase, setPhase] = useState<Phase>(() =>
    fanoutAt && deadlineMs !== null && deadlineMs > Date.now()
      ? 'countdown'
      : 'report',
  );
  const [report, setReport] = useState<OpeningReportResponse | null>(null);
  const [reportError, setReportError] = useState<string | null>(null);
  const [polling, setPolling] = useState(false);
  const [pollToken, setPollToken] = useState(0);
  const [busy, setBusy] = useState<'cancel' | 'stop' | null>(null);
  const [stopConfirm, setStopConfirm] = useState(false);
  const [message, setMessage] = useState<{
    variant: AlertVariant;
    text: string;
  } | null>(null);

  // Compte à rebours : une seconde à la fois, puis bascule sur le rapport.
  useEffect(() => {
    if (phase !== 'countdown' || deadlineMs === null) return;
    const timer = setInterval(() => {
      const current = Date.now();
      setNow(current);
      if (current >= deadlineMs) {
        setPhase('report');
        // L'envoi est parti : la colonne « Annoncé » et « À faire » changent.
        onChanged();
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [phase, deadlineMs, onChanged]);

  // Rapport : lu tout de suite, puis toutes les 5 s tant que des push
  // attendent ; [Actualiser] relance un cycle de 10 minutes.
  useEffect(() => {
    if (phase !== 'report') return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const startedAt = Date.now();

    async function tick() {
      let next: OpeningReportResponse | null = null;
      try {
        next = await fetchOpeningReport(scholarshipId, cycleId);
        if (cancelled) return;
        setReport(next);
        setReportError(null);
      } catch (error) {
        if (cancelled) return;
        setReportError(
          error instanceof Error && error.message
            ? error.message
            : t('scholarships.opening.reportError'),
        );
      }
      if (shouldPollReport(next, startedAt, Date.now())) {
        setPolling(true);
        timer = setTimeout(() => void tick(), REPORT_POLL_INTERVAL_MS);
      } else {
        setPolling(false);
      }
    }

    void tick();
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [phase, pollToken, scholarshipId, cycleId, t]);

  async function cancel() {
    setBusy('cancel');
    setMessage(null);
    try {
      await cancelOpening(scholarshipId, cycleId);
      setPhase('cancelled');
      onChanged();
    } catch (error) {
      const parsed = apiErrorCode(error);
      if (parsed.code === 'OPENING_NOT_SCHEDULED' && fanoutAt) {
        const key = cancelConflictMessageKey(error, fanoutAt, holdSeconds);
        setMessage({ variant: 'warning', text: t(key) });
        setPhase(key === 'scholarships.opening.tooLateToCancel' ? 'report' : 'gone');
        onChanged();
      } else {
        setMessage({
          variant: 'danger',
          text: parsed.message || t('scholarships.opening.cancelError'),
        });
      }
    } finally {
      setBusy(null);
    }
  }

  async function stop() {
    setBusy('stop');
    setMessage(null);
    try {
      const result = await stopOpening(scholarshipId, cycleId);
      setMessage({
        variant: 'success',
        text: fill(t('scholarships.opening.stopped'), {
          n: result.stopped,
          inFlight: result.inFlight,
        }),
      });
      setPollToken((value) => value + 1);
      onChanged();
    } catch (error) {
      setMessage({
        variant: 'danger',
        text: apiErrorCode(error).message || t('scholarships.opening.stopError'),
      });
    } finally {
      setBusy(null);
      setStopConfirm(false);
    }
  }

  const remaining = deadlineMs === null ? 0 : secondsUntil(deadlineMs, now);
  // Annulé ou introuvable : seule l'alerte parle, la ligne « programmées à »
  // serait démentie juste en dessous.
  const heading =
    phase === 'countdown'
      ? toNotify === null
        ? fill(t('scholarships.opening.scheduledLineNoCount'), {
            time: formatTime(fanoutAt),
          })
        : fill(t('scholarships.opening.scheduledLine'), {
            n: toNotify,
            time: formatTime(fanoutAt),
          })
      : phase === 'report'
        ? `${t('scholarships.opening.reportTitle')} · ${academicYear}`
        : null;

  return (
    <section style={cardStyle} aria-live="polite">
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 8,
          flexWrap: 'wrap',
        }}
      >
        {heading ? (
          <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
            {heading}
          </strong>
        ) : (
          <span />
        )}
        {onHide && phase !== 'countdown' ? (
          <Button size="sm" variant="ghost" onClick={onHide}>
            {t('scholarships.opening.hideCta')}
          </Button>
        ) : null}
      </div>

      {phase === 'countdown' ? (
        <>
          <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
            {t('scholarships.opening.scheduledHint')}
          </p>
          <div>
            <Button
              variant="dangerOutline"
              loading={busy === 'cancel'}
              onClick={() => void cancel()}
            >
              {fill(t('scholarships.opening.cancelCta'), {
                time: formatCountdown(remaining),
              })}
            </Button>
          </div>
        </>
      ) : null}

      {phase === 'cancelled' ? (
        <Alert variant="success">{t('scholarships.opening.cancelled')}</Alert>
      ) : null}

      {message ? <Alert variant={message.variant}>{message.text}</Alert> : null}

      {phase === 'report' ? (
        <div style={{ display: 'grid', gap: 6 }}>
          {reportError ? <Alert variant="warning">{reportError}</Alert> : null}
          {report === null ? (
            reportError ? null : (
              <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                {t('scholarships.opening.reportLoading')}
              </p>
            )
          ) : (
            <>
              {report.fanout.scheduledAt !== null ? (
                <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                  {t('scholarships.opening.fanoutPending')}
                </p>
              ) : null}
              <p style={{ ...lineStyle, fontWeight: 700 }}>
                {formatReportLine(report, t)}
              </p>
              {reportDeferredDetail(report, t) ? (
                <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                  {reportDeferredDetail(report, t)}
                </p>
              ) : null}
              <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                {reportProvidersLine(report, t)}
              </p>
              {report.push.untracked > 0 ? (
                <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                  {fill(t('scholarships.opening.reportUntracked'), {
                    n: report.push.untracked,
                  })}
                </p>
              ) : null}
              <p style={{ ...lineStyle, fontSize: 'var(--text-xs)', color: 'var(--text-faint)' }}>
                {fill(t('scholarships.opening.reportUpdatedAt'), {
                  time: formatTime(report.generatedAt),
                })}
              </p>
            </>
          )}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {!polling ? (
              <Button
                size="sm"
                variant="secondary"
                onClick={() => setPollToken((value) => value + 1)}
              >
                {t('scholarships.opening.reportRefresh')}
              </Button>
            ) : null}
            {report && report.push.pending > 0 ? (
              <Button
                size="sm"
                variant="dangerOutline"
                loading={busy === 'stop'}
                onClick={() => setStopConfirm(true)}
              >
                {t('scholarships.opening.stopCta')}
              </Button>
            ) : null}
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={stopConfirm}
        title={t('scholarships.opening.stopConfirmTitle')}
        description={t('scholarships.opening.stopConfirm')}
        confirmLabel={t('scholarships.opening.stopConfirmCta')}
        cancelLabel={t('scholarships.opening.closeCta')}
        variant="danger"
        loading={busy === 'stop'}
        onConfirm={() => void stop()}
        onCancel={() => setStopConfirm(false)}
      />
    </section>
  );
}
