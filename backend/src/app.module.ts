import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { APP_GUARD, APP_INTERCEPTOR, Reflector } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

import { AdminUsersController } from './modules/admin-users/admin-users.controller';
import { AdminUsersService } from './modules/admin-users/admin-users.service';
import { AuthController } from './modules/auth/auth.controller';
import { AuthService } from './modules/auth/auth.service';
import { SupabaseAuthService } from './modules/auth/supabase-auth.service';
import { CatalogController } from './modules/catalog/catalog.controller';
import { CatalogService } from './modules/catalog/catalog.service';
import { CountriesModule } from './modules/countries/countries.module';
import { CompetitionReadinessModule } from './modules/competition-readiness/competition-readiness.module';
import { AdminCompetitionReadinessController } from './modules/competition-readiness/admin/admin-competition-readiness.controller';
import { AppointmentsController } from './modules/appointments/appointments.controller';
import { AppointmentsService } from './modules/appointments/appointments.service';
import { AdminAuthGuard } from './common/guards/admin-auth.guard';
import { StudentAuthGuard } from './common/guards/student-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { buildThrottlerOptions } from './common/throttler-options';
import { AdminCasesController } from './modules/cases/admin-cases.controller';
import { CasesController } from './modules/cases/cases.controller';
import { CaseLeadMailService } from './modules/cases/case-lead-mail.service';
import { CasesService } from './modules/cases/cases.service';
import { CaseMessagingGateway } from './modules/cases/case-messaging.gateway';
import { CaseReassignmentCronService } from './modules/cases/case-reassignment-cron.service';
import { CommunityController } from './modules/community/community.controller';
import { CommunityService } from './modules/community/community.service';
import { ContentController } from './modules/content/content.controller';
import { ContentService } from './modules/content/content.service';
import { ParcoursController } from './modules/parcours/parcours.controller';
import { ParcoursService } from './modules/parcours/parcours.service';
import { ParcoursWeeklyService } from './modules/parcours/parcours-weekly.service';
import { AppConfigController } from './modules/config/app-config.controller';
import { EefSearchController } from './modules/etudes-en-france/search/eef-search.controller';
import { EefSearchService } from './modules/etudes-en-france/search/eef-search.service';
import { EefShortlistController } from './modules/etudes-en-france/shortlist/eef-shortlist.controller';
import { EefShortlistService } from './modules/etudes-en-france/shortlist/eef-shortlist.service';
import { EtudesEnFranceController } from './modules/etudes-en-france/etudes-en-france.controller';
import { EtudesEnFranceService } from './modules/etudes-en-france/etudes-en-france.service';
import { AdminEefInterestController } from './modules/etudes-en-france/admin-eef-interest.controller';
import { AdminEefInterestService } from './modules/etudes-en-france/admin-eef-interest.service';
import { EefPublicationController } from './modules/etudes-en-france/publication/eef-publication.controller';
import { EefPublicationService } from './modules/etudes-en-france/publication/eef-publication.service';
import { PremiumWaitlistController } from './modules/premium/premium-waitlist.controller';
import { PremiumWaitlistService } from './modules/premium/premium-waitlist.service';
import { AdminPremiumWaitlistController } from './modules/premium/admin-premium-waitlist.controller';
import { AdminPremiumWaitlistService } from './modules/premium/admin-premium-waitlist.service';
import { HealthController } from './modules/health/health.controller';
import { NotificationsController } from './modules/notifications/notifications.controller';
import { NotificationsService } from './modules/notifications/notifications.service';
import { OneSignalSenderService } from './modules/notifications/onesignal-sender.service';
import { FcmSenderService } from './modules/notifications/fcm-sender.service';
import { PushSenderService } from './modules/notifications/push-sender.service';
import { PushOpensController } from './modules/notifications/push-opens.controller';
import { CampaignExecutorService } from './modules/notifications/campaign-executor.service';
import { CampaignMailService } from './modules/notifications/campaign-mail.service';
import { CampaignCronService } from './modules/notifications/campaign-cron.service';
import { NotificationDispatchService } from './modules/notifications/notification-dispatch.service';
import { WeeklyDigestService } from './modules/notifications/weekly-digest.service';
import { MilestoneReminderService } from './modules/notifications/milestone-reminder.service';
import { PushOutboxWorkerService } from './modules/notifications/push-outbox-worker.service';
import { ProfileNudgeCronService } from './modules/notifications/profile-nudge-cron.service';
import { SalonReminderCronService } from './modules/notifications/salon-reminder-cron.service';
import { MauticService } from './modules/newsletter/mautic.service';
import { NewsletterSyncService } from './modules/newsletter/newsletter-sync.service';
import { NewsletterSyncCronService } from './modules/newsletter/newsletter-sync-cron.service';
import { DeviceTokensController } from './modules/notifications/device-tokens.controller';
import { AdminPushController } from './modules/notifications/admin-push.controller';
import { CoachController } from './modules/coach/coach.controller';
import { CoachQuotaService } from './modules/coach/coach-quota.service';
import { CoachService } from './modules/coach/coach.service';
import { DocumentReviewController } from './modules/document-review/document-review.controller';
import { DocumentReviewService } from './modules/document-review/document-review.service';
import { CommercialController } from './modules/commercial/commercial.controller';
import { CommercialService } from './modules/commercial/commercial.service';
import { AdminDashboardController } from './modules/admin-dashboard/admin-dashboard.controller';
import { AdminDashboardService } from './modules/admin-dashboard/admin-dashboard.service';
import { AdminAppBuildsController } from './modules/app-builds/admin-app-builds.controller';
import { AdminAppBuildsService } from './modules/app-builds/admin-app-builds.service';
import { AppBuildInterceptor } from './modules/app-builds/app-build.interceptor';
import { AppBuildTrackerService } from './modules/app-builds/app-build-tracker.service';
import { AdminCatalogController } from './modules/admin-catalog/admin-catalog.controller';
import { AdminCatalogService } from './modules/admin-catalog/admin-catalog.service';
import { ImpactController } from './modules/impact/impact.controller';
import { ImpactService } from './modules/impact/impact.service';
import { ToolsController } from './modules/tools/tools.controller';
import { ToolsService } from './modules/tools/tools.service';
import { YoutubeController } from './modules/content-youtube/youtube.controller';
import { YoutubeService } from './modules/content-youtube/youtube.service';
import { KayakController } from './modules/kayak/kayak.controller';
import { KayakService } from './modules/kayak/kayak.service';
import { MatchesController } from './modules/matches/matches.controller';
import { MatchesService } from './modules/matches/matches.service';
import { MatchRecomputeService } from './modules/matches/match-recompute.service';
import { AiConsentGuard } from './modules/ai/ai-consent.guard';
import { AiConsentService } from './modules/ai/ai-consent.service';
import { AiQuotaGuard } from './modules/ai/ai-quota.guard';
import { AiQuotaService } from './modules/ai/ai-quota.service';
import { LlmService } from './modules/ai/llm.service';
import { OrientationController } from './modules/orientation/orientation.controller';
import { OrientationService } from './modules/orientation/orientation.service';
import { PartnerLeadsController } from './modules/partner-leads/partner-leads.controller';
import { PartnerLeadsService } from './modules/partner-leads/partner-leads.service';
import { ProfilesController } from './modules/profiles/profiles.controller';
import { ProfilesService } from './modules/profiles/profiles.service';
import { PrismaService } from './modules/prisma/prisma.service';
import { ReportsController } from './modules/reports/reports.controller';
import { ReportsService } from './modules/reports/reports.service';
import { SavedItemsController } from './modules/saved-items/saved-items.controller';
import { SavedItemsService } from './modules/saved-items/saved-items.service';
import { AntivirusService } from './modules/storage/antivirus.service';
import { StorageService } from './modules/storage/storage.service';
import {
  AdminCounsellorsController,
  CounsellorsController,
} from './modules/counsellors/counsellors.controller';
import { CounsellorsService } from './modules/counsellors/counsellors.service';
// NOTE: PaymentsController/AdminPaymentsController are intentionally NOT
// registered — the launch is WhatsApp-advisor only (no in-app checkout), and an
// unauthenticated payment webhook is a needless attack surface. PaymentsService
// stays a provider because ServicePackagesService injects it.
import { PaymentsService } from './modules/payments/payments.service';
import { CinetpayAdapter } from './modules/payments/cinetpay.adapter';
import { PaydunyaAdapter } from './modules/payments/paydunya.adapter';
import { ParentLinksController } from './modules/parent-links/parent-links.controller';
import { ParentLinksService } from './modules/parent-links/parent-links.service';
import { ReferralCreditsReconcileCronService } from './modules/referrals/referral-credits-reconcile-cron.service';
import { ReferralCreditsService } from './modules/referrals/referral-credits.service';
import { ReferralsController } from './modules/referrals/referrals.controller';
import { ReferralsService } from './modules/referrals/referrals.service';
import { AmbassadorController } from './modules/referrals/ambassador.controller';
import { AmbassadorService } from './modules/referrals/ambassador.service';
import { AdminScholarshipsController, ScholarshipsController } from './modules/scholarships-index/admin-scholarships.controller';
import { ScholarshipsIndexService } from './modules/scholarships-index/scholarships-index.service';
import { DailyScholarshipService } from './modules/scholarships-index/daily-scholarship.service';
import { ScholarshipAlertsController } from './modules/scholarships-index/scholarship-alerts.controller';
import { ScholarshipAlertsService } from './modules/scholarships-index/scholarship-alerts.service';
import { ScholarshipLifecycleService } from './modules/scholarships-index/scholarship-lifecycle.service';
import { ScholarshipContentQualityService } from './modules/scholarships-index/scholarship-content-quality.service';
import { ScholarshipVideosService } from './modules/scholarships-index/scholarship-videos.service';
import { UserNotificationsController } from './modules/scholarships-index/user-notifications.controller';
import { UserNotificationsService } from './modules/scholarships-index/user-notifications.service';
import { FollowedScholarshipsController } from './modules/scholarships-index/followed-scholarships.controller';
import { FollowedScholarshipsService } from './modules/scholarships-index/followed-scholarships.service';
import { AdminScholarshipOpeningController } from './modules/scholarships-index/opening/admin-scholarship-opening.controller';
import { ScholarshipOpeningAdminService } from './modules/scholarships-index/opening/scholarship-opening-admin.service';
import { ScholarshipOpeningAudienceService } from './modules/scholarships-index/opening/scholarship-opening-audience.service';
import { ScholarshipOpeningFanoutService } from './modules/scholarships-index/opening/scholarship-opening-fanout.service';
import { CandidateSnapshotService } from './modules/scholarship-match/candidate-snapshot';
import { ScholarshipMatchController } from './modules/scholarship-match/scholarship-match.controller';
import { ScholarshipMatchEnabledGuard } from './modules/scholarship-match/scholarship-match.feature';
import { ScholarshipMatchService } from './modules/scholarship-match/scholarship-match.service';
import { GreatYopScraper } from './modules/scholarships-index/scrapers/greatyop.scraper';
import { MastereTnScraper } from './modules/scholarships-index/scrapers/mastereTn.scraper';
import { VisaAvailabilityController } from './modules/visa-availability/visa-availability.controller';
import { VisaAvailabilityService } from './modules/visa-availability/visa-availability.service';
import {
  AdminServicePackagesController,
  MyPurchasesController,
  ServicePackagesController,
} from './modules/service-packages/service-packages.controller';
import { ServicePackagesService } from './modules/service-packages/service-packages.service';
import {
  AdminAlumniController,
  AlumniController,
  MyAlumniController,
} from './modules/alumni/alumni.controller';
import { AlumniService } from './modules/alumni/alumni.service';
import {
  AdminPartnersController,
  PartnersController,
} from './modules/partners/partners.controller';
import { PartnersService } from './modules/partners/partners.service';
import {
  AdminSalonController,
  MySalonController,
  SalonController,
} from './modules/salon/salon.controller';
import { SalonService } from './modules/salon/salon.service';


