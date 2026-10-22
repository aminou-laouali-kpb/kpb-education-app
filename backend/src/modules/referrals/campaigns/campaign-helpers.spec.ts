import {
  ambassadorCodeFor,
  normalizeReferralCode,
  publicNameFromFullName,
  publicNameIssue,
  refereeDisplayName,
} from '../referral-code';
import {
  editableFields,
  isEligiblePlace,
  nextStatus,
  parsePrizes,
  parseQualificationRule,
  unrankableReason,
} from './campaign-rules';
import { DISPOSABLE_EMAIL_DOMAINS_VERSION, isDisposableEmail } from './disposable-email-domains';
import { isProfileComplete } from './profile-completion';
import { hashAttributionSignals, ipBlock, normalizeIp } from './referral-signals';

describe('codes de parrainage', () => {
  it('normalise casse, espaces, tirets', () => {
    expect(normalizeReferralCode(' ktou-ab-1a2b3c ')).toBe('KTOUAB1A2B3C');
    expect(normalizeReferralCode('k7pq 2mza')).toBe('K7PQ2MZA');
  });

  it('garde l’algorithme historique du code ambassadeur (stable par profil)', () => {
    const a = ambassadorCodeFor('profile-123', 'Binta Sarr');
    expect(a).toMatch(/^KTOU-BS-[0-9a-z]{6}$/);
    expect(ambassadorCodeFor('profile-123', 'Binta Sarr')).toBe(a);
    expect(ambassadorCodeFor('profile-123', '')).toMatch(/^KTOU-XX-/);
  });

  it('nom public « Prénom I. »', () => {
    expect(publicNameFromFullName('aïcha konaté')).toBe('Aïcha K.');
    expect(publicNameFromFullName('Moussa Ibrahim Diallo')).toBe('Moussa D.');
    expect(publicNameFromFullName('Fatou')).toBe('Fatou');
    expect(publicNameFromFullName('  ')).toBe('');
    expect(refereeDisplayName('')).toBe('Filleul');
  });

  it('refuse un nom public qui fuirait un e-mail ou un numéro', () => {
    expect(publicNameIssue('Aïcha K.')).toBeNull();
    expect(publicNameIssue('aicha@gmail.com')).toBe('public_name_contains_email');
    expect(publicNameIssue('Aïcha 90 12 34')).toBe('public_name_contains_digits');
    expect(publicNameIssue('x'.repeat(41))).toBe('public_name_too_long');
  });
});

describe('règles de campagne', () => {
  it('prix de novembre : rangs sans trou, montants entiers', () => {
    expect(
      parsePrizes([
        { rank: 2, amountFcfa: 50000 },
        { rank: 1, amountFcfa: 100000 },
        { rank: 3, amountFcfa: 30000 },
      ]),
    ).toEqual([
      { rank: 1, amountFcfa: 100000 },
      { rank: 2, amountFcfa: 50000 },
      { rank: 3, amountFcfa: 30000 },
    ]);
    expect(parsePrizes([{ rank: 1, amountFcfa: 1 }, { rank: 3, amountFcfa: 1 }])).toBeNull();
    expect(parsePrizes([{ rank: 1, amountFcfa: -5 }])).toBeNull();
    expect(parsePrizes('x')).toBeNull();
  });

  it('règle de qualification : défauts et bornes', () => {
    expect(parseQualificationRule({}).requireAccountCreatedInWindow).toBe(true);
    expect(parseQualificationRule({ ipBurstThreshold: 1 }).ipBurstThreshold).toBe(2);
    expect(parseQualificationRule({ ipBurstThreshold: 'x' }).ipBurstThreshold).toBe(3);
  });

  it('transitions draft → live → frozen → closed', () => {
    expect(nextStatus('draft', 'launch')).toBe('live');
    expect(nextStatus('live', 'freeze')).toBe('frozen');
    expect(nextStatus('frozen', 'close')).toBe('closed');
    expect(nextStatus('draft', 'close')).toBeNull();
    expect(nextStatus('closed', 'unfreeze')).toBeNull();
  });

  it('les dates, prix et l’éligibilité se figent au lancement', () => {
    expect(editableFields('draft')).toContain('startDate');
    expect(editableFields('live')).not.toContain('startDate');
    expect(editableFields('live')).not.toContain('prizes');
    expect(editableFields('closed')).toEqual([]);
  });

  it('villes pilotables (sans accent ni casse), liste vide = toutes', () => {
    expect(isEligiblePlace('niamey', ['Niamey', 'Maradi'])).toBe(true);
    expect(isEligiblePlace('Abidjan', ['Niamey'])).toBe(false);
    expect(isEligiblePlace('', ['Niamey'])).toBe(false);
    expect(isEligiblePlace('Kpalimé', [])).toBe(true);
    expect(isEligiblePlace('Cotonou', ['cotonou'])).toBe(true);
  });

  it('un mineur non autorisé ne peut être ni classé ni primé', () => {
    const base = { status: 'active', minorStatus: 'minor', ambassadorApproved: true };
    expect(unrankableReason({ ...base, parentalAuthStatus: 'pending' })).toBe(
      'parental_authorization_missing',
    );
    expect(unrankableReason({ ...base, parentalAuthStatus: 'refused' })).toBe(
      'parental_authorization_missing',
    );
    expect(unrankableReason({ ...base, parentalAuthStatus: 'verified' })).toBeNull();
  });
});

