// Miroir manuel du contrat de l'annonce d'ouverture des bourses suivies
// (chantier C) :
//   backend/src/modules/scholarships-index/opening/scholarship-opening.contract.ts
// La référence écrite est `docs/api-contracts.md` ; toute modification de
// contrat passe d'abord côté backend. Les vocabulaires (modes, codes d'erreur,
// états, raisons) sont des tableaux à l'exécution : un test les compare au
// fichier backend (`scholarship-opening-types.test.ts`), pour qu'un code ou un
// état ajouté d'un côté ne soit pas ignoré en silence de l'autre.

export type IsoDateTime = string;

// ── Vocabulaires ────────────────────────────────────────────────────────────

/** `KPB_SCHOLARSHIP_OPENING_MODE` côté serveur. */
export const SCHOLARSHIP_OPENING_MODES = [
  'legacy',
  'outbox_alerts',
  'outbox_followers',
] as const;
export type ScholarshipOpeningMode = (typeof SCHOLARSHIP_OPENING_MODES)[number];

/** `alerts` = abonnés « M'avertir » seulement ; `followers` = favoris ∪ alertes. */
export const OPENING_AUDIENCE_SCOPES = ['alerts', 'followers'] as const;
export type OpeningAudienceScope = (typeof OPENING_AUDIENCE_SCOPES)[number];

export const OPENING_ERROR_CODES = [
  'OPENING_BUSY',
  'OPENING_NOT_RETROACTIVE',
  'OPENING_CONFIRMATION_REQUIRED',
  'OPENING_REQUIRES_ADMIN',
  'OPENING_AUDIENCE_CHANGED',
  'OPENING_NOT_SCHEDULED',
] as const;
export type OpeningErrorCode = (typeof OPENING_ERROR_CODES)[number];

export interface OpeningErrorDetails {
  OPENING_BUSY: undefined;
  OPENING_NOT_RETROACTIVE: undefined;
  OPENING_CONFIRMATION_REQUIRED: { toNotify: number; threshold: number };
  OPENING_REQUIRES_ADMIN: { toNotify: number; threshold: number };
  OPENING_AUDIENCE_CHANGED: { toNotify: number; expectedRecipients: number };
  OPENING_NOT_SCHEDULED: { lastFanoutAt: IsoDateTime | null };
}

/** Corps d'erreur de `GlobalExceptionFilter` pour un code d'annonce. */
export interface OpeningErrorBody<C extends OpeningErrorCode = OpeningErrorCode> {
  statusCode: number;
  message: string;
  requestId?: string;
  code: C;
  details?: OpeningErrorDetails[C];
  timestamp?: IsoDateTime;
}

export const OPENING_NOTIFICATION_STATES = [
  'scheduled',
  'already_scheduled',
  'nothing_to_send',
  'sent_legacy',
  'none',
] as const;
export type OpeningNotificationState = (typeof OPENING_NOTIFICATION_STATES)[number];

export const OPENING_NOTIFICATION_REASONS = [
  'dates_only',
  'already_announced',
  'pre_existing_open',
  'legacy_first_activation_only',
] as const;
export type OpeningNotificationReason = (typeof OPENING_NOTIFICATION_REASONS)[number];

/** Pourquoi un cycle n'est volontairement pas annoncé. */
export const CYCLE_OPENING_SKIP_REASONS = [
  'pre_existing_open',
  'dates_only',
  'not_public_at_fanout',
  'cycle_closed_at_fanout',
] as const;
export type CycleOpeningSkipReason = (typeof CYCLE_OPENING_SKIP_REASONS)[number];

/** Une clé de message `event_*` par action (« Derniers événements »). */
export const OPENING_AUDIT_ACTIONS = [
  'scholarship_cycle.opened',
  'scholarship_cycle.notify_scheduled',
  'scholarship_cycle.notified_legacy',
  'scholarship_cycle.dates_updated',
  'scholarship_cycle.notify_cancelled',
  'scholarship_cycle.notify_stopped',
  'scholarship_cycle.fanout_completed',
  'scholarship_cycle.fanout_expired',
] as const;
export type OpeningAuditAction = (typeof OPENING_AUDIT_ACTIONS)[number];

