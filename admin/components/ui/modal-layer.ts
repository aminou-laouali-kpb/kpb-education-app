'use client';

import { RefObject, useEffect, useRef, useSyncExternalStore } from 'react';

/**
 * Modal layers: what makes a dialog actually modal.
 *
 * `aria-modal="true"` alone only asks assistive technology to ignore the rest
 * of the page; a mouse click or the Tab key still reaches it. While a dialog
 * is open, everything outside the TOPMOST dialog is made `inert` (no click, no
 * focus, hidden from assistive technology): the siblings of the dialog and of
 * each of its ancestors, up to `<body>`. Dialogs are portalled to `<body>`, so
 * in practice the whole application root becomes inert. A ConfirmDialog
 * opened over a Modal becomes the new top layer: the Modal is inert under it,
 * and comes back when the confirmation closes.
 *
 * Only the `inert` attributes set here are removed again: an element that was
 * already inert for another reason stays inert.
 */

/** What can take keyboard focus inside a dialog, in DOM order. */
export const FOCUSABLE_SELECTOR = [
  'button:not([disabled])',
  'a[href]',
  'area[href]',
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'iframe',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

/** The few DOM members the background computation needs (testable without a DOM). */
export interface LayerNode<T extends LayerNode<T>> {
  readonly parentElement: T | null;
  readonly children: ArrayLike<T>;
}

/**
 * Everything that must not be reachable while `top` is the open dialog: the
 * siblings of `top` and of each of its ancestors, up to (and excluding)
 * `root`. `top`, its ancestors and its descendants are not returned.
 */
export function backgroundOf<T extends LayerNode<T>>(top: T, root: T): T[] {
  const background: T[] = [];
  let node = top;
  while (node !== root && node.parentElement) {
    const parent: T = node.parentElement;
    for (const sibling of Array.from(parent.children)) {
      if (sibling !== node) background.push(sibling);
    }
    node = parent;
  }
  return background;
}

/**
 * Tab and Shift+Tab cycle inside the dialog: the index to focus instead of
 * the browser's default move, or `null` when the default move stays inside.
 * `current` is the index of the focused element among the focusable ones
 * (`-1` when the focus is on the dialog itself or nowhere).
 */
export function wrappedFocusIndex(
  current: number,
  count: number,
  shiftKey: boolean,
): number | null {
  if (count === 0) return null;
  if (shiftKey) return current <= 0 ? count - 1 : null;
  return current === -1 || current >= count - 1 ? 0 : null;
}

const layers: HTMLElement[] = [];
const madeInert = new Set<Element>();

function applyInert(): void {
  for (const element of madeInert) element.removeAttribute('inert');
  madeInert.clear();
  const top = layers[layers.length - 1];
  if (!top || typeof document === 'undefined') return;
  for (const element of backgroundOf<Element>(top, document.body)) {
    if (element.hasAttribute('inert')) continue;
    element.setAttribute('inert', '');
    madeInert.add(element);
  }
}

/** Opens a layer: everything outside `element` becomes inert until the returned release. */
export function pushModalLayer(element: HTMLElement): () => void {
  layers.push(element);
  applyInert();
  return () => {
    const index = layers.lastIndexOf(element);
    if (index !== -1) layers.splice(index, 1);
    applyInert();
  };
}

/** Is `element` the topmost open dialog? Escape and Tab only act on that one. */
export function isTopModalLayer(element: HTMLElement | null): boolean {
  return element !== null && layers[layers.length - 1] === element;
}

function focusableIn(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
    (element) => !element.closest('[inert]') && element.getClientRects().length > 0,
  );
}

const noopSubscribe = () => () => {};

/**
 * `true` once the page runs in the browser after hydration. Dialogs render in
 * place on the server (and during hydration, so the markup matches), then in a
 * portal on `<body>`.
 */
export function useCanPortal(): boolean {
  return useSyncExternalStore(
    noopSubscribe,
    () => true,
    () => false,
  );
}

export interface ModalLayerOptions {
  open: boolean;
  /** The element that stays interactive: the overlay holding the dialog. */
  layerRef: RefObject<HTMLElement | null>;
  /** The dialog itself: Tab cycles inside it, it takes the focus as a last resort. */
  dialogRef: RefObject<HTMLElement | null>;
  /** Where the focus goes on open; the first focusable element otherwise. */
  initialFocus?: () => HTMLElement | null;
  /** Escape on the topmost dialog. `undefined` = Escape does nothing. */
  onEscape?: () => void;
  /** Changes when the layer element is re-created (portal switch). */
  mountKey?: unknown;
}

/**
 * The modal behaviour shared by `Modal` and `ConfirmDialog`: background made
 * inert, initial focus, Tab / Shift+Tab kept inside, Escape on the topmost
 * dialog only, and the focus given back to where it was on close.
 */
export function useModalLayer({
  open,
  layerRef,
  dialogRef,
  initialFocus,
  onEscape,
  mountKey,
}: ModalLayerOptions): void {
  // Read at key press / open time: a new callback identity on every render
  // must neither re-run the open effect nor steal the focus back.
  const initialFocusRef = useRef(initialFocus);
  initialFocusRef.current = initialFocus;
  const onEscapeRef = useRef(onEscape);
  onEscapeRef.current = onEscape;

  useEffect(() => {
    const layer = layerRef.current;
    const dialog = dialogRef.current;
    if (!open || !layer || !dialog) return;

    const active = document.activeElement;
    const previous =
      active instanceof HTMLElement && !layer.contains(active) ? active : null;
    const release = pushModalLayer(layer);

    const preferred = initialFocusRef.current?.() ?? null;
    const target =
      preferred && !preferred.matches(':disabled')
        ? preferred
        : (focusableIn(dialog)[0] ?? dialog);
    target.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (!isTopModalLayer(layer) || !dialog) return;
      if (event.key === 'Escape') {
        const escape = onEscapeRef.current;
        if (escape) {
          event.preventDefault();
          escape();
        }
        return;
      }
      if (event.key !== 'Tab') return;
      const focusable = focusableIn(dialog);
      if (focusable.length === 0) {
        event.preventDefault();
        dialog.focus();
        return;
      }
      const current = focusable.indexOf(document.activeElement as HTMLElement);
      const next = wrappedFocusIndex(current, focusable.length, event.shiftKey);
      if (next !== null) {
        event.preventDefault();
        focusable[next].focus();
      }
    }
    document.addEventListener('keydown', onKeyDown);

    return () => {
      document.removeEventListener('keydown', onKeyDown);
      release();
      // After every cleanup of this commit: when a confirmation and its
      // modal close together, the modal's layer may still be on top at the
      // moment this one is released, and an inert element cannot take focus.
      queueMicrotask(() => {
        if (previous?.isConnected && !previous.closest('[inert]')) previous.focus();
      });
    };
    // `mountKey`: the layer element changes when the dialog moves into its portal.
  }, [open, layerRef, dialogRef, mountKey]);
}
