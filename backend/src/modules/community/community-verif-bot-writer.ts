// ─────────────────────────────────────────────────────────────────────────────
// Bot « Vérif » (C3) — RÉDACTION de la réponse proposée.
//
// Modèle DÉTERMINISTE (FR / EN selon la question, tutoiement, niveau B1,
// aucune promesse, aucun pourcentage) qui assemble les faits, puis un pied
// FIXE : « Fiche @… : vérifié le JJ/MM/AAAA, source : … », la phrase de
// prudence si la question parle d'argent ou d'arnaque, et le rappel de
// confirmer sur le site officiel.
//
// Option LLM (`KPB_COMMUNITY_VERIF_BOT_LLM`) : seul le CORPS peut être
// reformulé, jamais le pied. La sortie est contrôlée automatiquement
// (`checkRewrite`) : un chiffre, un mois, un lien ou une mention absents du
// texte déterministe, un « % » ou une promesse ⇒ repli sur le modèle.
// ─────────────────────────────────────────────────────────────────────────────

import type { VerifIntent } from './community-verif-bot-detect';
import type {
  CountryFacts,
  EntityFacts,
  FactSet,
  InstitutionFacts,
  IntakeFact,
  IntakesFacts,
  ProgramFacts,
  ScholarshipFacts,
  UsVisaFact,
} from './community-verif-bot-facts';
import { VERIF_BOT_MAX_DOCUMENTS, VERIF_BOT_TEXT_MAX } from './community-verif-bot.config';

type Lang = 'fr' | 'en';

const MONTHS_FR = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre',
  'novembre', 'décembre',
];
const MONTHS_EN = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
  'November', 'December',
];

