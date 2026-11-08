import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'case_timeline_definition.dart';
import '../../core/ui/app_tokens.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

/// M14 per-status timeline rendered as the handoff's Dossier "step checklist":
/// a done step gets a green check + struck-through label, the current step a
/// numbered blue ring (plus a red "Your turn" badge only when it is genuinely
/// the student's move), an upcoming step a muted number, and a terminal
/// rejection a red cross.
///
/// Read-only by design: the steps are DERIVED from the case status (see
/// [buildCaseTimelineSteps]) — there is no per-step "mark done" action in the
/// model, so we render status-driven progress rather than fake toggles.
class CaseStatusTimeline extends StatelessWidget {
  const CaseStatusTimeline({super.key, required this.steps});

  final List<CaseTimelineStepViewModel> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              index: i,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.isLast,
  });

  final CaseTimelineStepViewModel step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = step.state == CaseTimelineStepState.passed ||
        step.state == CaseTimelineStepState.terminalSuccess;
    final isError = step.state == CaseTimelineStepState.terminalError;
    final isCurrent = step.state == CaseTimelineStepState.current;
    final yourTurn = isCurrent && isCaseStudentActionStatus(step.status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: KpbColors.canvas)),
      ),
      child: Row(
        children: [
          _Marker(
            done: done,
            isError: isError,
            isCurrent: isCurrent,
            number: index + 1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.titleFr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w700,
                    color: done
                        ? KpbColors.textFaint
                        : isError
                            ? KpbColors.error
                            : isCurrent
                                ? KpbColors.brandNavy
                                : KpbColors.gray700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: KpbColors.textFaint,
                  ),
                ),
                if ((step.subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle!,
                    // La date de l'étape est porteuse de sens : textMuted
                    // (4,76:1), jamais textFaint (revue avant la 58, n° 28).
                    style: const TextStyle(
                      fontSize: 11,
                      color: KpbColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (yourTurn) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KpbColors.errorLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'case_step_your_turn'.tr,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.done,
    required this.isError,
    required this.isCurrent,
    required this.number,
  });

  final bool done;
  final bool isError;
  final bool isCurrent;
  final int number;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: KpbColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    if (isError) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: KpbColors.error,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
      );
    }
    final accent = isCurrent ? KpbColors.actionPrimary : KpbColors.borderStrong;
    final numColor = isCurrent ? KpbColors.actionPrimary : KpbColors.textFaint;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: numColor,
        ),
      ),
    );
  }
}
