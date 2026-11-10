import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { CaseType } from '../../../common/enums/case-type.enum';
import {
  CASE_CONTEXT_LABEL_MAX,
  CASE_DESCRIPTION_MAX,
  CASE_TITLE_MAX,
  clampCaseText,
  CreateCaseDto,
} from './create-case.dto';

/**
 * Contrat du corps de `POST /cases`, passé dans la MÊME ValidationPipe que
 * `main.ts`.
 *
 * Audit avant la 59 : un récit de plus de 2 000 caractères recevait un 400.
 * L'app avait déjà dit « transmise à l'équipe » et réessayait sans fin ; aucun
 * conseiller ne recevait la demande. Le serveur coupe désormais au lieu de
 * refuser, parce que les apps déjà installées n'ont aucune limite de saisie.
 */
describe("CreateCaseDto — un texte trop long est coupé, jamais refusé", () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });
  const validate = (value: unknown) =>
    pipe.transform(value, {
      type: 'body',
      metatype: CreateCaseDto,
    }) as Promise<CreateCaseDto>;

  const body = (over: Record<string, unknown> = {}) => ({
    type: CaseType.ScholarshipSupport,
    title: 'Bourse Eiffel',
    description: 'Bonjour',
    contextLabel: 'Bourse',
    preferredContactMethod: 'whatsapp',
    ...over,
  });

  it('accepte le corps ordinaire de l’app sans le modifier', async () => {
    const dto = await validate(body());
    expect(dto.title).toBe('Bourse Eiffel');
    expect(dto.description).toBe('Bonjour');
    expect(dto.contextLabel).toBe('Bourse');
  });

  it('un récit de 2 001 caractères passe en entier (il était refusé)', async () => {
    const story = 'a'.repeat(2001);
    const dto = await validate(body({ description: story }));
    expect(dto.description).toBe(story);
  });

  it('au-delà de la limite, le récit est coupé et la demande arrive', async () => {
    const dto = await validate(
      body({ description: 'b'.repeat(CASE_DESCRIPTION_MAX + 500) }),
    );
    expect(dto.description).toHaveLength(CASE_DESCRIPTION_MAX);
  });

  it('un intitulé et un contexte trop longs sont coupés', async () => {
    const dto = await validate(
      body({
        title: 't'.repeat(CASE_TITLE_MAX + 40),
        contextLabel: 'c'.repeat(CASE_CONTEXT_LABEL_MAX + 40),
      }),
    );
    expect(dto.title).toHaveLength(CASE_TITLE_MAX);
    expect(dto.contextLabel).toHaveLength(CASE_CONTEXT_LABEL_MAX);
  });

  it('ne laisse pas un émoji coupé en deux en fin de texte', () => {
    // « 😀 » occupe deux unités UTF-16 : la coupe tombe au milieu.
    const cut = clampCaseText('ab😀', 3) as string;
    expect(cut).toBe('ab');
  });

  it('laisse la validation refuser ce qui n’est pas un texte', async () => {
    await expect(validate(body({ description: 42 }))).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(validate(body({ title: undefined }))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('refuse toujours un champ inconnu (liste blanche stricte)', async () => {
    await expect(validate(body({ senderRole: 'admin' }))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
