import { Injectable, Logger } from '@nestjs/common';

/**
 * Sends campaign emails through Resend (same provider + fetch pattern as
 * MagicLinkMailService). Campaign sends are best-effort per recipient: a
 * failure is reported as `false` so the executor records an honest delivery
 * status instead of aborting the whole campaign.
 */
@Injectable()
export class CampaignMailService {
  private readonly logger = new Logger(CampaignMailService.name);

  /** Whether an email provider is configured at all. */
  get isEnabled(): boolean {
    return Boolean(process.env.RESEND_API_KEY?.trim());
  }

  async send(
    to: string,
    subject: string,
    text: string,
    options?: { replyTo?: string; headers?: Record<string, string> },
  ): Promise<boolean> {
    const resendKey = process.env.RESEND_API_KEY?.trim();
    if (!resendKey) return false;

    const from =
      process.env.KPB_CAMPAIGN_MAIL_FROM?.trim() ??
      process.env.KPB_MAGIC_LINK_FROM?.trim() ??
      'KPB Education <noreply@kpbeducation.cloud>';

    const replyTo = options?.replyTo?.trim();
    const payload: Record<string, unknown> = {
      from,
      to: [to],
      subject,
      text,
    };
    if (replyTo) payload.reply_to = replyTo;
    // En-têtes ajoutés (ex. `List-Unsubscribe` des e-mails promotionnels).
    if (options?.headers && Object.keys(options.headers).length > 0) {
      payload.headers = options.headers;
    }

    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
      if (!response.ok) {
        this.logger.error(
          `Campaign email provider failed with status ${response.status}.`,
        );
        return false;
      }
      return true;
    } catch {
      this.logger.error('Campaign email provider request failed.');
      return false;
    }
  }
}
