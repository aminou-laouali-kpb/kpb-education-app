import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/study_level.dart';

void main() {
  group('normalizeStudentLevel (year axis)', () {
    test('maps terse codes to clean years', () {
      expect(normalizeStudentLevel('L1'), StudentLevel.bachelor1);
      expect(normalizeStudentLevel('B1'), StudentLevel.bachelor1);
      expect(normalizeStudentLevel('L3'), StudentLevel.bachelor3);
      expect(normalizeStudentLevel('M1'), StudentLevel.master1);
      expect(normalizeStudentLevel('M2'), StudentLevel.master2);
      expect(normalizeStudentLevel('Terminale'), StudentLevel.terminale);
      expect(normalizeStudentLevel('Doctorat'), StudentLevel.doctorat);
    });

    test('maps legacy onboarding labels', () {
      expect(normalizeStudentLevel('L1 / Bachelor 1'), StudentLevel.bachelor1);
      expect(normalizeStudentLevel('L3 / Bachelor 3'), StudentLevel.bachelor3);
    });

    test('maps the onboarding "High school" token to Terminale', () {
      expect(normalizeStudentLevel('High school'), StudentLevel.terminale);
    });

    test('is accent/case insensitive', () {
      expect(normalizeStudentLevel('licence 2'), StudentLevel.bachelor2);
      expect(normalizeStudentLevel('  MASTER 1  '), StudentLevel.master1);
    });

    test('returns null for junk', () {
      expect(normalizeStudentLevel(null), isNull);
      expect(normalizeStudentLevel(''), isNull);
      expect(normalizeStudentLevel('???'), isNull);
    });
  });

  group('studentLevelLabel display', () {
    test('produces clean labels, never terse codes', () {
      expect(studentLevelLabel('L1'), 'Bachelor 1');
      expect(studentLevelLabel('M2'), 'Master 2');
      expect(studentLevelLabel('Terminale'), 'Terminale');
    });

    test('falls back to the original when unknown', () {
      expect(studentLevelLabel('Prépa intégrée'), 'Prépa intégrée');
    });
  });

  group('studentLevelLabels list', () {
    test('exposes 7 clean labels in order', () {
      expect(studentLevelLabels, [
        'Terminale',
        'Bachelor 1',
        'Bachelor 2',
        'Bachelor 3',
        'Master 1',
        'Master 2',
        'Doctorat',
      ]);
    });
  });

  group('needsBacSeries', () {
    test('only Terminale and Bachelor 1', () {
      expect(StudentLevel.terminale.needsBacSeries, isTrue);
      expect(StudentLevel.bachelor1.needsBacSeries, isTrue);
      expect(StudentLevel.bachelor2.needsBacSeries, isFalse);
      expect(StudentLevel.master1.needsBacSeries, isFalse);
    });
  });

  group('normalizeProgramLevel (degree axis)', () {
    test('maps OMNES families to clean degrees', () {
      expect(normalizeProgramLevel('Bachelor · Bac+3'), ProgramLevel.bachelor);
      expect(normalizeProgramLevel('MSc · Bac+5'), ProgramLevel.master);
      expect(normalizeProgramLevel('PGE · Bac+5'), ProgramLevel.master);
      expect(
          normalizeProgramLevel('Grande Ecole · Bac+5'), ProgramLevel.master);
      expect(normalizeProgramLevel('BBA · Bac+4'), ProgramLevel.bba);
      expect(
          normalizeProgramLevel('Visa (Bac +5) · Bac+5'), ProgramLevel.master);
    });

    test('maps mock catalog tokens', () {
      expect(normalizeProgramLevel('Bac+3'), ProgramLevel.bachelor);
      expect(normalizeProgramLevel('Bac+5'), ProgramLevel.master);
      expect(normalizeProgramLevel('MBA'), ProgramLevel.mba);
      expect(normalizeProgramLevel('Doctorat'), ProgramLevel.doctorat);
      expect(normalizeProgramLevel('DBA'), ProgramLevel.mba);
    });

    test('multi-level string resolves to the highest', () {
      expect(normalizeProgramLevel('Bac+3 / Bac+5'), ProgramLevel.master);
    });

    test('unknown → other', () {
      expect(normalizeProgramLevel('Certificat'), ProgramLevel.other);
      expect(normalizeProgramLevel(''), ProgramLevel.other);
    });
  });

  group('programLevelLabel display + filterKey', () {
    test('clean degree labels', () {
      expect(programLevelLabel('MSc · Bac+5'), 'Master');
      expect(programLevelLabel('Bac+3'), 'Bachelor');
      expect(programLevelLabel('BBA · Bac+4'), 'BBA');
    });

    test('keeps bespoke labels when unknown', () {
      expect(programLevelLabel('Summer School'), 'Summer School');
    });

    test('filter families', () {
      expect(ProgramLevel.bachelor.filterKey, 'bachelor');
      expect(ProgramLevel.bba.filterKey, 'bachelor');
      expect(ProgramLevel.master.filterKey, 'master');
      expect(ProgramLevel.mba.filterKey, 'mba');
      expect(ProgramLevel.doctorat.filterKey, 'doctorate');
      expect(ProgramLevel.college.filterKey, 'college');
      expect(ProgramLevel.gradCert.filterKey, 'college');
    });

    test('collèges canadiens : diplôme collégial et certificat postdiplôme',
        () {
      expect(normalizeProgramLevel('Diplôme collégial'), ProgramLevel.college);
      expect(normalizeProgramLevel('Advanced Diploma'), ProgramLevel.college);
      expect(
          normalizeProgramLevel('Graduate certificate'), ProgramLevel.gradCert);
      expect(normalizeProgramLevel('Certificat postdiplôme'),
          ProgramLevel.gradCert);
      expect(programLevelLabel('Diplôme collégial'), 'Diplôme collégial');
      expect(programLevelLabel('Graduate certificate'), 'Graduate certificate');
      // Les niveaux existants ne bougent pas.
      expect(normalizeProgramLevel('Bachelor · Bac+3'), ProgramLevel.bachelor);
      expect(normalizeProgramLevel('MSc · Bac+5'), ProgramLevel.master);
    });
  });
}
