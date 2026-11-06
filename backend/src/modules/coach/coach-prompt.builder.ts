export type CoachLanguage = 'fr' | 'en';

type CoachProfileContext = {
  fullName?: string;
  currentLevel?: string;
  targetCountryIds?: string[];
  annualTuitionBudgetEur?: number;
  /// Legacy compatibility during the profile-budget migration.
  monthlyBudgetEur?: number;
  openCases?: string[];
  /// Verified catalog facts retrieved for this question (RAG). When present,
  /// the model must use ONLY these for any figure/date/eligibility claim.
  verifiedContext?: string;
  /// Student's UI / preferred language. The coach must answer in this language
  /// so Anglophone students are not served French (and vice-versa).
  language?: CoachLanguage;
};

/// Normalize an arbitrary locale-ish string ('en', 'en_US', 'EN', …) to a
/// supported coach language, defaulting to French.
export function resolveCoachLanguage(raw?: string | null): CoachLanguage {
  return String(raw ?? '').trim().toLowerCase().startsWith('en') ? 'en' : 'fr';
}

/// Pseudonymize the annual tuition budget into a coarse range before it leaves the
/// server for the LLM. We never send the exact euro figure (a re-identifying
/// data point); a bucket is enough for budget-aware guidance.
export function budgetBucket(
  eur: number | undefined,
  lang: CoachLanguage,
): string {
  if (!eur || eur <= 0) return lang === 'en' ? 'not specified' : 'non renseigné';
  let range: string;
  if (eur < 5000) range = '< 5 000';
  else if (eur < 10000) range = '5 000–10 000';
  else if (eur < 20000) range = '10 000–20 000';
  else range = '> 20 000';
  return lang === 'en'
    ? `${range} €/year tuition (range)`
    : `${range} €/an de scolarité (tranche)`;
}

/// Verification freshness annotation for a RAG fact, with time decay. A fact
/// verified longer ago than [staleDays] is flagged STALE so the coach can warn
/// rather than present a year-old figure as currently verified. Returns the
/// bracket text used in `[source: …, <annotation>]`.
export function freshnessAnnotation(
  lastVerifiedAt: Date | null | undefined,
  lang: CoachLanguage,
  opts?: { now?: Date; staleDays?: number },
): string {
  const en = lang === 'en';
  if (!lastVerifiedAt) return en ? 'to confirm' : 'à confirmer';
  const now = opts?.now ?? new Date();
  const staleDays = opts?.staleDays ?? 180;
  const ageDays = Math.floor(
    (now.getTime() - lastVerifiedAt.getTime()) / 86_400_000,
  );
  // Le mois et l'année, comme l'élève les lira : « 2026-06-26 » passait tel
  // quel dans les réponses (audit build 57, T5-03).
  const date = monthYear(lastVerifiedAt, lang);
  if (ageDays > staleDays) {
    return en
      ? `verified ${date} — STALE, re-verify before quoting`
      : `vérifiée en ${date} — PÉRIMÉ, à revérifier avant de citer`;
  }
  return en ? `verified ${date}` : `vérifiée en ${date}`;
}

const MONTHS: Record<CoachLanguage, readonly string[]> = {
  fr: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
  en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
};

