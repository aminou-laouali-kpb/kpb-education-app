part of 'app_models.dart';

enum CaseType {
  consultation,
  applicationSupport,
  scholarshipSupport,
  housingSupport,
  mentorship,
}

enum CaseStatus {
  draft,
  submitted,
  underReview,
  documentsNeeded,
  counselorAssigned,
  awaitingStudent,
  scheduled,
  inProgress,
  applicationSubmitted,
  waitingDecision,
  awaitingPayment,
  completed,
  rejected,
  cancelled,
}

enum ContactMethod { inApp, whatsapp, phone }

class CaseTimelineEvent {
  const CaseTimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final DateTime createdAt;
  final CaseStatus status;
}

class CaseMessage {
  const CaseMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderName;
  final String senderRole;
  final LocalizedText body;
  final DateTime createdAt;
}

class DocumentRequest {
  const DocumentRequest({
    required this.id,
    required this.title,
    required this.isProvided,
  });

  final String id;
  final LocalizedText title;
  final bool isProvided;

  DocumentRequest copyWith({
    bool? isProvided,
  }) {
    return DocumentRequest(
      id: id,
      title: title,
      isProvided: isProvided ?? this.isProvided,
    );
  }
}

class StudentCase {
  const StudentCase({
    required this.id,
    required this.referenceCode,
    required this.type,
    required this.title,
    required this.description,
    required this.contextLabel,
    required this.status,
    required this.preferredContactMethod,
    required this.createdAt,
    required this.updatedAt,
    required this.nextStepTitle,
    required this.nextStepDescription,
    required this.timeline,
    required this.messages,
    required this.documentRequests,
    this.assignedAdvisorName,
    this.counsellorId,
    this.scheduledAt,
    this.parentCanView = false,
    this.scholarshipId,
  });

  final String id;
  final String referenceCode;
  final CaseType type;
  final LocalizedText title;
  final LocalizedText description;
  final LocalizedText contextLabel;
  final CaseStatus status;
  final ContactMethod preferredContactMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalizedText nextStepTitle;
  final LocalizedText nextStepDescription;
  final List<CaseTimelineEvent> timeline;
  final List<CaseMessage> messages;
  final List<DocumentRequest> documentRequests;
  // Advisor contact numbers are deliberately NOT modeled: every WhatsApp/phone
  // hand-off goes through the official KPB line (AppConfig.whatsappNumber) —
  // personal counsellor numbers must never reach the client (anti-fraud).
  final String? assignedAdvisorName;

  /// Marketplace counsellor id (Track B), when one is assigned. Null for cases
  /// handled by a free-text advisor. Used to attribute an admission-milestone
  /// review to the right counsellor (KPB-75).
  final String? counsellorId;

  final DateTime? scheduledAt;

  /// Whether the student has opted into sharing this case with a linked parent.
  /// Drives the parent-visibility toggle and what the parent dashboard shows.
  /// Defaults to false — students opt in explicitly, per case.
  final bool parentCanView;

  /// La bourse à laquelle le dossier est lié (« Être accompagné » depuis le
  /// test « Mes 10 bourses »), ou `null`. Sert à retrouver un dossier déjà
  /// ouvert pour la même bourse au lieu d'en créer un second.
  final String? scholarshipId;

  /// Le dossier est-il encore ouvert (ni terminé, ni refusé, ni annulé) ?
  bool get isOpen =>
      status != CaseStatus.completed &&
      status != CaseStatus.rejected &&
      status != CaseStatus.cancelled;

  /// True while the case still carries a client-generated temporary id
  /// (`case-<millis>`). On a successful remote create the backend swaps in the
  /// canonical id + referenceCode, so a non-temp id means the reference is the
  /// authoritative one. Used to mark the reference as provisional in the UI and
  /// to avoid quoting a not-yet-registered reference to a WhatsApp advisor.
  bool get isReferenceProvisional => id.startsWith('case-');

  StudentCase copyWith({
    CaseStatus? status,
    DateTime? updatedAt,
    LocalizedText? nextStepTitle,
    LocalizedText? nextStepDescription,
    List<CaseTimelineEvent>? timeline,
    List<CaseMessage>? messages,
    List<DocumentRequest>? documentRequests,
    String? assignedAdvisorName,
    String? counsellorId,
    DateTime? scheduledAt,
    bool? parentCanView,
  }) {
    return StudentCase(
      id: id,
      referenceCode: referenceCode,
      type: type,
      title: title,
      description: description,
      contextLabel: contextLabel,
      status: status ?? this.status,
      preferredContactMethod: preferredContactMethod,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextStepTitle: nextStepTitle ?? this.nextStepTitle,
      nextStepDescription: nextStepDescription ?? this.nextStepDescription,
      timeline: timeline ?? this.timeline,
      messages: messages ?? this.messages,
      documentRequests: documentRequests ?? this.documentRequests,
      assignedAdvisorName: assignedAdvisorName ?? this.assignedAdvisorName,
      counsellorId: counsellorId ?? this.counsellorId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      parentCanView: parentCanView ?? this.parentCanView,
      scholarshipId: scholarshipId,
    );
  }
}
