import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import type { ApiError } from './api-client';
import {
  activateErrorText,
  activateOutcome,
  activationDraftError,
  announcedCell,
  announcementRequest,
  apiErrorCode,
  audienceLines,
  auditEventMessageKey,
  buildActivateBody,
  buildForecastBody,
  canCancelScheduled,
  cancelConflictMessageKey,
  cycleOptionLabel,
  cycleOptions,
  draftForCycle,
  eventReasonMessageKey,
  EVENT_REASON_CODES,
  fill,
  followersCell,
  followersSubText,
  forecastDraftError,
  formatCountdown,
  formatReportLine,
  isTypedConfirmationValid,
  localFanoutDeadline,
  needsTypedConfirmation,
  openingErrorText,
  phoneCopy,
  phoneTabs,
  previewBanners,
  previewQueryForDraft,
  previewQueryKey,
  previewSummaryText,
  primaryAction,
  recentEventLabel,
  recentEventTitle,
  reportDeferredDetail,
  reportProvidersLine,
  REPORT_POLL_MAX_MS,
  scheduledCardAnnouncement,
  scheduledCardChanged,
  scheduledCardStatus,
  scheduledCycle,
  secondsUntil,
  shouldPollReport,
  showDatesOnlyAction,
  todoRowText,
  type OpeningDraft,
  type Translate,
} from './scholarship-opening';
import type {
  ActivateScholarshipResponse,
  OpeningPreviewCycle,
  OpeningPreviewResponse,
  OpeningReportResponse,
} from './scholarship-opening-types';

// Les libellés sont lus dans les VRAIS fichiers de messages : ces tests
// vérifient aussi la formulation que l'équipe lira (« acceptées par le
// fournisseur », jamais « reçues »).
type Messages = Record<string, unknown>;
function translator(locale: 'fr' | 'en'): Translate {
  const messages = JSON.parse(
    readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'),
  ) as Messages;
  return (key) => {
    const value = key
      .split('.')
      .reduce<unknown>(
        (current, part) =>
          current && typeof current === 'object'
            ? (current as Messages)[part]
            : undefined,
        messages,
      );
    return typeof value === 'string' ? value : key;
  };
}
const t = translator('fr');
const tEn = translator('en');

function cycle(overrides: Partial<OpeningPreviewCycle> = {}): OpeningPreviewCycle {
  return {
    id: 'cyc_2027',
    academicYear: '2027-2028',
    status: 'open',
    rawStatus: 'open',
    dateConfidence: 'confirmed',
    opensAt: '2027-10-01T00:00:00.000Z',
    closesAt: '2027-11-05T23:59:59.999Z',
    estimatedOpenAt: '2027-09-15T00:00:00.000Z',
    estimatedCloseAt: '2027-11-01T23:59:59.999Z',
    activatedAt: null,
    openingNotifiedAt: null,
    openingNotifiedBy: null,
    openingAudience: null,
    openingFanoutDueAt: null,
    openingLastFanoutAt: null,
    openingSkippedAt: null,
    openingSkippedReason: null,
    openingStoppedAt: null,
    openingPreExisting: false,
    ...overrides,
  };
}

function preview(
  overrides: Partial<OpeningPreviewResponse> = {},
): OpeningPreviewResponse {
  const base: OpeningPreviewResponse = {
    scholarshipId: 'chevening',
    name: { fr: 'Bourse Chevening', en: 'Chevening Scholarship' },
    mode: 'outbox_followers',
    scope: 'followers',
    holdSeconds: 120,
    confirmThreshold: 500,
    canSendAboveThreshold: false,
    worker: { enabled: true, oldestDuePendingSeconds: 0 },
    push: { configured: true, fcm: true, oneSignal: true },
    cycles: [cycle()],
    nextAcademicYear: '2028-2029',
    target: {
      academicYear: '2027-2028',
      cycleId: 'cyc_2027',
      exists: true,
      firstActivation: true,
      alreadyAnnounced: false,
      preExistingOpen: false,
      fanoutScheduledAt: null,
      defaultNotify: true,
    },
    readiness: {
      scholarshipId: 'chevening',
      ready: true,
      score: 100,
      verificationMaxAgeDays: 0,
      checks: [],
      blockingIssues: [],
    },
    audience: {
      followers: 334,
      viaFavoriteOnly: 240,
      viaAlertOnly: 50,
      viaBoth: 22,
      muted: 22,
      alreadyNotifiedThisCycle: 0,
      recentlyNotified: 0,
      toNotify: 312,
      pushEligible: 298,
      optedOut: 9,
      pushDisabled: 5,
      deferredQuietHours: 41,
      deferredPacing: 3,
      byLanguage: { fr: 280, en: 32 },
      devices: { fcm: 12, oneSignalOnly: 286 },
    },
    copy: {
      variant: 'opened',
      fr: {
        alert: { title: "C'est ouvert", body: 'Chevening : candidatures…' },
        favorite: { title: 'Une bourse que tu suis est ouverte', body: 'Chevening…' },
      },
      en: {
        alert: { title: 'Applications are open', body: 'Chevening: apply by…' },
        favorite: { title: 'A scholarship you follow is open', body: 'Chevening…' },
      },
      bundleExample: {
        fr: { title: '3 bourses que tu suis sont ouvertes', body: 'Chevening, Eiffel et 1 autre.' },
        en: { title: '3 scholarships you follow are open', body: 'Chevening, Eiffel and 1 more.' },
      },
    },
    recentEvents: [],
  };
  return { ...base, ...overrides };
}

function report(
  push: Partial<OpeningReportResponse['push']> = {},
  fanout: Partial<OpeningReportResponse['fanout']> = {},
): OpeningReportResponse {
  return {
    scholarshipId: 'chevening',
    cycleId: 'cyc_2027',
    academicYear: '2027-2028',
    fanout: {
      scheduledAt: null,
      completedAt: '2027-10-01T10:02:00.000Z',
      lastFanoutAt: '2027-10-01T10:02:00.000Z',
      stoppedAt: null,
      notifiedBy: { id: 'adm_1', name: 'Aminata D.' },
      scope: 'followers',
      ...fanout,
    },
    inbox: { total: 312, read: 37 },
    push: {
      accepted: 280,
      acceptedPushes: 265,
      noDevice: 10,
      failed: 0,
      expired: 0,
      pending: 7,
      deferredQuietHours: 4,
      deferredPacing: 2,
      retrying: 1,
      skipped: {
        total: 15,
        optOut: 9,
        pushDisabled: 5,
        muted: 0,
        unfollowed: 1,
        notPublic: 0,
        cycleClosed: 0,
        pushUnconfigured: 0,
        stoppedByStaff: 0,
      },
      untracked: 0,
      ...push,
    },
    byProvider: { fcm: 12, onesignal: 268 },
    oldestDuePendingAt: null,
    generatedAt: '2027-10-01T10:05:00.000Z',
  };
}

