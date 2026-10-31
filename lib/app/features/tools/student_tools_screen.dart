import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../ai_advisor/ai_consent.dart';
import '../etudes_en_france/eef_entry.dart';
import 'cv_generator_screen.dart';
import 'document_scanner_screen.dart';
import 'impact_dashboard_screen.dart';
import 'interview_simulator_screen.dart';
import 'motivation_letters_screen.dart';

/// Hub screen listing all student tools.
class StudentToolsScreen extends StatelessWidget {
  const StudentToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('student_tools_title'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          Text(
            'student_tools_intro'.tr,
            style: TextStyle(fontSize: 14, color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.lg),
          // ── Espace « Études en France » ─────────────────────────────────
          // La deuxième porte. Le tiroir n'est pas la seule : cet écran est
          // atteignable depuis l'accueil, et ne poser l'entrée que dans le
          // tiroir rejouerait le défaut PARC-05 déjà nommé plus bas.
          if (EefEntry.isVisible) ...[
            _ToolCard(
              icon: Icons.public_rounded,
              color: KpbColors.actionPrimary,
              title: 'eef_title'.tr,
              subtitle: 'eef_tools_subtitle'.tr,
              onTap: () => Get.to<void>(
                () => const EefEntry(source: 'student_tools'),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],
          // ── Les trois outils IA masqués par M1 ──────────────────────────
          // Le tiroir n'est pas la seule porte : cet écran-ci est atteignable
          // depuis l'accueil, et poser la garde sur le seul tiroir aurait rejoué
          // à l'identique le défaut PARC-05 (dix-huit points d'entrée, un seul
          // gardé). Voir AppConfig.aiToolsEnabled.
          if (AppConfig.aiToolsEnabled) ...[
            _ToolCard(
              icon: Icons.description_rounded,
              color: KpbColors.blue,
              title: 'cv_generator_title'.tr,
              subtitle: 'student_tools_cv_subtitle'.tr,
              onTap: () => openAiToolIfConsented(
                context,
                () => const CvGeneratorScreen(),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            _ToolCard(
              icon: Icons.mail_outline_rounded,
              color: KpbColors.success,
              title: 'letters_title'.tr,
              subtitle: 'student_tools_letters_subtitle'.tr,
              onTap: () => openAiToolIfConsented(
                context,
                () => const MotivationLettersScreen(),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            _ToolCard(
              icon: Icons.record_voice_over_rounded,
              color: KpbColors.gold,
              title: 'interview_title'.tr,
              subtitle: 'student_tools_interview_subtitle'.tr,
              onTap: () => openAiToolIfConsented(
                context,
                () => const InterviewSimulatorScreen(),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],
          _ToolCard(
            icon: Icons.document_scanner_rounded,
            color: KpbColors.sky,
            title: 'scanner_title'.tr,
            subtitle: 'student_tools_scanner_subtitle'.tr,
            onTap: () => Get.to(() => const DocumentScannerScreen()),
          ),
          if (RemoteFeatureFlags.instance.publicImpactStatsEnabled) ...[
            const SizedBox(height: KpbSpacing.md),
            _ToolCard(
              icon: Icons.insights_rounded,
              color: KpbColors.navy,
              title: 'impact_title'.tr,
              subtitle: 'student_tools_impact_subtitle'.tr,
              onTap: () => Get.to(() => const ImpactDashboardScreen()),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.kpb.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.kpb.textMuted),
        ],
      ),
    );
  }
}
