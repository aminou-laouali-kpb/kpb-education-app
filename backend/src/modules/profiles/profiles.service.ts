import { createHash, createHmac } from 'node:crypto';

import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { UserProfile } from '@prisma/client';

import { NewsletterSyncService } from '../newsletter/newsletter-sync.service';
import {
  NotificationOptOutType,
  sanitizeOptOutTypes,
  withOptOut,
} from '../../common/notification-types';
import { PrismaService } from '../prisma/prisma.service';
import {
  AntivirusUnavailableError,
  InfectedFileError,
} from '../storage/antivirus.service';
import {
  type StoredObject,
  StorageService,
  StorageWriteError,
} from '../storage/storage.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import {
  avatarInfected,
  avatarNotFound,
  avatarProfileNotFound,
  avatarScannerUnavailable,
  avatarStorageUnavailable,
  avatarUploadConflict,
  ProfileAvatarHttpException,
} from './profile-avatar.errors';
import {
  assertAvatarContent,
  assertAvatarScannerReady,
  AVATAR_ENDPOINT_PATH,
  AVATAR_STORAGE_LABEL,
} from './profile-avatar.policy';
import { isAtLeastAge, MINIMUM_ACCOUNT_AGE } from './profile-age.policy';
import { isProfileComplete } from '../referrals/campaigns/profile-completion';
import { parseLanguageTests } from '../scholarship-match/match-inputs';
import {
  refreshPostCounters,
  refreshReplyCounters,
} from '../community/community-counters';

/** The multipart file as produced by multer's memory storage. */
export interface UploadedAvatarFile {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
  size: number;
}

export interface AvatarStream {
  /** Stable per-stored-object validator; changes when the avatar changes. */
  etag: string;
  /** Null when the caller's If-None-Match already matches (304, zero bytes). */
  object: StoredObject | null;
}

/**
 * Les avis conseiller qui sont « à » cet utilisateur : ceux qu'il a signés, ET
 * ceux qu'aucun auteur ne rattache mais qui portent l'un de SES dossiers.
 *
 * Le second critère existe à cause de l'historique. Tant que l'auteur venait du
 * corps de la requête, l'app ne l'envoyait pas : les avis déjà enregistrés ont
 * `reviewerUserId = NULL`, et la seule trace de leur auteur est le dossier noté —
 * que la suppression du compte emporte. Sans ce critère, le nom civil et le
 * texte survivent à l'effacement (RGPD, droit à l'effacement) ; sans lui non
 * plus, l'export ne les rendrait pas à leur auteur.
 *
 * La migration de reprise n'en rattache qu'une partie : elle exige que le
 * conseiller du dossier soit celui qui est noté, parce qu'un rattachement rend
 * l'avis éligible à la publication au titre du consentement de CE propriétaire.
 * Effacer et exporter n'ont pas cette contrainte : « trop » est la bonne
 * direction d'erreur pour une suppression, et un avis qui porte le dossier de
 * quelqu'un lui appartient assez pour lui être rendu.
 */
/**
 * Ce qui reste d'un compte supprimé dans les lignes qu'on garde pour leurs
 * compteurs (livraisons de campagnes) ou leur comptabilité (prix de la
 * compétition) : une étiquette neutre, jamais un nom ni un identifiant.
 */
export const DELETED_ACCOUNT_LABEL = 'Compte supprimé';
/** `NotificationDelivery.recipientId` (NOT NULL) d'un compte supprimé. */
export const DELETED_RECIPIENT_ID = 'compte-supprime';
/** Motif d'un forfait dont le lauréat a supprimé son compte (`reason` NOT NULL). */
export const ERASED_FORFEIT_REASON = 'Motif effacé (compte supprimé)';
/** `AdminAuditEvent.changes` des actions de compétition visant un compte supprimé. */
export const ERASED_AUDIT_CHANGES = { erased: 'account_deleted' } as const;

function reviewsOfUser(userId: string, caseIds: string[]) {
  return {
    OR: [
      { reviewerUserId: userId },
      { reviewerUserId: null, caseId: { in: caseIds } },
    ],
  };
}

/** `voucherCode` d'une dépense de crédits (`metadata`), seule clé exportée. */
function voucherCodeOf(metadata: unknown): string | null {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) return null;
  const code = (metadata as Record<string, unknown>).voucherCode;
  return typeof code === 'string' && code ? code : null;
}

/** « •••• 4567 » : les 4 derniers caractères d'un numéro de versement. */
function maskAccount(account: string): string {
  const trimmed = account.trim();
  if (!trimmed) return '';
  return trimmed.length <= 4 ? '••••' : `•••• ${trimmed.slice(-4)}`;
}

@Injectable()
export class ProfilesService {
  private readonly logger = new Logger(ProfilesService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly storageService: StorageService,
    // Optional so unit tests constructing the service positionally keep
    // working; when absent, the reconciliation cron alone syncs Mautic.
    @Optional() private readonly newsletterSync?: NewsletterSyncService,
  ) {}

  // Returned ONLY when the database is not configured. Kept readonly and never
  // mutated — a previous mutable singleton leaked one user's profile fields
  // into another user's responses (cross-tenant leak + race condition).
  private readonly demoProfile = {
    id: 'demo-user',
    accountType: 'student',
    preferredLanguage: 'fr',
    fullName: 'Aissatou Ibrahim',
    email: 'aissatou@example.com',
    phone: '+22790000000',
    whatsApp: '+22790000000',
    countryOfResidence: 'Niger',
    currentLevel: 'High school',
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    fieldIds: ['computer_science', 'business'],
    // Active ISO country ids (see seed:countries-m5) — matches the catalog after
    // the canada->can / france->fra remap so coach targeting + UI resolve them.
    targetCountryIds: ['can', 'fra'],
    gradeRange: '12 - 14/20',
    annualTuitionBudgetEur: 7500,
    preferredCurrency: 'XOF',
    wantsScholarshipSupport: true,
    availableDocuments: ['Passport', 'Transcripts'],
    hasAvatar: false,
    avatarUrl: null as string | null,
    updatedAt: new Date().toISOString(),
  };

