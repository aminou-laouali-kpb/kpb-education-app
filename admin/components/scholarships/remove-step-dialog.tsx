'use client';

import { useLocale } from '../locale-provider';
import { ConfirmDialog } from '../ui';
import type { ScholarshipEntry, ScholarshipStepEntry } from './types';

export interface RemoveStepTarget {
  entry: Pick<ScholarshipEntry, 'id' | 'nameFr' | 'nameEn'>;
  step: Pick<ScholarshipStepEntry, 'id' | 'stepNumber' | 'titleFr' | 'titleEn'>;
}

interface RemoveStepDialogProps {
  /** Étape visée ; `null` = dialogue fermé. */
  target: RemoveStepTarget | null;
  loading: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Confirmation avant de retirer une étape de candidature d'une bourse : la
 * suppression est définitive côté API, le dialogue nomme donc l'étape et la
 * bourse visées.
 */
export function RemoveStepDialog({ target, loading, onConfirm, onCancel }: RemoveStepDialogProps) {
  const { t, locale } = useLocale();
  if (!target) return null;
  const { entry, step } = target;
  const stepTitle = (locale === 'en' ? step.titleEn : step.titleFr) || step.titleFr;
  const scholarship = (locale === 'en' ? entry.nameEn : entry.nameFr) || entry.nameFr;
  return (
    <ConfirmDialog
      open
      variant="danger"
      title={t('scholarships.removeStepConfirmTitle')
        .replace('{number}', String(step.stepNumber))
        .replace('{step}', stepTitle)}
      description={t('scholarships.removeStepConfirmBody').replace('{scholarship}', scholarship)}
      confirmLabel={t('scholarships.removeStepCta')}
      cancelLabel={t('scholarships.removeStepCancelCta')}
      loading={loading}
      onConfirm={onConfirm}
      onCancel={onCancel}
    />
  );
}
