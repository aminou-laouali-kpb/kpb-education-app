import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { LocaleProvider } from '../locale-provider';
import { Alert, ConfirmDialog, Modal } from '../ui';
import { OpeningScheduledCard } from './OpeningScheduledCard';
import { OpeningTodoCard } from './OpeningTodoCard';

// Rendu serveur (react-dom/server, environnement node) : les effets ne
// tournent pas, on lit le balisage du premier rendu. Les comportements du
// navigateur (focus, inert, minuteries) sont couverts par les fonctions pures
// de `modal-layer.ts` et `scholarship-opening.ts`.

function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

/** Le contenu de chaque élément `aria-live` ou `role="status"` du balisage. */
function liveRegions(html: string): string[] {
  return [
    ...html.matchAll(/<(\w+)[^>]*(?:aria-live="[^"]+"|role="status")[^>]*>([\s\S]*?)<\/\1>/g),
  ].map((match) => match[2]);
}

const noop = () => {};

describe('Modal et ConfirmDialog (rendu serveur)', () => {
  it('Modal : dialogue modal titré, rien quand il est fermé', () => {
    const html = render(
      <Modal open title="Annonce de l'ouverture" onClose={noop}>
        <p>Corps</p>
      </Modal>,
    );
    expect(html).toContain('role="dialog"');
    expect(html).toContain('aria-modal="true"');
    expect(html).toMatch(/aria-labelledby="([^"]+)"[\s\S]*<h2 id="\1"/);
    expect(
      render(
        <Modal open={false} title="x" onClose={noop}>
          <p>Corps</p>
        </Modal>,
      ),
    ).toBe('');
  });

  it('ConfirmDialog : dialogue modal, confirmation désactivée tant que demandé', () => {
    const html = render(
      <ConfirmDialog
        open
        title="Prévenir 612 étudiants ?"
        confirmLabel="Confirmer l'envoi"
        cancelLabel="Annuler"
        confirmDisabled
        onConfirm={noop}
        onCancel={noop}
      >
        <input aria-label="Nombre" />
      </ConfirmDialog>,
    );
    expect(html).toContain('aria-modal="true"');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*>Confirmer l&#x27;envoi<\/button>/);
  });
});

describe('OpeningScheduledCard (rendu serveur)', () => {
  const base = {
    scholarshipId: 'chevening',
    cycleId: 'cyc_2027',
    academicYear: '2027-2028',
    holdSeconds: 120,
    toNotify: 312,
    onChanged: noop,
  };

  it('compte à rebours visible, mais ni dans une région live ni dans le nom du bouton', () => {
    const fanoutAt = new Date(Date.now() + 95_000).toISOString();
    const html = render(
      <OpeningScheduledCard {...base} fanoutAt={fanoutAt} deadlineMs={Date.parse(fanoutAt)} />,
    );
    // Visible : « Annuler l'envoi (1:35) ».
    expect(html).toMatch(/Annuler l&#x27;envoi \(\d:\d{2}\)/);
    // Nom accessible fixe.
    expect(html).toContain('aria-label="Annuler l&#x27;envoi"');
    // Une seule région live, vide au premier rendu (remplie à l'effet), et
    // jamais autour du bouton.
    const regions = liveRegions(html);
    expect(regions).toEqual(['']);
    expect(html).not.toMatch(/<section[^>]*aria-live/);
  });

  it('heure passée, envoi pas encore lancé : « En attente d’envoi » et annulation encore proposée', () => {
    const fanoutAt = new Date(Date.now() - 30_000).toISOString();
    const html = render(
      <OpeningScheduledCard {...base} fanoutAt={fanoutAt} deadlineMs={Date.parse(fanoutAt)} />,
    );
    expect(html).toContain('En attente d&#x27;envoi · 2027-2028');
    expect(html).toContain('Vous pouvez encore l&#x27;annuler.');
    expect(html).toMatch(/<button[^>]*aria-label="Annuler l&#x27;envoi"[^>]*>Annuler l&#x27;envoi<\/button>/);
  });

  it('rapport d’un envoi passé : pas d’annulation', () => {
    const html = render(<OpeningScheduledCard {...base} fanoutAt={null} deadlineMs={null} />);
    expect(html).toContain('Rapport d&#x27;envoi · 2027-2028');
    expect(html).not.toContain('Annuler l&#x27;envoi');
  });
});

describe('Alert (rendu serveur)', () => {
  it('rôle live selon la gravité ; aucun quand un parent annonce déjà le texte', () => {
    expect(render(<Alert variant="warning">x</Alert>)).toContain('role="alert"');
    expect(render(<Alert variant="success">x</Alert>)).toContain('role="status"');
    const silent = render(
      <Alert variant="warning" live={false}>
        x
      </Alert>,
    );
    expect(silent).not.toContain('role=');
    expect(liveRegions(silent)).toEqual([]);
  });
});

describe('OpeningTodoCard (rendu serveur)', () => {
  it('« abonnés à prévenir », le même nombre que la colonne de la liste', () => {
    const html = render(
      <OpeningTodoCard
        todo={{
          mode: 'outbox_followers',
          scope: 'followers',
          total: 1,
          items: [
            {
              scholarshipId: 'chevening',
              nameFr: 'Chevening',
              cycleId: 'cyc_2027',
              academicYear: '2027-2028',
              opensAt: null,
              closesAt: null,
              source: 'catalogue',
              followers: 334,
              notifiable: 312,
            },
          ],
        }}
        onPrepare={noop}
      />,
    );
    expect(html).toContain('312 abonnés à prévenir (334 au total)');
  });
});
