import { decide, type AssistFacts } from './assist-bridge.guards';
import { nextSendableAt, shortExcerpt } from './assist-bridge.service';

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const now = new Date('2026-10-17T12:00:00Z');

function facts(over: Partial<AssistFacts> = {}): AssistFacts {
  return {
    mode: 'on',
    now,
    detectedAt: new Date(now.getTime() - 60 * 1000),
    isStudent: true,
    optedOut: false,
    sanctioned: false,
    sourceVisible: true,
    coachSourceClosed: false,
    featureAvailable: true,
    featureUsedRecently: false,
    lastNeedSentAt: null,
    lastAnySentAt: null,
    quietHours: false,
    ...over,
  };
}

/**
 * Bot « Passerelle » — garde-fous (fonction pure) : 1 notification par élève
 * sur 72 h, un même besoin pas avant 30 jours, désinscription, sanctions,
 * source disparue, fonction coupée ou déjà utilisée, heures calmes, shadow.
 */
describe('Passerelle — garde-fous', () => {
  it('tout est bon : envoi', () => {
    expect(decide(facts())).toEqual({ action: 'send' });
  });

  it.each<[string, Partial<AssistFacts>, string]>([
    ['compte non élève', { isStudent: false }, 'not_student'],
    ['désinscrit (clé assist_bridge)', { optedOut: true }, 'opt_out'],
    ['lecture seule ou banni', { sanctioned: true }, 'sanctioned'],
    ['source coach refermée', { coachSourceClosed: true }, 'coach_source_off'],
    ['publication masquée, supprimée ou d’un autre', { sourceVisible: false }, 'source_not_visible'],
    ['fonction coupée (drapeau, offre absente)', { featureAvailable: false }, 'feature_unavailable'],
    ['fonction déjà utilisée récemment', { featureUsedRecently: true }, 'feature_used'],
  ])('%s → %s', (_label, over, reason) => {
    expect(decide(facts(over))).toEqual({ action: 'skip', reason });
  });

  it('72 h : une seule notification passerelle par élève', () => {
    expect(decide(facts({ lastAnySentAt: new Date(now.getTime() - 71 * HOUR) }))).toEqual({ action: 'skip', reason: 'user_cap' });
    expect(decide(facts({ lastAnySentAt: new Date(now.getTime() - 73 * HOUR) }))).toEqual({ action: 'send' });
  });

  it('30 jours : un même besoin n’est pas re-proposé', () => {
    expect(decide(facts({ lastNeedSentAt: new Date(now.getTime() - 29 * DAY), lastAnySentAt: new Date(now.getTime() - 29 * DAY) }))).toEqual({
      action: 'skip',
      reason: 'need_cooldown',
    });
    expect(decide(facts({ lastNeedSentAt: new Date(now.getTime() - 31 * DAY), lastAnySentAt: new Date(now.getTime() - 31 * DAY) }))).toEqual({
      action: 'send',
    });
  });

  it('l’ordre : le droit d’envoyer avant la pertinence (désinscrit ET fonction utilisée → opt_out)', () => {
    expect(decide(facts({ optedOut: true, featureUsedRecently: true, sanctioned: true }))).toEqual({ action: 'skip', reason: 'opt_out' });
  });

  it('heures calmes : report, jamais un envoi la nuit ; trop vieux : abandon', () => {
    expect(decide(facts({ quietHours: true }))).toEqual({ action: 'defer' });
    expect(decide(facts({ quietHours: true, detectedAt: new Date(now.getTime() - 49 * HOUR) }))).toEqual({
      action: 'skip',
      reason: 'expired',
    });
  });

  it('shadow : tous les garde-fous, puis « shadow » au lieu d’envoyer (même la nuit)', () => {
    expect(decide(facts({ mode: 'shadow' }))).toEqual({ action: 'skip', reason: 'shadow' });
    expect(decide(facts({ mode: 'shadow', quietHours: true }))).toEqual({ action: 'skip', reason: 'shadow' });
    expect(decide(facts({ mode: 'shadow', optedOut: true }))).toEqual({ action: 'skip', reason: 'opt_out' });
    expect(decide(facts({ mode: 'shadow', lastAnySentAt: new Date(now.getTime() - HOUR) }))).toEqual({ action: 'skip', reason: 'user_cap' });
  });

  it('nextSendableAt : la première heure pleine hors fenêtre calme locale', () => {
    // Niger = UTC+1 : 22 h locale (21 h UTC) → 8 h locale = 7 h UTC le lendemain.
    const at = nextSendableAt(new Date('2026-10-17T21:30:00Z'), 'Niger');
    expect(at.toISOString()).toBe('2026-10-18T07:00:00.000Z');
  });

  it('shortExcerpt : jetons lisibles, coupé au mot', () => {
    expect(shortExcerpt('Qui connaît @[Bourse Eiffel](scholarship:abc) ?')).toBe('Qui connaît @Bourse Eiffel ?');
    const long = shortExcerpt('mot '.repeat(80));
    expect(long.length).toBeLessThanOrEqual(120);
    expect(long.endsWith('…')).toBe(true);
  });
});