function monthYear(date: Date, lang: CoachLanguage): string {
  return `${MONTHS[lang][date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

/// Output guardrail: returns a localized caveat to append when the reply
/// states a concrete figure (currency amount or percentage) but NO verified
/// context grounded it. Conservative by design — only fires when grounding was
/// entirely absent, so it never second-guesses a properly-sourced figure.
export function unsourcedFigureCaveat(
  reply: string,
  verifiedContext: string,
  lang: CoachLanguage,
): string | null {
  if ((verifiedContext ?? '').trim().length > 0) return null;
  const hasFigure =
    /(€|\$|£)\s?\d|\d[\d  .,]*\s?(€|\$|£|eur|usd|cad|gbp|%)/i.test(reply);
  if (!hasFigure) return null;
  return lang === 'en'
    ? '\n\n⚠️ The figures above are not from the verified KPB catalogue — confirm them with a KPB advisor.'
    : '\n\n⚠️ Les chiffres ci-dessus ne proviennent pas du catalogue vérifié KPB — confirme-les avec un conseiller KPB.';
}

export function buildCoachSystemPrompt(profile: CoachProfileContext): string {
  const lang: CoachLanguage = profile.language === 'en' ? 'en' : 'fr';
  const verified = profile.verifiedContext?.trim();
  const hasVerified = !!verified && verified.length > 0;

  if (lang === 'en') {
    const countries =
      (profile.targetCountryIds ?? []).join(', ') || 'not specified';
    const budget = budgetBucket(
      profile.annualTuitionBudgetEur ??
        (profile.monthlyBudgetEur != null
          ? profile.monthlyBudgetEur * 12
          : undefined),
      'en',
    );
    const cases = (profile.openCases ?? []).join(', ') || 'none';

    // PII minimization: the student's name is deliberately NOT sent to the LLM.
    return `You are KPB Intelligence, a study-abroad guidance assistant for African students.
Student context (pseudonymized — no name is shared):
- Level: ${profile.currentLevel ?? 'not specified'}
- Target countries: ${countries}
- Indicative budget: ${budget}
- Open cases: ${cases}

VERIFIED CONTEXT (KPB catalogue data):
${hasVerified ? verified : 'No verified data available for this question.'}

Rules:
- Reply in English, max 4 sentences.
- For ANY figure or date (fees, amounts, deadlines, eligibility conditions), use ONLY the VERIFIED CONTEXT above. NEVER invent a figure, a date or a condition.
- Cite the source in plain words, in parentheses, with its name and the month it was verified (e.g. "(source: Campus France, verified June 2026)"). Never write "verified context", "[source: …]", brackets or a YYYY-MM-DD date: the student must not see how you work.
- If the requested information is not in the VERIFIED CONTEXT, say plainly that you have no verified information on it and invite the student to confirm with a KPB advisor — do not guess.
- Recommend only the 9 KPB destinations (France, Canada, USA, UK, Germany, Spain, Morocco, Turkey, UAE).
- Mention KPB partner schools when relevant.
- No personalized legal/financial advice.
- If the student is in distress, point them to a human KPB advisor.
- End with: "For important decisions, contact a KPB advisor."`;
  }

  const countries =
    (profile.targetCountryIds ?? []).join(', ') || 'non renseignés';
  const budget = budgetBucket(
    profile.annualTuitionBudgetEur ??
      (profile.monthlyBudgetEur != null
        ? profile.monthlyBudgetEur * 12
        : undefined),
    'fr',
  );
  const cases = (profile.openCases ?? []).join(', ') || 'aucune';

  // Minimisation : le nom de l'étudiant n'est volontairement PAS envoyé au LLM.
  return `Tu es KPB Intelligence, assistant d'orientation pour étudiants francophones d'Afrique.
Contexte étudiant (pseudonymisé — aucun nom n'est transmis):
- Niveau: ${profile.currentLevel ?? 'non renseigné'}
- Pays visés: ${countries}
- Budget indicatif: ${budget}
- Demandes en cours: ${cases}

CONTEXTE VÉRIFIÉ (données du catalogue KPB) :
${hasVerified ? verified : 'Aucune donnée vérifiée disponible pour cette question.'}

Règles:
- Réponds en français, max 4 phrases.
- Pour TOUT fait chiffré ou daté (frais, montant, date limite, condition d'éligibilité), utilise UNIQUEMENT le CONTEXTE VÉRIFIÉ ci-dessus. N'invente JAMAIS un chiffre, une date ou une condition.
- Cite la source en clair, entre parenthèses, avec son nom et le mois de sa vérification (ex. « (source : Campus France, vérifiée en juin 2026) »). N'écris jamais « contexte vérifié », « [source: …] », de crochets ni de date au format AAAA-MM-JJ : l'élève ne doit pas voir ta cuisine interne.
- Si l'information demandée n'est pas dans le CONTEXTE VÉRIFIÉ, dis simplement que tu n'as pas d'information vérifiée là-dessus et invite à confirmer avec un conseiller KPB — ne devine pas.
- Recommande uniquement les 9 destinations KPB (France, Canada, USA, UK, Allemagne, Espagne, Maroc, Turquie, EAU).
- Mentionne les écoles partenaires KPB quand pertinent.
- Pas de conseil juridique/financier personnalisé.
- En cas de détresse, oriente vers un conseiller humain KPB.
- Termine par: "Pour les décisions importantes, contacte un conseiller KPB."`;
}

export function buildCoachSuggestions(profile: CoachProfileContext): string[] {
  const lang: CoachLanguage = profile.language === 'en' ? 'en' : 'fr';
  const targets = profile.targetCountryIds ?? [];

  if (lang === 'en') {
    const suggestions = [
      'Which schools fit my budget?',
      'How do I apply to private schools in France?',
      'Which countries for computer science?',
    ];
    if (targets.includes('fra')) {
      suggestions[1] = 'OMNES vs ICN: which should I choose?';
    }
    return suggestions;
  }

  const suggestions = [
    'Quelles écoles pour mon budget ?',
    'Comment postuler en France privé ?',
    'Quels pays pour l’informatique ?',
  ];
  if (targets.includes('fra')) {
    suggestions[1] = 'OMNES vs ICN : que choisir ?';
  }
  return suggestions;
}
