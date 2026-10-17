// Garde PRIV-T4 : les destinataires et permissions que le code utilise
// doivent être NOMMÉS dans la politique in-app et sur la page web.
//
// Dérivé du dépôt suivi par git (patron no_hardcoded_french_test.dart),
// pas d'un souvenir. Deux familles :
//
//   (A) hôtes https:// dans lib/ + backend/src (hors *.spec.*)
//   (B) permissions AndroidManifest + clés NS*UsageDescription d'Info.plist
//
// Chaque processeur de (A) et chaque jeton de (B) doit apparaître dans
// legal_pages.dart ET confidentialite.html. Un hôte tiers qui n'est ni
// first-party, ni processeur mappé, ni contenu/catalogue connu, fait
// échouer avec « hôte tiers non mappé » — c'est la mutation n°2.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _hostPattern = RegExp(r'https?://([A-Za-z0-9.-]+)');

const _firstPartySuffixes = <String>[
  'kpbeducation.cloud',
  'kpbeducation.com',
  'vps-planethoster.com',
  'localhost',
  'localhost.',
  '127.0.0.1',
  'example.org',
  'example.test',
  'student.example',
  'invalid.test',
];

/// Hôte → jeton qui doit figurer dans les deux politiques.
const _processorSuffixToToken = <String, String>{
  // Provider IA primaire depuis le 25/08/2026 (deepseek-v4-flash), routage
  // épinglé zdr + data_collection=deny côté backend ; Groq reste le repli
  // legacy tant que le chemin GROQ_* existe dans llm.service.ts.
  'openrouter.ai': 'OpenRouter',
  'groq.com': 'Groq',
  'onesignal.com': 'OneSignal',
  'posthog.com': 'PostHog',
  'supabase.co': 'Supabase',
  'resend.com': 'Resend',
  'firebaseio.com': 'Firebase',
  // Le push part par FCM en direct depuis le backend : titre, corps et jeton
  // d'appareil. Plus précis que `googleapis.com` (non-processeur, ci-dessous),
  // il est donc vérifié EN PREMIER — sinon le suffixe générique l'avalait.
  'fcm.googleapis.com': 'Cloud Messaging',
  'paydunya.com': 'PayDunya',
  'cinetpay.com': 'CinetPay',
  // YouTube a longtemps vécu dans la liste des NON-processeurs, et c'est
  // précisément ce classement qui a autorisé l'omission du lecteur embarqué
  // dans les deux politiques : le lecteur (youtube-nocookie.com) et les
  // vignettes (img.youtube.com, rendues dès l'accueil, connexion ou pas)
  // envoient l'adresse IP et le user-agent de l'étudiant à Google à chaque
  // affichage. Un destinataire de données techniques est un destinataire :
  // il se nomme.
  'youtube.com': 'YouTube',
  'youtu.be': 'YouTube',
  // Même nature que les vignettes YouTube : `Image.network` charge le logo
  // d'un établissement depuis upload.wikimedia.org dès l'ouverture de la
  // fiche. Wikimedia Foundation reçoit l'adresse IP et le user-agent.
  'wikimedia.org': 'Wikimedia',
};

