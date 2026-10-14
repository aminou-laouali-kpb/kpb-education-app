import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';

import { NOTIFICATION_OPT_OUT_TYPES } from '../../../common/notification-types';
import {
  audienceScopeForMode,
  canSendAboveOpeningThreshold,
  FOLLOWED_SCHOLARSHIP_OPT_OUT,
  isAboveOpeningThreshold,
  isOpeningAudienceChangeRejected,
  isOpeningAudienceScope,
  isOutboxOpeningMode,
  isPushOutboxEnabled,
  notificationKeyForRef,
  OPENING_AUDIT_ACTIONS,
  OPENING_BUNDLE_MAX_REFS,
  OPENING_BUNDLE_ROUTE,
  OPENING_ERROR_CODES,
  OPENING_ERROR_STATUS,
  OPENING_TUNABLE_ENV,
  openingBundlePushData,
  openingDedupeKey,
  openingError,
  openingErrorMessage,
  openingPushData,
  openingRef,
  PUSH_DEFER_REASONS,
  PUSH_FAIL_REASONS,
  PUSH_SKIP_REASON_REPORT_KEY,
  PUSH_SKIP_REASONS,
  readOpeningTunables,
  readScholarshipOpeningMode,
  RETRY_BACKOFF_MS,
  retryDelayMs,
  scholarshipRoute,
  type OpeningErrorBody,
} from './scholarship-opening.contract';

