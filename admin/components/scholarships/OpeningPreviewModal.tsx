'use client';

import { CSSProperties, useEffect, useState } from 'react';

import {
  audienceLines,
  fill,
  isTypedConfirmationValid,
  needsTypedConfirmation,
  previewBanners,
  primaryAction,
} from '../../lib/scholarship-opening';
import type { OpeningPreviewResponse } from '../../lib/scholarship-opening-types';
import { useLocale } from '../locale-provider';
import { Alert, Button, ConfirmDialog, Field, Input, Modal } from '../ui';
import { PhonePreview } from './PhonePreview';

/**
 * Aperçu d'une annonce d'ouverture, puis confirmation.
 *
 * Ce que l'équipe lit avant d'envoyer : les avertissements (mode, envois
 * suspendus, cycle déjà annoncé ou pré-existant), la complétude de la fiche,
 * qui sera prévenu et comment (push, heures calmes, rythme, versions de
 * l'app), et le texte exact sur un téléphone. [Continuer] ouvre une
 * confirmation qui répète le nombre ; au-delà du seuil, il faut le saisir.
 * Le nombre confirmé part en `expectedRecipients` : si l'audience a grossi
 * depuis, le serveur refuse au lieu d'écrire à plus d'étudiants.
 */

const sectionTitleStyle: CSSProperties = {
  margin: 0,
  fontSize: 9.5,
  fontWeight: 800,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  color: 'var(--text-faint)',
};

const lineStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-sm)',
  lineHeight: 1.5,
};

/** « 2 min » pour 120 s, « 45 s » sinon. */
function holdDelay(holdSeconds: number): string {
  return holdSeconds >= 60 && holdSeconds % 60 === 0
    ? `${holdSeconds / 60} min`
    : `${holdSeconds} s`;
}

export interface OpeningPreviewModalProps {
  open: boolean;
  preview: OpeningPreviewResponse | null;
  /** L'aperçu est en cours de recalcul : rien ne se confirme sur des chiffres périmés. */
  loading: boolean;
  /** Le dernier refus du serveur, affiché dans la fenêtre. */
  error: string | null;
  canSendAboveThreshold: boolean;
  submitting: boolean;
  onClose: () => void;
  /** Lance `activate {notify: true, expectedRecipients}` ; vrai si accepté. */
  onConfirm: (expectedRecipients: number) => Promise<boolean>;
}