  async getMe(userId?: string) {
    const id = userId ?? 'demo-user';
    const dbProfile = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id } }),
    );

    return dbProfile ? this.mapDbProfile(dbProfile) : this.demoProfile;
  }

  /**
   * The `disabledNotificationTypes` value to write, or null when this PATCH
   * touches no notification preference (so the column is left alone).
   *
   * An explicit array wins outright. Otherwise the legacy per-type booleans are
   * applied ON TOP of the stored list — a client that only knows about one type
   * must never blank the student's other preferences.
   */
  private async resolveOptOutTypes(
    id: string,
    input: UpdateProfileDto,
  ): Promise<NotificationOptOutType[] | null> {
    if (input.disabledNotificationTypes !== undefined) {
      return sanitizeOptOutTypes(input.disabledNotificationTypes);
    }
    if (
      input.dailyScholarshipOptOut === undefined &&
      input.weeklyDigestOptOut === undefined
    ) {
      return null;
    }

    const current = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { id },
        select: { disabledNotificationTypes: true },
      }),
    );
    let types: readonly string[] = current?.disabledNotificationTypes ?? [];
    if (input.dailyScholarshipOptOut !== undefined) {
      types = withOptOut(
        types,
        'daily_scholarship',
        input.dailyScholarshipOptOut,
      );
    }
    if (input.weeklyDigestOptOut !== undefined) {
      types = withOptOut(types, 'weekly_digest', input.weeklyDigestOptOut);
    }
    return sanitizeOptOutTypes([...types]);
  }

  async updateMe(input: UpdateProfileDto, userId?: string) {
    const id = userId ?? 'demo-user';

    // Do not rely on the mobile onboarding form for the contractual 16+ floor.
    // The DTO catches HTTP calls and this duplicate service-boundary check also
    // covers internal/direct callers that bypass Nest's ValidationPipe.
    if (
      input.birthDate !== undefined &&
      !isAtLeastAge(input.birthDate, MINIMUM_ACCOUNT_AGE)
    ) {
      throw new BadRequestException({
        code: 'minimum_age_not_met',
        message: `You must be at least ${MINIMUM_ACCOUNT_AGE} years old to create an account.`,
      });
    }

    // Newsletter consent transition: stamp the GDPR proof only when the flag
    // actually flips to true — re-sending true must not rewrite the original
    // consent timestamp.
    let stampNewsletterConsent = false;
    if (input.scholarshipNewsletterOptIn === true) {
      const current = await this.prismaService.execute((prisma) =>
        prisma.userProfile.findUnique({
          where: { id },
          select: { newsletterOptIn: true },
        }),
      );
      stampNewsletterConsent = current ? !current.newsletterOptIn : false;
    }

    // Même règle pour les nouvelles et offres de KPB (XC-06) : la preuve
    // horodatée n'est posée qu'au vrai passage à `true`.
    let stampPromotionsConsent = false;
    if (input.promotionsEmailOptIn === true) {
      const current = await this.prismaService.execute((prisma) =>
        prisma.userProfile.findUnique({
          where: { id },
          select: { promotionsEmailOptIn: true },
        }),
      );
      stampPromotionsConsent = current ? !current.promotionsEmailOptIn : false;
    }

    // Push promotionnel (chantier juridique 57, App Store 4.5.4) : même règle,
    // preuve horodatée posée au seul vrai passage à `true`.
    let stampPromotionsPushConsent = false;
    if (input.promotionsPushOptIn === true) {
      const current = await this.prismaService.execute((prisma) =>
        prisma.userProfile.findUnique({
          where: { id },
          select: { promotionsPushOptIn: true },
        }),
      );
      stampPromotionsPushConsent = current ? !current.promotionsPushOptIn : false;
    }

    // KPB-169: per-type notification opt-outs live in one array column. A
    // client may send the array directly, or the legacy per-type booleans —
    // which are folded into the array so the already-built app keeps working.
    const optOutTypes = await this.resolveOptOutTypes(id, input);

    const updated = await this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id },
        data: {
          ...(input.fullName ? { fullName: input.fullName } : {}),
          ...(input.phone ? { phone: input.phone } : {}),
          // Même règle que `phone` : une valeur vide ne remplace pas le numéro
          // (les anciennes builds envoyaient '' après un redémarrage à froid).
          ...(input.whatsApp ? { whatsApp: input.whatsApp } : {}),
          ...(input.preferredLanguage
            ? { preferredLanguage: input.preferredLanguage }
            : {}),
          ...(input.countryOfResidence
            ? { countryOfResidence: input.countryOfResidence }
            : {}),
          ...(input.currentLevel
            ? { currentLevel: input.currentLevel }
            : {}),
          ...(input.targetLevel ? { targetLevel: input.targetLevel } : {}),
          ...(input.languageLevel
            ? { languageLevel: input.languageLevel }
            : {}),
          ...(input.gradeRange ? { gradeRange: input.gradeRange } : {}),
          // `undefined` (champ absent) ≠ `null` (effacement demandé). Le test
          // de vérité qui précédait — `input.bacSeries ? …` — confondait les
          // deux, donc aucune requête ne pouvait remettre la colonne à NULL :
          // un étudiant passé de Terminale à Master gardait indéfiniment une
          // série de bac obsolète, qui continuait de satisfaire l'item
          // « moyenne » de son score de complétion.
          ...(input.bacSeries !== undefined
            ? { bacSeries: input.bacSeries || null }
            : {}),
          ...(input.monthlyBudgetEur !== undefined
            ? { monthlyBudgetEur: input.monthlyBudgetEur }
            : {}),
          ...(input.annualTuitionBudgetEur !== undefined
            ? { annualTuitionBudgetEur: input.annualTuitionBudgetEur }
            : {}),
          ...(input.preferredCurrency
            ? { preferredCurrency: input.preferredCurrency }
            : {}),
          ...(input.wantsScholarshipSupport !== undefined
            ? { wantsScholarship: input.wantsScholarshipSupport }
            : {}),
          ...(input.scholarshipNewsletterOptIn !== undefined
            ? { newsletterOptIn: input.scholarshipNewsletterOptIn }
            : {}),
          ...(optOutTypes ? { disabledNotificationTypes: optOutTypes } : {}),
          ...(stampNewsletterConsent
            ? { newsletterConsentedAt: new Date() }
            : {}),
          ...(input.promotionsEmailOptIn !== undefined
            ? { promotionsEmailOptIn: input.promotionsEmailOptIn }
            : {}),
          ...(stampPromotionsConsent
            ? { promotionsEmailConsentedAt: new Date() }
            : {}),
          ...(input.promotionsPushOptIn !== undefined
            ? { promotionsPushOptIn: input.promotionsPushOptIn }
            : {}),
          ...(stampPromotionsPushConsent
            ? { promotionsPushConsentedAt: new Date() }
            : {}),
          ...(input.fieldIds ? { fieldIds: input.fieldIds } : {}),
          ...(input.targetCountryIds
            ? { targetCountryIds: input.targetCountryIds }
            : {}),
          ...(input.availableDocuments
            ? { availableDocuments: input.availableDocuments }
            : {}),
          ...(input.aiConsentedAt !== undefined
            ? { aiConsentedAt: new Date(input.aiConsentedAt) }
            : {}),
          ...(input.birthDate !== undefined
            ? { birthDate: new Date(input.birthDate) }
            : {}),
          ...(input.guardianName !== undefined
            ? { guardianName: input.guardianName }
            : {}),
          ...(input.guardianContact !== undefined
            ? { guardianContact: input.guardianContact }
            : {}),
          ...(input.guardianConsentedAt !== undefined
            ? { guardianConsentedAt: new Date(input.guardianConsentedAt) }
            : {}),
        },
      }),
    );

    if (updated) {
      // Compétition ambassadeurs : l'instant où le profil devient complet date
      // la qualification d'un filleul. Posé une seule fois, au mieux.
      if (!updated.profileCompletedAt && isProfileComplete(updated, new Date())) {
        await this.prismaService.tryExecute((prisma) =>
          prisma.userProfile.updateMany({
            where: { id: updated.id, profileCompletedAt: null },
            data: { profileCompletedAt: new Date() },
          }),
        );
      }
      // Fire-and-forget: low-latency Mautic push. A failure here is fine —
      // the state stays desired≠synced and the reconciliation cron retries.
      if (input.scholarshipNewsletterOptIn !== undefined) {
        // `.catch` : syncProfile peut rejeter (erreur DB transitoire) et un
        // rejet non géré arrêterait le process.
        void this.newsletterSync?.syncProfile(updated.id).catch(() => false);
      }
      return this.mapDbProfile(updated);
    }

    // No database: return a per-request merge of the demo profile without
    // mutating any shared state.
    return {
      ...this.demoProfile,
      ...input,
      updatedAt: new Date().toISOString(),
    };
  }

  // ── Profile photo ──────────────────────────────────────────────────────────
  // The image is stored as a private object and referenced by its storage KEY.
  // No public URL exists anywhere: the bytes only ever leave through
  // `streamAvatar`, behind StudentAuthGuard, for the owner of the row.

  /**
   * Replaces the caller's avatar. Order of operations is what keeps the bucket
   * clean: validate → scan+store the new object → claim the row conditionally →
   * only then delete the previous object. A failure at any earlier step leaves
   * either nothing new stored, or a brand-new object that we delete ourselves.
   */
  async uploadAvatar(file: UploadedAvatarFile, userId?: string) {
    const id = userId ?? 'demo-user';

    // Cheap, honest rejections first — never scan or store what we will refuse.
    const mimeType = assertAvatarContent(file.buffer);
    assertAvatarScannerReady();

    const before = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { id },
        select: { avatarStorageKey: true },
      }),
    );
    if (!before) throw avatarProfileNotFound();

    let stored;
    try {
      stored = await this.storageService.save(
        file.buffer,
        AVATAR_STORAGE_LABEL,
        mimeType,
      );
    } catch (error) {
      throw this.translateAvatarStorageError(error);
    }

    try {
      const updated = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          // Conditional claim: if a concurrent upload changed the key while we
          // were scanning, we lose and discard our object instead of orphaning
          // the winner's — the row and the bucket never disagree.
          const claimed = await tx.userProfile.updateMany({
            where: { id, avatarStorageKey: before.avatarStorageKey },
            data: { avatarStorageKey: stored.key },
          });
          if (claimed.count === 0) throw avatarUploadConflict();
          return tx.userProfile.findUnique({ where: { id } });
        }),
      );
      if (!updated) throw avatarProfileNotFound();

      // Committed: the old object is now unreferenced. Deleting it after the
      // commit (never before) means a failed commit cannot destroy the avatar
      // the student still has. `delete` swallows its own errors.
      if (
        before.avatarStorageKey &&
        before.avatarStorageKey !== stored.key
      ) {
        await this.storageService.delete(before.avatarStorageKey);
      }
      return this.mapDbProfile(updated);
    } catch (error) {
      // Nothing references the new object — remove it rather than leak it.
      await this.storageService.delete(stored.key);
      throw error instanceof ProfileAvatarHttpException
        ? error
        : this.translateAvatarStorageError(error);
    }
  }

  /**
   * Streams the caller's own avatar. `ifNoneMatch` lets a client revalidate for
   * a few hundred bytes instead of re-downloading the image — the audience pays
   * for its data by the megabyte.
   */
  async streamAvatar(
    userId?: string,
    ifNoneMatch?: string,
  ): Promise<AvatarStream> {
    const id = userId ?? 'demo-user';
    const profile = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { id },
        select: { avatarStorageKey: true },
      }),
    );
    if (!profile) throw avatarProfileNotFound();
    if (!profile.avatarStorageKey) throw avatarNotFound();

    const etag = this.avatarEtag(profile.avatarStorageKey);
    if (ifNoneMatch && this.etagMatches(ifNoneMatch, etag)) {
      return { etag, object: null };
    }

    let object: StoredObject | null;
    try {
      object = await this.storageService.getObject(profile.avatarStorageKey);
    } catch (error) {
      throw this.translateAvatarStorageError(error);
    }
    // The row points at an object the store does not have. That is a 404 for
    // this user, not a 500 and certainly not "check your connection".
    if (!object) throw avatarNotFound();
    return { etag, object };
  }

  /** Clears the key, then removes the object (best-effort, never throws). */
  async deleteAvatar(userId?: string) {
    const id = userId ?? 'demo-user';
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const before = await tx.userProfile.findUnique({
          where: { id },
          select: { avatarStorageKey: true },
        });
        if (!before) return null;
        const updated = await tx.userProfile.update({
          where: { id },
          data: { avatarStorageKey: null },
        });
        return { previousKey: before.avatarStorageKey, profile: updated };
      }),
    );
    if (!result) throw avatarProfileNotFound();

    if (result.previousKey) {
      await this.storageService.delete(result.previousKey);
    }
    return this.mapDbProfile(result.profile);
  }

  /**
   * « Effacer ma nationalité » (correctifs 57) : retire le consentement
   * explicite donné au test « Mes 10 bourses ».
   *
   * Efface la nationalité ET la seconde nationalité du profil, et supprime les
   * runs du test — ils ont été calculés avec elle et ses raisons (« réservée
   * aux ressortissants de… ») la laissent deviner. Une seule transaction : on
   * ne garde jamais des résultats qui dépendent d'une donnée retirée. Le
   * prochain test redemandera la nationalité et la case de consentement.
   *
   * Pas derrière le drapeau `scholarshipMatch` : un test refermé ne doit pas
   * empêcher d'effacer ce qu'il a collecté. Idempotent.
   */
  async eraseNationality(userId?: string) {
    const id = userId ?? 'demo-user';
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const exists = await tx.userProfile.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!exists) return null;
        const runs = await tx.scholarshipMatchRun.deleteMany({
          where: { userId: id },
        });
        await tx.userProfile.update({
          where: { id },
          data: { nationalityCode: null, secondNationalityCode: null },
        });
        return { matchRunsDeleted: runs.count };
      }),
    );
    if (!result) throw new NotFoundException('Profile not found.');
    return {
      nationalityCode: null,
      secondNationalityCode: null,
      matchRunsDeleted: result.matchRunsDeleted,
    };
  }

  /**
   * Keeps the two 503 causes apart. Both used to read as one generic
   * "unavailable", which is precisely how a real cause gets hidden: a student
   * told "storage problem" when in fact our scanner is down cannot be helped by
   * support, and neither can one told "connection problem" for a clean 404.
   */
  private translateAvatarStorageError(error: unknown): unknown {
    if (error instanceof InfectedFileError) return avatarInfected();
    if (error instanceof AntivirusUnavailableError) {
      return avatarScannerUnavailable();
    }
    if (error instanceof StorageWriteError) return avatarStorageUnavailable();
    return error;
  }

  /**
   * Weak validator derived from the storage key. The key itself is never sent —
   * it is hashed, so the ETag cannot be turned back into an object path.
   */
  private avatarEtag(storageKey: string): string {
    const digest = createHash('sha256')
      .update(`avatar:${storageKey}`)
      .digest('hex')
      .slice(0, 32);
    return `W/"${digest}"`;
  }

  private etagMatches(header: string, etag: string): boolean {
    return header
      .split(',')
      .map((candidate) => candidate.trim())
      .some(
        (candidate) =>
          candidate === '*' ||
          candidate === etag ||
          candidate === etag.replace(/^W\//, ''),
      );
  }

  /// GDPR / store-required account deletion. The Supabase identity is hard-
  /// deleted first, then every user-owned row is hard-deleted in one transaction
  /// (FK-safe order: case children → case-referencing rows → cases → other
  /// user-owned rows → profile). A provider failure aborts before any local
  /// write, so this endpoint can never report success while the login survives.
  async deleteMe(
    userId?: string,
  ): Promise<{ deleted: boolean; authIdentityRemoved: boolean }> {
    const id = userId ?? 'demo-user';
    const actorKey = this.analyticsActorKey(id);

    const purged = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({
        where: { id },
        select: {
          email: true,
          supabaseUserId: true,
          avatarStorageKey: true,
          // Whether this contact was ever pushed to Mautic. `null` = never
          // synced: deletion must NOT look it up, because the lookup itself would
          // newly disclose the email to the processor — the never-consented
          // invariant newsletter-sync.service.ts guarantees. Revue P1 #246.
          newsletterSyncedOptIn: true,
        },
      });
      if (!profile) return null;

      // Supabase Auth and Postgres cannot share a transaction. Delete Auth
      // first so provider/configuration failures leave the local account intact
      // and retriable instead of purging the only durable Supabase user id.
      // A later Postgres failure is returned as an error (never as success) and
      // needs operational cleanup; already-issued JWTs may remain valid only
      // until their configured expiry, per Supabase's documented semantics.
      const authIdentityRemoved = await this.deleteSupabaseAuthUser(
        profile.supabaseUserId,
      );

      const cases = await prisma.case.findMany({
        where: { userId: id },
        select: { id: true },
      });
      const caseIds = cases.map((c) => c.id);
      const workspaces = await prisma.scholarshipWorkspace.findMany({
        where: { userId: id },
        select: { id: true },
      });
      const workspaceIds = workspaces.map((workspace) => workspace.id);
      const artifactVersions = await prisma.applicationArtifactVersion.findMany({
        where: { artifact: { workspaceId: { in: workspaceIds } } },
        select: { id: true, storageKey: true },
      });
      const reviewRequests = await prisma.studyReviewRequest.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const outcomeEvidence = await prisma.outcomeEvidenceAsset.findMany({
        where: { ownerUserId: id },
        select: { id: true, storageKey: true },
      });
      const submissions = await prisma.applicationSubmission.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const admissionDecisions =
        await prisma.applicationDecisionRecord.findMany({
          where: { workspaceId: { in: workspaceIds } },
          select: { id: true },
        });
      const fundingDecisions = await prisma.fundingDecisionRecord.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const diagnostics = await prisma.aiDiagnostic.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const guardianAuthorizations =
        await prisma.guardianAuthorization.findMany({
          where: { OR: [{ minorUserId: id }, { guardianUserId: id }] },
          select: { evidenceStorageKey: true },
        });
      // Pilot enrolment/assessment mutations are initiated by an admin, so
      // their idempotency rows are owned by that admin rather than by the
      // participant. Collect the created resource ids before the membership
      // cascade so account deletion also erases response snapshots containing
      // the participant id, workspace id or research answers.
      const impactMemberships =
        await prisma.impactCohortMembership.findMany({
          where: { userId: id },
          select: {
            id: true,
            assessments: { select: { id: true } },
            experimentAssignment: { select: { id: true } },
          },
        });
      const artifactVersionIds = artifactVersions.map((version) => version.id);
      const reviewRequestIds = reviewRequests.map((request) => request.id);
      const evidenceIds = outcomeEvidence.map((evidence) => evidence.id);
      const submissionIds = submissions.map((submission) => submission.id);
      const admissionDecisionIds = admissionDecisions.map(
        (decision) => decision.id,
      );
      const fundingDecisionIds = fundingDecisions.map(
        (decision) => decision.id,
      );
      const diagnosticIds = diagnostics.map((diagnostic) => diagnostic.id);
      const impactMembershipIds = impactMemberships.map(
        (membership) => membership.id,
      );
      const impactMembershipChildIds = impactMemberships.flatMap(
        (membership) => [
          ...membership.assessments.map((assessment) => assessment.id),
          ...(membership.experimentAssignment
            ? [membership.experimentAssignment.id]
            : []),
        ],
      );
      const artifactStorageKeys = artifactVersions
        .map((version) => version.storageKey)
        .filter((key): key is string => Boolean(key));
      const outcomeStorageKeys = outcomeEvidence
        .map((evidence) => evidence.storageKey)
        .filter((key): key is string => Boolean(key));
      const guardianEvidenceStorageKeys = guardianAuthorizations
        .map((authorization) => authorization.evidenceStorageKey)
        .filter((key): key is string => Boolean(key));

      // Collect uploaded document URLs before deleting the rows, so we can also
      // remove the underlying files from object storage (GDPR right to erasure).
      const documents = await prisma.caseDocument.findMany({
        where: { caseId: { in: caseIds } },
        select: { fileUrl: true },
      });
      const fileUrls = documents
        .map((d: { fileUrl: string | null }) => d.fileUrl)
        .filter((u: string | null): u is string => !!u);

      // Counsellors this user reviewed — collected BEFORE the delete so their
      // denormalized avgRating/reviewCount can be recomputed AFTER it. Deleting
      // a published review would otherwise leave those counters inflated. P2 #246.
      const authoredReviews = await prisma.counsellorReview.findMany({
        where: reviewsOfUser(id, caseIds),
        select: { counsellorId: true },
      });
      const affectedCounsellorIds = [
        ...new Set(authoredReviews.map((r) => r.counsellorId)),
      ];

      // Communauté (C1 + C2) : SUPPRESSION définitive, pas d'anonymisation
      // (docs/community-api-contract.md §12). La fiche membre part en cascade
      // avec le profil, et avec elle publications (réponses des autres
      // comprises), réponses, « utile », mentions, suivis, blocages, charte,
      // sanctions, et les signalements VISANT ses contenus ou son profil ; ceux
      // qu'il a RÉDIGÉS restent, sans auteur (SET NULL), 12 mois au plus
      // (`reporterDeletedAt`, purge quotidienne). On relève AVANT la
      // suppression les contenus d'autrui dont les compteurs vont bouger
      // (ses réponses et ses « utile »), recalculés APRÈS.
      // Compétition ambassadeurs : relevés AVANT la cascade (la ligne
      // `Ambassador` emporte ses participations) pour effacer ce qui survit à
      // celle-ci — prix non versés et forfaits (SET NULL), et les traces du
      // journal d'audit qui visent ces lignes (audit 57, F08 et F17).
      const ambassadorRows = await prisma.ambassador.findMany({
        where: { userProfileId: id },
        select: { id: true },
      });
      const ambassadorIds = ambassadorRows.map((a) => a.id);
      const participantIds = ambassadorIds.length
        ? (
            await prisma.referralCampaignParticipant.findMany({
              where: { ambassadorId: { in: ambassadorIds } },
              select: { id: true },
            })
          ).map((p) => p.id)
        : [];
      const forfeitIds = participantIds.length
        ? (
            await prisma.referralCampaignPrizeForfeit.findMany({
              where: { participantId: { in: participantIds } },
              select: { id: true },
            })
          ).map((f) => f.id)
        : [];
      const refereeCampaignRowIds = (
        await prisma.referralCampaignReferral.findMany({
          where: { refereeProfileId: id },
          select: { id: true },
        })
      ).map((r) => r.id);
      // `changes` des lignes Ambassador / participant : `userProfileId`, nom
      // public, ville, statut de mineur, note d'autorisation parentale →
      // effacés. Forfait et décision sur un filleul : `changes` ne porte que
      // des identifiants de lignes supprimées et des rangs → gardés ; seul le
      // motif libre (`reasonCode`) part.
      const competitionAuditTargets = [
        { entityType: 'Ambassador', ids: ambassadorIds, eraseChanges: true },
        { entityType: 'ReferralCampaignParticipant', ids: participantIds, eraseChanges: true },
        { entityType: 'ReferralCampaignPrizeForfeit', ids: forfeitIds, eraseChanges: false },
        { entityType: 'ReferralCampaignReferral', ids: refereeCampaignRowIds, eraseChanges: false },
      ].filter((t) => t.ids.length > 0);

      const communityMember = await prisma.communityMember.findUnique({
        where: { userId: id },
        select: { id: true },
      });
      const communityMemberId = communityMember?.id ?? null;
      const communityTouched = communityMemberId
        ? await Promise.all([
            prisma.communityReply.findMany({
              where: { authorMemberId: communityMemberId },
              select: { postId: true },
            }),
            prisma.communityReaction.findMany({
              where: { memberId: communityMemberId },
              select: { postId: true, replyId: true, reply: { select: { postId: true } } },
            }),
          ])
        : null;
      const communityPostIds = communityTouched
        ? [
            ...new Set([
              ...communityTouched[0].map((r) => r.postId),
              ...communityTouched[1].flatMap((r) =>
                [r.postId, r.reply?.postId].filter((v): v is string => !!v),
              ),
            ]),
          ]
        : [];
      const communityReplyIds = communityTouched
        ? [
            ...new Set(
              communityTouched[1]
                .map((r) => r.replyId)
                .filter((v): v is string => !!v),
            ),
          ]
        : [];

      await prisma.$transaction([
        // Children of Case (no cascade defined).
        prisma.caseMessage.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseTimelineEvent.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.caseTask.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseDocument.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseInternalNote.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.notificationDelivery.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        // Livraisons des campagnes de l'équipe (diffusions : `caseId` NULL,
        // `recipientId` = référence plate sans cascade). Les statistiques de
        // campagne COMPTENT ces lignes (`campaignStats`, statut final de
        // l'exécuteur) : on les garde, ANONYMISÉES — plus de nom civil ni
        // d'identifiant de compte (audit 57, F05).
        prisma.notificationDelivery.updateMany({
          where: { recipientId: id },
          data: {
            recipientId: DELETED_RECIPIENT_ID,
            recipientName: DELETED_ACCOUNT_LABEL,
          },
        }),
        // Rows that reference Case (must precede Case).
        prisma.appointment.deleteMany({ where: { userId: id } }),
        // ServicePurchase references PaymentIntent → delete it first.
        prisma.servicePurchase.deleteMany({ where: { userId: id } }),
        prisma.paymentIntent.deleteMany({ where: { userId: id } }),
        prisma.case.deleteMany({ where: { userId: id } }),
        // Other user-owned rows.
        prisma.savedItem.deleteMany({ where: { userId: id } }),
        prisma.academyPurchase.deleteMany({ where: { userId: id } }),
        prisma.salonRegistration.deleteMany({ where: { userId: id } }),
        // CoachMessage cascades from CoachConversation (onDelete: Cascade).
        prisma.coachConversation.deleteMany({ where: { userId: id } }),
        prisma.orientationSession.deleteMany({ where: { userId: id } }),
        prisma.parentChildLink.deleteMany({
          where: { OR: [{ parentId: id }, { childId: id }] },
        }),
        prisma.referral.deleteMany({
          where: { OR: [{ referrerId: id }, { refereeProfileId: id }] },
        }),
        // Referral-reward ledger (KPB-77) — FK is ON DELETE RESTRICT.
        prisma.creditTransaction.deleteMany({ where: { profileId: id } }),
        // ── Résidus à référence « plate » : ces tables pointent le profil par un
        // String SANS `@relation`, donc AUCUNE cascade ne les atteint. Sans ces
        // trois lignes, un nom civil et un compte de paiement survivent à la
        // suppression de compte — droit à l'effacement (RGPD), STORE_READINESS §6,
        // revue P1 sur #244. Gardés par profiles.postgres.spec.ts.
        //
        // (1) Avis conseiller rédigé PAR l'utilisateur : porte `reviewerName`
        // (nom civil) + `body`. `reviewerUserId` est `String?` sans relation —
        // et NULL pour tous les avis enregistrés avant que l'auteur vienne du
        // jeton : ceux-là se retrouvent par le dossier noté (voir reviewsOfUser).
        prisma.counsellorReview.deleteMany({ where: reviewsOfUser(id, caseIds) }),
        // (2a) Compétition, AVANT la cascade : un prix NON versé et un forfait
        // survivent à la suppression (SET NULL) — ils ne gardent plus ni le nom
        // public ni le motif libre. Le prix VERSÉ reste tel quel (rang, nom
        // public, montant, versement : la trace comptable que la politique
        // annonce). Un prix non versé devenu orphelin se déclare forfait et se
        // réattribue comme les autres (`forfeitPrize`, sans `participantId`).
        prisma.referralCampaignPrizeAward.updateMany({
          where: {
            participantId: { in: participantIds },
            payoutStatus: { not: 'paid' },
          },
          data: {
            publicNameSnapshot: DELETED_ACCOUNT_LABEL,
            note: null,
            payoutReference: null,
          },
        }),
        prisma.referralCampaignPrizeForfeit.updateMany({
          where: { participantId: { in: participantIds } },
          data: {
            publicNameSnapshot: DELETED_ACCOUNT_LABEL,
            reason: ERASED_FORFEIT_REASON,
          },
        }),
        // Journal d'audit (jamais purgé) : l'action, l'auteur et la date
        // restent — c'est la responsabilité de l'équipe — mais plus le lien
        // vers le compte (`userProfileId`), le nom public, la ville, le statut
        // de mineur, la note d'autorisation parentale ni les motifs libres.
        ...competitionAuditTargets.map((target) =>
          prisma.adminAuditEvent.updateMany({
            where: { entityType: target.entityType, entityId: { in: target.ids } },
            data: target.eraseChanges
              ? { changes: ERASED_AUDIT_CHANGES, reasonCode: null }
              : { reasonCode: null },
          }),
        ),
        // (2) L'utilisateur EN TANT QU'ambassadeur : la ligne `Ambassador` porte le
        // `payoutAccount`. Ses `referrals` / `commissions` / `withdrawals` ont
        // `ambassador … onDelete: Cascade` (relationMode foreignKeys), donc
        // supprimer l'`Ambassador` les emporte au niveau base — ne pas les lister.
        prisma.ambassador.deleteMany({ where: { userProfileId: id } }),
        // (3) L'utilisateur EN TANT QUE filleul d'un AUTRE ambassadeur : cette ligne
        // (`refereeName` = son nom) appartient à l'ambassadeur parrain, donc aucune
        // cascade partant de cet utilisateur ne l'atteint. À purger nommément —
        // sans toucher l'ambassadeur parrain lui-même.
        prisma.ambassadorReferral.deleteMany({
          where: { refereeProfileId: id },
        }),
        // (4) Compétition ambassadeurs : l'utilisateur EN TANT QUE filleul dans
        // une campagne (référence plate, comme ci-dessus) et ses empreintes
        // anti-fraude, comme filleul ou comme parrain. En tant qu'ambassadeur,
        // ses participations partent par cascade avec la ligne `Ambassador` ;
        // un prix déjà versé garde sa trace comptable (`participantId` → NULL,
        // nom public figé) ; les prix non versés et les forfaits sont
        // anonymisés plus haut (2a).
        prisma.referralCampaignReferral.deleteMany({
          where: { refereeProfileId: id },
        }),
        prisma.referralAttributionSignal.deleteMany({
          where: {
            OR: [{ refereeProfileId: id }, { referrerProfileId: id }],
          },
        }),
        // Competition Readiness technical records do not all have an FK to the
        // profile. Purge them explicitly before the workspace/profile cascade.
        prisma.analyticsEvent.deleteMany({
          where: {
            OR: [
              { workspaceId: { in: workspaceIds } },
              ...(actorKey ? [{ actorKey }] : []),
            ],
          },
        }),
        prisma.domainEventOutbox.deleteMany({
          where: {
            OR: [
              {
                aggregateType: 'ScholarshipWorkspace',
                aggregateId: { in: workspaceIds },
              },
              {
                aggregateType: 'ApplicationArtifactVersion',
                aggregateId: { in: artifactVersionIds },
              },
              {
                aggregateType: 'StudyReviewRequest',
                aggregateId: { in: reviewRequestIds },
              },
              {
                aggregateType: 'OutcomeEvidenceAsset',
                aggregateId: { in: evidenceIds },
              },
              {
                aggregateType: 'ApplicationSubmission',
                aggregateId: { in: submissionIds },
              },
              {
                aggregateType: 'ApplicationDecisionRecord',
                aggregateId: { in: admissionDecisionIds },
              },
              {
                aggregateType: 'FundingDecisionRecord',
                aggregateId: { in: fundingDecisionIds },
              },
              {
                aggregateType: 'AiDiagnostic',
                aggregateId: { in: diagnosticIds },
              },
            ],
          },
        }),
        prisma.idempotencyRecord.deleteMany({
          where: {
            OR: [
              // Student-owned operations.
              { actorId: id },
              // Admin-owned pilot operations whose replay snapshot contains
              // this student's research or membership data.
              ...(impactMembershipIds.length > 0
                ? [
                    {
                      resourceType: 'ImpactCohortMembership',
                      resourceId: { in: impactMembershipIds },
                    },
                  ]
                : []),
              ...(impactMembershipChildIds.length > 0
                ? [
                    {
                      resourceType: 'PilotRecord',
                      resourceId: { in: impactMembershipChildIds },
                    },
                  ]
                : []),
            ],
          },
        }),
        // Shares restrict deletion of both consent receipts and artifact
        // versions, so they must be removed before the workspace cascade.
        prisma.studyReviewArtifactShare.deleteMany({
          where: { reviewRequestId: { in: reviewRequestIds } },
        }),
        // Outcome records use RESTRICT for immutable evidence and revision
        // chains. Break optional history links, then remove children before the
        // evidence and consent receipts they reference.
        prisma.outcomeVerificationEvent.deleteMany({
          where: {
            OR: [
              { entityType: 'submission', entityId: { in: submissionIds } },
              {
                entityType: 'admission',
                entityId: { in: admissionDecisionIds },
              },
              {
                entityType: 'funding',
                entityId: { in: fundingDecisionIds },
              },
            ],
          },
        }),
        prisma.outcomeEvidenceLink.deleteMany({
          where: {
            OR: [
              { evidenceId: { in: evidenceIds } },
              { linkedByUserId: id },
            ],
          },
        }),
        prisma.fundingDecisionRecord.updateMany({
          where: { workspaceId: { in: workspaceIds } },
          data: { supersedesId: null, admissionDecisionId: null },
        }),
        prisma.fundingDecisionRecord.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        prisma.applicationDecisionRecord.updateMany({
          where: { workspaceId: { in: workspaceIds } },
          data: { supersedesId: null },
        }),
        prisma.applicationDecisionRecord.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        prisma.applicationSubmission.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        // Preserve aggregate AI accounting while severing every user link.
        prisma.aiUsageAttempt.updateMany({
          where: { diagnosticId: { in: diagnosticIds } },
          data: {
            diagnosticId: null,
            actorKey: null,
            providerRequestId: null,
          },
        }),
        prisma.aiBudgetTransaction.updateMany({
          where: { diagnosticId: { in: diagnosticIds } },
          data: { diagnosticId: null },
        }),
        prisma.outcomeEvidenceAsset.deleteMany({
          where: { id: { in: evidenceIds } },
        }),
        // Pilot memberships also RESTRICT their explicit research receipt.
        // Assessments and assignments cascade from the membership.
        prisma.impactCohortMembership.deleteMany({ where: { userId: id } }),
        // Receipts must precede GuardianAuthorization because that relation is
        // RESTRICT; workspaces themselves cascade from UserProfile.
        prisma.consentReceipt.deleteMany({ where: { userId: id } }),
        prisma.guardianAuthorization.deleteMany({
          where: { OR: [{ minorUserId: id }, { guardianUserId: id }] },
        }),
        prisma.deviceToken.deleteMany({ where: { userProfileId: id } }),
        prisma.partnerLead.deleteMany({ where: { userId: id } }),
        prisma.studentCredential.deleteMany({ where: { userProfileId: id } }),
        prisma.magicLinkToken.deleteMany({ where: { email: profile.email } }),
        // Journal de modération : l'action reste (responsabilité de l'équipe),
        // le lien vers le membre part. Référence plate, sans cascade.
        ...(communityMemberId
          ? [
              prisma.forumModerationAction.updateMany({
                where: { memberId: communityMemberId },
                data: { memberId: null },
              }),
              // Signalements RÉDIGÉS : ils restent sans auteur (SET NULL à la
              // suppression du profil, plus bas), datés ici pour la purge à
              // 12 mois (`CommunityPurgeCronService`, chantier juridique 57).
              prisma.communityReport.updateMany({
                where: { reporterMemberId: communityMemberId },
                data: { reporterDeletedAt: new Date() },
              }),
            ]
          : []),
        prisma.userProfile.delete({ where: { id } }),
      ]);

      // Compteurs des publications et réponses d'AUTRES membres touchées
      // (celles du membre sont déjà parties ; les ids absents sont ignorés).
      await refreshReplyCounters(prisma, communityReplyIds);
      await refreshPostCounters(prisma, communityPostIds);

      // Recompute each affected counsellor's published-review counters, mirroring
      // CounsellorsService (avgRating/reviewCount over isPublished reviews).
      // updateMany, not update: no throw if a counsellor was removed meanwhile.
      // P2 #246.
      for (const counsellorId of affectedCounsellorIds) {
        const published = await prisma.counsellorReview.findMany({
          where: { counsellorId, isPublished: true },
          select: { rating: true },
        });
        const count = published.length;
        const avg =
          count === 0
            ? 0
            : published.reduce((sum, r) => sum + r.rating, 0) / count;
        await prisma.counsellor.updateMany({
          where: { id: counsellorId },
          data: { avgRating: avg, reviewCount: count },
        });
      }

      return {
        authIdentityRemoved,
        supabaseUserId: profile.supabaseUserId,
        // Carried out of the transaction so the newsletter processor (Mautic)
        // can be asked to forget the contact after the local purge succeeds —
        // but ONLY when it was ever synced (the gate at the call site).
        email: profile.email,
        newsletterSyncedOptIn: profile.newsletterSyncedOptIn,
        fileUrls,
        artifactStorageKeys,
        outcomeStorageKeys,
        guardianEvidenceStorageKeys,
        // The profile photo is user-uploaded content too: erasure must reach the
        // object, not just the column that pointed at it.
        avatarStorageKeys: profile.avatarStorageKey
          ? [profile.avatarStorageKey]
          : [],
      };
    });

    if (!purged) {
      // No DB (demo mode) or no such profile — nothing to purge server-side.
      return { deleted: false, authIdentityRemoved: false };
    }

    // Best-effort deletion of the uploaded files (passports, transcripts) from
    // object storage. Never abort the deletion outcome if a file delete fails —
    // StorageService.delete already swallows and logs its own errors.
    for (const url of purged.fileUrls) {
      const key = this.storageService.keyFromUrl(url);
      if (key) await this.storageService.delete(key);
    }
    for (const key of purged.artifactStorageKeys) {
      await this.storageService.delete(key);
    }
    for (const key of purged.outcomeStorageKeys) {
      await this.storageService.delete(key);
    }
    for (const key of purged.guardianEvidenceStorageKeys) {
      await this.storageService.delete(key);
    }
    for (const key of purged.avatarStorageKeys) {
      await this.storageService.delete(key);
    }

    // Ask the newsletter processor (Mautic) to forget the contact too. Outside
    // the transaction and best-effort: Postgres and an external marketing system
    // cannot share one, and the local deletion must stand even if Mautic is
    // unreachable. Gated on `newsletterSyncedOptIn` being non-null: a
    // never-consented account holds nothing at Mautic, and even the lookup would
    // newly disclose its email — the leak newsletter-sync guards against (P1 #246).
    await this.newsletterSync?.forgetContact(
      purged.email,
      purged.newsletterSyncedOptIn,
    );

    return {
      deleted: true,
      authIdentityRemoved: purged.authIdentityRemoved,
    };
  }

  /// Hard-delete the Supabase Auth identity via the Admin REST API. Production
  /// bootstrap requires these credentials and a request failure is fail-closed.
  /// Tests/development retain the no-key local-purge path for ergonomics.
  private async deleteSupabaseAuthUser(
    supabaseUserId: string | null,
  ): Promise<boolean> {
    if (!supabaseUserId) {
      if (process.env.NODE_ENV === 'production') {
        this.logger.error(
          'Account deletion refused because the profile is not linked to a Supabase Auth identity.',
        );
        throw this.accountDeletionUnavailable();
      }
      return false;
    }
    const url = process.env.SUPABASE_URL?.trim();
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    if (!url || !key) {
      if (process.env.NODE_ENV === 'production') {
        this.logger.error(
          'Account deletion refused because the Supabase admin configuration is unavailable.',
        );
        throw this.accountDeletionUnavailable();
      }
      this.logger.warn(
        'Supabase Auth identity deletion skipped outside production because admin credentials are not configured.',
      );
      return false;
    }

    let res: Response;
    try {
      res = await fetch(
        `${url.replace(/\/+$/, '')}/auth/v1/admin/users/${encodeURIComponent(supabaseUserId)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: key,
            authorization: `Bearer ${key}`,
            'content-type': 'application/json',
          },
          // Match auth.admin.deleteUser(id, false) explicitly. The false value
          // is a hard delete; true would retain a soft-deleted auth.users row.
          body: JSON.stringify({ should_soft_delete: false }),
          signal: AbortSignal.timeout(10_000),
        },
      );
    } catch {
      // Provider error bodies and URLs can contain tokens or user identifiers.
      this.logger.error('Supabase admin deleteUser request failed.');
      throw this.accountDeletionUnavailable();
    }

    // Idempotent retry: 404 proves the identity is already absent (for example
    // when the provider committed a previous request but its response was lost).
    if (!res.ok && res.status !== 404) {
      this.logger.error(
        `Supabase admin deleteUser failed with status ${res.status}.`,
      );
      throw this.accountDeletionUnavailable();
    }
    return true;
  }

  private accountDeletionUnavailable(): ServiceUnavailableException {
    return new ServiceUnavailableException(
      'Account deletion is temporarily unavailable. Please retry.',
    );
  }

  /// GDPR data export (portability): aggregate every user-owned record into one
  /// JSON document. Uploaded document files are referenced by URL, not embedded.
  async exportMe(userId?: string) {
    const id = userId ?? 'demo-user';
    const actorKey = this.analyticsActorKey(id);

    const data = await this.prismaService.execute(async (prisma) => {
      const row = await prisma.userProfile.findUnique({ where: { id } });
      if (!row) return null;
      // The export is a document the student may forward anywhere. Private
      // storage keys stay out of it (see the `note` below) — the photo is
      // reported as a boolean, and downloaded from the authenticated endpoint.
      const { avatarStorageKey, ...exportableProfile } = row;
      const profile = {
        ...exportableProfile,
        hasAvatar: Boolean(avatarStorageKey),
      };

      const [
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinksAsParent,
        parentLinksAsChild,
        scholarshipWorkspaces,
        consentReceipts,
        aiQuotaBuckets,
        impactCohortMemberships,
        eefInterest,
        scholarshipMatchRuns,
        scholarshipAlertSubscriptions,
        campaignParticipations,
        campaignReferrals,
        referralSignals,
        communityMember,
        referralAsReferee,
        referralsAsReferrer,
        creditTransactions,
        ambassadorRow,
        prizeAwards,
        prizeForfeits,
        campaignDeliveries,
      ] = await Promise.all([
        prisma.case.findMany({
          where: { userId: id },
          include: { messages: true, timelineEvents: true, documents: true },
        }),
        prisma.savedItem.findMany({ where: { userId: id } }),
        prisma.appointment.findMany({ where: { userId: id } }),
        prisma.academyPurchase.findMany({ where: { userId: id } }),
        prisma.servicePurchase.findMany({ where: { userId: id } }),
        prisma.salonRegistration.findMany({ where: { userId: id } }),
        prisma.coachConversation.findMany({
          where: { userId: id },
          include: { messages: true },
        }),
        prisma.orientationSession.findMany({ where: { userId: id } }),
        prisma.parentChildLink.findMany({ where: { parentId: id } }),
        prisma.parentChildLink.findMany({ where: { childId: id } }),
        prisma.scholarshipWorkspace.findMany({
          where: { userId: id },
          include: {
            steps: true,
            artifacts: {
              orderBy: [{ kind: 'asc' }, { createdAt: 'asc' }],
              select: {
                id: true,
                workspaceId: true,
                kind: true,
                title: true,
                currentVersionId: true,
                createdAt: true,
                updatedAt: true,
                versions: {
                  orderBy: { versionNumber: 'asc' },
                  select: {
                    id: true,
                    artifactId: true,
                    versionNumber: true,
                    originalFileName: true,
                    mimeType: true,
                    sizeBytes: true,
                    sha256: true,
                    processingStatus: true,
                    rejectionCode: true,
                    uploadedAt: true,
                    deletedAt: true,
                    createdAt: true,
                  },
                },
              },
            },
            reviewRequests: {
              orderBy: { requestNumber: 'asc' },
              include: {
                artifactShares: {
                  select: {
                    id: true,
                    artifactVersionId: true,
                    consentReceiptId: true,
                    grantedAt: true,
                    revokedAt: true,
                  },
                },
              },
            },
            diagnostics: {
              orderBy: { createdAt: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                artifactVersionId: true,
                status: true,
                documentKind: true,
                generatedLanguage: true,
                strength: true,
                priorityImprovement: true,
                rationale: true,
                nextAction: true,
                criterionReferences: true,
                workspaceVersion: true,
                criteriaVersion: true,
                promptVersion: true,
                fallbackReason: true,
                startedAt: true,
                completedAt: true,
                createdAt: true,
                updatedAt: true,
                usageAttempts: {
                  orderBy: { attemptNumber: 'asc' },
                  select: {
                    id: true,
                    attemptNumber: true,
                    feature: true,
                    provider: true,
                    model: true,
                    promptVersion: true,
                    priceVersion: true,
                    usageSource: true,
                    inputTokens: true,
                    cachedInputTokens: true,
                    outputTokens: true,
                    totalTokens: true,
                    latencyMs: true,
                    estimatedCostMicrosUsd: true,
                    outcome: true,
                    errorCode: true,
                    startedAt: true,
                    completedAt: true,
                    createdAt: true,
                  },
                },
              },
            },
            outcomeEvidence: {
              orderBy: { createdAt: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                kind: true,
                originalFileName: true,
                mimeType: true,
                sizeBytes: true,
                sha256: true,
                processingStatus: true,
                version: true,
                rejectionCode: true,
                retentionClass: true,
                uploadedAt: true,
                deletedAt: true,
                createdAt: true,
                updatedAt: true,
                links: {
                  orderBy: { linkedAt: 'asc' },
                  select: {
                    id: true,
                    entityType: true,
                    entityId: true,
                    isPrimary: true,
                    linkedAt: true,
                  },
                },
              },
            },
            submissions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                version: true,
                submittedAt: true,
                submissionChannel: true,
                applicationRefHash: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
            admissionDecisions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                supersedesId: true,
                version: true,
                isCurrent: true,
                issuedByName: true,
                admissionDecision: true,
                issuedAt: true,
                receivedAt: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
            fundingDecisions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                admissionDecisionId: true,
                supersedesId: true,
                version: true,
                isCurrent: true,
                issuedByName: true,
                fundingDecision: true,
                fundingAmountMinor: true,
                fundingCurrency: true,
                issuedAt: true,
                receivedAt: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
          },
          orderBy: { lastActivityAt: 'desc' },
        }),
        prisma.consentReceipt.findMany({
          where: { userId: id },
          select: {
            id: true,
            userId: true,
            purpose: true,
            noticeId: true,
            languageCode: true,
            channel: true,
            grantedAt: true,
            revokedAt: true,
            guardianAuthorizationId: true,
            ipHash: true,
            userAgentClass: true,
            createdAt: true,
            notice: {
              select: {
                id: true,
                purpose: true,
                version: true,
                languageCode: true,
                contentHash: true,
                effectiveAt: true,
                retiredAt: true,
              },
            },
            guardianAuthorization: {
              select: {
                id: true,
                minorUserId: true,
                guardianUserId: true,
                relationshipCode: true,
                verificationMethod: true,
                status: true,
                verifiedAt: true,
                expiresAt: true,
                revokedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
          },
          orderBy: { grantedAt: 'desc' },
        }),
        prisma.aiQuotaBucket.findMany({
          where: { userId: id },
          select: {
            id: true,
            feature: true,
            periodKey: true,
            quotaLimit: true,
            used: true,
            resetsAt: true,
            createdAt: true,
            updatedAt: true,
          },
          orderBy: { createdAt: 'asc' },
        }),
        prisma.impactCohortMembership.findMany({
          where: { userId: id },
          select: {
            id: true,
            cohortId: true,
            workspaceId: true,
            consentReceiptId: true,
            version: true,
            status: true,
            enrolledAt: true,
            withdrawnAt: true,
            exitReason: true,
            countryCodeLocked: true,
            studyLevelLocked: true,
            genderCodeLocked: true,
            deviceClassLocked: true,
            connectivityLocked: true,
            profileRubricVersion: true,
            matchingAlgorithmVersion: true,
            baselineSnapshot: true,
            cohort: {
              select: {
                id: true,
                code: true,
                version: true,
                label: true,
                cohortType: true,
                pilot: {
                  select: {
                    id: true,
                    code: true,
                    version: true,
                    name: true,
                    hypothesis: true,
                    protocolVersion: true,
                    status: true,
                  },
                },
              },
            },
            assessments: {
              orderBy: { administeredAt: 'asc' },
              select: {
                id: true,
                assessmentType: true,
                instrumentVersion: true,
                answers: true,
                score: true,
                administeredAt: true,
              },
            },
            experimentAssignment: {
              select: {
                id: true,
                experimentKey: true,
                experimentVersion: true,
                armCode: true,
                assignedAt: true,
              },
            },
          },
          orderBy: { enrolledAt: 'asc' },
        }),
        // La déclaration d'intérêt « Études en France ».
        //
        // Elle manquait. La SUPPRESSION la couvrait déjà par la cascade, mais
        // l'export non : un étudiant qui demandait ses données ne recevait ni sa
        // déclaration, ni son `consentedAt` — c'est-à-dire précisément la preuve
        // qu'on lui opposerait s'il demandait sur quelle base on l'a rappelé.
        //
        // Le doc de release la listait honnêtement comme absente ; documenter une
        // omission n'est pas la réparer quand le champ est le consentement.
        prisma.eefInterest.findMany({
          where: { userId: id },
          select: {
            id: true,
            currentLevel: true,
            targetLevel: true,
            fieldIds: true,
            wantsPremium: true,
            consentVersion: true,
            consentedAt: true,
            createdAt: true,
            updatedAt: true,
          },
        }),
        // « Mes 10 bourses » (chantier D) : les résultats calculés pour
        // l'élève (5 au plus). Supprimés avec le profil par la cascade.
        prisma.scholarshipMatchRun.findMany({
          where: { userId: id },
          orderBy: { createdAt: 'asc' },
        }),
        // Les cloches « M'avertir » posées par l'élève. Elles manquaient à
        // l'export alors que la suppression les couvre (cascade).
        prisma.scholarshipAlertSubscription.findMany({
          where: { userId: id },
          orderBy: { createdAt: 'asc' },
        }),
        // Compétition ambassadeurs : participations (comme ambassadeur), lignes
        // de filleul et empreintes anti-fraude (hachées) relevées au parrainage.
        prisma.referralCampaignParticipant.findMany({
          where: { ambassador: { userProfileId: id } },
          select: {
            publicName: true,
            city: true,
            country: true,
            status: true,
            statusReason: true,
            minorStatus: true,
            parentalAuthStatus: true,
            parentalAuthVerifiedAt: true,
            qualifiedCount: true,
            rank: true,
            enrolledAt: true,
            campaign: { select: { slug: true, nameFr: true, startsAt: true, endsAt: true } },
          },
        }),
        prisma.referralCampaignReferral.findMany({
          where: { refereeProfileId: id },
          select: {
            attachedAt: true,
            qualifiedAt: true,
            status: true,
            flags: true,
            adminDecision: true,
            adminDecisionReason: true,
            campaign: { select: { slug: true, nameFr: true } },
          },
        }),
        prisma.referralAttributionSignal.findMany({
          where: { refereeProfileId: id },
          select: {
            codeKind: true,
            ipHash: true,
            ipBlockHash: true,
            deviceHashes: true,
            clientDeviceHash: true,
            createdAt: true,
          },
        }),
        // Communauté (C1 + C2) : tout ce que le membre a écrit ou décidé, tous
        // états confondus. Les signalements VISANT l'élève ne lui sont pas
        // rendus (protection des signaleurs), seulement ceux qu'il a rédigés.
        prisma.communityMember.findUnique({
          where: { userId: id },
          select: {
            id: true,
            charterVersion: true,
            charterAcceptedAt: true,
            createdAt: true,
            charterAcceptances: { select: { version: true, acceptedAt: true }, orderBy: { acceptedAt: 'asc' } },
            posts: {
              select: {
                id: true, type: true, title: true, body: true, status: true, statusReason: true,
                createdAt: true, editedAt: true, deletedAt: true,
                mentions: { select: { entityType: true, entityId: true, labelFr: true } },
                hashtags: { select: { hashtag: { select: { tag: true } } } },
              },
              orderBy: { createdAt: 'asc' },
            },
            replies: {
              select: {
                id: true, postId: true, body: true, status: true, statusReason: true,
                isVerified: true, createdAt: true, editedAt: true, deletedAt: true,
              },
              orderBy: { createdAt: 'asc' },
            },
            reactions: { select: { postId: true, replyId: true, createdAt: true }, orderBy: { createdAt: 'asc' } },
            follows: { select: { postId: true, createdAt: true }, orderBy: { createdAt: 'asc' } },
            blocksMade: { select: { blockedMemberId: true, createdAt: true }, orderBy: { createdAt: 'asc' } },
            reportsFiled: {
              select: { targetType: true, targetKey: true, reason: true, details: true, status: true, createdAt: true, resolvedAt: true },
              orderBy: { createdAt: 'asc' },
            },
            sanctions: {
              select: { kind: true, reason: true, endsAt: true, createdAt: true, revokedAt: true },
              orderBy: { createdAt: 'asc' },
            },
          },
        }),
        // Parrainage (politique §8, audit 57 F07) : le rattachement de l'élève
        // comme filleul (date seule : ni le nom ni l'identifiant du parrain),
        // ses filleuls comme parrain (dates seules : le nombre est déjà
        // affiché dans l'app), ses crédits (sans l'identifiant du filleul de
        // `metadata`), son espace ambassadeur et ses prix et forfaits.
        prisma.referral.findUnique({
          where: { refereeProfileId: id },
          select: { createdAt: true },
        }),
        prisma.referral.findMany({
          where: { referrerId: id },
          orderBy: { createdAt: 'asc' },
          select: { createdAt: true },
        }),
        prisma.creditTransaction.findMany({
          where: { profileId: id },
          orderBy: { createdAt: 'asc' },
          select: { amount: true, reason: true, metadata: true, createdAt: true },
        }),
        prisma.ambassador.findUnique({
          where: { userProfileId: id },
          select: {
            code: true,
            displayName: true,
            campus: true,
            city: true,
            payoutMethod: true,
            payoutAccount: true,
            kycStatus: true,
            totalReferrals: true,
            totalCommissionsFCFA: true,
            activatedAt: true,
            approvedAt: true,
            cashProgramEnabled: true,
            referrals: {
              orderBy: { signedUpAt: 'asc' },
              select: {
                status: true,
                signedUpAt: true,
                quizCompletedAt: true,
                applicationCreatedAt: true,
                premiumSubscribedAt: true,
                placedAt: true,
              },
            },
            commissions: {
              orderBy: { earnedAt: 'asc' },
              select: { amountFCFA: true, reason: true, label: true, earnedAt: true },
            },
            withdrawals: {
              orderBy: { requestedAt: 'asc' },
              select: {
                amountFCFA: true,
                method: true,
                destinationAccount: true,
                status: true,
                requestedAt: true,
                processedAt: true,
                transactionId: true,
              },
            },
          },
        }),
        prisma.referralCampaignPrizeAward.findMany({
          where: { participant: { ambassador: { userProfileId: id } } },
          orderBy: [{ createdAt: 'asc' }, { rank: 'asc' }],
          select: {
            rank: true,
            publicNameSnapshot: true,
            amountFcfa: true,
            recipient: true,
            payoutStatus: true,
            payoutMethod: true,
            payoutReference: true,
            paidAmountFcfa: true,
            paidAt: true,
            createdAt: true,
            campaign: { select: { slug: true, nameFr: true } },
          },
        }),
        prisma.referralCampaignPrizeForfeit.findMany({
          where: { participant: { ambassador: { userProfileId: id } } },
          orderBy: { forfeitedAt: 'asc' },
          select: {
            rank: true,
            publicNameSnapshot: true,
            amountFcfa: true,
            reason: true,
            forfeitedAt: true,
            campaign: { select: { slug: true, nameFr: true } },
          },
        }),
        // Livraisons des campagnes de l'équipe (audit 57, F05) : la campagne,
        // le canal, l'état et les dates — pas `recipientName`, ni les
        // identifiants internes.
        prisma.notificationDelivery.findMany({
          where: { recipientId: id },
          orderBy: { createdAt: 'asc' },
          select: {
            channel: true,
            status: true,
            createdAt: true,
            deliveredAt: true,
            openedAt: true,
            campaign: { select: { name: true, templateId: true } },
          },
        }),
      ]);

      // Les avis que l'étudiant a rédigés sur ses conseillers : son nom, sa note
      // et son texte sont SES données. Ils manquaient à l'export alors que la
      // suppression de compte les efface — tant que l'auteur restait NULL, il
      // n'existait aucun moyen de les retrouver. Lus après les dossiers : ceux
      // d'avant l'auteur ne se rattachent que par le dossier noté.
      const counsellorReviews = await prisma.counsellorReview.findMany({
        where: reviewsOfUser(
          id,
          cases.map((c) => c.id),
        ),
        orderBy: { createdAt: 'asc' },
        select: {
          id: true,
          counsellorId: true,
          caseId: true,
          reviewerName: true,
          rating: true,
          body: true,
          isPublished: true,
          createdAt: true,
        },
      });

      // Bot « Passerelle » (C3 bis) : les besoins repérés dans ce que l'élève a
      // écrit et ce qu'il a fait des suggestions. Aucun texte n'y est stocké :
      // le besoin, la règle, la source (type + id) et les dates.
      const assistBridgeEvents = await prisma.assistBridgeEvent.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'asc' },
        select: {
          source: true,
          sourceId: true,
          needId: true,
          ruleId: true,
          ruleVersion: true,
          status: true,
          statusReason: true,
          createdAt: true,
          sentAt: true,
          openedFeatureAt: true,
          openedWhatsappAt: true,
          dismissedAt: true,
        },
      });

      // Les notifications in-app de l'élève (annonces d'ouverture, rappels de
      // date limite, communauté, passerelle…). Elles manquaient à l'export
      // alors que la suppression les couvre (cascade). Seuls les champs qui
      // décrivent la notification et son sort sont rendus : la clé de
      // déduplication, les verrous et l'identifiant du worker, le lot et la
      // dernière erreur du fournisseur sont des détails d'exploitation.
      const notifications = await prisma.userNotification.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'asc' },
        select: {
          id: true,
          kind: true,
          scholarshipId: true,
          cycleId: true,
          titleFr: true,
          titleEn: true,
          bodyFr: true,
          bodyEn: true,
          route: true,
          data: true,
          createdAt: true,
          readAt: true,
          pushedAt: true,
          pushStatus: true,
        },
      });

      const workspaceIds = scholarshipWorkspaces.map(
        (workspace) => workspace.id,
      );
      const analyticsEvents = await prisma.analyticsEvent.findMany({
        where: {
          OR: [
            { workspaceId: { in: workspaceIds } },
            ...(actorKey ? [{ actorKey }] : []),
          ],
        },
        select: {
          eventId: true,
          eventName: true,
          schemaVersion: true,
          occurredAt: true,
          receivedAt: true,
          source: true,
          pilotId: true,
          cohortId: true,
          countryCodeLocked: true,
          scholarshipId: true,
          cycleId: true,
          workspaceId: true,
          properties: true,
          isTest: true,
        },
        orderBy: { occurredAt: 'asc' },
      });

      // Titre public (celui qu'a vu l'élève) de chaque campagne reçue.
      const templateIds = [
        ...new Set(
          campaignDeliveries
            .map((d) => d.campaign.templateId)
            .filter((v): v is string => !!v),
        ),
      ];
      const templates = templateIds.length
        ? await prisma.notificationTemplate.findMany({
            where: { id: { in: templateIds } },
            select: { id: true, titleFr: true, titleEn: true },
          })
        : [];
      const templateById = new Map(templates.map((t) => [t.id, t]));
      const campaignNotifications = campaignDeliveries.map((d) => {
        const template = d.campaign.templateId
          ? templateById.get(d.campaign.templateId)
          : undefined;
        return {
          campaign: {
            name: d.campaign.name,
            titleFr: template?.titleFr ?? null,
            titleEn: template?.titleEn ?? null,
          },
          channel: d.channel,
          status: d.status,
          sentAt: d.createdAt,
          deliveredAt: d.deliveredAt,
          openedAt: d.openedAt,
        };
      });

      return {
        profile,
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinks: { asParent: parentLinksAsParent, asChild: parentLinksAsChild },
        counsellorReviews,
        scholarshipWorkspaces,
        consentReceipts,
        aiQuotaBuckets,
        analyticsEvents,
        impactCohortMemberships,
        // `findMany` puis premier élément : la contrainte unique sur `userId`
        // garantit zéro ou une ligne, et rendre un objet plutôt qu'un tableau
        // d'un élément dit au lecteur ce que la donnée est réellement.
        eefInterest: eefInterest[0] ?? null,
        scholarshipMatchRuns,
        scholarshipAlertSubscriptions,
        referral: {
          code: row.referralCode,
          creditBalance: row.reviewCredits,
          asReferee: referralAsReferee
            ? { attachedAt: referralAsReferee.createdAt }
            : null,
          asReferrer: {
            count: referralsAsReferrer.length,
            attachedAt: referralsAsReferrer.map((r) => r.createdAt),
          },
          creditTransactions: creditTransactions.map((t) => ({
            amount: t.amount,
            reason: t.reason,
            ...(voucherCodeOf(t.metadata) ? { voucherCode: voucherCodeOf(t.metadata) } : {}),
            createdAt: t.createdAt,
          })),
          ambassador: ambassadorRow
            ? {
                ...ambassadorRow,
                // Le compte de versement est rendu masqué : l'export peut
                // circuler, l'élève connaît son numéro.
                payoutAccount: maskAccount(ambassadorRow.payoutAccount),
                withdrawals: ambassadorRow.withdrawals.map((w) => ({
                  ...w,
                  destinationAccount: maskAccount(w.destinationAccount),
                })),
              }
            : null,
        },
        referralCampaigns: {
          asAmbassador: campaignParticipations,
          asReferee: campaignReferrals,
          attributionSignals: referralSignals,
          prizes: prizeAwards,
          prizeForfeits,
        },
        campaignNotifications,
        community: communityMember
          ? {
              member: {
                memberId: communityMember.id,
                memberSince: communityMember.createdAt,
                charterVersion: communityMember.charterVersion,
                charterAcceptedAt: communityMember.charterAcceptedAt,
              },
              charterAcceptances: communityMember.charterAcceptances,
              posts: communityMember.posts.map(({ hashtags, ...post }) => ({
                ...post,
                hashtags: hashtags.map((h) => h.hashtag.tag),
              })),
              replies: communityMember.replies,
              helpfulReactions: communityMember.reactions,
              follows: communityMember.follows,
              blocks: communityMember.blocksMade,
              reportsFiled: communityMember.reportsFiled,
              sanctions: communityMember.sanctions,
            }
          : null,
        assistBridgeEvents,
        notifications,
      };
    });

    const portable = data
      ? this.toPortableObject(data)
      : { profile: this.demoProfile };
    return {
      exportedAt: new Date().toISOString(),
      note: 'Export of your KPB Education data. Uploaded document binaries and private storage keys are not embedded.',
      ...portable,
    };
  }

  private toPortableObject(value: unknown): Record<string, unknown> {
    return JSON.parse(
      JSON.stringify(value, (_key, current) =>
        typeof current === 'bigint' ? current.toString() : current,
      ),
    ) as Record<string, unknown>;
  }

  private analyticsActorKey(userId: string): string | null {
    const secret = process.env.KPB_ANALYTICS_ACTOR_SECRET?.trim();
    return secret
      ? createHmac('sha256', secret).update(userId).digest('hex')
      : null;
  }

  private mapDbProfile(p: UserProfile) {
    return {
      id: p.id,
      accountType: p.accountType,
      preferredLanguage: p.preferredLanguage,
      fullName: p.fullName,
      email: p.email,
      phone: p.phone,
      whatsApp: p.whatsApp,
      countryOfResidence: p.countryOfResidence,
      currentLevel: p.currentLevel,
      targetLevel: p.targetLevel,
      languageLevel: p.languageLevel,
      gradeRange: p.gradeRange,
      bacSeries: p.bacSeries,
      annualTuitionBudgetEur: p.annualTuitionBudgetEur,
      monthlyBudgetEur: p.monthlyBudgetEur,
      preferredCurrency: p.preferredCurrency,
      wantsScholarshipSupport: p.wantsScholarship,
      scholarshipNewsletterOptIn: p.newsletterOptIn,
      // Correctifs 57 : sa PRÉSENCE dit à l'app que ce serveur connaît aussi la
      // clé `kpb_promotions` (les lignes de préférence ne s'affichent qu'alors).
      promotionsEmailOptIn: p.promotionsEmailOptIn,
      // Chantier juridique 57 : sa PRÉSENCE dit à l'app que ce serveur exige
      // l'opt-in du push promotionnel (l'interrupteur ne s'affiche qu'alors).
      promotionsPushOptIn: p.promotionsPushOptIn,
      disabledNotificationTypes: sanitizeOptOutTypes(
        p.disabledNotificationTypes,
      ),
      // Legacy mirrors, derived — kept so a client built before KPB-169 still
      // renders the right switch state. Removed with the columns in KPB-174.
      dailyScholarshipOptOut: (p.disabledNotificationTypes ?? []).includes(
        'daily_scholarship',
      ),
      weeklyDigestOptOut: (p.disabledNotificationTypes ?? []).includes(
        'weekly_digest',
      ),
      fieldIds: p.fieldIds,
      targetCountryIds: p.targetCountryIds,
      availableDocuments: p.availableDocuments,
      // The storage key is deliberately NOT exposed — it would leak the internal
      // object layout. Clients get a boolean plus the authenticated endpoint.
      hasAvatar: Boolean(p.avatarStorageKey),
      avatarUrl: p.avatarStorageKey ? AVATAR_ENDPOINT_PATH : null,
      aiConsentedAt: p.aiConsentedAt ? p.aiConsentedAt.toISOString() : null,
      birthDate: p.birthDate ? p.birthDate.toISOString() : null,
      guardianName: p.guardianName,
      guardianContact: p.guardianContact,
      guardianConsentedAt: p.guardianConsentedAt
        ? p.guardianConsentedAt.toISOString()
        : null,
      // « Mes 10 bourses » (chantier D) — LECTURE SEULE ici : ces valeurs ne
      // s'écrivent que par POST /scholarships/match/runs, jamais par le PATCH
      // du profil complet. Les builds plus anciennes ignorent ces clés
      // (profile_api_codec.dart lit des clés explicites).
      nationalityCode: p.nationalityCode,
      secondNationalityCode: p.secondNationalityCode,
      highestDiploma: p.highestDiploma,
      scholarshipTargetLevel: p.scholarshipTargetLevel,
      gradeBandOn20: p.gradeBandOn20,
      englishLevel: p.englishLevel,
      frenchLevel: p.frenchLevel,
      languageTests: parseLanguageTests(p.languageTests),
      workExperienceBand: p.workExperienceBand,
      scholarshipProfileConfirmedAt: p.scholarshipProfileConfirmedAt
        ? p.scholarshipProfileConfirmedAt.toISOString()
        : null,
      scholarshipMatchAlertsOptIn: p.scholarshipMatchAlertsOptInAt !== null,
      updatedAt: p.updatedAt.toISOString(),
    };
  }
}
