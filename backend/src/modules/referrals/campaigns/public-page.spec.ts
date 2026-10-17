import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { runInNewContext } from 'node:vm';

import type { PrismaService } from '../../prisma/prisma.service';
import { ReferralCampaignService } from './referral-campaign.service';

/**
 * La page publique `kpbeducation.cloud/classement/` (web/public/classement) et
 * la page d'invitation : aucun champ de trop ne peut s'afficher, la CSP du site
 * est respectée (pas de script ni de style inline), et la réponse RÉELLE du
 * service passe par le modèle d'affichage fermé de la page.
 */
const WEB = resolve(__dirname, '../../../../../web');
const read = (p: string) => readFileSync(resolve(WEB, p), 'utf8');

interface PageApi {
  toViewModel: (payload: unknown) => {
    entries: Array<Record<string, unknown>>;
    rulesUrl: string;
    provisional: boolean;
  };
  filterEntries: (entries: unknown[], q: string, city: string) => Array<{ name: string }>;
  formatCountdown: (ms: number) => string;
  countdownTarget: (vm: unknown, now: number) => { label: string; target: number | null };
}

const page = require(resolve(WEB, 'public/classement/classement.js')) as PageApi;

describe('page publique du classement', () => {
  it('respecte la CSP : script et style externes, aucun inline', () => {
    const html = read('public/classement/index.html');
    expect(html).toContain('src="/classement/classement.js"');
    expect(html).toContain('href="/classement/classement.css"');
    expect(html).not.toMatch(/<script>|<script\s+type="text\/javascript">|style=/);
    expect(html).toContain('Classement provisoire');
    expect(html).toContain('<meta name="kpb-api" content="https://api.kpbeducation.cloud/api">');
    const nginx = read('nginx.conf');
    expect(nginx).toMatch(/connect-src 'self' https:\/\/api\.kpbeducation\.cloud/);
    expect(nginx).toMatch(/default-src 'self'/);
  });

  it('n’insère jamais de HTML venant de l’API', () => {
    const js = read('public/classement/classement.js');
    expect(js).not.toMatch(/innerHTML|outerHTML|insertAdjacentHTML|document\.write/);
  });

  it('le modèle d’affichage ne garde que rang, nom public, ville et nombre', () => {
    const vm = page.toViewModel({
      campaign: { nameFr: 'X', rulesUrl: 'javascript:alert(1)', provisional: true },
      entries: [
        {
          rank: 1,
          name: 'Aïcha K.',
          city: 'Niamey',
          qualified: 12,
          email: 'aicha@gmail.com',
          id: 'part_internal',
          ambassadorCode: 'KTOU-AK-1a2b3c',
          referees: [{ email: 'x@y.z' }],
        },
      ],
    });
    expect(Object.keys(vm.entries[0]).sort()).toEqual(['city', 'name', 'qualified', 'rank']);
    expect(JSON.stringify(vm)).not.toMatch(/@|part_internal|KTOU|referees/);
    // Un lien de règlement non https est ignoré.
    expect(vm.rulesUrl).toBe('');
  });

  it('affiche la réponse réelle du service sans fuite', async () => {
    const client = {
      referralCampaign: {
        findUnique: async () => ({
          id: 'camp_internal_id',
          slug: 'ambassadeurs-novembre-2026',
          nameFr: 'Compétition ambassadeurs',
          nameEn: 'Ambassador challenge',
          timeZone: 'Africa/Lagos',
          startsAt: new Date('2026-10-31T23:00:00Z'),
          endsAt: new Date('2026-11-10T23:00:00Z'),
          status: 'live',
          prizes: [{ rank: 1, amountFcfa: 100000 }],
          rulesUrl: null,
          lastComputedAt: null,
        }),
      },
      referralCampaignParticipant: {
        findMany: async () => [
          {
            id: 'part_internal',
            ambassadorId: 'amb_internal',
            publicName: 'Aïcha K.',
            city: 'Niamey',
            status: 'active',
            minorStatus: 'adult',
            parentalAuthStatus: 'not_required',
            parentalAuthNote: 'note privée',
            qualifiedCount: 4,
            flaggedCount: 2,
            rank: 1,
            ambassador: { approvedAt: new Date() },
          },
        ],
      },
    };
    const svc = new ReferralCampaignService({
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService);
    const payload = await svc.publicLeaderboard('ambassadeurs-novembre-2026', undefined);
    const vm = page.toViewModel(JSON.parse(JSON.stringify(payload)));
    expect(vm.entries).toEqual([{ rank: 1, name: 'Aïcha K.', city: 'Niamey', qualified: 4 }]);
    expect(JSON.stringify(vm)).not.toMatch(/internal|note privée|flagged/);
    expect(vm.provisional).toBe(true);
  });

  it('cherche un nom sans accents ni casse, filtre par ville', () => {
    const entries = [
      { rank: 1, name: 'Aïcha K.', city: 'Niamey', qualified: 3 },
      { rank: 2, name: 'Moussa D.', city: 'Maradi', qualified: 2 },
    ];
    expect(page.filterEntries(entries, 'aicha', '').map((e) => e.name)).toEqual(['Aïcha K.']);
    expect(page.filterEntries(entries, '', 'maradi').map((e) => e.name)).toEqual(['Moussa D.']);
  });

  it('compte à rebours : avant, pendant, après', () => {
    const vm = {
      status: 'live',
      startsAt: '2026-10-31T23:00:00.000Z',
      endsAt: '2026-11-10T23:00:00.000Z',
    };
    const before = page.countdownTarget(vm, Date.parse('2026-10-30T23:00:00Z'));
    expect(before.label).toContain('commence');
    expect(page.formatCountdown(before.target! - Date.parse('2026-10-30T23:00:00Z'))).toBe(
      '1 j 00 h 00 min 00 s',
    );
    expect(page.countdownTarget(vm, Date.parse('2026-11-05T00:00:00Z')).label).toContain('Fin');
    expect(page.countdownTarget(vm, Date.parse('2026-11-11T00:00:00Z')).target).toBeNull();
    expect(page.countdownTarget({ ...vm, status: 'closed' }, 0).label).toContain('validés');
  });
});

describe('page d’invitation', () => {
  it('code visible, bouton copier, boutons des boutiques, consigne pour l’app installée', () => {
    const html = read('public/invite.html');
    expect(html).toContain('id="ref-code"');
    expect(html).toContain('id="ref-copy"');
    expect(html).toContain('play.google.com/store/apps/details?id=com.karatou.android');
    expect(html).toContain('apps.apple.com/app/id1128659292');
    expect(html).toMatch(/Parrainage/);
    expect(html).toMatch(/après ton inscription/);
    expect(html).not.toMatch(/<script>|style=/);
  });

  it('nettoie le code, l’affiche et le passe à Google Play (Install Referrer, build 57)', () => {
    const nodes: Record<string, { textContent: string; hidden: boolean; href: string; addEventListener: () => void }> =
      {};
    const node = (id: string) =>
      (nodes[id] ??= { textContent: '', hidden: true, href: '', addEventListener: () => undefined });
    runInNewContext(read('public/invite.js'), {
      window: { location: { search: '?ref=KTOU-AK-1a2b3c%3Cimg%20src%3Dx%3E' } },
      URLSearchParams,
      encodeURIComponent,
      document: { getElementById: node },
      navigator: {},
    });
    // Caractères hors [A-Za-z0-9-] retirés, puis 20 caractères au plus.
    expect(nodes['ref-code'].textContent).toBe('KTOU-AK-1a2b3cimgsrc');
    expect(nodes['ref-card'].hidden).toBe(false);
    expect(nodes.android.href).toBe(
      'https://play.google.com/store/apps/details?id=com.karatou.android&referrer=' +
        encodeURIComponent('utm_source=invite&utm_medium=referral&ref=KTOU-AK-1a2b3cimgsrc'),
    );
  });
});
