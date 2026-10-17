/**
 * Coarse roles mirrored from the backend InternalRole enum.
 *
 * This module is presentation-only: it may hide tabs and actions, but it must
 * never be used as an authorization boundary. The backend remains authoritative
 * for role, scope, assignment, purpose, separation-of-duties and audit checks.
 */
export enum InternalRole {
  Counselor = 'counselor',
  Commercial = 'commercial',
  ContentManager = 'content_manager',
  Moderator = 'moderator',
  Admin = 'admin',
  SuperAdmin = 'super_admin',
}

export enum AdminCapability {
  ViewReviewRequestMetadata = 'view_review_request_metadata',
  ViewAssignedReviewRequests = 'view_assigned_review_requests',
  ViewSharedReviewDocuments = 'view_shared_review_documents',
  AssignReviewRequests = 'assign_review_requests',
  TriageReviewRequests = 'triage_review_requests',
  ManageOwnAvailability = 'manage_own_availability',
  ManageCounsellorAvailability = 'manage_counsellor_availability',
  OfferReviewSlots = 'offer_review_slots',
  AdviseCaseConversion = 'advise_case_conversion',
  ConvertReviewToCase = 'convert_review_to_case',
  VerifyOutcomes = 'verify_outcomes',
  ViewScholarshipContent = 'view_scholarship_content',
  ManageScholarshipContent = 'manage_scholarship_content',
  ManagePartnerAgreements = 'manage_partner_agreements',
  ViewAssignedPilotCohorts = 'view_assigned_pilot_cohorts',
  RecruitPilotParticipants = 'recruit_pilot_participants',
  ViewPilotAggregates = 'view_pilot_aggregates',
  ManagePilots = 'manage_pilots',
  FreezeImpactSnapshots = 'freeze_impact_snapshots',
  ViewAiAggregateCosts = 'view_ai_aggregate_costs',
  ViewAiQualityAggregates = 'view_ai_quality_aggregates',
  ViewAiOperations = 'view_ai_operations',
  ManageAiBudget = 'manage_ai_budget',
  ManageAiPrompt = 'manage_ai_prompt',
  ManageFeatureFlags = 'manage_feature_flags',
  ExportPersonalData = 'export_personal_data',
  /**
   * Lire la liste d'intérêt « Études en France ».
   *
   * Distincte de [ExportPersonalData], et c'est le point : lire une page à
   * l'écran et faire sortir la table entière dans un fichier qui quitte le
   * périmètre ne sont pas le même acte. Le contrôleur backend applique
   * exactement la même distinction — cette capacité correspond à son `@Roles`
   * de classe, l'export à celui de sa méthode.
   */
  ViewInterestList = 'view_interest_list',
  /**
   * Créer et modifier les universités et les formations du catalogue.
   *
   * Miroir exact du `@Roles(Admin, SuperAdmin, ContentManager)` porté par
   * `AdminCatalogController`. Distincte de [ManageScholarshipContent] : ce
   * contrôleur-là gouverne les bourses, celui-ci le catalogue d'écoles. Les
   * confondre ferait dériver l'un quand l'autre change de périmètre.
   */
  ManageCatalogContent = 'manage_catalog_content',
  /**
   * Publier ou retirer un établissement de l'import « Études en France » et ses
   * formations.
   *
   * Miroir exact du `@Roles(Admin, SuperAdmin)` de `EefPublicationController`.
   * PAS `ContentManager` : il édite le catalogue mais ne signe pas sa
   * publication, qui rend visibles à un étudiant sans compte des fiches que
   * personne n'avait relues. Distincte de [ManageCatalogContent], et c'est le
   * point : élargir l'une ne doit jamais élargir l'autre.
   */
  PublishEefCatalog = 'publish_eef_catalog',
  /**
   * Annoncer l'ouverture d'une bourse à PLUS de `confirmThreshold` (500)
   * étudiants.
   *
   * Miroir de `OPENING_SEND_ROLES` (Admin, SuperAdmin) dans
   * `backend/…/opening/scholarship-opening.contract.ts`, que `activate` fait
   * respecter par un 403 `OPENING_REQUIRES_ADMIN`. PAS `ContentManager` : il
   * ouvre les cycles et annonce en dessous du seuil, mais un envoi massif
   * engage la relation avec des milliers d'étudiants. Présentation seulement :
   * elle désactive le bouton, le serveur reste seul juge.
   */
  SendLargeScholarshipOpening = 'send_large_scholarship_opening',
  /**
   * Suivre la compétition ambassadeurs (campagnes, classement, filleuls).
   *
   * Miroir du `@Roles(Admin, SuperAdmin, Commercial)` de classe de
   * `AdminReferralCampaignsController` : l'équipe qui recrute les ambassadeurs
   * suit le classement.
   */
  ViewReferralCampaigns = 'view_referral_campaigns',
  /**
   * Créer, lancer, geler, clore une campagne ; activer un ambassadeur ;
   * exclure ou valider un filleul ; valider le podium ; noter un versement ;
   * exporter. Miroir des `@Roles(Admin, SuperAdmin)` de méthode du même
   * contrôleur. Présentation seulement : le serveur reste seul juge.
   */
  ManageReferralCampaigns = 'manage_referral_campaigns',
}