export function OpeningPreviewModal({
  open,
  preview,
  loading,
  error,
  canSendAboveThreshold,
  submitting,
  onClose,
  onConfirm,
}: OpeningPreviewModalProps) {
  const { t, locale } = useLocale();
  const [confirmOpen, setConfirmOpen] = useState(false);
  // Le nombre répété et saisi est figé à l'ouverture de la confirmation : un
  // aperçu recalculé entre-temps ne doit pas changer ce qui est confirmé.
  const [confirmCount, setConfirmCount] = useState(0);
  const [typed, setTyped] = useState('');

  useEffect(() => {
    if (!open) setConfirmOpen(false);
  }, [open]);

  const name = preview ? (locale === 'en' ? preview.name.en : preview.name.fr) : '';
  const title = preview
    ? fill(t('scholarships.opening.previewTitle'), {
        name,
        year: preview.target.academicYear,
      })
    : t('scholarships.opening.previewLoading');
  const action = preview
    ? primaryAction(preview, { canSendAboveThreshold }, t)
    : null;
  const banners = preview ? previewBanners(preview, t) : [];
  const lines = preview ? audienceLines(preview.audience, t) : null;
  const typedRequired = preview
    ? needsTypedConfirmation(confirmCount, preview.confirmThreshold)
    : false;
  const continueDisabled =
    !preview || loading || submitting || action?.disabledReason !== null;

  function startConfirmation() {
    if (!preview || !action) return;
    if (action.kind === 'open_only') {
      // Personne à prévenir : rien à confirmer, l'ouverture part telle quelle.
      void onConfirm(0);
      return;
    }
    setConfirmCount(preview.audience.toNotify);
    setTyped('');
    setConfirmOpen(true);
  }

  async function confirm() {
    await onConfirm(confirmCount);
    setConfirmOpen(false);
  }

  return (
    <>
      <Modal
        open={open}
        title={title}
        size="lg"
        busy={submitting}
        closeOnEscape={!confirmOpen}
        onClose={onClose}
        footer={
          <>
            <Button variant="secondary" disabled={submitting} onClick={onClose}>
              {t('scholarships.opening.closeCta')}
            </Button>
            <Button
              variant="primary"
              loading={submitting && !confirmOpen}
              disabled={continueDisabled}
              onClick={startConfirmation}
            >
              {action?.kind === 'open_only'
                ? t('scholarships.opening.openOnlyCta')
                : t('scholarships.opening.continueCta')}
            </Button>
          </>
        }
      >
        {!preview ? (
          <p style={lineStyle}>{t('scholarships.opening.previewLoading')}</p>
        ) : (
          <>
            {loading ? (
              <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                {t('scholarships.opening.previewLoading')}
              </p>
            ) : null}
            {error ? <Alert variant="danger">{error}</Alert> : null}
            {banners.map((banner) => (
              <Alert key={banner.text} variant={banner.variant}>
                {banner.text}
              </Alert>
            ))}
            {action?.disabledReason &&
            !banners.some((banner) => banner.text === action.disabledReason) ? (
              <Alert variant="warning">{action.disabledReason}</Alert>
            ) : null}

            <section style={{ display: 'grid', gap: 6 }}>
              <h3 style={sectionTitleStyle}>
                {t('scholarships.opening.readinessTitle')}
              </h3>
              {preview.readiness.ready ? (
                <p style={lineStyle}>{t('scholarships.opening.readinessReady')}</p>
              ) : null}
              <ul style={{ margin: 0, paddingLeft: 0, listStyle: 'none', display: 'grid', gap: 4 }}>
                {preview.readiness.checks.map((check) => (
                  <li
                    key={check.code}
                    style={{
                      ...lineStyle,
                      color: check.passed ? 'var(--text)' : 'var(--danger-fg)',
                    }}
                  >
                    <span
                      role="img"
                      aria-label={
                        check.passed
                          ? t('scholarships.opening.checkPassed')
                          : t('scholarships.opening.checkFailed')
                      }
                    >
                      {check.passed ? '✓' : '✗'}
                    </span>{' '}
                    {locale === 'en' && check.labelEn ? check.labelEn : check.labelFr}
                  </li>
                ))}
              </ul>
            </section>

            {lines ? (
              <section style={{ display: 'grid', gap: 4 }}>
                <h3 style={sectionTitleStyle}>
                  {t('scholarships.opening.audienceTitle')}
                </h3>
                <p style={{ ...lineStyle, fontWeight: 700 }}>{lines.audience}</p>
                {lines.exclusions ? (
                  <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                    {lines.exclusions}
                  </p>
                ) : null}
                <p style={lineStyle}>{lines.delivery}</p>
                <p style={{ ...lineStyle, color: 'var(--text-muted)' }}>
                  {lines.devices} · {lines.languages}
                </p>
              </section>
            ) : null}

            <section style={{ display: 'grid', gap: 6 }}>
              <h3 style={sectionTitleStyle}>{t('scholarships.opening.phoneTitle')}</h3>
              <PhonePreview copy={preview.copy} scope={preview.scope} />
            </section>
          </>
        )}
      </Modal>

      {preview ? (
        <ConfirmDialog
          open={open && confirmOpen}
          title={fill(t('scholarships.opening.confirmTitle'), { n: confirmCount })}
          description={fill(
            preview.mode === 'legacy'
              ? t('scholarships.opening.confirmBodyLegacy')
              : t('scholarships.opening.confirmBody'),
            { n: confirmCount, name, delay: holdDelay(preview.holdSeconds) },
          )}
          confirmLabel={t('scholarships.opening.confirmCta')}
          cancelLabel={t('scholarships.opening.closeCta')}
          loading={submitting}
          confirmDisabled={
            typedRequired && !isTypedConfirmationValid(typed, confirmCount)
          }
          onConfirm={() => void confirm()}
          onCancel={() => setConfirmOpen(false)}
        >
          {typedRequired ? (
            <Field
              label={fill(t('scholarships.opening.typeToConfirm'), {
                n: confirmCount,
              })}
            >
              {({ id }) => (
                <Input
                  id={id}
                  // Le bouton de confirmation est désactivé à l'ouverture et ne
                  // peut donc pas prendre le focus : ConfirmDialog le donne à
                  // ce champ (sans `autoFocus`, qui le prendrait avant que la
                  // fenêtre ait noté où le rendre à la fermeture).
                  inputMode="numeric"
                  autoComplete="off"
                  value={typed}
                  onChange={(event) => setTyped(event.target.value)}
                />
              )}
            </Field>
          ) : null}
        </ConfirmDialog>
      ) : null}
    </>
  );
}
