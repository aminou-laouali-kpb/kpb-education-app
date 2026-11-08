import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'auth_welcome_screen.dart';

/// Le code à 6 chiffres, quelle que soit sa provenance : frappe, collage d'un
/// e-mail (« Ton code : 123 456 »), ou remplissage automatique du système.
///
/// `digitsOnly` seul gardait TOUS les chiffres d'un texte collé : « Code
/// 123456, valable 60 min » devenait « 12345660 », tronqué à « 123456 » par
/// chance — et « valable 60 min : 123456 » devenait « 601234 », un code faux
/// soumis d'office. On prend donc d'abord une suite ISOLÉE de six chiffres ;
/// à défaut, les six premiers chiffres.
class OtpCodeInputFormatter extends TextInputFormatter {
  const OtpCodeInputFormatter();

  static const length = 6;
  static final _isolatedCode = RegExp(r'(?<!\d)\d{6}(?!\d)');
  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final digits = raw.replaceAll(_nonDigit, '');
    if (digits == raw && digits.length <= length) return newValue;
    final code = _isolatedCode.firstMatch(raw)?.group(0) ??
        (digits.length > length ? digits.substring(0, length) : digits);
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }
}

/// Pourquoi la vérification du code a échoué, du point de vue de l'élève.
enum OtpVerifyFailure {
  /// Le serveur a refusé le code (faux, expiré, déjà utilisé).
  invalidCode,

  /// Trop d'essais : le serveur limite (429).
  rateLimited,

  /// Le serveur n'a pas pu répondre : réseau coupé, délai dépassé, 5xx. Le
  /// code est peut-être encore valide.
  network,
}

/// Classe une erreur de `verifyOTP` / `signInWithOtp`.
///
/// Avant la revue de la 58, TOUTE erreur s'affichait « Code invalide ou
/// expiré » : sur une 3G qui coupe, l'élève qui avait tapé le bon code en
/// redemandait un, ce qui invalidait le premier.
OtpVerifyFailure classifyOtpError(Object error) {
  if (error is AuthRetryableFetchException ||
      error is TimeoutException ||
      error is SocketException) {
    return OtpVerifyFailure.network;
  }
  if (error is AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429 || error.message.toLowerCase().contains('rate limit')) {
      return OtpVerifyFailure.rateLimited;
    }
    if (status != null && status >= 500) return OtpVerifyFailure.network;
    return OtpVerifyFailure.invalidCode;
  }
  // Erreur inconnue (client HTTP, plateforme) : rien ne dit que le code est
  // faux. On ne pousse pas l'élève à en redemander un.
  return OtpVerifyFailure.network;
}

class MagicLinkVerifyScreen extends StatefulWidget {
  const MagicLinkVerifyScreen({
    super.key,
    required this.authService,
    required this.email,
  });

  final AuthService authService;
  final String email;

  @override
  State<MagicLinkVerifyScreen> createState() => _MagicLinkVerifyScreenState();
}

