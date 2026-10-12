part of '../home_screen.dart';

// Carte « Étudier à l'étranger » et sa feuille de pays.

class _AbroadEnrollmentCard extends StatelessWidget {
  const _AbroadEnrollmentCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAbroadCountriesSheet(context, controller),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
            color: KpbColors.warning.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: KpbColors.warning.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Premium World Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KpbColors.warning,
                    borderRadius: KpbRadius.mdBr,
                    boxShadow: [
                      BoxShadow(
                        color: KpbColors.warning.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'register_abroad_title'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KpbColors.warning.withValues(alpha: 0.15),
                              borderRadius: KpbRadius.xsBr,
                              border: Border.all(
                                color: KpbColors.warning.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'home_badge_guidance'.tr,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: KpbColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'home_apply_world_desc'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: KpbColors.textFaint,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            // Footer with dynamic flag list & CTA
            Row(
              children: [
                // Horizontal Row of Flags
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: const [
                        'canada',
                        'usa',
                        'uk',
                        'germany',
                        'morocco'
                      ]
                          .map((id) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: KpbRadius.xsBr,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _flag(id),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // CTA text & arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'discover'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: KpbColors.warning,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: KpbColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showAbroadCountriesSheet(BuildContext context, AppController controller) {
  final targetCountryIds = ['canada', 'usa', 'uk', 'germany', 'morocco'];
  final countries = targetCountryIds
      .map((id) => controller.countries.firstWhereOrNull((c) => c.id == id))
      .whereType<CountryModel>()
      .toList();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: EdgeInsets.only(
          left: KpbSpacing.lg,
          right: KpbSpacing.lg,
          top: KpbSpacing.md,
          bottom: KpbSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: KpbRadius.pillBr,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header Title
            Row(
              children: [
                Text(
                  'register_abroad_cta'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "🌍",
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'home_destinations_desc'.tr,
              style: TextStyle(
                fontSize: 13,
                color: KpbColors.textFaint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // List of countries
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: countries.map((country) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: KpbColors.brandNavy,
                        borderRadius: KpbRadius.mdBr,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: KpbRadius.mdBr,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Get.back();
                              Get.to(() =>
                                  CountryDetailScreen(countryId: country.id));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(KpbSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Flag circular badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _flag(country.id),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Text contents
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              controller.resolve(country.name),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            // Difficulty Badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.05),
                                                borderRadius: KpbRadius.xsBr,
                                              ),
                                              child: Text(
                                                'home_admission_prefix'
                                                    .trParams({
                                                  'value': controller.resolve(
                                                      country
                                                          .admissionDifficulty)
                                                }),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: KpbColors
                                                      .textDarkSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          controller.resolve(country.whyStudy),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: KpbColors.textFaint,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Budget Row
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.payments_outlined,
                                              size: 14,
                                              color: KpbColors.warning,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'tuition_prefix'.tr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              controller.resolve(
                                                  country.tuitionRange),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: KpbColors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right Chevron
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Tools Banner — CV generator + Letters shortcut
// ─────────────────────────────────────────────────────────────────────────────
