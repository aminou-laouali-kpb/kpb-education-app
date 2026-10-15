import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/app_tokens.dart';
import '../scholarships/scholarship_detail_screen.dart';
import '../scholarships/widgets/follow_scholarship_button.dart';

/// Home "Bourse du jour" card (KPB-162). Self-fetches today's featured
/// scholarship; renders nothing until loaded and self-hides when none is
/// available or on error. The "nouveau" badge marks the daily refresh.
class DailyScholarshipCard extends StatefulWidget {
  const DailyScholarshipCard({super.key});

  @override
  State<DailyScholarshipCard> createState() => _DailyScholarshipCardState();
}

class _DailyScholarshipCardState extends State<DailyScholarshipCard> {
  final _ctrl = Get.find<AppController>();
  LiveScholarshipModel? _daily;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LiveScholarshipModel? daily;
    try {
      final lang = Get.locale?.languageCode == 'en' ? 'en' : 'fr';
      daily = await _ctrl.apiClient.fetchDailyScholarship(lang: lang);
    } catch (_) {
      // Best-effort: any failure just hides the card.
      daily = null;
    }
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _loaded = true;
    });
    if (daily != null) {
      unawaited(AnalyticsService.instance.logDailyScholarshipViewed(daily.id));
    }
  }

  void _open(LiveScholarshipModel s) {
    AnalyticsService.instance.logDailyScholarshipOpened(s.id);
    Get.to(
      () => ScholarshipDetailScreen(
        scholarshipId: s.id,
        initialScholarship: s,
        apiClient: _ctrl.apiClient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _daily;
    if (!_loaded || s == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
      child: Material(
        color: KpbColors.actionPrimarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _open(s),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'daily_scholarship_title'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: KpbColors.actionPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: KpbColors.actionPrimary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'daily_scholarship_badge_new'.tr,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                      if (s.countryName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.countryName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: KpbColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FollowScholarshipButton(
                  scholarshipId: s.id,
                  scholarshipTitle: s.title,
                  variant: FollowButtonVariant.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
