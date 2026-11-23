// L'invite envoyée à Groq, inspectée — la garde qui manquait.
//
// ## Ce qui s'est passé
//
// L'écran de consentement IA affiche, mot pour mot, avant tout appel :
//
//   « Ton nom civil n'est pas recopié dans l'invite. »
//   « Your civil name is not copied into the prompt. »
//
// Il l'était. Le client postait `profile.fullName` (app_controller.dart) et
// `createSession` sérialisait l'objet `profile` ENTIER dans le message `user`
// du LLM. Le lot 11 avait retiré `Nom : ${dto.name}` des routes /tools et
// manqué celle-ci — or c'est la surface la plus utilisée de l'app, et c'est
// précisément celle que garde `AiConsentGuard`. Le consentement était donc
// recueilli sur une phrase fausse.
//
// ## Pourquoi la suite existante ne pouvait pas le voir
//
// Deux raisons, et la seconde est la plus instructive :
//
//   · `orientation.service.spec.ts` stube `completeJson` en ne déstructurant
//     que `fallback` — l'invite n'était jamais regardée. Trois tests passaient
//     `fullName: 'Aminata Diallo'` sans jamais demander où il allait ;
//   · `orientation.controller.spec.ts` ASSERTE `profile.fullName === 'A'`. Le
//     test avait raison sur son sujet (le contrôleur ne doit pas laisser le
//     client usurper un `id`) mais il donnait au lecteur l'impression que la
//     traversée du nom était voulue.
//
// Une garde qui ne lit pas la charge utile ne garde rien. Celle-ci la lit.

import { Test, TestingModule } from '@nestjs/testing';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrientationService } from './orientation.service';
import { ORIENTATION_FIELDS } from './orientation-fields.data';

/** Sortie bien formée du modèle : une explication par filière. */
function validLlmOutput() {
  return {
    data: {
      recommendations: ORIENTATION_FIELDS.map((field) => ({
        fieldId: field.id,
        explanationFr: `Explication ${field.id}.`,
        explanationEn: `Explanation ${field.id}.`,
      })),
    },
    model: 'test-model',
    billed: true,
  };
}

/// Ce que la projection est autorisée à contenir. La liste est CLOSE : ajouter
/// un champ au corps de la requête ne suffit pas à le faire entrer dans
/// l'invite, il faut le déclarer ici — donc y penser.
const ALLOWED = [
  'currentLevel',
  'fieldIds',
  'preferredLanguage',
  'targetCountryIds',
];

/// Les données que l'utilisateur nous confie et qui n'ont aucune raison de
/// partir chez un tiers pour obtenir une recommandation de filière.
const NEVER_SENT = [
  'Aminata Diallo',
  'Aminata',
  'Diallo',
  'aminata@example.org',
  '+22790000000',
  'Fatima Diallo',
  '2008-04-11',
  'user-42',
];

describe("l'invite d'orientation", () => {
  let service: OrientationService;
  let completeJson: jest.Mock;

  beforeEach(async () => {
    completeJson = jest.fn(async () => validLlmOutput());
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrientationService,
        { provide: LlmService, useValue: { completeJson } },
        { provide: PrismaService, useValue: { tryExecute: async () => null } },
      ],
    }).compile();
    service = module.get<OrientationService>(OrientationService);
  });

  /// Un corps de requête réaliste : exactement ce que le client envoie
  /// aujourd'hui, plus les champs qu'un client plus bavard pourrait joindre.
  const submit = () =>
    service.createSession({
      answers: { interests: ['tech'], ai_concern: ['ai_yes'] },
      profile: {
        id: 'user-42',
        fullName: 'Aminata Diallo',
        email: 'aminata@example.org',
        phone: '+22790000000',
        whatsapp: '+22790000000',
        birthDate: '2008-04-11',
        guardianName: 'Fatima Diallo',
        currentLevel: 'terminale',
        targetCountryIds: ['fr', 'ca'],
        fieldIds: ['d07'],
        preferredLanguage: 'fr',
      },
    });

  const sentToGroq = () => {
    expect(completeJson).toHaveBeenCalledTimes(1);
    return completeJson.mock.calls[0][0] as { system: string; user: string };
  };

  it('ne porte aucune donnée identifiante', async () => {
    await submit();
    const { system, user } = sentToGroq();
    const sent = `${system}\n${user}`;
    for (const secret of NEVER_SENT) {
      expect(sent).not.toContain(secret);
    }
  });

  it('porte bien les faits que l\'écran de consentement annonce', async () => {
    // Sans cette assertion, vider l'invite rendrait le test précédent vert
    // pour rien — et l'orientation cesserait d'être personnalisée sans que
    // personne ne le voie.
    await submit();
    const { user } = sentToGroq();
    expect(user).toContain('terminale');
    expect(user).toContain('d07');
    expect(user).toContain('interests');
  });

  it('expose une projection CLOSE, pas l\'objet du client', async () => {
    await submit();
    const payload = JSON.parse(sentToGroq().user) as {
      profile: Record<string, unknown>;
    };
    expect(Object.keys(payload.profile).sort()).toEqual(ALLOWED);
  });

  it('ne laisse pas un client faire passer un objet dans un champ texte',
    async () => {
      await service.createSession({
        answers: { interests: ['tech'] },
        profile: {
          currentLevel: { nested: 'Aminata Diallo' },
          preferredLanguage: ['fr', 'Diallo'],
          targetCountryIds: ['fr', { smuggled: 'Aminata' }],
          fieldIds: ['d07'],
        },
      });
      const { user } = sentToGroq();
      expect(user).not.toContain('Aminata');
      expect(user).not.toContain('Diallo');
      expect(user).not.toContain('smuggled');
    });
});