// ── Formes communes ─────────────────────────────────────────────────────────

export interface LocalizedPushCopy {
  title: string;
  body: string;
}

export interface OpeningAdminRef {
  id: string;
  name: string;
}

export interface ScholarshipReadinessCheck {
  code: string;
  labelFr: string;
  labelEn: string;
  passed: boolean;
}

export interface ScholarshipReadinessReport {
  scholarshipId: string;
  ready: boolean;
  score: number;
  verificationMaxAgeDays: number;
  checks: ScholarshipReadinessCheck[];
  blockingIssues: ScholarshipReadinessCheck[];
}

// ── POST /admin/scholarships/:id/activate ───────────────────────────────────

/**
 * Le corps. `notify` et `expectedRecipients` sont refusés par un backend
 * antérieur au chantier : cet admin se déploie après le backend.
 */
export interface ActivateScholarshipBody {
  academicYear: string;
  opensAt: IsoDateTime;
  closesAt: IsoDateTime;
  estimatedOpenAt?: IsoDateTime;
  estimatedCloseAt?: IsoDateTime;
  dateConfidence?: 'confirmed';
  sourceUrl?: string;
  /** `false` = « Enregistrer les dates sans prévenir ». */
  notify?: boolean;
  /** Le `toNotify` confirmé à l'aperçu ; exigé au-delà du seuil. */
  expectedRecipients?: number;
}

export interface ActivateScholarshipResponse {
  scholarshipId: string;
  cycleId: string;
  status: string;
  firstActivation: boolean;
  subscribers: number;
  pushesSent: number;
  academicYear: string;
  mode: ScholarshipOpeningMode;
  notification: {
    state: OpeningNotificationState;
    toNotify: number;
    fanoutAt: IsoDateTime | null;
    reason: OpeningNotificationReason | null;
  };
}

// ── GET /admin/scholarships/:id/opening-preview ─────────────────────────────

export interface OpeningPreviewQuery {
  academicYear?: string;
  opensAt?: IsoDateTime;
  closesAt?: IsoDateTime;
}

export interface OpeningPreviewCycle {
  id: string;
  academicYear: string;
  /** Statut servi ; `rawStatus` est le littéral en base. */
  status: string;
  rawStatus: string;
  dateConfidence: string;
  opensAt: IsoDateTime | null;
  closesAt: IsoDateTime | null;
  estimatedOpenAt: IsoDateTime | null;
  estimatedCloseAt: IsoDateTime | null;
  activatedAt: IsoDateTime | null;
  openingNotifiedAt: IsoDateTime | null;
  openingNotifiedBy: OpeningAdminRef | null;
  openingAudience: number | null;
  openingFanoutDueAt: IsoDateTime | null;
  openingLastFanoutAt: IsoDateTime | null;
  openingSkippedAt: IsoDateTime | null;
  openingSkippedReason: CycleOpeningSkipReason | null;
  openingStoppedAt: IsoDateTime | null;
  openingPreExisting: boolean;
}

export interface OpeningPreviewTarget {
  academicYear: string;
  cycleId: string | null;
  exists: boolean;
  firstActivation: boolean;
  alreadyAnnounced: boolean;
  preExistingOpen: boolean;
  fanoutScheduledAt: IsoDateTime | null;
  defaultNotify: boolean;
}

/**
 * Toutes les clés décrivent l'ensemble `toNotify`, sauf `followers`, `muted`,
 * `alreadyNotifiedThisCycle` et `recentlyNotified` (les exclusions).
 */
