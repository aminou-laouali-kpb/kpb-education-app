import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { BulkScholarshipAlertsDto } from './bulk-scholarship-alerts.dto';
import { ReadNotificationsByRefDto } from './read-notifications-by-ref.dto';
import { UpdateScholarshipAlertDto } from './update-scholarship-alert.dto';

/** Les corps des nouvelles routes étudiant, par la ValidationPipe de `main.ts`. */
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

describe('UpdateScholarshipAlertDto', () => {
  const validate = (value: unknown) =>
    pipe.transform(value, { type: 'body', metatype: UpdateScholarshipAlertDto });

  it.each([true, false])('accepte notifyOpening=%s', async (notifyOpening) => {
    await expect(validate({ notifyOpening })).resolves.toMatchObject({
      notifyOpening,
    });
  });

  it.each([[{}], [{ notifyOpening: 'false' }], [{ notifyOpening: true, pushEnabled: false }]])(
    'refuse %j',
    async (value) => {
      await expect(validate(value)).rejects.toBeInstanceOf(BadRequestException);
    },
  );
});

describe('ReadNotificationsByRefDto', () => {
  const validate = (value: unknown) =>
    pipe.transform(value, { type: 'body', metatype: ReadNotificationsByRefDto });

  it('accepte jusqu’à 20 références d’annonce', async () => {
    const refs = Array.from({ length: 20 }, (_, i) => `scholarship-opened:clx${i}`);
    await expect(validate({ refs })).resolves.toMatchObject({ refs });
  });

  it.each([
    ['une liste vide', { refs: [] }],
    ['21 références', { refs: Array.from({ length: 21 }, (_, i) => `r${i}`) }],
    ['une référence trop longue', { refs: ['a'.repeat(201)] }],
    ['un caractère hors alphabet (%)', { refs: ['scholarship-opened:%'] }],
    ['une virgule (liste jointe)', { refs: ['scholarship-opened:a,scholarship-opened:b'] }],
    ['un nombre', { refs: [42] }],
    ['un champ inconnu', { refs: ['r1'], userId: 'someone-else' }],
  ])('refuse %s', async (_label, value) => {
    await expect(validate(value)).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('BulkScholarshipAlertsDto', () => {
  const validate = (value: unknown) =>
    pipe.transform(value, { type: 'body', metatype: BulkScholarshipAlertsDto });

  it('accepte jusqu’à 10 identifiants (et une liste vide)', async () => {
    const scholarshipIds = Array.from({ length: 10 }, (_, i) => `sch-${i}`);
    await expect(validate({ scholarshipIds })).resolves.toMatchObject({ scholarshipIds });
    await expect(validate({ scholarshipIds: [] })).resolves.toMatchObject({ scholarshipIds: [] });
  });

  it.each([
    ['11 identifiants', { scholarshipIds: Array.from({ length: 11 }, (_, i) => `s${i}`) }],
    ['un identifiant trop long', { scholarshipIds: ['a'.repeat(65)] }],
    ['un nombre', { scholarshipIds: [42] }],
    ['pas de liste', {}],
    ['un champ inconnu', { scholarshipIds: ['s1'], userId: 'someone-else' }],
  ])('refuse %s', async (_label, value) => {
    await expect(validate(value)).rejects.toBeInstanceOf(BadRequestException);
  });
});
