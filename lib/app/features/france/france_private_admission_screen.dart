import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/intake_calendar.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../explore/program_detail_screen.dart';

/// M7 — Admission France écoles privées. La campagne affichée est calculée
/// par [IntakeCalendar] : la build vit ~90 jours, et « septembre 2026 » écrit
/// en dur serait devenu faux le 1er octobre, sans correctif possible côté
/// contenu.
class FrancePrivateAdmissionScreen extends StatelessWidget {
  const FrancePrivateAdmissionScreen({super.key});

  static List<String> get _processSteps => [
        'france_step_choose_school'.tr,
        'france_step_build_dossier'.tr,
        'france_step_interview_validation'.tr,
        'france_step_student_visa'.tr,
        'france_step_housing_departure'.tr,
        'france_step_arrival'.tr,
      ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final partners = controller.institutions
        .where(
          (i) =>
              (i.countryId == 'fra' || i.countryId == 'france') && i.isPartner,
        )
        .toList();
    final francePrograms = controller.programs
        .where((p) => p.countryId == 'fra' || p.countryId == 'france')
        .length;

    // ── L'en-tête qui débordait de 88 px à la POLICE NORMALE (FLU-07) ──────
    //
    // L'ancienne version écrivait `expandedHeight: 220` et un padding haut de
    // 96 px en dur. Trois erreurs empilées : le padding doublait l'encoche que
    // le SliverAppBar absorbe déjà dans son étendue ; le titre de 24 px passe
    // sur DEUX lignes dès 360 px de large, ce que la hauteur figée ignorait ;
    // et rien ne grandissait avec l'échelle de texte. Résultat mesuré par la
    // matrice d'écrans : 41 px de débordement sur iPhone 14 et 64 px sur
    // Android compact À L'ÉCHELLE 1,0 — l'écran d'un module vitrine, atteint
    // en trois taps, rayé de jaune pour tout le monde.
    //
    // La hauteur est désormais MESURÉE, pas estimée. Première tentative
    // instructive : une somme de « hauteurs de ligne raisonnables » laissait
    // encore 26 px de débordement, parce qu'un glyphe émoji (le drapeau en
    // 44 pt) est bien plus haut que fontSize × 1,3. On fait donc mesurer
    // chaque bloc par le moteur de texte lui-même, avec la même largeur, la
    // même échelle et le même maxLines que le rendu — la hauteur et le contenu
    // ne peuvent plus diverger, c'est le même calcul.
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = MediaQuery.sizeOf(context).width - 48; // padding 24+24
    final subtitleText = '${'france_sept_intake'.trParams({
          'intake': IntakeCalendar.label()
        })} · $francePrograms ${'programs_available'.tr}';

    // Le style est FUSIONNÉ avec celui que les Text hériteront réellement.
    // Deux pièges mesurés ici même : (1) sans fusion, la mesure ignore le
    // `height: 1.43` du thème Material et rend chaque ligne ~30 % trop courte
    // — 48 px pour un titre qui en occupe 68 ; (2) `DefaultTextStyle.of` ne
    // suffit PAS, parce que ce `build` s'exécute AU-DESSUS du Scaffold : c'est
    // le widget Material du Scaffold qui installera `bodyMedium` pour ses
    // descendants. On prend donc le style à sa source, le thème.
    final ambientStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    double measure(String text, TextStyle style, {int maxLines = 2}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: ambientStyle.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: textWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final headerHeight = 12 + // respiration au-dessus du drapeau
        measure(displayCountryFlag(id: 'fra'), const TextStyle(fontSize: 44),
            maxLines: 1) +
        8 +
        measure('france_admission_title'.tr,
            const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)) +
        6 +
        measure(subtitleText, const TextStyle(fontSize: 13)) +
        20; // marge basse

    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: headerHeight,
            pinned: true,
            backgroundColor: KpbColors.navy,
            foregroundColor: Colors.white,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: KpbColors.heroGradient),
                // L'encoche vient de MediaQuery, pas d'un « 96 » qui la
                // devinait : l'étendue du SliverAppBar vaut
                // topPadding + expandedHeight, et ce padding-ci est le seul à
                // devoir la connaître.
                padding: EdgeInsets.fromLTRB(24, topPadding + 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      displayCountryFlag(id: 'fra'),
                      style: const TextStyle(fontSize: 44),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'france_admission_title'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.kpb.gray100,
                      borderRadius: KpbRadius.mdBr,
                      border: Border.all(color: context.kpb.gray200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: context.kpb.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'france_public_unis_soon'.trParams({
                              'intake': IntakeCalendar.label(capitalized: true)
                            }),
                            style: KpbTextStyles.bodySm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'france_why_private'.tr,
                          style: KpbTextStyles.titleMd,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'france_private_intro'.tr,
                          style: KpbTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route_outlined,
                                color: KpbColors.blue, size: 20),
                            const SizedBox(width: 8),
                            // Expanded : à l'échelle 1,3 sur 360 px, ce titre
                            // débordait de 1,3 px sur la droite — le second
                            // débordement de FLU-07.
                            Expanded(
                              child: Text('france_path_steps'.tr,
                                  style: KpbTextStyles.titleMd),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _processSteps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: KpbColors.blue,
                                  borderRadius: KpbRadius.smBr,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _processSteps[i],
                                  style: KpbTextStyles.bodySm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('france_partner_schools_title'.tr,
                      style: KpbTextStyles.titleMd),
                  const SizedBox(height: 10),
                  if (partners.isEmpty)
                    KpbCard(
                      child: Text(
                        'france_sync_catalog'.tr,
                        style: KpbTextStyles.bodySm,
                      ),
                    )
                  else
                    ...partners.map(
                      (inst) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: KpbCard(
                          onTap: () {
                            final program =
                                controller.programs.firstWhereOrNull(
                              (p) => p.institutionId == inst.id,
                            );
                            if (program != null) {
                              Get.to(
                                () => ProgramDetailScreen(
                                  programId: program.id,
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: context.kpb.skyLight,
                                  borderRadius: KpbRadius.mdBr,
                                ),
                                child: const Icon(
                                  Icons.account_balance_outlined,
                                  color: KpbColors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.resolve(inst.name),
                                      style: KpbTextStyles.titleMd,
                                    ),
                                    Text(
                                      controller.resolve(inst.location),
                                      style: KpbTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              KpbBadge(
                                label: 'saved_partner_badge'.tr,
                                color: KpbColors.success,
                                small: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          12,
          KpbSpacing.pagePad,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: context.kpb.cardBg,
          border: Border(top: BorderSide(color: context.kpb.gray100)),
        ),
        child: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => CaseComposerSheet(
              caseType: CaseType.applicationSupport,
              title: 'france_case_title'.tr,
              contextLabel: 'france_case_context_label'.trParams(
                  {'intake': IntakeCalendar.label(capitalized: true)}),
              countryId: 'fra',
            ),
          ),
          child: Text('france_start_procedure'.tr),
        ),
      ),
    );
  }
}
