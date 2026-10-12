part of '../app_api_client.dart';

/// Espace « Études en France » : intérêt, profil, catalogue, villes.
mixin _EefApi on _ApiClientBase {
  // ── Espace « Études en France » ────────────────────────────────────────

  /// La déclaration d'intérêt du profil authentifié, ou l'état « pas déclaré ».
  Future<Map<String, dynamic>> getEefInterest() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/interest',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Déclare l'intérêt du profil authentifié pour l'espace.
  ///
  /// Aucun `try`/`catch` ici, volontairement : l'appelant DOIT voir l'échec.
  /// Une erreur avalée à ce niveau ferait afficher « c'est noté » pour une ligne
  /// que le serveur n'a jamais écrite — le défaut exact que le masquage
  /// `documentUploadEnabled` documente, où « fourni ✓ » était coché avant
  /// l'appel réseau et l'échec disparaissait dans Crashlytics.
  Future<Map<String, dynamic>> declareEefInterest({
    required String consentVersion,
    String? currentLevel,
    String? targetLevel,
    List<String> fieldIds = const <String>[],
    bool wantsPremium = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/etudes-en-france/interest',
      data: <String, dynamic>{
        // Le consentement est envoyé EXPLICITEMENT, et le serveur refuse la
        // requête sans lui. Ce n'est pas une formalité : avant ce champ, le
        // serveur horodatait chaque écriture, donc n'importe quelle requête —
        // un rejeu, un retry automatique — fabriquait une preuve de
        // consentement. `consentVersion` dit QUEL texte a été affiché, sans
        // quoi on ne pourrait produire qu'une date.
        'consent': true,
        'consentVersion': consentVersion,
        if (currentLevel != null && currentLevel.isNotEmpty)
          'currentLevel': currentLevel,
        if (targetLevel != null && targetLevel.isNotEmpty)
          'targetLevel': targetLevel,
        if (fieldIds.isNotEmpty) 'fieldIds': fieldIds,
        'wantsPremium': wantsPremium,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Met à jour les NIVEAUX et les DOMAINES d'une déclaration existante — rien
  /// d'autre (`PATCH /etudes-en-france/interest`).
  ///
  /// Ne touche ni au consentement, ni à la version du texte accepté, ni à
  /// l'intérêt Premium : `POST` est un remplacement complet qui réécrit tout cela
  /// et fabriquerait un consentement au rappel que l'étudiant n'a pas redonné.
  ///
  /// Trois états par champ, comme côté serveur : `null` = inchangé, chaîne ou
  /// liste vide = effacé, valeur = remplacée.
  ///
  /// Pas de `try`/`catch` : l'appelant DOIT voir l'échec, pour la même raison que
  /// [declareEefInterest].
  Future<Map<String, dynamic>> updateEefProfile({
    String? currentLevel,
    String? targetLevel,
    List<String>? fieldIds,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/etudes-en-france/interest',
      data: <String, dynamic>{
        if (currentLevel != null) 'currentLevel': currentLevel,
        if (targetLevel != null) 'targetLevel': targetLevel,
        if (fieldIds != null) 'fieldIds': fieldIds,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Retire la déclaration d'intérêt du profil authentifié.
  ///
  /// Pas de `try`/`catch`, comme la déclaration : l'appelant DOIT voir l'échec.
  /// Afficher « tu es retiré » sur une ligne toujours en base serait le même
  /// mensonge que « c'est noté » sur une ligne jamais écrite.
  Future<Map<String, dynamic>> withdrawEefInterest() async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/etudes-en-france/interest',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Recherche paginée du catalogue « Études en France ».
  ///
  /// PUBLIQUE : aucune session n'est requise. C'est la décision produit
  /// « catalogue gratuit, accompagnement payant » — chercher sa formation avant
  /// de créer un compte est précisément ce qui donne une raison d'en créer un.
  ///
  /// Les listes partent en valeurs séparées par des virgules. Le serveur
  /// accepte aussi la forme répétée (`?cycle=a&cycle=b`) ; on retient la
  /// première parce qu'elle tient dans une URL plus courte, ce qui compte sur
  /// les réseaux du public visé.
  ///
  /// Pas de `try`/`catch` : l'appelant DOIT voir l'échec. Une liste vide rendue
  /// sur une panne se lirait « aucune formation ne correspond », ce qui est un
  /// mensonge — et le contrôleur distingue justement les deux.
  Future<Map<String, dynamic>> searchEefCatalog({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> campusCities = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
    String? cursor,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/search',
      queryParameters: <String, dynamic>{
        ..._eefFilterParams(
          query: query,
          cycles: cycles,
          procedureTypes: procedureTypes,
          fieldIds: fieldIds,
          campusCities: campusCities,
          institutionIds: institutionIds,
          selectivities: selectivities,
        ),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Les villes du catalogue sous les filtres posés — `GET
  /// /etudes-en-france/cities`, PUBLIQUE comme la recherche.
  ///
  /// Sert la feuille « Ville » : la facette `campusCity` de la recherche est
  /// tronquée à 20 villes, alors que la France en compte plusieurs centaines
  /// où une formation est offerte. Cette route rend la liste ENTIÈRE, avec le
  /// compte de formations de chaque ville.
  ///
  /// Mêmes paramètres de filtre que [searchEefCatalog], SAUF `campusCity` :
  /// le serveur l'ignore, et une ville déjà cochée ne doit pas réduire la
  /// liste des villes — on veut pouvoir en cocher une autre. Il n'y a donc
  /// volontairement pas de paramètre `campusCities` ici.
  ///
  /// Pas de `try`/`catch`, comme la recherche : l'appelant DOIT voir l'échec.
  /// C'est lui — `EefCatalogController.loadCities` — qui distingue un backend
  /// plus ancien que l'app (404/405/5xx → repli sur la facette) d'une vraie
  /// panne (réseau, 4xx → « Réessayer »).
  Future<Map<String, dynamic>> fetchEefCities({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/cities',
      queryParameters: _eefFilterParams(
        query: query,
        cycles: cycles,
        procedureTypes: procedureTypes,
        fieldIds: fieldIds,
        institutionIds: institutionIds,
        selectivities: selectivities,
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Les filtres du catalogue, tels qu'ils partent dans l'URL : listes en
  /// valeurs séparées par des virgules, familles vides omises, texte rogné.
  /// Un seul endroit pour la recherche ET pour la liste des villes — deux
  /// copies finiraient par ne plus filtrer pareil, et la liste des villes
  /// compterait alors autre chose que ce que la recherche rend.
  static Map<String, dynamic> _eefFilterParams({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> campusCities = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
  }) {
    String? csv(List<String> values) =>
        values.isEmpty ? null : values.join(',');

    return <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (csv(cycles) != null) 'cycle': csv(cycles),
      if (csv(procedureTypes) != null) 'procedureType': csv(procedureTypes),
      if (csv(fieldIds) != null) 'fieldId': csv(fieldIds),
      if (csv(campusCities) != null) 'campusCity': csv(campusCities),
      if (csv(institutionIds) != null) 'institutionId': csv(institutionIds),
      if (csv(selectivities) != null) 'selectivity': csv(selectivities),
    };
  }
}