const ALL_ROLES = Object.freeze([
  InternalRole.Counselor,
  InternalRole.Commercial,
  InternalRole.ContentManager,
  InternalRole.Moderator,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
] as const);

const ROLE_CAPABILITIES = {
  [InternalRole.Counselor]: Object.freeze([
    AdminCapability.ViewInterestList,
    AdminCapability.ViewReviewRequestMetadata,
    AdminCapability.ViewAssignedReviewRequests,
    AdminCapability.ViewSharedReviewDocuments,
    AdminCapability.TriageReviewRequests,
    AdminCapability.ManageOwnAvailability,
    AdminCapability.OfferReviewSlots,
    AdminCapability.AdviseCaseConversion,
    AdminCapability.ViewScholarshipContent,
    AdminCapability.ViewAssignedPilotCohorts,
    AdminCapability.ViewAiAggregateCosts,
  ]),
  [InternalRole.Commercial]: Object.freeze([
    AdminCapability.ViewReferralCampaigns,
    AdminCapability.ViewInterestList,
    AdminCapability.ViewReviewRequestMetadata,
    AdminCapability.ConvertReviewToCase,
    AdminCapability.ViewScholarshipContent,
    AdminCapability.ManagePartnerAgreements,
    AdminCapability.RecruitPilotParticipants,
  ]),
  [InternalRole.ContentManager]: Object.freeze([
    AdminCapability.ViewScholarshipContent,
    AdminCapability.ManageScholarshipContent,
    AdminCapability.ManageCatalogContent,
  ]),
  [InternalRole.Moderator]: Object.freeze([
    AdminCapability.VerifyOutcomes,
    AdminCapability.ViewScholarshipContent,
    AdminCapability.ViewPilotAggregates,
    AdminCapability.ViewAiQualityAggregates,
  ]),
  [InternalRole.Admin]: Object.freeze([
    AdminCapability.ViewInterestList,
    AdminCapability.ViewReviewRequestMetadata,
    AdminCapability.ViewAssignedReviewRequests,
    AdminCapability.ViewSharedReviewDocuments,
    AdminCapability.AssignReviewRequests,
    AdminCapability.TriageReviewRequests,
    AdminCapability.ManageCounsellorAvailability,
    AdminCapability.OfferReviewSlots,
    AdminCapability.AdviseCaseConversion,
    AdminCapability.ConvertReviewToCase,
    AdminCapability.VerifyOutcomes,
    AdminCapability.ViewScholarshipContent,
    AdminCapability.ManageScholarshipContent,
    AdminCapability.ManageCatalogContent,
    AdminCapability.PublishEefCatalog,
    AdminCapability.SendLargeScholarshipOpening,
    AdminCapability.ManagePartnerAgreements,
    AdminCapability.ViewAssignedPilotCohorts,
    AdminCapability.RecruitPilotParticipants,
    AdminCapability.ViewPilotAggregates,
    AdminCapability.ManagePilots,
    AdminCapability.FreezeImpactSnapshots,
    AdminCapability.ViewAiAggregateCosts,
    AdminCapability.ViewAiQualityAggregates,
    AdminCapability.ViewAiOperations,
    AdminCapability.ExportPersonalData,
    AdminCapability.ViewReferralCampaigns,
    AdminCapability.ManageReferralCampaigns,
  ]),
  [InternalRole.SuperAdmin]: Object.freeze(
    Object.values(AdminCapability),
  ),
} satisfies Record<InternalRole, readonly AdminCapability[]>;

const NO_CAPABILITIES = Object.freeze([]) as readonly AdminCapability[];

export function isInternalRole(role: string | null | undefined): role is InternalRole {
  return role !== null && role !== undefined && ALL_ROLES.includes(role as InternalRole);
}

/**
 * Returns coarse UI capabilities only. A positive result does not authorize an
 * API call and does not imply access to a country, cohort, case or document.
 */
export function getAdminCapabilities(
  role: string | null | undefined,
): readonly AdminCapability[] {
  return isInternalRole(role) ? ROLE_CAPABILITIES[role] : NO_CAPABILITIES;
}

/**
 * Safe for rendering decisions only. The backend must still reject every
 * unauthorized request independently of what the UI displays.
 */
export function hasAdminCapability(
  role: string | null | undefined,
  capability: AdminCapability,
): boolean {
  return getAdminCapabilities(role).includes(capability);
}
