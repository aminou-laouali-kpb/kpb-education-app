part of '../case_detail_screen.dart';

// En-tête du dossier, anneau de progression et prochaine étape.

// ─────────────────────────────────────────────────────────────────────────────
// Header — back · flag · institution · program · progress ring
// ─────────────────────────────────────────────────────────────────────────────
class _DossierHeader extends StatelessWidget {
  const _DossierHeader({
    required this.ctrl,
    required this.studentCase,
    required this.progress,
  });

  final AppController ctrl;
  final StudentCase studentCase;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = studentCase;
    final title = ctrl.resolve(c.title);
    final contextLabel = ctrl.resolve(c.contextLabel);
    final flag = _dossierFlag('$title $contextLabel');
    final pill = _statusPill(c.status);
    final pct = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KpbColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: KpbColors.border),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 19, color: KpbColors.brandNavy),
              ),
            ),
            const SizedBox(width: 10),
            if (flag != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_caseTypeIcon(c.type),
                    size: 18, color: KpbColors.actionPrimary),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: KpbColors.brandNavy,
                      height: 1.2,
                    ),
                  ),
                  if (contextLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ProgressRing(value: progress, pct: pct),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pill.bg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                pill.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: pill.fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                c.referenceCode,
                overflow: TextOverflow.ellipsis,
                // textMuted : la référence du dossier est ce que l'étudiant
                // LIT au conseiller sur WhatsApp — à 11,5 px et 2,56:1 sur
                // fond clair, elle était à peine déchiffrable.
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.textMuted,
                ),
              ),
            ),
            if (c.isReferenceProvisional) ...[
              const SizedBox(width: 6),
              Text(
                'case_reference_provisional'.tr,
                style:
                    const TextStyle(fontSize: 10.5, color: KpbColors.textMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.pct});
  final double value;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _RingPainter(value),
        child: Center(
          child: Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = KpbColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (value > 0) {
      final prog = Paint()
        ..color = KpbColors.actionPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, prog);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Next step
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.label,
    required this.title,
    required this.description,
  });

  final String label;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KpbColors.actionPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_right_alt_rounded,
                color: KpbColors.actionPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.actionPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.brandNavy,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: KpbColors.gray700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blue info tip
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTip extends StatelessWidget {
  const _InfoTip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: KpbColors.actionPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: KpbColors.actionPrimaryPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: KpbColors.brandNavy,
      ),
    );
  }
}
