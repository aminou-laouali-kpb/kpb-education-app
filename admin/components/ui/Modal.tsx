'use client';

import { ReactNode, useId, useRef } from 'react';
import { createPortal } from 'react-dom';

import { cx } from './cx';
import { useCanPortal, useModalLayer } from './modal-layer';
import styles from './ui.module.css';

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
   * `false` keeps Escape from closing this dialog. Escape only ever acts on
   * the topmost dialog, so a ConfirmDialog opened on top no longer needs it.
   */
  closeOnEscape?: boolean;
}

/**
 * General-purpose accessible modal (role=dialog + aria-modal, labelled by its
 * title), rendered in a portal on `<body>`.
 *
 * While open, the rest of the page is `inert`: nothing behind the overlay can
 * be clicked, focused or read (e.g. the panel buttons that opened it). Focus
 * moves to the first focusable element, Tab and Shift+Tab cycle inside the
 * dialog, Escape and an overlay click close it unless `busy`, and the focus
 * returns to the previously focused element on close. The body scrolls, the
 * title and footer stay visible.
 *
 * A ConfirmDialog opened from inside should be rendered as a sibling, not a
 * child: React events bubble through the component tree (portals included),
 * so a click on the confirm overlay would otherwise also reach this overlay.
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
  const overlayRef = useRef<HTMLDivElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  // An overlay click only counts when the press also started on the overlay:
  // a text selection dragged out of the dialog must not close it.
  const pressedOnOverlay = useRef(false);
  const titleId = useId();
  const canPortal = useCanPortal();

  useModalLayer({
    open,
    layerRef: overlayRef,
    dialogRef,
    onEscape: closeOnEscape && !busy ? onClose : undefined,
    mountKey: canPortal,
  });

  if (!open) return null;

  const overlay = (
    <div
      ref={overlayRef}
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

  return canPortal ? createPortal(overlay, document.body) : overlay;
}
