import { describe, expect, it } from 'vitest';

import {
  CAMPAIGN_PURPOSES,
  channelCountLine,
  DEFAULT_CAMPAIGN_PURPOSE,
  previewBody,
} from './campaign-purpose';

const labels = {
  push_no_consent: 'sans consentement push',
  push_opted_out: 'push coupé',
  push_minor_without_guardian: 'mineurs sans accord (push)',
  email_no_consent: 'sans consentement',
  email_minor_without_guardian: 'mineurs sans accord',
};

describe('campaign-purpose (XC-06)', () => {
  it('promotionnel par défaut, et seulement deux finalités', () => {
    expect(DEFAULT_CAMPAIGN_PURPOSE).toBe('promotional');
    expect([...CAMPAIGN_PURPOSES].sort()).toEqual(['informational', 'promotional']);
  });

  it('l’aperçu envoie la finalité et les canaux (push par défaut)', () => {
    expect(previewBody({ audienceType: 'all_users', filters: {}, channels: [], purpose: 'promotional' })).toEqual({
      audienceType: 'all_users',
      filters: {},
      channels: ['push'],
      purpose: 'promotional',
    });
  });

  it('dit le nombre réel par canal et ce qui est filtré', () => {
    expect(
      channelCountLine(
        {
          channel: 'email',
          eligible: 120,
          blocked: { email_no_consent: 40, email_minor_without_guardian: 3 },
        },
        labels,
        'filtrés',
      ),
    ).toBe('email : 120 (filtrés : 40 sans consentement, 3 mineurs sans accord)');
    expect(channelCountLine({ channel: 'push', eligible: 9, blocked: {} }, labels, 'filtrés')).toBe('push : 9');
    // Chantier juridique 57 : le push promotionnel est en opt-in.
    expect(
      channelCountLine(
        {
          channel: 'push',
          eligible: 5,
          blocked: { push_opted_out: 1, push_no_consent: 90, push_minor_without_guardian: 2 },
        },
        labels,
        'filtrés',
      ),
    ).toBe('push : 5 (filtrés : 90 sans consentement push, 1 push coupé, 2 mineurs sans accord (push))');
  });
});
