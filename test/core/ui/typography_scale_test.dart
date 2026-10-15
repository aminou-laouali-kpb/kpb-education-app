// Échelle typographique : sept tailles, de 12 à 28 sp ; les titres en
// Plus Jakarta Sans (police déjà embarquée, aucun téléchargement).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';

void main() {
  test('sept tailles strictement croissantes, de 12 à 28', () {
    const scale = KpbFontSize.scale;
    expect(scale, hasLength(7));
    expect(scale.first, 12);
    expect(scale.last, 28);
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]));
    }
  });

  final styles = <String, TextStyle>{
    'display': KpbTextStyles.display,
    'displaySm': KpbTextStyles.displaySm,
    'displayXs': KpbTextStyles.displayXs,
    'headlineLg': KpbTextStyles.headlineLg,
    'headline': KpbTextStyles.headline,
    'headlineSm': KpbTextStyles.headlineSm,
    'titleLg': KpbTextStyles.titleLg,
    'title': KpbTextStyles.title,
    'titleMd': KpbTextStyles.titleMd,
    'titleSm': KpbTextStyles.titleSm,
    'body': KpbTextStyles.body,
    'bodySm': KpbTextStyles.bodySm,
    'label': KpbTextStyles.label,
    'labelSm': KpbTextStyles.labelSm,
    'caption': KpbTextStyles.caption,
  };

  test('chaque style de KpbTextStyles est sur l\'échelle', () {
    styles.forEach((name, style) {
      expect(KpbFontSize.scale, contains(style.fontSize), reason: name);
    });
  });

  test('les titres (≥ 18 sp) sont en Plus Jakarta Sans', () {
    styles.forEach((name, style) {
      if (style.fontSize! >= KpbFontSize.lg) {
        expect(style.fontFamily, KpbTextStyles.headingFamily, reason: name);
      }
    });
  });

  test('le TextTheme Material suit l\'échelle', () {
    final t = AppTheme.buildTheme().textTheme;
    for (final style in [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
    ]) {
      expect(KpbFontSize.scale, contains(style!.fontSize));
    }
  });
}
