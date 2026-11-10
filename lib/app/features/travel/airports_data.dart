/// Curated airport/city reference data for the flight estimator.
///
/// This backs the searchable origin/destination picker. Entries cover KPB's
/// real corridors: African origins (West/Central/North/East/Southern Africa)
/// and the study/destination hubs students fly to (Europe, North America,
/// Gulf, Asia).
///
/// ACCURACY NOTE: every 3-letter code below is a verified IATA airport code.
/// A wrong code silently returns no flights from the Kayak proxy, so the list
/// deliberately errs on the side of omission over guessing.
library;

import '../../core/utils/search_text.dart';

/// A single airport/city option in the picker.
///
/// [city] and [country] are proper nouns and stay as plain strings (they are
/// rendered through this model in the UI, never as hardcoded `Text()`
/// literals, so the no-hardcoded-French guard never sees them).
class Airport {
  const Airport(this.code, this.city, this.country);

  /// 3-letter IATA airport code (e.g. `CDG`).
  final String code;

  /// City / metropolitan area name.
  final String city;

  /// Country name (localized to French, matching the app's default locale).
  final String country;

  /// e.g. `Paris (CDG)`.
  String get displayName => '$city ($code)';

  /// Lower-cased haystack used for case-insensitive search on code, city and
  /// country.
  bool matches(String query) {
    final q = foldForSearch(query);
    if (q.isEmpty) return true;
    return code.toLowerCase().contains(q) ||
        foldForSearch(city).contains(q) ||
        foldForSearch(country).contains(q);
  }
}

/// Small default set shown when the search box is empty (KPB's most common
/// origins and destinations). Kept as the first-glance list.
const List<Airport> popularAirports = [
  Airport('CDG', 'Paris', 'France'),
  Airport('YUL', 'Montréal', 'Canada'),
  Airport('YYZ', 'Toronto', 'Canada'),
  Airport('JFK', 'New York', 'États-Unis'),
  Airport('BRU', 'Bruxelles', 'Belgique'),
  Airport('CMN', 'Casablanca', 'Maroc'),
  Airport('IST', 'Istanbul', 'Turquie'),
  Airport('LHR', 'Londres', 'Royaume-Uni'),
  Airport('FRA', 'Francfort', 'Allemagne'),
  Airport('MAD', 'Madrid', 'Espagne'),
  Airport('DXB', 'Dubaï', 'Émirats arabes unis'),
  Airport('ABJ', 'Abidjan', 'Côte d\'Ivoire'),
  Airport('DKR', 'Dakar', 'Sénégal'),
  Airport('DLA', 'Douala', 'Cameroun'),
  Airport('LBV', 'Libreville', 'Gabon'),
];