function apiError(status: number, body: unknown, message = 'Refus du serveur'): ApiError {
  const error = new Error(message) as ApiError;
  error.status = status;
  error.body = typeof body === 'string' ? body : JSON.stringify(body);
  return error;
}

const DRAFT: OpeningDraft = {
  academicYear: '2027-2028',
  estimatedOpenAt: '',
  estimatedCloseAt: '',
  opensAt: '2027-10-01',
  closesAt: '2027-11-05',
  sourceUrl: 'https://www.chevening.org/apply',
};

describe('fill', () => {
  it('remplace chaque occurrence et laisse visible une variable oubliée', () => {
    expect(fill('{n} sur {n} · {missing}', { n: 3 })).toBe('3 sur 3 · {missing}');
  });
});

describe('brouillon et corps d’écriture', () => {
  it('préremplit les dates du cycle et garde la source saisie', () => {
    expect(draftForCycle('2027-2028', cycle(), 'https://source')).toEqual({
      academicYear: '2027-2028',
      estimatedOpenAt: '2027-09-15',
      estimatedCloseAt: '2027-11-01',
      opensAt: '2027-10-01',
      closesAt: '2027-11-05',
      sourceUrl: 'https://source',
    });
  });

  it('laisse les dates vides pour un nouveau cycle', () => {
    expect(draftForCycle('2028-2029', undefined, 'https://source')).toEqual({
      academicYear: '2028-2029',
      estimatedOpenAt: '',
      estimatedCloseAt: '',
      opensAt: '',
      closesAt: '',
      sourceUrl: 'https://source',
    });
  });

  it('exige les deux dates confirmées, dans l’ordre', () => {
    expect(activationDraftError({ ...DRAFT, opensAt: '' })).toBe(
      'scholarships.activationValidationError',
    );
    expect(
      activationDraftError({ ...DRAFT, opensAt: '2027-11-06', closesAt: '2027-11-05' }),
    ).toBe('scholarships.activationDateError');
    // Ouvre et ferme le même jour : 00:00 → 23:59:59.999, c'est valide.
    expect(
      activationDraftError({ ...DRAFT, opensAt: '2027-11-05', closesAt: '2027-11-05' }),
    ).toBeNull();
    expect(activationDraftError(DRAFT)).toBeNull();
  });

  it('exige les deux dates estimées pour une prévision', () => {
    expect(forecastDraftError(DRAFT)).toBe('scholarships.forecastValidationError');
    expect(
      forecastDraftError({
        ...DRAFT,
        estimatedOpenAt: '2027-09-15',
        estimatedCloseAt: '2027-09-01',
      }),
    ).toBe('scholarships.activationDateError');
    expect(
      forecastDraftError({
        ...DRAFT,
        estimatedOpenAt: '2027-09-15',
        estimatedCloseAt: '2027-11-01',
      }),
    ).toBeNull();
  });

  it('envoie notify et le nombre confirmé, dates en UTC', () => {
    expect(buildActivateBody(DRAFT, { notify: true, expectedRecipients: 312 })).toEqual({
      academicYear: '2027-2028',
      opensAt: '2027-10-01T00:00:00.000Z',
      closesAt: '2027-11-05T23:59:59.999Z',
      dateConfidence: 'confirmed',
      sourceUrl: 'https://www.chevening.org/apply',
      notify: true,
      expectedRecipients: 312,
    });
  });

  it('garde notify:false explicite et n’invente ni nombre ni source', () => {
    const body = buildActivateBody({ ...DRAFT, sourceUrl: '  ' }, { notify: false });
    expect(body.notify).toBe(false);
    expect('expectedRecipients' in body).toBe(false);
    expect('sourceUrl' in body).toBe(false);
  });

  it('transmet un nombre confirmé de 0 (ouverture sans personne à prévenir)', () => {
    expect(
      buildActivateBody(DRAFT, { notify: true, expectedRecipients: 0 }).expectedRecipients,
    ).toBe(0);
  });

  it('bâtit le corps d’une prévision', () => {
    expect(
      buildForecastBody({
        ...DRAFT,
        estimatedOpenAt: '2027-09-15',
        estimatedCloseAt: '2027-11-01',
      }),
    ).toEqual({
      academicYear: '2027-2028',
      estimatedOpenAt: '2027-09-15T00:00:00.000Z',
      estimatedCloseAt: '2027-11-01T23:59:59.999Z',
      sourceUrl: 'https://www.chevening.org/apply',
    });
  });

  it('n’envoie à l’aperçu que des dates complètes, et sa clé suit le brouillon', () => {
    expect(previewQueryForDraft({ ...DRAFT, closesAt: '2027-11' })).toEqual({
      academicYear: '2027-2028',
      opensAt: '2027-10-01T00:00:00.000Z',
    });
    const key = previewQueryKey(previewQueryForDraft(DRAFT));
    expect(previewQueryKey(previewQueryForDraft({ ...DRAFT, sourceUrl: 'x' }))).toBe(key);
    expect(previewQueryKey(previewQueryForDraft({ ...DRAFT, closesAt: '2027-11-06' }))).not.toBe(
      key,
    );
    expect(
      previewQueryKey(previewQueryForDraft({ ...DRAFT, academicYear: '2028-2029' })),
    ).not.toBe(key);
  });
});

describe('confirmation saisie', () => {
  it('n’est exigée qu’AU-DELÀ du seuil (500 exactement passe)', () => {
    expect(needsTypedConfirmation(500, 500)).toBe(false);
    expect(needsTypedConfirmation(501, 500)).toBe(true);
    expect(needsTypedConfirmation(0, 500)).toBe(false);
  });

  it('accepte le nombre exact, espaces de lecture compris', () => {
    expect(isTypedConfirmationValid('312', 312)).toBe(true);
    expect(isTypedConfirmationValid(' 1 234 ', 1234)).toBe(true);
    expect(isTypedConfirmationValid('1 234', 1234)).toBe(true);
  });

  it('refuse tout autre nombre ou format', () => {
    expect(isTypedConfirmationValid('', 312)).toBe(false);
    expect(isTypedConfirmationValid('313', 312)).toBe(false);
    expect(isTypedConfirmationValid('312.0', 312)).toBe(false);
    expect(isTypedConfirmationValid('1,234', 1234)).toBe(false);
  });
});

