import {
  campaignChannelBlock,
  countCampaignChannels,
  isDeclaredMinor,
  parseCampaignPurpose,
  PROMOTIONS_OPT_OUT,
} from './campaign-purpose';
import { NOTIFICATION_OPT_OUT_TYPES } from '../../common/notification-types';

/**
 * Correctifs 57 (XC-06) : une campagne promotionnelle ne part jamais par
 * e-mail sans consentement, ni en push vers qui l'a coupée.
 */
describe('campaign-purpose', () => {
  const now = new Date('2026-11-01T12:00:00Z');
  const adult = new Date('2000-01-01T00:00:00Z');
  const minor = new Date('2010-06-01T00:00:00Z');

  it('défaut prudent : absent, inconnu ou mal écrit ⇒ promotionnel', () => {
    expect(parseCampaignPurpose(undefined)).toBe('promotional');
    expect(parseCampaignPurpose(null)).toBe('promotional');
    expect(parseCampaignPurpose('info')).toBe('promotional');
    expect(parseCampaignPurpose('INFORMATIONAL')).toBe('promotional');
    expect(parseCampaignPurpose('promotional')).toBe('promotional');
    expect(parseCampaignPurpose('informational')).toBe('informational');
  });

  it('la clé de désinscription push est une clé connue du profil', () => {
    expect(NOTIFICATION_OPT_OUT_TYPES).toContain(PROMOTIONS_OPT_OUT);
    expect(PROMOTIONS_OPT_OUT).toBe('kpb_promotions');
  });

  it('promotionnel, e-mail : seulement avec le consentement (défaut NON)', () => {
    expect(campaignChannelBlock('promotional', 'email', {}, now)).toBe('email_no_consent');
    expect(
      campaignChannelBlock('promotional', 'email', { promotionsEmailOptIn: false, birthDate: adult }, now),
    ).toBe('email_no_consent');
    expect(
      campaignChannelBlock('promotional', 'email', { promotionsEmailOptIn: true, birthDate: adult }, now),
    ).toBeNull();
    // Âge inconnu : le consentement suffit (on ne peut pas savoir).
    expect(campaignChannelBlock('promotional', 'email', { promotionsEmailOptIn: true }, now)).toBeNull();
  });

  it('promotionnel, e-mail : un mineur déclaré exige AUSSI l’accord du représentant légal', () => {
    expect(
      campaignChannelBlock('promotional', 'email', { promotionsEmailOptIn: true, birthDate: minor }, now),
    ).toBe('email_minor_without_guardian');
    expect(
      campaignChannelBlock(
        'promotional',
        'email',
        { promotionsEmailOptIn: true, birthDate: minor, guardianConsentedAt: now },
        now,
      ),
    ).toBeNull();
    // Sans consentement, le mineur reste bloqué d'abord pour ça.
    expect(
      campaignChannelBlock('promotional', 'email', { birthDate: minor, guardianConsentedAt: now }, now),
    ).toBe('email_no_consent');
  });

  it('promotionnel, push : jamais vers un compte qui a coupé kpb_promotions', () => {
    expect(campaignChannelBlock('promotional', 'push', {}, now)).toBeNull();
    expect(
      campaignChannelBlock('promotional', 'push', { disabledNotificationTypes: ['weekly_digest'] }, now),
    ).toBeNull();
    expect(
      campaignChannelBlock('promotional', 'push', { disabledNotificationTypes: ['kpb_promotions'] }, now),
    ).toBe('push_opted_out');
  });

  it('informationnel : aucun filtre de plus qu’avant', () => {
    const r = { disabledNotificationTypes: ['kpb_promotions'], birthDate: minor };
    expect(campaignChannelBlock('informational', 'push', r, now)).toBeNull();
    expect(campaignChannelBlock('informational', 'email', r, now)).toBeNull();
  });

  it('majorité : 18 ans révolus au jour près', () => {
    expect(isDeclaredMinor(new Date('2008-11-01T12:00:00Z'), now)).toBe(false);
    expect(isDeclaredMinor(new Date('2008-11-02T00:00:00Z'), now)).toBe(true);
    expect(isDeclaredMinor(null, now)).toBe(false);
  });

  it('compte par canal ce qui partira réellement', () => {
    const recipients = [
      { promotionsEmailOptIn: true, birthDate: adult },
      { promotionsEmailOptIn: false, disabledNotificationTypes: ['kpb_promotions'] },
      { promotionsEmailOptIn: true, birthDate: minor },
      {},
    ];
    expect(countCampaignChannels('promotional', ['push', 'email'], recipients, now)).toEqual([
      { channel: 'push', eligible: 3, blocked: { push_opted_out: 1 } },
      {
        channel: 'email',
        eligible: 1,
        blocked: { email_no_consent: 2, email_minor_without_guardian: 1 },
      },
    ]);
    expect(countCampaignChannels('informational', ['email'], recipients, now)).toEqual([
      { channel: 'email', eligible: 4, blocked: {} },
    ]);
  });
});
