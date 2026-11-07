import { validate } from 'class-validator';

import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { birthDateAtUtcMidnight, isAtLeastAge } from './profile-age.policy';
import { ProfilesService } from './profiles.service';

describe('profile minimum-age policy', () => {
  const now = new Date('2026-08-23T12:00:00.000Z');

  it('uses calendar age at the exact sixteenth birthday', () => {
    expect(isAtLeastAge('2010-08-23T00:00:00.000Z', 16, now)).toBe(true);
    expect(isAtLeastAge('2010-08-24T00:00:00.000Z', 16, now)).toBe(false);
  });

  it('rejects under-16 and future birth dates at the HTTP DTO boundary', async () => {
    const underAge = new UpdateProfileDto();
    underAge.birthDate = new Date(
      Date.UTC(new Date().getUTCFullYear() - 15, 0, 1),
    ).toISOString();
    expect(await validate(underAge)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: 'birthDate' }),
      ]),
    );

    const future = new UpdateProfileDto();
    future.birthDate = '2999-01-01T00:00:00.000Z';
    expect(await validate(future)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: 'birthDate' }),
      ]),
    );
  });

  it('accepts an adult birth date and keeps the field optional', async () => {
    const adult = new UpdateProfileDto();
    adult.birthDate = '2000-01-01T00:00:00.000Z';
    await expect(validate(adult)).resolves.toHaveLength(0);
    await expect(validate(new UpdateProfileDto())).resolves.toHaveLength(0);
  });

  it('also enforces the floor for direct service callers', async () => {
    const service = new ProfilesService(
      {} as PrismaService,
      {} as StorageService,
    );
    const underAge = new Date();
    underAge.setUTCFullYear(underAge.getUTCFullYear() - 15);

    await expect(
      service.updateMe({ birthDate: underAge.toISOString() }, 'user-a'),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'minimum_age_not_met' }),
    });
  });
});

describe('birthDateAtUtcMidnight (audit 57, T4-06)', () => {
  // L'app envoie le minuit local, sans fuseau ; le serveur tourne en
  // Africa/Niamey (UTC+1). Avant le correctif, la base gardait 23:00Z la veille.
  it.each([
    ['1990-03-15T00:00:00.000', '1990-03-15T00:00:00.000Z'],
    ['1990-03-15', '1990-03-15T00:00:00.000Z'],
    ['1990-03-15T00:00:00.000Z', '1990-03-15T00:00:00.000Z'],
    // Ancienne valeur renvoyée par une app qui l'a relue du serveur.
    ['1990-03-14T23:00:00.000Z', '1990-03-15T00:00:00.000Z'],
    // Minuit local à Nairobi (UTC+3) et à Dakar (UTC+0).
    ['1990-03-15T00:00:00.000+03:00', '1990-03-15T00:00:00.000Z'],
    ['1990-03-15T00:00:00+00:00', '1990-03-15T00:00:00.000Z'],
  ])('%s → %s', (input, expected) => {
    expect(birthDateAtUtcMidnight(input).toISOString()).toBe(expected);
  });

  it('ne dépend pas du fuseau du serveur', () => {
    const before = process.env.TZ;
    process.env.TZ = 'Africa/Niamey';
    try {
      expect(
        birthDateAtUtcMidnight('2008-11-07T00:00:00.000').toISOString(),
      ).toBe('2008-11-07T00:00:00.000Z');
    } finally {
      process.env.TZ = before;
    }
  });

  it('laisse une valeur illisible invalide', () => {
    expect(Number.isNaN(birthDateAtUtcMidnight('pas une date').getTime())).toBe(
      true,
    );
  });
});
