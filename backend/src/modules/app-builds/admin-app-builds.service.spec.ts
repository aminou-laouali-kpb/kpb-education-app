import { ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { AdminAppBuildsService } from './admin-app-builds.service';

const NOW = new Date('2026-10-13T12:00:00.000Z');
const SINCE = new Date('2026-09-13T12:00:00.000Z');

type BuildGroup = { lastAppBuild: number | null; _count: { _all: number } };
type VersionGroup = {
  lastAppVersion: string | null;
  _count: { _all: number };
};

function makeService(data: {
  allProfiles: number;
  neverSeen: number;
  builds: BuildGroup[];
  versions: VersionGroup[];
}) {
  const count = jest.fn((args?: { where?: unknown }) =>
    Promise.resolve(args?.where ? data.neverSeen : data.allProfiles),
  );
  const groupBy = jest.fn((args: { by: string[] }) =>
    Promise.resolve(
      args.by[0] === 'lastAppBuild' ? data.builds : data.versions,
    ),
  );
  const client = { userProfile: { count, groupBy } };
  const prisma = {
    isEnabled: true,
    execute: jest.fn((operation: (c: typeof client) => Promise<unknown>) =>
      operation(client),
    ),
  } as unknown as PrismaService;
  return { service: new AdminAppBuildsService(prisma), count, groupBy };
}

const build = (lastAppBuild: number | null, n: number): BuildGroup => ({
  lastAppBuild,
  _count: { _all: n },
});
const version = (lastAppVersion: string | null, n: number): VersionGroup => ({
  lastAppVersion,
  _count: { _all: n },
});

describe('AdminAppBuildsService.getAdoption', () => {
  it('compte par build et par version les comptes vus sur 30 jours', async () => {
    const { service, groupBy, count } = makeService({
      allProfiles: 1000,
      neverSeen: 600,
      builds: [build(54, 50), build(null, 100), build(56, 200), build(55, 50)],
      versions: [
        version('2.3.0', 250),
        version(null, 100),
        version('2.10.0', 10),
        version('2.9.1', 40),
      ],
    });

    const result = await service.getAdoption(NOW);

    // La fenêtre et le filtre sont posés côté serveur, depuis une seule horloge.
    for (const call of groupBy.mock.calls) {
      expect(call[0]).toMatchObject({
        where: { lastAppSeenAt: { gte: SINCE } },
        _count: { _all: true },
      });
    }
    expect(count).toHaveBeenCalledWith({ where: { lastAppSeenAt: null } });

    expect(result).toEqual({
      windowDays: 30,
      since: SINCE.toISOString(),
      generatedAt: NOW.toISOString(),
      activeProfiles: 400,
      byBuild: [
        { build: 56, count: 200, share: 0.5, shareAtOrAbove: 0.5 },
        { build: 55, count: 50, share: 0.125, shareAtOrAbove: 0.625 },
        { build: 54, count: 50, share: 0.125, shareAtOrAbove: 0.75 },
      ],
      byVersion: [
        { version: '2.10.0', count: 10, share: 0.025 },
        { version: '2.9.1', count: 40, share: 0.1 },
        { version: '2.3.0', count: 250, share: 0.625 },
      ],
      unknownBuild: { count: 100, share: 0.25 },
      unknownVersion: { count: 100, share: 0.25 },
      neverSeen: { count: 600, share: 0.6 },
      allProfiles: 1000,
    });
  });

  it('les parts par build et la part inconnue somment à 1', async () => {
    const { service } = makeService({
      allProfiles: 7,
      neverSeen: 0,
      builds: [build(56, 1), build(55, 1), build(null, 1)],
      versions: [],
    });

    const result = await service.getAdoption(NOW);
    const total =
      result.byBuild.reduce((sum, row) => sum + row.count, 0) +
      result.unknownBuild.count;
    expect(total).toBe(result.activeProfiles);
    // Arrondi à 4 décimales, pas en pourcentage entier : 1/3 ne devient pas 0.
    expect(result.byBuild[0].share).toBe(0.3333);
    expect(result.byBuild[1].shareAtOrAbove).toBe(0.6667);
  });

  it('ne divise pas par zéro sans aucun compte vu', async () => {
    const { service } = makeService({
      allProfiles: 0,
      neverSeen: 0,
      builds: [],
      versions: [],
    });

    const result = await service.getAdoption(NOW);
    expect(result.activeProfiles).toBe(0);
    expect(result.byBuild).toEqual([]);
    expect(result.byVersion).toEqual([]);
    expect(result.unknownBuild).toEqual({ count: 0, share: 0 });
    expect(result.neverSeen).toEqual({ count: 0, share: 0 });
  });

  it('ne rend que des comptages : aucun identifiant ni date par compte', async () => {
    const { service } = makeService({
      allProfiles: 3,
      neverSeen: 1,
      builds: [build(56, 2)],
      versions: [version('2.3.0', 2)],
    });

    const body = JSON.stringify(await service.getAdoption(NOW));
    expect(body).not.toMatch(/"id"|email|fullName|profileId|lastAppSeenAt/);
  });

  it('répond 503 sans base, plutôt que des zéros qui se liraient comme une mesure', async () => {
    const service = new AdminAppBuildsService({
      isEnabled: false,
      execute: jest.fn(),
    } as unknown as PrismaService);
    await expect(service.getAdoption(NOW)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('répond 503 si la lecture ne rend rien', async () => {
    const service = new AdminAppBuildsService({
      isEnabled: true,
      execute: jest.fn().mockResolvedValue(null),
    } as unknown as PrismaService);
    await expect(service.getAdoption(NOW)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
