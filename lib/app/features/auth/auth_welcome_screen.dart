import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_root_shell.dart';
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
      // The redirect lands in the app while the browser that showed the consent
      // screen may still be presented on top of it. Dismiss it first, otherwise
      // the user stares at the blank redirect page while the app has already
      // navigated behind it.
      await _authService.dismissAuthWebView();
      if (!mounted) return;
      // Success logging (login vs sign-up + method) is centralized in
      // navigateAfterAuth so it stays accurate for both Google and email.
      await navigateAfterAuth(method: _pendingMethod);
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

            return Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 24, sidePadding, 20),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 44),
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
                      const SizedBox(height: 28),
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
                      const SizedBox(height: 28),
                      Text(
                        'auth_intelligence_body'.tr,
                        style: const TextStyle(
                          color: KpbColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _BenefitRow(
                        icon: Icons.percent_rounded,
                        label: 'auth_intelligence_benefit_fit'.tr,
                      ),
                      const SizedBox(height: 17),
                      _BenefitRow(
                        icon: Icons.smart_toy_outlined,
                        label: 'auth_intelligence_benefit_ai'.tr,
                      ),
                      const SizedBox(height: 17),
                      _BenefitRow(
                        icon: Icons.support_agent_rounded,
                        label: 'auth_intelligence_benefit_support'.tr,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 58,
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: KpbTextStyles.bodyFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: () {
                            _pendingMethod = 'email';
                            Get.to(
                              () => MagicLinkEmailScreen(
                                  authService: authService),
                            );
                          },
                          icon:
                              const Icon(Icons.mail_outline_rounded, size: 23),
                          label: Text('auth_receive_email_link'.tr),
                          style: FilledButton.styleFrom(
                            backgroundColor: KpbColors.actionPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: KpbTextStyles.bodyFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
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
                  ),
                ),
              ),
            );
          },
        ),
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
                fontSize: 10,
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

/// True while a [navigateAfterAuth] call is still resolving the session.
///
/// Two triggers can race on one sign-in: the `signedIn` listener on this screen
/// (still mounted under the pushed magic-link screens) and the explicit call
/// made by `MagicLinkVerifyScreen` once `verifyOTP` returns. Without this guard
/// the second one replays `Get.offAll` and logs a duplicate login/sign-up event.
bool _authNavigationInFlight = false;

/// Resumes the authenticated session after Google / magic-link sign-in.
///
/// Logs the auth outcome once, with the accurate [method] ('google' | 'email')
/// and the signup-vs-login distinction: a user with no completed onboarding is
/// treated as a new sign-up (`sign_up` event carrying the signup method),
/// otherwise a returning login. Centralized here so callers don't double-log.
Future<void> navigateAfterAuth({String method = 'email'}) async {
  if (_authNavigationInFlight) return;
  _authNavigationInFlight = true;
  try {
    final controller = Get.find<AppController>();
    await controller.finishAuthSession();
    if (controller.hasCompletedOnboarding) {
      unawaited(AnalyticsService.instance.logLogin(method: method));
      unawaited(Get.offAll(() => const AppRootShell()));
    } else {
      unawaited(AnalyticsService.instance.logRegister(method: method));
      unawaited(Get.offAll(() => const OnboardingScreen()));
    }
  } finally {
    // Reset so a later sign-out → sign-in in the same session still navigates.
    _authNavigationInFlight = false;
  }
}
