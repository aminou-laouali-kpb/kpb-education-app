import '../models/app_models.dart';

class RoadmapEngine {
  static List<RoadmapStepModel> getSteps() {
    return const [
      RoadmapStepModel(
        type: RoadmapStepType.audit,
        title: LocalizedText(
            fr: 'Initialisation \u0026 Audit Dossier',
            en: 'Initialization \u0026 Document Audit'),
        description: LocalizedText(
          fr: 'Rassemblez vos documents d\'identité, diplômes et relevés de notes.',
          en: 'Gather your ID, degrees, and academic transcripts.',
        ),
        daysBeforeDeadline: 60,
      ),
      RoadmapStepModel(
        type: RoadmapStepType.language,
        title: LocalizedText(
            fr: 'Certification de Langue', en: 'Language Certification'),
        description: LocalizedText(
          fr: 'Passez le TOEFL, IELTS ou TCF si nécessaire pour cette destination.',
          en: 'Take TOEFL, IELTS, or TCF if required for this destination.',
        ),
        daysBeforeDeadline: 45,
      ),
      RoadmapStepModel(
        type: RoadmapStepType.writing,
        title:
            LocalizedText(fr: 'Rédaction Stratégique', en: 'Strategic Writing'),
        description: LocalizedText(
          fr: 'Rédigez votre lettre de motivation (Personal Statement) avec nos tutoriels.',
          en: 'Write your Personal Statement using our tutorials.',
        ),
        daysBeforeDeadline: 30,
        // PAS d'actionRoute. Il valait '/academy', une route qui n'existe pas
        // dans AppRoutes : le bouton rendu par roadmap_timeline_view affichait un
        // Get.snackbar « Redirection vers les tutoriels… » et rien d'autre. Et il
        // n'y a de toute façon aucun tutoriel de rédaction dans l'app, l'Academy
        // étant masquée. Un bouton qui promet une redirection qui n'arrive jamais
        // est pire qu'un bouton absent : l'étudiant croit avoir raté quelque chose.
      ),
      RoadmapStepModel(
        type: RoadmapStepType.review,
        title:
            LocalizedText(fr: 'Revue Finale Expert', en: 'Final Expert Review'),
        description: LocalizedText(
          fr: 'Faites relire votre dossier par un expert KPB avant de l\'envoyer.',
          en: 'Have a KPB expert review your application before you send it.',
        ),
        daysBeforeDeadline: 15,
        // Idem : '/consultation' n'existe pas non plus. L'affordance n'est pas
        // perdue pour autant — l'écran hôte porte DÉJÀ, juste en dessous, un
        // bouton « créer un dossier » qui ouvre réellement le tunnel
        // (orientation_roadmap_screen.dart). Deux boutons pour la même action,
        // dont un seul marche, valent moins qu'un seul qui marche.
      ),
      RoadmapStepModel(
        type: RoadmapStepType.submission,
        title: LocalizedText(
            fr: 'Soumission Officielle', en: 'Official Submission'),
        description: LocalizedText(
          fr: 'Vérifiez une dernière fois et soumettez votre candidature.',
          en: 'Final check and submit your application.',
        ),
        daysBeforeDeadline: 0,
      ),
    ];
  }

  static DateTime calculateDate(DateTime deadline, int daysBefore) {
    return deadline.subtract(Duration(days: daysBefore));
  }
}
