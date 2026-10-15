import 'dart:async';
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
  int _resendCooldown = 0;

  /// Le dernier code soumis D'OFFICE (au 6e chiffre). Un même code n'est
  /// soumis d'office qu'une fois : la frappe, le collage et le remplissage
  /// automatique déclenchent tous `onChanged`, et le clavier peut encore
  /// envoyer « OK » derrière. Remis à zéro dès que le code est incomplet,
  /// pour qu'un code retapé reparte.
  String? _autoSubmittedCode;

  @override
  void dispose() {
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

    try {
      await widget.authService.verifyMagicLink(
        email: widget.email,
        code: code,
        token: token,
      );
      // Success logging is centralized in navigateAfterAuth (login vs sign-up
      // + method), so it is not duplicated here.
      await navigateAfterAuth(method: 'email');
    } catch (error) {
      unawaited(AnalyticsService.instance
          .logAuthFailed(method: 'email', reason: 'verify_error'));
      if (!mounted) return;
      setState(() {
        _error = 'auth_magic_verify_error'.tr;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await widget.authService.requestMagicLink(email: widget.email);
      if (!mounted) return;
      setState(() => _resendCooldown = 60);
      _startCooldownTimer();
    } catch (error) {
      final rate = error is AuthException &&
          (error.statusCode == '429' ||
              error.message.toLowerCase().contains('rate'));
      unawaited(AnalyticsService.instance.logAuthFailed(
          method: 'email', reason: rate ? 'rate_limited' : 'send_error'));
      setState(() {
        _error =
            rate ? 'auth_magic_resend_cooldown'.tr : 'auth_magic_send_error'.tr;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldownTimer() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || _resendCooldown <= 0) return;
      setState(() => _resendCooldown--);
      _startCooldownTimer();
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
            ],
          ),
        ),
      ),
    );
  }
}