/** « 08/01/2027 » — jour UTC, la forme demandée (JJ/MM/AAAA) dans les deux langues. */
export function formatDay(isoDate: string): string {
  const d = new Date(isoDate);
  const dd = String(d.getUTCDate()).padStart(2, '0');
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${dd}/${mm}/${d.getUTCFullYear()}`;
}

/** Un jour nu `AAAA-MM-JJ` (avis visa) ou une date ISO → JJ/MM/AAAA. */
function formatAnyDay(value: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : formatDay(value);
}

/** « janvier 2027 » / « January 2027 » — une date ESTIMÉE se dit au mois près. */
export function formatMonth(isoDate: string, lang: Lang): string {
  const d = new Date(isoDate);
  return `${(lang === 'en' ? MONTHS_EN : MONTHS_FR)[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

function label(entity: EntityFacts, lang: Lang): string {
  return lang === 'en' ? entity.ref.labelEn : entity.ref.labelFr;
}

function intakeLabel(intake: IntakeFact, lang: Lang): string {
  const base =
    intake.month !== null
      ? `${(lang === 'en' ? MONTHS_EN : MONTHS_FR)[intake.month - 1]} ${intake.year}`
      : lang === 'en'
        ? `${intake.spring ? 'spring' : 'autumn'} ${intake.year}`
        : `${intake.spring ? 'printemps' : 'automne'} ${intake.year}`;
  const tags = [
    intake.spring && intake.month !== null ? (lang === 'en' ? 'spring intake' : 'rentrée décalée') : null,
    intake.estimated ? (lang === 'en' ? 'to be confirmed' : 'à confirmer') : null,
  ].filter(Boolean);
  return tags.length ? `${base} (${tags.join(', ')})` : base;
}

const T = {
  fr: {
    hello: 'Bonjour ! Voici ce que disent les données vérifiées de KPB.',
    session: (y: string) => `session ${y}`,
    status: 'Statut',
    sch: {
      open: (d: string) => `les candidatures sont ouvertes. Clôture confirmée : le ${d}.`,
      closing_soon: (d: string) =>
        `les candidatures sont ouvertes et la clôture approche : le ${d} (date confirmée). Prépare ton dossier sans attendre.`,
      open_date_to_confirm: () => "les candidatures sont ouvertes, mais la date de clôture n'est pas encore confirmée.",
      opens_on: (d: string) => `les candidatures ne sont pas encore ouvertes. Ouverture confirmée : le ${d}.`,
      opening_estimated: (m: string) =>
        `les candidatures ne sont pas encore ouvertes. Ouverture estimée : ${m} (date non confirmée).`,
      closing_estimated: (m: string) =>
        `la période de candidature est peut-être en cours. Clôture estimée : ${m} (date non confirmée).`,
      date_to_confirm: () => "nous n'avons pas encore de date confirmée pour la prochaine session.",
      closed: () => 'les candidatures sont fermées pour cette session.',
    },
    inCatalog: 'Cette bourse figure dans le catalogue vérifié de KPB.',
    funding: 'Financement',
    documents: 'Documents demandés',
    moreDocuments: 'la liste complète est sur la fiche',
    link: 'Lien officiel',
    website: 'Site officiel',
    partner: (n: string) => `${n} est un établissement partenaire de KPB.`,
    notPartner: (n: string) => `${n} figure dans le catalogue de KPB, mais ce n'est pas un établissement partenaire.`,
    intakes: 'Prochaines rentrées publiées',
    schoolIntakes: "Rentrées de l'école (pas forcément celles de cette formation)",
    ownIntakes: "Rentrées publiées de l'école",
    noUpcoming: "Aucune prochaine rentrée n'est publiée pour l'instant.",
    tuition: 'Frais de scolarité publiés',
    appFee: (n: number) => `Frais de candidature publiés : ${n} €.`,
    deadline: (d: string) => `Date limite de candidature : le ${d}.`,
    deadlinePassed: (d: string) => `La date limite publiée (${d}) est passée : la prochaine n'est pas encore connue.`,
    school: (n: string, partner: boolean) =>
      partner ? `Formation de ${n}, établissement partenaire de KPB.` : `Formation de ${n} (établissement non partenaire de KPB).`,
    nextIntake: 'Prochaine rentrée indiquée',
    visa: (types: string, list: string) =>
      `Avis visa : les demandes de visa étudiant (${types}) pour les États-Unis sont actuellement suspendues pour les ressortissants de : ${list}.`,
    visaSource: (d: string | null, url: string) =>
      d ? `Avis vérifié le ${d}, source : ${url}` : `Source de l'avis : ${url}`,
    unanswered: (items: string) =>
      `Les données de KPB ne précisent pas encore : ${items}. Regarde sur le site officiel.`,
    stale: (n: string, d: string | null) =>
      d
        ? `Attention : la fiche ${n} n'a pas été revérifiée depuis le ${d}. Vérifie sur le site officiel.`
        : `Attention : la fiche ${n} n'a pas de date de vérification. Vérifie sur le site officiel.`,
    sourceLine: (token: string, d: string | null, url: string | null) =>
      `Fiche ${token} : ${d ? `vérifié le ${d}` : 'date de vérification non renseignée'}, source : ${url ?? 'fiche KPB'}`,
    scam:
      "Prudence : une bourse ou une admission ne s'achète jamais auprès d'un « agent ». Ne paie personne rencontré ici et signale toute demande d'argent.",
    closing: "Les informations peuvent changer : confirme toujours sur le site officiel avant d'envoyer ton dossier.",
    intentNames: {
      status: 'le statut', deadline: 'la date limite', fees: 'les frais', documents: 'les documents demandés',
      partner: 'le partenariat', exists: "l'existence de cette entité dans le catalogue", intake: 'les rentrées',
      visa: 'la situation des visas pour ce pays', truth: '', scam: '',
    } satisfies Record<VerifIntent, string>,
  },
  en: {
    hello: "Hi! Here is what KPB's verified data says.",
    session: (y: string) => `${y} session`,
    status: 'Status',
    sch: {
      open: (d: string) => `applications are open. Confirmed closing date: ${d}.`,
      closing_soon: (d: string) =>
        `applications are open and the closing date is near: ${d} (confirmed). Prepare your application now.`,
      open_date_to_confirm: () => 'applications are open, but the closing date is not confirmed yet.',
      opens_on: (d: string) => `applications are not open yet. Confirmed opening date: ${d}.`,
      opening_estimated: (m: string) => `applications are not open yet. Estimated opening: ${m} (not confirmed).`,
      closing_estimated: (m: string) =>
        `the application period may be running. Estimated closing: ${m} (not confirmed).`,
      date_to_confirm: () => 'we do not have a confirmed date for the next session yet.',
      closed: () => 'applications are closed for this session.',
    },
    inCatalog: "This scholarship is listed in KPB's verified catalogue.",
    funding: 'Funding',
    documents: 'Required documents',
    moreDocuments: 'the full list is on the page',
    link: 'Official link',
    website: 'Official website',
    partner: (n: string) => `${n} is a KPB partner institution.`,
    notPartner: (n: string) => `${n} is listed in KPB's catalogue, but it is not a partner institution.`,
    intakes: 'Next published intakes',
    schoolIntakes: "The school's intakes (not necessarily this programme's)",
    ownIntakes: "The school's published intakes",
    noUpcoming: 'No upcoming intake is published yet.',
    tuition: 'Published tuition fees',
    appFee: (n: number) => `Published application fee: €${n}.`,
    deadline: (d: string) => `Application deadline: ${d}.`,
    deadlinePassed: (d: string) => `The published deadline (${d}) has passed: the next one is not known yet.`,
    school: (n: string, partner: boolean) =>
      partner ? `A programme of ${n}, a KPB partner institution.` : `A programme of ${n} (not a KPB partner institution).`,
    nextIntake: 'Next intake listed',
    visa: (types: string, list: string) =>
      `Visa notice: US student visa applications (${types}) are currently suspended for nationals of: ${list}.`,
    visaSource: (d: string | null, url: string) => (d ? `Notice checked on ${d}, source: ${url}` : `Notice source: ${url}`),
    unanswered: (items: string) => `KPB's data does not say yet: ${items}. Check the official website.`,
    stale: (n: string, d: string | null) =>
      d
        ? `Careful: the ${n} page has not been re-checked since ${d}. Check the official website.`
        : `Careful: the ${n} page has no verification date. Check the official website.`,
    sourceLine: (token: string, d: string | null, url: string | null) =>
      `Page ${token}: ${d ? `checked on ${d}` : 'no verification date'}, source: ${url ?? 'KPB page'}`,
    scam:
      'Be careful: a scholarship or an admission is never bought from an "agent". Never pay anyone you met here, and report any request for money.',
    closing: 'Information can change: always confirm on the official website before you send your application.',
    intentNames: {
      status: 'the status', deadline: 'the deadline', fees: 'the fees', documents: 'the required documents',
      partner: 'the partnership', exists: 'whether it is listed in the catalogue', intake: 'the intakes',
      visa: 'the visa situation for this country', truth: '', scam: '',
    } satisfies Record<VerifIntent, string>,
  },
} as const;

function bullet(text: string): string {
  return `– ${text}`;
}

/** `ofInstitution` : les rentrées de l'école citée elle-même (pas un repli). */
function intakeLines(intakes: IntakesFacts, lang: Lang, ofInstitution = false): string[] {
  const t = T[lang];
  const headOf = () => (ofInstitution ? t.ownIntakes : intakes.fromSchool ? t.schoolIntakes : t.intakes);
  if (intakes.dates.length) {
    const head = headOf();
    return [bullet(`${head}${colon(lang)} ${intakes.dates.map((d) => intakeLabel(d, lang)).join(', ')}.`)];
  }
  if (intakes.allPast) return [bullet(t.noUpcoming)];
  if (intakes.labels.length) {
    const head = headOf();
    return [bullet(`${head}${colon(lang)} ${intakes.labels.join(', ')}.`)];
  }
  return [];
}

/** Deux-points typographiques : espace avant en français, pas en anglais. */
function colon(lang: Lang): string {
  return lang === 'en' ? ':' : ' :';
}

function documentsLine(docs: { fr: string[]; en: string[] }, lang: Lang): string | null {
  const items = lang === 'en' ? (docs.en.length ? docs.en : docs.fr) : docs.fr;
  if (!items.length) return null;
  const shown = items.slice(0, VERIF_BOT_MAX_DOCUMENTS);
  const sep = lang === 'en' ? '; ' : ' ; ';
  const more = items.length > shown.length ? `${sep}${T[lang].moreDocuments}` : '';
  return bullet(`${T[lang].documents}${colon(lang)} ${shown.join(sep)}${more}.`.replace('..', '.'));
}

function scholarshipBlock(e: ScholarshipFacts, intents: ReadonlySet<VerifIntent>, lang: Lang): string[] {
  const t = T[lang];
  const s = e.status;
  const date = s.date;
  const phrase =
    s.kind === 'opening_estimated' || s.kind === 'closing_estimated'
      ? t.sch[s.kind](formatMonth(date!, lang))
      : s.kind === 'open' || s.kind === 'closing_soon' || s.kind === 'opens_on'
        ? t.sch[s.kind](formatDay(date!))
        : t.sch[s.kind]();
  const head = s.academicYear ? `${label(e, lang)} (${t.session(s.academicYear)})` : label(e, lang);
  const lines = [head, bullet(`${t.status}${colon(lang)} ${phrase}`)];
  if (intents.has('exists') || intents.has('truth')) lines.push(bullet(t.inCatalog));
  if (intents.has('fees') && e.funding) lines.push(bullet(`${t.funding}${colon(lang)} ${lang === 'en' ? e.funding.en : e.funding.fr}.`));
  if (intents.has('documents')) {
    const docs = documentsLine(e.documents, lang);
    if (docs) lines.push(docs);
  }
  if (e.applicationUrl) lines.push(bullet(`${t.link}${colon(lang)} ${e.applicationUrl}`));
  return lines;
}

function institutionBlock(e: InstitutionFacts, intents: ReadonlySet<VerifIntent>, lang: Lang): string[] {
  const t = T[lang];
  const name = label(e, lang);
  const lines = [name, bullet(e.isPartner ? t.partner(name) : t.notPartner(name))];
  lines.push(...intakeLines(e.intakes, lang, true));
  if (intents.has('fees') && e.tuition) lines.push(bullet(`${t.tuition}${colon(lang)} ${lang === 'en' ? e.tuition.en : e.tuition.fr}.`));
  if (e.websiteUrl) lines.push(bullet(`${t.website}${colon(lang)} ${e.websiteUrl}`));
  return lines;
}

function programBlock(e: ProgramFacts, intents: ReadonlySet<VerifIntent>, lang: Lang): string[] {
  const t = T[lang];
  const lines = [label(e, lang)];
  if (e.institution) {
    lines.push(bullet(t.school(lang === 'en' ? e.institution.labelEn : e.institution.labelFr, e.institution.isPartner)));
  }
  lines.push(...intakeLines(e.intakes, lang));
  if (e.applicationDeadline) {
    const d = formatDay(e.applicationDeadline.date);
    lines.push(bullet(e.applicationDeadline.passed ? t.deadlinePassed(d) : t.deadline(d)));
  }
  if (intents.has('fees')) {
    if (e.tuition) lines.push(bullet(`${t.tuition}${colon(lang)} ${lang === 'en' ? e.tuition.en : e.tuition.fr}.`));
    if (e.applicationFeeEur !== null) lines.push(bullet(t.appFee(e.applicationFeeEur)));
  }
  if (intents.has('documents')) {
    const docs = documentsLine(e.documents, lang);
    if (docs) lines.push(docs);
  }
  return lines;
}

function countryBlock(e: CountryFacts, lang: Lang): string[] {
  const t = T[lang];
  const lines = [label(e, lang)];
  if (e.nextIntake) lines.push(bullet(`${t.nextIntake}${colon(lang)} ${lang === 'en' ? e.nextIntake.en : e.nextIntake.fr}.`));
  return lines;
}

function visaLines(visa: UsVisaFact, lang: Lang): string[] {
  const t = T[lang];
  const names = visa.countries.map((c) => (lang === 'en' ? c.nameEn : c.nameFr)).join(', ');
  return [
    t.visa(visa.visaTypes.join(', '), names),
    t.visaSource(visa.verifiedAt ? formatAnyDay(visa.verifiedAt) : null, visa.sourceUrl),
  ];
}

/** Jeton de mention canonique : la fiche s'ouvre d'un toucher dans l'app. */
export function mentionToken(entity: EntityFacts): string {
  const text = entity.ref.labelFr.replace(/[\]\n\r]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 80) || '?';
  return `@[${text}](${entity.ref.type}:${entity.ref.id})`;
}

export interface RenderInput {
  facts: FactSet;
  intents: readonly VerifIntent[];
  unanswered: readonly VerifIntent[];
  lang: Lang;
  scamCaution: boolean;
}

export interface RenderedDraft {
  /** Les faits (reformulable par le LLM). */
  body: string;
  /** Sources, prudence, rappel (jamais reformulé). */
  footer: string;
}

export function renderDraft(input: RenderInput): RenderedDraft {
  const { facts, lang } = input;
  const t = T[lang];
  const intents = new Set(input.intents);
  const blocks: string[] = [t.hello];
  const visaNeeded = facts.entities.some((e) => e.kind !== 'scholarship' && e.isUs);
  for (const e of facts.entities) {
    const lines =
      e.kind === 'scholarship'
        ? scholarshipBlock(e, intents, lang)
        : e.kind === 'institution'
          ? institutionBlock(e, intents, lang)
          : e.kind === 'program'
            ? programBlock(e, intents, lang)
            : countryBlock(e, lang);
    if (e.source.stale) {
      lines.push(t.stale(label(e, lang), e.source.verifiedAt ? formatDay(e.source.verifiedAt) : null));
    }
    blocks.push(lines.join('\n'));
  }
  if (visaNeeded && facts.usVisa) blocks.push(visaLines(facts.usVisa, lang).join('\n'));
  const missing = input.unanswered.map((i) => t.intentNames[i]).filter(Boolean);
  if (missing.length) blocks.push(t.unanswered(missing.join(', ')));

  const footer: string[] = facts.entities.map((e) =>
    t.sourceLine(mentionToken(e), e.source.verifiedAt ? formatDay(e.source.verifiedAt) : null, e.source.url),
  );
  if (input.scamCaution) footer.push(t.scam);
  footer.push(t.closing);
  return { body: blocks.join('\n\n'), footer: footer.join('\n') };
}

/** Le texte publié : corps + pied, sous la limite d'une réponse. */
export function composeText(body: string, footer: string): string {
  const room = VERIF_BOT_TEXT_MAX - footer.length - 2;
  const trimmedBody = body.length > room ? `${body.slice(0, Math.max(0, room - 1)).trimEnd()}…` : body;
  return `${trimmedBody}\n\n${footer}`;
}

// ── Contrôle d'une reformulation (LLM) ──────────────────────────────────────

const URL_RE = /https?:\/\/[^\s)]+/gi;
const PROMISE_RE =
  /(garanti|garantie|garantis|garanties|assur[ée]e? d|c'est s[uû]r|certaine? d['’ ]?(être|etre|avoir|obtenir)|guarantee|guaranteed|you will (get|be accepted|win)|sure to)/i;

