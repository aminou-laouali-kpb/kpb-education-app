'use client';

import { CSSProperties, useEffect, useRef, useState } from 'react';

import {
  apiErrorCode,
  canCancelScheduled,
  cancelConflictMessageKey,
  fill,
  formatCountdown,
  formatReportLine,
  formatTime,
  openingErrorText,
  REPORT_POLL_INTERVAL_MS,
  reportDeferredDetail,
  reportProvidersLine,
  scheduledCardAnnouncement,
  scheduledCardChanged,
  scheduledCardStatus,
  secondsUntil,
  shouldPollReport,
  type ScheduledCardPhase,
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
 * eux. À l'heure dite sur le poste, l'envoi n'est pas forcément parti (file du
 * worker, interrupteur coupé, horloge du poste en avance) : la carte affiche
 * « En attente d'envoi » et garde [Annuler l'envoi] tant que le serveur ne
 * rapporte pas l'envoi commencé — il accepte l'annulation jusque-là. Ensuite :
 * le rapport, relu toutes les 5 s tant que des push attendent (10 min au
 * plus), et [Arrêter les envois restants], qui garde les entrées d'inbox et
 * ne retient que les push pas encore partis.
 *
 * Lecteurs d'écran : seule une région dédiée annonce les CHANGEMENTS d'état
 * (programmé, en attente d'envoi, annulé, commencé) ; ni le compte à rebours
 * de chaque seconde ni les chiffres relus du rapport n'y passent.
 */

const srOnlyStyle: CSSProperties = {
  position: 'absolute',
  width: 1,
  height: 1,
  margin: -1,
  padding: 0,
  overflow: 'hidden',
  clip: 'rect(0 0 0 0)',
  whiteSpace: 'nowrap',
  border: 0,
};

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
  const [phase, setPhase] = useState<ScheduledCardPhase>(() =>
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
  // Annulation refusée « trop tard » : l'envoi a commencé, même si le
  // dernier rapport lu le montrait encore programmé.
  const [fanoutStarted, setFanoutStarted] = useState(false);

  // Compte à rebours : une seconde à la fois, puis bascule sur le rapport,
  // qui dit si l'envoi a réellement commencé (« En attente d'envoi » sinon).
  useEffect(() => {
    if (phase !== 'countdown' || deadlineMs === null) return;
    const timer = setInterval(() => {
      const current = Date.now();
      setNow(current);
      if (current >= deadlineMs) setPhase('report');
    }, 1000);
    return () => clearInterval(timer);
  }, [phase, deadlineMs]);

  const status = scheduledCardStatus({
    phase,
    scheduled: fanoutAt !== null,
    report,
    fanoutStarted,
  });

  // L'envoi a commencé côté serveur : la colonne « Annoncé » et « À faire »
  // changent. Pas avant : à zéro sur le poste, l'envoi peut encore attendre.
  const previousStatus = useRef(status);
  useEffect(() => {
    const before = previousStatus.current;
    previousStatus.current = status;
    if (scheduledCardChanged(before, status)) onChanged();
  }, [status, onChanged]);

  // La région `aria-live` est rendue vide, puis remplie : un texte présent
  // dès l'insertion n'est pas lu par tous les lecteurs d'écran.
  const announcement = scheduledCardAnnouncement(status, { toNotify, fanoutAt }, t);
  const [liveText, setLiveText] = useState('');
  useEffect(() => {
    setLiveText(announcement);
  }, [announcement]);

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
        if (key === 'scholarships.opening.tooLateToCancel') {
          // L'envoi a commencé : le statut passe à « commencé » (les listes
          // sont relues à ce moment-là) et le rapport est relu tout de suite.
          setFanoutStarted(true);
          setPhase('report');
          setPollToken((value) => value + 1);
        } else {
          setPhase('gone');
          onChanged();
        }
      } else {
        // 409 OPENING_BUSY : le worker tient le cycle (envoi en préparation)
        // depuis plus de 5 s. Réessayer quelques secondes plus tard répond
        // OPENING_NOT_SCHEDULED, traité ci-dessus.
        setMessage({
          variant: parsed.code === 'OPENING_BUSY' ? 'warning' : 'danger',
          text: openingErrorText(error, t, t('scholarships.opening.cancelError')),
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
  const cancellable = canCancelScheduled(status);
  // Annulé ou introuvable : seule l'alerte parle, la ligne « programmées à »
  // serait démentie juste en dessous.
  const heading =
    status === 'scheduled'
      ? toNotify === null
        ? fill(t('scholarships.opening.scheduledLineNoCount'), {
            time: formatTime(fanoutAt),
          })
        : fill(t('scholarships.opening.scheduledLine'), {
            n: toNotify,
            time: formatTime(fanoutAt),
          })
      : status === 'awaiting'
        ? `${t('scholarships.opening.awaitingTitle')} · ${academicYear}`
        : status === 'started' || status === 'report'
          ? `${t('scholarships.opening.reportTitle')} · ${academicYear}`
          : null;

  return (
    <section style={cardStyle}>
      <p role="status" aria-live="polite" aria-atomic="true" style={srOnlyStyle}>
        {liveText}
      </p>
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
        {onHide && !cancellable ? (
          <Button size="sm" variant="ghost" onClick={onHide}>
            {t('scholarships.opening.hideCta')}
          </Button>
        ) : null}
      </div>

      {cancellable ? (
        <>
          <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
            {status === 'scheduled'
              ? t('scholarships.opening.scheduledHint')
              : t('scholarships.opening.awaitingHint')}
          </p>
          <div>
            <Button
              variant="dangerOutline"
              loading={busy === 'cancel'}
              // Nom accessible fixe : le compte à rebours visible change
              // chaque seconde et ne doit pas être relu sur le bouton.
              aria-label={t('scholarships.opening.cancelCtaShort')}
              onClick={() => void cancel()}
            >
              {status === 'scheduled'
                ? fill(t('scholarships.opening.cancelCta'), {
                    time: formatCountdown(remaining),
                  })
                : t('scholarships.opening.cancelCtaShort')}
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
          {status === 'awaiting' ? null : report === null ? (
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
