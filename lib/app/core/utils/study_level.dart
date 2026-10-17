// ─────────────────────────────────────────────────────────────────────────────
// Study levels — single source of truth (Chantier A).
//
// The app mixes TWO genuinely different academic axes; we keep them separate
// on purpose because conflating them produces wrong labels:
//
//   1. STUDENT LEVEL (a *year* of study) — what a student declares about
//      themselves in onboarding/profile, and what feeds the eligibility
//      simulator. Vocabulary: Terminale · Bachelor 1/2/3 · Master 1/2 · Doctorat.
//
//   2. PROGRAM DEGREE LEVEL (a *diploma*) — what a formation in the catalogue
//      awards. Raw sources are messy ("Bac+3", "MSc · Bac+5", "PGE", "Grande
//      Ecole", "BBA"…). We normalise them to clean degree labels:
//      Bachelor · BBA · Master · MBA / DBA · Doctorat.
//
// Everything user-facing should go through `studentLevelLabel()` or
// `programLevelLabel()` so "B1", "L1", "Bac+5", "MSc · Bac+5" never leak to the
// UI again.
// ─────────────────────────────────────────────────────────────────────────────

/// A student's current year of study (axis 1).
enum StudentLevel {
  terminale,
  bachelor1,
  bachelor2,
  bachelor3,
  master1,
  master2,
  doctorat,
}

extension StudentLevelX on StudentLevel {
  /// Stable machine key (safe to persist / send to the API).
  String get key {
    switch (this) {
      case StudentLevel.terminale:
        return 'terminale';
      case StudentLevel.bachelor1:
        return 'bachelor_1';
      case StudentLevel.bachelor2:
        return 'bachelor_2';
      case StudentLevel.bachelor3:
        return 'bachelor_3';
      case StudentLevel.master1:
        return 'master_1';
      case StudentLevel.master2:
        return 'master_2';
      case StudentLevel.doctorat:
        return 'doctorat';
    }
  }

  /// Human label shown in the UI (FR).
  String get labelFr {
    switch (this) {
      case StudentLevel.terminale:
        return 'Terminale';
      case StudentLevel.bachelor1:
        return 'Bachelor 1';
      case StudentLevel.bachelor2:
        return 'Bachelor 2';
      case StudentLevel.bachelor3:
        return 'Bachelor 3';
      case StudentLevel.master1:
        return 'Master 1';
      case StudentLevel.master2:
        return 'Master 2';
      case StudentLevel.doctorat:
        return 'Doctorat';
    }
  }

  /// First year of a cycle → a bac series is still relevant.
  bool get needsBacSeries =>
      this == StudentLevel.terminale || this == StudentLevel.bachelor1;
}

/// Ordered list of clean student-level labels (used by onboarding/profile/
/// simulator dropdowns).
final List<String> studentLevelLabels =
    StudentLevel.values.map((l) => l.labelFr).toList(growable: false);

/// Normalise any raw/legacy student-level token to a canonical [StudentLevel].
/// Handles old onboarding values ("L1 / Bachelor 1", "M1") and terse codes
/// ("B1", "L3"). Returns null when nothing reasonable matches.
StudentLevel? normalizeStudentLevel(String? raw) {
  if (raw == null) return null;
  final s = _slug(raw);
  if (s.isEmpty) return null;

  // « High school » est le jeton que l'onboarding persiste pour le lycée.
  if (s.contains('terminale') ||
      s == 'bac' ||
      s.contains('lycee') ||
      s.contains('highschool')) {
    return StudentLevel.terminale;
  }
  if (s.contains('doctorat') || s.contains('phd') || s.contains('these')) {
    return StudentLevel.doctorat;
  }
  // Master years.
  if (s.contains('m1') || s.contains('master1') || s.contains('master 1')) {
    return StudentLevel.master1;
  }
  if (s.contains('m2') || s.contains('master2') || s.contains('master 2')) {
    return StudentLevel.master2;
  }
  // Bachelor / Licence years (L1-L3, B1-B3).
  if (s.contains('l1') ||
      s.contains('b1') ||
      s.contains('bachelor1') ||
      s.contains('bachelor 1') ||
      s.contains('licence1')) {
    return StudentLevel.bachelor1;
  }
  if (s.contains('l2') ||
      s.contains('b2') ||
      s.contains('bachelor2') ||
      s.contains('bachelor 2') ||
      s.contains('licence2')) {
    return StudentLevel.bachelor2;
  }
  if (s.contains('l3') ||
      s.contains('b3') ||
      s.contains('bachelor3') ||
      s.contains('bachelor 3') ||
      s.contains('licence3')) {
    return StudentLevel.bachelor3;
  }
  // Bare "master" / "bachelor" without a year → assume the first year.
  if (s.contains('master')) return StudentLevel.master1;
  if (s.contains('bachelor') || s.contains('licence')) {
    return StudentLevel.bachelor1;
  }
  return null;
}

