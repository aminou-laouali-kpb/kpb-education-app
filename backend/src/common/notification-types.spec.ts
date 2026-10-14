import {
  NOTIFICATION_OPT_OUT_TYPES,
  sanitizeOptOutTypes,
  withOptOut,
} from './notification-types';

/**
 * La clé `followed_scholarship_updates` (chantier C) doit survivre à
 * `sanitizeOptOutTypes` : c'est lui qui filtre ce que le profil écrit et relit.
 * Une clé absente de la liste serait effacée en silence au premier PATCH du
 * profil, et l'étudiant qui a coupé les annonces d'ouverture les recevrait de
 * nouveau sans rien avoir touché.
 */
describe('notification-types — clés de désinscription', () => {
  it('connaît la clé des bourses suivies', () => {
    expect(NOTIFICATION_OPT_OUT_TYPES).toContain('followed_scholarship_updates');
  });

  it('garde la nouvelle clé et écarte les clés inconnues', () => {
    expect(
      sanitizeOptOutTypes([
        'followed_scholarship_updates',
        'scholarship_opened',
        'deadline_reminder',
        42,
        'weekly_digest',
        'followed_scholarship_updates',
      ]),
    ).toEqual(['followed_scholarship_updates', 'weekly_digest']);
  });

  it('pose et retire la clé sans toucher aux autres', () => {
    const on = withOptOut(['daily_scholarship'], 'followed_scholarship_updates', true);
    expect(on).toEqual(['daily_scholarship', 'followed_scholarship_updates']);
    expect(withOptOut(on, 'followed_scholarship_updates', false)).toEqual([
      'daily_scholarship',
    ]);
  });

  it('rend une liste vide pour une entrée qui n’est pas un tableau', () => {
    expect(sanitizeOptOutTypes('followed_scholarship_updates')).toEqual([]);
    expect(sanitizeOptOutTypes(undefined)).toEqual([]);
  });
});
