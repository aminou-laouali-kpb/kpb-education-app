part of 'app_models.dart';

class FieldModel {
  const FieldModel({
    required this.id,
    required this.name,
    required this.description,
    required this.subjects,
    required this.careers,
    required this.dailyLife,
    required this.skills,
    required this.personalityTraits,
    required this.relatedCountryIds,
    required this.relatedScholarshipIds,
    required this.accentColor,
    this.iaResilience = '',
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final List<LocalizedText> subjects;
  final List<LocalizedText> careers;
  final List<LocalizedText> dailyLife;
  final List<LocalizedText> skills;
  final List<LocalizedText> personalityTraits;
  final List<String> relatedCountryIds;
  final List<String> relatedScholarshipIds;
  final Color accentColor;

  /// AI-resilience of the field's careers: 'high' | 'medium' | 'low' (or '').
  /// Drives the "métier d'avenir" framing. Sourced from the orientation
  /// field metadata.
  final String iaResilience;

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return KpbColors.csBlue;
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xff')));
      } catch (e) {
        return KpbColors.csBlue;
      }
    }

    return FieldModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      description: parseLoc('description'),
      subjects: parseLocList('subjects'),
      careers: parseLocList('careers'),
      dailyLife: parseLocList('dailyLife'),
      skills: parseLocList('skills'),
      personalityTraits: parseLocList('personalityTraits'),
      relatedCountryIds:
          (json['relatedCountryIds'] as List<dynamic>?)?.cast<String>() ?? [],
      relatedScholarshipIds:
          (json['relatedScholarshipIds'] as List<dynamic>?)?.cast<String>() ??
              [],
      accentColor: parseColor(json['accentColorHex'] as String?),
      iaResilience: json['iaResilience'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'description': description.toJson(),
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'careers': careers.map((e) => e.toJson()).toList(),
        'dailyLife': dailyLife.map((e) => e.toJson()).toList(),
        'skills': skills.map((e) => e.toJson()).toList(),
        'personalityTraits': personalityTraits.map((e) => e.toJson()).toList(),
        'relatedCountryIds': relatedCountryIds,
        'relatedScholarshipIds': relatedScholarshipIds,
        'accentColorHex':
            '#${accentColor.toARGB32().toRadixString(16).substring(2)}',
        'iaResilience': iaResilience,
      };
}

class CountryModel {
  const CountryModel({
    required this.id,
    required this.name,
    required this.whyStudy,
    required this.tuitionRange,
    required this.livingCostRange,
    required this.visaOverview,
    required this.admissionDifficulty,
    required this.popularFieldIds,
    this.code = '',
    this.flagEmoji = '',
    this.tagline = const LocalizedText(fr: '', en: ''),
    this.nextIntakeLabel = const LocalizedText(fr: '', en: ''),
    this.mainLanguage = const LocalizedText(fr: '', en: ''),
    this.marketingDescription = const LocalizedText(fr: '', en: ''),
    this.whyStudyBulletsFr = const [],
    this.whyStudyBulletsEn = const [],
    this.howItWorks = const LocalizedText(fr: '', en: ''),
    this.costsOverview = const LocalizedText(fr: '', en: ''),
    this.languageSection = const LocalizedText(fr: '', en: ''),
    this.partnerSchools = const LocalizedText(fr: '', en: ''),
    this.scholarshipsSection = const LocalizedText(fr: '', en: ''),
    this.whatsAppPrefill = const LocalizedText(fr: '', en: ''),
    this.mvpNote = const LocalizedText(fr: '', en: ''),
    this.displayOrder = 0,
    this.isActive = true,
    this.eligibilityQuiz,
    this.lastVerifiedAt,
    this.sourceUrl,
  });