function numbersOf(text: string): Set<string> {
  return new Set([...text.matchAll(/\d+/g)].map((m) => String(Number(m[0]))));
}

function monthsOf(text: string): Set<string> {
  const out = new Set<string>();
  const lower = text.toLowerCase();
  for (const m of text.matchAll(/\b\d{1,2}\/(\d{1,2})\/\d{4}\b/g)) {
    const idx = Number(m[1]) - 1;
    if (idx >= 0 && idx < 12) {
      out.add(MONTHS_FR[idx]);
      out.add(MONTHS_EN[idx].toLowerCase());
    }
  }
  MONTHS_FR.forEach((name, idx) => {
    if (new RegExp(`\\b${name}\\b`, 'i').test(lower)) {
      out.add(name);
      out.add(MONTHS_EN[idx].toLowerCase());
    }
  });
  MONTHS_EN.forEach((name, idx) => {
    if (new RegExp(`\\b${name}\\b`, 'i').test(lower)) {
      out.add(name.toLowerCase());
      out.add(MONTHS_FR[idx]);
    }
  });
  return out;
}

export type RewriteCheck = { ok: true } | { ok: false; reason: string };

/**
 * Le LLM ne peut rien ajouter : chaque nombre, mois et lien de sa sortie doit
 * figurer dans le texte déterministe ; aucune mention (le pied les porte),
 * aucun « % », aucune promesse.
 */
