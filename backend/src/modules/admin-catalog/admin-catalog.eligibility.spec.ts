import { BadRequestException, NotFoundException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import type { AdminSessionUser } from '../auth/auth.service';
import type { PrismaService } from '../prisma/prisma.service';
import { AdminCatalogService } from './admin-catalog.service';
import { ELIGIBILITY_AUDIT_PURPOSE } from './scholarship-eligibility-admin';

/**
 * L'éligibilité structurée passe par `createScholarship` / `updateScholarship`
 * (chantier D4) : lecture stricte, écriture ET audit dans une seule
 * transaction, tampon « Conditions vérifiées » au nom de l'admin connecté. Un
 * corps sans champ d'éligibilité garde l'ancien chemin, sans transaction.
 */

const ACTOR: AdminSessionUser = {
  id: 'admin-7',
  fullName: 'Moussa Éditeur',
  email: 'moussa@kpb.test',
  role: InternalRole.ContentManager,
  languageScope: [],
};

const CRITERION = {
  type: 'age',
  key: 'age-max',
  impact: 'hard',
  max: 29,
  maxInclusive: true,
  asOf: { kind: 'unspecified' },
  officialTextFr: '29 ans au plus.',
  officialTextEn: '29 years old at most.',
  sourceUrl: 'https://example.org/eiffel',
};

interface Existing {
  eligibleLevels: string[];
  fieldsScope: string;
  eligibilityCriteria: unknown;
  eligibilityStructuredAt: Date | null;
  eligibilityStructuredBy: string | null;
}

function makeService(existing: Existing | null = {
  eligibleLevels: ['master'],
  fieldsScope: 'all',
  eligibilityCriteria: [],
  eligibilityStructuredAt: null,
  eligibilityStructuredBy: null,
}) {
  const calls: string[] = [];
  const updates: Array<Record<string, unknown>> = [];
  const creates: Array<Record<string, unknown>> = [];
  const audits: Array<Record<string, unknown>> = [];
  let failAudit = false;
  const tx = {
    scholarship: {
      findUnique: async () => {
        calls.push('tx.scholarship.findUnique');
        return existing;
      },
      update: async ({ data }: { data: Record<string, unknown> }) => {
        calls.push('tx.scholarship.update');
        updates.push(data);
        return { id: 'sch-1', ...data };
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        calls.push('tx.scholarship.create');
        creates.push(data);
        return { id: 'sch-new', ...data };
      },
    },
    adminAuditEvent: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        calls.push('tx.adminAuditEvent.create');
        if (failAudit) throw new Error('audit indisponible');
        audits.push(data);
        return data;
      },
    },
  };
  const client = {
    ...tx,
    scholarship: {
      ...tx.scholarship,
      update: async ({ data }: { data: Record<string, unknown> }) => {
        calls.push('scholarship.update');
        updates.push(data);
        return { id: 'sch-1', ...data };
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        calls.push('scholarship.create');
        creates.push(data);
        return { id: 'sch-new', ...data };
      },
    },
    $transaction: async (fn: (t: typeof tx) => Promise<unknown>) => {
      calls.push('$transaction');
      return fn(tx);
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: typeof client) => unknown) => fn(client),
  } as unknown as PrismaService;
  return {
    service: new AdminCatalogService(prisma),
    calls,
    updates,
    creates,
    audits,
    failAuditNext: () => {
      failAudit = true;
    },
  };
}

