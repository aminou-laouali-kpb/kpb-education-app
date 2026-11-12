import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/app_tokens.dart';
import 'app_tour_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// La visite guidée de l'application (build 59)
//
// ## Pourquoi
//
// L'app a beaucoup de fonctions, et l'élève qui arrive (souvent peu à l'aise
// avec un téléphone) ne sait pas où elles sont. À la première arrivée sur
// l'accueil, une visite lui montre, l'un après l'autre, les vrais boutons de
// l'écran : l'écran s'assombrit, seul le bouton expliqué reste éclairé et
// entouré, et une bulle dit en mots simples à quoi il sert.
//
// ## Ce qu'elle garantit
//
// - Elle ne s'ouvre qu'UNE fois par appareil : le drapeau est écrit quand
//   l'élève la ferme (« J'ai compris » ou « Passer »). Une panne du stockage
//   ne la fait jamais revenir en boucle dans la même session.
// - Elle reste joignable : Profil → « Revoir la visite ».
// - Elle ne nomme que ce que l'élève voit : l'étape KPB Intelligence n'existe
//   que si le bouton est affiché, et la liste des outils est lue dans le
//   tiroir lui-même (`KpbToolsDrawer.visibleTools`).
// - Elle ne s'ouvre pas par-dessus autre chose : si un écran, une feuille ou un
//   dialogue est déjà ouvert, elle attend le prochain démarrage.
// ─────────────────────────────────────────────────────────────────────────────

/// Les boutons que la visite éclaire. Une instance PAR shell (comme la clé du
/// tiroir) : deux shells qui se chevauchent le temps d'une transition ne se
/// disputent jamais une même `GlobalKey`.
class AppTourTargets {
  final GlobalKey tools = GlobalKey(debugLabel: 'app_tour_tools');
  final GlobalKey home = GlobalKey(debugLabel: 'app_tour_home');
  final GlobalKey universities = GlobalKey(debugLabel: 'app_tour_universities');
  final GlobalKey scholarships = GlobalKey(debugLabel: 'app_tour_scholarships');
  final GlobalKey cases = GlobalKey(debugLabel: 'app_tour_cases');
  final GlobalKey profile = GlobalKey(debugLabel: 'app_tour_profile');
  final GlobalKey coach = GlobalKey(debugLabel: 'app_tour_coach');
}

/// Un outil du menu ☰, tel que le tiroir l'affiche.
typedef AppTourTool = ({String labelKey, IconData icon, Color color});

/// Ce dont la visite a besoin du shell vivant.
abstract interface class AppTourHost {
  BuildContext get context;
  AppTourTargets get targets;

  /// L'onglet affiché en ce moment.
  int get currentTab;

  /// Affiche un onglet (la visite montre l'écran dont elle parle).
  void goToTab(int tab);

  /// Le bouton KPB Intelligence est-il affiché (élève connecté) ?
  bool get coachVisible;

  /// Les outils que le menu ☰ affiche en ce moment.
  List<AppTourTool> get tools;

  /// Le prénom de l'élève, ou une chaîne vide.
  String get firstName;
}

/// Ce qui a ouvert la visite (`tour_trigger` de `app_tour_shown`).
enum AppTourTrigger {
  firstOpen('first_open'),
  replay('replay');

  const AppTourTrigger(this.key);
  final String key;
}

/// Comment elle s'est fermée (`tour_exit` de `app_tour_completed`).
enum AppTourExit {
  finished('finished'),
  skipped('skipped');

  const AppTourExit(this.key);
  final String key;
}

/// Ce que la visite mesure (interface : un test peut l'observer).
abstract interface class AppTourAnalytics {
  void shown({required String trigger});
  void completed({
    required String exit,
    required int stepsSeen,
    required int stepsTotal,
  });
}

class _ServiceAppTourAnalytics implements AppTourAnalytics {
  const _ServiceAppTourAnalytics();

