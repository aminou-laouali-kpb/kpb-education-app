import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { AdminCapability, hasAdminCapability, InternalRole } from '../lib/admin-capabilities';
import { visibleNavHrefs } from './dashboard-shell';

/** Les rôles du `@Roles` de classe de `NotificationsController`. */
function notificationsControllerRoles(): InternalRole[] {
  const source = readFileSync(
    join(__dirname, '..', '..', 'backend', 'src', 'modules', 'notifications', 'notifications.controller.ts'),
    'utf8',
  );
  const block = /@Roles\(([^)]*)\)\s*export class NotificationsController/.exec(source)?.[1] ?? '';
  return [...block.matchAll(/InternalRole\.(\w+)/g)].map(
    ([, name]) => InternalRole[name as keyof typeof InternalRole],
  );
}

describe('menu « Notifications » — miroir de NotificationsController (audit 57, F22)', () => {
  it('la capacité accorde exactement les rôles du contrôleur', () => {
    const backend = notificationsControllerRoles();
    expect(backend.length).toBeGreaterThan(0);
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ManageNotificationCampaigns),
    );
    expect(allowed.sort()).toEqual([...backend].sort());
  });

  it.each([InternalRole.Counselor, InternalRole.Moderator])(
    'le menu de %s ne propose pas Notifications (le serveur rendrait 403)',
    (role) => {
      expect(visibleNavHrefs(role)).not.toContain('/notifications');
    },
  );

  it.each([InternalRole.Commercial, InternalRole.ContentManager, InternalRole.Admin, InternalRole.SuperAdmin])(
    'le menu de %s propose Notifications',
    (role) => {
      expect(visibleNavHrefs(role)).toContain('/notifications');
    },
  );
});
