import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  auditEventMessageKey,
  CYCLE_STATUSES,
  openingErrorMessageKey,
  phoneTabMessageKey,
  skipReasonMessageKey,
  type PhoneTab,
} from './scholarship-opening';
import {
  CYCLE_OPENING_SKIP_REASONS,
  OPENING_AUDIT_ACTIONS,
  OPENING_ERROR_CODES,
} from './scholarship-opening-types';

// Ce que l'annonce d'ouverture affiche doit exister dans les deux langues, et
// dire « acceptées par le fournisseur », jamais « reçues » ni « délivrées » :
// un 200 de FCM ou de OneSignal ne prouve pas que le téléphone a affiché quoi
// que ce soit. Sur le modèle de `eef-publication.messages.test.ts`.

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');

function lookup(messages: Messages, key: string): unknown {
  return key
    .split('.')
    .reduce<unknown>(
      (current, part) =>
        current && typeof current === 'object' ? (current as Messages)[part] : undefined,
      messages,
    );
}

function leafKeys(value: unknown, prefix = ''): string[] {
  if (value && typeof value === 'object') {
    return Object.entries(value as Messages).flatMap(([key, child]) =>
      leafKeys(child, prefix ? `${prefix}.${key}` : key),
    );
  }
  return [prefix];
}

const OPENING = 'scholarships.opening';
const frOpening = lookup(fr, OPENING);
const enOpening = lookup(en, OPENING);

/** Les fichiers qui affichent l'annonce, relus pour y trouver chaque `t('…')`. */
const SOURCES = [
  ['app', 'scholarships', 'page.tsx'],
  ['components', 'scholarships', 'CycleOpeningPanel.tsx'],
  ['components', 'scholarships', 'OpeningPreviewModal.tsx'],
  ['components', 'scholarships', 'OpeningScheduledCard.tsx'],
  ['components', 'scholarships', 'OpeningTodoCard.tsx'],
  ['components', 'scholarships', 'PhonePreview.tsx'],
  ['lib', 'scholarship-opening.ts'],
].map((parts) => readFileSync(join(__dirname, '..', ...parts), 'utf8'));

function expectInBothLocales(key: string) {
  expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
  expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
}

describe('messages de l’annonce d’ouverture', () => {
  it('donnent les mêmes clés en français et en anglais', () => {
    expect(leafKeys(frOpening).sort()).toEqual(leafKeys(enOpening).sort());
  });

  it('gardent les mêmes variables `{…}` dans les deux langues', () => {
    const variables = (text: unknown) =>
      [...String(text).matchAll(/\{(\w+)\}/g)].map((match) => match[1]).sort();
    for (const key of leafKeys(frOpening, OPENING)) {
      expect({ key, vars: variables(lookup(en, key)) }).toEqual({
        key,
        vars: variables(lookup(fr, key)),
      });
    }
  });

  it('ne laissent aucun texte vide', () => {
    for (const messages of [fr, en]) {
      for (const key of leafKeys(lookup(messages, OPENING), OPENING)) {
        const text = lookup(messages, key);
        expect(typeof text === 'string' && text.trim() !== '').toBe(true);
      }
    }
  });

  it('couvrent chaque clé `t(\'scholarships…\')` écrite en toutes lettres', () => {
    const used = new Set(
      SOURCES.flatMap((source) =>
        [...source.matchAll(/t\(\s*['`](scholarships\.[A-Za-z_.]+)['`]/g)].map((m) => m[1]),
      ),
    );
    // Les modules passent aussi des clés à des fonctions (`t(key)`) : la
    // plupart sont écrites en toutes lettres dans `scholarship-opening.ts`.
    for (const source of SOURCES) {
      for (const match of source.matchAll(/['`](scholarships\.opening\.[A-Za-z]+(?:_[a-z_]+)?)['`]/g)) {
        used.add(match[1]);
      }
    }
    expect(used.size).toBeGreaterThan(60);
    for (const key of used) expectInBothLocales(key);
  });

  it('ont un libellé pour chaque action d’audit (« Derniers événements »)', () => {
    for (const action of OPENING_AUDIT_ACTIONS) expectInBothLocales(auditEventMessageKey(action));
  });

  it('ont un libellé pour chaque code d’erreur d’annonce', () => {
    for (const code of OPENING_ERROR_CODES) expectInBothLocales(openingErrorMessageKey(code));
  });

  it('ont un libellé pour chaque raison de cycle non annoncé', () => {
    for (const reason of CYCLE_OPENING_SKIP_REASONS) {
      expectInBothLocales(skipReasonMessageKey(reason));
    }
  });

  it('ont un libellé pour chaque statut de cycle, source « À faire » et onglet', () => {
    for (const status of CYCLE_STATUSES) expectInBothLocales(`${OPENING}.cycleStatus_${status}`);
    for (const source of ['catalogue', 'admin']) expectInBothLocales(`${OPENING}.todoSource_${source}`);
    const tabs: PhoneTab[] = ['alert', 'favorite', 'dates', 'bundle'];
    for (const tab of tabs) expectInBothLocales(phoneTabMessageKey(tab));
  });

  it('ne disent jamais « reçu » ni « délivré » en français', () => {
    for (const key of leafKeys(frOpening, OPENING)) {
      const text = String(lookup(fr, key)).toLowerCase();
      expect({ key, text, banned: /reçu|délivr/.test(text) }).toMatchObject({ banned: false });
    }
  });

  it('ne disent jamais "received" ni "delivered" en anglais', () => {
    for (const key of leafKeys(enOpening, OPENING)) {
      const text = String(lookup(en, key)).toLowerCase();
      expect({ key, text, banned: /receiv|deliver/.test(text) }).toMatchObject({ banned: false });
    }
  });

  it('écrivent le rapport avec « acceptées par le fournisseur »', () => {
    expect(lookup(fr, `${OPENING}.reportLine`)).toContain('acceptées par le fournisseur');
    expect(lookup(en, `${OPENING}.reportLine`)).toContain('accepted by the provider');
  });

  // « étudiants abonnés notifiés » s'affichait même quand personne n'avait été
  // prévenu : ces clés de l'ancien éditeur ne doivent pas revenir.
  it('ont retiré les clés de l’ancien éditeur d’ouverture', () => {
    for (const key of ['activateCta', 'activationHint', 'activationSuccess']) {
      expect(lookup(fr, `scholarships.${key}`)).toBeUndefined();
      expect(lookup(en, `scholarships.${key}`)).toBeUndefined();
      for (const source of SOURCES) expect(source).not.toContain(`scholarships.${key}'`);
    }
  });
});
