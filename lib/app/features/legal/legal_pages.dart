import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/utils/external_link.dart';

// Destinataires dérivés du code (PRIV-T1 / PRIV-T4) : OpenRouter, Groq,
// Firebase (dont Cloud Messaging), OneSignal (anciennes versions, repli
// serveur), PostHog, Supabase, Resend, Mautic, backend KPB
// (kpbeducation.cloud), PayDunya, CinetPay.
// Permissions : caméra, photo, micro, notifications, biométrie, localisation.
// Les corps vivent dans AppTranslations ; cette liste garde les noms dans CE
// fichier pour la garde qui lit legal_pages.dart.

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Screen
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy'.tr),
        backgroundColor: context.kpb.pageBg,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: context.kpb.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'privacy_policy'.tr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.kpb.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'last_updated_october_2026'.tr,
              style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.lg),
            // §1 nomme l'éditeur : KPB Global L.L.C-FZ, Meydan Free Zone,
            // licence 2537631.01 — voir 'privacy_s1_body'. Le corps vit dans
            // AppTranslations, la garde legal_identity_test lit les deux.
            _LegalSection(
              title: 'privacy_s1_title'.tr,
              body: 'privacy_s1_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s2_title'.tr,
              body: 'privacy_s2_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s3_title'.tr,
              body: 'privacy_s3_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s4_title'.tr,
              body: 'privacy_s4_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s5_title'.tr,
              body: 'privacy_s5_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_transfers_title'.tr,
              body: 'privacy_transfers_body'.tr,
            ),
            // Sections du 18/10/2026 (décisions du propriétaire) : communauté,
            // bots Vérif et Passerelle, parrainage et compétition, nationalité.
            // Rédigé le 18/10/2026 — à relire par le propriétaire avant
            // soumission.
            _LegalSection(
              title: 'privacy_community_title'.tr,
              body: 'privacy_community_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_bots_title'.tr,
              body: 'privacy_bots_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_referral_title'.tr,
              body: 'privacy_referral_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_nationality_title'.tr,
              body: 'privacy_nationality_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s6_title'.tr,
              body: 'privacy_s6_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s7_title'.tr,
              body: 'privacy_s7_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s8_title'.tr,
              body: 'privacy_s8_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s9_title'.tr,
              body: 'privacy_s9_body'.tr,
            ),
            _LegalSection(
              title: 'privacy_s10_title'.tr,
              body: 'privacy_s10_body'.tr,
            ),
            const SizedBox(height: KpbSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service Screen
// ─────────────────────────────────────────────────────────────────────────────
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('terms_of_use_2'.tr),
        backgroundColor: context.kpb.pageBg,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: context.kpb.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'terms_of_use'.tr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.kpb.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'last_updated_october_2026'.tr,
              style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.lg),
            _LegalSection(
              title: 'terms_s1_title'.tr,
              body:
                  'Les présentes Conditions Générales d\'Utilisation (ci-après "CGU") régissent l\'accès et l\'utilisation de l\'application mobile KPB Education, éditée par KPB Global L.L.C-FZ (Meydan Free Zone, Dubaï, Émirats arabes unis).\n\n'
                  'L\'application fournit des services d\'orientation, d\'information et d\'accompagnement pour les étudiants souhaitant poursuivre leurs études à l\'étranger.',
            ),
            _LegalSection(
              title: 'terms_s2_title'.tr,
              body:
                  'En créant un compte et en utilisant l\'application, vous acceptez sans réserve les présentes CGU.\n\n'
                  'Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser l\'application.',
            ),
            _LegalSection(
              title: 'terms_s3_title'.tr,
              body:
                  '• L\'inscription est gratuite et ouverte aux étudiants, parents et partenaires institutionnels\n'
                  '• Vous devez fournir des informations exactes et à jour\n'
                  '• Vous êtes responsable de la confidentialité de votre mot de passe\n'
                  '• Vous devez être âgé d\'au moins 16 ans pour créer un compte',
            ),
            _LegalSection(
              title: 'terms_s4_title'.tr,
              body: 'KPB Education propose :\n\n'
                  '• Un test d\'orientation personnalisé\n'
                  '• Un catalogue de filières, pays, institutions, programmes et bourses\n'
                  '• Un système de mise en relation avec des conseillers\n'
                  '• Un suivi de dossiers de candidature\n'
                  '• Des contenus éducatifs (articles, guides)\n\n'
                  'Les informations fournies sont à titre indicatif et ne constituent pas un engagement contractuel de résultat.',
            ),
            // Mesure d'audience — ACTIVE PAR DÉFAUT, donc annoncée ici et pas
            // seulement dans la politique de confidentialité : un défaut qui
            // collecte doit se lire dans le contrat qu'on accepte, pas
            // uniquement dans l'annexe qu'on ouvre rarement.
            //
            // Titre ET corps passent par `.tr`, contrairement aux sections
            // voisines dont le corps est un littéral français : en anglais,
            // celles-là rendent du français (voir la revue i18n).
            _LegalSection(
              title: 'terms_analytics_title'.tr,
              body: 'terms_analytics_body'.tr,
            ),
            _LegalSection(
              title: 'terms_s5_title'.tr,
              body:
                  'Certains services d\'accompagnement (suivi de dossier, consultation personnalisée) peuvent être soumis à des frais.\n\n'
                  'Les tarifs sont affichés avant toute souscription. Aucun paiement n\'est prélevé sans votre consentement explicite.',
            ),
            _LegalSection(
              title: 'terms_s6_title'.tr,
              body: 'Vous vous engagez à :\n\n'
                  '• Utiliser l\'application de manière loyale et conformément aux lois en vigueur\n'
                  '• Ne pas fournir de fausses informations\n'
                  '• Ne pas tenter d\'accéder de manière non autorisée aux systèmes de KPB Education\n'
                  '• Respecter les autres utilisateurs dans les espaces communautaires\n'
                  '• Ne pas utiliser l\'application à des fins commerciales non autorisées',
            ),
            // Communauté (charte en quatre règles) et compétition des
            // ambassadeurs (renvoi au règlement). Rédigé le 18/10/2026 — à
            // relire par le propriétaire avant soumission.
            _LegalSection(
              title: 'terms_community_title'.tr,
              body: 'terms_community_body'.tr,
            ),
            _LegalSection(
              title: 'terms_competition_title'.tr,
              body: 'terms_competition_body'.tr,
            ),
            _LegalSection(
              title: 'terms_s7_title'.tr,
              body:
                  'L\'ensemble des contenus de l\'application (textes, images, logos, code source) est la propriété de KPB Education ou de ses partenaires et est protégé par les lois relatives à la propriété intellectuelle.\n\n'
                  'Toute reproduction ou diffusion non autorisée est interdite.',
            ),
            _LegalSection(
              title: 'terms_s8_title'.tr,
              body:
                  'KPB Education s\'efforce de fournir des informations exactes et à jour, mais ne garantit pas :\n\n'
                  '• L\'exactitude ou l\'exhaustivité des informations sur les programmes, bourses ou institutions\n'
                  '• L\'obtention d\'une admission ou d\'une bourse\n'
                  '• La disponibilité continue et ininterrompue de l\'application\n\n'
                  'KPB Education ne saurait être tenu responsable des décisions prises par l\'utilisateur sur la base des informations fournies.',
            ),
            _LegalSection(
              title: 'terms_s9_title'.tr,
              body:
                  '• Vous pouvez supprimer votre compte à tout moment depuis les paramètres de l\'application\n'
                  '• KPB Education se réserve le droit de suspendre ou supprimer un compte en cas de violation des présentes CGU\n'
                  '• En cas de résiliation, vos données personnelles seront traitées conformément à notre Politique de Confidentialité',
            ),
            // §10 nomme la loi (Émirats arabes unis) et la juridiction
            // (Dubaï) — voir 'terms_s10_body'.
            _LegalSection(
              title: 'terms_s10_title'.tr,
              body: 'terms_s10_body'.tr,
            ),
            _LegalSection(
              title: 'terms_s11_title'.tr,
              body: 'terms_s11_body'.tr,
            ),
            const SizedBox(height: KpbSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Section Widget — texte sélectionnable, adresses cliquables
// ─────────────────────────────────────────────────────────────────────────────
class _LegalSection extends StatefulWidget {
  const _LegalSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  State<_LegalSection> createState() => _LegalSectionState();
}

class _LegalSectionState extends State<_LegalSection> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final _linkPattern = RegExp(
    r'(https://[^\s]+)|([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})',
  );

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(Color bodyColor, Color linkColor) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _linkPattern.allMatches(widget.body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.body.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final uri = token.contains('@')
          ? Uri(scheme: 'mailto', path: token)
          : Uri.parse(token);
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          kpbOpenExternalUrl(uri);
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.body.length) {
      spans.add(TextSpan(text: widget.body.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = context.kpb.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.kpb.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: bodyColor,
                height: 1.6,
              ),
              children: _spans(bodyColor, KpbColors.actionPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
