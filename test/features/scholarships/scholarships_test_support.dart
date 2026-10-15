// Doublure commune de `GET /scholarships` pour les tests d'écran.
//
// Depuis le chantier I, la liste lit l'ENVELOPPE (`fetchLiveScholarshipsPage` :
// total réel, `query` appliquée) et envoie TOUS ses critères à chaque appel —
// statuts, tri, pagination compris. Un `when` qui oublierait un seul argument
// nommé ne correspondrait plus : mocktail rendrait `null`, et l'écran
// s'afficherait vide sans que le test le dise. D'où ce point unique.

import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/live_scholarships_query.dart';

import '../../widget_test_helpers.dart';

/// À appeler une fois par fichier (`setUpAll`) : `any(named: 'sort')` exige une
/// valeur de repli pour l'énumération.
void registerScholarshipListFallbacks() {
  registerFallbackValue(ScholarshipListSort.relevance);
}

/// `fetchLiveScholarshipsPage(...)` avec n'importe quels critères, sauf
/// [fundingType] quand il est précisé.
When<Future<LiveScholarshipsPage>> whenScholarshipsPage(
  MockApiClient api, {
  Object? fundingType = _anyValue,
}) {
  return when(
    () => api.fetchLiveScholarshipsPage(
      lang: any(named: 'lang'),
      level: any(named: 'level'),
      fieldIds: any(named: 'fieldIds'),
      fundingType: identical(fundingType, _anyValue)
          ? any(named: 'fundingType')
          : fundingType as String?,
      statuses: any(named: 'statuses'),
      sort: any(named: 'sort'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  );
}

const Object _anyValue = Object();

/// Une page servie par un backend du chantier I (`query` présente).
LiveScholarshipsPage scholarshipsPage(List<dynamic> items, {int? total}) =>
    LiveScholarshipsPage(
      items: items,
      total: total ?? items.length,
      hasMore: false,
      serverAppliedQuery: true,
    );
