part of '../app_controller.dart';

mixin _SearchMixin on _AppControllerBase {
  AppSearchContext get _searchContext => AppSearchContext(
        localeCode: localeCode,
        fields: fields,
        countries: countries,
        institutions: institutions,
        programs: programs,
        scholarships: scholarships,
        profile: profile,
        latestOrientationSession: latestOrientationSession,
      );

  /// One scorer per controller state. It used to be rebuilt on EVERY access,
  /// so each `recommendedInstitutions` read re-scored the whole catalogue
  /// (O(institutions × programs)) several times per build. Invalidated by
  /// [AppController.update], i.e. on every state change.
  AppSearchService? _searchServiceCache;

  AppSearchService get _searchService =>
      _searchServiceCache ??= AppSearchService(_searchContext);

  void _invalidateSearchCache() => _searchServiceCache = null;

  /// Best-matching program in [countryId] for the current profile, ranked by
  /// the shared search scorer. Replaces the old France/ECE-Lyon-only stub so
  /// the eligibility-quiz CTA recommends a real program for all 9 destinations.
  /// Returns null when the catalog has no program for that country.
  ProgramModel? topProgramForCountry(String countryId) {
    final norm = normalizeCountryId(countryId);
    final svc = _searchService;
    ProgramModel? best;
    var bestScore = -1;
    for (final program in programs) {
      if (normalizeCountryId(program.countryId) != norm) continue;
      final score = svc.programMatch(program);
      if (score > bestScore) {
        bestScore = score;
        best = program;
      }
    }
    return best;
  }

  void addSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchHistory.remove(trimmed);
    _searchHistory.insert(0, trimmed);
    if (_searchHistory.length > 10) _searchHistory.removeLast();
    _persist();
    AnalyticsService.instance.logSearch(trimmed);
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    _persist();
    update();
  }

  List<SearchResult> search(String query) => _searchService.run(query);

  int fieldMatch(FieldModel field) => _searchService.fieldMatch(field);

  int programMatch(ProgramModel program) =>
      _searchService.programMatch(program);

  int institutionMatch(InstitutionModel institution) =>
      _searchService.institutionMatch(institution);

  /// Displayable fit tier for [program], or null without a profile — the
  /// ranking score then is a constant fallback that says nothing about the
  /// student, so no badge must be shown.
  ProfileFit? programFit(ProgramModel program) => profile == null
      ? null
      : ProfileFit.fromScore(_searchService.programMatch(program));

  /// Displayable fit tier for [field]; see [programFit].
  ProfileFit? fieldFit(FieldModel field) => profile == null
      ? null
      : ProfileFit.fromScore(_searchService.fieldMatch(field));

  /// Displayable fit tier for [institution]; see [programFit].
  ProfileFit? institutionFit(InstitutionModel institution) => profile == null
      ? null
      : ProfileFit.fromScore(_searchService.institutionMatch(institution));

  /// Displayable fit tier for [scholarship]. Unlike schools, scholarships
  /// carry a curated `baseMatch`, so a tier exists even without a profile.
  ProfileFit scholarshipFit(ScholarshipModel scholarship) =>
      ProfileFit.fromScore(_searchService.scholarshipMatch(scholarship));

  List<FieldModel> get recommendedFields => _searchService.recommendedFields;

  List<ProgramModel> get recommendedPrograms =>
      _searchService.recommendedPrograms;

  List<InstitutionModel> get recommendedInstitutions =>
      _searchService.recommendedInstitutions;

  List<String> matchExplanation(SearchResultType type, String id) =>
      _searchService.matchExplanation(type, id);

  List<ScholarshipModel> get recommendedScholarships =>
      _searchService.recommendedScholarships;

  int scholarshipMatch(ScholarshipModel scholarship) =>
      _searchService.scholarshipMatch(scholarship);
}
