part of '../home_screen.dart';

// En-tête de l'accueil : salutation, cloche, « Mes suivis » (ou profil).

// ─────────────────────────────────────────────────────────────────────────────
// App bar — greeting (fills the title slot) + soft-elevated icon chips
// ─────────────────────────────────────────────────────────────────────────────
class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final greeting = firstName.isNotEmpty
        ? 'home_design_greeting_named'.trParams({'name': firstName})
        : 'home_design_greeting'.tr;

    // Two things happen here, both required.
    //
    // 1. `SizedBox(width: double.infinity)` — AppBar wraps the title in
    //    `_AppBarTitleBox`, which SHRINK-WRAPS its child. Without this the
    //    greeting would report its natural width and the slot's real budget
    //    would be unmeasurable (and unassertable in tests).
    //
    // 2. `FittedBox(scaleDown)` instead of relying on ellipsis — the previous
    //    round of this bug was "fixed" by decluttering the header, which only
    //    moved the cliff. West-African first names are long (« Abdoulaye »,
    //    « Mouhamadou ») and AppBar already clamps title text scaling at
    //    1.34×, so at large accessibility sizes the line still cannot fit any
    //    fixed budget. Scaling the line down keeps the user's name WHOLE —
    //    truncating someone's own name to "Salut, …" is the actual defect.
    //    `maxLines`/`overflow` stay as a backstop if this ever loses the
    //    FittedBox.
    return SizedBox(
      key: homeGreetingSlotKey,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            greeting,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: KpbTextStyles.headingFamily,
              fontSize: KpbFontSize.xl,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: KpbColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }
}

/// Accès direct à « Mes suivis » (bourses suivies, échéances).
class _HomeFollowedButton extends StatelessWidget {
  const _HomeFollowedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'followed_title'.tr,
      child: KpbPressable(
        key: const ValueKey<String>('home-followed-entry'),
        onTap: onTap,
        child: Container(
          width: _kHomeHeaderButton,
          height: _kHomeHeaderButton,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: KpbColors.border),
          ),
          child: const Icon(Icons.bookmarks_outlined,
              color: KpbColors.brandNavy, size: 20),
        ),
      ),
    );
  }
}

class _HomeProfileButton extends StatelessWidget {
  const _HomeProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'nav_profile'.tr,
      child: KpbPressable(
        onTap: onTap,
        child: Container(
          width: _kHomeHeaderButton,
          height: _kHomeHeaderButton,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: KpbColors.border),
          ),
          child: const Icon(Icons.person_outline_rounded,
              color: KpbColors.brandNavy, size: 20),
        ),
      ),
    );
  }
}

/// Notifications bell (App-engagement handoff). The unread dot is HONEST: it is
/// shown when the real case list yields at least one live-derived notification
/// (`hasDerivedNotifications`) OR the server feed has unread entries (the
/// `unread-count` badge — a « bourse ouverte » the student has not seen).
class _NotifBellChip extends StatefulWidget {
  const _NotifBellChip({
    required this.hasUnread,
    required this.onTap,
    this.onMounted,
  });
  final bool hasUnread;
  final VoidCallback onTap;

  /// Appelé une fois au montage : rafraîchit le badge serveur (borné à une
  /// requête par minute par le contrôleur).
  final Future<void> Function()? onMounted;

  @override
  State<_NotifBellChip> createState() => _NotifBellChipState();
}

class _NotifBellChipState extends State<_NotifBellChip> {
  @override
  void initState() {
    super.initState();
    final onMounted = widget.onMounted;
    if (onMounted != null) unawaited(onMounted());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        button: true,
        label: 'notifications_title'.tr,
        child: KpbPressable(
          key: const ValueKey<String>('home-bell'),
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _kHomeHeaderButton,
                height: _kHomeHeaderButton,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: c.softShadow,
                  border: Border.all(color: KpbColors.border),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 20, color: KpbColors.textMuted),
              ),
              if (widget.hasUnread)
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    key: const ValueKey<String>('home-bell-unread-dot'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: KpbColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
