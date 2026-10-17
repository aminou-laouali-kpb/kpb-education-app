import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/intake_calendar.dart';
import '../../core/models/app_models.dart';
import '../../core/models/community.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/ui/components/source_link.dart';
import '../../core/ui/components/verified_badge.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../community/hub/community_entity_section.dart';
import '../france/france_private_admission_screen.dart';
import 'eligibility_quiz_screen.dart';
import 'program_detail_screen.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/us_visa_notice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).

class CountryDetailScreen extends StatefulWidget {
  const CountryDetailScreen({super.key, required this.countryId});

  final String countryId;

  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  late final AppController _controller;
  CountryModel? _country;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AppController>();
    unawaited(AnalyticsService.instance.logViewCountry(widget.countryId));
    _load();
  }

  Future<void> _load() async {
    try {
      final country = await _controller.loadCountryDetail(widget.countryId);
      if (!mounted) return;
      setState(() {
        _country = country;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _countryKey => normalizeCountryId(widget.countryId);

  List<InstitutionModel> _partnerInstitutions(CountryModel country) {
    return _controller.institutions
        .where(
          (i) =>
              i.countryId == country.id ||
              i.countryId == _countryKey ||
              i.countryId == widget.countryId,
        )
        .where((i) => i.isPartner)
        .take(8)
        .toList();
  }

  List<ScholarshipModel> _countryScholarships(CountryModel country) {
    return _controller.scholarships
        .where(
          (s) =>
              s.countryId == country.id ||
              s.countryId == _countryKey ||
              s.countryId == widget.countryId,
        )
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KpbColors.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final country = _country ?? _controller.countryByIdOrNull(_countryKey);
    if (country == null) {
      return Scaffold(
        backgroundColor: KpbColors.canvas,
        body: Center(child: Text('country_not_found'.tr)),
      );
    }

    final locale = _controller.localeCode;
    final name = _controller.resolve(country.name);
    final marketing = _controller.resolve(country.marketingDescription);
    final whyStudy = _controller.resolve(country.whyStudy);
    final bullets = country.whyStudyBulletsFor(locale);
    final steps = country.howItWorksStepsFor(locale);
    final mvpNote = country.mvpNote.resolve(locale);
    final visa = _controller.resolve(country.visaOverview);
    final languageText = _controller.resolve(country.languageSection).isNotEmpty
        ? _controller.resolve(country.languageSection)
        : _controller.resolve(country.mainLanguage);
    final scholarshipsIntro = _controller.resolve(country.scholarshipsSection);
    final partners = _partnerInstitutions(country);
    final scholarships = _countryScholarships(country);
    final isFrance = country.id == 'fra' || country.id == 'france';

    // Contiguous numbering across the sections actually present (honest — a
    // section with no catalog data is skipped rather than shown empty).
    var n = 0;
    String num() => '${++n}.';

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: KpbColors.brandNavy,
              ),
            ),
            const SizedBox(height: 14),
            _Hero(
              flag: displayCountryFlag(
                  id: country.id, flagEmoji: country.flagEmoji),
              badge: 'country_guide_badge'.tr,
              // Per-country generated visual (owner request): wire this to a
              // future CountryModel field (e.g. country.heroImageUrl) once the
              // backend exposes one — _Hero falls back to today's gradient.
              imageUrl: null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VerifiedBadge(lastVerifiedAt: country.lastVerifiedAt),
                KpbSourceLink(url: country.sourceUrl),
              ],
            ),
          ],
        ),
      ),
    ];

    if (mvpNote.isNotEmpty) {
      children.add(_NoteBox(text: mvpNote));
    }
    if (isUnitedStatesCountryId(country.id)) {
      children.add(UsVisaNotice(
        countryOfResidence: _controller.profile?.countryOfResidence,
        localeCode: locale,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      ));
    }
    if (isFrance) {
      children.add(_FranceCard(
        onTap: () => Get.to(() => FrancePrivateAdmissionScreen()),
      ));
    }

    // 1. Overview & highlights.
    if (marketing.isNotEmpty || whyStudy.isNotEmpty) {
      children.add(_Heading('${num()} ${'country_overview_highlights'.tr}'));
      children.add(_GuideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (marketing.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: whyStudy.isNotEmpty ? 10 : 0),
                child: Text(marketing, style: _bodyStyle),
              ),
            if (whyStudy.isNotEmpty) Text(whyStudy, style: _bodyStyle),
          ],
        ),
      ));
      children.add(_ConsultPill(
        onTap: () => _openConsultation(context, _controller, country),
      ));
    }

    // 2. Why study here.
    if (bullets.isNotEmpty) {
      children.add(_Heading('${num()} ${'country_why_this_country'.tr}'));
      children.add(_GuideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < bullets.length; i++) ...[
              if (i > 0) const SizedBox(height: 11),
              _CheckBullet(text: bullets[i]),
            ],
          ],
        ),
      ));
    }

    // 3. Admission routes & process.
    if (steps.isNotEmpty) {
      children.add(_Heading('${num()} ${'country_admission_routes'.tr}'));
      children.add(_GuideCard(
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _NumberStep(index: i + 1, text: steps[i]),
            ],
          ],
        ),
      ));
    }

    // 4. Tuition & cost of living — deliberately NO price; routes to KPB.
    children.add(_Heading('${num()} ${'country_tuition_living'.tr}'));
    children.add(_CostCard(
      onTap: () => _openConsultation(context, _controller, country),
    ));

    // 5. Student visa procedure.
    if (visa.isNotEmpty) {
      children.add(_Heading('${num()} ${'country_visa_procedure'.tr}'));
      children.add(_VisaCard(text: visa));
    }

    // Verified universities (no number — matches the handoff).
    if (partners.isNotEmpty) {
      children.add(_Heading('country_verified_universities'.tr));
      for (final inst in partners) {
        children.add(_UniRow(
          name: _controller.resolve(inst.name),
          location: _controller.resolve(inst.location),
          fit: _controller.institutionFit(inst),
          onTap: inst.programIds.isNotEmpty
              ? () => Get.to(
                  () => ProgramDetailScreen(programId: inst.programIds.first))
              : null,
        ));
      }
    }

    // Required language (real catalog data; compact card).
    if (languageText.isNotEmpty) {
      children.add(_Heading('country_required_language'.tr));
      children.add(_GuideCard(child: Text(languageText, style: _bodyStyle)));
    }

    // Available scholarships (real catalog data).
    if (scholarshipsIntro.isNotEmpty || scholarships.isNotEmpty) {
      children.add(_Heading('country_available_scholarships'.tr));
      children.add(_GuideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scholarshipsIntro.isNotEmpty)
              Padding(
                padding:
                    EdgeInsets.only(bottom: scholarships.isNotEmpty ? 10 : 0),
                child: Text(scholarshipsIntro, style: _bodyStyle),
              ),
            for (var i = 0; i < scholarships.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      size: 16, color: KpbColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _controller.resolve(scholarships[i].name),
                      style: _bodyStyle,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ));
    }

    // 6. KPB support services.
    children.add(_Heading('${num()} ${'country_support_services'.tr}'));
    children.add(_GuideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SupportBullet(
              icon: Icons.travel_explore_rounded,
              labelKey: 'svc_school_search'),
          SizedBox(height: 11),
          _SupportBullet(
              icon: Icons.description_outlined, labelKey: 'svc_application'),
          SizedBox(height: 11),
          _SupportBullet(
              icon: Icons.record_voice_over_outlined,
              labelKey: 'svc_interview'),
          SizedBox(height: 11),
          _SupportBullet(
              icon: Icons.flight_takeoff_rounded, labelKey: 'svc_visa'),
        ],
      ),
    ));

    // Secondary — eligibility self-check (existing feature).
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: OutlinedButton.icon(
        onPressed: () =>
            Get.to(() => EligibilityQuizScreen(countryId: country.id)),
        icon: const Icon(Icons.quiz_outlined, size: 18),
        label: Text('take_eligibility_quiz'.tr),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: KpbColors.border, width: 1.5),
          foregroundColor: KpbColors.actionPrimary,
        ),
      ),
    ));

    // Communauté : « Discussions (N) » sur ce pays (drapeau distant
    // `community` ; hauteur nulle sinon).
    children.add(CommunityEntitySection(
      entity: CommunityMention(
        type: CommunityEntityType.country,
        id: country.id,
        label: name,
        countryId: country.id,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    ));

    // Primary hand-off — WhatsApp "Get supported".
    children.add(_GetSupportedCta(
      label: 'get_supported'.tr,
      onTap: () => _openWhatsApp(_controller, country),
    ));

    children.add(const SizedBox(height: 28));

    // The breadcrumb (with the back button) is pinned OUTSIDE the scroll view:
    // the target audience does not reliably know the iOS back-swipe gesture,
    // so the visible back affordance must survive scrolling (owner review).
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Breadcrumb(crumb: 'nav_destinations'.tr, onBack: () => Get.back()),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: children),
            ),
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(
  fontSize: 12.5,
  height: 1.6,
  color: KpbColors.textSecondary,
);

