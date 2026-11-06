/**
 * L'accueil de l'assistant porte LE nom de l'app (audit build 57, T5-03) : il
 * se présentait « Coach KPB » quand l'écran d'entrée dit « KPB Intelligence ».
 * Les conversations déjà créées gardent l'ancien accueil en base : il est
 * réécrit à la lecture, pour l'élève comme pour l'historique rejoué au modèle.
 */
import { COACH_GREETING, currentGreeting } from './coach.service';

describe('accueil de KPB Intelligence', () => {
  it('se présente sous un seul nom', () => {
    for (const greeting of Object.values(COACH_GREETING)) {
      expect(greeting).toContain('KPB Intelligence');
      expect(greeting).not.toMatch(/Coach/);
    }
  });

  it('réécrit à la lecture les accueils enregistrés sous l’ancien nom', () => {
    expect(
      currentGreeting(
        "Salut ! Je suis ton Coach KPB. Pose-moi tes questions sur les études à l'étranger, le budget ou les écoles partenaires.",
      ),
    ).toBe(COACH_GREETING.fr);
    expect(
      currentGreeting(
        "Hi! I'm your KPB Coach. Ask me anything about studying abroad, your budget, or partner schools.",
      ),
    ).toBe(COACH_GREETING.en);
  });

  it('ne touche à aucun autre message, même s’il cite le Coach', () => {
    const autre = 'Le Coach KPB a dit : candidate avant le 15 janvier.';
    expect(currentGreeting(autre)).toBe(autre);
  });
});