  final String id;
  final String code;
  final String flagEmoji;
  final LocalizedText name;
  final LocalizedText tagline;
  final LocalizedText nextIntakeLabel;
  final LocalizedText mainLanguage;
  final LocalizedText whyStudy;
  final LocalizedText marketingDescription;
  final List<String> whyStudyBulletsFr;
  final List<String> whyStudyBulletsEn;
  final LocalizedText howItWorks;
  final LocalizedText costsOverview;
  final LocalizedText languageSection;
  final LocalizedText partnerSchools;
  final LocalizedText scholarshipsSection;
  final LocalizedText whatsAppPrefill;
  final LocalizedText mvpNote;
  final LocalizedText tuitionRange;
  final LocalizedText livingCostRange;
  final LocalizedText visaOverview;
  final LocalizedText admissionDifficulty;
  final List<String> popularFieldIds;
  final int displayOrder;
  final bool isActive;
  final CountryEligibilityQuizModel? eligibilityQuiz;
  final DateTime? lastVerifiedAt;
  final String? sourceUrl;

  List<String> whyStudyBulletsFor(String localeCode) =>
      localeCode.startsWith('en') && whyStudyBulletsEn.isNotEmpty
          ? whyStudyBulletsEn
          : whyStudyBulletsFr;

  List<String> howItWorksStepsFor(String localeCode) {
    final raw = howItWorks.resolve(localeCode);
    if (raw.isEmpty) return const [];
    return raw
        .split('·')
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  CountryModel copyWith({CountryEligibilityQuizModel? eligibilityQuiz}) {
    return CountryModel(
      id: id,
      code: code,
      flagEmoji: flagEmoji,
      name: name,
      tagline: tagline,
      nextIntakeLabel: nextIntakeLabel,
      mainLanguage: mainLanguage,
      whyStudy: whyStudy,
      marketingDescription: marketingDescription,
      whyStudyBulletsFr: whyStudyBulletsFr,
      whyStudyBulletsEn: whyStudyBulletsEn,
      howItWorks: howItWorks,
      costsOverview: costsOverview,
      languageSection: languageSection,
      partnerSchools: partnerSchools,
      scholarshipsSection: scholarshipsSection,
      whatsAppPrefill: whatsAppPrefill,
      mvpNote: mvpNote,
      tuitionRange: tuitionRange,
      livingCostRange: livingCostRange,
      visaOverview: visaOverview,
      admissionDifficulty: admissionDifficulty,
      popularFieldIds: popularFieldIds,
      displayOrder: displayOrder,
      isActive: isActive,
      eligibilityQuiz: eligibilityQuiz ?? this.eligibilityQuiz,
      lastVerifiedAt: lastVerifiedAt,
      sourceUrl: sourceUrl,
    );
  }

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<String> parseBulletList(String key) {
      final nested = json[key];
      if (nested is Map) {
        final fr = nested['fr'];
        if (fr is List) return fr.cast<String>();
      }
      final direct = json['${key}Fr'];
      if (direct is List) return direct.cast<String>();
      return const [];
    }

    List<String> parseBulletListEn(String key) {
      final nested = json[key];
      if (nested is Map) {
        final en = nested['en'];
        if (en is List) return en.cast<String>();
      }
      final direct = json['${key}En'];
      if (direct is List) return direct.cast<String>();
      return const [];
    }

    CountryEligibilityQuizModel? quiz;
    final rawQuiz = json['eligibilityQuiz'];
    if (rawQuiz is Map<String, dynamic>) {
      quiz = CountryEligibilityQuizModel.fromJson(rawQuiz);
    }

    return CountryModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      flagEmoji: json['flagEmoji'] as String? ?? '',
      name: parseLoc('name'),
      tagline: parseLoc('tagline'),
      nextIntakeLabel: parseLoc('nextIntakeLabel'),
      mainLanguage: parseLoc('mainLanguage'),
      whyStudy: parseLoc('whyStudy'),
      marketingDescription: parseLoc('marketingDescription'),
      whyStudyBulletsFr: parseBulletList('whyStudyBullets'),
      whyStudyBulletsEn: parseBulletListEn('whyStudyBullets'),
      howItWorks: parseLoc('howItWorks'),
      costsOverview: parseLoc('costsOverview'),
      languageSection: parseLoc('languageSection'),
      partnerSchools: parseLoc('partnerSchools'),
      scholarshipsSection: parseLoc('scholarshipsSection'),
      whatsAppPrefill: parseLoc('whatsAppPrefill'),
      mvpNote: parseLoc('mvpNote'),
      tuitionRange: parseLoc('tuitionRange'),
      livingCostRange: parseLoc('livingCostRange'),
      visaOverview: parseLoc('visaOverview'),
      admissionDifficulty: parseLoc('admissionDifficulty'),
      popularFieldIds:
          (json['popularFieldIds'] as List<dynamic>?)?.cast<String>() ?? [],
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      eligibilityQuiz: quiz,
      lastVerifiedAt:
          DateTime.tryParse(json['lastVerifiedAt'] as String? ?? ''),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'flagEmoji': flagEmoji,
        'name': name.toJson(),
        'tagline': tagline.toJson(),
        'nextIntakeLabel': nextIntakeLabel.toJson(),
        'mainLanguage': mainLanguage.toJson(),
        'whyStudy': whyStudy.toJson(),
        'marketingDescription': marketingDescription.toJson(),
        'whyStudyBullets': {
          'fr': whyStudyBulletsFr,
          'en': whyStudyBulletsEn,
        },
        'howItWorks': howItWorks.toJson(),
        'costsOverview': costsOverview.toJson(),
        'languageSection': languageSection.toJson(),
        'partnerSchools': partnerSchools.toJson(),
        'scholarshipsSection': scholarshipsSection.toJson(),
        'whatsAppPrefill': whatsAppPrefill.toJson(),
        'mvpNote': mvpNote.toJson(),
        'tuitionRange': tuitionRange.toJson(),
        'livingCostRange': livingCostRange.toJson(),
        'visaOverview': visaOverview.toJson(),
        'admissionDifficulty': admissionDifficulty.toJson(),
        'popularFieldIds': popularFieldIds,
        'displayOrder': displayOrder,
        'isActive': isActive,
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'sourceUrl': sourceUrl,
        if (eligibilityQuiz != null)
          'eligibilityQuiz': {
            'questions': eligibilityQuiz!.questions
                .map(
                  (q) => {
                    'id': q.id,
                    'textFr': q.textFr,
                    'textEn': q.textEn,
                    'options': q.options
                        .map(
                          (o) => {
                            'value': o.value,
                            'labelFr': o.labelFr,
                            'labelEn': o.labelEn,
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
            'verdicts': eligibilityQuiz!.verdicts.map(
              (key, value) => MapEntry(
                key,
                {
                  'titleFr': value.titleFr,
                  'titleEn': value.titleEn,
                  'messageFr': value.messageFr,
                  'messageEn': value.messageEn,
                  'ctaFr': value.ctaFr,
                  'ctaEn': value.ctaEn,
                  'alternativeCountryIds': value.alternativeCountryIds,
                },
              ),
            ),
          },
      };
}

class InstitutionModel {
  const InstitutionModel({
    required this.id,
    required this.name,
    required this.countryId,
    required this.location,
    required this.overview,
    required this.studyLevels,
    required this.tuitionLabel,
    required this.languageRequirements,
    required this.intakePeriods,
    required this.programIds,
    this.isPartner = false,
    this.logoUrl,
    this.logoSourceUrl,
    this.logoLicence,
    this.lastVerifiedAt,
    this.sourceUrl,
  });

  final String id;
  final LocalizedText name;
  final String countryId;
  final LocalizedText location;
  final LocalizedText overview;
  final List<String> studyLevels;
  final LocalizedText tuitionLabel;
  final LocalizedText languageRequirements;
  final List<String> intakePeriods;
  final List<String> programIds;
  final bool isPartner;
  final String? logoUrl;
  final String? logoSourceUrl;
  final String? logoLicence;
  final DateTime? lastVerifiedAt;
  final String? sourceUrl;

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return InstitutionModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      countryId: json['countryId'] as String? ?? '',
      location: parseLoc('location'),
      overview: parseLoc('overview'),
      studyLevels:
          (json['studyLevels'] as List<dynamic>?)?.cast<String>() ?? [],
      tuitionLabel: parseLoc('tuitionLabel'),
      languageRequirements: parseLoc('languageRequirements'),
      intakePeriods:
          (json['intakePeriods'] as List<dynamic>?)?.cast<String>() ?? [],
      programIds: (json['programIds'] as List<dynamic>?)?.cast<String>() ?? [],
      isPartner: json['isPartner'] as bool? ?? false,
      logoUrl: json['logoUrl'] as String?,
      logoSourceUrl: json['logoSourceUrl'] as String?,
      logoLicence: json['logoLicence'] as String?,
      lastVerifiedAt:
          DateTime.tryParse(json['lastVerifiedAt'] as String? ?? ''),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'countryId': countryId,
        'location': location.toJson(),
        'overview': overview.toJson(),
        'studyLevels': studyLevels,
        'tuitionLabel': tuitionLabel.toJson(),
        'languageRequirements': languageRequirements.toJson(),
        'intakePeriods': intakePeriods,
        'programIds': programIds,
        'isPartner': isPartner,
        'logoUrl': logoUrl,
        'logoSourceUrl': logoSourceUrl,
        'logoLicence': logoLicence,
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'sourceUrl': sourceUrl,
      };
}

/// One campus on which a (multi-campus) formation is delivered, with its own
/// price and intake. Used by OMNES formations, where the same programme runs on
/// several campuses at different prices. Empty for single-campus programs.
class CampusOffering {
  const CampusOffering({
    required this.campus,
    this.tuitionUpfront,
    this.tuitionInstallments,
    this.intake,
  });

  final String campus;
  final num? tuitionUpfront;
  final num? tuitionInstallments;
  final String? intake;

  /// Localized headline tuition for this campus, e.g. "12 690 €/an".
  String tuitionLabel(String localeCode) {
    final value = tuitionUpfront;
    if (value == null) {
      return localeCode.startsWith('en') ? 'On request' : 'Sur demande';
    }
    final amount = _formatEuro(value);
    return localeCode.startsWith('en') ? '$amount/year' : '$amount/an';
  }

  static String _formatEuro(num value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer €';
  }

  factory CampusOffering.fromJson(Map<String, dynamic> json) => CampusOffering(
        campus: json['campus'] as String? ?? '',
        tuitionUpfront: json['tuitionUpfront'] as num?,
        tuitionInstallments: json['tuitionInstallments'] as num?,
        intake: json['intake'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'campus': campus,
        'tuitionUpfront': tuitionUpfront,
        'tuitionInstallments': tuitionInstallments,
        'intake': intake,
      };
}

class ProgramModel {
  const ProgramModel({
    required this.id,
    required this.institutionId,
    required this.countryId,
    required this.fieldId,
    required this.name,
    required this.level,
    required this.duration,
    required this.tuition,
    required this.language,
    required this.requirements,
    this.campusOfferings = const [],
    this.lastVerifiedAt,
    this.sourceUrl,
  });

  final String id;
  final String institutionId;
  final String countryId;
  final String fieldId;
  final LocalizedText name;
  final LocalizedText level;
  final LocalizedText duration;
  final LocalizedText tuition;
  final LocalizedText language;
  final List<LocalizedText> requirements;

  /// Campuses on which this formation is available (multi-campus schools like
  /// OMNES). Empty for single-campus programs.
  final List<CampusOffering> campusOfferings;
  final DateTime? lastVerifiedAt;
  final String? sourceUrl;

  /// True when the formation is offered on more than one campus.
  bool get isMultiCampus => campusOfferings.length > 1;

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    List<CampusOffering> parseOfferings() {
      final raw = json['campusOfferings'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => CampusOffering.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();
      }
      return const [];
    }

    return ProgramModel(
      id: json['id'] as String? ?? '',
      institutionId: json['institutionId'] as String? ?? '',
      countryId: json['countryId'] as String? ?? '',
      fieldId: json['fieldId'] as String? ?? '',
      name: parseLoc('name'),
      level: parseLoc('level'),
      duration: parseLoc('duration'),
      tuition: parseLoc('tuition'),
      language: parseLoc('language'),
      requirements: parseLocList('requirements'),
      campusOfferings: parseOfferings(),
      lastVerifiedAt:
          DateTime.tryParse(json['lastVerifiedAt'] as String? ?? ''),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'institutionId': institutionId,
        'countryId': countryId,
        'fieldId': fieldId,
        'name': name.toJson(),
        'level': level.toJson(),
        'duration': duration.toJson(),
        'tuition': tuition.toJson(),
        'language': language.toJson(),
        'requirements': requirements.map((e) => e.toJson()).toList(),
        if (campusOfferings.isNotEmpty)
          'campusOfferings': campusOfferings.map((e) => e.toJson()).toList(),
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'sourceUrl': sourceUrl,
      };
}

/// Application-window status for a scholarship (Ouvert / Bientôt clôturé /
/// Clôturé), derived from [ScholarshipModel.deadlineAt].
enum ScholarshipWindowStatus { open, closingSoon, closed }

class ScholarshipModel {
  const ScholarshipModel({
    required this.id,
    required this.name,
    required this.countryId,
    required this.levelEligible,
    required this.typeOfFunding,
    required this.deadlineLabel,
    required this.keyRequirements,
    required this.relatedFieldIds,
    required this.baseMatch,
    this.academyCourseId,
    this.eligibility = const [],
    this.deadlineAt,
    this.deadlineIsEstimated = false,
  });

  final String id;
  final LocalizedText name;
  final String countryId;
  final LocalizedText levelEligible;
  final LocalizedText typeOfFunding;
  final LocalizedText deadlineLabel;
  final List<LocalizedText> keyRequirements;
  final List<String> relatedFieldIds;
  final int baseMatch;
  final String? academyCourseId;

  /// Who can apply (distinct from [keyRequirements], which are application
  /// steps). Drives the scholarship eligibility self-check. May be empty for
  /// scraped/live entries.
  final List<LocalizedText> eligibility;

  /// Application close date. Null = no fixed deadline (treated as open / rolling).
  final DateTime? deadlineAt;

  /// Vrai quand [deadlineAt] est une PROJECTION (cycle `estimated`), pas une
  /// date confirmée. 20 des 31 fiches publiées sont dans ce cas : leur
  /// `deadlineAt` vient de `estimatedCloseAt` à l'import. Un compte à rebours
  /// au jour près sur une date estimée serait un mensonge — l'onglet Bourses
  /// se tait déjà dans ce cas, et le calendrier d'échéances doit en faire
  /// autant. Faux par défaut : une fiche sans cycle est traitée comme
  /// confirmée pour ne pas dégrader l'historique.
  final bool deadlineIsEstimated;

  /// Jours CALENDAIRES restants jusqu'à la clôture confirmée (0 = le jour
  /// même), ou null si la date est inconnue, ESTIMÉE ou passée. Seule source
  /// des comptes à rebours : l'accueil lisait le libellé texte (« Mai 2026 »,
  /// « Clôturé — … ») et la carte « Deadline urgente » ne s'affichait jamais ;
  /// `inDays` tronqué décalait aussi le compte d'un jour.
  int? daysUntilDeadline({DateTime? now}) {
    if (deadlineIsEstimated) return null;
    final close = deadlineAt;
    if (close == null) return null;
    final ref = now ?? DateTime.now();
    if (!ref.isBefore(close)) return null;
    final c = close.toLocal();
    final r = ref.toLocal();
    // Dates UTC construites sur les composantes locales : aucun décalage
    // d'heure d'été ne fausse la différence en jours.
    return DateTime.utc(c.year, c.month, c.day)
        .difference(DateTime.utc(r.year, r.month, r.day))
        .inDays;
  }

  /// Ouvert / Bientôt clôturé / Clôturé, derived from [deadlineAt]. [now] is
  /// injectable for testing; [soonDays] is the "closing soon" window.
  ScholarshipWindowStatus windowStatus({DateTime? now, int soonDays = 21}) {
    // Une date ESTIMÉE ne peut produire ni « Bientôt clôturé » ni « Clôturé ».
    // Les deux sont des affirmations au jour près sur une projection : le
    // badge annonçait la clôture d'une campagne dont personne n'a publié la
    // date, et « Clôturé » aurait fait renoncer un étudiant à une bourse encore
    // ouverte. Le champ existait déjà et disait la vérité ; c'est ce calcul qui
    // ne le consultait pas.
    if (deadlineIsEstimated) return ScholarshipWindowStatus.open;
    final close = deadlineAt;
    if (close == null) return ScholarshipWindowStatus.open;
    final ref = now ?? DateTime.now();
    if (!ref.isBefore(close)) return ScholarshipWindowStatus.closed;
    if (close.difference(ref).inDays <= soonDays) {
      return ScholarshipWindowStatus.closingSoon;
    }
    return ScholarshipWindowStatus.open;
  }

  factory ScholarshipModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    return ScholarshipModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      countryId: json['countryId'] as String? ?? '',
      levelEligible: parseLoc('levelEligible'),
      typeOfFunding: parseLoc('typeOfFunding'),
      deadlineLabel: parseLoc('deadlineLabel'),
      keyRequirements: parseLocList('keyRequirements'),
      relatedFieldIds:
          (json['relatedFieldIds'] as List<dynamic>?)?.cast<String>() ?? [],
      baseMatch: json['baseMatch'] as int? ?? 0,
      academyCourseId: json['academyCourseId'] as String?,
      eligibility: parseLocList('eligibility'),
      deadlineAt: DateTime.tryParse(json['deadlineAt'] as String? ?? ''),
      deadlineIsEstimated: (json['dateConfidence'] as String?) == 'estimated',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'countryId': countryId,
        'levelEligible': levelEligible.toJson(),
        'typeOfFunding': typeOfFunding.toJson(),
        'deadlineLabel': deadlineLabel.toJson(),
        'keyRequirements': keyRequirements.map((e) => e.toJson()).toList(),
        'relatedFieldIds': relatedFieldIds,
        'baseMatch': baseMatch,
        'academyCourseId': academyCourseId,
        'eligibility': eligibility.map((e) => e.toJson()).toList(),
        'deadlineAt': deadlineAt?.toIso8601String(),
        // Symétrique de `fromJson`, qui lit cette clé. Elle manquait, donc
        // toute copie persistée (cache hors-ligne, instantané local) revenait
        // avec `deadlineIsEstimated = false` : une date estimée redevenait
        // « confirmée » au simple aller-retour par le disque, et le compte à
        // rebours réapparaissait sur une projection.
        'dateConfidence': deadlineIsEstimated ? 'estimated' : 'confirmed',
      };
}

/// Ordered, admin-authored "how to apply" step for a live scholarship (e.g.
/// Chevening: online form then interview; MEXT: written exam). Distinct from
/// the generic deadline countdown in [RoadmapEngine] — these are curated per
/// scholarship, never scraped.
class ScholarshipApplicationStepModel {
  const ScholarshipApplicationStepModel({
    required this.id,
    required this.stepNumber,
    required this.title,
    required this.description,
    this.estimatedDurationDays,
  });

  final String id;
  final int stepNumber;
  final String title;
  final String description;
  final int? estimatedDurationDays;

  factory ScholarshipApplicationStepModel.fromJson(Map<String, dynamic> json) {
    return ScholarshipApplicationStepModel(
      id: json['id'] as String? ?? '',
      stepNumber: json['stepNumber'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      estimatedDurationDays: json['estimatedDurationDays'] as int?,
    );
  }
}

/// Scraped scholarship from the live index (GreatYop + Mastere.tn).
/// This is a separate model from [ScholarshipModel] which is the curated,
/// seed-based catalog. Live scholarships come from the /scholarships endpoint.
class LiveScholarshipModel {
  const LiveScholarshipModel({
    required this.id,
    required this.title,
    required this.countryName,
    required this.fundingType,
    this.applicationRequirement = 'separate_application',
    required this.description,
    required this.advantages,
    required this.eligibility,
    this.keyRequirements = const [],
    required this.level,
    required this.deadlineLabel,
    this.deadlineAt,
    required this.applicationUrl,
    this.sourceUrl,
    required this.tags,
    required this.matchScore,
    this.currentCycle,
    this.applicationSteps = const [],
    this.videos = const [],
    this.isAlertEnabled,
  });

  final String id;
  final String title;
  final String countryName;
  final String fundingType; // 'fully_funded' | 'partially_funded' | 'unknown'
  final String applicationRequirement; // 'automatic' | 'separate_application'
  final String description;
  final List<String> advantages;
  final List<String> eligibility;
  final List<String> keyRequirements;
  final String level;
  final String deadlineLabel;
  final DateTime? deadlineAt;
  final String applicationUrl;
  final String? sourceUrl;
  final List<String> tags;
  final int matchScore;
  final ScholarshipCycleModel? currentCycle;
  final List<ScholarshipApplicationStepModel> applicationSteps;
  final List<ScholarshipVideoModel> videos;
  final bool? isAlertEnabled;

  bool get isFullyFunded => fundingType == 'fully_funded';
  bool get isPartiallyFunded => fundingType == 'partially_funded';
  bool get isAutomaticAdmission => applicationRequirement == 'automatic';

  factory LiveScholarshipModel.fromJson(Map<String, dynamic> json) {
    final rawAlert = json['alert'];
    final isAlertEnabled = json['isAlertEnabled'] is bool
        ? json['isAlertEnabled'] as bool
        : rawAlert is Map && rawAlert['subscribed'] is bool
            ? rawAlert['subscribed'] as bool
            : null;

    return LiveScholarshipModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      countryName: json['countryName'] as String? ?? '',
      fundingType: json['fundingType'] as String? ?? 'unknown',
      applicationRequirement:
          json['applicationRequirement'] as String? ?? 'separate_application',
      description: json['description'] as String? ?? '',
      advantages: (json['advantages'] as List<dynamic>?)?.cast<String>() ?? [],
      eligibility:
          (json['eligibility'] as List<dynamic>?)?.cast<String>() ?? [],
      keyRequirements:
          (json['keyRequirements'] as List<dynamic>?)?.cast<String>() ?? [],
      level: json['level'] as String? ?? '',
      deadlineLabel: json['deadlineLabel'] as String? ?? '',
      deadlineAt: json['deadlineAt'] != null
          ? DateTime.tryParse(json['deadlineAt'] as String)
          : null,
      applicationUrl: json['applicationUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      matchScore: json['matchScore'] as int? ?? 0,
      currentCycle: json['currentCycle'] is Map<String, dynamic>
          ? ScholarshipCycleModel.fromJson(
              json['currentCycle'] as Map<String, dynamic>)
          : null,
      applicationSteps: (json['applicationSteps'] as List<dynamic>?)
              ?.map((e) => ScholarshipApplicationStepModel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      videos: (() {
        final videos = (json['videos'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => ScholarshipVideoModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .where((video) => video.youtubeVideoId.isNotEmpty)
                .toList() ??
            <ScholarshipVideoModel>[];
        // List responses expose only one `featuredVideo`; detail responses
        // expose the complete `videos` array. Preserve the list preview as a
        // useful initial detail while the full record is loading.
        if (videos.isEmpty && json['featuredVideo'] is Map) {
          final featured = ScholarshipVideoModel.fromJson(
            Map<String, dynamic>.from(json['featuredVideo'] as Map),
          );
          if (featured.youtubeVideoId.isNotEmpty) videos.add(featured);
        }
        videos.sort((a, b) {
          if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
          return a.displayOrder.compareTo(b.displayOrder);
        });
        return videos;
      })(),
      isAlertEnabled: isAlertEnabled,
    );
  }
}

/// Optional YouTube explanation attached to a live scholarship.
///
/// The parser deliberately accepts both the target scholarship-video contract
/// (`youtubeVideoId`) and older/general YouTube shapes (`videoId`, `youtubeId`,
/// or a URL). That lets the mobile release ship before the backend migration
/// without making video support a hard dependency for scholarship details.
class ScholarshipVideoModel {
  const ScholarshipVideoModel({
    required this.id,
    required this.youtubeVideoId,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.language,
    required this.displayOrder,
    required this.durationSeconds,
    required this.isFeatured,
    required this.watchUrl,
    required this.shareUrl,
  });

  final String id;
  final String youtubeVideoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String language;
  final int displayOrder;
  final int? durationSeconds;
  final bool isFeatured;
  final String watchUrl;
  final String shareUrl;

  String get effectiveThumbnailUrl => thumbnailUrl.trim().isNotEmpty
      ? thumbnailUrl.trim()
      : 'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';

  factory ScholarshipVideoModel.fromJson(Map<String, dynamic> json) {
    String firstString(Iterable<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    final rawId = firstString(const [
      'youtubeVideoId',
      'videoId',
      'youtubeId',
      'youtubeUrl',
      'url',
      'watchUrl',
      'shareUrl',
    ]);

    return ScholarshipVideoModel(
      id: firstString(const ['id']),
      youtubeVideoId: _extractYoutubeVideoId(rawId),
      title: firstString(const ['title', 'titleFr', 'titleEn']),
      description:
          firstString(const ['description', 'descriptionFr', 'descriptionEn']),
      thumbnailUrl: firstString(const ['thumbnailUrl', 'thumbnail']),
      language: firstString(const ['languageCode', 'language', 'lang']).isEmpty
          ? 'fr'
          : firstString(const ['languageCode', 'language', 'lang']),
      displayOrder: json['displayOrder'] is num
          ? (json['displayOrder'] as num).toInt()
          : (json['position'] is num ? (json['position'] as num).toInt() : 0),
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).toInt()
          : null,
      isFeatured: json['isFeatured'] == true,
      watchUrl: firstString(const ['watchUrl']),
      shareUrl: firstString(const ['shareUrl']),
    );
  }

  static String _extractYoutubeVideoId(String value) {
    final raw = value.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(raw)) return raw;
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
      return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(segment) ? segment : '';
    }
    if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      final queryId = uri.queryParameters['v'] ?? '';
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(queryId)) return queryId;
      final segments = uri.pathSegments;
      final markerIndex = segments.indexWhere(
        (segment) =>
            segment == 'embed' || segment == 'shorts' || segment == 'live',
      );
      if (markerIndex >= 0 && markerIndex + 1 < segments.length) {
        final segment = segments[markerIndex + 1];
        return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(segment) ? segment : '';
      }
    }
    return '';
  }
}

/// One annual application window. Estimated dates remain visibly distinct
/// from admin-confirmed opening and closing dates.
class ScholarshipCycleModel {
  const ScholarshipCycleModel({
    required this.id,
    required this.academicYear,
    required this.status,
    required this.dateConfidence,
    this.estimatedOpenAt,
    this.estimatedCloseAt,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final String academicYear;
  final String status;
  final String dateConfidence;
  final DateTime? estimatedOpenAt;
  final DateTime? estimatedCloseAt;
  final DateTime? opensAt;
  final DateTime? closesAt;

  bool get isOpen => status == 'open';
  bool get isEstimated => dateConfidence == 'estimated';

  factory ScholarshipCycleModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    return ScholarshipCycleModel(
      id: json['id'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '',
      status: json['status'] as String? ?? 'forecast',
      dateConfidence: json['dateConfidence'] as String? ?? 'estimated',
      estimatedOpenAt: parse('estimatedOpenAt'),
      estimatedCloseAt: parse('estimatedCloseAt'),
      opensAt: parse('opensAt'),
      closesAt: parse('closesAt'),
    );
  }
}
