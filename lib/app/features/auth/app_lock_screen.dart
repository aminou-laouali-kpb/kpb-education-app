import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/security_service.dart';
import '../../core/ui/app_tokens.dart';

/// Full screen overlay that requires biometric authentication to dismiss.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Trigger auth immediately upon showing the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() => _hasError = false);
    bool success;
    try {
      success = await SecurityService.instance.authenticate();
    } catch (_) {
      // Ceinture et bretelles : une erreur inattendue doit afficher
      // « Authentification échouée » et laisser « Déverrouiller », jamais
      // sortir de l'écran sans rien dire.
      success = false;
    }
    // The screen may have been popped while the auth dialog was open; guard
    // against setState/navigation on a disposed State.
    if (!mounted) return;
    if (success) {
      Get.back(); // Dismiss the lock screen
    } else {
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope equivalent to prevent back navigation
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: KpbColors.bgDarkMidnight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Un cadenas dessiné localement, et non une animation tirée d'un
                // CDN tiers.
                //
                // Cette place était occupée par le seul `Lottie.network` du
                // dépôt, sur une URL lottiefiles qui répond **403**. Deux
                // conséquences, chacune suffisante :
                //
                //  · en release, lottie ne rend son erreur que sous `kDebugMode`
                //    (lottie_builder.dart:538-548) — l'écran de verrouillage
                //    affichait donc un TROU de 180×180 à chaque ouverture, et
                //    personne ne le voyait en développement ;
                //  · et chaque déverrouillage envoyait l'adresse IP de
                //    l'utilisateur à un tiers que la déclaration de
                //    confidentialité des stores ne mentionne pas. Sur un écran de
                //    sécurité, c'est le pire endroit possible pour une fuite
                //    involontaire.
                //
                // Le paquet `lottie` n'avait aucun autre usage dans l'app : il
                // sort de pubspec.yaml avec cet appel.
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 88,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'app_locked'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'app_lock_prompt'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 48),
                if (_hasError) ...[
                  Text(
                    'auth_failed'.tr,
                    style: TextStyle(color: KpbColors.error, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KpbColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KpbRadius.pill)),
                  ),
                  child: Text('unlock'.tr,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
