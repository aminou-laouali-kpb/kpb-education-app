/**
 * Route ouverte au tap d'une notification de campagne (audit 57, F11).
 *
 * Le DTO du serveur (`CreateNotificationCampaignDto.route`) accepte une route
 * INTERNE de l'app, et l'exécuteur la pose dans la charge du push ; sans elle,
 * l'app ouvre l'accueil. La console n'envoyait jamais ce champ : la campagne
 * « Notre politique évolue » déposait l'élève sur l'accueil, sans accès direct
 * à la politique.
 *
 * Les routes proposées sont celles que l'app 2.3.1 (57) sait ouvrir
 * (`AppRoutes.normalizeExternalRoute`) ; une route inconnue de la build
 * installée ouvre l'accueil — c'est le cas de `/legal/privacy` sur les
 * builds 2.3.0 et plus anciennes.
 */

/** Même expression que `@Matches` du DTO serveur. */
export const CAMPAIGN_ROUTE_PATTERN = /^\/[A-Za-z0-9\-_/]*$/;

/** Longueur maximale acceptée par le DTO (`@MaxLength(200)`). */
export const CAMPAIGN_ROUTE_MAX_LENGTH = 200;

export const CAMPAIGN_ROUTE_PRESETS = [
  { value: '', key: 'home' },
  { value: '/legal/privacy', key: 'legalPrivacy' },
  { value: '/scholarships', key: 'scholarships' },
  { value: '/etudes-en-france', key: 'eef' },
  { value: '/profile', key: 'profile' },
] as const;

export type CampaignRoutePresetKey = (typeof CAMPAIGN_ROUTE_PRESETS)[number]['key'];

/** Valeur du menu déroulant qui ouvre la saisie libre. */
export const CUSTOM_ROUTE_CHOICE = '__custom__';

/** La route saisie, sans espaces autour ; vide = accueil. */
export function normalizeCampaignRoute(raw: string): string {
  return raw.trim();
}

/** `true` si le serveur acceptera la route (vide compris : accueil). */
export function isValidCampaignRoute(raw: string): boolean {
  const route = normalizeCampaignRoute(raw);
  if (route === '') return true;
  return route.length <= CAMPAIGN_ROUTE_MAX_LENGTH && CAMPAIGN_ROUTE_PATTERN.test(route);
}

/** Le champ `route` du corps de création : `null` pour l'accueil. */
export function campaignRouteForBody(raw: string): string | null {
  const route = normalizeCampaignRoute(raw);
  return route === '' ? null : route;
}

/** Le préréglage qui porte cette route, ou `null` pour une route libre. */
export function campaignRoutePreset(route: string | null | undefined): CampaignRoutePresetKey | null {
  const value = normalizeCampaignRoute(route ?? '');
  return CAMPAIGN_ROUTE_PRESETS.find((preset) => preset.value === value)?.key ?? null;
}

/**
 * Ce qu'affichent l'aperçu et la liste : « Politique de confidentialité
 * (/legal/privacy) », « Accueil », ou la route libre telle quelle.
 * [label] donne le libellé d'un préréglage dans la langue de l'admin.
 */
export function campaignRouteLabel(
  route: string | null | undefined,
  label: (key: CampaignRoutePresetKey) => string,
): string {
  const value = normalizeCampaignRoute(route ?? '');
  const preset = campaignRoutePreset(value);
  if (preset === 'home') return label('home');
  if (preset) return `${label(preset)} (${value})`;
  return value;
}
