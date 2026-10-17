import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/eef_search.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_catalog_controller.dart';
import 'eef_catalog_filters.dart';
import 'eef_data_notice.dart';
import 'eef_help_bubble.dart';
import 'eef_help_card.dart';
import 'eef_help_line.dart';
import 'eef_private_schools_sheet.dart';

/// Le catalogue « Études en France », cherché SUR LE SERVEUR.
///
/// ## Pourquoi cet écran ne charge pas le catalogue
///
/// `AppController` tient la totalité du catalogue en mémoire et filtre côté
/// app. C'était tenable à 133 formations ; à 10 247 c'est une app qui rame sur
/// les appareils les moins chers — ceux du public visé. Cet écran ne garde donc
/// jamais plus que les pages qu'on lui a demandé d'afficher, et tout le tri,
/// les filtres et les compteurs viennent de `GET /etudes-en-france/search`.
///
/// ## Ce que l'écran s'interdit
///
/// Confondre « rien ne correspond » et « je n'ai pas pu demander ». Le premier
/// est un fait qui appelle à élargir sa recherche, le second une panne qui
/// appelle à réessayer. Deux états, deux écrans, deux gestes.
class EefCatalogScreen extends StatelessWidget {
  const EefCatalogScreen({super.key, this.source = 'hub'});

  /// Par quelle porte l'étudiant est arrivé — pour savoir laquelle amène du
  /// monde (voir `logEefCatalogViewed`).
  final String source;

  @override
  Widget build(BuildContext context) {
    // La route est joignable par lien profond même drapeaux éteints, comme
    // `EefEntry` : sans cette porte, un lien reçu avant l'ouverture montrerait un
    // catalogue que la vitrine dit « en préparation ». Elle se reconstruit à
    // l'arrivée des drapeaux serveur, pour ne pas rester sur « bientôt ».
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!RemoteFeatureFlags.instance.eefSpaceEnabled) {
          return ComingSoonScreen(title: 'eef_catalog_title'.tr);
        }
        return _EefCatalogView(source: source);
      },
    );
  }
}

class _EefCatalogView extends StatefulWidget {
  const _EefCatalogView({required this.source});

  final String source;

  @override
  State<_EefCatalogView> createState() => _EefCatalogViewState();
}

class _EefCatalogViewState extends State<_EefCatalogView> {
  late final EefCatalogController _controller;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _queryField = TextEditingController();
  int _seenGeneration = 0;

  @override
  void initState() {
    super.initState();
    // `AppApiClient` n'est pas enregistré dans GetX : il vit sur
    // `AppController`, qui l'a construit. Même motif que la vitrine.
    _controller = EefCatalogController(
      apiClient: Get.find<AppController>().apiClient,
    );
    _controller.addListener(_onControllerChanged);
    _scroll.addListener(_onScroll);
    unawaited(AnalyticsService.instance.logEefCatalogViewed(widget.source));
    _controller.refresh();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Le champ suit le contrôleur. « Tout effacer » vide `query` côté
    // contrôleur ; sans cette synchronisation le champ gardait le texte, et
    // l'étudiant voyait « droit » dans la barre au-dessus de résultats qui ne
    // portaient plus aucun filtre. Pendant la frappe les deux sont égaux, donc
    // le curseur n'est jamais déplacé.
    if (_queryField.text != _controller.query) {
      _queryField.value = TextEditingValue(
        text: _controller.query,
        selection: TextSelection.collapsed(offset: _controller.query.length),
      );
    }
    // Une nouvelle recherche remonte la liste en haut.
    if (_controller.searchGeneration != _seenGeneration) {
      _seenGeneration = _controller.searchGeneration;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Un écran d'avance : la page suivante part avant que l'étudiant ne voie le
    // bas de la liste, donc sans temps mort visible.
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) _controller.loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _queryField.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Le nom d'un domaine (`d07`), dans la langue active, depuis le référentiel
  /// que l'app charge déjà (`AppController.fields`, synchronisé avec le
  /// catalogue) — les mêmes noms que partout ailleurs dans l'app. `null` quand le
  /// référentiel ne connaît pas ce domaine : la valeur est alors ignorée plutôt
  /// qu'affichée sous son code.
  String? _fieldName(String id) {
    final locale = Get.locale?.languageCode ?? 'fr';
    return eefLocalizedName(
      Get.find<AppController>().fieldByIdOrNull(id)?.name,
      locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruit à l'arrivée des drapeaux serveur. Le clavier se lit ICI,
    // au-dessus du `Scaffold` : le corps ne le voit plus (le `Scaffold` le
    // consomme), et la bulle masquerait le champ de recherche.
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) =>
          _scaffold(bubbleShown: EefHelpBubble.shouldShow(context)),
    );
  }

