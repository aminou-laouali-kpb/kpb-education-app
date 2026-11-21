import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { visibleNavHrefs } from '../components/dashboard-shell';
import { ACADEMY_STATUSES } from './academy';
import { AdminCapability, hasAdminCapability, InternalRole } from './admin-capabilities';

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

const SOURCES = [
  ['app', 'academy', 'page.tsx'],
  ['components', 'academy', 'CourseForm.tsx'],
  ['components', 'academy', 'LessonsEditor.tsx'],
  ['components', 'academy', 'ImportPanel.tsx'],
].map((parts) => readFileSync(join(__dirname, '..', ...parts), 'utf8'));

describe('messages des cours Academy', () => {
  it('donnent les mêmes clés en français et en anglais', () => {
    expect(leafKeys(fr.academy).sort()).toEqual(leafKeys(en.academy).sort());
    expect(typeof lookup(fr, 'nav.academy')).toBe('string');
    expect(typeof lookup(en, 'nav.academy')).toBe('string');
  });

  it('ne laissent aucun texte vide', () => {
    for (const messages of [fr, en]) {
      for (const key of leafKeys(messages.academy, 'academy')) {
        const text = lookup(messages, key);
        expect({ key, ok: typeof text === 'string' && text.trim() !== '' }).toEqual({
          key,
          ok: true,
        });
      }
    }
  });

  it('couvrent chaque clé `t(\'academy…\')` des écrans', () => {
    const used = new Set(
      SOURCES.flatMap((source) =>
        [...source.matchAll(/t\(\s*['`](academy\.[A-Za-z_.]+)['`]/g)].map((m) => m[1]),
      ),
    );
    expect(used.size).toBeGreaterThan(40);
    for (const key of used) {
      expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
      expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
    }
  });

  // `t(\`academy.status.${status}\`)` échappe à la recherche ci-dessus.
  it.each(ACADEMY_STATUSES)('nomment le statut %s', (status) => {
    expect(typeof lookup(fr, `academy.status.${status}`)).toBe('string');
    expect(typeof lookup(en, `academy.status.${status}`)).toBe('string');
  });
});

/** Les rôles du `@Roles` de classe d'`AdminAcademyController`, lus sur le fichier. */
function academyControllerRoles(): InternalRole[] {
  const source = readFileSync(
    join(__dirname, '..', '..', 'backend', 'src', 'modules', 'academy', 'admin-academy.controller.ts'),
    'utf8',
  );
  const block = /@Roles\(([^)]*)\)\s*export class AdminAcademyController/.exec(source)?.[1] ?? '';
  return [...block.matchAll(/InternalRole\.(\w+)/g)].map(
    ([, name]) => InternalRole[name as keyof typeof InternalRole],
  );
}

describe('menu « Cours (Academy) » — miroir d’AdminAcademyController', () => {
  it('la capacité accorde exactement les rôles du contrôleur', () => {
    const backend = academyControllerRoles();
    expect(backend.length).toBeGreaterThan(0);
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ManageAcademyCourses),
    );
    expect(allowed.sort()).toEqual([...backend].sort());
  });

  it('reste distincte de la capacité du catalogue', () => {
    expect(AdminCapability.ManageAcademyCourses).not.toBe(
      AdminCapability.ManageCatalogContent,
    );
  });

  it.each([InternalRole.Counselor, InternalRole.Commercial, InternalRole.Moderator])(
    'le menu de %s ne propose pas les cours (le serveur rendrait 403)',
    (role) => {
      expect(visibleNavHrefs(role)).not.toContain('/academy');
    },
  );

  it.each([InternalRole.ContentManager, InternalRole.Admin, InternalRole.SuperAdmin])(
    'le menu de %s propose les cours',
    (role) => {
      expect(visibleNavHrefs(role)).toContain('/academy');
    },
  );
});
