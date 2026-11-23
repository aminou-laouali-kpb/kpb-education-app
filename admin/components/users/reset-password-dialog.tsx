'use client';

import { useLocale } from '../locale-provider';
import { ConfirmDialog } from '../ui';

export interface ResetPasswordTarget {
  id: string;
  fullName: string;
  email: string;
}

interface ResetPasswordDialogProps {
  /** Compte visé ; `null` = dialogue fermé. */
  target: ResetPasswordTarget | null;
  /** Vrai quand l'admin connecté vise son propre compte. */
  isSelf: boolean;
  loading: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Confirmation avant de réinitialiser le mot de passe d'un membre de l'équipe :
 * l'ancien mot de passe est écrasé et la session de rafraîchissement révoquée
 * tout de suite, sans retour arrière. Le dialogue nomme le compte visé et
 * prévient en plus quand l'admin se vise lui-même.
 */
export function ResetPasswordDialog({
  target,
  isSelf,
  loading,
  onConfirm,
  onCancel,
}: ResetPasswordDialogProps) {
  const { t } = useLocale();
  if (!target) return null;
  const description = [
    t('users.resetConfirmBody').replace('{email}', target.email),
    isSelf ? t('users.resetConfirmSelf') : null,
  ]
    .filter(Boolean)
    .join(' ');
  return (
    <ConfirmDialog
      open
      variant="danger"
      title={t('users.resetConfirmTitle').replace('{name}', target.fullName)}
      description={description}
      confirmLabel={t('users.resetConfirmCta')}
      cancelLabel={t('users.resetCancelCta')}
      loading={loading}
      onConfirm={onConfirm}
      onCancel={onCancel}
    />
  );
}