describe('AdminCatalogService — éligibilité structurée', () => {
  it('un corps sans champ d’éligibilité garde l’ancien chemin (ni transaction, ni audit)', async () => {
    const { service, calls, audits } = makeService();
    await service.updateScholarship('sch-1', { nameFr: 'Eiffel' }, ACTOR, 'req-1');
    expect(calls).toEqual(['scholarship.update']);
    expect(audits).toHaveLength(0);
  });

  it('écrit niveaux, domaines et critères normalisés, retire le tampon, et audite', async () => {
    const { service, calls, updates, audits } = makeService({
      eligibleLevels: ['master'],
      fieldsScope: 'unknown',
      eligibilityCriteria: [],
      eligibilityStructuredAt: new Date('2026-09-01T00:00:00.000Z'),
      eligibilityStructuredBy: 'KPB',
    });
    await service.updateScholarship(
      'sch-1',
      {
        nameFr: 'Eiffel',
        eligibleLevels: ['master'],
        fieldsScope: 'all',
        eligibilityCriteria: [{ ...CRITERION, extra: 'ignoré' }],
      },
      ACTOR,
      'req-2',
    );
    expect(calls).toEqual([
      '$transaction',
      'tx.scholarship.findUnique',
      'tx.scholarship.update',
      'tx.adminAuditEvent.create',
    ]);
    expect(updates[0]).toMatchObject({
      nameFr: 'Eiffel',
      fieldsScope: 'all',
      eligibilityStructuredAt: null,
      eligibilityStructuredBy: null,
    });
    // Niveaux inchangés : pas réécrits.
    expect(updates[0]).not.toHaveProperty('eligibleLevels');
    expect((updates[0].eligibilityCriteria as Array<Record<string, unknown>>)[0]).not.toHaveProperty(
      'extra',
    );
    expect(audits[0]).toMatchObject({
      actorAdminId: 'admin-7',
      action: 'scholarship.eligibility_updated',
      purposeCode: ELIGIBILITY_AUDIT_PURPOSE,
      entityType: 'Scholarship',
      entityId: 'sch-1',
      requestId: 'req-2',
      result: 'success',
    });
  });

  it('« Conditions vérifiées » tamponne au nom de l’admin connecté', async () => {
    const { service, updates, audits } = makeService();
    const before = Date.now();
    await service.updateScholarship(
      'sch-1',
      { eligibilityCriteria: [CRITERION], markStructured: true },
      ACTOR,
      'req-3',
    );
    const stampedAt = updates[0].eligibilityStructuredAt as Date;
    expect(stampedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(updates[0].eligibilityStructuredBy).toBe('Moussa Éditeur');
    expect(audits[0]).toMatchObject({
      action: 'scholarship.eligibility_structured',
      changes: expect.objectContaining({ stamped: true, criteriaKeys: ['age-max'] }),
    });
  });

  it('une forme invalide est refusée par une 400 AVANT toute écriture', async () => {
    const { service, calls } = makeService();
    await expect(
      service.updateScholarship(
        'sch-1',
        { eligibilityCriteria: [{ ...CRITERION, sourceUrl: '' }] },
        ACTOR,
        'req-4',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(calls).toEqual([]);
  });

  it('une bourse introuvable donne une 404', async () => {
    const { service } = makeService(null);
    await expect(
      service.updateScholarship('nope', { eligibleLevels: ['master'] }, ACTOR, 'req-5'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('l’écriture et l’audit partagent la transaction : un audit en échec fait échouer l’appel', async () => {
    const { service, failAuditNext } = makeService();
    failAuditNext();
    await expect(
      service.updateScholarship('sch-1', { eligibleLevels: ['bachelor'] }, ACTOR, 'req-6'),
    ).rejects.toThrow('audit indisponible');
  });

  it('createScholarship accepte les trois champs et le tampon, dans une transaction auditée', async () => {
    const { service, creates, audits, calls } = makeService();
    await service.createScholarship(
      {
        nameFr: 'Bourse manuelle',
        countryId: 'fra',
        eligibleLevels: ['bachelor'],
        fieldsScope: 'listed',
        eligibilityCriteria: [CRITERION],
        markStructured: true,
      },
      ACTOR,
      'req-7',
    );
    expect(calls).toEqual(['$transaction', 'tx.scholarship.create', 'tx.adminAuditEvent.create']);
    expect(creates[0]).toMatchObject({
      moderationStatus: 'pending',
      eligibleLevels: ['bachelor'],
      fieldsScope: 'listed',
      eligibilityStructuredBy: 'Moussa Éditeur',
    });
    expect(audits[0]).toMatchObject({ entityId: 'sch-new', action: 'scholarship.eligibility_structured' });
  });

  it('createScholarship sans champ d’éligibilité reste inchangé (non analysée)', async () => {
    const { service, creates, calls } = makeService();
    await service.createScholarship({ nameFr: 'Bourse', countryId: 'fra' });
    expect(calls).toEqual(['scholarship.create']);
    expect(creates[0]).not.toHaveProperty('eligibleLevels');
  });

  it('createScholarship refuse un niveau inconnu avant d’écrire', async () => {
    const { service, calls } = makeService();
    await expect(
      service.createScholarship({ nameFr: 'B', countryId: 'fra', eligibleLevels: ['phd'] }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(calls).toEqual([]);
  });
});
