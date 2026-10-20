import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { ForfeitPrizeDto } from './referral-campaign.dto';

/// Les MÊMES options que `main.ts`.
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

describe('ForfeitPrizeDto', () => {
  const run = (body: unknown) => pipe.transform(body, { type: 'body', metatype: ForfeitPrizeDto });

  it('nomme le lauréat affiché', async () => {
    await expect(run({ participantId: 'p1', reason: 'Injoignable' })).resolves.toMatchObject({
      participantId: 'p1',
    });
  });

  // Audit 57, F17 : le lauréat a supprimé son compte, le prix n'a plus de
  // participant — l'équipe doit pouvoir le déclarer forfait quand même.
  it('accepte un prix sans lauréat (absent ou null)', async () => {
    await expect(run({ reason: 'Compte supprimé' })).resolves.toMatchObject({ reason: 'Compte supprimé' });
    await expect(run({ participantId: null, reason: 'Compte supprimé' })).resolves.toMatchObject({
      participantId: null,
    });
  });

  it('refuse un identifiant vide ou un motif trop court', async () => {
    await expect(run({ participantId: '', reason: 'Injoignable' })).rejects.toBeInstanceOf(BadRequestException);
    await expect(run({ participantId: 'p1', reason: 'x' })).rejects.toBeInstanceOf(BadRequestException);
  });
});