export function checkRewrite(candidate: unknown, reference: RenderedDraft): RewriteCheck {
  if (typeof candidate !== 'string') return { ok: false, reason: 'not_text' };
  const text = candidate.trim();
  if (text.length < 40 || text.length > VERIF_BOT_TEXT_MAX - reference.footer.length - 2) {
    return { ok: false, reason: 'length' };
  }
  if (text.includes('%')) return { ok: false, reason: 'percent' };
  if (text.includes('@[')) return { ok: false, reason: 'mention' };
  if (PROMISE_RE.test(text)) return { ok: false, reason: 'promise' };
  const refText = `${reference.body}\n${reference.footer}`;
  const allowedNumbers = numbersOf(refText);
  for (const n of numbersOf(text)) {
    if (!allowedNumbers.has(n)) return { ok: false, reason: 'unknown_number' };
  }
  const allowedMonths = monthsOf(refText);
  for (const m of monthsOf(text)) {
    if (!allowedMonths.has(m)) return { ok: false, reason: 'unknown_month' };
  }
  const allowedUrls = new Set((refText.match(URL_RE) ?? []).map((u) => u.replace(/[.,;]+$/, '')));
  for (const url of text.match(URL_RE) ?? []) {
    if (!allowedUrls.has(url.replace(/[.,;]+$/, ''))) return { ok: false, reason: 'unknown_link' };
  }
  return { ok: true };
}

