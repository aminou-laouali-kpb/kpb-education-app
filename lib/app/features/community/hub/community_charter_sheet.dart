import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_toast.dart';
import '../../../core/ui/kpb_haptics.dart';
import 'community_format.dart';

/// Peut-on écrire (publier, répondre, « utile ») ? Vérifie, dans l'ordre :
/// la fiche membre (chargée au besoin), une restriction (lecture seule,
/// bannissement), puis la charte courante — affichée si elle n'a pas encore
/// été acceptée (première publication ou nouvelle version).
Future<bool> ensureCommunityCanWrite(BuildContext context) async {
  final store = CommunityStore.instance;
  final me = await store.loadMe();
  if (!context.mounted) return false;
  if (me == null) {
    final failure = store.meFailure ?? CommunityFailure.server;
    KpbToast.error(
      communityFailureMessage(CommunityException(failure)),
      context: context,
    );
    return false;
  }
  final restriction = me.restriction;
  if (restriction != null) {
    await showCommunityRestrictionSheet(context, restriction);
    return false;
  }
  if (!me.charterRequired) return true;
  return showCommunityCharterSheet(context);
}

/// La feuille de la charte : quatre règles courtes et « J'ai compris ».
/// Rend vrai quand le serveur a enregistré l'acceptation.
Future<bool> showCommunityCharterSheet(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: KpbColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.lg)),
    ),
    builder: (_) => const CommunityCharterSheet(),
  );
  return accepted ?? false;
}

/// Les quatre règles, servies par le serveur dans la langue de l'app ; les
/// textes embarqués ne servent que si le serveur n'en a pas fourni.
List<CommunityCharterRule> communityCharterRules(CommunityCharter? charter) {
  final served = charter?.rules ?? const <CommunityCharterRule>[];
  if (served.isNotEmpty) return served;
  return <CommunityCharterRule>[
    for (var i = 1; i <= 4; i++)
      CommunityCharterRule(
        id: 'local_$i',
        title: 'comm_charter_rule_${i}_title'.tr,
        body: 'comm_charter_rule_${i}_body'.tr,
      ),
  ];
}

class CommunityCharterSheet extends StatefulWidget {
  const CommunityCharterSheet({super.key});

  @override
  State<CommunityCharterSheet> createState() => _CommunityCharterSheetState();
}

class _CommunityCharterSheetState extends State<CommunityCharterSheet> {
  bool _saving = false;

  static const _icons = <IconData>[
    Icons.favorite_border_rounded,
    Icons.money_off_rounded,
    Icons.phonelink_lock_rounded,
    Icons.fact_check_outlined,
  ];

  Future<void> _accept() async {
    setState(() => _saving = true);
    final ok = await CommunityStore.instance.acceptCharter();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      unawaited(KpbHaptics.success());
      unawaited(AnalyticsService.instance.logCommunityCharterAccepted());
      Navigator.of(context).pop(true);
    } else {
      KpbToast.error('comm_charter_failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charter = CommunityStore.instance.me?.charter;
    final rules = communityCharterRules(charter);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.page, KpbSpacing.md, KpbSpacing.page, 0),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KpbColors.borderStrong,
                        borderRadius: KpbRadius.pillBr,
                      ),
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      charter?.title ?? 'comm_charter_title'.tr,
                      style: KpbTextStyles.titleLg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'comm_charter_intro'.tr,
                    style: KpbTextStyles.bodySm,
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  for (var i = 0; i < rules.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KpbSpacing.sm + 4),
                      child: MergeSemantics(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: KpbColors.actionPrimarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icons[i % _icons.length],
                                size: 18,
                                color: KpbColors.actionPrimary,
                              ),
                            ),
                            const SizedBox(width: KpbSpacing.sm + 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rules[i].title,
                                    style: KpbTextStyles.titleMd,
                                  ),
                                  if (rules[i].body.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      rules[i].body,
                                      style: KpbTextStyles.bodySm,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    'comm_charter_footer'.tr,
                    style: KpbTextStyles.caption,
                  ),
                  const SizedBox(height: KpbSpacing.md),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KpbSpacing.page, KpbSpacing.sm,
                  KpbSpacing.page, KpbSpacing.md),
              child: FilledButton(
                key: const ValueKey<String>('comm-charter-accept'),
                onPressed: _saving || charter == null ? null : _accept,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('comm_charter_accept'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explique une restriction (lecture seule, bannissement) avec le motif écrit
/// par l'équipe, montré au seul intéressé.
Future<void> showCommunityRestrictionSheet(
  BuildContext context,
  CommunityRestriction restriction,
) {
  final until = restriction.until;
  final title = restriction.isBan
      ? 'comm_restriction_ban_title'.tr
      : 'comm_restriction_read_only_title'.tr;
  final body = restriction.isBan
      ? 'comm_err_banned'.tr
      : until == null
          ? 'comm_err_read_only'.tr
          : 'comm_err_read_only_until'
              .trParams({'date': communityShortDate(until)});
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: KpbColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_clock_outlined,
                size: 36, color: KpbColors.warning),
            const SizedBox(height: KpbSpacing.sm),
            Text(title,
                textAlign: TextAlign.center, style: KpbTextStyles.title),
            const SizedBox(height: KpbSpacing.sm),
            Text(body, textAlign: TextAlign.center, style: KpbTextStyles.body),
            if (restriction.reason != null) ...[
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'comm_restriction_reason'
                    .trParams({'reason': restriction.reason!}),
                textAlign: TextAlign.center,
                style: KpbTextStyles.bodySm,
              ),
            ],
            const SizedBox(height: KpbSpacing.sm),
            Text(
              'comm_restriction_read_ok'.tr,
              textAlign: TextAlign.center,
              style: KpbTextStyles.caption,
            ),
            const SizedBox(height: KpbSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text('comm_got_it'.tr),
            ),
          ],
        ),
      ),
    ),
  );
}
