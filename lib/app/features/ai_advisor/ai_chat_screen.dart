import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/ai_content_report_service.dart';
import '../../core/ui/components/verified_advisor_sheet.dart';
import '../../core/ui/components/ai_content_report_sheet.dart';
import '../tools/motivation_letters_screen.dart';
import '../../core/ui/app_tokens.dart';
import 'coach_quota_handoff.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool reportable;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.reportable = false,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _coach = CoachService();
  final List<AiMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  int? _remainingMessages;
  int? _weeklyQuota;
  List<String> _suggestions = const [];
  String? _assistantDraft;
  String? _bootstrapError;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final controller = Get.find<AppController>();
    final profile = controller.profile;
    if (profile == null) {
      if (mounted) setState(() => _bootstrapping = false);
      return;
    }

    try {
      final quota = await _coach.fetchQuota(profile.id);
      final suggestions = await _coach.fetchSuggestions(profile.id);
      final conversationId =
          await _coach.ensureConversation(userId: profile.id, profile: profile);
      final history = await _coach.fetchHistory(conversationId);

      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _bootstrapError = null;
        _remainingMessages = quota.remaining;
        _weeklyQuota = quota.limit;
        _suggestions = suggestions;
        if (history.isNotEmpty) {
          // Rehydrate the persisted conversation (survives app restarts).
          _messages.addAll(history.map(
            (m) => AiMessage(
              text: m.content,
              isUser: m.isUser,
              timestamp: DateTime.now(),
              reportable: !m.isUser,
            ),
          ));
        } else {
          _messages.add(AiMessage(
            text: 'coach_welcome_message'
                .trParams({'name': profile.fullName.split(' ').first}),
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      });
      _scrollToBottom();
    } catch (_) {
      unawaited(AnalyticsService.instance.logCoachLoadFailed());
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _bootstrapError = 'coach_load_error';
        _remainingMessages = null;
        _weeklyQuota = null;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
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

  /// Honest tap target for the quota chip. Premium is NOT built yet (a later
  /// PR), so this only surfaces the real remaining/limit — never a paywall or
  /// fake checkout.
  void _showQuotaInfo() {
    KpbToast.info(
      'coach_quota_info_body'.trParams({
        'rem': '${_remainingMessages ?? '—'}',
        'total': '${_weeklyQuota ?? '—'}',
      }),
      title: 'coach_quota_info_title'.tr,
    );
  }

  bool get _quotaExhausted =>
      _remainingMessages != null && _remainingMessages! <= 0;

  /// The conversion the free AI exists for: the student just hit the paywall
  /// moment, hand them to a human KPB advisor with the conversation context.
  /// The verified-advisor sheet shows the exact prefill (and official number)
  /// before anything leaves the app, then logs the `whatsapp_handoff` funnel
  /// event through the shared choke-point in whatsapp_utils.
  void _continueWithAdvisor() {
    String? lastUserMessage;
    for (final msg in _messages.reversed) {
      if (msg.isUser) {
        lastUserMessage = msg.text;
        break;
      }
    }
    final topic = clipCoachHandoffTopic(lastUserMessage);
    final prefill = topic == null
        ? 'coach_wa_prefill'.tr
        : '${'coach_wa_prefill'.tr}\n'
            '${'coach_wa_prefill_topic'.trParams({'topic': topic})}';
    unawaited(showVerifiedAdvisorThenWhatsApp(
      prefill: prefill,
      source: 'ai_quota_exhausted',
      contextType: 'coach',
    ));
  }

  /// [source] : `input` (zone de saisie) ou `suggestion` (puce tapée) — pour
  /// savoir si les suggestions servent. Mesuré par `ai_coach_message_sent`,
  /// qui ne porte JAMAIS le texte.
  Future<void> _sendMessage(String text, {String source = 'input'}) async {
    if (text.trim().isEmpty) return;
    // Un seul tour à la fois : un deuxième envoi pendant le streaming remettait
    // le brouillon à zéro et mélangeait les deux réponses (et le quota était
    // décompté deux fois).
    if (_isTyping) return;
    // Defensive only: when the quota is exhausted the input bar is replaced by
    // the advisor hand-off panel, so nothing should reach this path.
    if (_quotaExhausted) return;

    final controller = Get.find<AppController>();
    final profile = controller.profile;
    if (profile == null) return;

    setState(() {
      _messages.add(AiMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      // null (et pas '') jusqu'au premier token : c'est ce qui affiche
      // l'indicateur « en train d'écrire » pendant l'attente.
      _assistantDraft = null;
    });
    _scrollToBottom();
    _textController.clear();

    var assistantIndex = -1;
    // Comment le tour s'est terminé — `unreachable` tant que le flux n'a rien
    // dit, puis écrasé par l'événement qui le clôt.
    var result = 'unreachable';

    try {
      await for (final event in _coach.sendMessage(
        userId: profile.id,
        profile: profile,
        message: text,
      )) {
        if (!mounted) return;

        if (event.type == 'error') {
          // The server enforces the quota inside the stream too (the local
          // counter can be stale, e.g. two devices). Show the same friendly
          // hand-off state as a client-side exhaustion — never a raw error.
          final isQuotaRefusal = looksLikeCoachQuotaError(event.message);
          result = isQuotaRefusal ? 'quota_refused' : 'error';
          setState(() {
            _isTyping = false;
            if (isQuotaRefusal) {
              _remainingMessages = 0;
              _messages.add(AiMessage(
                text: 'coach_quota_reached_body'
                    .trParams({'quota': '$_weeklyQuota'}),
                isUser: false,
                timestamp: DateTime.now(),
              ));
            } else {
              _messages.add(AiMessage(
                text: event.message ?? 'coach_unavailable'.tr,
                isUser: false,
                timestamp: DateTime.now(),
              ));
            }
          });
          break;
        }

        if (event.type == 'token' && event.text != null) {
          _assistantDraft = '${_assistantDraft ?? ''}${event.text}';
          if (assistantIndex == -1) {
            _messages.add(AiMessage(
              text: _assistantDraft!,
              isUser: false,
              timestamp: DateTime.now(),
              reportable: true,
            ));
            assistantIndex = _messages.length - 1;
          } else {
            _messages[assistantIndex] = AiMessage(
              text: _assistantDraft!,
              isUser: false,
              timestamp: _messages[assistantIndex].timestamp,
              reportable: true,
            );
          }
          setState(() {});
          _scrollToBottom();
        }

        if (event.type == 'done') {
          result = 'ok';
          setState(() {
            _isTyping = false;
            if (event.quotaRemaining != null) {
              _remainingMessages = event.quotaRemaining!;
            } else {
              final current = _remainingMessages ?? 0;
              final cap = _weeklyQuota ?? current;
              _remainingMessages = (current - 1).clamp(0, cap);
            }
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(AiMessage(
          text: 'coach_unreachable'.tr,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    unawaited(AnalyticsService.instance.logCoachMessageSent(
      source: source,
      result: result,
      quotaRemaining: _remainingMessages,
    ));

    if (mounted && _isTyping) {
      setState(() => _isTyping = false);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _bootstrapError != null
                  ? _buildBootstrapError()
                  : _bootstrapping
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length +
                              (_isTyping && _assistantDraft == null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildTypingIndicator();
                            }
                            final msg = _messages[index];
                            return _buildMessageBubble(msg);
                          },
                        ),
            ),
            if (_bootstrapError == null &&
                !_bootstrapping &&
                !_quotaExhausted &&
                _messages.length <= 2 &&
                !_isTyping &&
                _suggestions.isNotEmpty)
              _buildSuggestions(),
            // Quota épuisé = LE moment de conversion : la zone de saisie cède
            // sa place à un bloc persistant de hand-off vers un conseiller
            // humain (jamais un toast, jamais une impasse).
            if (_bootstrapError != null || _bootstrapping)
              const SizedBox.shrink()
            else if (_quotaExhausted)
              _buildQuotaHandoffPanel(context)
            else
              _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBootstrapError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'coach_load_error'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: KpbColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _bootstrapping = true;
                  _bootstrapError = null;
                });
                unawaited(_bootstrap());
              },
              child: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.arrow_back_rounded,
                    color: KpbColors.brandNavy, size: 20),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KpbColors.actionPrimary, KpbColors.decorSky],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'coach_ai_title'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
                Text(
                  'coach_status_tagline'.tr,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Real quota chip — bound to CoachService quota. Tap is an honest
          // info toast (Premium is a later PR), never a paywall.
          GestureDetector(
            onTap: _showQuotaInfo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: KpbColors.surfaceMuted,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${_remainingMessages ?? '—'}/${_weeklyQuota ?? '—'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.82 : 0.88),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? KpbColors.actionPrimary : KpbColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: KpbColors.border),
          boxShadow: isUser ? null : _cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _parseAndRichText(msg.text, isUser),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isUser && msg.reportable) ...[
                  InkWell(
                    key: const ValueKey('coach_report_ai_output'),
                    onTap: () => unawaited(showAiContentReportSheet(
                      context: context,
                      surface: AiContentSurface.coach,
                      generatedText: msg.text,
                      sourceReference: _coach.conversationId,
                    )),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 12,
                            color: KpbColors.textFaint,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'ai_report_action'.tr,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: KpbColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isUser ? Colors.white70 : KpbColors.textFaint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Renders **bold** markdown. On the user's blue bubble everything is white;
  /// on the assistant's white bubble body is navy and bold is accented blue.
  Widget _parseAndRichText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : KpbColors.brandNavy;
    final boldColor = isUser ? Colors.white : KpbColors.actionPrimary;
    final baseStyle = TextStyle(color: baseColor, fontSize: 13, height: 1.5);

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      final parts = line.split('**');
      for (var j = 0; j < parts.length; j++) {
        final isBold = j % 2 == 1;
        spans.add(TextSpan(
          text: parts[j],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? boldColor : baseColor,
          ),
        ));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KpbColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
          boxShadow: _cardShadow,
        ),
        child: const SizedBox(
          width: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TypingDot(index: 0),
              _TypingDot(index: 1),
              _TypingDot(index: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _suggestions.map((sug) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              onTap: () => _sendMessage(sug, source: 'suggestion'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: KpbColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: KpbColors.actionPrimary.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Text(
                  sug,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.actionPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Persistent quota-exhausted state, shown IN PLACE of the input bar: a
  /// benevolent explanation plus a prominent "continue with a KPB advisor on
  /// WhatsApp" CTA (the free AI is a lead generator; this is the conversion).
  Widget _buildQuotaHandoffPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                size: 18,
                color: KpbColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'coach_quota_handoff_title'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'coach_quota_handoff_body'.trParams({'quota': '$_weeklyQuota'}),
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: KpbColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _continueWithAdvisor,
              style: FilledButton.styleFrom(
                // Vert WhatsApp = token marque externe (allowlist §10.4),
                // même CTA que les autres hand-offs conseiller de l'app.
                backgroundColor: KpbColors.whatsapp,
                foregroundColor: KpbColors.brandNavy,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(
                'coach_quota_handoff_cta'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: KpbColors.canvas,
        border: Border(top: BorderSide(color: KpbColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Left round button → the real motivation-letter tool.
          //
          // Masqué par M1, et c'est le chemin le plus facile à oublier : ce
          // raccourci part du COACH, la seule surface IA que le plan garde en
          // ligne. Une garde posée sur le tiroir et la boîte à outils l'aurait
          // laissé grand ouvert. Le coach lui-même continue de fonctionner —
          // son consentement est vérifié côté serveur avant tout appel au
          // fournisseur, contrairement à `/tools/personalize-letter`.
          if (AppConfig.aiToolsEnabled) ...[
            Semantics(
              button: true,
              label: 'coach_generate_letter'.tr,
              child: GestureDetector(
                onTap: () => Get.to(() => const MotivationLettersScreen()),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: KpbColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: KpbColors.textMuted, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: KpbColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: KpbColors.border, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  color: KpbColors.brandNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'coach_input_hint'.tr,
                  hintStyle:
                      const TextStyle(color: KpbColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'a11y_send_message'.tr,
            child: GestureDetector(
              onTap:
                  _isTyping ? null : () => _sendMessage(_textController.text),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color:
                      _isTyping ? KpbColors.textFaint : KpbColors.actionPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int index;
  const _TypingDot({required this.index});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;

  static const _colors = [
    KpbColors.textFaint,
    KpbColors.borderStrong,
    KpbColors.border
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _animController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _anim.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _colors[widget.index % _colors.length],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
