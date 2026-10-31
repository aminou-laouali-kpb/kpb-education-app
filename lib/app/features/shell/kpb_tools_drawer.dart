import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../ai_advisor/ai_consent.dart';
import '../budget/budget_calculator_screen.dart';
import '../etudes_en_france/eef_entry.dart';
import '../cases/document_review_screen.dart';
import '../housing/housing_estimator_screen.dart';
import '../tools/cv_generator_screen.dart';
import '../tools/document_scanner_screen.dart';
import '../tools/impact_dashboard_screen.dart';
import '../tools/interview_simulator_screen.dart';
import '../tools/motivation_letters_screen.dart';
import '../travel/flight_estimator_screen.dart';

/// Global hamburger drawer for the KPB student tools.
///
/// Tab screens have their own Scaffolds, so the AppShell's drawer cannot be
/// reached via `Scaffold.of(context)` from inside a tab. Each AppShell instead
/// registers its own Scaffold key here on mount, so any descendant can call
/// [open] to surface the drawer regardless of how deeply it is nested.
class KpbToolsDrawer extends StatelessWidget {
  const KpbToolsDrawer({super.key});

  /// Scaffold key of the AppShell currently on screen. Each AppShell instance
  /// publishes its own key on mount ([registerShell]) and clears it on dispose
  /// ([unregisterShell]) — so if two shells briefly overlap during a route
  /// transition (e.g. `Get.offAllNamed('/')` firing while the boot shell is
  /// still a frame from being torn down, as happens when the app is foregrounded
  /// via a `kpb://` URL) they never share one GlobalKey, which would crash with
  /// "Duplicate GlobalKey [LabeledGlobalKey<ScaffoldState>]".
  static GlobalKey<ScaffoldState>? _activeShellKey;

  /// Publish [key] as the live shell. Called from `AppShell.initState`.
  static void registerShell(GlobalKey<ScaffoldState> key) {
    _activeShellKey = key;
  }

  /// Clear [key] if it is still the live shell. Called from `AppShell.dispose`.
  /// The identity check stops an outgoing shell's teardown from clobbering an
  /// incoming shell that already registered ahead of it.
  static void unregisterShell(GlobalKey<ScaffoldState> key) {
    if (identical(_activeShellKey, key)) _activeShellKey = null;
  }

