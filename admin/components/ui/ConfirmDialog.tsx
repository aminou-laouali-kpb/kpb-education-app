'use client';

import { ReactNode, useEffect, useId, useRef } from 'react';

import { Button } from './Button';
import styles from './ui.module.css';

export interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description?: string;
  /**
   * Extra content between the description and the actions (e.g. a typed
   * confirmation field). Give its input `autoFocus` when the confirm button
   * starts disabled: a disabled button cannot take the initial focus.
   */
  children?: ReactNode;
  confirmLabel: string;
  cancelLabel: string;
  variant?: 'danger' | 'primary';
  loading?: boolean;
  /** Keeps the confirm button disabled (e.g. until the typed value matches). */
  confirmDisabled?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Accessible confirmation modal for destructive/irreversible actions
 * (role=dialog + aria-modal, Escape to cancel, overlay click to cancel,
 * focus moves to the confirm button on open).
 */
export function ConfirmDialog({
  open,
  title,
  description,
  children,
  confirmLabel,
  cancelLabel,
  variant = 'primary',
  loading = false,
  confirmDisabled = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const confirmRef = useRef<HTMLButtonElement>(null);
  const titleId = useId();

  // Initial focus on open only: re-running it on every render (a new
  // `onCancel` identity, a keystroke in `children`) would pull the focus out
  // of a field the user is typing in as soon as the button becomes enabled.
  useEffect(() => {
    if (open) confirmRef.current?.focus();
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape' && !loading) onCancel();
    }
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, loading, onCancel]);

  if (!open) return null;

  return (
    <div
      className={styles.overlay}
      onClick={() => {
        if (!loading) onCancel();
      }}
    >
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onClick={(event) => event.stopPropagation()}
      >
        <h2 id={titleId} className={styles.dialogTitle}>
          {title}
        </h2>
        {description ? <p className={styles.dialogDesc}>{description}</p> : null}
        {children}
        <div className={styles.dialogActions}>
          <Button variant="secondary" onClick={onCancel} disabled={loading}>
            {cancelLabel}
          </Button>
          <Button
            ref={confirmRef}
            variant={variant === 'danger' ? 'danger' : 'primary'}
            loading={loading}
            disabled={confirmDisabled}
            onClick={onConfirm}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
