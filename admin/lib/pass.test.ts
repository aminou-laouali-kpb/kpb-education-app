import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { visibleNavHrefs } from '../components/dashboard-shell';
import { AdminCapability, hasAdminCapability, InternalRole } from './admin-capabilities';
import { EMPTY_PASS_DRAFT, PassDraftError, toPassGrantInput } from './pass';

describe('toPassGrantInput', () => {
  const draft = {
    ...EMPTY_PASS_DRAFT,
    email: ' aicha@example.org ',
    paymentReference: ' OM-2611-4455 ',
    amountXof: '15 000',
  };

  it('nettoie et type les champs', () => {
    expect(toPassGrantInput(draft)).toEqual({
      email: 'aicha@example.org',
      durationDays: 30,
      paymentReference: 'OM-2611-4455',
      amountXof: 15000,
    });
  });

  it.each([
    [{ email: 'pas-un-email' }, /E-mail/],
    [{ durationDays: '0' }, /durée/],
    [{ durationDays: '731' }, /durée/],
    [{ paymentReference: 'A' }, /Référence/],
    [{ amountXof: '15,5' }, /montant/],
  ])('refuse %o', (patch, message) => {
    expect(() => toPassGrantInput({ ...draft, ...patch })).toThrow(message);
    expect(() => toPassGrantInput({ ...draft, ...patch })).toThrow(PassDraftError);
  });
});

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');
const lookup = (messages: Messages, key: string): unknown =>
  key.split('.').reduce<unknown>(
    (current, part) => (current && typeof current === 'object' ? (current as Messages)[part] : undefined),
    messages,
  );
const leafKeys = (value: unknown, prefix = ''): string[] =>
  value && typeof value === 'object'
    ? Object.entries(value as Messages).flatMap(([key, child]) =>
        leafKeys(child, prefix ? `${prefix}.${key}` : key),
      )
    : [prefix];

describe('messages du Pass', () => {
  it('ont les mêmes clés en français et en anglais', () => {
    expect(leafKeys(fr.pass).sort()).toEqual(leafKeys(en.pass).sort());
  });

  it('couvrent chaque clé de la page, états compris', () => {
    const page = readFileSync(join(__dirname, '..', 'app', 'pass', 'page.tsx'), 'utf8');
    const used = new Set([
      ...[...page.matchAll(/t\(\s*['`](pass\.[A-Za-z_.]+)['`]/g)].map((m) => m[1]),
      ...['active', 'upcoming', 'expired', 'revoked'].map((state) => `pass.state.${state}`),
      'nav.pass',
    ]);
    expect(used.size).toBeGreaterThan(30);
    for (const key of used) {
      expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
      expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
    }
  });
});

/** Les rôles du `@Roles` de classe d'`AdminPassController`, lus sur le fichier. */
function passControllerRoles(): InternalRole[] {
  const source = readFileSync(
    join(__dirname, '..', '..', 'backend', 'src', 'modules', 'pass', 'pass.controller.ts'),
    'utf8',
  );
  const block = /@Roles\(([^)]*)\)\s*export class AdminPassController/.exec(source)?.[1] ?? '';
  return [...block.matchAll(/InternalRole\.(\w+)/g)].map(
    ([, name]) => InternalRole[name as keyof typeof InternalRole],
  );
}

describe('menu « Pass Karatou » — miroir d’AdminPassController', () => {
  it('la capacité accorde exactement les rôles du contrôleur', () => {
    const backend = passControllerRoles();
    expect(backend.length).toBeGreaterThan(0);
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ManagePassGrants),
    );
    expect(allowed.sort()).toEqual([...backend].sort());
  });

  it.each([InternalRole.Counselor, InternalRole.ContentManager, InternalRole.Moderator])(
    'le menu de %s ne propose pas le Pass',
    (role) => {
      expect(visibleNavHrefs(role)).not.toContain('/pass');
    },
  );

  it.each([InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin])(
    'le menu de %s propose le Pass',
    (role) => {
      expect(visibleNavHrefs(role)).toContain('/pass');
    },
  );
});
