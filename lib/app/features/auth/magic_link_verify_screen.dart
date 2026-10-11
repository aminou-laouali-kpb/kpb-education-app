import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'auth_welcome_screen.dart';

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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify({String? code, String? token}) async {
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
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                decoration: KpbInputDecoration.build(
                  context,
                  label: 'auth_magic_verify_code_label'.tr,
                  prefixIcon: Icons.pin_outlined,
                ).copyWith(counterText: ''),
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) {
                  if (_codeController.text.length == 6) {
                    _verify(code: _codeController.text);
                  }
                },
              ),
              const SizedBox(height: KpbSpacing.md),
              FilledButton(
                onPressed: _loading || _codeController.text.length != 6
                    ? null
                    : () => _verify(code: _codeController.text),
                child: Text('auth_magic_verify_button'.tr),
              ),
              if (_error != null) ...[
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KpbColors.error, fontSize: 13),
                ),
              ],
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
