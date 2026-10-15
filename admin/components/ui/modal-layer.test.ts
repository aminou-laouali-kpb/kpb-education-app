import { describe, expect, it } from 'vitest';

import { backgroundOf, wrappedFocusIndex, type LayerNode } from './modal-layer';

// A tiny tree with the two DOM members `backgroundOf` reads, so the rule
// "everything outside the top dialog is inert" is checked without a browser.
interface FakeNode extends LayerNode<FakeNode> {
  name: string;
  parentElement: FakeNode | null;
  children: FakeNode[];
}

function node(name: string, children: FakeNode[] = []): FakeNode {
  const created: FakeNode = { name, parentElement: null, children };
  for (const child of children) child.parentElement = created;
  return created;
}

function names(nodes: FakeNode[]): string[] {
  return nodes.map((current) => current.name).sort();
}

describe('backgroundOf — what becomes inert behind the topmost dialog', () => {
  it('a dialog portalled on <body>: the whole application root, and nothing of the dialog', () => {
    const panelButton = node('panel-button');
    const app = node('app', [node('sidebar'), node('panel', [panelButton])]);
    const dialog = node('modal-overlay', [node('dialog', [node('continue')])]);
    const body = node('body', [app, node('route-announcer'), dialog]);
    expect(names(backgroundOf(dialog, body))).toEqual(['app', 'route-announcer']);
  });

  it('a confirmation over a modal: the modal is inert too, until the confirmation closes', () => {
    const modal = node('modal-overlay');
    const confirm = node('confirm-overlay');
    const body = node('body', [node('app'), modal, confirm]);
    expect(names(backgroundOf(confirm, body))).toEqual(['app', 'modal-overlay']);
    expect(names(backgroundOf(modal, body))).toEqual(['app', 'confirm-overlay']);
  });

  it('a dialog rendered in place: every sibling along the way up, never an ancestor', () => {
    const primary = node('primary-button');
    const datesOnly = node('dates-only-button');
    const overlay = node('modal-overlay');
    const panel = node('panel', [primary, datesOnly, overlay]);
    const page = node('page', [node('table'), panel]);
    const body = node('body', [page, node('next-portal')]);
    expect(names(backgroundOf(overlay, body))).toEqual([
      'dates-only-button',
      'next-portal',
      'primary-button',
      'table',
    ]);
  });
});

describe('wrappedFocusIndex — Tab and Shift+Tab stay inside the dialog', () => {
  it('Tab on the last element goes back to the first', () => {
    expect(wrappedFocusIndex(2, 3, false)).toBe(0);
  });

  it('Shift+Tab on the first element goes to the last', () => {
    expect(wrappedFocusIndex(0, 3, true)).toBe(2);
  });

  it('focus on the dialog itself (or lost): Tab to the first, Shift+Tab to the last', () => {
    expect(wrappedFocusIndex(-1, 3, false)).toBe(0);
    expect(wrappedFocusIndex(-1, 3, true)).toBe(2);
  });

  it('in the middle: the browser moves the focus itself', () => {
    expect(wrappedFocusIndex(0, 3, false)).toBeNull();
    expect(wrappedFocusIndex(1, 3, false)).toBeNull();
    expect(wrappedFocusIndex(2, 3, true)).toBeNull();
  });

  it('a single focusable element keeps the focus', () => {
    expect(wrappedFocusIndex(0, 1, false)).toBe(0);
    expect(wrappedFocusIndex(0, 1, true)).toBe(0);
  });

  it('nothing focusable: nothing to move to', () => {
    expect(wrappedFocusIndex(-1, 0, false)).toBeNull();
  });
});
