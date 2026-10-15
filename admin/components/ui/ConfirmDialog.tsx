'use client';

import { ReactNode, useId, useRef } from 'react';
import { createPortal } from 'react-dom';

import { Button } from './Button';
import { useCanPortal, useModalLayer } from './modal-layer';
import styles from './ui.module.css';

export interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description?: string;
  /**
   * Extra content between the description and the actions (e.g. a typed
   * confirmation field). When the confirm button starts disabled, the first
   * field takes the initial focus (a disabled button cannot): no `autoFocus`
   * needed, and none wanted — it would move the focus before the dialog can
   * remember where to give it back.
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

const FIELD_SELECTOR = 'input:not([disabled]), select:not([disabled]), textarea:not([disabled])';

/**
 * Accessible confirmation modal for destructive/irreversible actions
 * (role=dialog + aria-modal), rendered in a portal on `<body>` with the rest
 * of the page — including a Modal it was opened from — made `inert` while it
 * is open. Focus moves to the confirm button on open (to the first field when
 * the button starts disabled), Tab cycles inside, Escape and an overlay click
 * cancel, and the focus returns where it was on close.
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
  const overlayRef = useRef<HTMLDivElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const confirmRef = useRef<HTMLButtonElement>(null);
  const titleId = useId();
  const canPortal = useCanPortal();

  // Initial focus on open only (the hook reads it once): re-running it on a
  // later render (a keystroke in `children`) would pull the focus out of a
  // field the user is typing in as soon as the button becomes enabled.
  useModalLayer({
    open,
    layerRef: overlayRef,
    dialogRef,
    initialFocus: () =>
      confirmRef.current && !confirmRef.current.disabled
        ? confirmRef.current
        : (dialogRef.current?.querySelector<HTMLElement>(FIELD_SELECTOR) ?? null),
    onEscape: loading ? undefined : onCancel,
    mountKey: canPortal,
  });

  if (!open) return null;

  const overlay = (
    <div
      ref={overlayRef}
      className={styles.overlay}
      onClick={() => {
        if (!loading) onCancel();
      }}
    >
      <div
        ref={dialogRef}
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
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

  return canPortal ? createPortal(overlay, document.body) : overlay;
}
