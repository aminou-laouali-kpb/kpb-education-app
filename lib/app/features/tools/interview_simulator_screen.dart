import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/utils/ai_error_message.dart';
import '../ai_advisor/ai_consent.dart';
import '../ai_advisor/ai_disclosure_banner.dart';
import '../etudes_en_france/eef_help_line.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

/// One question turn: the prompt plus the student's real answer and the real
/// backend feedback once submitted.
class _IvTurn {
  _IvTurn(this.question);
  final String question;
  String? answer;
  Map<String, dynamic>? feedback;
}

/// AI Interview Simulator — visa / admission / scholarship mock interviews
/// with per-answer scoring and feedback (powered by Groq).
class InterviewSimulatorScreen extends StatefulWidget {
  const InterviewSimulatorScreen({super.key, this.fromEefHub = false});

  /// `true` UNIQUEMENT quand l'écran est ouvert depuis le hub de l'espace « Études
  /// en France » : une ligne « Besoin d'aide pour préparer ton entretien ? »
  /// ouvre alors WhatsApp vers le conseiller, au début de l'écran (le choix du
  /// type d'entretien) — pas pendant l'exercice, qu'elle interromprait. Ailleurs
  /// (boîte à outils, tiroir, dossier d'un étudiant), rien ne change. Un
  /// paramètre explicite plutôt qu'un état global.
  final bool fromEefHub;

  @override
  State<InterviewSimulatorScreen> createState() =>
      _InterviewSimulatorScreenState();
}

enum _Stage { pickType, loading, chat }

class _InterviewSimulatorScreenState extends State<InterviewSimulatorScreen> {
  final _ctrl = Get.find<AppController>();
  final _answerCtrl = TextEditingController();
  final _scrollController = ScrollController();

  _Stage _stage = _Stage.pickType;
  String _type = 'visa';
  List<_IvTurn> _turns = [];
  int _currentIndex = 0;
  bool _evaluating = false;

  _IvTurn? get _currentTurn =>
      _turns.isEmpty ? null : _turns[_currentIndex.clamp(0, _turns.length - 1)];

  bool get _currentAnswered => _currentTurn?.feedback != null;

  bool get _isLast => _currentIndex >= _turns.length - 1;

  bool get _isDone => _turns.isNotEmpty && _isLast && _currentAnswered;

