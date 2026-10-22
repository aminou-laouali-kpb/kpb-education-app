import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  CAMPAIGN_ROUTE_PATTERN,
  CAMPAIGN_ROUTE_PRESETS,
  campaignRouteForBody,
  campaignRouteLabel,
  campaignRoutePreset,
  isValidCampaignRoute,
} from './campaign-route';

const labels: Record<string, string> = {
  home: 'Accueil',
  legalPrivacy: 'Politique de confidentialité',
  scholarships: 'Bourses',
  eef: 'Études en France',
  profile: 'Profil',
};
const label = (key: string) => labels[key] ?? key;

describe('route au tap d’une campagne (audit 57, F11)', () => {
  it('la regex est celle du DTO serveur, octet pour octet', () => {
    const dto = readFileSync(
      join(
        __dirname,
        '..',
        '..',
        'backend',
        'src',
        'modules',
        'notifications',
        'dto',
        'create-notification-campaign.dto.ts',
      ),
      'utf8',
    );
    const serverPattern = /@Matches\((\/\^.*\$\/),/.exec(dto)?.[1];
    expect(serverPattern).toBe(String(CAMPAIGN_ROUTE_PATTERN));
    expect(dto).toContain('@MaxLength(200)');
  });

  it('propose la politique de confidentialité, et l’accueil par défaut', () => {
    expect(CAMPAIGN_ROUTE_PRESETS[0]).toEqual({ value: '', key: 'home' });
    expect(CAMPAIGN_ROUTE_PRESETS.map((p) => p.value)).toContain('/legal/privacy');
    for (const preset of CAMPAIGN_ROUTE_PRESETS) {
      expect(isValidCampaignRoute(preset.value)).toBe(true);
    }
  });

  it('valide la saisie libre comme le serveur', () => {
    expect(isValidCampaignRoute('/scholarships/abc-123')).toBe(true);
    expect(isValidCampaignRoute('  /parcours/aicha_k  ')).toBe(true);
    expect(isValidCampaignRoute('https://kpbeducation.cloud/confidentialite.html')).toBe(false);
    expect(isValidCampaignRoute('legal/privacy')).toBe(false);
    expect(isValidCampaignRoute('/legal/privacy?x=1')).toBe(false);
    expect(isValidCampaignRoute('/a b')).toBe(false);
    expect(isValidCampaignRoute(`/${'a'.repeat(200)}`)).toBe(false);
  });

  it('envoie null pour l’accueil, la route nettoyée sinon', () => {
    expect(campaignRouteForBody('')).toBeNull();
    expect(campaignRouteForBody('   ')).toBeNull();
    expect(campaignRouteForBody(' /legal/privacy ')).toBe('/legal/privacy');
  });

  it('libellé de l’aperçu et de la liste', () => {
    expect(campaignRouteLabel(null, label)).toBe('Accueil');
    expect(campaignRouteLabel('', label)).toBe('Accueil');
    expect(campaignRouteLabel('/legal/privacy', label)).toBe('Politique de confidentialité (/legal/privacy)');
    expect(campaignRouteLabel('/scholarships/abc', label)).toBe('/scholarships/abc');
    expect(campaignRoutePreset('/scholarships/abc')).toBeNull();
    expect(campaignRoutePreset('/profile')).toBe('profile');
  });

  it('chaque préréglage a son libellé dans les deux langues', () => {
    for (const locale of ['fr', 'en']) {
      const messages = JSON.parse(
        readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'),
      ) as { notifications: Record<string, string> };
      for (const preset of CAMPAIGN_ROUTE_PRESETS) {
        expect(messages.notifications[`route_${preset.key}`], `${locale} route_${preset.key}`).toBeTruthy();
      }
      for (const key of ['routeLabel', 'routeHint', 'route_custom', 'routeCustomLabel', 'routeInvalid', 'previewRoute']) {
        expect(messages.notifications[key], `${locale} ${key}`).toBeTruthy();
      }
    }
  });
});
