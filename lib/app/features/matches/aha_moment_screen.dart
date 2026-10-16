import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/match_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/ui/app_tokens.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
/// Post-onboarding AHA moment (Phase 0 / P0-D — kit US-003): the first thing
/// a student sees after completing their profile is the schools that best
/// match it, each with a qualitative fit tier (never a percentage or an
/// admission probability — brand compliance).
///
/// Primary source is the backend `GET /matches/aha-moment` (deterministic
/// algorithm v1). If the call fails (offline, guest token edge, server down),
/// the screen degrades to the local AppSearchService affinity score so the
/// reveal never dead-ends — those fallback results are flagged as estimates.
class AhaMomentScreen extends StatefulWidget {
  const AhaMomentScreen({super.key});

  @override
  State<AhaMomentScreen> createState() => _AhaMomentScreenState();
}

class _AhaMomentScreenState extends State<AhaMomentScreen> {
  final AppController _ctrl = Get.find<AppController>();

  bool _loading = true;
  List<SchoolMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<SchoolMatch> matches;
    try {
      final json = await _ctrl.apiClient.getAhaMatches();
      matches = MatchApiCodec.ahaMatchesFromApi(json);
    } catch (_) {
      matches = const [];
    }
    if (matches.isEmpty) {
      matches = _localFallback();
    }
    if (!mounted) return;
    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  /// Offline/degraded path: reuse the local affinity score (0–98) and map it
  /// onto match zones through the [ProfileFit] thresholds (70/50).
  List<SchoolMatch> _localFallback() {
    final institutions = _ctrl.recommendedInstitutions.take(3);
    return institutions.map((institution) {
      final score = _ctrl.institutionMatch(institution);
      return SchoolMatch(
        institutionId: institution.id,
        institutionName: institution.name,
        programId: '',
        programName: const LocalizedText(fr: '', en: ''),
        probability: score / 100,
        zone: score >= 70
            ? SchoolMatchZone.green
            : score >= 50
                ? SchoolMatchZone.yellow
                : SchoolMatchZone.blue,
        isEstimate: true,
        algorithmVersion: 'local',
        factors: const [],
        narrative: const LocalizedText(fr: '', en: ''),
      );
    }).toList();
  }

  void _goHome() => Get.offAllNamed(AppRoutes.home);

  void _seeAllUniversities() {
    _ctrl.goToTab(StudentShellTab.universities);
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.brandNavy,
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(KpbColors.decorSky),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'aha_loading'.tr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KpbColors.textFaint,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 30)),
                        const SizedBox(height: 10),
                        Text(
                          _headline(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _matches.isEmpty
                              ? 'aha_empty_body'.tr
                              : 'aha_subtitle'.tr,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: KpbColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _matches.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                            itemCount: _matches.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _MatchCard(match: _matches[index]),
                          ),
                  ),
                  if (_matches.any((m) => m.isEstimate)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'aha_estimate_note'.tr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: KpbColors.textFaint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _seeAllUniversities,
                            style: FilledButton.styleFrom(
                              backgroundColor: KpbColors.actionPrimary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Flexible : « Voir toutes les universités »
                                // dépasse les 264 pt du bouton dès ×1,3 sur un
                                // Android 360 dp. Le libellé passe à la ligne,
                                // jamais coupé ni débordant.
                                Flexible(
                                  child: Text(
                                    'aha_see_all_cta'.tr,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 17),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _goHome,
                          style: TextButton.styleFrom(
                            foregroundColor: KpbColors.textFaint,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: Text(
                            'aha_cta'.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Personalizes with the student's real first name + real match count when
  /// available; falls back to the generic title otherwise (never a fabricated
  /// name or count).
  String _headline() {
    final firstName = (_ctrl.profile?.fullName ?? '').trim().split(' ').first;
    if (firstName.isEmpty || _matches.isEmpty) return 'aha_title'.tr;
    return 'aha_title_named'
        .trParams({'name': firstName, 'count': '${_matches.length}'});
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final SchoolMatch match;

  String get _zoneKey => switch (match.zone) {
        SchoolMatchZone.green => 'aha_zone_green',
        SchoolMatchZone.yellow => 'aha_zone_yellow',
        SchoolMatchZone.blue => 'aha_zone_blue',
      };

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final locale = ctrl.localeCode;
    final institutionName = match.institutionName.resolve(locale);
    final programName = match.programName.resolve(locale);
    final narrative = match.narrative.resolve(locale);

    // Enrich with real catalog data (flag/city/fees) when we can resolve the
    // institution — never fabricated, just a lookup by the same institutionId
    // the match already carries.
    final institution = ctrl.institutionByIdOrNull(match.institutionId);
    final country = institution == null
        ? null
        : ctrl.countryByIdOrNull(institution.countryId);
    final flag = country?.flagEmoji ?? '';
    final location =
        institution == null ? '' : ctrl.resolve(institution.location);
    final fees =
        institution == null ? '' : ctrl.resolve(institution.tuitionLabel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (flag.isNotEmpty) ...[
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  institutionName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Palier qualitatif seulement : la probabilité serveur sert au
              // tri, jamais à l'affichage (conformité : aucun pourcentage).
              ProfileFitBadge(fit: ProfileFit.fromZone(match.zone)),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              location,
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (programName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              programName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: KpbColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          Text(_zoneKey.tr,
              style: const TextStyle(fontSize: 11, color: KpbColors.textFaint)),
          if (narrative.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              narrative,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: KpbColors.gray700,
              ),
            ),
          ],
          if (fees.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fees,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: KpbColors.actionPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
