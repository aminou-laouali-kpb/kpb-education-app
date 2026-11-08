/// Ce que l'historique du dossier peut montrer à l'élève sous un titre
/// (revue avant la 58, constat 36, et sa relecture sur la PR #407).
///
/// Les descriptions viennent de la base TELLES QUELLES. Tant que la reprise
/// serveur (`backend/src/modules/cases/legacy-english-copy.ts`, script
/// `backfill:cases-fr`) n'a pas tourné, elles peuvent être au « vous »
/// (« Votre dossier a été attribué à … ») ou dans l'anglais interne d'avant
/// (« Auto-reassigned after 10h inactivity to … », « round-robin »).
///
/// Deux temps, et l'ordre compte :
///  1. on réécrit au « tu » les phrases que nos services ont EUX-MÊMES écrites
///     — la même table que la reprise serveur, dont le test
///     `case_timeline_copy_test.dart` vérifie qu'elle reste identique ;
///  2. on n'affiche le résultat que s'il ne vouvoie pas et ne contient aucun
///     mot anglais ou interne. Une phrase inconnue qui échoue est MASQUÉE :
///     l'élève voit le titre seul, comme avant, jamais du jargon.
library;

class _Regle {
  const _Regle(this.motif, this.cible);

  /// Motif ancré `^…$` ; `(.+)` capture le nom ou le titre reporté.
  final String motif;

  /// Remplacement ; `$1` reporte le segment capturé.
  final String cible;
}

/// Trace exacte des écritures d'avant (anglais, puis français au « vous ») des
/// colonnes `CaseTimelineEvent.description` et `Case.nextStepDescription` —
/// `update()` recopie la seconde dans la première.
const _regles = <_Regle>[
  // Anglais d'avant la traduction.
  _Regle(r'^The student created a new case from the mobile app\.$',
      'Ta demande a été créée depuis l’application.'),
  _Regle(r'^(.+) was assigned automatically \(round-robin\)\.$',
      r'Ton dossier a été attribué à $1.'),
  _Regle(r'^The case was updated by an admin or counselor\.$',
      'Le dossier a été mis à jour par l’équipe KPB.'),
  _Regle(r'^A new service message was added to the case\.$',
      'Un nouveau message a été ajouté au dossier.'),
  _Regle(r'^(.+) was uploaded to the case\.$',
      r'Le document « $1 » a été ajouté au dossier.'),
  _Regle(r'^(.+) scheduled a follow-up on this case\.$',
      r'$1 a programmé un point de suivi sur ton dossier.'),
  _Regle(r'^(.+) is now the owner of this case\.$',
      r'$1 suit désormais ton dossier.'),
  _Regle(r'^(.+) was added to the case workflow\.$',
      r'L’action « $1 » a été ajoutée à ton dossier.'),
  _Regle(r'^Auto-reassigned after 10h inactivity to (.+)\.$',
      r'Ton dossier a été réattribué à $1.'),
  _Regle(r'^The KPB team will review your request and assign a counselor\.$',
      'L’équipe KPB va examiner ta demande et t’attribuer un conseiller.'),
  _Regle(
      r'^(.+) has been assigned to your case and will contact you shortly\.$',
      r'$1 suit ton dossier et te contactera bientôt.'),
  _Regle(r'^Confirm your availability and prepare your supporting documents\.$',
      'Confirme ta disponibilité et prépare tes pièces justificatives.'),
  _Regle(
      r'^Your counselor will qualify your profile and contact you shortly\.$',
      'Ton conseiller va étudier ton profil et te contactera bientôt.'),
  // Français au « vous » d'avant la revue de la 58.
  _Regle(r'^Votre demande a été créée depuis l’application\.$',
      'Ta demande a été créée depuis l’application.'),
  _Regle(r'^Votre dossier a été attribué à (.+)\.$',
      r'Ton dossier a été attribué à $1.'),
  _Regle(r'^(.+) a programmé un point de suivi sur votre dossier\.$',
      r'$1 a programmé un point de suivi sur ton dossier.'),
  _Regle(r'^(.+) suit désormais votre dossier\.$',
      r'$1 suit désormais ton dossier.'),
  _Regle(r'^L’action « (.+) » a été ajoutée à votre dossier\.$',
      r'L’action « $1 » a été ajoutée à ton dossier.'),
  _Regle(r'^Votre dossier a été réattribué à (.+)\.$',
      r'Ton dossier a été réattribué à $1.'),
  _Regle(
      r'^L’équipe KPB va examiner votre demande et vous attribuer un conseiller\.$',
      'L’équipe KPB va examiner ta demande et t’attribuer un conseiller.'),
  _Regle(r'^(.+) suit votre dossier et vous contactera prochainement\.$',
      r'$1 suit ton dossier et te contactera bientôt.'),
  _Regle(
      r'^Confirmez votre disponibilité et préparez vos pièces justificatives\.$',
      'Confirme ta disponibilité et prépare tes pièces justificatives.'),
  _Regle(
      r'^Votre conseiller va étudier votre profil et vous contactera prochainement\.$',
      'Ton conseiller va étudier ton profil et te contactera bientôt.'),
];

/// « rendez-vous » n'est pas un vouvoiement : le trait d'union l'exclut.
final _vouvoiement = RegExp(r'(^|[^\p{L}-])(votre|vos|vous)(?![\p{L}-])',
    caseSensitive: false, unicode: true);

/// Mots anglais courants ou vocabulaire interne : la moindre trace masque la
/// description. Large exprès — un faux positif coûte une ligne, un faux
/// négatif montre « round-robin » à un élève.
final _anglaisOuInterne = RegExp(
  r'(^|[^\p{L}])(the|your|you|was|were|has|have|been|will|please|thank|'
  r'to|of|and|for|is|are|this|that|with|by|be|internal|lead|follow|'
  r'counselor|counsellor|uploaded|assigned|request|case|admin|owner|workflow|'
  r'round-robin|inactivity|auto-reassigned|student)(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// La description à afficher sous le titre, ou `null` pour n'afficher que le
/// titre.
String? studentTimelineDescription(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  for (final regle in _regles) {
    final re = RegExp(regle.motif, dotAll: true);
    final m = re.firstMatch(text);
    if (m != null) {
      text = m.groupCount >= 1
          ? regle.cible.replaceAll(r'$1', m.group(1)!)
          : regle.cible;
      break;
    }
  }
  if (_vouvoiement.hasMatch(text) || _anglaisOuInterne.hasMatch(text)) {
    return null;
  }
  return text;
}
