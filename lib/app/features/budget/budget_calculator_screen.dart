import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/scholarship_navigation.dart';
import '../../core/utils/country_utils.dart';
import 'data/budget_data.dart';
import '../../core/ui/app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cost simulator — App-engagement handoff restyle (navy/blue).
//
// HONEST-DATA NOTES (the "Simulateur de coût" mock mixes in fabricated specifics
// the calculator has no input for — deliberately OMITTED here):
//   • Subtitle "Grenoble · 2 years · flatshare · flight from Dakar" → there is
//     NO city, NO years selector, NO housing-type toggle and NO flight input.
//     The subtitle only shows the REAL selected destination + monthly period.
//   • "ESTIMATED TOTAL — 2 YEARS" / "≈ 18,5 M FCFA" / "≈ €28,200" → the model is
//     MONTHLY and per-destination native currency; no multi-year rollup and no
//     cross-currency FCFA/EUR total (the BCEAO 655.957 peg only converts EUR and
//     the model is multi-currency, so no conversion is shown). The dark card
//     shows the real monthly total in the destination currency + the real
//     min/max lifestyle band.
//   • "the Eiffel scholarship would cover most of it" → not computed; no named
//     scholarship or coverage claim. Only a generic scholarships CTA remains.
//   • "Living costs: Numbeo … · flight: Kayak … · BCEAO rate 655.957" → the data
//     is KPB Education's own compiled living-cost model (see budget_data.dart),
//     not Numbeo, and there is no flight here. The footnote attributes it
//     honestly to KPB's own estimates.
// Everything rendered below is bound to the REAL budget_data.dart model.
// ─────────────────────────────────────────────────────────────────────────────

/// Lifestyle band selector — maps to the profile's min / typical / max amounts.
enum Lifestyle { econome, standard, confort }

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
class BudgetCalculatorScreen extends StatefulWidget {
  const BudgetCalculatorScreen({super.key});

  @override
  State<BudgetCalculatorScreen> createState() => _BudgetCalculatorScreenState();
}

class _BudgetCalculatorScreenState extends State<BudgetCalculatorScreen> {
  LivingBudgetProfile? _selectedProfile;
  Lifestyle _lifestyle = Lifestyle.standard;

  @override
  void initState() {
    super.initState();
    if (mockBudgetProfiles.isNotEmpty) {
      _selectedProfile = mockBudgetProfiles.first;
    }
  }

  /// Scale applied to each category's typical amount so the breakdown always
  /// sums to the displayed total (min for thrifty, max for comfort, else 1.0).
  double _getMultiplier(LivingBudgetProfile p) {
    if (_lifestyle == Lifestyle.econome) return p.monthlyMin / p.totalTypical;
    if (_lifestyle == Lifestyle.confort) return p.monthlyMax / p.totalTypical;
    return 1.0;
  }

  double _getTotal(LivingBudgetProfile p) {
    if (_lifestyle == Lifestyle.econome) return p.monthlyMin;
    if (_lifestyle == Lifestyle.confort) return p.monthlyMax;
    return p.totalTypical;
  }

  @override
  Widget build(BuildContext context) {
    final p = _selectedProfile;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: p == null
            ? const Center(child: CircularProgressIndicator())
            : _body(p),
      ),
    );
  }

  Widget _body(LivingBudgetProfile p) {
    final mult = _getMultiplier(p);
    final total = _getTotal(p);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _header(p),
        const SizedBox(height: 16),
        _destinationSelector(),
        const SizedBox(height: 12),
        _lifestyleToggle(),
        const SizedBox(height: 16),
        _totalCard(p, total),
        const SizedBox(height: 14),
        _categoryCard(p, mult),
        const SizedBox(height: 14),
        _scholarshipsCta(),
      ],
    );
  }

  // ── Header: circle back + title + real context subtitle ───────────────────
  Widget _header(LivingBudgetProfile p) {
    return Row(
      children: [
        _CircleBackButton(onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'budget_calculator_title'.tr,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${p.country} · ${'budget_subtitle_monthly'.tr}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11.5, color: KpbColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Destination selector (real input) ─────────────────────────────────────
  Widget _destinationSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: mockBudgetProfiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final profile = mockBudgetProfiles[i];
          final selected = profile == _selectedProfile;
          return GestureDetector(
            onTap: () => setState(() => _selectedProfile = profile),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? KpbColors.actionPrimarySoft : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected
                      ? KpbColors.actionPrimary.withValues(alpha: 0.3)
                      : KpbColors.border,
                ),
              ),
              child: Text(
                '${countryFlag(profile.country)} ${profile.country}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? KpbColors.actionPrimaryPressed
                      : KpbColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Lifestyle band toggle (real input) ────────────────────────────────────
  Widget _lifestyleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: KpbColors.border),
      ),
      child: Row(
        children: [
          _lifestyleSegment('budget_lifestyle_econome'.tr, Lifestyle.econome),
          _lifestyleSegment('budget_lifestyle_standard'.tr, Lifestyle.standard),
          _lifestyleSegment('budget_lifestyle_confort'.tr, Lifestyle.confort),
        ],
      ),
    );
  }

  Widget _lifestyleSegment(String text, Lifestyle mode) {
    final selected = _lifestyle == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lifestyle = mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? KpbColors.actionPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : KpbColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dark navy total card (eyebrow + real monthly total + real band) ───────
  Widget _totalCard(LivingBudgetProfile p, double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: KpbColors.brandNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'estimated_monthly_budget'.tr.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: KpbColors.decorSky,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '≈ ${_money(total)} ${p.currency}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              height: 1.05,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${'budget_monthly_range'.tr}: '
            '${_money(p.monthlyMin)}–${_money(p.monthlyMax)} ${p.currency}',
            style: const TextStyle(fontSize: 11.5, color: KpbColors.textFaint),
          ),
        ],
      ),
    );
  }

  // ── White breakdown card: real category rows + honest source footnote ─────
  Widget _categoryCard(LivingBudgetProfile p, double mult) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: const [
          BoxShadow(
            color: KpbShadow.softNavy,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < p.categories.length; i++) ...[
            _categoryRow(p.categories[i], mult, p.currency, p.totalTypical),
            if (i != p.categories.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          Text(
            'budget_sources_note'.tr,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: KpbColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(
    BudgetCategory cat,
    double mult,
    String currency,
    double totalTypical,
  ) {
    final value = (cat.typical * mult).round();
    final pct =
        totalTypical <= 0 ? 0.0 : (cat.typical / totalTypical).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                cat.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_money(value)} $currency',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KpbColors.actionPrimary,
              ),
            ),
          ],
        ),
        if (cat.note != null) ...[
          const SizedBox(height: 2),
          Text(
            cat.note!,
            style: const TextStyle(fontSize: 10.5, color: KpbColors.textFaint),
          ),
        ],
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 7,
            color: KpbColors.surfaceMuted,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: KpbColors.decorSky,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Generic scholarships CTA (routes to the MVP-gated scholarships screen) ─
  Widget _scholarshipsCta() {
    return InkWell(
      // L'onglet Bourses de la coquille, pas une seconde liste empilée.
      onTap: openScholarshipOrTab,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.actionPrimary, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 18, color: KpbColors.actionPrimary),
            const SizedBox(width: 8),
            Text(
              'budget_see_scholarships_cta'.tr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: KpbColors.actionPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Groups an amount into space-separated thousands (e.g. 18000 → "18 000").
String _money(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KpbColors.border),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 19,
          color: KpbColors.brandNavy,
          semanticLabel: 'a11y_back'.tr,
        ),
      ),
    );
  }
}