// ─────────────────────────────────────────────────────────────────────────────
// CTA actions.
// ─────────────────────────────────────────────────────────────────────────────
void _openConsultation(
  BuildContext context,
  AppController controller,
  CountryModel country,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CaseComposerSheet(
      caseType: CaseType.consultation,
      title: 'country_study_in'
          .trParams({'country': controller.resolve(country.name)}),
      contextLabel: controller.resolve(country.name),
      countryId: country.id,
    ),
  );
}

void _openWhatsApp(AppController controller, CountryModel country) {
  openWhatsAppOrToast(
    prefill: kpbWhatsAppPrefill(
      custom: controller.resolve(country.whatsAppPrefill),
      country: controller.resolve(country.name),
    ),
    source: 'country_detail',
    contextType: 'destination',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Header pieces.
// ─────────────────────────────────────────────────────────────────────────────
/// Pinned breadcrumb bar with the back button. Rendered outside the scroll
/// view so the back affordance never leaves the screen while scrolling.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.crumb, required this.onBack});
  final String crumb;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        border: Border(bottom: BorderSide(color: KpbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      // The whole row (circle + label) is one tap target: 30px alone is too
      // small for first-smartphone users.
      child: GestureDetector(
        onTap: onBack,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                    color: KpbColors.actionPrimary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 15, color: KpbColors.actionPrimary),
            ),
            const SizedBox(width: 9),
            Text(
              crumb,
              style: const TextStyle(
                fontSize: 12,
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

/// Country hero frame. Accepts an optional per-country image URL (owner wants
/// generated country visuals later): when [imageUrl] is provided the image is
/// the backdrop (under a navy scrim so flag/badge stay readable); on null,
/// empty, or load failure it falls back cleanly to the current gradient.
class _Hero extends StatelessWidget {
  const _Hero({required this.flag, required this.badge, this.imageUrl});
  final String flag;
  final String badge;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Base layer: the current brand gradient — always painted, so a
          // missing/failed image degrades to exactly today's rendering.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [KpbColors.brandNavy, KpbColors.heroIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            Positioned.fill(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                // On load error the gradient base layer shows through.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Scrim: keeps flag/badge readable on any photo brightness.
            Positioned.fill(
              child: ColoredBox(
                color: KpbColors.brandNavy.withValues(alpha: 0.45),
              ),
            ),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            child: Column(
              children: [
                Text(flag, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: KpbColors.error,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: KpbColors.error.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section building blocks.
// ─────────────────────────────────────────────────────────────────────────────
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: KpbColors.actionPrimaryPressed,
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        child: child,
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: KpbColors.actionPrimarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.55,
            fontWeight: FontWeight.w600,
            color: KpbColors.actionPrimaryPressed,
          ),
        ),
      ),
    );
  }
}

class _FranceCard extends StatelessWidget {
  const _FranceCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KpbColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined,
                    color: KpbColors.actionPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'private_schools_admission'.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'dedicated_path_intake'.trParams(
                          {'intake': IntakeCalendar.label(capitalized: true)}),
                      style: const TextStyle(
                          fontSize: 11.5, color: KpbColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: KpbColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBullet extends StatelessWidget {
  const _CheckBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 16, color: KpbColors.success),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _bodyStyle)),
      ],
    );
  }
}

