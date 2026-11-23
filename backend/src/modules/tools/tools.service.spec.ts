import { ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { CvSummaryDto, LETTER_TIMEOUT_MS, ToolsService } from './tools.service';

type CompleteJsonParams = {
  system: string;
  user: string;
  maxTokens?: number;
  fallback: { fr: string; en: string };
  timeoutMs?: number;
};

function buildService(isConfigured: boolean) {
  const completeJson = jest.fn(async (params: CompleteJsonParams) => ({
    data: { fr: 'Résumé FR', en: 'Summary EN' },
    model: 'test-model',
    params,
  }));
  const llm = { isConfigured, completeJson } as unknown as LlmService;
  return { service: new ToolsService(llm), completeJson };
}

const dto: CvSummaryDto = {
  name: 'Awa Traoré',
  studyLevel: 'Bachelor 3',
  fieldOfStudy: 'Informatique',
  targetCountry: 'France',
  targetLevel: 'Master',
  countryOfResidence: 'Burkina Faso',
  skills: ['Python', 'Analyse de données'],
  languages: ['Français', 'Anglais (B2)'],
  experience: 'Stage KPB Education, 2024',
  objective: 'Intégrer un Master en Informatique.',
};

describe('ToolsService.generateCvSummary', () => {
  it('answers 503 when the AI provider is not configured on the server', async () => {
    // This is the ONLY legitimate reason for the app to show "AI unavailable";
    // it must stay distinguishable from a network failure client-side.
    const { service } = buildService(false);
    await expect(service.generateCvSummary(dto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('forwards every profile fact it receives into the prompt context except the civil name', async () => {
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary(dto);

    const { user } = completeJson.mock.calls[0][0];
    // IA-T2: the previous assertion `toContain('Awa Traoré')` required the
    // leak. Inverting it is the harness repair, not a behaviour change we
    // forgot to test — the name must not reach Groq.
    expect(user).not.toContain('Awa Traoré');
    expect(user).not.toContain('Nom :');
    expect(user).toContain('Bachelor 3');
    expect(user).toContain('Informatique');
    expect(user).toContain('Burkina Faso');
    expect(user).toContain('France');
    expect(user).toContain('Master');
    expect(user).toContain('Analyse de données');
    expect(user).toContain('Anglais (B2)');
    expect(user).toContain('Stage KPB Education, 2024');
    expect(user).toContain('Intégrer un Master en Informatique.');
  });

  it('omits the optional lines that were not provided', async () => {
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary({
      name: 'Awa',
      studyLevel: 'Terminale',
      fieldOfStudy: 'Santé',
    });

    const { user } = completeJson.mock.calls[0][0];
    expect(user).not.toContain('Pays cible');
    expect(user).not.toContain('Objectif professionnel');
    expect(user).not.toContain('undefined');
  });

  it('forbids emoji so the generated CV PDF cannot render tofu boxes', async () => {
    // The client PDF uses the `pdf` package's built-in Helvetica: no glyph
    // above U+00FF, so an emoji is drawn as an empty rectangle. The client
    // sanitises defensively; the prompt keeps preview and PDF identical.
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary(dto);

    const { system } = completeJson.mock.calls[0][0];
    expect(system).toMatch(/emoji/i);
    expect(system).toContain('texte simple');
  });

  it('returns the provider payload unchanged', async () => {
    const { service } = buildService(true);
    await expect(service.generateCvSummary(dto)).resolves.toEqual({
      fr: 'Résumé FR',
      en: 'Summary EN',
    });
  });
});

describe('ToolsService.personalizeLetters', () => {
  it('does not forward the student name into the Groq prompt', async () => {
    const { service, completeJson } = buildService(true);
    await service.personalizeLetters({
      templateKey: 'visa',
      templateBody: 'Madame, Monsieur,',
      name: 'Awa Traoré',
      fieldOfStudy: 'Informatique',
      targetCountry: 'France',
    });

    const { user } = completeJson.mock.calls[0][0];
    expect(user).not.toContain('Awa Traoré');
    expect(user).not.toContain('Nom :');
    expect(user).toContain('Informatique');
    expect(user).toContain('France');
  });

  it('gives the long FR+EN generation more than the short-call timeout', async () => {
    const { service, completeJson } = buildService(true);
    await service.personalizeLetters({
      templateKey: 'admission_master',
      templateBody: 'Madame, Monsieur,',
      fieldOfStudy: 'Informatique',
    });

    expect(completeJson.mock.calls[0][0].timeoutMs).toBe(LETTER_TIMEOUT_MS);
    // Two provider attempts must still fit in the app's 90 s AI timeout.
    expect(2 * LETTER_TIMEOUT_MS).toBeLessThan(90_000);
  });

  it('answers 503 rather than passing the untouched template off as personalised', async () => {
    const { service, completeJson } = buildService(true);
    completeJson.mockImplementationOnce(async (params: CompleteJsonParams) => ({
      data: params.fallback,
      model: 'local-fallback',
      params,
    }));

    await expect(
      service.personalizeLetters({
        templateKey: 'admission_master',
        templateBody: 'Madame, Monsieur,',
        fieldOfStudy: 'Informatique',
      }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});

// ── Audit 22/11/2026, constat 16 : plus de faux résultat présenté comme vrai ──

describe('ToolsService — repli fournisseur et forme des sorties', () => {
  const fallbackOnce = (completeJson: jest.Mock) =>
    completeJson.mockImplementationOnce(async (params: { fallback: unknown }) => ({
      data: params.fallback,
      model: 'local-fallback',
    }));
  const answerOnce = (completeJson: jest.Mock, data: unknown) =>
    completeJson.mockImplementationOnce(async () => ({ data, model: 'test-model' }));
  const feedbackDto = {
    type: 'visa' as const,
    question: 'Pourquoi la France ?',
    answer: 'Parce que.',
  };

  it('résumé de CV : 503 au lieu d’une phrase générique quand le fournisseur échoue', async () => {
    const { service, completeJson } = buildService(true);
    fallbackOnce(completeJson);
    await expect(service.generateCvSummary(dto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('résumé de CV : 503 quand le JSON n’a pas la bonne forme', async () => {
    const { service, completeJson } = buildService(true);
    answerOnce(completeJson, { fr: 'Texte', en: '' });
    await expect(service.generateCvSummary(dto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    answerOnce(completeJson, { fr: 42, en: 'Text' });
    await expect(service.generateCvSummary(dto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('lettre : 503 quand le JSON n’a pas la bonne forme', async () => {
    const { service, completeJson } = buildService(true);
    answerOnce(completeJson, { fr: ['x'], en: 'Letter' });
    await expect(
      service.personalizeLetters({
        templateKey: 'visa',
        templateBody: 'Madame, Monsieur,',
        fieldOfStudy: 'Informatique',
      }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('évaluation d’entretien : 503 au lieu de la note fictive de 70/100', async () => {
    const { service, completeJson } = buildService(true);
    fallbackOnce(completeJson);
    await expect(
      service.evaluateInterviewAnswer(feedbackDto),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('évaluation d’entretien : note normalisée et bornée, listes de textes', async () => {
    const { service, completeJson } = buildService(true);
    answerOnce(completeJson, {
      score: '85',
      strengths: 'Réponse directe.',
      improvements: ['Citer un exemple.', '', 7],
      modelAnswer: 'Je choisis la France pour…',
    });
    await expect(service.evaluateInterviewAnswer(feedbackDto)).resolves.toEqual({
      score: 85,
      strengths: ['Réponse directe.'],
      improvements: ['Citer un exemple.'],
      modelAnswer: 'Je choisis la France pour…',
    });

    answerOnce(completeJson, { score: 140, strengths: [], improvements: [] });
    await expect(service.evaluateInterviewAnswer(feedbackDto)).resolves.toMatchObject({
      score: 100,
      modelAnswer: '',
    });
  });

  it('évaluation d’entretien : 503 si la note manque ou n’est pas un nombre', async () => {
    const { service, completeJson } = buildService(true);
    answerOnce(completeJson, { score: 'bien', strengths: [], improvements: [] });
    await expect(
      service.evaluateInterviewAnswer(feedbackDto),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    answerOnce(completeJson, { strengths: ['x'], improvements: ['y'] });
    await expect(
      service.evaluateInterviewAnswer(feedbackDto),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('questions d’entretien : une sortie mal formée retombe sur la liste type', async () => {
    const { service, completeJson } = buildService(true);
    answerOnce(completeJson, { questions: 'pas une liste' });
    const result = await service.getInterviewQuestions({ type: 'visa' });
    expect(result.questions).toHaveLength(6);
    expect(result.questions.every((q) => typeof q === 'string' && q.length > 0)).toBe(true);

    answerOnce(completeJson, { questions: ['Q1 ?', '', 3, 'Q2 ?'] });
    await expect(service.getInterviewQuestions({ type: 'visa' })).resolves.toEqual({
      questions: ['Q1 ?', 'Q2 ?'],
    });
  });
});
