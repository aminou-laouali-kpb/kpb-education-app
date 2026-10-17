import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/ui/app_tokens.dart';

// Libellés, icônes et messages de la communauté. Tout texte passe par les
// traductions (clés `comm_*`) : FR et EN à parité, tutoiement.

/// Le libellé d'un type de publication.
String communityPostTypeLabel(CommunityPostType type) => switch (type) {
      CommunityPostType.question => 'comm_type_question'.tr,
      CommunityPostType.experience => 'comm_type_experience'.tr,
      CommunityPostType.advice => 'comm_type_advice'.tr,
    };

/// La phrase d'aide d'un type (compositeur).
String communityPostTypeHint(CommunityPostType type) => switch (type) {
      CommunityPostType.question => 'comm_type_question_hint'.tr,
      CommunityPostType.experience => 'comm_type_experience_hint'.tr,
      CommunityPostType.advice => 'comm_type_advice_hint'.tr,
    };

IconData communityPostTypeIcon(CommunityPostType type) => switch (type) {
      CommunityPostType.question => Icons.help_outline_rounded,
      CommunityPostType.experience => Icons.auto_stories_outlined,
      CommunityPostType.advice => Icons.lightbulb_outline_rounded,
    };

Color communityPostTypeColor(CommunityPostType type) => switch (type) {
      CommunityPostType.question => KpbColors.actionPrimary,
      CommunityPostType.experience => KpbColors.lawPurple,
      CommunityPostType.advice => KpbColors.success,
    };

/// Le libellé d'un badge de rôle.
String communityBadgeLabel(CommunityBadge badge) => switch (badge) {
      CommunityBadge.kpbTeam => 'comm_badge_team'.tr,
      CommunityBadge.kpbAdvisor => 'comm_badge_advisor'.tr,
      CommunityBadge.kpbAssistant => 'comm_badge_assistant'.tr,
      CommunityBadge.verifiedAlumni => 'comm_badge_alumni'.tr,
      CommunityBadge.ambassador => 'comm_badge_ambassador'.tr,
    };

IconData communityBadgeIcon(CommunityBadge badge) => switch (badge) {
      CommunityBadge.kpbTeam => Icons.shield_rounded,
      CommunityBadge.kpbAdvisor => Icons.verified_rounded,
      CommunityBadge.kpbAssistant => Icons.fact_check_rounded,
      CommunityBadge.verifiedAlumni => Icons.school_rounded,
      CommunityBadge.ambassador => Icons.star_rounded,
    };

Color communityBadgeColor(CommunityBadge badge) => switch (badge) {
      CommunityBadge.kpbTeam => KpbColors.brandNavy,
      CommunityBadge.kpbAdvisor => KpbColors.actionPrimary,
      CommunityBadge.kpbAssistant => KpbColors.brandNavy,
      CommunityBadge.verifiedAlumni => KpbColors.success,
      CommunityBadge.ambassador => KpbColors.warning,
    };

/// Le libellé d'une famille d'entités (« Bourse », « Pays »…).
String communityEntityTypeLabel(CommunityEntityType type) => switch (type) {
      CommunityEntityType.scholarship => 'comm_entity_scholarship'.tr,
      CommunityEntityType.country => 'comm_entity_country'.tr,
      CommunityEntityType.institution => 'comm_entity_institution'.tr,
      CommunityEntityType.program => 'comm_entity_program'.tr,
    };

IconData communityEntityIcon(CommunityEntityType type) => switch (type) {
      CommunityEntityType.scholarship => Icons.workspace_premium_outlined,
      CommunityEntityType.country => Icons.public_rounded,
      CommunityEntityType.institution => Icons.account_balance_outlined,
      CommunityEntityType.program => Icons.menu_book_outlined,
    };

/// Le libellé d'un fil.
String communityTabLabel(CommunityFeedTab tab) => switch (tab) {
      CommunityFeedTab.forYou => 'comm_tab_for_you'.tr,
      CommunityFeedTab.recent => 'comm_tab_recent'.tr,
      CommunityFeedTab.unanswered => 'comm_tab_unanswered'.tr,
    };

/// Le libellé d'un motif de signalement.
String communityReportReasonLabel(CommunityReportReason reason) =>
    switch (reason) {
      CommunityReportReason.scam => 'comm_report_reason_scam'.tr,
      CommunityReportReason.harassment => 'comm_report_reason_harassment'.tr,
      CommunityReportReason.inappropriate =>
        'comm_report_reason_inappropriate'.tr,
      CommunityReportReason.spam => 'comm_report_reason_spam'.tr,
      CommunityReportReason.personalInfo =>
        'comm_report_reason_personal_info'.tr,
      CommunityReportReason.misinformation =>
        'comm_report_reason_misinformation'.tr,
      CommunityReportReason.other => 'comm_report_reason_other'.tr,
    };

