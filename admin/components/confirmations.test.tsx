import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { DeleteParcoursDialog } from './content/delete-parcours-dialog';
import { LocaleProvider } from './locale-provider';
import { RemoveStepDialog } from './scholarships/remove-step-dialog';
import { ResetPasswordDialog } from './users/reset-password-dialog';

// Rendu serveur (react-dom/server, environnement node), comme
// `community/community-components.test.tsx` : on lit le balisage du premier
// rendu, en français (langue par défaut du LocaleProvider).

function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};

const counselor = { id: 'adm_2', fullName: 'Awa Diallo', email: 'awa@kpb.test' };

const story = {
  id: 'pc_1',
  personName: 'Moussa K.',
  title: { fr: 'De Niamey à Lyon', en: 'From Niamey to Lyon' },
};

describe('ResetPasswordDialog', () => {
  it('ne rend rien sans compte visé', () => {
    expect(
      render(<ResetPasswordDialog target={null} isSelf={false} loading={false} onConfirm={noop} onCancel={noop} />),
    ).toBe('');
  });

  it('nomme le compte visé et prévient de la fermeture de session', () => {
    const html = render(
      <ResetPasswordDialog target={counselor} isSelf={false} loading={false} onConfirm={noop} onCancel={noop} />,
    );
    expect(html).toContain('role="dialog"');
    expect(html).toContain('aria-modal="true"');
    expect(html).toContain('Réinitialiser le mot de passe de Awa Diallo ?');
    expect(html).toContain('awa@kpb.test');
    expect(html).toContain('session fermée');
    expect(html).toContain('>Annuler<');
    expect(html).not.toContain('votre propre compte');
    expect(html).not.toMatch(/\{(name|email)\}/);
  });

  it("avertit quand l'admin se vise lui-même", () => {
    const html = render(
      <ResetPasswordDialog target={counselor} isSelf loading={false} onConfirm={noop} onCancel={noop} />,
    );
    expect(html).toContain('votre propre compte');
  });

  it('désactive les boutons pendant la requête', () => {
    const html = render(
      <ResetPasswordDialog target={counselor} isSelf={false} loading onConfirm={noop} onCancel={noop} />,
    );
    expect(html.match(/<button[^>]*disabled/g)?.length).toBe(2);
  });
});

describe('DeleteParcoursDialog', () => {
  it('ne rend rien sans témoignage visé', () => {
    expect(render(<DeleteParcoursDialog target={null} loading={false} onConfirm={noop} onCancel={noop} />)).toBe('');
  });

  it('nomme le témoignage et dit que la suppression est définitive', () => {
    const html = render(
      <DeleteParcoursDialog target={story} loading={false} onConfirm={noop} onCancel={noop} />,
    );
    expect(html).toContain('role="dialog"');
    expect(html).toContain('Supprimer le témoignage « De Niamey à Lyon » ?');
    expect(html).toContain('Moussa K.');
    expect(html).toContain('définitivement');
    expect(html).toContain('>Supprimer<');
    expect(html).not.toMatch(/\{(title|name)\}/);
  });
});

const stepTarget = {
  entry: { id: 'sch_1', nameFr: 'Bourse Eiffel', nameEn: 'Eiffel Scholarship' },
  step: { id: 'st_1', stepNumber: 2, titleFr: 'Dossier en ligne', titleEn: 'Online file' },
};

describe('RemoveStepDialog', () => {
  it('ne rend rien sans étape visée', () => {
    expect(render(<RemoveStepDialog target={null} loading={false} onConfirm={noop} onCancel={noop} />)).toBe('');
  });

  it("nomme l'étape et la bourse, et dit que c'est définitif", () => {
    const html = render(
      <RemoveStepDialog target={stepTarget} loading={false} onConfirm={noop} onCancel={noop} />,
    );
    expect(html).toContain('role="dialog"');
    expect(html).toContain('Retirer l&#x27;étape 2 « Dossier en ligne » ?');
    expect(html).toContain('« Bourse Eiffel »');
    expect(html).toContain('définitivement');
    expect(html).toContain('>Retirer<');
    expect(html).toContain('>Annuler<');
    expect(html).not.toMatch(/\{(number|step|scholarship)\}/);
  });

  it('désactive les boutons pendant la requête', () => {
    const html = render(<RemoveStepDialog target={stepTarget} loading onConfirm={noop} onCancel={noop} />);
    expect(html.match(/<button[^>]*disabled/g)?.length).toBe(2);
  });
});

describe('textes des confirmations', () => {
  type Messages = Record<string, Record<string, unknown>>;
  const load = (locale: string): Messages =>
    JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
  const keys = [
    ['users', 'resetConfirmTitle', '{name}'],
    ['users', 'resetConfirmBody', '{email}'],
    ['users', 'resetConfirmSelf', null],
    ['users', 'resetConfirmCta', null],
    ['users', 'resetCancelCta', null],
    ['content', 'parcoursDeleteConfirmTitle', '{title}'],
    ['content', 'parcoursDeleteConfirmBody', '{name}'],
    ['content', 'deleteCta', null],
    ['content', 'cancelCta', null],
    ['scholarships', 'removeStepConfirmTitle', '{step}'],
    ['scholarships', 'removeStepConfirmBody', '{scholarship}'],
    ['scholarships', 'removeStepCta', null],
    ['scholarships', 'removeStepCancelCta', null],
  ] as const;

  it.each(['fr', 'en'])('existent en %s avec leurs variables', (locale) => {
    const messages = load(locale);
    for (const [section, key, placeholder] of keys) {
      const value = messages[section]?.[key];
      expect(typeof value, `${section}.${key}`).toBe('string');
      if (placeholder) expect(value, `${section}.${key}`).toContain(placeholder);
    }
  });
});
