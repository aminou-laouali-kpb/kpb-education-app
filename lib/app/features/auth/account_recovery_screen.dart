import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/ui/kpb_components.dart';
import 'auth_welcome_screen.dart';

/// La session est ouverte, mais le profil du compte n'a pas pu être lu
/// (réseau coupé, délai, serveur indisponible).
///
/// Revue avant la 58 : cet échec était traité comme « pas de profil ». Un
/// élève qui avait déjà un compte partait à l'onboarding, et ses réponses
/// remplaçaient son profil serveur (niveau, pays, filières, date de
/// naissance). Ici, rien n'est écrit : l'élève réessaie, ou se déconnecte.
class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key, this.method});

  /// Méthode de connexion d'origine ('google' | 'email'), pour l'événement de
  /// connexion quand la reprise aboutit. Nulle après un démarrage à froid.
  final String? method;

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  bool _retrying = false;
  bool _stillFailing = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _stillFailing = false;
    });
    final outcome = await navigateAfterAuth(
      method: widget.method,
      stayOnFailure: true,
    );
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _stillFailing = outcome == AuthSessionOutcome.accountUnavailable;
    });
  }

  Future<void> _logout() async {
    await Get.find<AppController>().logout();
    unawaited(Get.offAll(() => const AppBootScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: context.kpb.textSecondary,
                ),
                const SizedBox(height: KpbSpacing.lg),
                Text(
                  'auth_account_unavailable_title'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: KpbFontSize.xl,
                    fontWeight: FontWeight.w800,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.md),
                Text(
                  'auth_account_unavailable_body'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: KpbFontSize.md,
                    height: 1.45,
                    color: context.kpb.textSecondary,
                  ),
                ),
                if (_stillFailing) ...[
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    'auth_account_unavailable_still'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: KpbFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: KpbSpacing.xl),
                FilledButton(
                  onPressed: _retrying ? null : _retry,
                  child: _retrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('auth_account_unavailable_retry'.tr),
                ),
                const SizedBox(height: KpbSpacing.sm),
                TextButton(
                  onPressed: _retrying ? null : _logout,
                  child: Text('auth_account_unavailable_logout'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
