import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_toast.dart';
import '../../../core/utils/external_link.dart';

/// « Voir la condition officielle » : la citation EXACTE de l'organisme et
/// le lien vers sa source. Fermé par défaut. C'est le SEUL texte de l'écran
/// qui peut contenir « % » — c'est celui de l'organisme, pas celui de KPB.
class OfficialConditionExpander extends StatefulWidget {
  const OfficialConditionExpander({super.key, required this.official});

  final MatchOfficialCondition official;

  @override
  State<OfficialConditionExpander> createState() =>
      _OfficialConditionExpanderState();
}

class _OfficialConditionExpanderState extends State<OfficialConditionExpander> {
  bool _open = false;

  Future<void> _openSource(String url) async {
    if (await kpbOpenExternalUrlString(url)) return;
    KpbToast.error(
      'external_link_failed_body'.tr,
      title: 'external_link_failed_title'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final official = widget.official;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: TextButton.icon(
            key: const ValueKey<String>('match-official-toggle'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.xs),
            ),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(
              _open
                  ? 'scholarship_match_official_hide'.tr
                  : 'scholarship_match_official_show'.tr,
            ),
          ),
        ),
        if (_open)
          Container(
            key: const ValueKey<String>('match-official-quote'),
            width: double.infinity,
            padding: const EdgeInsets.all(KpbSpacing.sm),
            decoration: BoxDecoration(
              color: KpbColors.surfaceMuted,
              borderRadius: BorderRadius.circular(KpbRadius.sm),
              border: const Border(
                left: BorderSide(color: KpbColors.borderStrong, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'scholarship_match_official_quote_label'.tr,
                  style: KpbTextStyles.caption.copyWith(
                    color: KpbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  '« ${official.text} »',
                  key: const ValueKey<String>('match-official-text'),
                  style: KpbTextStyles.bodySm.copyWith(
                    fontStyle: FontStyle.italic,
                    color: KpbColors.textPrimary,
                  ),
                ),
                if (official.sourceUrl != null)
                  TextButton.icon(
                    key: const ValueKey<String>('match-official-source'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () =>
                        unawaited(_openSource(official.sourceUrl!)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text('scholarship_match_official_source'.tr),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
