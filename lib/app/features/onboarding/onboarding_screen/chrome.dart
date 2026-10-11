part of '../onboarding_screen.dart';

// En-tête de progression, gabarit de page et barre du bas.

// ─────────────────────────────────────────────────────────────────────────────
// Progress Header
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.page,
    required this.total,
    this.onBack,
    this.onSkip,
  });
  final int page, total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (onBack != null)
                  Semantics(
                    button: true,
                    label: 'a11y_back'.tr,
                    child: GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: KpbColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 18, color: KpbColors.brandNavy),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 38),
                const Spacer(),
                Text(
                  '${page + 1} / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: KpbColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(38, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('skip'.tr),
                  )
                else
                  const SizedBox(width: 38),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            ClipRRect(
              borderRadius: KpbRadius.pillBr,
              child: LinearProgressIndicator(
                value: (page + 1) / total,
                minHeight: 6,
                backgroundColor: KpbColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    KpbColors.actionPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Page extends StatelessWidget {
  const _Page({
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final Key formKey;
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          const SizedBox(height: KpbSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.25,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: KpbColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.total,
    required this.onNext,
    this.busy = false,
  });
  final int page, total;
  final VoidCallback onNext;

  /// Vrai pendant l'envoi. `onPressed: null` — pas un bouton actif dont on
  /// ignore les appuis : un bouton actif qui ne fait rien est indiscernable
  /// d'une app plantée, et c'est exactement le rapport de bug que la 49
  /// aurait reçu.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onNext,
          style: FilledButton.styleFrom(
            backgroundColor: KpbColors.actionPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isLast ? 'create_account'.tr : 'continue'.tr),
        ),
      ),
    );
  }
}
