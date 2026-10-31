// `textFaint` sur fond clair — interdit PAR CALCUL, plus seulement par
// commentaire.
//
// Le token s'interdit lui-même : « 2,56:1 sur blanc : JAMAIS pour un texte
// porteur de sens » (app_tokens.dart). Deux surfaces l'utilisaient quand même
// sur fond clair, et pas n'importe lesquelles :
//
//   · auth_welcome_screen — la note « KPB Intelligence » du PREMIER écran de
//     l'app, 13 px, dans un FittedBox qui la rétrécit encore ;
//   · case_detail_screen — la RÉFÉRENCE DU DOSSIER (11,5 px), la chaîne même
//     que l'étudiant lit à son conseiller sur WhatsApp.
//
// Deux gardes :
//   (1) un CLIQUET par fichier sur les occurrences de `KpbColors.textFaint` —
//       les deux fichiers corrigés ne peuvent pas remonter ;
//   (2) l'ARITHMÉTIQUE du contraste — pour que le commentaire du token ne
//       puisse plus dériver de la réalité : si quelqu'un éclaircit textMuted
//       ou fonce le canvas, c'est le calcul qui rougit, pas un chiffre écrit
//       dans un commentaire.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/app_tokens.dart';

/// Luminance relative WCAG 2.x, puis ratio (L1+0.05)/(L2+0.05).
double contrastRatio(Color a, Color b) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color color) =>
      0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Budget d'occurrences de `KpbColors.textFaint` par fichier — UNIQUEMENT les
/// fichiers du correctif PARC-11. Les ~110 autres occurrences du dépôt vivent
/// majoritairement sur fond navy (6,96:1, largement AA) et ne sont pas le
/// sujet ; les budgéter toutes reviendrait à désarmer le cliquet sous le
/// volume.
const kTextFaintBudget = <String, int>{
  // La note KPB Intelligence est passée à textMuted : plus rien ici.
  'lib/app/features/auth/auth_welcome_screen.dart': 0,
  // La référence de dossier et son badge « provisoire » sont passés à
  // textMuted ; les 4 occurrences restantes sont sur les sous-arbres sombres
  // (timeline navy, carte étudiant) ou décoratives.
  // Écran découpé en parties : 1 dans l'écran, 3 dans le fil (timeline navy).
  'lib/app/features/cases/case_detail_screen.dart': 1,
  'lib/app/features/cases/case_detail_screen/thread.dart': 3,
  // Audit build 57, T7-19 : libellé de tuile et indication du champ passés à
  // textMuted ; ce qui reste est sur fond navy (6,96:1) ou décoratif.
  'lib/app/features/scholarships/scholarship_detail_screen.dart': 0,
  'lib/app/features/ai_advisor/ai_chat_screen.dart': 5,
  'lib/app/features/home/home_screen/cards.dart': 1,
};

void main() {
  group('(2) l\'arithmétique du contraste', () {
    test('textFaint sur canvas reste sous 3,0 — donc interdit pour du sens',
        () {
      final ratio = contrastRatio(KpbColors.textFaint, KpbColors.canvas);
      expect(
        ratio,
        lessThan(3.0),
        reason: 'textFaint atteint ${ratio.toStringAsFixed(2)}:1 sur canvas. '
            'S\'il passe 3,0, son commentaire « JAMAIS pour un texte porteur '
            'de sens » ne décrit plus le même token : mettez à jour le '
            'commentaire ET ce test ensemble.',
      );
    });

    test('textMuted sur canvas tient le seuil AA de 4,5', () {
      final ratio = contrastRatio(KpbColors.textMuted, KpbColors.canvas);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'textMuted ne tient plus AA (${ratio.toStringAsFixed(2)}:1 '
            'sur canvas) : c\'est le token de REMPLACEMENT du correctif '
            'PARC-11 — s\'il faiblit, le correctif ne corrige plus rien.',
      );
    });
  });

  // Audit build 57, T7-19 : le blanc sur le vert WhatsApp ne donne que 1,98:1.
  group('(3) texte sur le vert WhatsApp', () {
    test('le blanc est illisible, le bleu nuit tient AA', () {
      expect(contrastRatio(Colors.white, KpbColors.whatsapp), lessThan(3.0));
      expect(contrastRatio(KpbColors.brandNavy, KpbColors.whatsapp),
          greaterThanOrEqualTo(4.5));
    });

    test('aucun bouton plein WhatsApp ne porte de texte blanc', () {
      const files = [
        'lib/app/core/ui/components/verified_advisor_sheet.dart',
        'lib/app/features/ai_advisor/ai_chat_screen.dart',
        'lib/app/features/premium/premium_screen.dart',
        'lib/app/features/explore/program_detail_screen.dart',
      ];
      final offenders = <String>[];
      var found = 0;
      for (final path in files) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final isWhatsAppFill =
              lines[i].contains('backgroundColor: KpbColors.whatsapp') ||
                  lines[i].contains('bg: KpbColors.whatsapp');
          if (!isWhatsAppFill) continue;
          found++;
          final next =
              lines.sublist(i + 1, (i + 4).clamp(0, lines.length)).join('\n');
          if (next.contains('Colors.white,')) offenders.add('  $path:${i + 1}');
        }
      }
      // Tiroir : on a bien trouvé les quatre boutons.
      expect(found, 4);
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('(1) le cliquet par fichier', () {
    test('les occurrences de textFaint ne remontent pas', () {
      final over = <String>[];
      final freed = <String>[];
      kTextFaintBudget.forEach((path, budget) {
        final lines = File(path).readAsLinesSync();
        var count = 0;
        for (final line in lines) {
          if (line.trimLeft().startsWith('//')) continue;
          count += 'KpbColors.textFaint'.allMatches(line).length;
        }
        if (count > budget) {
          over.add('  $path : $count pour un budget de $budget');
        }
        if (count < budget) {
          freed.add('  $path : $count — abaissez le budget à $count');
        }
      });

      expect(
        over,
        isEmpty,
        reason: 'textFaint est revenu sur une surface corrigée. À 2,56:1 sur '
            'fond clair, il est illisible pour une bonne part du public — '
            'utilisez textMuted (4,76:1) pour tout texte porteur de sens.\n'
            '${over.join('\n')}',
      );
      // Cliquet descendant, même règle que screen_overflow_budget : un
      // progrès non verrouillé se perd.
      expect(freed, isEmpty,
          reason: 'Verrouillez le progrès :\n${freed.join('\n')}');
    });
  });
}
