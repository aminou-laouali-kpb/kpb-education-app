import { Reflector, APP_INTERCEPTOR } from '@nestjs/core';
import { PATH_METADATA } from '@nestjs/common/constants';

import { AppModule } from '../../app.module';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminDashboardController } from '../admin-dashboard/admin-dashboard.controller';
import { AdminAppBuildsController } from './admin-app-builds.controller';
import { AppBuildInterceptor } from './app-build.interceptor';
import { AppBuildTrackerService } from './app-build-tracker.service';

/**
 * Le périmètre de la route, résolu comme `RolesGuard` le résout (handler puis
 * classe), et comparé au tableau de bord dont elle reprend les rôles.
 */
describe('AdminAppBuildsController — périmètre', () => {
  const reflector = new Reflector();

  it('vit sous /admin/app-builds', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AdminAppBuildsController)).toBe(
      'admin/app-builds',
    );
  });

  it('exige une session d’administration puis un rôle', () => {
    expect(Reflect.getMetadata('__guards__', AdminAppBuildsController)).toEqual(
      [AdminAuthGuard, RolesGuard],
    );
  });

  it('est ouverte aux mêmes rôles que le tableau de bord, pas plus', () => {
    const handlers = Object.getOwnPropertyNames(
      AdminAppBuildsController.prototype,
    ).filter((name) => name !== 'constructor');
    expect(handlers).toEqual(['getAdoption']);

    const roles = reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
      AdminAppBuildsController.prototype.getAdoption,
      AdminAppBuildsController,
    ]);
    const dashboardRoles = reflector.get<InternalRole[]>(
      ROLES_KEY,
      AdminDashboardController,
    );
    expect([...roles].sort()).toEqual([...dashboardRoles].sort());
    expect(roles).not.toContain(InternalRole.Moderator);
    expect(roles).not.toContain(InternalRole.ContentManager);
  });
});

describe('AppModule — suivi des builds branché', () => {
  const providers = (Reflect.getMetadata('providers', AppModule) ??
    []) as unknown[];
  const controllers = (Reflect.getMetadata('controllers', AppModule) ??
    []) as unknown[];

  it('enregistre l’intercepteur en global, et son service', () => {
    expect(providers).toContainEqual({
      provide: APP_INTERCEPTOR,
      useClass: AppBuildInterceptor,
    });
    expect(providers).toContain(AppBuildTrackerService);
  });

  it('expose la route d’administration', () => {
    expect(controllers).toContain(AdminAppBuildsController);
  });
});