@Module({
  imports: [
    JwtModule.register({
      global: true,
      secret: process.env.KPB_JWT_SECRET ?? (() => {
        if (process.env.NODE_ENV === 'production') {
          throw new Error('KPB_JWT_SECRET must be set in production');
        }
        return 'kpb-student-jwt-secret-local-dev';
      })(),
      signOptions: { expiresIn: '1h' },
    }),
    // Un seul limiteur, par construction : tout limiteur déclaré ici s'applique à
    // TOUTES les routes (voir `throttler-options.ts`).
    ThrottlerModule.forRoot(buildThrottlerOptions()),
    ScheduleModule.forRoot(),
    CountriesModule,
    CompetitionReadinessModule,
  ],
  controllers: [
    AuthController,
    AdminCasesController,
    AdminCompetitionReadinessController,
    AdminUsersController,
    CatalogController,
    AppointmentsController,
    CasesController,
    CommunityController,
    ContentController,
    ParcoursController,
    DeviceTokensController,
    PushOpensController,
    AdminPushController,
    DocumentReviewController,
    AppConfigController,
    EtudesEnFranceController,
    EefSearchController,
    EefShortlistController,
    AdminEefInterestController,
    EefPublicationController,
    PremiumWaitlistController,
    AdminPremiumWaitlistController,
    HealthController,
    NotificationsController,
    OrientationController,
    CoachController,
    CommercialController,
    AdminDashboardController,
    AdminAppBuildsController,
    AdminCatalogController,
    ImpactController,
    ToolsController,
    YoutubeController,
    KayakController,
    MatchesController,
    PartnerLeadsController,
    ProfilesController,
    ReportsController,
    SavedItemsController,
    CounsellorsController,
    AdminCounsellorsController,
    ParentLinksController,
    ReferralsController,
    AmbassadorController,
    // Annonce d'ouverture (chantier C). Déclaré AVANT AdminScholarshipsController :
    // ses routes à segment fixe (`opening-todo`, `opening-overview`) ne doivent
    // jamais être lues comme un `:id` de bourse.
    AdminScholarshipOpeningController,
    AdminScholarshipsController,
    ScholarshipsController,
    ScholarshipAlertsController,
    UserNotificationsController,
    FollowedScholarshipsController,
    // « Mes 10 bourses » (chantier D) : `scholarships/match/*`, deux segments
    // au moins, jamais capturés par `GET /scholarships/:id`.
    ScholarshipMatchController,
    VisaAvailabilityController,
    ServicePackagesController,
    MyPurchasesController,
    AdminServicePackagesController,
    AlumniController,
    MyAlumniController,
    AdminAlumniController,
    PartnersController,
    AdminPartnersController,
    SalonController,
    MySalonController,
    AdminSalonController,
  ],
  providers: [
    Reflector,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Note la build de l'app (en-têtes X-KPB-App-*) des requêtes élève
    // authentifiées ; ne touche ni à la requête ni à la réponse.
    { provide: APP_INTERCEPTOR, useClass: AppBuildInterceptor },
    AdminAuthGuard,
    StudentAuthGuard,
    RolesGuard,
    AdminUsersService,
    AuthService,
    SupabaseAuthService,
    AppointmentsService,
    CaseLeadMailService,
    CasesService,
    CaseMessagingGateway,
    CaseReassignmentCronService,
    CatalogService,
    CommunityService,
    ContentService,
    ParcoursService,
    ParcoursWeeklyService,
    OneSignalSenderService,
    FcmSenderService,
    PushSenderService,
    CampaignExecutorService,
    CampaignMailService,
    CampaignCronService,
    NotificationDispatchService,
    WeeklyDigestService,
    MilestoneReminderService,
    ProfileNudgeCronService,
    SalonReminderCronService,
    MauticService,
    NewsletterSyncService,
    NewsletterSyncCronService,
    NotificationsService,
    OrientationService,
    LlmService,
    AiConsentService,
    AiConsentGuard,
    AiQuotaService,
    AiQuotaGuard,
    DocumentReviewService,
    CoachService,
    CoachQuotaService,
    CommercialService,
    AdminDashboardService,
    AdminAppBuildsService,
    AppBuildTrackerService,
    AdminCatalogService,
    ImpactService,
    ToolsService,
    YoutubeService,
    KayakService,
    MatchesService,
    MatchRecomputeService,
    PartnerLeadsService,
    ProfilesService,
    PrismaService,
    ReportsService,
    SavedItemsService,
    AntivirusService,
    StorageService,
    CounsellorsService,
    PaymentsService,
    CinetpayAdapter,
    PaydunyaAdapter,
    ParentLinksService,
    ReferralsService,
    EtudesEnFranceService,
    EefSearchService,
    EefShortlistService,
    AdminEefInterestService,
    EefPublicationService,
    PremiumWaitlistService,
    AdminPremiumWaitlistService,
    AmbassadorService,
    ReferralCreditsService,
    ReferralCreditsReconcileCronService,
    ScholarshipsIndexService,
    DailyScholarshipService,
    ScholarshipAlertsService,
    ScholarshipLifecycleService,
    ScholarshipContentQualityService,
    ScholarshipVideosService,
    UserNotificationsService,
    // Annonce d'ouverture d'une bourse suivie (chantier C).
    ScholarshipOpeningAdminService,
    ScholarshipOpeningAudienceService,
    ScholarshipOpeningFanoutService,
    PushOutboxWorkerService,
    FollowedScholarshipsService,
    // « Mes 10 bourses » (chantier D).
    CandidateSnapshotService,
    ScholarshipMatchService,
    ScholarshipMatchEnabledGuard,
    GreatYopScraper,
    MastereTnScraper,
    VisaAvailabilityService,
    ServicePackagesService,
    AlumniService,
    PartnersService,
    SalonService,
  ],
})
export class AppModule {}
