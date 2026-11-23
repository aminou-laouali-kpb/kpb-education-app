import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { AiQuotaService } from '../ai/ai-quota.service';
import { ToolsController } from './tools.controller';
import { ToolsService } from './tools.service';

// Audit 22/11/2026, constat 16 : le guard décompte avant l'appel au modèle ;
// quand l'outil n'a rien produit (503), l'unité est rendue.
describe('ToolsController — remboursement du quota', () => {
  const consumedAt = new Date('2026-11-22T23:59:59.000Z');
  const req = {
    aiQuotaConsumption: {
      userId: 'user-a',
      feature: 'student_tools',
      consumedAt,
    },
  };

  function build(evaluate: jest.Mock) {
    const refund = jest.fn(async () => undefined);
    const tools = {
      evaluateInterviewAnswer: evaluate,
    } as unknown as ToolsService;
    const quota = { refund } as unknown as AiQuotaService;
    return { controller: new ToolsController(tools, quota), refund };
  }

  const dto = { type: 'visa' as const, question: 'Q ?', answer: 'R.' };

  it('rend l’unité, à la date du décompte, quand l’outil répond 503', async () => {
    const { controller, refund } = build(
      jest.fn().mockRejectedValue(new ServiceUnavailableException()),
    );
    await expect(
      controller.evaluateInterviewAnswer(dto, req),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(refund).toHaveBeenCalledWith({
      userId: 'user-a',
      feature: 'student_tools',
      now: consumedAt,
    });
  });

  it('ne rend rien sur un résultat réel', async () => {
    const { controller, refund } = build(
      jest.fn().mockResolvedValue({ score: 80, strengths: [], improvements: [], modelAnswer: '' }),
    );
    await controller.evaluateInterviewAnswer(dto, req);
    expect(refund).not.toHaveBeenCalled();
  });

  it('ne rend rien sur une autre erreur', async () => {
    const { controller, refund } = build(
      jest.fn().mockRejectedValue(new BadRequestException()),
    );
    await expect(
      controller.evaluateInterviewAnswer(dto, req),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(refund).not.toHaveBeenCalled();
  });

  it('un remboursement en échec ne masque pas la 503', async () => {
    const { controller, refund } = build(
      jest.fn().mockRejectedValue(new ServiceUnavailableException()),
    );
    refund.mockRejectedValueOnce(new Error('db down'));
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    await expect(
      controller.evaluateInterviewAnswer(dto, req),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