describe('erreurs du serveur', () => {
  it('lit le code et les détails dans le corps brut', () => {
    const parsed = apiErrorCode(
      apiError(409, {
        statusCode: 409,
        message: 'Le nombre a changé',
        code: 'OPENING_AUDIENCE_CHANGED',
        details: { toNotify: 340, expectedRecipients: 312 },
      }, 'Le nombre a changé'),
    );
    expect(parsed).toEqual({
      status: 409,
      code: 'OPENING_AUDIENCE_CHANGED',
      details: { toNotify: 340, expectedRecipients: 312 },
      message: 'Le nombre a changé',
    });
  });

  it('ignore un code inconnu et un corps illisible', () => {
    expect(apiErrorCode(apiError(400, { code: 'SCHOLARSHIP_NOT_READY' })).code).toBeNull();
    expect(apiErrorCode(apiError(502, 'Bad Gateway', 'Bad Gateway'))).toEqual({
      status: 502,
      code: null,
      details: {},
      message: 'Bad Gateway',
    });
    expect(apiErrorCode('boom')).toEqual({
      status: null,
      code: null,
      details: {},
      message: '',
    });
  });

  it('409 audience changée : nouveau nombre et aperçu à relire', () => {
    const result = activateErrorText(
      apiError(409, {
        code: 'OPENING_AUDIENCE_CHANGED',
        details: { toNotify: 340, expectedRecipients: 312 },
      }),
      t,
      'secours',
    );
    expect(result).toEqual({
      text: "Le nombre d'abonnés à prévenir a changé (340). Vérifiez avant de confirmer.",
      refreshPreview: true,
    });
  });

  it('409 envoi en préparation : réessayer, sans relire l’aperçu', () => {
    expect(activateErrorText(apiError(409, { code: 'OPENING_BUSY' }), t, 'secours')).toEqual({
      text: 'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.',
      refreshPreview: false,
    });
  });

  it('403 réservé aux administrateurs : le seuil est repris', () => {
    expect(
      activateErrorText(
        apiError(403, {
          code: 'OPENING_REQUIRES_ADMIN',
          details: { toNotify: 812, threshold: 500 },
        }),
        t,
        'secours',
      ).text,
    ).toBe("Au-delà de 500 destinataires, l'envoi est réservé aux administrateurs.");
  });

  it('409 pas d’annonce rétroactive', () => {
    const result = activateErrorText(
      apiError(409, { code: 'OPENING_NOT_RETROACTIVE' }),
      t,
      'secours',
    );
    expect(result.text).toContain('ne peut pas être annoncé après coup');
    expect(result.refreshPreview).toBe(true);
  });

  it('toute autre erreur garde le message du serveur, sinon le libellé de secours', () => {
    expect(activateErrorText(apiError(400, { message: 'x' }, 'Champ invalide'), t, 'secours')).toEqual({
      text: 'Champ invalide',
      refreshPreview: false,
    });
    expect(activateErrorText(new Error(''), t, 'secours').text).toBe('secours');
  });
});

describe('annulation refusée', () => {
  const fanoutAt = '2027-10-01T10:02:00.000Z'; // programmé à 10:00:00, 120 s
  const conflict = (lastFanoutAt: string | null) =>
    apiError(409, { code: 'OPENING_NOT_SCHEDULED', details: { lastFanoutAt } });

  it('« trop tard » seulement si un envoi a eu lieu après la programmation', () => {
    expect(cancelConflictMessageKey(conflict('2027-10-01T10:02:04.000Z'), fanoutAt, 120)).toBe(
      'scholarships.opening.tooLateToCancel',
    );
  });

  it('sinon « aucun envoi programmé » (relance, double annulation)', () => {
    expect(cancelConflictMessageKey(conflict(null), fanoutAt, 120)).toBe(
      'scholarships.opening.notScheduled',
    );
    // Dernier envoi = la première annonce, bien avant cette programmation.
    expect(cancelConflictMessageKey(conflict('2027-09-01T08:00:00.000Z'), fanoutAt, 120)).toBe(
      'scholarships.opening.notScheduled',
    );
  });

  it('409 envoi en préparation : le texte suit la langue de l’admin, pas celle du serveur', () => {
    // Le serveur rédige ce message en français, quelle que soit la langue.
    const busy = apiError(
      409,
      { code: 'OPENING_BUSY' },
      'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.',
    );
    expect(openingErrorText(busy, tEn, 'fallback')).toBe(
      'A send is being prepared for this cycle. Try again in a few seconds.',
    );
    expect(openingErrorText(busy, t, 'secours')).toBe(
      'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.',
    );
  });

  it('sans code d’annonce : le message du serveur, sinon le libellé de secours', () => {
    expect(openingErrorText(apiError(404, { message: 'x' }, 'Introuvable'), t, 'secours')).toBe(
      'Introuvable',
    );
    expect(openingErrorText(new Error(''), t, 'secours')).toBe('secours');
    // OPENING_NOT_SCHEDULED a son propre texte (cancelConflictMessageKey).
    expect(
      openingErrorText(
        apiError(409, { code: 'OPENING_NOT_SCHEDULED', details: { lastFanoutAt: null } }, 'brut'),
        t,
        'secours',
      ),
    ).toBe('brut');
  });
});