/// Sites que le code cite sans leur envoyer les données personnelles de
/// l'étudiant (catalogue, scrapers, WebView, stores, médias).
const _nonProcessorSuffixes = <String>[
  'googleapis.com',
  'unsplash.com',
  'wa.me',
  'whatsapp.com',
  'kayak.fr',
  'kayak.com',
  'studapart.com',
  'apple.com',
  'play.google.com',
  'google.com',
  'ashesi.edu.gh',
  'stanford.edu',
  'mccallmacbainscholars.org',
  'stipendiumhungaricum.hu',
  'uwc.org',
  'univ-poitiers.fr',
  'education-in-russia.com',
  'state.gov',
  'sjtu.edu.cn',
  'europa.eu',
  'ethz.ch',
  'fulbrightonline.org',
  'utoronto.ca',
  'yorku.ca',
  'greatyop.com',
  'alueducation.com',
  'blogspot.com',
  'mastercardfdn.org',
  // Gates Cambridge et Carnegie Mellon University Africa : fiches du
  // catalogue ajoutées le 07/10/2026. Leurs pages officielles sont des
  // SOURCES que l'étudiant ouvre, jamais des destinataires de ses données.
  'gatescambridge.org',
  'cmu.edu',
  'yok.gov.tr',
  'dfat.gov.au',
  // Le site officiel du programme Australia Awards Africa : la fiche du
  // catalogue pointait un PDF DFAT devenu injoignable, re-pointé le 24/08/2026
  // vers la page réellement consultée. Même nature que dfat.gov.au — un lien
  // que l'étudiant OUVRE, jamais un destinataire de ses données.
  'australiaawardsafrica.org',
  'globaluni.ru',
  'gov.kz',
  'campusfrance.org',
  'studyinromania.gov.ro',
  'si.se',
  'daad.de',
  'studyin.kz',
  'studyinazerbaijan.edu.az',
  'turkiyeburslari.gov.tr',
  'worldbank.org',
  'u.ae',
  'uct.ac.za',
  'amci.ma',
  // Université Mundiapolis : le catalogue cite ses pages de formation comme
  // SOURCE d'un niveau de diplôme (`Program.sourceUrl`). Un lien que l'équipe
  // et l'étudiant ouvrent pour vérifier une fiche, jamais un destinataire de
  // données personnelles.
  'mundiapolis.ma',
  // Universiapolis et ses écoles : le catalogue cite leurs pages comme SOURCE
  // d'un niveau de diplôme (`Program.sourceUrl`). Des liens qu'on ouvre pour
  // vérifier une fiche, jamais des destinataires de données personnelles.
  'universiapolis.ma',
  'e-polytechnique.ma',
  'suphcom.ma',
  'suphdroit.ma',
  // ESSEC et l'Université d'Ottawa : le catalogue cite leur site officiel
  // comme SOURCE de la description d'établissement (`Institution.sourceUrl`).
  // Même nature que les deux précédents — un lien que l'étudiant OUVRE pour
  // vérifier une fiche, jamais un destinataire de ses données.
  'essec.edu',
  'uottawa.ca',
  // Écoles du groupe IGENSIA Education (chantier E/J) : le catalogue cite
  // leur page de candidature en ligne (`websiteUrl`, `sourceUrl`). Des liens
  // que l'étudiant OUVRE, jamais des destinataires de ses données.
  'igensia-school-of-business.fr',
  'igensiatech.fr',
  'igensia-rh.com',
  // American Business College (groupe IGENSIA) : page de programme et de
  // candidature citée comme SOURCE ; France Compétences : fiche RNCP citée
  // comme source de la reconnaissance d'un diplôme. Des liens que l'étudiant
  // OUVRE, jamais des destinataires de ses données.
  'american-business-college-paris.com',
  'francecompetences.fr',
  // Portails de l'État français dont vient le catalogue « Études en France ».
  // data.enseignementsup-recherche.gouv.fr publie les jeux ouverts que la
  // collecte interroge — depuis un poste d'exploitation, jamais depuis
  // l'application — et que chaque fiche cite ensuite comme SOURCE vérifiable
  // (`Program.sourceUrl`, filtrée sur la ligne exacte). monmaster.gouv.fr est
  // le lien de dernier recours vers la fiche d'un master quand
  // l'établissement n'en publie pas.
  //
  // Même nature que mundiapolis.ma ou essec.edu ci-dessus : des liens qu'on
  // OUVRE pour vérifier une fiche. Ni l'un ni l'autre ne reçoit la moindre
  // donnée d'un étudiant — l'app ne les appelle jamais.
  'enseignementsup-recherche.gouv.fr',
  'monmaster.gouv.fr',
  // Liens OFFICIELS que `/config/app` fait afficher à l'étudiant (XC-05) : la
  // page de l'ambassade qui justifie une suspension de pays, et la licence qui
  // régit le catalogue (CAT-M03). Ce sont des adresses que l'étudiant OUVRE pour
  // vérifier ce que l'app affirme — l'app ne les appelle jamais, aucune donnée
  // d'étudiant ne leur est envoyée. Elles vivent côté serveur (servies, pas
  // compilées), mais le test lit aussi `backend/src`.
  'diplomatie.gouv.fr',
  'etalab.gouv.fr',
  'aucegypt.edu',
  'auf.org',
  'campuschina.org',
  'chevening.org',
  'funding-guide.de',
  'educanada.ca',
  'gov.uk',
  'icdf.org.tw',
  'mastere.tn',
  'mes.tn',
  'mesrs.dz',
  'mfa.gov.bn',
  'ote.nat.tn',
  'qu.edu.qa',
  'rhodeshouse.ox.ac.uk',
  'schwarzmanscholars.org',
  'studyinjapan.go.jp',
  'studyinspain.info',
  'up.ac.za',
];

const _permissionToToken = <String, String>{
  'android.permission.INTERNET': 'HTTPS',
  'android.permission.ACCESS_NETWORK_STATE': 'HTTPS',
  'android.permission.POST_NOTIFICATIONS': 'notifications',
  'android.permission.USE_BIOMETRIC': 'biométrie',
  'android.permission.RECORD_AUDIO': 'micro',
  'NSFaceIDUsageDescription': 'biométrie',
  'NSCameraUsageDescription': 'caméra',
  'NSPhotoLibraryUsageDescription': 'photo',
  'NSMicrophoneUsageDescription': 'micro',
  // « micro » ne suffit pas pour celle-ci : la permission couvre la
  // reconnaissance VOCALE, et une politique qui parle du micro sans dire que
  // la voix peut être reconnue (et par qui) ne dit pas ce que l'OS demande.
  'NSSpeechRecognitionUsageDescription': 'reconnaissance',
  'NSLocationWhenInUseUsageDescription': 'localisation',
};

String _legalPages() =>
    File('lib/app/features/legal/legal_pages.dart').readAsStringSync();

String _confidentialite() =>
    File('web/public/confidentialite.html').readAsStringSync();

