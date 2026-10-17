import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/us_visa_suspension.dart';
import '../../services/remote_feature_flags.dart';
import '../../utils/country_utils.dart';
import '../../utils/external_link.dart';
import '../../utils/whatsapp_utils.dart';
import '../kpb_components.dart';

/// Vrai pour un identifiant de pays qui désigne les États-Unis (`usa`, `us`,
/// `united states`).
bool isUnitedStatesCountryId(String? countryId) {
  final id = normalizeCountryId(countryId ?? '');
  return id == 'usa' || id == 'us';
}

/// L'avis « visas étudiants suspendus » des fiches établissement, formation et
/// pays des ÉTATS-UNIS (décision du propriétaire du 17/10/2026).
///
/// On garde les États-Unis pour tout le monde ; on informe, sobrement : un
/// encadré neutre (pas d'alerte rouge), le texte voulu par le propriétaire, la
/// page officielle et WhatsApp. Si le pays de résidence du profil est dans la
/// liste, l'avis le dit EN PREMIER ; sinon il reste général.
///
/// La liste est servie par `/config/app` ([RemoteFeatureFlags.usVisaSuspension],
/// repli embarqué) : l'encadré se reconstruit quand la réponse arrive, et
/// disparaît si le serveur sert une liste vide.
///
/// Vie privée : la comparaison au pays de l'élève est locale. Le renvoi
/// WhatsApp est mesuré avec une source et un contexte CONSTANTS, jamais avec le
/// pays ni avec « concerné / pas concerné ».
class UsVisaNotice extends StatelessWidget {
  const UsVisaNotice({
    super.key,
    required this.countryOfResidence,
    required this.localeCode,
    this.margin = EdgeInsets.zero,
  });

  /// Le pays de résidence du profil, tel que saisi ; `null` sans profil.
  final String? countryOfResidence;
  final String localeCode;
  final EdgeInsetsGeometry margin;

  /// La source mesurée du renvoi WhatsApp. Constante, voir la classe.
  static const analyticsSource = 'us_visa_notice';
  static const analyticsContext = 'us_visa';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final suspension = RemoteFeatureFlags.instance.usVisaSuspension;
        if (!suspension.isActive) return const SizedBox.shrink();
        return Padding(
          padding: margin,
          child: _UsVisaNoticeCard(
            suspension: suspension,
            concerned: suspension.concerns(countryOfResidence),
            localeCode: localeCode,
          ),
        );
      },
    );
  }
}

class _UsVisaNoticeCard extends StatelessWidget {
  const _UsVisaNoticeCard({
    required this.suspension,
    required this.concerned,
    required this.localeCode,
  });

  final UsVisaSuspension suspension;
  final bool concerned;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final verified = suspension.lastVerifiedAt;
    final sourceUrl = suspension.sourceUrl;
    return Container(
      key: const ValueKey('us_visa_notice'),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le titre est un en-tête pour TalkBack / VoiceOver : on y saute
          // directement, puis le corps et les deux boutons se lisent dans
          // l'ordre.
          Semantics(
            header: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.info_outline_rounded,
                      size: 20, color: KpbColors.textSecondary),
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    'us_visa_notice_title'.tr,
                    style: KpbTextStyles.titleSm
                        .copyWith(color: KpbColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          if (concerned) ...[
            Text(
              'us_visa_notice_concerned'.tr,
              key: const ValueKey('us_visa_notice_concerned'),
              style: KpbTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KpbColors.textPrimary,
              ),
            ),
            const SizedBox(height: KpbSpacing.xs),
          ],
          Text(
            'us_visa_notice_body'
                .trParams({'countries': suspension.namesFor(localeCode)}),
            style: KpbTextStyles.bodySm.copyWith(color: KpbColors.textPrimary),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            'us_visa_notice_check'.tr,
            style:
                KpbTextStyles.bodySm.copyWith(color: KpbColors.textSecondary),
          ),
          if (verified != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'us_visa_notice_verified'.trParams({'date': _day(verified)}),
              style: KpbTextStyles.caption.copyWith(color: KpbColors.textMuted),
            ),
          ],
          const SizedBox(height: KpbSpacing.sm),
          // `Wrap` et non `Row` : à l'échelle de texte 1,5 les deux boutons
          // passent l'un sous l'autre au lieu de déborder.
          Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.xs,
            children: [
              if (sourceUrl != null)
                KpbButton(
                  key: const ValueKey('us_visa_notice_official'),
                  variant: KpbButtonVariant.secondary,
                  icon: Icons.open_in_new_rounded,
                  label: 'us_visa_notice_official_cta'.tr,
                  onPressed: () => kpbOpenExternalUrlString(sourceUrl),
                ),
              KpbButton(
                key: const ValueKey('us_visa_notice_whatsapp'),
                variant: KpbButtonVariant.tertiary,
                icon: Icons.chat_outlined,
                label: 'us_visa_notice_whatsapp_cta'.tr,
                onPressed: () => openWhatsAppOrToast(
                  prefill: 'us_visa_whatsapp_prefill'.tr,
                  source: UsVisaNotice.analyticsSource,
                  contextType: UsVisaNotice.analyticsContext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
