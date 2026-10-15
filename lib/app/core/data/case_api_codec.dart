import 'package:collection/collection.dart';

import '../models/app_models.dart';

/// Maps student-case REST payloads to domain models and wire-format strings.
///
/// Keeps API string conventions in one place (Phase 2 boundary).
abstract final class CaseApiCodec {
  static LocalizedText plainLocalized(String value) =>
      LocalizedText(fr: value, en: value);

  static String encodeCaseType(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return 'consultation';
      case CaseType.applicationSupport:
        return 'application_support';
      case CaseType.scholarshipSupport:
        return 'scholarship_support';
      case CaseType.housingSupport:
        return 'housing_support';
      case CaseType.mentorship:
        return 'mentorship';
    }
  }

  static String encodeCaseStatus(CaseStatus status) {
    switch (status) {
      case CaseStatus.draft:
        return 'draft';
      case CaseStatus.submitted:
        return 'submitted';
      case CaseStatus.underReview:
        return 'under_review';
      case CaseStatus.documentsNeeded:
        return 'documents_needed';
      case CaseStatus.counselorAssigned:
        return 'counselor_assigned';
      case CaseStatus.awaitingStudent:
        return 'awaiting_student';
      case CaseStatus.scheduled:
        return 'scheduled';
      case CaseStatus.inProgress:
        return 'in_progress';
      case CaseStatus.applicationSubmitted:
        return 'application_submitted';
      case CaseStatus.waitingDecision:
        return 'waiting_decision';
      case CaseStatus.awaitingPayment:
        return 'awaiting_payment';
      case CaseStatus.completed:
        return 'completed';
      case CaseStatus.rejected:
        return 'rejected';
      case CaseStatus.cancelled:
        return 'cancelled';
    }
  }

  static String encodeContactMethod(ContactMethod method) {
    switch (method) {
      case ContactMethod.inApp:
        return 'in_app';
      case ContactMethod.whatsapp:
        return 'whatsapp';
      case ContactMethod.phone:
        return 'phone';
    }
  }

  static CaseType? decodeCaseType(String? value) {
    return CaseType.values
        .firstWhereOrNull((item) => encodeCaseType(item) == value);
  }

  static CaseStatus? decodeCaseStatus(String? value) {
    return CaseStatus.values
        .firstWhereOrNull((item) => encodeCaseStatus(item) == value);
  }

  static ContactMethod? decodeContactMethod(String? value) {
    return ContactMethod.values
        .firstWhereOrNull((item) => encodeContactMethod(item) == value);
  }

  static StudentCase studentCaseFromApi(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return StudentCase(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      type: decodeCaseType(json['type'] as String?) ?? CaseType.consultation,
      title: plainLocalized(json['title'] as String? ?? ''),
      description: plainLocalized(json['description'] as String? ?? ''),
      contextLabel: plainLocalized(json['contextLabel'] as String? ?? ''),
      status:
          decodeCaseStatus(json['status'] as String?) ?? CaseStatus.submitted,
      preferredContactMethod: decodeContactMethod(
            json['preferredContactMethod'] as String?,
          ) ??
          ContactMethod.inApp,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      nextStepTitle: plainLocalized(json['nextStepTitle'] as String? ?? ''),
      nextStepDescription:
          plainLocalized(json['nextStepDescription'] as String? ?? ''),
      timeline: ((json['timeline'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (event) => CaseTimelineEvent(
              id: event['id'] as String? ?? '',
              title: plainLocalized(event['title'] as String? ?? ''),
              description:
                  plainLocalized(event['description'] as String? ?? ''),
              createdAt:
                  DateTime.tryParse(event['createdAt'] as String? ?? '') ??
                      DateTime.now(),
              status: decodeCaseStatus(event['status'] as String?) ??
                  CaseStatus.submitted,
            ),
          )
          .toList(),
      messages: ((json['messages'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (message) => CaseMessage(
              id: message['id'] as String? ?? '',
              senderName: message['senderName'] as String? ?? 'KPB',
              senderRole: message['senderRole'] as String? ?? 'system',
              body: plainLocalized(message['body'] as String? ?? ''),
              createdAt:
                  DateTime.tryParse(message['createdAt'] as String? ?? '') ??
                      DateTime.now(),
            ),
          )
          .toList(),
      documentRequests:
          ((json['documentRequests'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(
                (document) => DocumentRequest(
                  id: document['id'] as String? ?? '',
                  title: plainLocalized(document['title'] as String? ?? ''),
                  isProvided: document['isProvided'] as bool? ?? false,
                ),
              )
              .toList(),
      assignedAdvisorName: json['assignedAdvisorName'] as String?,
      counsellorId: json['counsellorId'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
      parentCanView: json['parentCanView'] as bool? ?? false,
      scholarshipId: _optionalId(json['scholarshipId']),
    );
  }

  /// `scholarshipId` : chaîne non vide, sinon `null` (backend plus ancien,
  /// dossier non lié, fiche supprimée).
  static String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
