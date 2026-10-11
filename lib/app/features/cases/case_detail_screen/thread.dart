part of '../case_detail_screen.dart';

// Fil de messages, chronologie et indicateur de saisie.

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.ctrl});
  final CaseMessage msg;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final isStudent = msg.senderRole == 'student';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isStudent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: KpbColors.actionPrimarySoft,
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : 'K',
                style: const TextStyle(
                  color: KpbColors.actionPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStudent ? KpbColors.actionPrimary : KpbColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isStudent ? 16 : 4),
                  bottomRight: Radius.circular(isStudent ? 4 : 16),
                ),
                border: isStudent ? null : Border.all(color: KpbColors.border),
                boxShadow: _cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.resolve(msg.body),
                    style: TextStyle(
                      fontSize: 14,
                      color: isStudent ? Colors.white : KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm', ctrl.localeCode).format(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isStudent ? Colors.white54 : KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isStudent) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History timeline item
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.ctrl,
  });

  final CaseTimelineEvent event;
  final bool isLast;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy', ctrl.localeCode).format(event.createdAt);
    final dotColor = _dotColor(event.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: dotColor.withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 40, color: KpbColors.surfaceMuted),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctrl.resolve(event.title),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11.5, color: KpbColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _dotColor(CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
      case CaseStatus.counselorAssigned:
      case CaseStatus.scheduled:
      case CaseStatus.inProgress:
      case CaseStatus.applicationSubmitted:
        return KpbColors.actionPrimary;
      case CaseStatus.underReview:
      case CaseStatus.waitingDecision:
      case CaseStatus.documentsNeeded:
      case CaseStatus.awaitingPayment:
        return KpbColors.warning;
      case CaseStatus.awaitingStudent:
      case CaseStatus.rejected:
        return KpbColors.error;
      case CaseStatus.completed:
        return KpbColors.success;
      case CaseStatus.cancelled:
      case CaseStatus.draft:
        return KpbColors.textFaint;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp CTA — "Contact a KPB counselor" (official KPB line only)
// ─────────────────────────────────────────────────────────────────────────────
class _GreenWhatsAppCta extends StatelessWidget {
  const _GreenWhatsAppCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'case_continue_whatsapp'.tr,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: KpbColors.whatsapp,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: KpbColors.whatsapp.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'case_continue_whatsapp'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated bouncing dot for the typing indicator.
class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});
  final Duration delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: KpbColors.textFaint,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