describe('scholarship-opening.contract', () => {
  describe('modes', () => {
    afterEach(() => jest.restoreAllMocks());

    it('legacy par défaut, sans variable ou vide', () => {
      expect(readScholarshipOpeningMode({})).toBe('legacy');
      expect(readScholarshipOpeningMode({ KPB_SCHOLARSHIP_OPENING_MODE: '  ' })).toBe(
        'legacy',
      );
    });

    it.each(['legacy', 'outbox_alerts', 'outbox_followers'] as const)(
      'lit %s (espaces et casse tolérés)',
      (mode) => {
        expect(
          readScholarshipOpeningMode({
            KPB_SCHOLARSHIP_OPENING_MODE: ` ${mode.toUpperCase()} `,
          }),
        ).toBe(mode);
      },
    );

    it('une valeur illisible vaut legacy, avec un seul avertissement par valeur', () => {
      const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
      const env = { KPB_SCHOLARSHIP_OPENING_MODE: 'outbox_folowers' };
      expect(readScholarshipOpeningMode(env)).toBe('legacy');
      expect(readScholarshipOpeningMode(env)).toBe('legacy');
      expect(warn).toHaveBeenCalledTimes(1);
      expect(String(warn.mock.calls[0][0])).toContain('outbox_folowers');
    });

    it('portée : abonnés seulement en outbox_followers', () => {
      expect(audienceScopeForMode('legacy')).toBe('alerts');
      expect(audienceScopeForMode('outbox_alerts')).toBe('alerts');
      expect(audienceScopeForMode('outbox_followers')).toBe('followers');
      expect(isOutboxOpeningMode('legacy')).toBe(false);
      expect(isOutboxOpeningMode('outbox_alerts')).toBe(true);
    });

    it('relit une portée stockée en texte', () => {
      expect(isOpeningAudienceScope('followers')).toBe(true);
      expect(isOpeningAudienceScope('alerts')).toBe(true);
      expect(isOpeningAudienceScope('everyone')).toBe(false);
      expect(isOpeningAudienceScope(null)).toBe(false);
    });

    it('le worker tourne sauf `false` explicite', () => {
      expect(isPushOutboxEnabled({})).toBe(true);
      expect(isPushOutboxEnabled({ KPB_PUSH_OUTBOX_ENABLED: '' })).toBe(true);
      expect(isPushOutboxEnabled({ KPB_PUSH_OUTBOX_ENABLED: 'true' })).toBe(true);
      expect(isPushOutboxEnabled({ KPB_PUSH_OUTBOX_ENABLED: 'false' })).toBe(false);
      expect(isPushOutboxEnabled({ KPB_PUSH_OUTBOX_ENABLED: ' FALSE ' })).toBe(false);
    });
  });

  describe('réglages', () => {
    it('défauts : les règles du propriétaire', () => {
      expect(readOpeningTunables({})).toEqual({
        holdSeconds: 120,
        confirmThreshold: 500,
        coalesceMinutes: 30,
        maxOpeningPushesPerDay: 2,
        renotifyDays: 30,
        outboxTtlHours: 72,
        tickBudgetMs: 60_000,
        concurrency: 8,
        batchSize: 200,
        leaseMs: 300_000,
        maxAttempts: 5,
        fanoutCyclesPerTick: 5,
        fanoutMaxLatenessHours: 24,
      });
    });

    it('une valeur vide vaut défaut (relais docker-compose), une valeur hors bornes est ramenée', () => {
      const tunables = readOpeningTunables({
        KPB_OPENING_HOLD_SECONDS: '',
        KPB_OPENING_CONFIRM_THRESHOLD: 'beaucoup',
        KPB_PUSH_OUTBOX_CONCURRENCY: '500',
        KPB_OPENING_MAX_PER_DAY: '0',
      });
      expect(tunables.holdSeconds).toBe(120);
      expect(tunables.confirmThreshold).toBe(500);
      expect(tunables.concurrency).toBe(OPENING_TUNABLE_ENV.concurrency.max);
      expect(tunables.maxOpeningPushesPerDay).toBe(1);
    });

    it('le bail couvre toujours le budget plus 120 s', () => {
      expect(
        readOpeningTunables({
          KPB_PUSH_OUTBOX_TICK_BUDGET_MS: '200000',
          KPB_PUSH_OUTBOX_LEASE_MS: '60000',
        }).leaseMs,
      ).toBe(320_000);
    });

    it('chaque réglage a son nom de variable, unique', () => {
      const names = Object.values(OPENING_TUNABLE_ENV).map((spec) => spec.name);
      expect(new Set(names).size).toBe(names.length);
      for (const spec of Object.values(OPENING_TUNABLE_ENV)) {
        expect(spec.fallback).toBeGreaterThanOrEqual(spec.min);
        expect(spec.fallback).toBeLessThanOrEqual(spec.max);
      }
    });

    it('nouvelles tentatives à 1 min, 5 min, 20 min puis 1 h', () => {
      expect([0, 1, 2, 3, 4, 9, -1].map(retryDelayMs)).toEqual([
        60_000, 300_000, 1_200_000, 3_600_000, 3_600_000, 3_600_000, 60_000,
      ]);
      expect(RETRY_BACKOFF_MS).toHaveLength(4);
    });
  });

  describe('seuil et rôles', () => {
    it('« au-delà de 500 » : 500 passe, 501 exige la confirmation', () => {
      expect(isAboveOpeningThreshold(500, 500)).toBe(false);
      expect(isAboveOpeningThreshold(501, 500)).toBe(true);
    });

    it('seuls admin et super_admin envoient au-delà du seuil', () => {
      expect(canSendAboveOpeningThreshold('admin')).toBe(true);
      expect(canSendAboveOpeningThreshold('super_admin')).toBe(true);
      expect(canSendAboveOpeningThreshold('content_manager')).toBe(false);
      expect(canSendAboveOpeningThreshold(undefined)).toBe(false);
    });

    it('tolère une baisse et une hausse de max(10, 10 %)', () => {
      expect(isOpeningAudienceChangeRejected(0, 312, 500)).toBe(false);
      expect(isOpeningAudienceChangeRejected(312 + 32, 312, 500)).toBe(false);
      expect(isOpeningAudienceChangeRejected(312 + 33, 312, 500)).toBe(true);
      expect(isOpeningAudienceChangeRejected(15, 5, 500)).toBe(false);
      expect(isOpeningAudienceChangeRejected(16, 5, 500)).toBe(true);
    });

    it('refuse un franchissement du seuil que la confirmation ne couvrait pas', () => {
      expect(isOpeningAudienceChangeRejected(501, 495, 500)).toBe(true);
      // Confirmé au-dessus du seuil : la tolérance seule s'applique.
      expect(isOpeningAudienceChangeRejected(540, 510, 500)).toBe(false);
    });
  });

  describe('clés et charge utile', () => {
    it('garde le format de clé d’avant le chantier', () => {
      expect(openingRef('c1')).toBe('scholarship-opened:c1');
      expect(openingDedupeKey('c1', 'u1')).toBe('scholarship-opened:c1:u1');
      expect(notificationKeyForRef(openingRef('c1'), 'u1')).toBe(
        openingDedupeKey('c1', 'u1'),
      );
      expect(scholarshipRoute('chevening')).toBe('/scholarships/chevening');
    });

    it('annonce seule : la route que les builds ≤ 56 savent ouvrir, et la clé de tap', () => {
      expect(openingPushData({ scholarshipId: 's1', cycleId: 'c1', userId: 'u1' })).toEqual({
        route: '/scholarships/s1',
        scholarshipId: 's1',
        cycleId: 'c1',
        type: 'scholarship_opened',
        kind: 'scholarship_opened',
        notificationKey: 'scholarship-opened:c1:u1',
        ref: 'scholarship-opened:c1',
      });
    });

    it('groupé : /deadlines, sans scholarshipId, 20 références au plus, toutes les lignes comptées', () => {
      const rows = Array.from({ length: 23 }, (_, i) => ({
        scholarshipId: `s${i}`,
        cycleId: `c${i}`,
      }));
      const data = openingBundlePushData(rows);
      expect(data.route).toBe(OPENING_BUNDLE_ROUTE);
      expect(data.route).toBe('/deadlines');
      expect(data.kind).toBe('scholarship_opened_bundle');
      expect(data.type).toBe('scholarship_opened_bundle');
      expect(data.count).toBe('23');
      expect(data.refs.split(',')).toHaveLength(OPENING_BUNDLE_MAX_REFS);
      expect(data.refs.split(',')[0]).toBe('scholarship-opened:c0');
      expect(data.scholarshipIds.split(',')).toHaveLength(20);
      expect(data).not.toHaveProperty('scholarshipId');
      // `Record<string, string>` : ce que les deux fournisseurs acceptent.
      const asData: Record<string, string> = data;
      expect(Object.values(asData).every((v) => typeof v === 'string')).toBe(true);
    });
  });

  describe('erreurs', () => {
    it('statut, code, détails et message complet pour chaque code', () => {
      const cases = [
        openingError('OPENING_BUSY'),
        openingError('OPENING_NOT_RETROACTIVE'),
        openingError('OPENING_CONFIRMATION_REQUIRED', { toNotify: 1_240, threshold: 500 }),
        openingError('OPENING_REQUIRES_ADMIN', { toNotify: 1_240, threshold: 500 }),
        openingError('OPENING_AUDIENCE_CHANGED', { toNotify: 360, expectedRecipients: 312 }),
        openingError('OPENING_NOT_SCHEDULED', { lastFanoutAt: null }),
      ];
      expect(cases.map((error) => (error.getResponse() as OpeningErrorBody).code)).toEqual(
        [...OPENING_ERROR_CODES],
      );
      for (const error of cases) {
        const body = error.getResponse() as OpeningErrorBody;
        expect(error.getStatus()).toBe(OPENING_ERROR_STATUS[body.code]);
        expect(body.message.length).toBeGreaterThan(20);
      }
      expect(cases[0]).toBeInstanceOf(ConflictException);
      expect(cases[2]).toBeInstanceOf(BadRequestException);
      expect(cases[3]).toBeInstanceOf(ForbiddenException);
      expect(cases[0].getResponse()).not.toHaveProperty('details');
      expect(cases[4].getResponse()).toMatchObject({
        details: { toNotify: 360, expectedRecipients: 312 },
      });
    });

    it('messages de l’équipe : les nombres, et jamais « reçu » ni « délivré »', () => {
      expect(
        openingErrorMessage('OPENING_CONFIRMATION_REQUIRED', {
          toNotify: 1_240,
          threshold: 500,
        }),
      ).toBe(
        "Plus de 500 étudiants seraient prévenus. Rechargez la page d'administration pour confirmer l'envoi avec le nombre exact.",
      );
      expect(
        openingErrorMessage('OPENING_REQUIRES_ADMIN', { toNotify: 1_240, threshold: 500 }),
      ).toBe("Au-delà de 500 destinataires, l'envoi est réservé aux administrateurs.");
      for (const code of OPENING_ERROR_CODES) {
        const message = openingErrorMessage(code, {
          toNotify: 1,
          threshold: 1,
          expectedRecipients: 1,
          lastFanoutAt: null,
        } as never);
        expect(message).not.toMatch(/reçu|délivr/i);
      }
    });
  });

  describe('vocabulaire', () => {
    it('la clé de désinscription est une clé connue du profil', () => {
      expect(NOTIFICATION_OPT_OUT_TYPES).toContain(FOLLOWED_SCHOLARSHIP_OPT_OUT);
    });

    it('chaque raison de saut a sa clé de rapport, et les raisons ne se recouvrent pas', () => {
      expect(Object.keys(PUSH_SKIP_REASON_REPORT_KEY).sort()).toEqual(
        [...PUSH_SKIP_REASONS].sort(),
      );
      const all = [...PUSH_SKIP_REASONS, ...PUSH_DEFER_REASONS, ...PUSH_FAIL_REASONS];
      expect(new Set(all).size).toBe(all.length);
      expect(PUSH_SKIP_REASONS).toContain('stopped_by_staff');
      expect(PUSH_DEFER_REASONS).toContain('deferred_busy');
    });

    it('les actions d’audit portent le préfixe du cycle', () => {
      for (const action of OPENING_AUDIT_ACTIONS) {
        expect(action).toMatch(/^scholarship_cycle\.[a-z_]+$/);
      }
      expect(OPENING_AUDIT_ACTIONS).toContain('scholarship_cycle.fanout_expired');
    });
  });
});