  @override
  void shown({required String trigger}) =>
      unawaited(AnalyticsService.instance.logAppTourShown(trigger: trigger));

  @override
  void completed({
    required String exit,
    required int stepsSeen,
    required int stepsTotal,
  }) =>
      unawaited(AnalyticsService.instance.logAppTourCompleted(
        exit: exit,
        stepsSeen: stepsSeen,
        stepsTotal: stepsTotal,
      ));
}

/// Les étapes, dans l'ordre. Le texte est sous `app_tour_<id>_title` et
/// `app_tour_<id>_body`.
enum AppTourStep {
  /// Bienvenue (sans bouton éclairé).
  welcome('welcome', Icons.waving_hand_rounded, StudentShellTab.home),

  /// L'onglet Accueil.
  home('home', Icons.home_rounded, StudentShellTab.home),

  /// Le menu ☰ et ses outils (sur l'accueil : c'est le seul onglet qui l'a).
  tools('tools', Icons.menu_rounded, StudentShellTab.home),

  /// L'onglet Universités.
  universities(
      'universities', Icons.school_rounded, StudentShellTab.universities),

  /// L'onglet Bourses.
  scholarships('scholarships', Icons.workspace_premium_rounded,
      StudentShellTab.scholarships),

  /// Le bouton KPB Intelligence (affiché sur les onglets autres que l'accueil).
  coach('coach', Icons.psychology_rounded, StudentShellTab.scholarships),

  /// L'onglet Dossiers : le conseiller.
  cases('cases', Icons.folder_copy_rounded, StudentShellTab.cases),

  /// L'onglet Profil, et où revoir la visite.
  profile('profile', Icons.person_rounded, StudentShellTab.profile),

  /// La fin (sans bouton éclairé).
  done('done', Icons.check_circle_rounded, StudentShellTab.home);

  const AppTourStep(this.id, this.icon, this.tab);

  final String id;
  final IconData icon;

  /// L'onglet affiché derrière la bulle.
  final int tab;

  String get titleKey => 'app_tour_${id}_title';
  String get bodyKey => 'app_tour_${id}_body';

  /// Le bouton éclairé, ou null (bulle au centre).
  GlobalKey? targetIn(AppTourTargets t) => switch (this) {
        AppTourStep.welcome || AppTourStep.done => null,
        AppTourStep.home => t.home,
        AppTourStep.tools => t.tools,
        AppTourStep.universities => t.universities,
        AppTourStep.scholarships => t.scholarships,
        AppTourStep.coach => t.coach,
        AppTourStep.cases => t.cases,
        AppTourStep.profile => t.profile,
      };
}

/// La description courte d'un outil du menu ☰ (`app_tour_tool_<labelKey>`).
String appTourToolDescriptionKey(String labelKey) => 'app_tour_tool_$labelKey';

abstract final class AppTour {
  @visibleForTesting
  static AppTourStore store = const SharedPreferencesAppTourStore();

  @visibleForTesting
  static AppTourAnalytics analytics = const _ServiceAppTourAnalytics();

  /// Faux sous `flutter test` : les tests qui montent le shell n'ont pas à
  /// fermer une visite. Les tests de la visite le remettent à vrai.
  @visibleForTesting
  static bool autoStartEnabled =
      kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  /// Le délai avant l'ouverture automatique : le temps que l'accueil se pose.
  @visibleForTesting
  static Duration autoStartDelay = const Duration(milliseconds: 900);

  static bool _autoShownThisRun = false;
  static bool _open = false;
  static AppTourHost? _host;

  @visibleForTesting
  static void resetForTest() {
    store = const SharedPreferencesAppTourStore();
    analytics = const _ServiceAppTourAnalytics();
    autoStartEnabled = false;
    autoStartDelay = const Duration(milliseconds: 900);
    _autoShownThisRun = false;
    _open = false;
    _host = null;
  }