/// Clean a raw student-level string for display. Falls back to the original
/// (trimmed) string if it can't be normalised, so we never blank out data.
String studentLevelLabel(String? raw) {
  final level = normalizeStudentLevel(raw);
  if (level != null) return level.labelFr;
  return (raw ?? '').trim();
}

/// A formation's awarded degree (axis 2).
enum ProgramLevel {
  bac2,
  bachelor,
  bba,
  master,
  mba,
  doctorat,
  // Collèges canadiens : diplôme / diplôme avancé de l'Ontario, DEC, CCNB…
  college,
  // Certificat postdiplôme de l'Ontario (après un premier diplôme).
  gradCert,
  other,
}

extension ProgramLevelX on ProgramLevel {
  String get labelFr {
    switch (this) {
      case ProgramLevel.bac2:
        return 'Bac+2';
      case ProgramLevel.bachelor:
        return 'Bachelor';
      case ProgramLevel.bba:
        return 'BBA';
      case ProgramLevel.master:
        return 'Master';
      case ProgramLevel.mba:
        return 'MBA / DBA';
      case ProgramLevel.doctorat:
        return 'Doctorat';
      case ProgramLevel.college:
        return 'Diplôme collégial';
      case ProgramLevel.gradCert:
        return 'Graduate certificate';
      case ProgramLevel.other:
        return 'Autre';
    }
  }

  /// Coarse filter family used by the catalogue filters.
  String get filterKey {
    switch (this) {
      case ProgramLevel.bac2:
      case ProgramLevel.bachelor:
      case ProgramLevel.bba:
        return 'bachelor';
      case ProgramLevel.master:
        return 'master';
      case ProgramLevel.mba:
        return 'mba';
      case ProgramLevel.doctorat:
        return 'doctorate';
      case ProgramLevel.college:
      case ProgramLevel.gradCert:
        return 'college';
      case ProgramLevel.other:
        return 'other';
    }
  }
}

/// Normalise a raw program/degree level string (e.g. "Bac+5", "MSc · Bac+5",
/// "PGE", "Grande Ecole", "BBA", "Bac+3 / Bac+5") to a [ProgramLevel].
/// When a string spans several levels (e.g. "Bac+3 / Bac+5") the HIGHEST is
/// returned so filters surface it under the more advanced bucket.
ProgramLevel normalizeProgramLevel(String? raw) {
  final s = _slug(raw ?? '');
  if (s.isEmpty) return ProgramLevel.other;

  // Highest-first so "bac+3 / bac+5" resolves to master.
  if (s.contains('doctorat') ||
      s.contains('phd') ||
      s.contains('dba') ||
      s.contains('bac8') ||
      s.contains('bac+8')) {
    // DBA is a doctorate-level MBA; keep it under MBA only if no plain doctorate.
    if (s.contains('dba') && !s.contains('doctorat') && !s.contains('phd')) {
      return ProgramLevel.mba;
    }
    return ProgramLevel.doctorat;
  }
  if (s.contains('mba')) return ProgramLevel.mba;
  // Avant « master » : un intitulé de collège ne contient aucun de ses jetons,
  // mais « certificat postdiplôme » doit rester un certificat, pas un master.
  if (s.contains('graduatecertificate') ||
      s.contains('certificatpostdiplome')) {
    return ProgramLevel.gradCert;
  }
  if (s.contains('diplomecollegial') ||
      s.contains('advanceddiploma') ||
      s.contains('ontariocollegediploma') ||
      s.contains('collegediploma')) {
    return ProgramLevel.college;
  }
  if (s.contains('bac5') ||
      s.contains('bac+5') ||
      s.contains('master') ||
      s.contains('msc') ||
      s.contains('pge') ||
      s.contains('grandeecole') ||
      s.contains('grande ecole') ||
      s.contains('mastere') ||
      s.contains('m2') ||
      s.contains('m1')) {
    return ProgramLevel.master;
  }
  if (s.contains('bba') || s.contains('bac4') || s.contains('bac+4')) {
    return ProgramLevel.bba;
  }
  if (s.contains('bac3') ||
      s.contains('bac+3') ||
      s.contains('bachelor') ||
      s.contains('licence')) {
    return ProgramLevel.bachelor;
  }
  if (s.contains('bac2') ||
      s.contains('bac+2') ||
      s.contains('bts') ||
      s.contains('dut')) {
    return ProgramLevel.bac2;
  }
  return ProgramLevel.other;
}

