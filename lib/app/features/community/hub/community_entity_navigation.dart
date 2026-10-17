import 'package:get/get.dart';

import '../../../core/controllers/app_controller.dart';
import '../../../core/models/community.dart';
import '../../../core/navigation/scholarship_navigation.dart';
import '../../explore/country_detail_screen.dart';
import '../../explore/program_detail_screen.dart';
import 'community_entity_space_screen.dart';

/// Ce qu'ouvre une carte d'entité mentionnée.
enum CommunityEntityDestination {
  /// La fiche existante (bourse, pays, formation).
  fiche,

  /// Pas de fiche connue dans le catalogue local : l'espace de discussion de
  /// l'entité, qui en garde le libellé figé.
  space,
}

/// Où mène [mention] (testable seule).
///
/// - bourse : toujours la fiche (le serveur la charge par identifiant ; une
///   bourse devenue non publique y affiche son propre « introuvable ») ;
/// - pays : la fiche pays ;
/// - formation : sa fiche si le catalogue local la connaît ;
/// - école : il n'existe pas de fiche « école » seule dans l'app — la fiche
///   d'une de ses formations la présente. On ouvre donc la première formation
///   de l'école connue du catalogue, sinon l'espace de discussion.
({CommunityEntityDestination kind, String? programId})
    resolveCommunityEntityDestination(
  CommunityMention mention, {
  AppController? controller,
}) {
  switch (mention.type) {
    case CommunityEntityType.scholarship:
    case CommunityEntityType.country:
      return (kind: CommunityEntityDestination.fiche, programId: null);
    case CommunityEntityType.program:
      final known = controller?.programByIdOrNull(mention.id) != null;
      return (
        kind: known
            ? CommunityEntityDestination.fiche
            : CommunityEntityDestination.space,
        programId: known ? mention.id : null,
      );
    case CommunityEntityType.institution:
      final program = controller?.programs
          .firstWhereOrNull((p) => p.institutionId == mention.id);
      return (
        kind: program != null
            ? CommunityEntityDestination.fiche
            : CommunityEntityDestination.space,
        programId: program?.id,
      );
  }
}

/// Ouvre la fiche de l'entité mentionnée (voir
/// [resolveCommunityEntityDestination]).
void openCommunityEntity(CommunityMention mention) {
  final controller =
      Get.isRegistered<AppController>() ? Get.find<AppController>() : null;
  final target =
      resolveCommunityEntityDestination(mention, controller: controller);
  if (target.kind == CommunityEntityDestination.space) {
    Get.to<void>(() => CommunityEntitySpaceScreen(entity: mention));
    return;
  }
  switch (mention.type) {
    case CommunityEntityType.scholarship:
      openScholarshipOrTab(scholarshipId: mention.id);
    case CommunityEntityType.country:
      Get.to<void>(() => CountryDetailScreen(countryId: mention.id));
    case CommunityEntityType.program:
    case CommunityEntityType.institution:
      Get.to<void>(() => ProgramDetailScreen(programId: target.programId!));
  }
}
