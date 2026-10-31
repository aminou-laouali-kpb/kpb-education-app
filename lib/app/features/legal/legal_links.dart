import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/utils/whatsapp_utils.dart';
import 'legal_pages.dart';

/// Les liens que l'élève cherche avant de donner son adresse : confidentialité,
/// conditions d'utilisation, et un moyen de joindre KPB.
///
/// Ils vivaient seulement dans la page Profil d'un élève connecté : un invité,
/// sur le mur du Profil ou sur l'écran d'entrée, n'avait aucun moyen de lire ce
/// à quoi il consent avant de créer un compte (audit build 57, T1-20, T4-35,
/// T6-08). Un public méfiant envers les arnaques regarde d'abord cela.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key, this.showContact = false});

  /// Ajoute « Nous contacter » (WhatsApp, ligne officielle de KPB).
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: KpbColors.textMuted,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          key: const ValueKey<String>('legal-link-privacy'),
          style: style,
          onPressed: () => Get.to<void>(() => const PrivacyPolicyScreen()),
          child: Text('profile_privacy_policy'.tr),
        ),
        TextButton(
          key: const ValueKey<String>('legal-link-terms'),
          style: style,
          onPressed: () => Get.to<void>(() => const TermsOfServiceScreen()),
          child: Text('profile_terms_of_service'.tr),
        ),
        if (showContact)
          TextButton(
            key: const ValueKey<String>('legal-link-contact'),
            style: style,
            onPressed: () => openWhatsAppOrToast(
              phone: AppConfig.whatsappNumber,
              prefill: kpbWhatsAppPrefill(),
              source: 'legal_links',
              contextType: 'contact',
            ),
            child: Text('legal_links_contact'.tr),
          ),
      ],
    );
  }
}
