import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/ai_error_message.dart';
import '../ai_advisor/ai_consent.dart';
import '../ai_advisor/ai_disclosure_banner.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
/// What kind of document the student is submitting for AI review.
enum _DocumentKind { motivation, cv }

extension on _DocumentKind {
  /// Wire value expected by `POST /document-review`.
  String get apiValue => switch (this) {
        _DocumentKind.motivation => 'motivation',
        _DocumentKind.cv => 'cv',
      };

  String get label => switch (this) {
        _DocumentKind.motivation => 'doc_review_kind_motivation'.tr,
        _DocumentKind.cv => 'CV',
      };

  String get hint => switch (this) {
        _DocumentKind.motivation => 'doc_review_hint_motivation'.tr,
        _DocumentKind.cv => 'doc_review_hint_cv'.tr,
      };
}

/// Parsed structured feedback from the backend AI review.
class _DocumentReview {
  const _DocumentReview({
    required this.score,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.missing,
  });

  final int score;
  final String summary;
  final List<String> strengths;
  final List<_ReviewImprovement> improvements;
  final List<String> missing;

  factory _DocumentReview.fromApi(Map<String, dynamic> json) {
    return _DocumentReview(
      score: (json['score'] as num?)?.round() ?? 0,
      summary: json['summary'] as String? ?? '',
      strengths: _stringList(json['strengths']),
      improvements: (json['improvements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_ReviewImprovement.fromApi)
          .where((i) => i.point.isNotEmpty || i.suggestion.isNotEmpty)
          .toList(),
      missing: _stringList(json['missing']),
    );
  }

  static List<String> _stringList(dynamic raw) {
    return (raw as List<dynamic>? ?? const [])
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _ReviewImprovement {
  const _ReviewImprovement({required this.point, required this.suggestion});

  final String point;
  final String suggestion;

  factory _ReviewImprovement.fromApi(Map<String, dynamic> json) {
    return _ReviewImprovement(
      point: (json['point'] as String? ?? '').trim(),
      suggestion: (json['suggestion'] as String? ?? '').trim(),
    );
  }
}

/// "Relecture IA" — a student pastes a motivation letter or CV draft and gets
/// instant structured feedback (score, summary, strengths, improvements,
/// missing elements). Offline-safe: any failure surfaces a friendly message.
class DocumentReviewScreen extends StatefulWidget {
  const DocumentReviewScreen({super.key, this.apiClient});

  /// Injectable for tests; defaults to a fresh authenticated client.
  final AppApiClient? apiClient;

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen> {
  late final AppApiClient _api = widget.apiClient ?? AppApiClient();
  final TextEditingController _textController = TextEditingController();

  _DocumentKind _kind = _DocumentKind.motivation;
  bool _loading = false;
  String? _error;
  _DocumentReview? _review;

  bool get _canSubmit => !_loading && _textController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _loading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _review = null;
    });

    try {
      final result = await _api.reviewDocument(
        kind: _kind.apiValue,
        text: text,
        language: Get.locale?.languageCode ?? 'fr',
      );
      if (!mounted) return;
      final review = result['review'] as Map<String, dynamic>?;
      if (review == null) {
        setState(() => _error = 'doc_review_unavailable'.tr);
        return;
      }
      setState(() => _review = _DocumentReview.fromApi(review));
    } catch (error) {
      if (!mounted) return;
      if (isAiConsentRequiredError(error)) {
        final granted =
            await ensureAiConsent(context, Get.find<AppController>());
        if (granted && mounted) {
          return _analyze();
        }
        return;
      }
      setState(() => _error = aiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('doc_review_title'.tr),
        backgroundColor: context.kpb.pageBg,
        foregroundColor: context.kpb.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          Text(
            'doc_review_paste_hint'.tr,
            style:
                KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary),
          ),
          const SizedBox(height: KpbSpacing.md),
          const AiDisclosureBanner(),
          const SizedBox(height: KpbSpacing.lg),

          // ── Kind selector ──────────────────────────────────────────────
          Text('doc_review_kind_label'.tr, style: KpbTextStyles.label),
          const SizedBox(height: KpbSpacing.sm),
          Row(
            children: [
              _kindChip(_DocumentKind.motivation),
              const SizedBox(width: KpbSpacing.sm),
              _kindChip(_DocumentKind.cv),
            ],
          ),
          const SizedBox(height: KpbSpacing.lg),

          // ── Draft input ────────────────────────────────────────────────
          Text('doc_review_draft_label'.tr, style: KpbTextStyles.label),
          const SizedBox(height: KpbSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: context.kpb.inputBg,
              borderRadius: KpbRadius.mdBr,
              border: Border.all(color: context.kpb.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _textController,
              minLines: 6,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: KpbTextStyles.body,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _kind.hint,
                hintStyle:
                    KpbTextStyles.body.copyWith(color: context.kpb.textMuted),
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.md),

          KpbButton(
            text: 'doc_review_analyze_cta'.tr,
            icon: Icons.auto_awesome_rounded,
            fullWidth: true,
            loading: _loading,
            bgColor: _canSubmit ? KpbColors.actionPrimary : context.kpb.gray300,
            onPressed: _canSubmit ? _analyze : () {},
          ),

          if (_error != null) ...[
            const SizedBox(height: KpbSpacing.md),
            _errorBanner(_error!),
          ],

          if (_review != null) ...[
            const SizedBox(height: KpbSpacing.lg),
            _resultView(_review!),
          ],

          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }

  Widget _kindChip(_DocumentKind kind) {
    final selected = _kind == kind;
    return Expanded(
      child: GestureDetector(
        onTap: _loading
            ? null
            : () => setState(() {
                  _kind = kind;
                  // Keep the previous result/error on screen; only the next
                  // analysis reflects the new kind.
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? KpbColors.actionPrimary : context.kpb.surfaceBg,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(
              color: selected ? KpbColors.actionPrimary : context.kpb.gray200,
              width: 1,
            ),
          ),
          child: Text(
            kind.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.kpb.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.errorLight,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: KpbColors.error, size: 20),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView(_DocumentReview review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scoreCard(review),
        if (review.summary.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.md),
          KpbCard(
            child: Text(review.summary, style: KpbTextStyles.body),
          ),
        ],
        if (review.strengths.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.lg),
          _bulletSection(
            title: 'doc_review_strengths'.tr,
            icon: Icons.check_circle_rounded,
            color: KpbColors.success,
            bullets: review.strengths,
          ),
        ],
        if (review.improvements.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.lg),
          _improvementsSection(review.improvements),
        ],
        if (review.missing.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.lg),
          _bulletSection(
            title: 'doc_review_missing'.tr,
            icon: Icons.report_problem_rounded,
            color: KpbColors.warning,
            bullets: review.missing,
          ),
        ],
        const SizedBox(height: KpbSpacing.lg),
        Text(
          'doc_review_disclaimer'.tr,
          style: KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
        ),
      ],
    );
  }

  Widget _scoreCard(_DocumentReview review) {
    final score = review.score.clamp(0, 100);
    final color = score >= 75
        ? KpbColors.success
        : score >= 50
            ? KpbColors.warning
            : KpbColors.error;

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$score',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: KpbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('doc_review_score_label'.tr,
                    style: KpbTextStyles.label.copyWith(color: color)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: KpbRadius.pillBr,
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 8,
                    backgroundColor: context.kpb.gray200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$score / 100',
                    style: KpbTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> bullets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title, icon, color),
        const SizedBox(height: KpbSpacing.sm),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < bullets.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i > 0 ? KpbSpacing.sm : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Icon(Icons.circle, size: 6, color: color),
                      ),
                      Expanded(
                        child: Text(bullets[i], style: KpbTextStyles.body),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _improvementsSection(List<_ReviewImprovement> improvements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('doc_review_improvements'.tr,
            Icons.tips_and_updates_rounded, KpbColors.actionPrimary),
        const SizedBox(height: KpbSpacing.sm),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < improvements.length; i++) ...[
                if (i > 0) const KpbDivider(),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: i == 0 ? 0 : KpbSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (improvements[i].point.isNotEmpty)
                        Text(
                          improvements[i].point,
                          style: KpbTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      if (improvements[i].suggestion.isNotEmpty) ...[
                        if (improvements[i].point.isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          improvements[i].suggestion,
                          style: KpbTextStyles.bodySm,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: KpbSpacing.sm),
        Text(title, style: KpbTextStyles.titleMd),
      ],
    );
  }
}
