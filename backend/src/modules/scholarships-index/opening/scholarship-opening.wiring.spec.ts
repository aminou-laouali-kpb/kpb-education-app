import { Reflector } from '@nestjs/core';
import { GUARDS_METADATA, PATH_METADATA } from '@nestjs/common/constants';

import { AppModule } from '../../../app.module';
import { ROLES_KEY } from '../../../common/decorators/roles.decorator';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { PushOutboxWorkerService } from '../../notifications/push-outbox-worker.service';
import { AdminScholarshipsController } from '../admin-scholarships.controller';
import { FollowedScholarshipsController } from '../followed-scholarships.controller';
import { FollowedScholarshipsService } from '../followed-scholarships.service';
import { AdminScholarshipOpeningController } from './admin-scholarship-opening.controller';
import { ScholarshipOpeningAdminService } from './scholarship-opening-admin.service';
import { ScholarshipOpeningAudienceService } from './scholarship-opening-audience.service';
import { ScholarshipOpeningFanoutService } from './scholarship-opening-fanout.service';

/**
 * Le branchement du chantier C est posé une fois, par le lot « schema » :
 * les lots suivants remplissent leurs fichiers sans toucher à `app.module.ts`.
 * Ce test fige ce qu'ils peuvent tenir pour acquis.
 */
describe('AppModule — annonce d’ouverture branchée', () => {
  const reflector = new Reflector();
  const providers = (Reflect.getMetadata('providers', AppModule) ?? []) as unknown[];
  const controllers = (Reflect.getMetadata('controllers', AppModule) ?? []) as unknown[];

  it('enregistre les services', () => {
    for (const provider of [
      ScholarshipOpeningAdminService,
      ScholarshipOpeningAudienceService,
      ScholarshipOpeningFanoutService,
      PushOutboxWorkerService,
      FollowedScholarshipsService,
    ]) {
      expect(providers).toContain(provider);
    }
  });

  it('enregistre les contrôleurs, celui de l’annonce avant celui des bourses', () => {
    expect(controllers).toContain(FollowedScholarshipsController);
    const opening = controllers.indexOf(AdminScholarshipOpeningController);
    expect(opening).toBeGreaterThanOrEqual(0);
    expect(opening).toBeLessThan(controllers.indexOf(AdminScholarshipsController));
  });

  it('les routes de l’équipe ont le périmètre des routes de bourses', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AdminScholarshipOpeningController)).toBe(
      Reflect.getMetadata(PATH_METADATA, AdminScholarshipsController),
    );
    expect(Reflect.getMetadata(GUARDS_METADATA, AdminScholarshipOpeningController)).toEqual([
      AdminAuthGuard,
      RolesGuard,
    ]);
    expect(reflector.get(ROLES_KEY, AdminScholarshipOpeningController)).toEqual(
      reflector.get(ROLES_KEY, AdminScholarshipsController),
    );
  });

  it('la liste des bourses suivies exige un compte étudiant', () => {
    expect(Reflect.getMetadata(PATH_METADATA, FollowedScholarshipsController)).toBe(
      'me/followed-scholarships',
    );
    expect(Reflect.getMetadata(GUARDS_METADATA, FollowedScholarshipsController)).toEqual([
      StudentAuthGuard,
    ]);
  });
});
