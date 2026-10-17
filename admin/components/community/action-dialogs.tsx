'use client';

import { ReactNode, useEffect, useState } from 'react';

import {
  actionNotifiesAuthor,
  buildSanctionPayload,
  type ContentAction,
  REASON_MAX,
  type SanctionKind,
  type SanctionPayload,
  validateReason,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, ConfirmDialog, Field, Input, Select, Textarea } from '../ui';
import { errorText, fill } from './shared';

/**
 * Confirmation avec motif obligatoire (contrat §4.2 : 3 à 500 caractères).
 * Le bouton reste désactivé tant que le motif n'est pas valide ; l'erreur du
 * serveur s'affiche dans la boîte, qui reste ouverte pour corriger.
 */
export function ReasonDialog({
  open,
  title,
  description,
  confirmLabel,
  variant = 'primary',
  extra,
  extraValid = true,
  onConfirm,
  onCancel,
}: Readonly<{
  open: boolean;
  title: string;
  description?: string;
  confirmLabel: string;
  variant?: 'primary' | 'danger';
  /** Champs en plus du motif (durée, case à cocher…). */
  extra?: ReactNode;
  extraValid?: boolean;
  onConfirm: (reason: string) => Promise<void>;
  onCancel: () => void;
}>) {
  const { t } = useLocale();
  const [reason, setReason] = useState('');
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setReason('');
      setTouched(false);
      setServerError(null);
      setBusy(false);
    }
  }, [open]);

  const reasonError = validateReason(reason);

  async function confirm() {
    setTouched(true);
    if (reasonError || !extraValid) return;
    setBusy(true);
    setServerError(null);
    try {
      await onConfirm(reason.trim());
    } catch (e) {
      setServerError(errorText(t, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      open={open}
      title={title}
      description={description}
      confirmLabel={confirmLabel}
      cancelLabel={t('communityAdmin.cancel')}
      variant={variant}
      loading={busy}
      confirmDisabled={Boolean(reasonError) || !extraValid}
      onConfirm={() => void confirm()}
      onCancel={onCancel}
    >
      <div style={{ display: 'grid', gap: 10, margin: '8px 0' }}>
        {serverError ? <Alert variant="danger">{serverError}</Alert> : null}
        {extra}
        <Field
          label={t('communityAdmin.reasonLabel')}
          error={touched && reasonError ? t(`communityAdmin.errors.${reasonError}`) : undefined}
        >
          {({ id, invalid }) => (
            <Textarea
              id={id}
              required
              aria-required="true"
              invalid={invalid}
              maxLength={REASON_MAX}
              placeholder={t('communityAdmin.reasonPlaceholder')}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              onBlur={() => setTouched(true)}
            />
          )}
        </Field>
      </div>
    </ConfirmDialog>
  );
}

/** Rétablir / masquer / supprimer / classer les signalements d'un contenu (§8.4). */
export function ContentActionDialog({
  action,
  targetLabel,
  onConfirm,
  onCancel,
}: Readonly<{
  action: ContentAction | null;
  targetLabel: string;
  onConfirm: (input: { action: ContentAction; reason: string; notifyAuthor: boolean }) => Promise<void>;
  onCancel: () => void;
}>) {
  const { t } = useLocale();
  const [notify, setNotify] = useState(true);
  useEffect(() => {
    if (action) setNotify(true);
  }, [action]);
  const current = action ?? 'hide';
  return (
    <ReasonDialog
      open={action !== null}
      title={fill(t(`communityAdmin.action.${current}.title`), { target: targetLabel })}
      description={t(`communityAdmin.action.${current}.body`)}
      confirmLabel={t(`communityAdmin.action.${current}.cta`)}
      variant={current === 'delete' || current === 'hide' ? 'danger' : 'primary'}
      extra={
        actionNotifiesAuthor(current) ? (
          <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 'var(--text-sm)' }}>
            <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} />
            {t('communityAdmin.notifyAuthor')}
          </label>
        ) : null
      }
      onConfirm={(reason) => onConfirm({ action: current, reason, notifyAuthor: notify })}
      onCancel={onCancel}
    />
  );
}

/** Avertir / lecture seule N jours / bannir (§8.5). */
export function SanctionDialog({
  kind,
  memberName,
  onConfirm,
  onCancel,
}: Readonly<{
  kind: SanctionKind | null;
  memberName: string;
  onConfirm: (body: SanctionPayload) => Promise<void>;
  onCancel: () => void;
}>) {
  const { t } = useLocale();
  const [selected, setSelected] = useState<SanctionKind>('warning');
  const [durationDays, setDurationDays] = useState('7');
  const [hideContent, setHideContent] = useState(false);

  useEffect(() => {
    if (kind) {
      setSelected(kind);
      setDurationDays('7');
      setHideContent(false);
    }
  }, [kind]);

  // Le motif est validé par ReasonDialog ; ici, la durée seule.
  const durationCheck = buildSanctionPayload({ kind: selected, reason: 'xxx', durationDays, hideContent });
  const durationError = !durationCheck.ok ? durationCheck.errors.durationDays : undefined;

  return (
    <ReasonDialog
      open={kind !== null}
      title={fill(t(`communityAdmin.sanction.${selected}.title`), { member: memberName })}
      description={t(`communityAdmin.sanction.${selected}.body`)}
      confirmLabel={t(`communityAdmin.sanction.${selected}.cta`)}
      variant={selected === 'warning' ? 'primary' : 'danger'}
      extraValid={!durationError}
      extra={
        <>
          <Field label={t('communityAdmin.sanction.kindLabel')}>
            {({ id }) => (
              <Select id={id} value={selected} onChange={(e) => setSelected(e.target.value as SanctionKind)}>
                {(['warning', 'read_only', 'ban'] as const).map((k) => (
                  <option key={k} value={k}>
                    {t(`communityAdmin.enum.sanction.${k}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          {selected === 'read_only' ? (
            <Field
              label={t('communityAdmin.sanction.durationLabel')}
              error={durationError ? t(`communityAdmin.errors.${durationError}`) : undefined}
            >
              {({ id, invalid }) => (
                <Input
                  id={id}
                  type="number"
                  min={1}
                  max={365}
                  invalid={invalid}
                  value={durationDays}
                  onChange={(e) => setDurationDays(e.target.value)}
                />
              )}
            </Field>
          ) : null}
          {selected === 'ban' ? (
            <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 'var(--text-sm)' }}>
              <input type="checkbox" checked={hideContent} onChange={(e) => setHideContent(e.target.checked)} />
              {t('communityAdmin.sanction.hideContent')}
            </label>
          ) : null}
        </>
      }
      onConfirm={async (reason) => {
        const built = buildSanctionPayload({ kind: selected, reason, durationDays, hideContent });
        if (!built.ok) throw new Error(t('communityAdmin.errors.durationInvalid'));
        await onConfirm(built.body);
      }}
      onCancel={onCancel}
    />
  );
}
