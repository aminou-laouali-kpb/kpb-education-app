import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { isPrizeHolderChanged, type PrizeAward } from '../../lib/referral-campaigns';
import { LocaleProvider } from '../locale-provider';
import { ForfeitFormBody, PayoutFormBody } from './campaign-detail';

// Rendu serveur (effets non exécutés), même méthode que les autres tests de
// composants. Audit 57, F21 : le refus du serveur doit s'afficher DANS la
// modale, pas sur l'onglet que l'overlay recouvre et rend inerte.
function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};

const award: PrizeAward = {
  id: 'pa_1',
  rank: 2,
  participantId: 'rp_1',
  publicNameSnapshot: 'Aïcha K. — Niamey',
  amountFcfa: 50000,
  recipient: 'parent',
  payoutStatus: 'pending',
  payoutMethod: 'wave',
  payoutReference: null,
  paidAmountFcfa: null,
  paidAt: null,
  paidByAdminId: null,
};

describe('modales des prix : l’erreur du serveur est dans la modale (F21)', () => {
  it('versement refusé : l’alerte est en tête du contenu, avant les champs', () => {
    const html = render(
      <PayoutFormBody
        draft={{ rank: 2, reference: 'W-1', date: '2026-11-20', recipient: 'ambassador' }}
        error="Lauréat mineur : le prix est versé au parent."
        onChange={noop}
      />,
    );
    const alert = html.indexOf('Lauréat mineur : le prix est versé au parent.');
    expect(alert).toBeGreaterThan(-1);
    expect(html).toContain('role="alert"');
    expect(alert).toBeLessThan(html.indexOf('type="date"'));
  });

  it('forfait refusé : même chose', () => {
    const html = render(
      <ForfeitFormBody
        draft={{ award, reason: 'injoignable' }}
        error="Le lauréat de ce rang a changé entre-temps : recharge la page."
        onChange={noop}
      />,
    );
    const alert = html.indexOf('Le lauréat de ce rang a changé entre-temps');
    expect(alert).toBeGreaterThan(-1);
    expect(alert).toBeLessThan(html.indexOf('<textarea'));
  });

  it('sans erreur, aucune alerte rouge', () => {
    const html = render(
      <PayoutFormBody draft={{ rank: 1, reference: '', date: '', recipient: 'parent' }} error={null} onChange={noop} />,
    );
    expect(html).not.toContain('role="alert"');
  });
});

describe('isPrizeHolderChanged : quand recharger la liste des prix', () => {
  const apiError = (status: number, body: unknown) =>
    Object.assign(new Error('x'), { status, body: typeof body === 'string' ? body : JSON.stringify(body) });

  it('reconnaît le 409 prize_holder_changed (corps Nest, à plat ou imbriqué)', () => {
    expect(isPrizeHolderChanged(apiError(409, { code: 'prize_holder_changed', message: 'm' }))).toBe(true);
    expect(isPrizeHolderChanged(apiError(409, { message: { code: 'prize_holder_changed' } }))).toBe(true);
  });

  it('ignore les autres refus', () => {
    expect(isPrizeHolderChanged(apiError(409, { message: 'Ce prix est déjà versé' }))).toBe(false);
    expect(isPrizeHolderChanged(apiError(400, { code: 'prize_holder_changed' }))).toBe(false);
    expect(isPrizeHolderChanged(apiError(409, 'pas du json'))).toBe(false);
    expect(isPrizeHolderChanged(new Error('réseau'))).toBe(false);
    expect(isPrizeHolderChanged(null)).toBe(false);
  });
});
