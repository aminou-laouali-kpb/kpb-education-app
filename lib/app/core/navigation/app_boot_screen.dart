import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/auth_service.dart';
import '../../features/auth/account_recovery_screen.dart';
import '../../features/auth/auth_welcome_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_root_shell.dart';

/// Resolves the first screen after app bootstrap based on auth/onboarding state.
class AppBootScreen extends StatelessWidget {
  const AppBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        if (controller.hasCompletedOnboarding || controller.isGuestMode) {
          return const AppRootShell();
        }

        final authService =
            Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
        final isAuthenticated = authService?.isLoggedIn ?? false;

        if (!isAuthenticated) {
          return const AuthWelcomeScreen();
        }

        // Connecté, mais le profil n'a pas pu être lu : on ne sait pas si ce
        // compte est déjà rempli. L'onboarding réécrirait le profil serveur.
        if (controller.accountLoadFailed) {
          return const AccountRecoveryScreen();
        }

        return const OnboardingScreen();
      },
    );
  }
}
