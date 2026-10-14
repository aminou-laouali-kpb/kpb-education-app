import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { ActivateScholarshipDto } from './activate-scholarship.dto';
import { OpeningPreviewQueryDto } from './opening-preview-query.dto';

/**
 * Le corps de `POST /admin/scholarships/:id/activate`, passé par la MÊME
 * ValidationPipe que `main.ts` (whitelist + forbidNonWhitelisted + transform).
 *
 * Deux contrats à tenir à la fois : l'admin déjà déployé envoie le corps
 * d'avant (sans `notify`) et doit continuer de passer ; le nouvel admin envoie
 * `notify` et `expectedRecipients`, que ce backend doit accepter AVANT que
 * l'admin ne soit déployé.
 */
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

function body(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    academicYear: '2027-2028',
    opensAt: '2027-10-01T00:00:00.000Z',
    closesAt: '2027-11-05T23:59:59.999Z',
    ...overrides,
  };
}

async function activate(value: Record<string, unknown>) {
  return pipe.transform(value, { type: 'body', metatype: ActivateScholarshipDto });
}

async function rejection(value: Record<string, unknown>): Promise<string[]> {
  try {
    await activate(value);
  } catch (error) {
    expect(error).toBeInstanceOf(BadRequestException);
    const response = (error as BadRequestException).getResponse() as {
      message: string[];
    };
    return response.message;
  }
  throw new Error('Le corps aurait dû être refusé.');
}

describe('ActivateScholarshipDto', () => {
  it('accepte le corps exact de l’admin déjà déployé', async () => {
    await expect(
      activate(
        body({
          estimatedOpenAt: '2027-09-01T00:00:00.000Z',
          estimatedCloseAt: '2027-11-01T23:59:59.999Z',
          dateConfidence: 'confirmed',
          sourceUrl: 'https://www.chevening.org/scholarships/',
        }),
      ),
    ).resolves.toBeInstanceOf(ActivateScholarshipDto);
  });

  it.each(['2027', '2027-2028'])('accepte l’année %s (forme du contrat)', async (year) => {
    await expect(activate(body({ academicYear: year }))).resolves.toMatchObject({
      academicYear: year,
    });
  });

  it('refuse deux années non consécutives', async () => {
    const messages = await rejection(body({ academicYear: '2027-2029' }));
    expect(messages).toEqual([
      'academicYear must be one year (2027) or two consecutive years (2027-2028)',
    ]);
  });

  it('garde le message de forme que l’admin déployé connaît', async () => {
    const messages = await rejection(body({ academicYear: '27-28' }));
    expect(messages).toContain('academicYear must look like 2026 or 2026-2027');
  });

  it('accepte notify et expectedRecipients (nouvel admin)', async () => {
    await expect(
      activate(body({ notify: true, expectedRecipients: 312 })),
    ).resolves.toMatchObject({ notify: true, expectedRecipients: 312 });
    await expect(activate(body({ notify: false }))).resolves.toMatchObject({
      notify: false,
    });
    await expect(activate(body({ expectedRecipients: 0 }))).resolves.toMatchObject({
      expectedRecipients: 0,
    });
  });

  it.each([
    ['notify texte', { notify: 'true' }, 'notify must be a boolean value'],
    ['expectedRecipients négatif', { expectedRecipients: -1 }, 'expectedRecipients must not be less than 0'],
    ['expectedRecipients décimal', { expectedRecipients: 3.5 }, 'expectedRecipients must be an integer number'],
    ['expectedRecipients énorme', { expectedRecipients: 1_000_001 }, 'expectedRecipients must not be greater than 1000000'],
  ])('refuse %s', async (_label, overrides, message) => {
    expect(await rejection(body(overrides))).toContain(message);
  });

  it('refuse toujours un champ inconnu', async () => {
    expect(await rejection(body({ audience: 'everyone' }))).toContain(
      'property audience should not exist',
    );
  });
});

describe('OpeningPreviewQueryDto', () => {
  async function preview(value: Record<string, unknown>) {
    return pipe.transform(value, { type: 'query', metatype: OpeningPreviewQueryDto });
  }

  it('accepte une requête vide (le serveur choisit l’année)', async () => {
    await expect(preview({})).resolves.toBeInstanceOf(OpeningPreviewQueryDto);
  });

  it('accepte l’année et les dates du formulaire', async () => {
    await expect(
      preview({
        academicYear: '2028-2029',
        opensAt: '2028-10-01T00:00:00.000Z',
        closesAt: '2028-11-05T23:59:59.999Z',
      }),
    ).resolves.toMatchObject({ academicYear: '2028-2029' });
  });

  it.each([
    [{ academicYear: '2028-2030' }],
    [{ opensAt: 'demain' }],
    [{ lang: 'fr' }],
  ])('refuse %j', async (query) => {
    await expect(preview(query)).rejects.toBeInstanceOf(BadRequestException);
  });
});
