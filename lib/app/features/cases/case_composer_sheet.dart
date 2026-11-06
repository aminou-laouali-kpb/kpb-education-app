import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import 'case_tunnel_flow.dart';

class CaseComposerSheet extends StatelessWidget {
  const CaseComposerSheet({
    super.key,
    required this.caseType,
    required this.title,
    required this.contextLabel,
    this.countryId,
    this.institutionId,
    this.programId,
    this.scholarshipId,
  });

  final CaseType caseType;
  final String title;
  final String contextLabel;
  final String? countryId;
  final String? institutionId;
  final String? programId;

  /// La bourse liée, transmise au dossier (`POST /cases`).
  final String? scholarshipId;

  @override
  Widget build(BuildContext context) {
    // La feuille peint son propre fond : trois appelants l'ouvrent avec
    // `backgroundColor: Colors.transparent`, et depuis une fiche bourse le
    // formulaire se mêlait à la page dessous (audit build 57, n° 5b).
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey<String>('case-composer-sheet-surface'),
      color:
          theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KpbRadius.xl),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: CaseTunnelFlow(
          prefill: CaseTunnelPrefill(
            title: title,
            contextLabel: contextLabel,
            initialType: caseType,
            countryId: countryId,
            institutionId: institutionId,
            programId: programId,
            scholarshipId: scholarshipId,
          ),
          onClose: () => Navigator.of(context).pop(),
          // Un seul bandeau après « Soumettre » : celui de `submitCase`. Le
          // second, posé ici, doublait le premier (audit build 57, T4-16).
          onSubmitted: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
