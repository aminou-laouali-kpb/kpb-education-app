'use client';

import { ReactNode, useEffect, useId, useRef } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

/** What can take keyboard focus inside the dialog, in DOM order. */
const FOCUSABLE = [
  'button:not([disabled])',
  '[href]',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

export interface ModalProps {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  /** Action row under the scrollable body (e.g. [Cancel] [Continue]). */
  footer?: ReactNode;
  /** `lg` widens the dialog to 760px for previews and reports. */
  size?: 'md' | 'lg';
  /** While true, neither Escape nor an overlay click closes the dialog. */
  busy?: boolean;
  /**
   * Pass `false` while a ConfirmDialog is open on top: both listen to Escape,
   * and one key press must only close the topmost dialog.
   */
  closeOnEscape?: boolean;
}

/**
 * General-purpose accessible modal (role=dialog + aria-modal, labelled by its
 * title). Focus moves to the first focusable element on open and returns to
 * the previously focused element on close; Escape and an overlay click close
 * it unless `busy`. The body scrolls, the title and footer stay visible.
 *
 * A ConfirmDialog opened from inside should be rendered as a sibling, not a
 * child: React events bubble through the component tree, so a click on the
 * confirm overlay would otherwise also reach this overlay.
 */
export function Modal({
  open,
  title,
  onClose,
  children,
  footer,
  size = 'md',
  busy = false,
  closeOnEscape = true,
}: ModalProps) {
  const dialogRef = useRef<HTMLDivElement>(null);
  // An overlay click only counts when the press also started on the overlay:
  // a text selection dragged out of the dialog must not close it.
  const pressedOnOverlay = useRef(false);
  const titleId = useId();

  useEffect(() => {
    if (!open) return;
    const previous =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    const dialog = dialogRef.current;
    const first = dialog?.querySelector<HTMLElement>(FOCUSABLE);
    (first ?? dialog)?.focus();
    return () => previous?.focus();
  }, [open]);

  useEffect(() => {
    if (!open || !closeOnEscape) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape' && !busy) onClose();
    }
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, closeOnEscape, busy, onClose]);

  if (!open) return null;

  return (
    <div
      className={styles.modalOverlay}
      onMouseDown={(event) => {
        pressedOnOverlay.current = event.target === event.currentTarget;
      }}
      onClick={(event) => {
        if (
          pressedOnOverlay.current &&
          event.target === event.currentTarget &&
          !busy
        ) {
          onClose();
        }
        pressedOnOverlay.current = false;
      }}
    >
      <div
        ref={dialogRef}
        className={cx(styles.modal, size === 'lg' && styles.modalLg)}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-busy={busy || undefined}
        tabIndex={-1}
      >
        <h2 id={titleId} className={styles.dialogTitle}>
          {title}
        </h2>
        <div className={styles.modalBody}>{children}</div>
        {footer ? <div className={styles.dialogActions}>{footer}</div> : null}
      </div>
    </div>
  );
}
