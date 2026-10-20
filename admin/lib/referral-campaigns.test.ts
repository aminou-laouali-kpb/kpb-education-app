import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { AdminCapability, hasAdminCapability, InternalRole } from './admin-capabilities';
import {
  availableActions,
  buildCampaignPayload,
  canForfeit,
  editableFields,
  forfeitBody,
  isOrphanPrize,
  inviteUrl,
  NOVEMBER_2026_DEFAULTS,
  NOVEMBER_2026_RULES_URL,
  parseList,
  parsePrizeAmounts,
  prizeAmountsText,
  publicLeaderboardUrl,
  REFERRAL_FLAGS,
  UNRANKABLE_REASONS,
} from './referral-campaigns';

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');

function lookup(messages: Messages, key: string): unknown {
  return key
    .split('.')
    .reduce<unknown>(
      (current, part) =>
        current && typeof current === 'object' ? (current as Messages)[part] : undefined,
      messages,
    );
}

function leafKeys(value: unknown, prefix = ''): string[] {
  if (value && typeof value === 'object') {
    return Object.entries(value as Messages).flatMap(([key, child]) =>
      leafKeys(child, prefix ? `${prefix}.${key}` : key),
    );
  }
  return [prefix];
}

describe('formulaire de campagne', () => {
  it('le préremplissage est la compétition de novembre 2026 (UTC+1, 3 prix)', () => {
    const built = buildCampaignPayload(NOVEMBER_2026_DEFAULTS);
    expect(built.ok).toBe(true);
    if (!built.ok) return;
    expect(built.body).toMatchObject({
      slug: 'ambassadeurs-novembre-2026',
      startDate: '2026-11-01',
      endDate: '2026-11-10',
      timeZone: 'Africa/Lagos',
      prizes: [
        { rank: 1, amountFcfa: 100000 },
        { rank: 2, amountFcfa: 50000 },
        { rank: 3, amountFcfa: 30000 },
      ],
      eligibleCities: ['Maradi', 'Niamey', 'Cotonou', 'Abidjan', 'Douala'],
      rulesUrl: NOVEMBER_2026_RULES_URL,
    });
  });

  it('le règlement prérempli est la page publiée (audit 57, F20)', () => {
    expect(NOVEMBER_2026_RULES_URL).toBe('https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html');
    // La page existe dans le site statique servi par nginx.
    const page = readFileSync(
      join(__dirname, '..', '..', 'web', 'public', 'reglement-ambassadeurs-2026-11.html'),
      'utf8',
    );
    expect(page).toContain('KPB Global L.L.C-FZ');
    expect(page).toContain('Apple et Google ne sont ni organisateurs ni partenaires');
  });

  it('« Règlement (texte) » dit qu’il est interne et que le bouton utilise le lien (FR/EN)', () => {
    const hint = (messages: Messages) =>
      ((messages.parrainage as Messages).form as Messages).rulesTextHint as string;
    expect(hint(fr)).toContain('non publié');
    expect(hint(fr)).toContain('« Lire le règlement » utilise le lien');
    expect(hint(en)).toContain('not published');
    expect(hint(en)).toContain('uses the link');
  });

  it('signale les erreurs de saisie sans appeler le serveur', () => {
    const built = buildCampaignPayload({
      ...NOVEMBER_2026_DEFAULTS,
      slug: 'Pas Bon',
      endDate: '2026-10-01',
      prizesText: '100000, beaucoup',
      rulesUrl: 'http://x',
    });
    expect(built).toEqual({
      ok: false,
      errors: {
        slug: 'errorSlug',
        endDate: 'errorDateOrder',
        prizesText: 'errorPrizes',
        rulesUrl: 'errorUrl',
      },
    });
  });

  it('lit les montants avec espaces et séparateurs, et les réécrit', () => {
    expect(parsePrizeAmounts('100 000; 50.000\n30000')).toEqual([
      { rank: 1, amountFcfa: 100000 },
      { rank: 2, amountFcfa: 50000 },
      { rank: 3, amountFcfa: 30000 },
    ]);
    expect(parsePrizeAmounts('')).toEqual([]);
    expect(prizeAmountsText([{ rank: 1, amountFcfa: 5 }])).toBe('5');
    expect(parseList('Niamey, Maradi;Niamey, ')).toEqual(['Niamey', 'Maradi']);
  });
});

