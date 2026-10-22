// Le règlement de la compétition des ambassadeurs est PUBLIÉ (audit 57, F20) :
// `web/public/reglement-ambassadeurs-2026-11.html`, dont l'URL est le
// `rulesUrl` de la campagne — seul lien que la page du classement et l'écran
// « Compétition » ouvrent (`rulesText` reste interne, jamais servi).
//
// La page reprend le texte arrêté (`docs/reglement-competition-ambassadeurs-
// novembre-2026.md`) SANS en changer le fond : chaque paragraphe, chaque
// puce et chaque ligne du tableau des prix du document doit s'y retrouver mot
// pour mot, une fois retirées les seules mentions de décision internes
// (« (décision du propriétaire…) »). Une modification d'un côté sans l'autre
// rougit ici.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pagePath = 'web/public/reglement-ambassadeurs-2026-11.html';
const _docPath = 'docs/reglement-competition-ambassadeurs-novembre-2026.md';
const _publicUrl =
    'https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html';

String _read(String path) => File(path).readAsStringSync();

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Le texte visible de la page : sans commentaires ni balises.
String _visibleText(String html) {
  final body = html.substring(html.indexOf('<main>'), html.indexOf('</main>'));
  final noComments = body.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final cells = noComments.replaceAll(RegExp(r'</t[dh]>'), ' ');
  return _collapse(cells.replaceAll(RegExp(r'<[^>]+>'), ''));
}

/// Les blocs du règlement (titres, paragraphes, puces, lignes de tableau),
/// à partir de « ## 1. Organisateur », en texte brut.
List<String> _docBlocks(String md) {
  final body = md.substring(md.indexOf('## 1. Organisateur'));
  final blocks = <String>[];
  var current = StringBuffer();
  void flush() {
    final text = current.toString().trim();
    if (text.isNotEmpty) blocks.add(text);
    current = StringBuffer();
  }

  for (final line in body.split('\n')) {
    final starts = line.startsWith('#') ||
        line.startsWith('- ') ||
        line.startsWith('|') ||
        RegExp(r'^\d+\. ').hasMatch(line);
    if (line.trim().isEmpty || starts) flush();
    if (line.trim().isEmpty) continue;
    if (line.startsWith('|')) {
      if (RegExp(r'^\|[-| ]+\|$').hasMatch(line)) continue;
      blocks.add(line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .join(' '));
      continue;
    }
    current.write(' $line');
    if (line.startsWith('#')) flush();
  }
  flush();
  return blocks.map((b) {
    var text = b.trim();
    if (text.startsWith('#')) {
      text = text.replaceFirst(RegExp(r'^#+ '), '');
    } else {
      text = text.replaceFirst(RegExp(r'^(- |\d+\. )'), '');
    }
    text = text
        .replaceAll('**', '')
        .replaceAll('`', '')
        // Seules mentions retirées de la page : la trace interne des décisions.
        .replaceAll(
          RegExp(
            r'\s*\((?:décision du propriétaire|durée validée par le '
            r'propriétaire)[^)]*\)',
          ),
          '',
        );
    return _collapse(text);
  }).toList();
}

void main() {
  final page = _read(_pagePath);
  final doc = _read(_docPath);
  final visible = _visibleText(page);

  test('chaque bloc du règlement arrêté figure tel quel sur la page', () {
    final blocks = _docBlocks(doc);
    expect(blocks.length, greaterThan(40), reason: 'découpage cassé');
    final missing = blocks.where((b) => !visible.contains(b)).toList();
    expect(
      missing,
      isEmpty,
      reason: 'la page publiée ne dit pas (mot pour mot) :\n'
          '${missing.join('\n')}',
    );
  });

  test('aucune note interne ni instruction à l\'équipe n\'est publiée', () {
    for (final internal in [
      'à relire',
      'propriétaire',
      'Règlement (texte)',
      'rulesText',
      'rulesUrl',
      'collé dans la campagne',
    ]) {
      expect(
        visible.contains(internal),
        isFalse,
        reason: 'la page publiée contient « $internal »',
      );
    }
  });

  test('même gabarit que les CGU : en-tête, pied, éditeur, liens', () {
    final conditions = _read('web/public/conditions.html');
    const header =
        '<header><div class="wrap"><a class="brand" href="/">KPB <span>Education</span></a></div></header>';
    expect(conditions, contains(header));
    expect(page, contains(header));
    expect(page, contains('<link rel="stylesheet" href="/styles.css">'));
    expect(page, contains('<html lang="fr">'));
    for (final link in [
      '<a href="/confidentialite.html">Confidentialité</a>',
      '<a href="/conditions.html">CGU</a>',
      '<a href="/suppression-compte.html">Suppression de compte</a>',
    ]) {
      expect(conditions, contains(link));
      expect(page, contains(link));
    }
    // Mentions de l'éditeur, comme le §12 des CGU.
    for (final fact in [
      'KPB Global L.L.C-FZ',
      '2537631.01',
      'Nad Al Sheba',
      'contact@kpbeducation.com',
    ]) {
      expect(visible, contains(fact));
    }
    expect(page, contains('href="/classement/"'));
    expect(page, contains('href="/conditions.html"'));
    expect(page, contains('href="/confidentialite.html"'));
  });

  test('nginx la sert et la CSP la laisse s\'afficher', () {
    final nginx = _read('web/nginx.conf');
    expect(nginx, contains(r'try_files $uri $uri/ =404;'));
    expect(nginx, contains("style-src 'self'"));
    expect(nginx, contains("default-src 'self'"));
    // CSP : ni style ni script en ligne, aucune ressource d'un autre hôte.
    expect(RegExp(r'\sstyle=').hasMatch(page), isFalse);
    expect(page.contains('<script'), isFalse);
    expect(page.contains('<style'), isFalse);
    expect(
      RegExp(r'''(?:src|href)="https?://''').hasMatch(page),
      isFalse,
      reason: 'ressource ou lien absolu : la page reste sur son origine',
    );
    // Le tableau des prix a son style dans la feuille commune.
    expect(page, contains('class="rules-table"'));
    expect(_read('web/public/styles.css'), contains('.rules-table'));
  });

  test('les CGU et les procédures renvoient au lien publié, pas au texte', () {
    expect(
      _read('web/public/conditions.html'),
      contains('<a href="/reglement-ambassadeurs-2026-11.html">'),
    );
    // En-tête du règlement : le lien est le seul publié, le texte est interne.
    final header = doc.substring(0, doc.indexOf('## 1. Organisateur'));
    final flatHeader = _collapse(header.replaceAll('>', ''));
    expect(flatHeader, contains(_publicUrl));
    expect(flatHeader, contains('**Ce lien est le seul publié**'));
    expect(flatHeader, isNot(contains('collé dans la campagne')));
    // Runbook §2 : poser `rulesUrl`, plus jamais « ou son texte ».
    final runbook = _read('docs/runbook-campagne-ambassadeurs.md');
    final step2 = runbook.substring(
      runbook.indexOf('## 2. Créer la campagne'),
      runbook.indexOf('## 3.'),
    );
    expect(_collapse(step2), contains('`rulesUrl` = `$_publicUrl`'));
    expect(step2, isNot(contains('ou son texte')));
    expect(_collapse(step2), contains('**refuse de lancer**'));
    // La console préremplit ce lien et dit que le texte est interne.
    expect(
      _read('admin/lib/referral-campaigns.ts'),
      contains("NOVEMBER_2026_RULES_URL = '$_publicUrl'"),
    );
    expect(
        _read('admin/messages/fr.json'), contains('Usage interne, non publié'));
  });
}
