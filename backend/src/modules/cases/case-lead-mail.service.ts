import { Injectable, Logger } from '@nestjs/common';

import { CampaignMailService } from '../notifications/campaign-mail.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Contact sheet emailed to Jojo and Richard when a student submits a
 * dossier. One message per address. The address is the counsellor row's
 * current email when that row is active, otherwise the address stored with
 * the commercial seed. An inactive row is skipped.
 *
 * Marketplace counsellors are not included. Trust-and-safety reports reuse
 * case creation and are not sales leads. A mail failure must not reject the
 * student's submission.
 */
const DESCRIPTION_LIMIT = 1500;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const COMMERCIAL_LEAD_RECIPIENTS = [
  {
    id: 'counsellor-jojo',
    email: 'josphandieuaimeagbessi@gmail.com',
  },
  {
    id: 'counsellor-richard',
    email: 'richardahogle@gmail.com',
  },
] as const;

const CASE_TYPE_LABELS: Record<string, string> = {
  consultation: 'Consultation',
  application_support: 'Inscription école',
  scholarship_support: 'Bourse',
  housing_support: 'Logement',
  mentorship: 'Mentorat',
};

const CONTACT_METHOD_LABELS: Record<string, string> = {
  in_app: "Dans l'application",
  whatsapp: 'WhatsApp',
  phone: 'Téléphone',
  email: 'E-mail',
};

const ACCOUNT_TYPE_LABELS: Record<string, string> = {
  student: 'Étudiant',
  parent: 'Parent',
  partner: 'Partenaire',
};

const LANGUAGE_LABELS: Record<string, string> = {
  fr: 'Français',
  en: 'Anglais',
};

export interface CaseLeadUser {
  fullName?: string | null;
  email?: string | null;
  phone?: string | null;
  whatsApp?: string | null;
  countryOfResidence?: string | null;
  preferredLanguage?: string | null;
  currentLevel?: string | null;
  targetLevel?: string | null;
  accountType?: string | null;
  guardianName?: string | null;
  guardianContact?: string | null;
}

export interface CaseLeadRecord {
  id?: string;
  referenceCode?: string | null;
  type?: string | null;
  title?: string | null;
  description?: string | null;
  contextLabel?: string | null;
  preferredContactMethod?: string | null;
  assignedAdvisorName?: string | null;
  createdAt?: Date | string | null;
  user?: CaseLeadUser | null;
}

export interface CaseMessageAlertRecord {
  id?: string;
  referenceCode?: string | null;
  title?: string | null;
  assignedAdvisorName?: string | null;
  user?: { fullName?: string | null; email?: string | null } | null;
  counsellor?: { email?: string | null; isActive?: boolean | null } | null;
}

@Injectable()
export class CaseLeadMailService {
  private readonly logger = new Logger(CaseLeadMailService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: CampaignMailService,
  ) {}

  async notifyNewCase(record: CaseLeadRecord): Promise<void> {
    if (isInternalReport(record)) return;
    if (!this.mail.isEnabled) {
      this.logger.warn(
        'Commercial lead email skipped: email provider is not configured.',
      );
      return;
    }

    const recipients = await this.recipients();
    if (recipients.length === 0) {
      this.logger.warn(
        `Commercial lead email skipped for case ${record.id ?? 'unknown'}: no active commercial address.`,
      );
      return;
    }

    const studentEmail = validEmail(record.user?.email);
    const subject = leadSubject(record);
    const text = leadBody(record);
    const results = await Promise.all(
      recipients.map(async (to) => {
        try {
          return await this.mail.send(to, subject, text, {
            replyTo: studentEmail ?? undefined,
          });
        } catch {
          return false;
        }
      }),
    );
    const delivered = results.filter(Boolean).length;
    if (delivered !== recipients.length) {
      this.logger.warn(
        `Commercial lead email delivered to ${delivered}/${recipients.length} for case ${record.id ?? 'unknown'}.`,
      );
    }
  }

  /**
   * Un élève a écrit dans son dossier. Le conseiller attribué reçoit l'alerte
   * (adresse de sa fiche, si elle est active) ; sans conseiller, les
   * commerciaux. Le texte ne reprend PAS le message : on le lit dans l'admin,
   * pas dans une boîte mail.
   */
  async notifyStudentMessage(record: CaseMessageAlertRecord): Promise<void> {
    if (!this.mail.isEnabled) return;
    const advisor =
      record.counsellor?.isActive !== false
        ? validEmail(record.counsellor?.email)
        : null;
    const recipients = advisor ? [advisor] : await this.recipients();
    if (recipients.length === 0) return;
    const reference = oneLine(record.referenceCode, 40) || 'dossier';
    const name = oneLine(record.user?.fullName, 80) || 'Un étudiant';
    const subject = `Nouveau message — ${reference} — ${name}`;
    const text = [
      `${name} a écrit dans son dossier ${reference}.`,
      `Suivi attribué à : ${oneLine(record.assignedAdvisorName, 120) || 'aucun conseiller'}.`,
      '',
      "Ouvrez l'administration KPB, rubrique Dossiers, pour lire le message et répondre.",
      "La réponse arrive dans l'application de l'étudiant, avec une notification.",
    ].join('\n');
    await Promise.all(
      recipients.map(async (to) => {
        try {
          await this.mail.send(to, subject, text, {
            replyTo: undefined,
          });
        } catch {
          this.logger.warn(
            `Message alert email failed for case ${record.id ?? 'unknown'}.`,
          );
        }
      }),
    );
  }