describe('compte à rebours', () => {
  const now = Date.parse('2027-10-01T10:00:01.800Z');

  it('arrondit à la seconde supérieure et s’arrête à zéro', () => {
    expect(secondsUntil('2027-10-01T10:02:00.000Z', now)).toBe(119);
    expect(secondsUntil('2027-10-01T09:59:00.000Z', now)).toBe(0);
    expect(secondsUntil('pas une date', now)).toBe(0);
    expect(secondsUntil(now + 5_000, now)).toBe(5);
  });

  it('affiche m:ss', () => {
    expect(formatCountdown(119)).toBe('1:59');
    expect(formatCountdown(7)).toBe('0:07');
    expect(formatCountdown(0)).toBe('0:00');
    expect(formatCountdown(-3)).toBe('0:00');
  });

  it('cale une programmation fraîche sur l’horloge du poste', () => {
    // Poste en avance de 5 minutes : l'heure absolue serait déjà passée.
    const requestStartedAt = Date.parse('2027-10-01T10:05:00.000Z');
    expect(
      localFanoutDeadline({
        state: 'scheduled',
        fanoutAt: '2027-10-01T10:02:00.000Z',
        holdSeconds: 120,
        requestStartedAt,
      }),
    ).toBe(requestStartedAt + 120_000);
  });

  it('garde l’heure du serveur pour une programmation existante', () => {
    expect(
      localFanoutDeadline({
        state: 'already_scheduled',
        fanoutAt: '2027-10-01T10:02:00.000Z',
        holdSeconds: 120,
        requestStartedAt: 0,
      }),
    ).toBe(Date.parse('2027-10-01T10:02:00.000Z'));
  });
});

describe('sélecteur de cycle', () => {
  it('dit qui a annoncé, quand, et à combien', () => {
    expect(
      cycleOptionLabel(
        cycle({
          openingNotifiedAt: '2027-10-07T12:00:00.000Z',
          openingNotifiedBy: { id: 'adm_1', name: 'Aminata D.' },
          openingAudience: 312,
        }),
        t,
      ),
    ).toBe('2027-2028 · ouverte · annoncée le 07/10 par Aminata D. (312)');
  });

  it('distingue programmé, écarté et non annoncé', () => {
    const due = cycle({ openingFanoutDueAt: '2027-10-01T10:02:00.000Z' });
    const date = new Date(due.openingFanoutDueAt as string);
    const time = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
    expect(cycleOptionLabel(due, t)).toBe(`2027-2028 · ouverte · envoi programmé à ${time}`);
    expect(
      cycleOptionLabel(
        cycle({ openingSkippedReason: 'pre_existing_open', openingPreExisting: true }),
        t,
      ),
    ).toBe('2027-2028 · ouverte · ouverte avant la mise en service, sans annonce');
    expect(cycleOptionLabel(cycle({ status: 'forecast' }), t)).toBe(
      '2027-2028 · prévision · non annoncée',
    );
    expect(cycleOptionLabel(cycle({ status: 'archived' }), t)).toBe(
      '2027-2028 · archived · non annoncée',
    );
  });

  it('liste les cycles du plus récent au plus ancien, puis le nouveau cycle', () => {
    const options = cycleOptions(
      preview({
        cycles: [
          cycle({ id: 'a', academicYear: '2026-2027', status: 'closed' }),
          cycle({ id: 'b', academicYear: '2027-2028' }),
        ],
      }),
      t,
    );
    expect(options.map((option) => option.value)).toEqual([
      '2027-2028',
      '2026-2027',
      '2028-2029',
    ]);
    expect(options[2].label).toBe('Nouveau cycle 2028-2029');
  });

  it('ne propose pas « nouveau cycle » pour une année déjà existante', () => {
    const options = cycleOptions(
      preview({ cycles: [cycle({ academicYear: '2028-2029' })], nextAcademicYear: '2028-2029' }),
      t,
    );
    expect(options).toHaveLength(1);
  });

  it('retrouve le cycle programmé', () => {
    const due = cycle({ id: 'due', openingFanoutDueAt: '2027-10-01T10:02:00.000Z' });
    expect(scheduledCycle(preview({ cycles: [cycle(), due] }))?.id).toBe('due');
    expect(scheduledCycle(preview())).toBeUndefined();
    expect(scheduledCycle(null)).toBeUndefined();
  });
});