String _translations() => [
      'lib/app/core/translations/app_translations_fr.dart',
      'lib/app/core/translations/app_translations_en.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

bool _matchesSuffix(String host, String suffix) {
  return host == suffix || host.endsWith('.$suffix');
}

String? _processorToken(String host) {
  for (final entry in _processorSuffixToToken.entries) {
    if (_matchesSuffix(host, entry.key)) return entry.value;
  }
  return null;
}

bool _isFirstParty(String host) =>
    _firstPartySuffixes.any((s) => _matchesSuffix(host, s));

bool _isNonProcessor(String host) =>
    _nonProcessorSuffixes.any((s) => _matchesSuffix(host, s));

Iterable<File> _codeFiles() sync* {
  for (final root in ['lib', 'backend/src']) {
    yield* Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
      final path = f.path;
      if (path.endsWith('.spec.ts') ||
          path.endsWith('.spec.dart') ||
          path.endsWith('_test.dart')) {
        return false;
      }
      return path.endsWith('.dart') ||
          path.endsWith('.ts') ||
          path.endsWith('.js');
    });
  }
}

Map<String, String> _hostsByFile() {
  final found = <String, String>{};
  for (final file in _codeFiles()) {
    final text = file.readAsStringSync();
    for (final match in _hostPattern.allMatches(text)) {
      final host = match.group(1)!.toLowerCase();
      found.putIfAbsent(host, () => file.path);
    }
  }
  return found;
}

void main() {
  test('chaque hôte processeur est nommé dans legal_pages ET confidentialite',
      () {
    final hosts = _hostsByFile();
    expect(hosts.length, greaterThan(20),
        reason: 'L\'extraction ne lit plus les sources : garde morte.');

    final unmapped = <String>[];
    final missing = <String>[];
    final inApp = '${_legalPages()}\n${_translations()}';
    final web = _confidentialite();

    hosts.forEach((host, file) {
      // Le processeur d'abord : un hôte précis (`fcm.googleapis.com`) ne doit
      // pas être blanchi par un suffixe générique de la liste des
      // non-processeurs (`googleapis.com`).
      final token = _processorToken(host);
      if (token == null && (_isFirstParty(host) || _isNonProcessor(host))) {
        return;
      }
      if (token == null) {
        unmapped.add('$host  (dans $file)');
        return;
      }
      final inLegal = inApp.contains(token);
      final inWeb = web.toLowerCase().contains(token.toLowerCase());
      if (!inLegal) {
        missing
            .add('$token — absent de legal_pages.dart / app_translations.dart '
                '(hôte $host)');
      }
      if (!inWeb) {
        missing.add('$token — absent de confidentialite.html (hôte $host)');
      }
    });

    expect(
      unmapped,
      isEmpty,
      reason: 'Hôte tiers non mappé — ajoute-le comme processeur (et nomme-le '
          'dans les deux politiques) ou comme contenu/catalogue :\n'
          '${unmapped.join('\n')}',
    );
    expect(
      missing,
      isEmpty,
      reason: 'Divulgation manquante :\n${missing.join('\n')}',
    );
  });

  test('chaque permission OS est nommée dans legal_pages ET confidentialite',
      () {
    // Le manifeste est lu SANS SES COMMENTAIRES. Un commentaire n'est pas une
    // permission déclarée, et depuis que le manifeste documente pourquoi il
    // LAISSE `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` au fusionneur,
    // le scan brut prenait cette explication pour une demande de permission et
    // exigeait qu'elle soit divulguée dans les politiques. C'est le symétrique
    // exact du défaut corrigé dans test/release/android_manifest_test.dart, où
    // la garde se déclenchait sur `QUERY_ALL_PACKAGES` écrit dans son propre
    // commentaire d'interdiction. Une garde qui lit les commentaires mesure la
    // prose, pas la configuration.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final inApp = '${_legalPages()}\n${_translations()}';
    final web = _confidentialite();

    final permissions = <String>[
      ...RegExp(r'android.permission.[A-Z_]+')
          .allMatches(manifest)
          .map((m) => m.group(0)!),
      ...RegExp(r'<key>(NS\w+UsageDescription)</key>')
          .allMatches(plist)
          .map((m) => m.group(1)!),
    ];
    expect(permissions, isNotEmpty,
        reason: 'Aucune permission extraite — garde morte.');

    final missing = <String>[];
    for (final perm in permissions.toSet()) {
      final token = _permissionToToken[perm];
      if (token == null) {
        missing.add('$perm — permission non mappée');
        continue;
      }
      if (!inApp.contains(token)) {
        missing.add('$token — absent de legal_pages.dart (permission $perm)');
      }
      if (!web.contains(token)) {
        missing
            .add('$token — absent de confidentialite.html (permission $perm)');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('plus de www.kpbeducation.com ni de conservation « 3 ans »', () {
    final corpus =
        '${_legalPages()}\n${_confidentialite()}\n${_translations()}';
    expect(corpus.contains('www.kpbeducation.com'), isFalse);
    expect(corpus.contains('3 ans après la clôture'), isFalse);
  });
}