export interface OpeningAudienceSummary {
  followers: number;
  viaFavoriteOnly: number;
  viaAlertOnly: number;
  viaBoth: number;
  muted: number;
  alreadyNotifiedThisCycle: number;
  recentlyNotified: number;
  toNotify: number;
  pushEligible: number;
  optedOut: number;
  pushDisabled: number;
  deferredQuietHours: number;
  deferredPacing: number;
  byLanguage: { fr: number; en: number };
  devices: { fcm: number; oneSignalOnly: number };
}

export interface OpeningPreviewCopy {
  variant: 'opened' | 'dates_confirmed';
  fr: { alert: LocalizedPushCopy; favorite: LocalizedPushCopy };
  en: { alert: LocalizedPushCopy; favorite: LocalizedPushCopy };
  bundleExample: { fr: LocalizedPushCopy; en: LocalizedPushCopy };
}

export interface OpeningRecentEvent {
  action: OpeningAuditAction;
  occurredAt: IsoDateTime;
  actorName: string | null;
  academicYear: string | null;
  toNotify: number | null;
}

export interface OpeningPreviewResponse {
  scholarshipId: string;
  name: { fr: string; en: string };
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  holdSeconds: number;
  confirmThreshold: number;
  canSendAboveThreshold: boolean;
  worker: { enabled: boolean; oldestDuePendingSeconds: number };
  push: { configured: boolean; fcm: boolean; oneSignal: boolean };
  cycles: OpeningPreviewCycle[];
  nextAcademicYear: string;
  target: OpeningPreviewTarget;
  readiness: ScholarshipReadinessReport;
  audience: OpeningAudienceSummary;
  copy: OpeningPreviewCopy;
  recentEvents: OpeningRecentEvent[];
}

// ── Annuler, arrêter, rapport ───────────────────────────────────────────────

export interface CancelOpeningResponse {
  cycleId: string;
  cancelled: true;
}

export interface StopOpeningResponse {
  cycleId: string;
  stopped: number;
  inFlight: number;
}

export interface OpeningReportSkipped {
  total: number;
  optOut: number;
  pushDisabled: number;
  muted: number;
  unfollowed: number;
  notPublic: number;
  cycleClosed: number;
  pushUnconfigured: number;
  stoppedByStaff: number;
}

/** « acceptées par le fournisseur », jamais « reçues » ni « délivrées ». */
export interface OpeningReportResponse {
  scholarshipId: string;
  cycleId: string;
  academicYear: string;
  fanout: {
    scheduledAt: IsoDateTime | null;
    completedAt: IsoDateTime | null;
    lastFanoutAt: IsoDateTime | null;
    stoppedAt: IsoDateTime | null;
    notifiedBy: OpeningAdminRef | null;
    scope: OpeningAudienceScope | null;
  };
  inbox: { total: number; read: number };
  push: {
    /** Lignes ; `acceptedPushes` compte les push (un groupé = 1). */
    accepted: number;
    acceptedPushes: number;
    noDevice: number;
    failed: number;
    expired: number;
    pending: number;
    deferredQuietHours: number;
    deferredPacing: number;
    retrying: number;
    skipped: OpeningReportSkipped;
    untracked: number;
  };
  byProvider: { fcm: number; onesignal: number };
  oldestDuePendingAt: IsoDateTime | null;
  generatedAt: IsoDateTime;
}

// ── « À faire » et colonnes de la liste ─────────────────────────────────────

export interface OpeningTodoItem {
  scholarshipId: string;
  nameFr: string;
  cycleId: string;
  academicYear: string;
  opensAt: IsoDateTime | null;
  closesAt: IsoDateTime | null;
  source: 'catalogue' | 'admin';
  followers: number;
}

export interface OpeningTodoResponse {
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  items: OpeningTodoItem[];
  total: number;
}

export interface OpeningOverviewItem {
  scholarshipId: string;
  followers: number;
  notifiable: number;
  lastAnnounced: {
    cycleId: string;
    academicYear: string;
    at: IsoDateTime;
    audience: number | null;
  } | null;
  scheduledAt: IsoDateTime | null;
}

export interface OpeningOverviewResponse {
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  items: OpeningOverviewItem[];
}