  /// Open the drawer from anywhere inside the AppShell tree.
  ///
  /// The Scaffold that encloses [context] wins: the ☰ button sits in the
  /// shell's own body, so it always opens ITS shell. The global key is only a
  /// fallback for callers below a tab's inner Scaffold. Relying on it alone
  /// left the ☰ inert for every first-time guest: `enterGuestMode()` then
  /// `Get.offAll` mount two shells, and the outgoing one's teardown could leave
  /// the key empty or aimed at the wrong shell (audit build 57, n° 3).
  static void open(BuildContext context) {
    final enclosing = Scaffold.maybeOf(context);
    if (enclosing != null && enclosing.hasDrawer) {
      enclosing.openDrawer();
      return;
    }
    _activeShellKey?.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _tools;
    return Drawer(
      backgroundColor: context.kpb.pageBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.lg, KpbSpacing.lg, KpbSpacing.md, KpbSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KpbColors.blue.withValues(alpha: 0.12),
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: const Icon(Icons.build_circle_outlined,
                            color: KpbColors.blue),
                      ),
                      const SizedBox(width: KpbSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('tools_drawer_title'.tr,
                                style: KpbTextStyles.title),
                            Text(
                              'tools_drawer_subtitle'.tr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.kpb.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
                itemCount: tools.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final t = tools[i];
                  return ListTile(
                    leading: Icon(t.icon, color: t.color),
                    title: Text(t.labelKey.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      if (t.requiresAiConsent) {
                        openAiToolIfConsented(context, t.builder);
                      } else {
                        Get.to<void>(t.builder);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les outils RÉELLEMENT offerts par le tiroir, sous une forme publique.
  ///
  /// Exposé pour que la matrice d'écrans (test/core/ui/screen_matrix_test.dart)
  /// se pilote sur CETTE liste et non sur une copie. Deux conséquences voulues :
  /// un outil ajouté ici est couvert automatiquement, et le compte reflète les
  /// drapeaux — il y a 9 entrées littérales et 4 à l'exécution aujourd'hui, les
  /// quatre outils IA étant masqués par `AppConfig.aiToolsEnabled` (M1) et
  /// `tools_flight` par `AppConfig.flightEstimatorEnabled`. Une matrice qui
  /// écrirait « 9 » en dur échouerait pour cette seule raison.
  @visibleForTesting
  static List<({String labelKey, Widget Function() builder})>
      get toolsForTest => _tools
          .map((tool) => (labelKey: tool.labelKey, builder: tool.builder))
          .toList(growable: false);

  /// Un GETTER, et non plus un `static final`.
  ///
  /// Une liste `static final` est construite une seule fois, au premier accès,
  /// et gèle donc la valeur des drapeaux au moment de cet accès. Tant que les
  /// drapeaux étaient des `bool.fromEnvironment` purs — invariants pour toute
  /// la durée du processus — c'était sans conséquence. `AppConfig.aiToolsEnabled`
  /// porte un `_override` de test : sans ce getter, la contre-épreuve
  /// « drapeau à VRAI ⇒ les quatre outils reviennent » dépendrait de l'ordre
  /// des tests dans le fichier, ce qui est précisément le genre de garde-fou
  /// qui reste vert pour de mauvaises raisons.
  static List<_ToolEntry> get _tools => <_ToolEntry>[
        // ── Espace « Études en France » ────────────────────────────────────
        // Placé EN TÊTE pendant la campagne : c'est le module que la vitrine
        // pousse, et un tiroir où il serait huitième ne le ferait pas trouver.
        // La visibilité passe par `EefEntry.isVisible`, qui lit le drapeau
        // SERVEUR — donc l'entrée apparaît le jour J sans binaire neuf.
        if (EefEntry.isVisible)
          _ToolEntry(
            labelKey: 'eef_title',
            icon: Icons.public_outlined,
            color: KpbColors.actionPrimary,
            builder: () => const EefEntry(source: 'tools_drawer'),
          ),
        // ── Les quatre outils IA masqués par M1 ────────────────────────────
        // Ils postaient le nom civil de l'étudiant à un fournisseur tiers,
        // sans garde de consentement serveur. Lot 11 a fermé la fuite ; le
        // masque reste jusqu'au déploiement couplé avec la build 49.
        // Voir AppConfig.aiToolsEnabled.
        if (AppConfig.aiToolsEnabled) ...[
          _ToolEntry(
            labelKey: 'tools_cv',
            icon: Icons.description_outlined,
            color: KpbColors.blue,
            requiresAiConsent: true,
            builder: () => const CvGeneratorScreen(),
          ),
          _ToolEntry(
            labelKey: 'tools_motivation_letter',
            icon: Icons.edit_note_outlined,
            color: KpbColors.blueMid,
            requiresAiConsent: true,
            builder: () => const MotivationLettersScreen(),
          ),
          _ToolEntry(
            labelKey: 'tools_interview',
            icon: Icons.record_voice_over_outlined,
            color: KpbColors.navy,
            requiresAiConsent: true,
            builder: () => const InterviewSimulatorScreen(),
          ),
        ],
        // Le scanner RESTE : capture locale et assemblage en PDF, aucun appel
        // réseau, aucune donnée qui sort du téléphone. C'est même l'outil qui
        // produit le fichier que l'étudiant envoie ensuite au conseiller,
        // maintenant que l'envoi en app est masqué (M2).
        _ToolEntry(
          labelKey: 'tools_doc_scanner',
          icon: Icons.document_scanner_outlined,
          color: KpbColors.sky,
          builder: () => const DocumentScannerScreen(),
        ),
        if (AppConfig.aiToolsEnabled)
          _ToolEntry(
            labelKey: 'tools_doc_review',
            icon: Icons.auto_awesome_outlined,
            color: KpbColors.gold,
            requiresAiConsent: true,
            builder: () => const DocumentReviewScreen(),
          ),
        _ToolEntry(
          labelKey: 'tools_budget',
          icon: Icons.savings_outlined,
          color: KpbColors.success,
          builder: () => const BudgetCalculatorScreen(),
        ),
        // Hidden while the backend has no Kayak key: the estimator can only
        // fail without it (revue vidéo du propriétaire — « ça ne sert à rien »).
        if (AppConfig.flightEstimatorEnabled)
          _ToolEntry(
            labelKey: 'tools_flight',
            icon: Icons.flight_takeoff_outlined,
            color: KpbColors.sky,
            builder: () => const FlightEstimatorScreen(),
          ),
        // Le Logement est « V1.1+ » : masqué du Profil par `mvpOnly`, il l'est
        // aussi ici (audit build 57, T6-10).
        if (!AppConfig.mvpOnly)
          _ToolEntry(
            labelKey: 'tools_housing',
            icon: Icons.home_work_outlined,
            color: KpbColors.warning,
            builder: () => const HousingEstimatorScreen(),
          ),
        if (RemoteFeatureFlags.instance.publicImpactStatsEnabled)
          _ToolEntry(
            labelKey: 'tools_impact',
            icon: Icons.insights_outlined,
            color: KpbColors.gold,
            builder: () => const ImpactDashboardScreen(),
          ),
      ];
}

class _ToolEntry {
  const _ToolEntry({
    required this.labelKey,
    required this.icon,
    required this.color,
    required this.builder,
    this.requiresAiConsent = false,
  });

  final String labelKey;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  final bool requiresAiConsent;
}