/// The full searchable catalogue. Grouped by region for maintainability; the
/// UI treats it as one flat list.
const List<Airport> kAirports = [
  // ── West Africa ──────────────────────────────────────────────────────────
  Airport('ABJ', 'Abidjan', 'Côte d\'Ivoire'),
  Airport('DKR', 'Dakar', 'Sénégal'),
  Airport('LFW', 'Lomé', 'Togo'),
  Airport('COO', 'Cotonou', 'Bénin'),
  Airport('NIM', 'Niamey', 'Niger'),
  Airport('OUA', 'Ouagadougou', 'Burkina Faso'),
  Airport('BKO', 'Bamako', 'Mali'),
  Airport('CKY', 'Conakry', 'Guinée'),
  Airport('ROB', 'Monrovia', 'Liberia'),
  Airport('FNA', 'Freetown', 'Sierra Leone'),
  Airport('ACC', 'Accra', 'Ghana'),
  Airport('LOS', 'Lagos', 'Nigéria'),
  Airport('ABV', 'Abuja', 'Nigéria'),
  Airport('PHC', 'Port Harcourt', 'Nigéria'),
  Airport('BJL', 'Banjul', 'Gambie'),
  Airport('OXB', 'Bissau', 'Guinée-Bissau'),
  Airport('NKC', 'Nouakchott', 'Mauritanie'),

  // ── Central Africa ─────────────────────────────────────────────────────────
  Airport('DLA', 'Douala', 'Cameroun'),
  Airport('YAO', 'Yaoundé', 'Cameroun'),
  Airport('NSI', 'Yaoundé Nsimalen', 'Cameroun'),
  Airport('LBV', 'Libreville', 'Gabon'),
  Airport('SSG', 'Malabo', 'Guinée équatoriale'),
  Airport('BGF', 'Bangui', 'République centrafricaine'),
  Airport('NDJ', 'N\'Djaména', 'Tchad'),
  Airport('BZV', 'Brazzaville', 'Congo'),
  Airport('FIH', 'Kinshasa', 'RD Congo'),
  Airport('FBM', 'Lubumbashi', 'RD Congo'),

  // ── East Africa ──────────────────────────────────────────────────────────
  Airport('NBO', 'Nairobi', 'Kenya'),
  Airport('ADD', 'Addis-Abeba', 'Éthiopie'),
  Airport('DAR', 'Dar es Salaam', 'Tanzanie'),
  Airport('KGL', 'Kigali', 'Rwanda'),
  Airport('BJM', 'Bujumbura', 'Burundi'),
  Airport('EBB', 'Entebbe', 'Ouganda'),
  Airport('JIB', 'Djibouti', 'Djibouti'),

  // ── North Africa / Maghreb ─────────────────────────────────────────────────
  Airport('CMN', 'Casablanca', 'Maroc'),
  Airport('RAK', 'Marrakech', 'Maroc'),
  Airport('RBA', 'Rabat', 'Maroc'),
  Airport('TUN', 'Tunis', 'Tunisie'),
  Airport('ALG', 'Alger', 'Algérie'),
  Airport('ORN', 'Oran', 'Algérie'),
  Airport('CAI', 'Le Caire', 'Égypte'),

  // ── Southern Africa ────────────────────────────────────────────────────────
  Airport('JNB', 'Johannesbourg', 'Afrique du Sud'),
  Airport('CPT', 'Le Cap', 'Afrique du Sud'),

  // ── France ─────────────────────────────────────────────────────────────────
  Airport('CDG', 'Paris Charles-de-Gaulle', 'France'),
  Airport('ORY', 'Paris Orly', 'France'),
  Airport('LYS', 'Lyon', 'France'),
  Airport('MRS', 'Marseille', 'France'),
  Airport('TLS', 'Toulouse', 'France'),
  Airport('NCE', 'Nice', 'France'),
  Airport('BOD', 'Bordeaux', 'France'),
  Airport('NTE', 'Nantes', 'France'),
  Airport('LIL', 'Lille', 'France'),
  Airport('MPL', 'Montpellier', 'France'),
  Airport('SXB', 'Strasbourg', 'France'),

  // ── Belgium ──────────────────────────────────────────────────────────────
  Airport('BRU', 'Bruxelles', 'Belgique'),
  Airport('CRL', 'Charleroi', 'Belgique'),

  // ── United Kingdom & Ireland ───────────────────────────────────────────────
  Airport('LHR', 'Londres Heathrow', 'Royaume-Uni'),
  Airport('LGW', 'Londres Gatwick', 'Royaume-Uni'),
  Airport('MAN', 'Manchester', 'Royaume-Uni'),
  Airport('EDI', 'Édimbourg', 'Royaume-Uni'),
  Airport('DUB', 'Dublin', 'Irlande'),

  // ── Canada ─────────────────────────────────────────────────────────────────
  Airport('YUL', 'Montréal', 'Canada'),
  Airport('YYZ', 'Toronto', 'Canada'),
  Airport('YOW', 'Ottawa', 'Canada'),
  Airport('YVR', 'Vancouver', 'Canada'),
  Airport('YQB', 'Québec', 'Canada'),

  // ── United States ──────────────────────────────────────────────────────────
  Airport('JFK', 'New York JFK', 'États-Unis'),
  Airport('EWR', 'Newark', 'États-Unis'),
  Airport('BOS', 'Boston', 'États-Unis'),
  Airport('IAD', 'Washington Dulles', 'États-Unis'),
  Airport('ORD', 'Chicago', 'États-Unis'),
  Airport('ATL', 'Atlanta', 'États-Unis'),
  Airport('LAX', 'Los Angeles', 'États-Unis'),
  Airport('IAH', 'Houston', 'États-Unis'),

  // ── Germany ────────────────────────────────────────────────────────────────
  Airport('FRA', 'Francfort', 'Allemagne'),
  Airport('MUC', 'Munich', 'Allemagne'),
  Airport('BER', 'Berlin', 'Allemagne'),
  Airport('DUS', 'Düsseldorf', 'Allemagne'),
  Airport('HAM', 'Hambourg', 'Allemagne'),

  // ── Netherlands ────────────────────────────────────────────────────────────
  Airport('AMS', 'Amsterdam', 'Pays-Bas'),

  // ── Spain ──────────────────────────────────────────────────────────────────
  Airport('MAD', 'Madrid', 'Espagne'),
  Airport('BCN', 'Barcelone', 'Espagne'),

  // ── Italy ──────────────────────────────────────────────────────────────────
  Airport('FCO', 'Rome', 'Italie'),
  Airport('MXP', 'Milan', 'Italie'),

  // ── Portugal ───────────────────────────────────────────────────────────────
  Airport('LIS', 'Lisbonne', 'Portugal'),
  Airport('OPO', 'Porto', 'Portugal'),

  // ── Switzerland ────────────────────────────────────────────────────────────
  Airport('GVA', 'Genève', 'Suisse'),
  Airport('ZRH', 'Zurich', 'Suisse'),

  // ── Austria ────────────────────────────────────────────────────────────────
  Airport('VIE', 'Vienne', 'Autriche'),

  // ── Turkey ─────────────────────────────────────────────────────────────────
  Airport('IST', 'Istanbul', 'Turquie'),
  Airport('SAW', 'Istanbul Sabiha Gökçen', 'Turquie'),

  // ── Gulf ───────────────────────────────────────────────────────────────────
  Airport('DXB', 'Dubaï', 'Émirats arabes unis'),
  Airport('AUH', 'Abou Dabi', 'Émirats arabes unis'),
  Airport('DOH', 'Doha', 'Qatar'),

  // ── China ──────────────────────────────────────────────────────────────────
  Airport('PEK', 'Pékin', 'Chine'),
  Airport('PVG', 'Shanghai', 'Chine'),
  Airport('CAN', 'Guangzhou', 'Chine'),

  // ── India ──────────────────────────────────────────────────────────────────
  Airport('DEL', 'New Delhi', 'Inde'),
];
