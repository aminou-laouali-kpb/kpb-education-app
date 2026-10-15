part of '../home_screen.dart';

// Section « Bourses » de l'accueil : « Tes bourses » (dernier run du test
// « Mes 10 bourses »), la carte « Fais le test », ou la liste neutre.

/// La section bourses de l'accueil, selon qui regarde :
///
/// - ÉLÈVE avec un run (drapeau `scholarshipMatch` ouvert) : « Tes bourses »,
///   3 cartes tirées du run (compatibles d'abord), chacune ouvre SA fiche ; le
///   lien « Voir mes N bourses » ouvre les résultats ;
/// - élève SANS run (drapeau ouvert) : la carte « Fais le test » ;
/// - drapeau fermé, invité, parent (ou serveur qui a coupé le test) : la liste
///   neutre [neutral] (clôture la plus proche d'abord), SANS aucun niveau de
///   compatibilité — exactement l'accueil d'avant le test.
///
/// La carte « Deadline urgente » ne dépend PAS de cette section : elle lit
/// toujours la liste complète (`_findUrgentDeadline`).
class _HomeScholarshipsSection extends StatefulWidget {
  const _HomeScholarshipsSection({
    required this.controller,
    required this.neutral,
  });

  final AppController controller;

  /// Les 3 bourses de la liste neutre (voir `_homeScholarships`).
  final List<ScholarshipModel> neutral;

  @override
  State<_HomeScholarshipsSection> createState() =>
      _HomeScholarshipsSectionState();
}

class _HomeScholarshipsSectionState extends State<_HomeScholarshipsSection> {
  /// Le compte pour lequel le run a été demandé (un changement de compte
  /// redemande).
  String? _requestedFor;

  /// Relit le dernier run de CE compte (cache, puis serveur une fois par
  /// passage au premier plan). Jamais pendant un build.
  void _ensureLoaded(ScholarshipMatchEntryVariant variant) {
    if (variant == ScholarshipMatchEntryVariant.hidden ||
        variant == ScholarshipMatchEntryVariant.guest) {
      return;
    }
    final app = widget.controller;
    final userId = scholarshipMatchUserId(app);
    if (_requestedFor == userId) return;
    _requestedFor = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ScholarshipMatchStore.instance.loadState(
        client: app.apiClient,
        userId: userId,
        lang: scholarshipMatchLang(app),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScholarshipMatchListener(
      builder: (context, variant) {
        _ensureLoaded(variant);
        final store = ScholarshipMatchStore.instance;
        switch (variant) {
          case ScholarshipMatchEntryVariant.hidden:
          case ScholarshipMatchEntryVariant.guest:
            return _neutralSection();
          case ScholarshipMatchEntryVariant.noRun:
            // Le dernier run de ce compte n'est pas encore relu du cache :
            // rien plutôt qu'un « Fais le test » démenti une frame plus tard.
            if (store.userId != scholarshipMatchUserId(widget.controller)) {
              return const SizedBox.shrink();
            }
            return _entryCard();
          case ScholarshipMatchEntryVariant.hasRun:
          case ScholarshipMatchEntryVariant.stale:
            final run = store.latestRun;
            final items = run == null ? const <MatchItem>[] : homeRunItems(run);
            if (run == null || items.isEmpty) return _entryCard();
            return _runSection(run, items);
        }
      },
    );
  }

  Widget _spaced(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: KpbSpacing.xl),
        child: child,
      );