describe('bouton principal', () => {
  it('« Ouvrir et prévenir » à la première annonce', () => {
    expect(primaryAction(preview(), { canSendAboveThreshold: false }, t)).toEqual({
      label: 'Ouvrir et prévenir les abonnés…',
      kind: 'announce',
      disabledReason: null,
    });
  });

  it('« Prévenir les N nouveaux abonnés » sur un cycle déjà annoncé', () => {
    const base = preview();
    const action = primaryAction(
      preview({
        target: { ...base.target, alreadyAnnounced: true },
        audience: { ...base.audience, toNotify: 14 },
      }),
      { canSendAboveThreshold: false },
      t,
    );
    expect(action.label).toBe('Prévenir les 14 nouveaux abonnés…');
    expect(action.kind).toBe('announce');
  });

  it('« Ouvrir le cycle sans prévenir » quand personne n’est à prévenir', () => {
    const base = preview();
    expect(
      primaryAction(
        preview({ audience: { ...base.audience, toNotify: 0 } }),
        { canSendAboveThreshold: false },
        t,
      ),
    ).toEqual({
      label: 'Ouvrir le cycle sans prévenir (aucun abonné à prévenir)',
      kind: 'open_only',
      disabledReason: null,
    });
    expect(
      primaryAction(preview({ audience: { ...base.audience, toNotify: 0 } }), {
        canSendAboveThreshold: false,
      }, tEn).label,
    ).toBe('Open the cycle without notifying (no followers to notify)');
  });

  it('« Ouvrir le cycle » n’envoie jamais notify:true : aucune annonce sans confirmation', () => {
    // Avec notify:true et expectedRecipients:0, le serveur tolère +10
    // destinataires : des abonnés arrivés depuis l'aperçu seraient prévenus
    // sans que personne ait confirmé quoi que ce soit.
    expect(announcementRequest('open_only', 0)).toEqual({ notify: false });
    expect(announcementRequest('open_only', 12)).toEqual({ notify: false });
    expect(buildActivateBody(DRAFT, announcementRequest('open_only', 0))).not.toHaveProperty(
      'expectedRecipients',
    );
    expect(buildActivateBody(DRAFT, announcementRequest('open_only', 0)).notify).toBe(false);
    expect(announcementRequest('announce', 312)).toEqual({
      notify: true,
      expectedRecipients: 312,
    });
  });

  it('« Ouvrir le cycle sans prévenir » reste possible sur un cycle pré-existant ou au-delà du seuil', () => {
    // notify:false est accepté par le serveur sur un cycle ouvert avant la
    // mise en service ; seule la complétude de la fiche (ou un envoi déjà
    // programmé) le bloque.
    const base = preview();
    const zero = { ...base.audience, toNotify: 0 };
    expect(
      primaryAction(
        preview({ audience: zero, target: { ...base.target, preExistingOpen: true } }),
        { canSendAboveThreshold: false },
        t,
      ).disabledReason,
    ).toBeNull();
    expect(
      primaryAction(
        preview({ audience: zero, readiness: { ...base.readiness, ready: false } }),
        { canSendAboveThreshold: true },
        t,
      ).disabledReason,
    ).toContain("La fiche n'est pas prête");
  });

  it('pas de second bouton identique « Enregistrer les dates sans prévenir »', () => {
    const base = preview();
    const openOnly = primaryAction(
      preview({ audience: { ...base.audience, toNotify: 0 } }),
      { canSendAboveThreshold: false },
      t,
    );
    expect(showDatesOnlyAction(openOnly)).toBe(false);
    // Désactivé (fiche incomplète, envoi programmé) : les dates restent corrigeables.
    expect(showDatesOnlyAction({ ...openOnly, disabledReason: 'x' })).toBe(true);
    expect(showDatesOnlyAction(primaryAction(base, { canSendAboveThreshold: false }, t))).toBe(
      true,
    );
    expect(showDatesOnlyAction(null)).toBe(true);
  });

  it('désactivé, avec la raison, quand la fiche n’est pas prête', () => {
    const base = preview();
    expect(
      primaryAction(
        preview({ readiness: { ...base.readiness, ready: false } }),
        { canSendAboveThreshold: true },
        t,
      ).disabledReason,
    ).toContain("La fiche n'est pas prête");
  });

  it('désactivé sur un cycle ouvert avant la mise en service', () => {
    const base = preview();
    expect(
      primaryAction(
        preview({ target: { ...base.target, preExistingOpen: true } }),
        { canSendAboveThreshold: true },
        t,
      ).disabledReason,
    ).toContain("pas d'annonce rétroactive");
  });

  it('au-delà du seuil, réservé à qui a le droit (500 exactement passe)', () => {
    const base = preview();
    const above = preview({ audience: { ...base.audience, toNotify: 501 } });
    const at = preview({ audience: { ...base.audience, toNotify: 500 } });
    expect(primaryAction(above, { canSendAboveThreshold: false }, t).disabledReason).toBe(
      "Au-delà de 500 destinataires, l'envoi est réservé aux administrateurs.",
    );
    expect(primaryAction(above, { canSendAboveThreshold: true }, t).disabledReason).toBeNull();
    expect(primaryAction(at, { canSendAboveThreshold: false }, t).disabledReason).toBeNull();
  });

  it('désactivé quand un envoi est déjà programmé', () => {
    const base = preview();
    expect(
      primaryAction(
        preview({
          target: { ...base.target, fanoutScheduledAt: '2027-10-01T10:02:00.000Z' },
        }),
        { canSendAboveThreshold: true },
        t,
      ).disabledReason,
    ).toBe('Un envoi est déjà programmé pour ce cycle.');
  });
});

describe('bandeaux de l’aperçu', () => {
  const texts = (value: OpeningPreviewResponse) =>
    previewBanners(value, t).map((banner) => banner.text);

  it('aucun bandeau dans le cas nominal', () => {
    expect(texts(preview())).toEqual([]);
  });

  it('ancien mode : envoi immédiat, alertes seulement', () => {
    const result = texts(preview({ mode: 'legacy', scope: 'alerts' }));
    expect(result[0]).toContain('Ancien mode : envoi immédiat, sans heures calmes');
    expect(result[1]).toContain("Seuls les abonnés « M'avertir » seront prévenus");
  });

  it('envois suspendus et fournisseur absent', () => {
    const result = texts(
      preview({
        worker: { enabled: false, oldestDuePendingSeconds: 0 },
        push: { configured: false, fcm: false, oneSignal: false },
      }),
    );
    expect(result).toEqual([
      'Les envois sont suspendus : les notifications attendront leur reprise.',
      "Aucun fournisseur de push n'est configuré : les notifications resteront visibles dans l'app seulement.",
    ]);
  });

  it('le worker ne compte pas en ancien mode', () => {
    expect(
      texts(preview({ mode: 'legacy', worker: { enabled: false, oldestDuePendingSeconds: 0 } })),
    ).not.toContain('Les envois sont suspendus : les notifications attendront leur reprise.');
  });

  it('pré-existant prime sur « déjà annoncé »', () => {
    const base = preview();
    const result = texts(
      preview({ target: { ...base.target, alreadyAnnounced: true, preExistingOpen: true } }),
    );
    expect(result).toHaveLength(1);
    expect(result[0]).toContain('Ouverte avant la mise en service');
  });

  it('cycle déjà annoncé, dates à venir, personne à prévenir', () => {
    const base = preview();
    expect(
      texts(
        preview({
          target: { ...base.target, alreadyAnnounced: true },
          copy: { ...base.copy, variant: 'dates_confirmed' },
          audience: { ...base.audience, toNotify: 0 },
        }),
      ),
    ).toEqual([
      "Ce cycle a déjà été annoncé : seuls les étudiants qui le suivent depuis l'annonce seront prévenus.",
      "L'ouverture est à venir : le message annonce les dates confirmées, pas une ouverture.",
      "Aucun abonné à prévenir pour ce cycle : l'ouverture n'enverra aucune notification. Si des étudiants suivent la bourse ensuite, vous pourrez les prévenir depuis ce panneau.",
    ]);
  });
});

