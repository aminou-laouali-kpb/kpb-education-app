import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';

import { CreateCaseMessageDto } from './create-case-message.dto';

/**
 * Contrat du corps de `POST /cases/:id/messages` avec l'app, passé dans la
 * MÊME ValidationPipe que `main.ts` (liste blanche stricte).
 *
 * Jusqu'à la revue avant la 58, l'app envoyait aussi `senderName` et
 * `senderRole` : `forbidNonWhitelisted` refusait alors CHAQUE message d'élève
 * en 400 (« property senderName should not exist »), en production depuis
 * juin. Les tests de l'app passaient par un serveur simulé qui acceptait tout.
 *
 * Les corps ci-dessous sont, clé pour clé, ceux de
 * `AppController.caseMessagePayload` (lib/app/core/controllers/
 * app_controller/cases.dart), vérifiés côté app par le test « (g) » de
 * test/core/controllers/case_message_outbox_flow_test.dart.
 */
describe("CreateCaseMessageDto — contrat avec le corps envoyé par l'app", () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });
  const validate = (value: unknown) =>
    pipe.transform(value, { type: 'body', metatype: CreateCaseMessageDto });

  it("serveur d'avant ce champ : le 400 nomme clientMessageId (repli de l'app)", async () => {
    // Le DTO tel qu'en production avant ce correctif. L'app 58 reconnaît ce
    // refus au nom du champ dans la réponse, et renvoie une fois sans lui.
    class LegacyCreateCaseMessageDto {
      @IsString()
      @IsNotEmpty()
      body!: string;
    }
    const error = await pipe
      .transform(
        { body: 'Bonjour', clientMessageId: 'user-1' },
        { type: 'body', metatype: LegacyCreateCaseMessageDto },
      )
      .catch((e: unknown) => e);
    expect(error).toBeInstanceOf(BadRequestException);
    expect(
      JSON.stringify((error as BadRequestException).getResponse()),
    ).toContain('property clientMessageId should not exist');
  });

  it("accepte le corps de l'app avec identifiant client", async () => {
    await expect(
      validate({ body: 'Bonjour', clientMessageId: 'user-1794136840140550' }),
    ).resolves.toMatchObject({
      body: 'Bonjour',
      clientMessageId: 'user-1794136840140550',
    });
  });

  it('accepte le corps sans identifiant (renvoi de repli, anciennes entrées)', async () => {
    await expect(validate({ body: 'Bonjour' })).resolves.toMatchObject({
      body: 'Bonjour',
    });
  });

  it.each([
    ['senderName', { body: 'Bonjour', senderName: 'Awa' }],
    ['senderRole', { body: 'Bonjour', senderRole: 'student' }],
    ['inconnu', { body: 'Bonjour', foo: 'bar' }],
  ])('refuse un champ hors du DTO (%s)', async (_label, value) => {
    await expect(validate(value)).rejects.toBeInstanceOf(BadRequestException);
  });
});