  /// Le shell vivant s'inscrit (pour « Revoir la visite » depuis le Profil).
  static void registerHost(AppTourHost host) => _host = host;

  static void unregisterHost(AppTourHost host) {
    if (identical(_host, host)) _host = null;
  }

  /// La visite est-elle ouverte en ce moment ?
  static bool get isOpen => _open;

  /// Les étapes à montrer : toutes, moins KPB Intelligence quand le bouton
  /// n'est pas affiché.
  static List<AppTourStep> stepsFor({required bool coachVisible}) => [
        for (final step in AppTourStep.values)
          if (step != AppTourStep.coach || coachVisible) step,
      ];

  static bool _isTopRoute(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent ?? true;

  /// Ouvre la visite si l'élève ne l'a jamais fermée sur cet appareil. Rend
  /// `true` si elle s'est ouverte.
  static Future<bool> showIfFirstOpen(AppTourHost host) async {
    if (!autoStartEnabled || _autoShownThisRun || _open) return false;
    try {
      if (await store.hasBeenSeen()) return false;
    } catch (_) {
      return false;
    }
    final context = host.context;
    if (!context.mounted || !_isTopRoute(context)) return false;
    _autoShownThisRun = true;
    await show(host, trigger: AppTourTrigger.firstOpen);
    return true;
  }

  /// Appelée par le shell à son premier rendu : attend que l'accueil soit
  /// posé, puis ouvre la visite si c'est la première fois.
  static Future<void> autoStart(AppTourHost host) async {
    if (!autoStartEnabled) return;
    await Future<void>.delayed(autoStartDelay);
    if (!host.context.mounted) return;
    await showIfFirstOpen(host);
  }

  /// « Revoir la visite » (Profil) : sur le shell vivant.
  static Future<void> replay() async {
    final host = _host;
    if (host == null || !host.context.mounted || _open) return;
    await show(host, trigger: AppTourTrigger.replay);
  }

  /// Ouvre la visite. Écrit le drapeau à la fermeture, quelle qu'elle soit.
  static Future<void> show(
    AppTourHost host, {
    required AppTourTrigger trigger,
  }) async {
    if (_open) return;
    _open = true;
    final startTab = host.currentTab;
    final steps = stepsFor(coachVisible: host.coachVisible);
    final progress = _Progress();
    analytics.shown(trigger: trigger.key);

    AppTourExit? exit;
    try {
      exit = await Navigator.of(host.context, rootNavigator: true)
          .push<AppTourExit>(
        PageRouteBuilder<AppTourExit>(
          opaque: false,
          settings: const RouteSettings(name: 'app_tour'),
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (_, __, ___) => _AppTourOverlay(
            host: host,
            steps: steps,
            progress: progress,
          ),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _open = false;
    }

    final how = exit ?? AppTourExit.skipped;
    analytics.completed(
      exit: how.key,
      stepsSeen: progress.seen,
      stepsTotal: steps.length,
    );
    try {
      await store.markSeen();
    } catch (_) {
      // Rien : `_autoShownThisRun` l'empêche déjà de revenir dans la session.
    }

    // L'élève retrouve l'écran d'où il est parti (l'accueil au premier
    // lancement, le Profil quand il l'a rejouée).
    if (host.context.mounted) host.goToTab(startTab);

    // « Passer » : on lui dit où la retrouver, sinon il la croit perdue.
    if (how == AppTourExit.skipped && host.context.mounted) {
      ScaffoldMessenger.maybeOf(host.context)?.showSnackBar(
        SnackBar(
          content: Text('app_tour_skipped_hint'.tr),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _Progress {
  int _highest = 0;
  void reach(int index) {
    if (index > _highest) _highest = index;
  }

  int get seen => _highest + 1;
}

/// L'écran de la visite : le voile percé autour du bouton, et la bulle.
class _AppTourOverlay extends StatefulWidget {
  const _AppTourOverlay({
    required this.host,
    required this.steps,
    required this.progress,
  });

  final AppTourHost host;
  final List<AppTourStep> steps;
  final _Progress progress;

  @override
  State<_AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<_AppTourOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _hole;
  bool _closing = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  AppTourStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _enter(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // « Réduire les animations » : l'anneau ne pulse pas.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    }
    // Rotation, clavier, taille du texte : on remesure le bouton.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _enter(int index) {
    _index = index;
    widget.progress.reach(index);
    _hole = null;
    final step = widget.steps[index];
    final binding = WidgetsBinding.instance;
    // Jamais pendant une construction : l'onglet change à l'image suivante,
    // puis on mesure le bouton deux images plus tard (la première reconstruit
    // l'onglet, la seconde a posé le bouton KPB Intelligence, absent de
    // l'accueil).
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.host.currentTab != step.tab) widget.host.goToTab(step.tab);
      binding.addPostFrameCallback((_) {
        _measure();
        binding.addPostFrameCallback((_) => _measure());
        binding.scheduleFrame();
      });
      binding.scheduleFrame();
    });
    binding.scheduleFrame();
  }

  void _measure() {
    if (!mounted) return;
    final key = _step.targetIn(widget.host.targets);
    Rect? rect;
    final box = key?.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize && me is RenderBox) {
      final topLeft = me.globalToLocal(box.localToGlobal(Offset.zero));
      rect = topLeft & box.size;
    }
    if (rect != _hole) setState(() => _hole = rect);
  }

  void _go(int target) {
    if (target < 0 || target >= widget.steps.length) return;
    setState(() => _enter(target));
  }

  void _close(AppTourExit exit) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(exit);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final isFirst = _index == 0;
    final isLast = _index == steps.length - 1;
    final hole = _hole?.inflate(6);

    return PopScope(
      canPop: false,
      // Retour du téléphone : étape précédente ; à la première, on ferme.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isFirst) {
          _close(AppTourExit.skipped);
        } else {
          _go(_index - 1);
        }
      },
      child: Semantics(
        key: const ValueKey('app-tour'),
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: 'app_tour_title'.tr,
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Stack(
                children: [
                  // Le voile : il absorbe les taps (un tap au hasard ne doit
                  // ni fermer la visite ni ouvrir un écran dessous).
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => CustomPaint(
                          painter: _ScrimPainter(
                            hole: hole,
                            pulse: _pulse.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._bubble(context, size, hole, isFirst, isLast),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _bubble(
    BuildContext context,
    Size size,
    Rect? hole,
    bool isFirst,
    bool isLast,
  ) {
    final pad = MediaQuery.paddingOf(context);
    const gap = 10.0;
    const arrowH = 12.0;
    const side = 16.0;
    final width = (size.width - 2 * side).clamp(0.0, 440.0);
    final left = (size.width - width) / 2;

    final card = _BubbleCard(
      step: _step,
      index: _index,
      total: widget.steps.length,
      isFirst: isFirst,
      isLast: isLast,
      tools: _step == AppTourStep.tools ? widget.host.tools : const [],
      firstName: widget.host.firstName,
      onBack: () => _go(_index - 1),
      onNext: () => isLast ? _close(AppTourExit.finished) : _go(_index + 1),
      onSkip: () => _close(AppTourExit.skipped),
    );

    if (hole == null) {
      final maxH = size.height - pad.top - pad.bottom - 32;
      return [
        Positioned(
          left: left,
          width: width,
          top: pad.top + 16,
          bottom: pad.bottom + 16,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: card,
            ),
          ),
        ),
      ];
    }

    // La bulle va du côté où il y a le plus de place.
    final above = hole.center.dy > size.height / 2;
    final arrowX =
        (hole.center.dx - 10).clamp(left + 16.0, left + width - 36.0);
    if (above) {
      final arrowTop = hole.top - gap - arrowH;
      final maxH = arrowTop - pad.top - 12;
      return [
        Positioned(
          left: arrowX,
          top: arrowTop,
          child: const _Arrow(down: true),
        ),
        Positioned(
          left: left,
          width: width,
          bottom: size.height - arrowTop - 0.5,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH.clamp(160.0, 9999.0)),
            child: card,
          ),
        ),
      ];
    }
    final arrowTop = hole.bottom + gap;
    final cardTop = arrowTop + arrowH - 0.5;
    final maxH = size.height - cardTop - pad.bottom - 12;
    return [
      Positioned(
        left: arrowX,
        top: arrowTop,
        child: const _Arrow(down: false),
      ),
      Positioned(
        left: left,
        width: width,
        top: cardTop,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH.clamp(160.0, 9999.0)),
          child: card,
        ),
      ),
    ];
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.step,
    required this.index,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.tools,
    required this.firstName,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final AppTourStep step;
  final int index;
  final int total;
  final bool isFirst;
  final bool isLast;
  final List<AppTourTool> tools;
  final String firstName;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  String get _title {
    if (step == AppTourStep.welcome && firstName.isNotEmpty) {
      return 'app_tour_welcome_title_named'.trParams({'name': firstName});
    }
    return step.titleKey.tr;
  }

  @override
  Widget build(BuildContext context) {
    // Le texte grandit avec le réglage du téléphone, jusqu'à 1,3 : au-delà la
    // bulle ne tiendrait plus à côté du bouton (elle défile si besoin).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        key: ValueKey('app-tour-card-${step.id}'),
        decoration: BoxDecoration(
          color: KpbColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 6, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'app_tour_step_counter'.trParams({
                        'current': '${index + 1}',
                        'total': '$total',
                      }),
                      style: const TextStyle(
                        color: KpbColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: KpbFontSize.sm,
                      ),
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      key: const ValueKey('app-tour-skip'),
                      onPressed: onSkip,
                      child: Text('app_tour_skip'.tr),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: KpbColors.actionPrimarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(step.icon,
                              color: KpbColors.actionPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              _title,
                              style: const TextStyle(
                                color: KpbColors.brandNavy,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.bodyKey.tr,
                      style: const TextStyle(
                        color: KpbColors.textPrimary,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    for (final tool in tools) ...[
                      const SizedBox(height: 10),
                      _ToolLine(tool: tool),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              child: Column(
                children: [
                  _Dots(index: index, total: total),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isFirst) ...[
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            key: const ValueKey('app-tour-back'),
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _OneLine('app_tour_back'.tr),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 3,
                        child: FilledButton(
                          key: const ValueKey('app-tour-next'),
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: KpbColors.actionPrimary,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _OneLine(
                            isLast
                                ? 'app_tour_finish'.tr
                                : isFirst
                                    ? 'app_tour_start'.tr
                                    : 'app_tour_next'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un libellé de bouton sur UNE ligne : réduit plutôt que coupé ou replié.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );
}

class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.tool});
  final AppTourTool tool;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tool.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(tool.icon, color: tool.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: tool.labelKey.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' : '),
                TextSpan(text: appTourToolDescriptionKey(tool.labelKey).tr),
              ],
            ),
            style: const TextStyle(
              color: KpbColors.textPrimary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= index ? KpbColors.actionPrimary : KpbColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.down});
  final bool down;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(20, 12),
        painter: _ArrowPainter(down: down),
      );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.down});
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (down) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = KpbColors.surface);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.down != down;
}

/// Le voile sombre, percé autour du bouton expliqué, avec un anneau qui pulse.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.pulse});

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = const Color(0xC70F172A);
    final full = Offset.zero & size;
    final h = hole;
    if (h == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(h, const Radius.circular(16));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full)
        ..addRRect(rrect),
      scrim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    final grow = 3 + 6 * pulse;
    canvas.drawRRect(
      rrect.inflate(grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = KpbColors.gold.withValues(alpha: 1 - pulse * 0.7),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.pulse != pulse;
}
