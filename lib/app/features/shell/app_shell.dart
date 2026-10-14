import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_offline_banner.dart';
import '../../core/ui/components/kpb_sample_data_banner.dart';
import '../../core/ui/kpb_haptics.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/shell_chrome.dart';
import '../cases/cases_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../scholarships/live_scholarships_screen.dart';
import '../universities/universities_screen.dart';
import '../ai_advisor/coach_fab.dart';
import 'kpb_tools_drawer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — 5-tab navigation. The order mirrors the approved engagement
// design, with Scholarships occupying the high-intent centre slot.
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // A fresh key per AppShell instance. The drawer opener targets whichever shell
  // is live (see KpbToolsDrawer.registerShell); giving each instance its own key
  // means two shells overlapping for a single transition frame never collide on
  // one GlobalKey — the "Duplicate GlobalKey" crash seen when the app was
  // foregrounded via a kpb:// URL.
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    KpbToolsDrawer.registerShell(_shellKey);
  }

  @override
  void dispose() {
    KpbToolsDrawer.unregisterShell(_shellKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final index = controller.shellIndex.clamp(0, StudentShellTab.count - 1);
        final fieldFilter = controller.universitiesInitialFieldId;

        final pages = <Widget>[
          const HomeScreen(),
          LiveScholarshipsScreen(apiClient: controller.apiClient),
          UniversitiesScreen(
            key: ValueKey(fieldFilter ?? 'all'),
            initialFieldId: fieldFilter,
          ),
          const CasesScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          // Attach this shell's own drawer key so any descendant (including tab
          // screens with their own inner Scaffolds) can call
          // `KpbToolsDrawer.open(context)`.
          key: _shellKey,
          drawer: const KpbToolsDrawer(),
          // Le glissé depuis le bord gauche suit le bouton : ouvrable sur
          // l'accueil, inerte ailleurs. Sans cela, retirer le bouton des
          // autres onglets n'aurait fait que RENDRE le tiroir invisible, pas
          // inatteignable — et un tiroir qu'on ne peut ouvrir que par accident
          // est pire que pas de tiroir du tout.
          //
          // Le `drawer:` lui-même reste posé sur tous les onglets, à dessein :
          // c'est lui qui donne à `_shellKey.currentState` un tiroir à ouvrir,
          // donc le lien profond qui vise la boîte à outils continue de
          // fonctionner quel que soit l'onglet courant.
          drawerEnableOpenDragGesture: index == StudentShellTab.home,
          // The banners live ABOVE the overlay Stack so they push everything
          // (tab content AND the floating hamburger) down instead of colliding
          // with the top-left drawer button. Both banners collapse to zero
          // height when inactive, so this has no effect in the normal case.
          body: StreamBuilder<bool>(
            stream: ConnectivityService.instance.onConnectivityChanged,
            initialData: ConnectivityService.instance.isOnline,
            builder: (context, snapshot) {
              final online = snapshot.data ?? true;
              // When a banner is visible it already absorbs the status-bar
              // inset (each banner wraps its content in SafeArea), so the
              // subtree below must not re-apply the top padding — otherwise
              // the hamburger would float a full status-bar height too low.
              // Real-but-dated rows: only worth a banner when the device is
              // online, otherwise KpbOfflineBanner already says it (with the
              // same freshness label) and we would stack two near-identical
              // strips.
              final staleCatalog = online &&
                  controller.catalogDataState == CatalogDataState.offline;
              final bannerVisible =
                  !online || controller.catalogIsSampleData || staleCatalog;

              return Column(
                children: [
                  const KpbOfflineBanner(),
                  // Honest signal when we're still on the bundled sample
                  // catalog (backend unreachable/empty, no cache) rather than
                  // real data.
                  if (controller.catalogIsSampleData)
                    const KpbSampleDataBanner(),
                  if (staleCatalog)
                    KpbStaleCatalogBanner(
                      snapshotAt: controller.catalogSnapshotAt,
                    ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: bannerVisible,
                      child: Stack(
                        children: [
                          IndexedStack(index: index, children: pages),
                          // Top-left hamburger overlay — ACCUEIL SEULEMENT.
                          // La boîte à outils (estimateur de coûts, etc.) est
                          // une extension de l'accueil, pas une commande
                          // globale : sur les autres onglets elle recouvrait un
                          // contenu déjà dense et proposait une sortie
                          // latérale au milieu d'une tâche. Le `CoachFab`
                          // juste en dessous applique déjà la règle inverse
                          // avec le même test.
                          //
                          // Masquer le bouton ne suffit PAS : sans
                          // `drawerEnableOpenDragGesture` (posé sur le
                          // Scaffold, plus haut), le tiroir resterait ouvrable
                          // au glissé depuis le bord gauche sur tous les
                          // onglets — donc masqué mais toujours atteignable.
                          //
                          // Sits clear of the dynamic-island / notch via
                          // SafeArea (a no-op below a visible banner).
                          if (index == StudentShellTab.home)
                            Positioned(
                              key: const ValueKey('kpb_shell_tools_button'),
                              top: 0,
                              left: 0,
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: KpbSpacing.xs, top: KpbSpacing.xs),
                                  child: _KpbDrawerButton(),
                                ),
                              ),
                            ),
                          // "KPB Intelligence" pill. It floats over the tab
                          // content, so every scrollable in a tab must keep
                          // `KpbShellChrome.bottomReserve(context)` free at its
                          // bottom edge (KpbShellBottomSpacer) — otherwise the
                          // pill and the nav bar hide the last row.
                          if (index != StudentShellTab.home) const CoachFab(),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _KpbFloatingNavBar(
                              currentIndex: index,
                              onTap: controller.goToTab,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _KpbFloatingNavBar extends StatelessWidget {
  const _KpbFloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('kpb_shell_nav_bar'),
        height: KpbShellChrome.navBarHeight,
        decoration: BoxDecoration(
          color: KpbColors.surface,
          border: Border(
            top: BorderSide(
              color: KpbColors.border,
            ),
          ),
        ),
        child: Row(
          children: [
            _NavItem(
              key: const ValueKey('kpb_nav_home'),
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'nav_home'.tr,
              isSelected: currentIndex == StudentShellTab.home,
              onTap: () => onTap(StudentShellTab.home),
            ),
            // The source design gives the university search the second slot.
            _NavItem(
              key: const ValueKey('kpb_nav_universities'),
              icon: Icons.school_outlined,
              selectedIcon: Icons.school_rounded,
              label: 'nav_universities'.tr,
              isSelected: currentIndex == StudentShellTab.universities,
              onTap: () => onTap(StudentShellTab.universities),
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_scholarships'),
              icon: Icons.notifications_none_rounded,
              selectedIcon: Icons.notifications_active_rounded,
              label: 'nav_scholarships'.tr,
              isSelected: currentIndex == StudentShellTab.scholarships,
              onTap: () => onTap(StudentShellTab.scholarships),
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_cases'),
              icon: Icons.folder_copy_outlined,
              selectedIcon: Icons.folder_copy_rounded,
              label: 'nav_cases'.tr,
              isSelected: currentIndex == StudentShellTab.cases,
              onTap: () => onTap(StudentShellTab.cases),
              badgeCount: Get.find<AppController>().totalUnreadCaseMessages,
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_profile'),
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'nav_profile'.tr,
              isSelected: currentIndex == StudentShellTab.profile,
              onTap: () => onTap(StudentShellTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = KpbColors.actionPrimary;
    const inactiveColor = KpbColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isSelected) KpbHaptics.selection();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 28,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KpbColors.actionPrimarySoft
                            : Colors.transparent,
                        borderRadius: KpbRadius.pillBr,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              isSelected ? selectedIcon : icon,
                              key: ValueKey<bool>(isSelected),
                              color: isSelected ? activeColor : inactiveColor,
                              size: 20,
                            ),
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              right: -12,
                              top: -7,
                              child: _NavBadge(count: badgeCount),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Scale the label down instead of truncating ("Destinatio…")
                  // or wrapping: every tab's label always fits on one line.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? activeColor : inactiveColor,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 9.5,
                        height: 1,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: KpbColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Small floating menu (hamburger) button that opens the KPB tools drawer.
/// Lives in the AppShell stack so it surfaces regardless of which tab is
/// currently rendered (each tab has its own Scaffold without a leading icon).
class _KpbDrawerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: context.kpb.cardBg.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: KpbShadow.soft,
        ),
        child: IconButton(
          icon: Icon(Icons.menu_rounded, color: context.kpb.textPrimary),
          tooltip: 'tools_drawer_title'.tr,
          onPressed: () => KpbToolsDrawer.open(context),
        ),
      ),
    );
  }
}