class _NumberStep extends StatelessWidget {
  const _NumberStep({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: KpbColors.actionPrimarySoft,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.actionPrimary,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(text, style: _bodyStyle)),
      ],
    );
  }
}

class _VisaCard extends StatelessWidget {
  const _VisaCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: KpbColors.warningLight,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.badge_outlined,
                  size: 13, color: KpbColors.warning),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(text, style: _bodyStyle)),
          ],
        ),
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KpbColors.brandNavy,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: KpbColors.decorSky.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.calculate_rounded,
                    size: 20, color: KpbColors.decorSky),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'country_cost_estimate_body'.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: KpbColors.borderStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UniRow extends StatelessWidget {
  const _UniRow({
    required this.name,
    required this.location,
    required this.fit,
    required this.onTap,
  });

  final String name;
  final String location;

  /// Null (no badge) without a student profile.
  final ProfileFit? fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KpbColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        location,
                        style: const TextStyle(
                            fontSize: 10.5, color: KpbColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (fit != null) ...[
                const SizedBox(width: 10),
                ProfileFitBadge(fit: fit!, fontSize: 11),
              ],
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: KpbColors.textFaint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportBullet extends StatelessWidget {
  const _SupportBullet({required this.icon, required this.labelKey});
  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: KpbColors.actionPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            labelKey.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: KpbColors.gray700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTAs.
// ─────────────────────────────────────────────────────────────────────────────
class _ConsultPill extends StatelessWidget {
  const _ConsultPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: KpbColors.actionPrimary,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: KpbColors.actionPrimary.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'book_consultation'.tr,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GetSupportedCta extends StatelessWidget {
  const _GetSupportedCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: KpbColors.whatsapp,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: KpbColors.whatsapp.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
