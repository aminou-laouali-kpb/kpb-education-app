import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { MilestoneReminderService } from './milestone-reminder.service';
import { PushSenderService } from './push-sender.service';

interface TestPushDto {
  userId: string;
  title?: string;
  body?: string;
  route?: string;
}

@Controller('admin/push')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class AdminPushController {
  constructor(
    private readonly sender: PushSenderService,
    private readonly reminders: MilestoneReminderService,
  ) {}

  /// Run the deadline / milestone pass on demand (test the pipeline without
  /// waiting for the 08:00 cron). KPB-173: this used to call a second, parallel
  /// reminder service that pushed directly — bypassing the durable feed, the
  /// dedup, the quiet hours and the daily cap. It now runs the same code as the
  /// cron, so a manual trigger can no longer produce a send the scheduled path
  /// would not have produced. Re-running the same day returns `deduped`.
  @Post('deadline-reminders')
  runDeadlineReminders() {
    return this.reminders.handleDailyMilestoneReminders();
  }

  /**
   * Fire a test push to a single user (by KPB user id). Goes through the same
   * router as every other send: FCM when the user has a registered device,
   * OneSignal otherwise (app versions not yet updated).
   *
   * KPB-173: intentionally direct — this is a diagnostic ping for one known
   * account, not a user-facing reminder. Routing it through the dispatcher
   * would write a fake entry into that person's durable feed and consume their
   * daily cap, which is exactly what a probe must not do.
   */
  @Post('test')
  async sendTest(@Body() dto: TestPushDto) {
    if (!dto?.userId) {
      return { ok: false, reason: 'userId is required' };
    }
    if (!this.sender.isConfigured) {
      return {
        ok: false,
        reason:
          'Push not configured — set FCM_SERVICE_ACCOUNT_JSON (or, during the ' +
          'transition, ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY).',
      };
    }

    // Le booléen était jeté et la sonde rendait `ok: true` quoi qu'il arrive.
    // Un diagnostic qui ne peut pas échouer ne diagnostique rien : pendant les
    // envois refusés par OneSignal du 04/09/2026, ce bouton aurait répondu
    // « envoyé ✅ ». C'est le seul outil dont dispose l'exploitant pour tester
    // la chaîne — il doit dire la vérité, et dire où regarder quand il échoue.
    const outcome = await this.sender.send(
      dto.userId,
      dto.title?.trim() || 'Test KPB Education',
      dto.body?.trim() || 'Ceci est une notification de test 🎓',
      dto.route ? { route: dto.route } : undefined,
    );

    if (!outcome.delivered) {
      return {
        ok: false,
        sentTo: dto.userId,
        via: outcome.via,
        reason:
          outcome.via === 'fcm'
            ? "FCM n'a livré à aucun appareil. Causes possibles : compte de " +
              'service invalide, clé APNs absente du projet Firebase (iOS), ' +
              'ou jeton refusé. Le motif exact est dans les journaux du ' +
              'conteneur api.'
            : "Aucun appareil joignable. Causes possibles : cet utilisateur " +
              "n'a pas d'appareil enregistré (notifications refusées, ou " +
              "jamais connecté depuis l'installation de la nouvelle version), " +
              'ni d\'abonnement OneSignal actif. Le motif exact est dans les ' +
              'journaux du conteneur api.',
      };
    }

    return { ok: true, sentTo: dto.userId, via: outcome.via };
  }
}
