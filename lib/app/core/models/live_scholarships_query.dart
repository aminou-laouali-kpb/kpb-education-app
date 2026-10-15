import 'package:flutter/foundation.dart';

/// Statuts filtrables de la liste des bourses — ceux de `GET /scholarships
/// ?status=` (chantier I), et ceux que la ligne de statut sait dire.
enum ScholarshipListStatus {
  /// Ouverte maintenant.
  open('open'),

  /// Ouverture CONFIRMÉE à venir (« Ouvre le … »).
  upcoming('upcoming'),

  /// Ouverture estimée ou à confirmer.
  forecast('forecast');

  const ScholarshipListStatus(this.wire);

  final String wire;
}

/// Tri de la liste (`GET /scholarships?sort=`).
enum ScholarshipListSort {
  /// L'ordre d'avant : pertinence pour le profil, puis date limite.
  relevance('relevance'),

  /// Clôture la plus proche d'abord.
  deadline('deadline'),

  /// Les plus récemment vérifiées d'abord.
  verified('verified'),

  /// Titre, A → Z.
  title('title');

  const ScholarshipListSort(this.wire);

  final String wire;

  static ScholarshipListSort parse(Object? raw) => ScholarshipListSort.values
      .firstWhere((sort) => sort.wire == raw, orElse: () => relevance);
}

// Le statut que la carte AFFICHE (`scholarshipListStatusOf`) et ce que la
// liste masque (`isScholarshipClosed`) se calculent dans
// `features/scholarships/scholarship_urgency.dart` : LE calcul d'urgence,
// partagé avec la fiche.

/// Une page de `GET /scholarships`, enveloppe comprise.
@immutable
class LiveScholarshipsPage {
  const LiveScholarshipsPage({
    required this.items,
    this.total,
    this.hasMore,
    this.serverAppliedQuery = false,
  });

  /// Les items bruts (JSON) : c'est ce que le cache hors ligne garde.
  final List<dynamic> items;

  /// Le total réel servi par le serveur, ou null (backend ancien).
  final int? total;

  /// `hasMore` du serveur, ou null.
  final bool? hasMore;

  /// Vrai quand la réponse porte `query` : le serveur a appliqué `q`,
  /// `status` et `sort`. Faux : backend antérieur, qui les a ignorés.
  final bool serverAppliedQuery;

  factory LiveScholarshipsPage.fromJson(Map<String, dynamic> json) {
    final total = json['total'];
    final hasMore = json['hasMore'];
    return LiveScholarshipsPage(
      items: json['items'] as List<dynamic>? ?? <dynamic>[],
      total: total is num && total >= 0 ? total.toInt() : null,
      hasMore: hasMore is bool ? hasMore : null,
      serverAppliedQuery: json['query'] is Map,
    );
  }
}
