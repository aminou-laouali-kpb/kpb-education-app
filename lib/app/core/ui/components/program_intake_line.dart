import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/app_models.dart';
import '../../utils/program_intakes.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

/// La ligne « Rentrées : oct. 2026 · mars 2027 (décalée) » d'une formation,
/// sur toutes les cartes et listes de formations, et en tête de la fiche.
///
/// Le résumé vient de [cachedProgramIntakeSummary] (règles dans
/// program_intakes.dart). Sans rien à dire, la ligne ne prend aucune place.
///
/// Le lecteur d'écran lit le libellé COMPLET — toutes les rentrées, mois en
/// toutes lettres, sans « + n » — et non le texte abrégé de la carte.
class ProgramIntakeLine extends StatelessWidget {
  const ProgramIntakeLine({
    super.key,
    required this.program,
    this.institution,
    this.color,
    this.localeCode,
  });

  final ProgramModel program;

  /// L'établissement de la formation, pour le repli « Rentrées de l'école ».
  final InstitutionModel? institution;

  /// Couleur du texte et de l'icône (fond sombre de la fiche) ; par défaut,
  /// le texte secondaire du thème.
  final Color? color;

  /// Par défaut, la langue active de l'app.
  final String? localeCode;

  @override
  Widget build(BuildContext context) {
    final summary = cachedProgramIntakeSummary(
      program,
      institution: institution,
    );
    final locale = localeCode ?? Get.locale?.languageCode ?? 'fr';
    final label = summary.shortLabel(locale);
    if (label == null) return const SizedBox.shrink();
    final tint = color ?? context.kpb.textSecondary;

    return Semantics(
      container: true,
      label: summary.semanticsLabel(locale),
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('program-intake-line'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              summary.allPast
                  ? Icons.event_busy_outlined
                  : Icons.event_outlined,
              size: 14,
              color: tint,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: KpbFontSize.xs,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