  Widget _entryCard() => _spaced(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
          child: ScholarshipMatchEntryCard(source: 'home'),
        ),
      );

  Widget _neutralSection() {
    final controller = widget.controller;
    final scholarships = widget.neutral;
    if (scholarships.isEmpty) return const SizedBox.shrink();
    return _spaced(
      HScrollSection(
        title: 'home_scholarships_title'.tr,
        actionLabel: 'see_all'.tr,
        onAction: () => Get.toNamed(AppRoutes.scholarships),
        itemCount: scholarships.length,
        height: 168,
        itemWidth: 210,
        itemBuilder: (ctx, i) {
          final s = scholarships[i];
          return _ScholarshipCard(
            scholarshipId: s.id,
            name: controller.resolve(s.name),
            flag: _flag(s.countryId),
            funding: controller.resolve(s.typeOfFunding),
            onTap: () => Get.toNamed(AppRoutes.scholarships),
          );
        },
      ),
    );
  }

  Widget _runSection(MatchRun run, List<MatchItem> items) {
    final total = run.items.length;
    final now = DateTime.now();
    return _spaced(
      Column(
        key: const ValueKey<String>('home-match-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'home_match_title'.tr,
                      style: KpbTextStyles.title,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('home-match-see-all'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => Get.to<void>(
                    () => const ScholarshipMatchResultsScreen(source: 'home'),
                  ),
                  child: Text(
                    total == 1
                        ? 'home_match_see_all_one'.tr
                        : 'home_match_see_all'.trParams({'count': '$total'}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.pagePad,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: KpbSpacing.sm),
              itemBuilder: (ctx, i) => _MatchHomeCard(item: items[i], now: now),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les 3 cartes de l'accueil tirées d'un run : les bourses encore servies,
/// compatibles d'abord, puis « à vérifier », chacune dans l'ordre du serveur.
@visibleForTesting
List<MatchItem> homeRunItems(MatchRun run) {
  final available = run.items.where((item) => item.available).toList();
  final ordered = <MatchItem>[
    ...available.where((item) => item.isCompatible),
    ...available.where((item) => !item.isCompatible),
  ];
  return ordered.take(3).toList();
}

/// Une bourse du run sur l'accueil : drapeau, statut en TEXTE (servi par le
/// serveur : compatible / à vérifier), nom, fenêtre de candidature. Le toucher
/// ouvre la fiche, où le bloc d'évaluation reprend les raisons.
class _MatchHomeCard extends StatelessWidget {
  const _MatchHomeCard({required this.item, required this.now});

  final MatchItem item;
  final DateTime now;

  void _open() {
    unawaited(AnalyticsService.instance.logScholarshipMatchResultOpened(
      itemId: item.scholarshipId,
      rank: item.rank,
      status: item.isCompatible ? 'eligible' : 'to_verify',
    ));
    unawaited(Get.toNamed<void>(
      AppRoutes.scholarshipDetailPath(item.scholarshipId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final compatible = item.isCompatible;
    final status = compatible
        ? 'scholarship_match_status_compatible'.tr
        : 'scholarship_match_status_to_verify'.tr;
    final window = matchWindowLabel(item.window, now);
    final bottom = window?.$1 ?? item.scholarship?.fundingLabel;
    final bottomColor = switch (window?.$2) {
      MatchWindowTone.open => KpbColors.success,
      MatchWindowTone.upcoming => KpbColors.actionPrimary,
      MatchWindowTone.closed => KpbColors.error,
      _ => KpbColors.textSecondary,
    };
    return KpbPressable(
      key: ValueKey<String>('home-match-card-${item.scholarshipId}'),
      onTap: _open,
      semanticLabel: '${item.name}, ${'scholarship_match_status_a11y'.trParams({
            'status': status
          })}${bottom == null ? '' : ', $bottom'}',
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KpbColors.surface,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Text(
                    _flag(item.scholarship?.countryId ?? ''),
                    style: KpbTextStyles.title,
                  ),
                ),
                const SizedBox(width: KpbSpacing.xs),
                Flexible(
                  child: ExcludeSemantics(
                    child: Container(
                      key: ValueKey<String>(
                        'home-match-status-${item.scholarshipId}',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: compatible
                            ? KpbColors.successLight
                            : KpbColors.warningLight,
                        borderRadius: BorderRadius.circular(KpbRadius.pill),
                      ),
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KpbTextStyles.label.copyWith(
                          color: compatible
                              ? KpbColors.success
                              : KpbColors.warning,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FollowScholarshipButton(
                  scholarshipId: item.scholarshipId,
                  scholarshipTitle: item.name,
                  variant: FollowButtonVariant.icon,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(
                item.name,
                style: KpbTextStyles.titleSm.copyWith(
                  color: KpbColors.brandNavy,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (bottom != null)
              ExcludeSemantics(
                child: Text(
                  bottom,
                  style: KpbTextStyles.label.copyWith(color: bottomColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