class _MagicLinkVerifyScreenState extends State<MagicLinkVerifyScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  /// Erreur du RENVOI, affichée sous « Renvoyer le code » : écrite dans le
  /// champ, elle faisait croire que le code saisi était faux.
  String? _resendError;

  /// Le code vient de partir depuis l'écran précédent : « Renvoyer » attend
  /// 60 s dès l'arrivée (Supabase refuse un deuxième envoi avant, en 429).
  static const _cooldownSeconds = 60;
  int _resendCooldown = _cooldownSeconds;
  Timer? _cooldownTimer;

  /// Le dernier code soumis D'OFFICE (au 6e chiffre). Un même code n'est
  /// soumis d'office qu'une fois : la frappe, le collage et le remplissage
  /// automatique déclenchent tous `onChanged`, et le clavier peut encore
  /// envoyer « OK » derrière. Remis à zéro dès que le code est incomplet,
  /// pour qu'un code retapé reparte.
  String? _autoSubmittedCode;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// Au 6e chiffre, la vérification part seule — une seule fois par code.
  void _onCodeChanged(String value) {
    if (value.length < OtpCodeInputFormatter.length) {
      _autoSubmittedCode = null;
      setState(() {});
      return;
    }
    if (_loading || value == _autoSubmittedCode) {
      setState(() {});
      return;
    }
    _autoSubmittedCode = value;
    unawaited(_verify(code: value));
  }

  Future<void> _verify({String? code, String? token}) async {
    // Une seule soumission à la fois : le 6e chiffre, « OK » du clavier et le
    // bouton peuvent arriver dans la même seconde. `_loading` passe à vrai
    // de façon SYNCHRONE ci-dessous, avant le premier `await`.
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // Une session est déjà ouverte (une vérification précédente a fini par
    // aboutir après une erreur réseau, ou l'écouteur `signedIn` navigue) :
    // renvoyer le même code, déjà consommé, ferait répondre « Code invalide ».
    // On termine la connexion à la place.
    if (widget.authService.isLoggedIn) {
      await _finishSignIn();
      return;
    }

    try {
      await widget.authService.verifyMagicLink(
        email: widget.email,
        code: code,
        token: token,
      );
    } catch (error) {
      // L'erreur est arrivée, mais la session s'est ouverte quand même (le
      // serveur a consommé le code) : ce n'est pas un échec.
      if (widget.authService.isLoggedIn) {
        await _finishSignIn();
        return;
      }
      final failure = classifyOtpError(error);
      unawaited(AnalyticsService.instance.logAuthFailed(
        method: 'email',
        reason: switch (failure) {
          OtpVerifyFailure.invalidCode => 'verify_error',
          OtpVerifyFailure.rateLimited => 'rate_limited',
          OtpVerifyFailure.network => 'verify_network',
        },
      ));
      // Le même code pourra repartir d'office une fois le réseau revenu.
      if (failure != OtpVerifyFailure.invalidCode) _autoSubmittedCode = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (failure) {
          OtpVerifyFailure.invalidCode => 'auth_magic_verify_error'.tr,
          OtpVerifyFailure.rateLimited => 'auth_magic_verify_rate_limited'.tr,
          OtpVerifyFailure.network => 'auth_magic_verify_network'.tr,
        };
      });
      return;
    }
    // Le code est accepté (et consommé) : ce qui suit n'est plus une affaire
    // de code. Hors du `try` ci-dessus, une lecture de compte ratée ne
    // s'affiche plus « Code invalide » ; navigateAfterAuth mène alors à
    // l'écran « Réessayer ». Success logging is centralized there too.
    await _finishSignIn();
  }

  Future<void> _finishSignIn() async {
    try {
      await navigateAfterAuth(method: 'email');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _resendError = null;
    });
    try {
      await widget.authService.requestMagicLink(email: widget.email);
      if (!mounted) return;
      setState(() => _resendCooldown = _cooldownSeconds);
      _startCooldownTimer();
    } catch (error) {
      final failure = classifyOtpError(error);
      final rate = failure == OtpVerifyFailure.rateLimited;
      unawaited(AnalyticsService.instance.logAuthFailed(
          method: 'email', reason: rate ? 'rate_limited' : 'send_error'));
      if (!mounted) return;
      setState(() {
        _resendError = switch (failure) {
          OtpVerifyFailure.rateLimited => 'auth_magic_resend_cooldown'.tr,
          OtpVerifyFailure.network => 'auth_magic_verify_network_resend'.tr,
          OtpVerifyFailure.invalidCode => 'auth_magic_send_error'.tr,
        };
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCooldown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.pageBg,
        elevation: 0,
        leading: BackButton(color: context.kpb.textPrimary),
        title: Text('auth_magic_verify_title'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'auth_magic_verify_body'.trParams({'email': widget.email}),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: context.kpb.textSecondary,
                ),
              ),
              const SizedBox(height: KpbSpacing.xl),
              TextFormField(
                controller: _codeController,
                enabled: !_loading,
                autofocus: true,
                // Le système propose le code reçu (iOS : depuis Mail ou
                // Messages ; Android : gestionnaires de saisie) au-dessus du
                // clavier.
                autofillHints: const [AutofillHints.oneTimeCode],
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: OtpCodeInputFormatter.length,
                inputFormatters: const [OtpCodeInputFormatter()],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                decoration: KpbInputDecoration.build(
                  context,
                  label: 'auth_magic_verify_code_label'.tr,
                  prefixIcon: Icons.pin_outlined,
                ).copyWith(
                  counterText: '',
                  // L'erreur s'écrit DANS le champ, là où l'œil est.
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onChanged: _onCodeChanged,
                onFieldSubmitted: (_) {
                  if (_codeController.text.length ==
                      OtpCodeInputFormatter.length) {
                    unawaited(_verify(code: _codeController.text));
                  }
                },
              ),
              const SizedBox(height: KpbSpacing.md),
              FilledButton(
                onPressed: _loading ||
                        _codeController.text.length !=
                            OtpCodeInputFormatter.length
                    ? null
                    : () => _verify(code: _codeController.text),
                child: Text('auth_magic_verify_button'.tr),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: KpbSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const Spacer(),
              TextButton(
                onPressed: (_resending || _resendCooldown > 0) ? null : _resend,
                child: Text(
                  _resendCooldown > 0
                      ? 'auth_magic_resend_wait'.trParams(
                          {'seconds': '$_resendCooldown'},
                        )
                      : 'auth_magic_resend'.tr,
                ),
              ),
              if (_resendError != null)
                Text(
                  _resendError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: KpbFontSize.sm,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