describe('lignes d’audience', () => {
  it('formule l’exemple du cahier des charges', () => {
    expect(audienceLines(preview().audience, t)).toEqual({
      audience:
        "312 étudiants seront prévenus : 240 favoris, 50 alertes « M'avertir », 22 les deux.",
      exclusions: '334 abonnés au total · 22 en sourdine exclus',
      delivery: "298 push · 14 seulement dans l'app · 41 à 8 h · 3 plus tard (rythme)",
      devices: "12 appareils récents, 286 anciennes versions de l'app",
      languages: '280 en français, 32 en anglais',
    });
  });

  it('liste toutes les exclusions, et aucune quand il n’y en a pas', () => {
    const base = preview().audience;
    expect(
      audienceLines(
        { ...base, muted: 0, alreadyNotifiedThisCycle: 4, recentlyNotified: 2 },
        t,
      ).exclusions,
    ).toBe(
      '334 abonnés au total · 4 déjà prévenus pour ce cycle · 2 prévenus récemment pour un autre cycle',
    );
    expect(
      audienceLines(
        {
          ...base,
          followers: base.toNotify,
          muted: 0,
          alreadyNotifiedThisCycle: 0,
          recentlyNotified: 0,
        },
        t,
      ).exclusions,
    ).toBeNull();
  });

  it('« abonnés à prévenir » dans le résumé du panneau, avec le total s’il diffère', () => {
    const base = preview();
    expect(previewSummaryText(base, t)).toBe(
      '312 abonnés à prévenir pour 2027-2028 (sur 334 abonnés au total).',
    );
    expect(
      previewSummaryText(
        preview({ audience: { ...base.audience, followers: 312 } }),
        tEn,
      ),
    ).toBe('312 followers to notify for 2027-2028.');
  });
});

describe('aperçu sur téléphone', () => {
  it('propose favori seulement en portée « followers »', () => {
    expect(phoneTabs('opened', 'followers')).toEqual(['alert', 'favorite', 'bundle']);
    expect(phoneTabs('opened', 'alerts')).toEqual(['alert', 'bundle']);
    expect(phoneTabs('dates_confirmed', 'followers')).toEqual(['dates', 'bundle']);
  });

  it('montre le texte du serveur, FR et EN', () => {
    const { copy } = preview();
    expect(phoneCopy(copy, 'favorite')).toEqual({ fr: copy.fr.favorite, en: copy.en.favorite });
    expect(phoneCopy(copy, 'bundle')).toEqual(copy.bundleExample);
    expect(phoneCopy(copy, 'dates')).toEqual({ fr: copy.fr.alert, en: copy.en.alert });
  });
});

describe('résultat d’une ouverture', () => {
  function response(
    notification: Partial<ActivateScholarshipResponse['notification']>,
    rest: Partial<ActivateScholarshipResponse> = {},
  ): ActivateScholarshipResponse {
    return {
      scholarshipId: 'chevening',
      cycleId: 'cyc_2027',
      status: 'open',
      firstActivation: true,
      subscribers: 312,
      pushesSent: 0,
      academicYear: '2027-2028',
      mode: 'outbox_followers',
      notification: {
        state: 'scheduled',
        toNotify: 312,
        fanoutAt: '2027-10-01T10:02:00.000Z',
        reason: null,
        ...notification,
      },
      ...rest,
    };
  }

  it('programmé (ou déjà programmé) : la carte de compte à rebours', () => {
    expect(activateOutcome(response({}), t)).toEqual({
      kind: 'scheduled',
      cycleId: 'cyc_2027',
      fanoutAt: '2027-10-01T10:02:00.000Z',
      toNotify: 312,
    });
    expect(activateOutcome(response({ state: 'already_scheduled' }), t).kind).toBe(
      'scheduled',
    );
  });

  it('ancien mode : « acceptées par le fournisseur », jamais « reçues »', () => {
    const outcome = activateOutcome(
      response(
        { state: 'sent_legacy', fanoutAt: null, toNotify: 290 },
        { mode: 'legacy', pushesSent: 280, subscribers: 340 },
      ),
      t,
    );
    // Les destinataires de l'aperçu, pas toutes les alertes actives : les
    // élèves prévenus récemment pour un autre cycle n'ont rien reçu.
    expect(outcome).toEqual({
      kind: 'message',
      text: "Cycle ouvert. 290 abonnés « M'avertir » prévenus, 280 notifications acceptées par le fournisseur (ancien mode).",
    });
  });

  it('dates seules ou personne à prévenir', () => {
    for (const state of ['none', 'nothing_to_send'] as const) {
      expect(activateOutcome(response({ state, fanoutAt: null }), t)).toEqual({
        kind: 'message',
        text: 'Dates enregistrées. Aucune notification envoyée.',
      });
    }
  });
});

describe('rapport d’envoi', () => {
  it('dit « acceptées par le fournisseur », en français comme en anglais', () => {
    expect(formatReportLine(report(), t)).toBe(
      '280 acceptées par le fournisseur · 10 sans appareil · 7 reportées · 0 échecs · 15 non envoyées · 37 lues',
    );
    expect(formatReportLine(report(), tEn)).toBe(
      '280 accepted by the provider · 10 without a device · 7 postponed · 0 failed · 15 not sent · 37 read',
    );
  });

  it('compte les expirées parmi les non envoyées', () => {
    expect(formatReportLine(report({ expired: 3 }), t)).toContain('18 non envoyées');
  });

  it('détaille les reports seulement s’il y en a', () => {
    expect(reportDeferredDetail(report(), t)).toBe(
      'Reportées : 4 jusqu\'à 8 h, 2 plus tard (rythme), 1 en nouvelle tentative.',
    );
    expect(reportDeferredDetail(report({ pending: 0 }), t)).toBeNull();
  });

  it('compte les push groupés pour un', () => {
    expect(reportProvidersLine(report(), t)).toBe(
      '265 push acceptés par le fournisseur (un push groupé compte pour un) · 12 via FCM · 268 via OneSignal',
    );
  });

  it('se relit tant que l’annonce se prépare ou que des push attendent, 10 min au plus', () => {
    const start = 1_000_000;
    expect(shouldPollReport(null, start, start)).toBe(true);
    expect(
      shouldPollReport(report({ pending: 0 }, { scheduledAt: '2027-10-01T10:02:00.000Z' }), start, start),
    ).toBe(true);
    expect(shouldPollReport(report({ pending: 7 }), start, start + 60_000)).toBe(true);
    expect(shouldPollReport(report({ pending: 0 }), start, start)).toBe(false);
    expect(shouldPollReport(report({ pending: 7 }), start, start + REPORT_POLL_MAX_MS)).toBe(
      false,
    );
  });
});

