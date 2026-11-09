import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../legal/legal_links.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_root_shell.dart';
import 'account_recovery_screen.dart';
import 'magic_link_email_screen.dart';
import '../../core/ui/components/kpb_toast.dart';

/// KPB Intelligence's acquisition entry point for Google or email sign-in.
class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  late final AuthService _authService = Get.find<AuthService>();
  StreamSubscription<AuthState>? _authSub;
  bool _googleLoading = false;

  /// La session vient de s'ouvrir (retour de Google ou lien e-mail) et le
  /// compte se prépare. Les trois actions sont remplacées par un état
  /// d'attente : avant, l'écran restait figé et « Explorer sans compte »
  /// touché à ce moment-là laissait un compte connecté en mode invité.
  bool _finishingAuth = false;
  // The auth method the user initiated with, read by the signed-in listener so
  // the success event carries the accurate method (KPB-158).
  String _pendingMethod = 'email';

  @override
  void initState() {
    super.initState();
    // Google OAuth (and a clicked magic link) return via deep link; complete
    // navigation when the session is established.
    _authSub = _authService.onAuthStateChange.listen((state) async {
      if (state.event != AuthChangeEvent.signedIn || !mounted) return;
      setState(() => _finishingAuth = true);
      try {
        // The redirect lands in the app while the browser that showed the
        // consent screen may still be presented on top of it. Dismiss it
        // first, otherwise the user stares at the blank redirect page while
        // the app has already navigated behind it.
        await _authService.dismissAuthWebView();
        if (!mounted) return;
        // Success logging (login vs sign-up + method) is centralized in
        // navigateAfterAuth so it stays accurate for both Google and email.
        await navigateAfterAuth(method: _pendingMethod);
      } finally {
        if (mounted) setState(() => _finishingAuth = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    _pendingMethod = 'google';
    setState(() => _googleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (_) {
      unawaited(AnalyticsService.instance
          .logAuthFailed(method: 'google', reason: 'oauth_error'));
      if (mounted) {
        KpbToast.error('auth_google_error'.tr, context: context);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  /// KPB-156: explore the app without an account. The boot router already sends
  /// guests to the shell; gated actions (dossiers, coach) prompt sign-up later.
  void _continueAsGuest() {
    // Une session est ouverte : ce n'est plus un invité (voir
    // `AppController.enterGuestMode`, qui l'ignore aussi).
    if (_finishingAuth || _authService.isLoggedIn) return;
    Get.find<AppController>().enterGuestMode();
    AnalyticsService.instance.logGuestModeEntered();
    Get.offAll(() => const AppRootShell());
  }

  @override
  Widget build(BuildContext context) {
    final authService = _authService;

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 720;
            final titleSize = isCompact ? 30.0 : 34.0;
            final sidePadding = constraints.maxWidth < 380 ? 28.0 : 40.0;

            // Espacements resserrés sur petit écran ou texte agrandi : les trois
            // actions doivent rester visibles sans défiler (audit build 57,
            // T1-04 et T7-13).
            final tight =
                isCompact || MediaQuery.textScalerOf(context).scale(1) > 1.2;
            final gap = tight ? 12.0 : 28.0;
            final benefitGap = tight ? 10.0 : 17.0;

            // Les ACTIONS sont hors de la zone défilante, en bas ; seul le
            // texte de présentation défile. Avant, tout défilait ensemble et
            // « Explorer sans compte » descendait sous la ligne de flottaison.
            return Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 24, sidePadding, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/images/logo/kpb-education-logo-full.png',
                              width: 150,
                              fit: BoxFit.contain,
                              semanticLabel: 'KPB Education',
                            ),
                          ),
                          SizedBox(height: gap),
                          Text(
                            'auth_intelligence_title'.tr,
                            style: TextStyle(
                              color: KpbColors.brandNavy,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              height: 1.04,
                              letterSpacing: -1.25,
                            ),
                          ),
                          SizedBox(height: gap),
                          Text(
                            'auth_intelligence_body'.tr,
                            style: const TextStyle(
                              color: KpbColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.42,
                            ),
                          ),
                          SizedBox(height: gap),
                          // Une icône « % » annonçait un pourcentage de
                          // compatibilité que l'app n'affiche pas (et ne doit pas
                          // afficher) : les formations sont CLASSÉES, rien de plus.
                          _BenefitRow(
                            icon: Icons.sort_rounded,
                            label: 'auth_intelligence_benefit_fit'.tr,
                          ),
                          SizedBox(height: benefitGap),
                          _BenefitRow(
                            icon: Icons.smart_toy_outlined,
                            label: 'auth_intelligence_benefit_ai'.tr,
                          ),
                          SizedBox(height: benefitGap),
                          _BenefitRow(
                            icon: Icons.support_agent_rounded,
                            label: 'auth_intelligence_benefit_support'.tr,
                          ),
                          SizedBox(height: gap),
                          // Avant de donner son adresse, l'élève peut lire à
                          // quoi il consent (audit build 57, T1-20).
                          Text(
                            'auth_terms_notice'.tr,
                            style: KpbTextStyles.caption,
                          ),
                          const LegalLinksRow(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: tight ? 12 : 20),
                  if (_finishingAuth)
                    const _FinishingAuthPanel()
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 58),
                      child: OutlinedButton.icon(
                        onPressed: _googleLoading ? null : _signInWithGoogle,
                        icon: _googleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: KpbColors.actionPrimary,
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.google,
                                size: 19,
                                color: KpbColors.googleBlue,
                              ),
                        label: Text('auth_continue_google'.tr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KpbColors.brandNavy,
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: KpbColors.border,
                            width: 1.5,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: KpbTextStyles.bodyFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 58),
                      child: FilledButton.icon(
                        onPressed: () {
                          _pendingMethod = 'email';
                          Get.to(
                            () =>
                                MagicLinkEmailScreen(authService: authService),
                          );
                        },
                        icon: const Icon(Icons.mail_outline_rounded, size: 23),
                        label: Text('auth_receive_email_link'.tr),
                        style: FilledButton.styleFrom(
                          backgroundColor: KpbColors.actionPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: KpbTextStyles.bodyFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Un élève qui a déjà un compte (nouveau téléphone,
                    // réinstallation) ne doit pas croire qu'il en crée un
                    // second : les deux boutons le reconnectent.
                    Text(
                      'auth_have_account_hint'.tr,
                      textAlign: TextAlign.center,
                      style: KpbTextStyles.caption.copyWith(
                        color: KpbColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Sans FittedBox : il rétrécissait la note jusqu'à
                    // l'illisible ; elle passe à la ligne.
                    Text(
                      'auth_intelligence_note'.tr,
                      textAlign: TextAlign.center,
                      // textMuted, pas textFaint : ce texte est PORTEUR DE
                      // SENS (il annonce KPB Intelligence) sur fond clair, où
                      // textFaint rend 2,56:1 — sous le seuil AA de 4,5:1 — et
                      // le FittedBox le rétrécit encore. Le token s'interdit
                      // lui-même cet usage ; un test le calcule désormais.
                      style: const TextStyle(
                        color: KpbColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: KpbColors.textMuted,
                        minimumSize: const Size(0, 44),
                        textStyle: const TextStyle(
                          fontFamily: KpbTextStyles.bodyFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text('auth_explore_guest'.tr),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// « Connexion réussie, on prépare ton espace… » : remplace les actions
/// pendant que [navigateAfterAuth] lit le compte.
class _FinishingAuthPanel extends StatelessWidget {
  const _FinishingAuthPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: KpbColors.actionPrimary),
          const SizedBox(height: 16),
          Text(
            'auth_finishing_session'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KpbColors.brandNavy,
              fontSize: KpbFontSize.md,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Icon(icon, size: 24, color: KpbColors.actionPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: KpbColors.gray700,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The [navigateAfterAuth] call still resolving the session, if any.
///
/// Two triggers can race on one sign-in: the `signedIn` listener on this screen
/// (still mounted under the pushed magic-link screens) and the explicit call
/// made by `MagicLinkVerifyScreen` once `verifyOTP` returns. The second one
/// joins the first instead of replaying `Get.offAll` and logging a duplicate
/// login/sign-up event — and, unlike before, it WAITS for it, so the code
/// screen keeps its spinner until the account is ready.
Future<AuthSessionOutcome>? _authNavigation;

/// Resumes the authenticated session after Google / magic-link sign-in.
///
/// Logs the auth outcome once, with the accurate [method] ('google' | 'email')
/// and the signup-vs-login distinction: a user with no completed onboarding is
/// treated as a new sign-up (`sign_up` event carrying the signup method),
/// otherwise a returning login. Centralized here so callers don't double-log.
/// A null [method] (retry after a cold start) logs nothing.
///
/// When the profile could not be READ ([AuthSessionOutcome.accountUnavailable])
/// the student goes neither to onboarding nor to the shell: they land on
/// [AccountRecoveryScreen] — or stay on it when [stayOnFailure] is set (its own
/// « Réessayer »).
Future<AuthSessionOutcome> navigateAfterAuth({
  String? method = 'email',
  bool stayOnFailure = false,
}) {
  final inFlight = _authNavigation;
  if (inFlight != null) return inFlight;
  final run = _resumeSession(method: method, stayOnFailure: stayOnFailure);
  _authNavigation = run;
  // Reset so a later sign-out → sign-in in the same session still navigates.
  return run.whenComplete(() => _authNavigation = null);
}

Future<AuthSessionOutcome> _resumeSession({
  required String? method,
  required bool stayOnFailure,
}) async {
  final controller = Get.find<AppController>();
  final outcome = await controller.finishAuthSession();
  if (outcome == AuthSessionOutcome.accountUnavailable) {
    unawaited(AnalyticsService.instance.logAuthFailed(
      method: method ?? 'session',
      reason: 'account_unavailable',
    ));
    if (!stayOnFailure) {
      unawaited(Get.offAll(() => AccountRecoveryScreen(method: method)));
    }
    return outcome;
  }
  if (controller.hasCompletedOnboarding) {
    if (method != null) {
      unawaited(AnalyticsService.instance.logLogin(method: method));
    }
    unawaited(Get.offAll(() => const AppRootShell()));
  } else {
    if (method != null) {
      unawaited(AnalyticsService.instance.logRegister(method: method));
    }
    unawaited(Get.offAll(() => const OnboardingScreen()));
  }
  return outcome;
}
