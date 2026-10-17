# Ambassador cash programme — rollout & legal checklist (KPB-160)

The **cash** Ambassador programme (FCFA balances, city leaderboard, Wave
withdrawals, in-app self-activation) is **gated OFF by default**. This document
is the operating procedure for keeping it safe and for opening it once legal
clearance is obtained.

> The **no-cash** referral programme (credits → WhatsApp advisor voucher,
> `ReferralScreen`) is unaffected and remains the default surface.

## Why it is gated

- **Play policy** — cash-for-referral can read as *incentivized installs* /
  deceptive behavior.
- **AML / KYC / tax** — cross-border FCFA payouts (Wave) create identity,
  reporting and tax duties that differ per country.
- **Minors** — the app has under-18 users; paying minors is a distinct risk.
- **Fraud** — self-referral rings, fake placements.

## How the gate works

`AmbassadorScreen` shows the cash surface only when:

```
AppConfig.ambassadorCashEnabled == true   // global flag, build-time
  OR  dashboard.activated == true          // Ambassador.cashProgramEnabled (see below)
```

Otherwise it shows an **application screen** — no FCFA, no leaderboard, no
withdrawal, no self-activation — just a "contact an advisor" path and a link to
the free referral programme.

- **Flag:** `KPB_AMBASSADOR_CASH_ENABLED` (`--dart-define`), default `false`
  (`lib/app/core/config/app_config.dart`). Build-time; flipping it needs a
  release.
- **The profile entry stays visible** ("Devenir ambassadeur"); it routes to the
  screen, which self-gates. New/unverified users therefore never see cash
  mechanics and cannot self-activate.

## Activating an individual ambassador (whitelist, flag left OFF)

> **Correction (17/10/2026).** This section used to say « mark their `Ambassador` record
> `activated = true` ». **There is no `activated` column.** `dashboard.activated` is computed
> by `AmbassadorService.getDashboard`. Until 17/10/2026 it was simply « an `Ambassador` row
> exists » — and any user could create that row through `POST /referrals/ambassador/activate`
> (no server guard). The real mechanics are now:

- **Activation is admin-only.** Console admin → « Compétition ambassadeurs » → « Activer un
  ambassadeur » (`POST /admin/ambassadors`, Admin/SuperAdmin, audited). It creates or reuses
  the `Ambassador` row and sets `approvedAt` / `approvedByAdminId`.
- `POST /referrals/ambassador/activate` now returns **403**
  (`ambassador_activation_admin_only`) when no row exists, unless the server flag
  `AMBASSADOR_SELF_ACTIVATION_ENABLED=true`. The installed app never calls it while the cash
  flag is off.
- `dashboard.activated` is **`Ambassador.cashProgramEnabled`**. The migration
  `20261022120000_referral_campaigns` set it to `true` on every row that existed before
  (their app keeps the cash surface). Ambassadors activated for the November 2026 competition
  get `false`: their app shows the application screen, never FCFA commissions.
- To give one vetted ambassador the cash surface (only once the checklist below is cleared):
  vet the person (18+, identity, payout account), then set `cashProgramEnabled = true` on their
  row (DB, no admin button on purpose). Payouts remain manual via Wave.

> The competition (`docs/runbook-campagne-ambassadeurs.md`) is **not** the cash programme:
> referees receive nothing, only the top 3 ambassadors win a fixed prize, paid to the parent
> for a minor.

## Opening the programme to everyone

Only after the legal checklist below is cleared:

1. Set `KPB_AMBASSADOR_CASH_ENABLED=true` in the release build config.
2. Ship a store release.
3. Monitor fraud/withdrawal metrics.

## Legal / compliance checklist (to clear before opening)

- [ ] **Play / App Store**: confirm the cash-referral mechanic is compliant
      (incentivized-behavior, real-money, and gambling-adjacent policies).
- [ ] **Countries in scope**: list the countries where payouts will run; confirm
      money-transmission / referral-reward legality in each.
- [ ] **KYC**: what identity verification is required before a payout, per
      country, per threshold?
- [ ] **Payout thresholds & caps**: minimum withdrawal, per-period caps,
      lifetime caps.
- [ ] **Tax**: reporting/withholding obligations on rewards, per country.
- [ ] **Minors**: exclude under-18s from cash (enforced by age/guardian data)?
- [ ] **Fraud controls**: self-referral detection, velocity limits, payout
      audit trail, clawback policy.
- [ ] **Terms**: ambassador T&Cs, consent, data handling for payout accounts.
- [ ] **Wave / payment provider**: contractual terms for bulk payouts.

---

*Source: Diagnostic produit 22/07/2026 — cycle 1 (Sécuriser), KPB-160.*