  Widget _scaffold({required bool bubbleShown}) {
    return Scaffold(
      appBar: AppBar(title: Text('eef_catalog_title'.tr)),
      // `LayoutBuilder` : l'en-tête des filtres se borne sur la hauteur RÉELLEMENT
      // libre du corps (clavier ouvert compris), que ni la taille de l'écran ni
      // un `MediaQuery` ne donnent — le `Scaffold` consomme le clavier.
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            _SearchField(controller: _controller, field: _queryField),
            EefFilterHeader(
              controller: _controller,
              fieldName: _fieldName,
              maxHeight: constraints.maxHeight * 0.34,
            ),
            // Une recherche AFFINÉE garde l'ancienne liste à l'écran le temps de
            // la réponse : sans signe de chargement, l'étudiant lit des résultats
            // périmés alors que sa puce est déjà cochée.
            if (_controller.phase == EefCatalogPhase.loading &&
                _controller.items.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            // La bulle vit dans un `Stack` qui enveloppe la SEULE liste : elle est
            // donc toujours AU-DESSUS de la rangée des sources, qui reste fixe, en
            // bas, et n'est pas déplacée. 16 dp du bord droit et de la rangée ;
            // la zone sûre est déjà consommée par la `SafeArea` de cette rangée.
            //
            // Sous [EefHelpBubble.minHostHeight] de liste (champ de recherche,
            // filtres occupent déjà tout l'écran),
            // le `Stack` rognerait la bulle et elle ne se laisserait plus toucher :
            // elle est alors retirée, et la liste reprend sa marge ordinaire.
            Expanded(
              child: LayoutBuilder(
                builder: (context, host) {
                  final showBubble = bubbleShown &&
                      host.maxHeight >= EefHelpBubble.minHostHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _Results(
                        controller: _controller,
                        scroll: _scroll,
                        fieldName: _fieldName,
                        bubbleShown: showBubble,
                      ),
                      if (showBubble)
                        const Positioned(
                          right: EefHelpBubble.edgeMargin,
                          bottom: EefHelpBubble.edgeMargin,
                          child:
                              EefHelpBubble(surface: EefBubbleSurface.catalog),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SafeArea(top: false, child: EefSourcesRow()),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.field});

  final EefCatalogController controller;
  final TextEditingController field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.sm,
      ),
      child: TextField(
        controller: field,
        onChanged: controller.onQueryChanged,
        onSubmitted: controller.search,
        textInputAction: TextInputAction.search,
        decoration: KpbInputDecoration.build(
          context,
          label: 'eef_catalog_search_hint'.tr,
          prefixIcon: Icons.search_rounded,
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.controller,
    required this.scroll,
    required this.fieldName,
    required this.bubbleShown,
  });

  final EefCatalogController controller;
  final ScrollController scroll;
  final EefFieldNameResolver fieldName;

  /// La bulle d'aide est posée sur le coin bas droit : la marge basse des listes
  /// passe de 32 à 104 dp (voir [EefHelpBubble.listBottomPadding]), pour que la
  /// dernière carte défile jusqu'au-dessus d'elle.
  final bool bubbleShown;

  /// Un état plein écran (vide, pas publié) reste dans une liste : la mention
  /// des données et la non-affiliation doivent rester atteignables partout.
  ///
  /// [help] est la carte d'aide de l'état, posée entre l'état et les mentions :
  /// c'est le moment où l'étudiant n'a plus rien à faire seul.
  ///
  /// [extra] est une ligne secondaire posée SOUS la carte d'aide et AVANT la
  /// mention des données (jamais dans la zone d'attribution) : elle se cache
  /// d'elle-même, sans laisser de marge, quand elle n'a pas lieu d'être.
  Widget _stateWithNotice(Widget state, {EefHelpStep? help, Widget? extra}) {
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        EefHelpBubble.listBottomPadding(bubbleShown: bubbleShown),
      ),
      children: [
        state,
        if (help != null) ...[
          EefHelpCard(step: help),
          const SizedBox(height: KpbSpacing.md),
        ],
        if (extra != null) extra,
        const EefDataNotice(),
      ],
    );
  }

  /// L'étudiant filtre-t-il sur une procédure qu'on confond (dossier jaune,
  /// Parcoursup, hors procédure) — ou une carte affichée a-t-elle une procédure
  /// que l'app ne sait pas nommer ?
  ///
  /// C'est le moment, et le seul, où la ligne d'aide de la procédure se montre
  /// au-dessus des résultats : partout ailleurs elle serait un bandeau
  /// permanent, que personne ne lit plus au bout de deux jours.
  bool get _showProcedureHelp =>
      controller
          .selectedValues(kEefFacetProcedure)
          .any(eefProcedureIsConfusing) ||
      controller.items.any((item) => !eefProcedureIsKnown(item.procedureType));

  @override
  Widget build(BuildContext context) {
    if (controller.phase == EefCatalogPhase.failed) {
      // Dans une liste, comme les autres états : la bulle ne recouvre ni le
      // texte ni « Réessayer » (marge basse de 104 dp), et un petit écran peut
      // défiler jusqu'au bouton. L'état reste centré quand il tient.
      final bottom = EefHelpBubble.listBottomPadding(bubbleShown: bubbleShown);
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          controller: scroll,
          padding: EdgeInsets.only(bottom: bottom),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - bottom),
              ),
              child: KpbErrorState(
                title: controller.failure == EefCatalogFailure.network
                    ? 'eef_catalog_error_network_title'.tr
                    : 'eef_catalog_error_server_title'.tr,
                subtitle: 'eef_catalog_error_body'.tr,
                onRetry: controller.refresh,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.phase == EefCatalogPhase.loading &&
        controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Avant « vide » : un catalogue où RIEN n'est publié n'a pas de recherche
    // trop étroite. Lui proposer « tout effacer » enverrait l'étudiant retirer
    // des filtres sur une base vide.
    if (controller.isCatalogNotPublished) {
      return _stateWithNotice(
        KpbEmptyState(
          icon: Icons.hourglass_top_rounded,
          title: 'eef_catalog_unpublished_title'.tr,
          subtitle: 'eef_catalog_unpublished_body'.tr,
        ),
        // Le texte ci-dessus renvoie à « un conseiller KPB » sans en donner le
        // moyen : la carte le donne.
        help: EefHelpStep.catalogUnpublished,
      );
    }

    if (controller.isEmptyResult) {
      // Un résultat vide venu d'un serveur qui A répondu est un FAIT. On le dit
      // comme tel, et on propose le seul geste utile : élargir.
      return _stateWithNotice(
        KpbEmptyState(
          icon: Icons.search_off_rounded,
          title: 'eef_catalog_empty_title'.tr,
          subtitle: 'eef_catalog_empty_body'.tr,
          actionLabel: 'eef_catalog_empty_action'.tr,
          onAction: controller.clearFilters,
        ),
        help: EefHelpStep.catalogEmpty,
        // Le moment où l'étudiant se croit écarté (« rien ne correspond ») : une
        // ligne lui dit qu'il existe un autre type d'établissement, avec ses
        // limites. Ici seulement — pas dans « rien n'est publié ». Elle n'existe
        // que si le serveur l'a ouverte et pour un compte non suspendu.
        extra: const EefPrivateSchoolsNote(),
      );
    }

    final items = controller.items;
    // UNE ligne d'aide à la fois sous le compteur : la ligne de procédure garde
    // la priorité sur celle des filtres (voir `eefCatalogHelpLineFor`). Les deux
    // lignes sont décidées ICI, au même endroit, pour qu'aucune ne s'empile sur
    // l'autre.
    final helpLine = eefCatalogHelpLineFor(
      confusingProcedure: _showProcedureHelp,
      filtersActive: controller.activeFilterCount > 0,
      suspended: EefHelp.isSuspended(),
    );
    // La carte « sous les résultats » n'existe que quand la liste est ENTIÈRE :
    // tant qu'il reste des pages, le défilement la repousse à chaque chargement,
    // et elle n'apparaîtrait qu'une demi-seconde sous les yeux de l'étudiant.
    final showResultsHelp = !controller.hasMore;
    // En-tête + cartes + pied (état de la page suivante) + [carte d'aide] +
    // mentions.
    final helpIndex = showResultsHelp ? items.length + 2 : -1;
    return ListView.separated(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.sm,
        KpbSpacing.pagePad,
        EefHelpBubble.listBottomPadding(bubbleShown: bubbleShown),
      ),
      itemCount: items.length + (showResultsHelp ? 4 : 3),
      separatorBuilder: (_, __) => const SizedBox(height: KpbSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'eef_catalog_result_count'
                      .trParams({'count': '${controller.total}'}),
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted),
                ),
                if (helpLine == EefCatalogHelpLine.procedure)
                  const EefHelpCard(step: EefHelpStep.catalogProcedure),
                if (helpLine == EefCatalogHelpLine.filters)
                  EefFiltersHelpLine(
                    controller: controller,
                    fieldName: fieldName,
                  ),
                // « Un accompagnement n'est pas une garantie » : UNE mention par
                // état de la liste. Quand elle est entière, la carte pleine du bas
                // la porte ; tant qu'il reste des pages — le catalogue par défaut,
                // des milliers de formations —, cette carte n'existe pas alors que
                // chaque formation propose déjà « Demander de l'aide » : la mention
                // vit alors ici, avant la liste, pour que l'aide ne soit jamais
                // proposée sans elle. Jamais les deux à la fois.
                //
                // `textSecondary` et non `textMuted` : un jeton « à réserver au texte
                // de 18 px et plus » (voir app_tokens.dart) ne tient pas 4,5:1 sur ce
                // fond en sombre (3,67:1 mesuré) — et c'est un texte de légende.
                if (!showResultsHelp)
                  Padding(
                    padding: const EdgeInsets.only(top: KpbSpacing.xs),
                    child: Text(
                      'eef_help_fineprint'.tr,
                      style: KpbTextStyles.caption
                          .copyWith(color: context.kpb.textSecondary),
                    ),
                  ),
              ],
            ),
          );
        }
        if (index <= items.length) {
          return _ProgramCard(item: items[index - 1]);
        }
        if (index == items.length + 1) {
          return _ListFooter(controller: controller);
        }
        if (index == helpIndex) {
          return const EefHelpCard(step: EefHelpStep.catalogResults);
        }
        return const Padding(
          padding: EdgeInsets.only(top: KpbSpacing.md),
          child: EefDataNotice(),
        );
      },
    );
  }
}