/// Clean a raw program level for display. Falls back to the original (trimmed)
/// string when nothing matches, so bespoke labels survive.
String programLevelLabel(String? raw) {
  final level = normalizeProgramLevel(raw);
  if (level != ProgramLevel.other) return level.labelFr;
  final original = (raw ?? '').trim();
  return original.isEmpty ? ProgramLevel.other.labelFr : original;
}

/// Lowercase, fold accents, and strip every non-alphanumeric character so that
/// spacing/punctuation variants collapse: "L1 / Bachelor 1", "Bac+5",
/// "MSc · Bac+5", "licence 2" all become comparable tokens. This is what lets
/// `contains('bac5')` / `contains('licence2')` match regardless of separators.
String _slug(String input) {
  var s = input.toLowerCase().trim();
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'û': 'u',
    'ù': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  accents.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Niveau d'études CANONIQUE d'une bourse (axe 3), indépendant de la locale.
///
/// Même vocabulaire que le serveur (`CanonicalStudyLevel`,
/// backend/src/modules/scholarships-index/scholarship-level.ts) : c'est ce que
/// le catalogue vérifié et le moteur « Mes 10 bourses » comparent.
enum ScholarshipStudyLevel { secondary, bachelor, master, doctorate }

/// Synonymes FR et EN de chaque niveau, cherchés comme MOTS dans un texte en
/// minuscules et sans accents. Copie conforme de `LEVEL_PATTERNS` côté serveur,
/// pièges compris : « Mastercard » n'est pas un master, « post-secondaire »
/// n'est pas le lycée, « pas de doctorat » n'est pas un doctorat.
final List<(ScholarshipStudyLevel, RegExp)> _scholarshipLevelPatterns = [
  (
    ScholarshipStudyLevel.secondary,
    RegExp(
      r'(?<!post[\s-])\b(?:secondary|secondaires?|lycees?|high[\s-]?schools?)\b',
    ),
  ),
  (
    ScholarshipStudyLevel.bachelor,
    RegExp(r'\b(?:bachelors?|bacheliers?|licences?|undergraduates?)\b'),
  ),
  (
    ScholarshipStudyLevel.master,
    RegExp(r'\b(?:masters?|masteres?|msc|mba|mim)\b'),
  ),
  (
    ScholarshipStudyLevel.doctorate,
    RegExp(
      r'(?<!\b(?:no|not|pas de|sans|hors|excluding|except)\s)(?<!post[\s-])'
      r'\b(?:doctorats?|doctorates?|doctoral|ph\.?\s?d|dphil)\b',
    ),
  ),
];

/// Niveaux canoniques cités dans un texte libre : le libellé `levelEligible`
/// d'une bourse, ou le niveau visé d'un profil (`Bachelor`, `Master`, `PhD`).
/// Vide quand rien n'est reconnu — et un ensemble vide veut dire « inconnu »,
/// jamais « aucun niveau » : l'appelant ne doit pas exclure sur un vide.
Set<ScholarshipStudyLevel> scholarshipStudyLevelsInText(String? text) {
  final levels = <ScholarshipStudyLevel>{};
  if (text == null || text.trim().isEmpty) return levels;
  final folded = _foldAccents(text.toLowerCase());
  for (final (level, pattern) in _scholarshipLevelPatterns) {
    if (pattern.hasMatch(folded)) levels.add(level);
  }
  return levels;
}

/// Minuscules déjà faites par l'appelant ; retire seulement les accents, sans
/// toucher aux espaces ni à la ponctuation (les motifs cherchent des MOTS).
String _foldAccents(String input) {
  const accents = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final index = accents.indexOf(char);
    buffer.write(index == -1 ? char : plain[index]);
  }
  return buffer.toString();
}
