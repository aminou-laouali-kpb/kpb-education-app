import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbHaptics — retours tactiles SÉMANTIQUES.
//
// Seul fichier autorisé à appeler `HapticFeedback` (budget vérifié par
// test/core/ui/ui_debt_audit_test.dart). Les écrans disent POURQUOI ils vibrent,
// jamais avec quelle intensité ; ainsi une vibration garde un sens constant
// dans toute l'app.
//
// Règle produit : on ne vibre pas à chaque tap. Une vibration accompagne un
// changement de sélection, une confirmation volontaire, ou un résultat
// (succès confirmé par le serveur, erreur bloquante).
// ─────────────────────────────────────────────────────────────────────────────
class KpbHaptics {
  KpbHaptics._();

  /// Changement de sélection : onglet, interrupteur, case, puce de filtre.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Action volontaire validée par l'utilisateur (étape suivante, ajout).
  static Future<void> confirm() => HapticFeedback.lightImpact();

  /// Résultat positif confirmé (dossier créé, parcours terminé).
  static Future<void> success() => HapticFeedback.mediumImpact();

  /// Blocage : saisie refusée, action impossible.
  static Future<void> error() => HapticFeedback.heavyImpact();
}