/// « il y a 5 min », « il y a 3 j »… (mêmes clés que le reste de l'app).
String communityRelativeTime(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final diff = (now ?? DateTime.now()).difference(at.toLocal());
  if (diff.inMinutes < 1) return 'time_ago_just_now'.tr;
  if (diff.inMinutes < 60) {
    return 'time_ago_minutes'.trParams({'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'time_ago_hours'.trParams({'n': '${diff.inHours}'});
  }
  if (diff.inDays < 7) {
    return 'time_ago_days'.trParams({'n': '${diff.inDays}'});
  }
  if (diff.inDays < 30) {
    return 'time_ago_weeks'.trParams({'n': '${diff.inDays ~/ 7}'});
  }
  return 'time_ago_months'.trParams({'n': '${diff.inDays ~/ 30}'});
}

/// « 4 réponses », « 1 réponse », « Aucune réponse ».
String communityReplyCountLabel(int count) => switch (count) {
      0 => 'comm_replies_none'.tr,
      1 => 'comm_replies_one'.tr,
      _ => 'comm_replies_many'.trParams({'n': '$count'}),
    };

/// « 2 utiles », « 1 utile ».
String communityHelpfulCountLabel(int count) => count == 1
    ? 'comm_helpful_one'.tr
    : 'comm_helpful_many'.trParams({'n': '$count'});

/// Le message à montrer pour un échec, sans jamais le texte brut du serveur.
String communityFailureMessage(CommunityException error) {
  switch (error.failure) {
    case CommunityFailure.offline:
      return 'comm_err_offline'.tr;
    case CommunityFailure.timeout:
      return 'comm_err_timeout'.tr;
    case CommunityFailure.rateLimited:
      return _rateLimitedMessage(error);
    case CommunityFailure.readOnly:
      final until = DateTime.tryParse('${error.details['until']}');
      if (error.details['kind'] == 'ban') return 'comm_err_banned'.tr;
      return until == null
          ? 'comm_err_read_only'.tr
          : 'comm_err_read_only_until'
              .trParams({'date': communityShortDate(until)});
    case CommunityFailure.charterRequired:
    case CommunityFailure.charterOutdated:
      return 'comm_err_charter'.tr;
    case CommunityFailure.notFound:
      return 'comm_err_not_found'.tr;
    case CommunityFailure.notAuthor:
      return 'comm_err_not_author'.tr;
    case CommunityFailure.editWindowClosed:
      return 'comm_err_edit_window'.tr;
    case CommunityFailure.postNotOpen:
      return 'comm_err_post_not_open'.tr;
    case CommunityFailure.invalidMention:
      return 'comm_err_invalid_mention'.tr;
    case CommunityFailure.tooManyMentions:
      return 'comm_err_too_many_mentions'.tr;
    case CommunityFailure.tooManyHashtags:
      return 'comm_err_too_many_hashtags'.tr;
    case CommunityFailure.cannotReactOwn:
      return 'comm_err_react_own'.tr;
    case CommunityFailure.cannotBlockSelf:
    case CommunityFailure.cannotReportSelf:
      return 'comm_err_self'.tr;
    case CommunityFailure.cannotBlockTeam:
      return 'comm_err_block_team'.tr;
    case CommunityFailure.validation:
      return 'comm_err_validation'.tr;
    case CommunityFailure.studentsOnly:
      return 'comm_err_students_only'.tr;
    case CommunityFailure.disabled:
      return 'comm_err_disabled'.tr;
    case CommunityFailure.invalidCursor:
    case CommunityFailure.unauthorized:
    case CommunityFailure.server:
    case CommunityFailure.invalid:
      return 'comm_err_generic'.tr;
  }
}

String _rateLimitedMessage(CommunityException error) {
  final scope = error.details['scope'];
  final limit = error.details['limit'];
  final limitText = limit is num ? '${limit.toInt()}' : null;
  final seconds = error.retryAfterSeconds;
  final minutes = seconds == null ? null : (seconds / 60).ceil();
  if (scope == 'posts_per_day' && limitText != null) {
    return 'comm_err_rate_posts'.trParams({'limit': limitText});
  }
  if (scope == 'replies_per_hour' && limitText != null) {
    return minutes != null && minutes > 0
        ? 'comm_err_rate_replies_wait'
            .trParams({'limit': limitText, 'minutes': '$minutes'})
        : 'comm_err_rate_replies'.trParams({'limit': limitText});
  }
  if (scope == 'reports_per_day') return 'comm_err_rate_reports'.tr;
  if (minutes != null && minutes > 0) {
    return 'comm_err_rate_wait'.trParams({'minutes': '$minutes'});
  }
  return 'comm_err_rate_generic'.tr;
}

/// « 17/10/2026 » (date courte, sans dépendre des données de locale).
String communityShortDate(DateTime at) {
  final local = at.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return '$d/$m/${local.year}';
}

/// « octobre 2026 » depuis `AAAA-MM`.
String communityMonthLabel(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return yyyyMm;
  return 'comm_month_$month'.trParams({'year': parts[0]});
}