  private async recipients(): Promise<string[]> {
    const rows = await this.prisma.tryExecute((prisma) =>
      prisma.counsellor.findMany({
        where: {
          OR: [
            { id: { in: COMMERCIAL_LEAD_RECIPIENTS.map((item) => item.id) } },
            {
              email: {
                in: COMMERCIAL_LEAD_RECIPIENTS.map((item) => item.email),
                mode: 'insensitive',
              },
            },
          ],
        },
        select: { id: true, email: true, isActive: true },
      }),
    );

    const seen = new Set<string>();
    const addresses: string[] = [];
    for (const person of COMMERCIAL_LEAD_RECIPIENTS) {
      const row = (rows ?? []).find(
        (item) =>
          item.id === person.id ||
          item.email.toLowerCase() === person.email.toLowerCase(),
      );
      if (row && !row.isActive) continue;
      const email = validEmail(row?.email) ?? person.email;
      const key = email.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      addresses.push(email);
    }
    return addresses;
  }
}

export function isInternalReport(record: CaseLeadRecord): boolean {
  const description = record.description ?? '';
  const title = record.title ?? '';
  const context = record.contextLabel ?? '';
  return (
    description.startsWith('TRUST_AND_SAFETY_REPORT') ||
    title.startsWith('AI content report') ||
    context.startsWith('Trust & Safety')
  );
}

function validEmail(value: string | null | undefined): string | null {
  const email = value?.trim() ?? '';
  if (!email || email.length > 320 || !EMAIL_PATTERN.test(email)) return null;
  return email;
}

function leadSubject(record: CaseLeadRecord): string {
  const reference = oneLine(record.referenceCode, 40) || 'nouveau dossier';
  const name = oneLine(record.user?.fullName, 80) || 'étudiant';
  return `Nouveau dossier ${reference} — ${name}`;
}

function leadBody(record: CaseLeadRecord): string {
  const user = record.user;
  const advisor =
    oneLine(record.assignedAdvisorName, 120) || 'Aucun conseiller attribué';
  const lines = [
    'Un étudiant vient de déposer une demande de dossier.',
    `Suivi attribué à : ${advisor}.`,
    "Un seul commercial doit rappeler, pour ne pas contacter l'étudiant plusieurs fois.",
    '',
    'Dossier',
    `Référence : ${shown(record.referenceCode)}`,
    `Type : ${label(CASE_TYPE_LABELS, record.type)}`,
    `Titre : ${shown(record.title)}`,
    `Contexte : ${shown(record.contextLabel)}`,
    `Contact préféré : ${label(CONTACT_METHOD_LABELS, record.preferredContactMethod)}`,
    `Déposé le : ${formatWhen(record.createdAt)}`,
    '',
    'Coordonnées',
    `Nom : ${shown(user?.fullName)}`,
    `E-mail : ${shown(user?.email)}`,
    `Téléphone : ${shown(user?.phone)}`,
    `WhatsApp : ${shown(user?.whatsApp)}`,
    `Pays de résidence : ${shown(user?.countryOfResidence)}`,
    `Langue : ${label(LANGUAGE_LABELS, user?.preferredLanguage)}`,
    `Niveau actuel : ${shown(user?.currentLevel)}`,
    `Niveau visé : ${shown(user?.targetLevel)}`,
    `Type de compte : ${label(ACCOUNT_TYPE_LABELS, user?.accountType)}`,
  ];
  const guardianName = oneLine(user?.guardianName, 160);
  const guardianContact = oneLine(user?.guardianContact, 160);
  if (guardianName || guardianContact) {
    lines.push(`Responsable légal : ${guardianName || 'Non renseigné'}`);
    lines.push(
      `Contact du responsable : ${guardianContact || 'Non renseigné'}`,
    );
  }
  lines.push('', "Message de l'étudiant", clip(record.description));
  if (validEmail(user?.email)) {
    lines.push('', "Répondre à cet e-mail écrit directement à l'étudiant.");
  }
  return lines.join('\n');
}

function shown(value: string | null | undefined): string {
  return oneLine(value, 200) || 'Non renseigné';
}

function label(
  labels: Record<string, string>,
  value: string | null | undefined,
): string {
  const key = value?.trim() ?? '';
  if (!key) return 'Non renseigné';
  return labels[key] ?? oneLine(key, 80);
}

function oneLine(value: string | null | undefined, max: number): string {
  if (!value) return '';
  return value.replace(/[\r\n\t]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
}

function clip(value: string | null | undefined): string {
  const cleaned = (value ?? '')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, ' ')
    .trim();
  if (!cleaned) return 'Non renseigné';
  if (cleaned.length <= DESCRIPTION_LIMIT) return cleaned;
  return `${cleaned.slice(0, DESCRIPTION_LIMIT - 1)}…`;
}

function formatWhen(value: Date | string | null | undefined): string {
  const date = value instanceof Date ? value : value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return 'Non renseigné';
  try {
    const formatted = new Intl.DateTimeFormat('fr-FR', {
      dateStyle: 'long',
      timeStyle: 'short',
      timeZone: 'UTC',
    }).format(date);
    return `${formatted} UTC`;
  } catch {
    return date.toISOString();
  }
}