/** Consigne du LLM : reformuler le corps, sans rien y ajouter. */
export function rewritePrompt(reference: RenderedDraft, lang: Lang): { system: string; user: string } {
  const system =
    lang === 'en'
      ? [
          'You rewrite a short answer for a community of students who want to study abroad.',
          'Rules: use ONLY the facts in the draft. Never add a number, a date, an amount, a percentage, a link or a name.',
          'Keep every date, amount and link exactly as written. No promise of admission or scholarship.',
          'Simple English (level B1), short sentences, friendly and direct. Answer in English.',
          'Return a JSON object: {"text": "..."} with the rewritten draft only (no sources, no signature).',
        ].join('\n')
      : [
          "Tu reformules une réponse courte pour une communauté d'élèves qui veulent étudier à l'étranger.",
          "Règles : utilise UNIQUEMENT les faits du brouillon. N'ajoute jamais de chiffre, de date, de montant, de pourcentage, de lien ni de nom.",
          "Garde chaque date, montant et lien exactement comme écrits. Aucune promesse d'admission ni de bourse.",
          'Tutoie, français simple (niveau B1), phrases courtes, ton chaleureux et direct. Réponds en français.',
          'Renvoie un objet JSON : {"text": "..."} avec seulement le brouillon reformulé (sans sources ni signature).',
        ].join('\n');
  return { system, user: reference.body };
}
