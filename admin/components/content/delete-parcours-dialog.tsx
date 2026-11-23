'use client';

import { useLocale } from '../locale-provider';
import { ConfirmDialog } from '../ui';

export interface DeleteParcoursTarget {
  id: string;
  personName: string;
  title: { fr: string; en: string };
}

interface DeleteParcoursDialogProps {
  /** Témoignage visé ; `null` = dialogue fermé. */
  target: DeleteParcoursTarget | null;
  loading: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Confirmation avant de supprimer un témoignage Parcours : la suppression est
 * physique côté API (pas de corbeille), le dialogue nomme donc la fiche visée.
 */
export function DeleteParcoursDialog({
  target,
  loading,
  onConfirm,
  onCancel,
}: DeleteParcoursDialogProps) {
  const { t, locale } = useLocale();
  if (!target) return null;
  const title = (locale === 'en' ? target.title.en : target.title.fr) || target.title.fr;
  return (
    <ConfirmDialog
      open
      variant="danger"
      title={t('content.parcoursDeleteConfirmTitle').replace('{title}', title)}
      description={t('content.parcoursDeleteConfirmBody').replace(
        '{name}',
        target.personName,
      )}
      confirmLabel={t('content.deleteCta')}
      cancelLabel={t('content.cancelCta')}
      loading={loading}
      onConfirm={onConfirm}
      onCancel={onCancel}
    />
  );
}
