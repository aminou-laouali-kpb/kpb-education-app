import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  duplicateFromError,
  recordedSaleMessage,
} from '../components/service-sales/RecordSaleForm';

const sale = {
  id: 'sp-1',
  amountXOF: 40000,
  listPriceXOF: 50000,
  discountPercent: 20,
  user: { fullName: 'Awa Diallo', email: 'awa@x.org' },
  package: { nameFr: 'Dossier prêt' },
};
const templates = {
  plain: '{service} — {name} ({email}) — {amount} FCFA',
  discounted: '{service} — {amount} FCFA, −{percent} % sur {list} FCFA',
};

describe('vente saisie dans l’admin', () => {
  it('annonce la remise du Pass quand le serveur l’a appliquée', () => {
    const n = (value: number) => new Intl.NumberFormat('fr-FR').format(value);
    expect(recordedSaleMessage(sale, templates)).toBe(
      `Dossier prêt — ${n(40000)} FCFA, −20 % sur ${n(50000)} FCFA`,
    );
  });

  it('sans remise, le message ne parle pas du Pass', () => {
    expect(
      recordedSaleMessage({ ...sale, amountXOF: 50000, discountPercent: 0 }, templates),
    ).toContain('Awa Diallo (awa@x.org)');
  });

  it('les textes existent dans les deux langues', () => {
    for (const locale of ['fr', 'en']) {
      const messages = JSON.parse(
        readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'),
      ) as { serviceSales: Record<string, string> };
      for (const key of [
        'recordOpenCta', 'recordTitle', 'recordHint', 'recordEmailLabel', 'recordPackageLabel',
        'recordStatusLabel', 'recordNoteLabel', 'recordCta', 'recordCancel', 'recordEmailInvalid',
        'recordPackageMissing', 'recordedPlain', 'recordedDiscounted',
        'duplicateTitle', 'duplicateBody', 'duplicateConfirmCta', 'duplicateCancelCta',
      ]) {
        expect({ locale, key, ok: Boolean(messages.serviceSales[key]) }).toEqual({ locale, key, ok: true });
      }
    }
  });

  it('reconnaît le refus de doublon et en extrait la vente ouverte', () => {
    const existing = {
      id: 'sp-open',
      status: 'pending_payment',
      amountXOF: 50000,
      createdAt: '2026-11-20T10:00:00.000Z',
      source: 'admin',
    };
    const error = Object.assign(new Error('conflict'), {
      status: 409,
      body: JSON.stringify({ statusCode: 409, code: 'DUPLICATE_OPEN_SALE', details: { existing } }),
    });
    expect(duplicateFromError(error)).toEqual(existing);
    expect(duplicateFromError(Object.assign(new Error('x'), { status: 409, body: '{"code":"OTHER"}' }))).toBeNull();
    expect(duplicateFromError(Object.assign(new Error('x'), { status: 500, body: 'oops' }))).toBeNull();
    expect(duplicateFromError(undefined)).toBeNull();
  });
});