describe('liste, « À faire » et historique', () => {
  const item = {
    scholarshipId: 'chevening',
    followers: 334,
    notifiable: 312,
    lastAnnounced: null,
    scheduledAt: null,
  };

  it('colonne Abonnés à prévenir : « — » avant chargement, 0 pour une bourse absente', () => {
    expect(followersCell(item, false)).toBe('—');
    expect(followersCell(undefined, true)).toBe('0');
    expect(followersCell(item, true)).toBe('312');
    expect(t('scholarships.opening.colFollowers')).toBe('Abonnés à prévenir');
  });

  it('colonne Abonnés à prévenir : le total en second, seulement s’il diffère', () => {
    expect(followersSubText(item, true, t)).toBe('334 au total');
    expect(followersSubText(item, true, tEn)).toBe('334 in total');
    expect(followersSubText({ ...item, followers: 312 }, true, t)).toBeNull();
    expect(followersSubText({ ...item, announcedTarget: null }, true, t)).toBe('334 au total');
    expect(followersSubText(item, false, t)).toBeNull();
    expect(followersSubText(undefined, true, t)).toBeNull();
  });

  describe('colonne Abonnés à prévenir d’une bourse dont le cycle proposé est déjà annoncé', () => {
    const announced = {
      ...item,
      announcedTarget: {
        cycleId: 'cyc_2027',
        academicYear: '2027-2028',
        announcedAt: '2027-10-07T12:00:00.000Z',
        newFollowers: 12,
      },
    };

    it('les nouveaux abonnés depuis l’annonce, pas l’audience de la portée (déjà prévenue)', () => {
      expect(followersCell(announced, true)).toBe('12');
      expect(followersCell(announced, false)).toBe('—');
      expect(followersSubText(announced, true, t)).toBe(
        "nouveaux depuis l'annonce 2027-2028 · 334 au total",
      );
      expect(followersSubText(announced, true, tEn)).toBe(
        'new since the 2027-2028 announcement · 334 in total',
      );
    });

    it('personne de nouveau : 0, jamais l’audience de la portée', () => {
      const none = { ...announced, announcedTarget: { ...announced.announcedTarget, newFollowers: 0 } };
      expect(followersCell(none, true)).toBe('0');
      expect(followersSubText(none, true, t)).toBe(
        "nouveaux depuis l'annonce 2027-2028 · 334 au total",
      );
    });

    it('tous les abonnés sont nouveaux : pas de total redondant', () => {
      const all = {
        ...announced,
        followers: 12,
        notifiable: 12,
      };
      expect(followersSubText(all, true, t)).toBe("nouveaux depuis l'annonce 2027-2028");
      expect(followersSubText(all, true, tEn)).toBe('new since the 2027-2028 announcement');
    });
  });

  it('colonne Annoncé : date (audience), « programmé » ou « — »', () => {
    expect(announcedCell(item, true, t)).toBe('—');
    expect(announcedCell(undefined, true, t)).toBe('—');
    expect(announcedCell(item, false, t)).toBe('—');
    expect(
      announcedCell({ ...item, scheduledAt: '2027-10-01T10:02:00.000Z' }, true, t),
    ).toBe('programmé');
    expect(
      announcedCell(
        {
          ...item,
          lastAnnounced: {
            cycleId: 'cyc_2027',
            academicYear: '2027-2028',
            at: '2027-10-07T12:00:00.000Z',
            audience: 312,
          },
        },
        true,
        t,
      ),
    ).toBe('07/10/2027 (312)');
  });

  const todoItem = {
    scholarshipId: 'chevening',
    nameFr: 'Chevening',
    cycleId: 'cyc_2027',
    academicYear: '2027-2028',
    opensAt: null,
    closesAt: '2027-11-05T23:59:59.999Z',
    source: 'catalogue' as const,
    followers: 334,
  };

  it('ligne « À faire » : le nombre de la colonne, « abonnés à prévenir », et le total', () => {
    expect(todoRowText({ ...todoItem, notifiable: 312 }, t)).toBe(
      'Chevening · 2027-2028 · 312 abonnés à prévenir (334 au total) · ouverte par le catalogue',
    );
    expect(todoRowText({ ...todoItem, followers: 312, notifiable: 312 }, t)).toBe(
      'Chevening · 2027-2028 · 312 abonnés à prévenir · ouverte par le catalogue',
    );
    expect(todoRowText({ ...todoItem, notifiable: 312, source: 'admin' }, tEn)).toBe(
      'Chevening · 2027-2028 · 312 followers to notify (334 in total) · opened from the admin',
    );
  });

  it('ligne « À faire » d’un backend antérieur (sans `notifiable`) : le total, libellé « abonnés »', () => {
    // Le total compte aussi les abonnés en sourdine : le dire « à prévenir »
    // serait faux.
    expect(todoRowText(todoItem, t)).toBe(
      'Chevening · 2027-2028 · 334 abonnés · ouverte par le catalogue',
    );
  });

  it('historique : une clé par action, « système » pour le worker', () => {
    expect(auditEventMessageKey('scholarship_cycle.fanout_expired')).toBe(
      'scholarships.opening.event_fanout_expired',
    );
    const label = recentEventLabel(
      {
        action: 'scholarship_cycle.fanout_completed',
        occurredAt: '2027-10-01T12:00:00.000Z',
        actorName: null,
        academicYear: '2027-2028',
        toNotify: null,
      },
      t,
    );
    expect(label).toMatch(
      /^01\/10\/2027 \d{2}:\d{2} · Notifications écrites dans l'app · système · 2027-2028$/,
    );
  });
});