describe('statuts et actions (miroir du serveur)', () => {
  it('propose les seules transitions possibles', () => {
    expect(availableActions({ status: 'draft', podiumValidatedAt: null })).toEqual(['launch']);
    expect(availableActions({ status: 'live', podiumValidatedAt: null })).toEqual(['freeze']);
    expect(availableActions({ status: 'frozen', podiumValidatedAt: null })).toEqual([
      'unfreeze',
      'validate_podium',
    ]);
    expect(availableActions({ status: 'frozen', podiumValidatedAt: '2026-11-12' })).toEqual([
      'validate_podium',
      'close',
    ]);
    expect(availableActions({ status: 'closed', podiumValidatedAt: '2026-11-12' })).toEqual([]);
  });

  it('fige dates, prix et villes au lancement', () => {
    expect(editableFields('draft')).toContain('prizes');
    expect(editableFields('live')).toEqual(['nameFr', 'nameEn', 'rulesText', 'rulesUrl']);
    expect(editableFields('closed')).toEqual([]);
  });

  it('construit les liens publics', () => {
    expect(publicLeaderboardUrl('ambassadeurs-novembre-2026')).toBe(
      'https://kpbeducation.cloud/classement/?c=ambassadeurs-novembre-2026',
    );
    expect(inviteUrl('KTOU-AK-1a2b3c')).toBe('https://kpbeducation.cloud/invite.html?ref=KTOU-AK-1a2b3c');
  });
});

describe('rôles', () => {
  it('lecture : Admin, SuperAdmin, Commercial ; gestion : Admin, SuperAdmin', () => {
    const view = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ViewReferralCampaigns),
    );
    const manage = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ManageReferralCampaigns),
    );
    expect(view).toEqual([InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin]);
    expect(manage).toEqual([InternalRole.Admin, InternalRole.SuperAdmin]);
  });
});

describe('messages de la compétition', () => {
  it('ont les mêmes clés en français et en anglais', () => {
    expect(leafKeys(fr.parrainage).sort()).toEqual(leafKeys(en.parrainage).sort());
    expect(lookup(fr, 'nav.referralCampaigns')).toBeTypeOf('string');
    expect(lookup(en, 'nav.referralCampaigns')).toBeTypeOf('string');
  });

  it.each([
    ...REFERRAL_FLAGS.map((f) => `parrainage.flag.${f}`),
    ...UNRANKABLE_REASONS.map((r) => `parrainage.unrankable.${r}`),
    ...['draft', 'live', 'frozen', 'closed'].map((s) => `parrainage.status.${s}`),
    ...['launch', 'freeze', 'unfreeze', 'validate_podium', 'close'].flatMap((a) => [
      `parrainage.action.${a}`,
      `parrainage.confirm.${a}`,
    ]),
    ...['errorSlug', 'errorRequired', 'errorDate', 'errorDateOrder', 'errorPrizes', 'errorUrl'].map(
      (k) => `parrainage.form.${k}`,
    ),
  ])('%s existe dans les deux langues', (key) => {
    expect(lookup(fr, key)).toBeTypeOf('string');
    expect(lookup(en, key)).toBeTypeOf('string');
  });

  it('chaque clé littérale référencée par les écrans existe', () => {
    const dir = join(__dirname, '..', 'components', 'referral-campaigns');
    const source = ['campaigns-hub.tsx', 'campaign-detail.tsx']
      .map((file) => readFileSync(join(dir, file), 'utf8'))
      .join('\n');
    const keys = [...source.matchAll(/t\('(parrainage\.[a-zA-Z_.]+)'\)/g)].map((m) => m[1]);
    expect(keys.length).toBeGreaterThan(50);
    for (const key of new Set(keys)) {
      expect(lookup(fr, key), key).toBeTypeOf('string');
      expect(lookup(en, key), key).toBeTypeOf('string');
    }
  });
});

describe('canForfeit (correctifs 57)', () => {
  it('seulement un prix non versé', () => {
    expect(canForfeit({ payoutStatus: 'pending', participantId: 'p1' })).toBe(true);
    expect(canForfeit({ payoutStatus: 'paid', participantId: 'p1' })).toBe(false);
    expect(canForfeit({ payoutStatus: 'paid', participantId: null })).toBe(false);
  });

  it('un prix orphelin (lauréat qui a supprimé son compte) se déclare forfait (audit 57)', () => {
    expect(canForfeit({ payoutStatus: 'pending', participantId: null })).toBe(true);
    expect(isOrphanPrize({ payoutStatus: 'pending', participantId: null })).toBe(true);
    expect(isOrphanPrize({ payoutStatus: 'pending', participantId: 'p1' })).toBe(false);
    expect(isOrphanPrize({ payoutStatus: 'paid', participantId: null })).toBe(false);
  });

  it('la requête omet participantId pour un prix orphelin, le garde sinon', () => {
    expect(forfeitBody({ participantId: null }, '  compte supprimé le 12/11  ')).toEqual({
      reason: 'compte supprimé le 12/11',
    });
    expect('participantId' in forfeitBody({ participantId: null }, 'x')).toBe(false);
    expect(forfeitBody({ participantId: 'p1' }, ' injoignable ')).toEqual({
      participantId: 'p1',
      reason: 'injoignable',
    });
  });

  it('le libellé « Lauréat : compte supprimé » existe dans les deux langues', () => {
    const parrainage = (messages: Messages) => messages.parrainage as Messages;
    expect(parrainage(fr).orphanWinner).toBe('Lauréat : compte supprimé');
    expect(parrainage(en).orphanWinner).toBe('Winner: account deleted');
    expect(parrainage(fr).forfeitOrphanHint).toBeTruthy();
    expect(parrainage(en).forfeitOrphanHint).toBeTruthy();
  });
});