/// Ce qui se passe sous la dernière carte : la page suivante qui charge, ou qui
/// a échoué.
///
/// Un échec de page suivante ne remplace PAS la liste (voir
/// [EefCatalogController.loadMoreFailed]) : il se dit ici, au bas de ce qui a été
/// lu, avec le geste qui relance.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final EefCatalogController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == EefCatalogPhase.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(KpbSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
        child: Column(
          children: [
            Text(
              'eef_catalog_more_failed'.tr,
              textAlign: TextAlign.center,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            TextButton(
              onPressed: controller.retryLoadMore,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('eef_catalog_more_retry'.tr),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.item});

  final EefProgram item;

  /// Le libellé de la procédure, ou `null` si la valeur n'est pas connue de
  /// l'app. `.tr` rend la CLÉ quand elle manque : un badge « eef_catalog_value_… »
  /// serait pire que pas de badge.
  String? _procedureLabel() {
    final procedure = item.procedureType;
    if (procedure == null) return null;
    final key = 'eef_catalog_value_procedureType_$procedure';
    final translated = key.tr;
    return translated == key ? null : translated;
  }

  @override
  Widget build(BuildContext context) {
    // `LocalizedText.resolve` porte déjà la règle de repli. La réécrire ici
    // en ferait une seconde source de vérité, qui finirait par diverger.
    final locale = Get.locale?.languageCode ?? 'fr';
    final program = item.program;
    final programName = program.name.resolve(locale);

    // L'université d'abord : « L1 - Droit » existe dans une quarantaine
    // d'établissements, et une carte qui n'en nomme aucun est inutilisable pour
    // choisir. Quand le serveur n'en a pas servi, la carte reste honnête — la
    // formation seule, sans nom inventé.
    final institution = item.institution;
    final institutionName = institution?.name.resolve(locale) ?? '';
    final acronym = institution?.acronym;
    final institutionLabel = institutionName.isEmpty
        ? ''
        : (acronym != null && !institutionName.contains(acronym)
            ? '$institutionName ($acronym)'
            : institutionName);
    final city = item.campusCity ?? institution?.location.resolve(locale) ?? '';
    final where =
        [institutionLabel, city].where((p) => p.isNotEmpty).join(' · ');

    final procedure = _procedureLabel();
    final level = program.level.resolve(locale);
    // Une 1re année d'accès santé (PASS ou L.AS) s'intitule souvent « L1 - Droit »
    // ou « L1 - Chimie » : sans ce badge, une recherche « médecine » montrerait des
    // licences de droit sans dire pourquoi. C'est le serveur qui le décide : le
    // cycle `sante` compte aussi des diplômes paramédicaux (orthophoniste…), dont
    // l'intitulé se suffit et qui ne sont pas un accès aux études de médecine.
    final healthAccess = item.healthAccess;

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(programName, style: KpbTextStyles.titleSm),
          if (where.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.school_outlined,
                    size: 14,
                    color: context.kpb.textMuted,
                  ),
                ),
                const SizedBox(width: KpbSpacing.xs),
                Expanded(
                  child: Text(
                    where,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: KpbSpacing.xs),
          Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (procedure != null)
                KpbBadge(
                  label: procedure,
                  small: true,
                  color: item.procedureType == 'hors_eef'
                      ? KpbColors.warning
                      : KpbColors.blue,
                ),
              if (healthAccess)
                KpbBadge(
                  label: 'eef_catalog_badge_health_access'.tr,
                  small: true,
                  color: KpbColors.success,
                ),
              if (level.isNotEmpty)
                Text(
                  level,
                  style: KpbTextStyles.bodySm
                      .copyWith(color: context.kpb.textMuted),
                ),
            ],
          ),
          // Les rentrées publiées de la formation, s'il y en a. Pas de repli
          // sur l'établissement : le résumé « Études en France » n'en porte
          // pas, et une université n'a pas de « septembre » par défaut.
          ProgramIntakeLine(program: program, localeCode: locale),
          const SizedBox(height: KpbSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: context.kpb.textMuted,
              ),
              const SizedBox(width: KpbSpacing.xs),
              Expanded(
                child: Text(
                  program.duration.resolve(locale),
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted),
                ),
              ),
            ],
          ),
          // `KpbSourceLink` se masque lui-même quand l'URL est absente ou non
          // ouvrable : pas de condition ici, sinon la règle vivrait à deux
          // endroits et l'un des deux finirait par diverger.
          const SizedBox(height: KpbSpacing.sm),
          KpbSourceLink(url: program.sourceUrl),
          // « Demander de l'aide » : un bouton de texte, pas une carte. Il nomme
          // la formation, l'université et la ville dans le message, et rien d'autre
          // de personnel. Pas de « vue » par carte affichée (voir
          // `EefHelpTrigger.catalogProgram`), et la mention de non-garantie n'est
          // pas répétée sous chaque carte : elle est portée UNE fois par l'écran,
          // par la carte du bas de liste ou, tant que la liste est paginée, par
          // l'en-tête (voir `_Results`).
          EefHelpLine(
            key: ValueKey('eef-help-program-${item.id}'),
            trigger: EefHelpTrigger.catalogProgram,
            subject: programName,
            prefill: (suspended) => EefHelpMessages.forProgram(
              program: programName,
              institution: institutionName,
              city: city,
              suspended: suspended,
            ),
          ),
        ],
      ),
    );
  }
}