describe('carte de programmation', () => {
  const pendingReport = report(
    { accepted: 0, acceptedPushes: 0, pending: 0, noDevice: 0 },
    { scheduledAt: '2027-10-01T10:02:00.000Z', completedAt: null, lastFanoutAt: null },
  );

  it('avant l’heure : programmé, annulable', () => {
    const status = scheduledCardStatus({ phase: 'countdown', scheduled: true, report: null });
    expect(status).toBe('scheduled');
    expect(canCancelScheduled(status)).toBe(true);
  });

  it('heure passée sur le poste, envoi pas encore lancé : « En attente d’envoi », toujours annulable', () => {
    for (const current of [null, pendingReport]) {
      const status = scheduledCardStatus({ phase: 'report', scheduled: true, report: current });
      expect(status).toBe('awaiting');
      expect(canCancelScheduled(status)).toBe(true);
    }
    expect(t('scholarships.opening.awaitingTitle')).toBe("En attente d'envoi");
  });

  it('envoi lancé côté serveur : plus d’annulation', () => {
    const status = scheduledCardStatus({ phase: 'report', scheduled: true, report: report() });
    expect(status).toBe('started');
    expect(canCancelScheduled(status)).toBe(false);
  });

  it('annulation refusée « trop tard » : commencé, même sur un rapport encore périmé', () => {
    expect(
      scheduledCardStatus({
        phase: 'report',
        scheduled: true,
        report: pendingReport,
        fanoutStarted: true,
      }),
    ).toBe('started');
  });

  it('annulé, disparu, ou simple rapport : jamais annulable', () => {
    for (const phase of ['cancelled', 'gone'] as const) {
      expect(canCancelScheduled(scheduledCardStatus({ phase, scheduled: true, report: null }))).toBe(
        false,
      );
    }
    const status = scheduledCardStatus({ phase: 'report', scheduled: false, report: pendingReport });
    expect(status).toBe('report');
    expect(canCancelScheduled(status)).toBe(false);
  });

  it('la région aria-live n’annonce que les changements d’état, sans compte à rebours', () => {
    const context = { toNotify: 312, fanoutAt: '2027-10-01T10:02:00.000Z' };
    const scheduled = scheduledCardAnnouncement('scheduled', context, t);
    expect(scheduled).toMatch(/^312 notifications programmées à \d{2}:\d{2}$/);
    // Rien qui ressemble à « 1:58 » : le texte ne change pas d'une seconde à l'autre.
    expect(scheduled).not.toMatch(/\d:\d{2}\)/);
    expect(scheduledCardAnnouncement('awaiting', context, t)).toContain("En attente d'envoi");
    expect(scheduledCardAnnouncement('cancelled', context, t)).toBe(
      "Envoi annulé. Aucun étudiant n'a été prévenu.",
    );
    expect(scheduledCardAnnouncement('started', context, t)).toBe("L'envoi a commencé.");
    expect(scheduledCardAnnouncement('report', context, t)).toBe('');
    expect(scheduledCardAnnouncement('gone', context, t)).toBe('');
  });

  it('les listes sont relues quand le serveur lance l’envoi, pas à zéro sur le poste', () => {
    expect(scheduledCardChanged('scheduled', 'awaiting')).toBe(false);
    expect(scheduledCardChanged('awaiting', 'awaiting')).toBe(false);
    expect(scheduledCardChanged('awaiting', 'started')).toBe(true);
    expect(scheduledCardChanged('scheduled', 'started')).toBe(true);
    expect(scheduledCardChanged('started', 'started')).toBe(false);
    expect(scheduledCardChanged('report', 'report')).toBe(false);
  });
});

describe('derniers événements : ce qui s’est réellement passé', () => {
  const base = {
    action: 'scholarship_cycle.fanout_completed' as const,
    occurredAt: '2027-10-01T12:00:00.000Z',
    actorName: null,
    academicYear: '2027-2028',
    toNotify: 0,
  };

  it('backend antérieur (sans `outcome`) ou `sent` : le libellé de l’action', () => {
    expect(recentEventTitle(base, t)).toBe("Notifications écrites dans l'app");
    expect(recentEventTitle({ ...base, outcome: 'sent', reasonCode: null }, t)).toBe(
      "Notifications écrites dans l'app",
    );
  });

  it('annonce non envoyée : le motif, jamais « notifications écrites »', () => {
    expect(
      recentEventTitle({ ...base, outcome: 'skipped', reasonCode: 'not_public_at_fanout' }, t),
    ).toBe('Annonce non envoyée : bourse plus publique');
    expect(
      recentEventTitle({ ...base, outcome: 'skipped', reasonCode: 'cycle_closed_at_fanout' }, tEn),
    ).toBe('Announcement not sent: cycle closed before sending');
    const label = recentEventLabel(
      { ...base, outcome: 'skipped', reasonCode: 'fanout_too_late' },
      t,
    );
    // Pas de « · 0 » final : rien n'est parti.
    expect(label).toMatch(
      /^01\/10\/2027 \d{2}:\d{2} · Annonce non envoyée : envoi trop en retard · système · 2027-2028$/,
    );
  });

  it('demande refusée : « Ouverture refusée : confirmation requise », avec le nombre refusé', () => {
    const refused = {
      ...base,
      action: 'scholarship_cycle.opened' as const,
      actorName: 'Aminata D.',
      toNotify: 612,
      outcome: 'refused' as const,
      reasonCode: 'OPENING_CONFIRMATION_REQUIRED',
    };
    expect(recentEventTitle(refused, t)).toBe('Ouverture refusée : confirmation requise');
    expect(recentEventLabel(refused, t)).toMatch(
      / · Ouverture refusée : confirmation requise · Aminata D\. · 2027-2028 · 612$/,
    );
    expect(
      recentEventTitle({ ...refused, reasonCode: 'OPENING_REQUIRES_ADMIN' }, tEn),
    ).toBe('Opening refused: restricted to administrators above the threshold');
    expect(
      recentEventTitle(
        { ...refused, action: 'scholarship_cycle.notify_cancelled', reasonCode: 'OPENING_BUSY' },
        t,
      ),
    ).toBe('Annulation refusée : envoi en cours de préparation');
  });

  it('motif inconnu de cet admin : affiché tel quel ; motif absent : le constat seul', () => {
    expect(
      recentEventTitle({ ...base, outcome: 'skipped', reasonCode: 'quota_exceeded' }, t),
    ).toBe('Annonce non envoyée : motif quota_exceeded');
    expect(recentEventTitle({ ...base, outcome: 'refused' }, t)).toBe('Ouverture refusée');
  });

  it('issue ou action inconnues (backend plus récent) : jamais une clé brute', () => {
    const unknownOutcome = { ...base, outcome: 'partial' } as unknown as Parameters<
      typeof recentEventTitle
    >[0];
    expect(recentEventTitle(unknownOutcome, t)).toBe("Notifications écrites dans l'app");
    const unknownAction = {
      ...base,
      action: 'scholarship_cycle.something_new',
    } as unknown as Parameters<typeof recentEventTitle>[0];
    expect(recentEventTitle(unknownAction, t)).toBe("Événement d'annonce");
  });

  it('chaque motif connu a un libellé dans les deux langues', () => {
    for (const code of EVENT_REASON_CODES) {
      const key = eventReasonMessageKey(code);
      expect(key).not.toBeNull();
      expect({ code, fr: t(key ?? '') }).not.toEqual({ code, fr: key });
      expect({ code, en: tEn(key ?? '') }).not.toEqual({ code, en: key });
    }
    expect(eventReasonMessageKey('quota_exceeded')).toBeNull();
  });
});
