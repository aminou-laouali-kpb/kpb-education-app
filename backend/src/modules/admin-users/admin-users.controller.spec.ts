import { ForbiddenException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';

describe('AdminUsersController — super admin protection', () => {
  function make(targetRole: string) {
    const calls: string[] = [];
    const service = {
      getRole: async () => targetRole,
      resetPassword: async () => {
        calls.push('reset');
        return { tempPassword: 'x' };
      },
      updateUser: async () => {
        calls.push('update');
        return {};
      },
      createUser: async () => {
        calls.push('create');
        return {};
      },
    } as unknown as AdminUsersService;
    return { controller: new AdminUsersController(service), calls };
  }
  const admin = { adminUser: { role: InternalRole.Admin } };
  const superAdmin = { adminUser: { role: InternalRole.SuperAdmin } };

  it('an Admin cannot reset a SuperAdmin password', async () => {
    const { controller, calls } = make(InternalRole.SuperAdmin);
    await expect(controller.resetPassword('su-1', admin)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(calls).toEqual([]);
  });

  it('an Admin cannot promote someone to SuperAdmin', async () => {
    const { controller, calls } = make(InternalRole.Counselor);
    await expect(
      controller.updateUser('u-1', { role: InternalRole.SuperAdmin } as any, admin),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(() =>
      controller.createUser({ role: InternalRole.SuperAdmin } as any, admin),
    ).toThrow(ForbiddenException);
    expect(calls).toEqual([]);
  });

  it('an Admin still manages regular operators; a SuperAdmin manages everyone', async () => {
    await make(InternalRole.Counselor).controller.resetPassword('u-1', admin);
    const { controller, calls } = make(InternalRole.SuperAdmin);
    await controller.resetPassword('su-1', superAdmin);
    expect(calls).toEqual(['reset']);
  });
});
