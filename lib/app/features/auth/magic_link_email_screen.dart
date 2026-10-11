import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'magic_link_verify_screen.dart';

class MagicLinkEmailScreen extends StatefulWidget {
  const MagicLinkEmailScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<MagicLinkEmailScreen> createState() => _MagicLinkEmailScreenState();
}

class _MagicLinkEmailScreenState extends State<MagicLinkEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.requestMagicLink(email: email);
      if (!mounted) return;
      unawaited(Get.to(
        () => MagicLinkVerifyScreen(
          authService: widget.authService,
          email: email,
        ),
      ));
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.pageBg,
        elevation: 0,
        leading: BackButton(color: context.kpb.textPrimary),
        title: Text('auth_magic_email_title'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'auth_magic_email_body'.tr,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: context.kpb.textSecondary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: KpbInputDecoration.build(
                    context,
                    label: 'email'.tr,
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'email_required'.tr;
                    }
                    final emailReg = RegExp(r'^[\w.+-]+@[\w-]+\.\w+$');
                    if (!emailReg.hasMatch(value.trim())) {
                      return 'email_invalid'.tr;
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    _error!,
                    style:
                        const TextStyle(color: KpbColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: KpbSpacing.lg),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('auth_magic_send_button'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