describe('profil complété (app installée 2.3.0)', () => {
  const complete = {
    accountType: 'student',
    phone: '+227 90000000',
    birthDate: new Date('2004-01-01'),
    guardianConsentedAt: null,
    fieldIds: ['d01'],
    targetCountryIds: ['fr'],
  };
  const now = new Date('2026-11-05');

  it('exige téléphone, naissance, un domaine et un pays visé', () => {
    expect(isProfileComplete(complete, now)).toBe(true);
    for (const missing of [
      { phone: '  ' },
      { birthDate: null },
      { fieldIds: [] },
      { targetCountryIds: [] },
      { accountType: 'parent' },
    ]) {
      expect(isProfileComplete({ ...complete, ...missing }, now)).toBe(false);
    }
  });

  it('n’exige PAS UserProfile.consentedAt : aucune build ne l’envoie (audit 57, F15)', () => {
    // La colonne reste NULL pour tous les comptes réels : l'exiger rendait tout
    // filleul « en attente » à jamais. La case est obligatoire à l'onboarding.
    expect(isProfileComplete({ ...complete, ...{ consentedAt: null } }, now)).toBe(true);
  });

  it('n’exige PAS le pays de résidence (facultatif dans la build 56)', () => {
    expect(isProfileComplete({ ...complete, ...{ countryOfResidence: '' } }, now)).toBe(true);
  });

  it('mineur : exige l’accord du tuteur', () => {
    const minor = { ...complete, birthDate: new Date('2009-06-01') };
    expect(isProfileComplete(minor, now)).toBe(false);
    expect(isProfileComplete({ ...minor, guardianConsentedAt: new Date() }, now)).toBe(true);
  });
});

describe('e-mails jetables (liste versionnée)', () => {
  it('reconnaît domaine et sous-domaine, pas les fournisseurs durables', () => {
    expect(DISPOSABLE_EMAIL_DOMAINS_VERSION).toMatch(/v\d+$/);
    expect(isDisposableEmail('a@yopmail.com')).toBe(true);
    expect(isDisposableEmail('a@mx.mailinator.com')).toBe(true);
    expect(isDisposableEmail('a@gmail.com')).toBe(false);
    expect(isDisposableEmail('a@orange.ne')).toBe(false);
    expect(isDisposableEmail('pas-un-email')).toBe(false);
  });
});

describe('empreintes anti-fraude', () => {
  it('normalise l’IP et calcule la plage', () => {
    expect(normalizeIp('::ffff:41.203.10.7')).toBe('41.203.10.7');
    expect(normalizeIp('nope')).toBeNull();
    expect(ipBlock('41.203.10.7')).toBe('41.203.10.0/24');
    expect(ipBlock('2c0f:f8f0:1:2::5')).toBe('2c0f:f8f0:0001::/48');
  });

  it('hache tout, ne garde rien en clair, et la même IP donne la même empreinte', () => {
    const a = hashAttributionSignals({ ip: '41.203.10.7', pushTokens: ['t1', 't1'], clientDeviceId: null }, 'k');
    const b = hashAttributionSignals({ ip: '41.203.10.8', pushTokens: [], clientDeviceId: 'install-123456' }, 'k');
    expect(a.ipHash).not.toBe(b.ipHash);
    expect(a.ipBlockHash).toBe(b.ipBlockHash);
    expect(a.deviceHashes).toHaveLength(1);
    expect(a.clientDeviceHash).toBeNull();
    expect(b.clientDeviceHash).toMatch(/^[0-9a-f]{32}$/);
    expect(JSON.stringify([a, b])).not.toMatch(/41\.203|t1|install-123456/);
  });
});