  @override
  void dispose() {
    _answerCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _start(String type) async {
    setState(() {
      _type = type;
      _stage = _Stage.loading;
    });
    try {
      final p = _ctrl.profile;
      final fieldId = p?.fieldIds.isNotEmpty == true ? p!.fieldIds.first : '';
      final field = _ctrl.fields
              .where((f) => f.id == fieldId)
              .map((f) => _ctrl.resolve(f.name))
              .firstOrNull ??
          '';
      final targetId = p?.targetCountryIds.isNotEmpty == true
          ? p!.targetCountryIds.first
          : '';
      final country = _ctrl.countries
              .where((c) => c.id == targetId)
              .map((c) => _ctrl.resolve(c.name))
              .firstOrNull ??
          '';

      // Leading slash required: Dio concatenates `baseUrl + path`, and the base
      // ends with `/api`, so 'tools/…' resolved to `/apitools/…` → 404.
      final result =
          await _ctrl.apiClient.postAi('/tools/interview/questions', {
        'type': type,
        'fieldOfStudy': field,
        'targetCountry': country,
        'language': _ctrl.localeCode == 'en' ? 'en' : 'fr',
      });
      final qs = (result['questions'] as List?)?.cast<String>() ?? [];
      if (mounted) {
        setState(() {
          _turns = qs.map((q) => _IvTurn(q)).toList();
          _currentIndex = 0;
          _stage = qs.isEmpty ? _Stage.pickType : _Stage.chat;
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      if (isAiConsentRequiredError(error)) {
        final granted = await ensureAiConsent(context, _ctrl);
        if (granted && mounted) {
          return _start(type);
        }
        if (mounted) setState(() => _stage = _Stage.pickType);
        return;
      }
      if (mounted) {
        setState(() => _stage = _Stage.pickType);
        KpbToast.error(aiErrorMessage(error), context: context);
      }
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerCtrl.text.trim();
    final turn = _currentTurn;
    if (text.isEmpty || turn == null) return;
    setState(() => _evaluating = true);
    try {
      final result = await _ctrl.apiClient.postAi('/tools/interview/feedback', {
        'type': _type,
        'question': turn.question,
        'answer': text,
        'language': _ctrl.localeCode == 'en' ? 'en' : 'fr',
      });
      if (mounted) {
        setState(() {
          turn.answer = text;
          turn.feedback = result;
        });
        _answerCtrl.clear();
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      if (isAiConsentRequiredError(error)) {
        final granted = await ensureAiConsent(context, _ctrl);
        if (granted && mounted) {
          return _submitAnswer();
        }
        return;
      }
      if (mounted) {
        KpbToast.error(aiErrorMessage(error), context: context);
      }
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  void _next() {
    setState(() {
      if (_currentIndex < _turns.length - 1) _currentIndex++;
    });
    _scrollToBottom();
  }

  void _replay() {
    _answerCtrl.clear();
    _start(_type);
  }

  /// Mean of the REAL per-answer scores — a derived summary, never a made-up
  /// number.
  int get _averageScore {
    final scores = _turns
        .map((t) => (t.feedback?['score'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AiDisclosureBanner(),
            ),
            Expanded(
              child: switch (_stage) {
                _Stage.pickType => _buildPicker(),
                _Stage.loading =>
                  const Center(child: CircularProgressIndicator()),
                _Stage.chat => _buildChat(),
              },
            ),
            if (_stage == _Stage.chat && !_isDone) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final subtitle = _stage == _Stage.chat && _turns.isNotEmpty
        ? 'interview_header_progress'.trParams({
            'current': '${_currentIndex + 1}',
            'total': '${_turns.length}',
          })
        : 'interview_header_subtitle'.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(bottom: BorderSide(color: KpbColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Semantics(
              button: true,
              label: 'a11y_back'.tr,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: KpbColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: KpbColors.brandNavy, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: KpbColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic_rounded, color: KpbColors.warning),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'interview_title'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Type picker ──────────────────────────────────────────────────────────
  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'interview_picker_intro'.tr,
          style: const TextStyle(
              fontSize: 13, height: 1.5, color: KpbColors.textMuted),
        ),
        if (widget.fromEefHub) ...[
          const SizedBox(height: 12),
          const EefHelpLine(trigger: EefHelpTrigger.toolInterview),
        ],
        const SizedBox(height: 16),
        _typeCard(
          'visa',
          Icons.flight_takeoff_rounded,
          KpbColors.actionPrimary,
          KpbColors.actionPrimarySoft,
          'interview_type_visa_title'.tr,
          'interview_type_visa_subtitle'.tr,
        ),
        const SizedBox(height: 10),
        _typeCard(
          'admission',
          Icons.school_rounded,
          KpbColors.success,
          KpbColors.successLight,
          'interview_type_admission_title'.tr,
          'interview_type_admission_subtitle'.tr,
        ),
        const SizedBox(height: 10),
        _typeCard(
          'scholarship',
          Icons.emoji_events_rounded,
          KpbColors.warning,
          KpbColors.warningLight,
          'interview_type_scholarship_title'.tr,
          'interview_type_scholarship_subtitle'.tr,
        ),
      ],
    );
  }

  Widget _typeCard(String type, IconData icon, Color color, Color bg,
      String title, String subtitle) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _start(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KpbColors.border),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.brandNavy)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: KpbColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: KpbColors.borderStrong),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat transcript ────────────────────────────────────────────────────────
  Widget _buildChat() {
    final visible = _currentIndex + 1; // questions revealed so far
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < visible && i < _turns.length; i++)
          ..._turnWidgets(_turns[i]),
        if (_isDone) _completionCard(),
      ],
    );
  }

  List<Widget> _turnWidgets(_IvTurn turn) {
    return [
      // JURY question — dark bubble
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'interview_jury_label'.tr,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: KpbColors.textFaint,
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: const BoxDecoration(
            color: KpbColors.brandNavy,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Text(
            turn.question,
            style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      ),
      // Student answer — blue bubble
      if (turn.answer != null)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: KpbColors.actionPrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              turn.answer!,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: Colors.white),
            ),
          ),
        ),
      // Feedback rows
      if (turn.feedback != null) ..._feedbackWidgets(turn.feedback!),
    ];
  }

  List<Widget> _feedbackWidgets(Map<String, dynamic> fb) {
    final score = (fb['score'] as num?)?.toInt() ?? 0;
    final strengths = (fb['strengths'] as List?)?.cast<String>() ?? const [];
    final improvements =
        (fb['improvements'] as List?)?.cast<String>() ?? const [];
    final modelAnswer = fb['modelAnswer'] as String? ?? '';
    final tone = _scoreTone(score);

    return [
      // Score chip
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grade_rounded, size: 15, color: tone.fg),
            const SizedBox(width: 8),
            Text(
              'interview_score_line'.trParams({'score': '$score'}),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: tone.fg),
            ),
          ],
        ),
      ),
      for (final s in strengths)
        _feedbackRow(Icons.check_circle_rounded, KpbColors.success,
            KpbColors.successLight, s),
      for (final s in improvements)
        _feedbackRow(Icons.lightbulb_rounded, KpbColors.warning,
            KpbColors.warningLight, s),
      if (modelAnswer.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KpbColors.border),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: KpbColors.actionPrimary, size: 17),
                  const SizedBox(width: 6),
                  Text('model_answer'.tr,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.brandNavy)),
                ],
              ),
              const SizedBox(height: 6),
              Text(modelAnswer,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.55, color: KpbColors.gray700)),
            ],
          ),
        ),
    ];
  }

  Widget _feedbackRow(IconData icon, Color fg, Color bg, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: fg),
            ),
          ),
        ],
      ),
    );
  }

  ({Color fg, Color bg}) _scoreTone(int score) {
    if (score >= 75) return (fg: KpbColors.success, bg: KpbColors.successLight);
    if (score >= 50) return (fg: KpbColors.warning, bg: KpbColors.warningLight);
    return (fg: KpbColors.error, bg: KpbColors.errorLight);
  }

  Widget _completionCard() {
    final avg = _averageScore;
    final verdict = avg >= 75
        ? 'interview_verdict_strong'.tr
        : avg >= 50
            ? 'interview_verdict_promising'.tr
            : 'interview_verdict_practice'.tr;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: [
          const Text('🎓', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text('interview_complete_title'.tr,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy)),
          const SizedBox(height: 4),
          Text(
            'interview_score_line'.trParams({'score': '$avg'}),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: KpbColors.actionPrimary),
          ),
          const SizedBox(height: 4),
          Text(verdict,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: KpbColors.textMuted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: GestureDetector(
                  onTap: _replay,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KpbColors.border, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('interview_replay'.tr,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.textMuted)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: KpbColors.actionPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text('interview_back_to_application'.tr,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar: answer input, or "next question" after feedback ────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: KpbColors.canvas,
        border: Border(top: BorderSide(color: KpbColors.border, width: 0.5)),
      ),
      child: _currentAnswered ? _nextButton() : _answerInput(),
    );
  }

  Widget _answerInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: BoxDecoration(
              color: KpbColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: KpbColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _answerCtrl,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(
                  color: KpbColors.brandNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'interview_answer_hint'.tr,
                hintStyle:
                    const TextStyle(color: KpbColors.textFaint, fontSize: 13),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'interview_submit_answer'.tr,
          child: GestureDetector(
            onTap: _evaluating ? null : _submitAnswer,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _evaluating
                    ? KpbColors.actionPrimary.withValues(alpha: 0.6)
                    : KpbColors.actionPrimary,
                shape: BoxShape.circle,
              ),
              child: _evaluating
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nextButton() {
    return GestureDetector(
      onTap: _next,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: KpbColors.actionPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('interview_next_question'.tr,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
