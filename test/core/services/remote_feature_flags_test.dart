// RemoteFeatureFlags : il échoue FERMÉ, et il ne devine pas.
//
// C'est ce service qui permet d'ouvrir l'espace « Études en France » le jour de
// la campagne en basculant une variable d'environnement, sans soumission App
// Store. Deux propriétés le rendent utilisable pour ça, et elles sont éprouvées
// ici plutôt que déduites de la lecture.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';

class _MockApiClient extends Mock implements AppApiClient {}

void main() {
  late _MockApiClient api;

  setUp(() {
    api = _MockApiClient();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefHelpBubbleEnabledOverride = null;
    AppConfig.eefPrivateSchoolsEnabledOverride = null;
  });

  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefHelpBubbleEnabledOverride = null;
    AppConfig.eefPrivateSchoolsEnabledOverride = null;
  });

  final flags = RemoteFeatureFlags.instance;

  group('le repli, quand le serveur ne répond pas', () {
    // La propriété qui compte : un backend injoignable ne doit pas OUVRIR un
    // module. Montrer par défaut une vitrine qu'on ne saurait plus éteindre à
    // distance est un mauvais échec ; ne rien montrer est réparable.
    test('échoue fermé sur les constantes de compilation', () async {
      when(api.getAppConfig).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/config/app'),
        type: DioExceptionType.connectionError,
      ));

      await flags.refresh(api);

      expect(flags.loaded, isFalse);
      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isFalse);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });

    test('ne lève jamais vers l\'appelant', () async {
      when(api.getAppConfig).thenThrow(StateError('boom'));
      await expectLater(flags.refresh(api), completes);
    });

    // La contre-épreuve du repli : le drapeau de compilation à VRAI doit bien
    // ouvrir le module quand le serveur est muet. Sans elle, « échoue fermé »
    // serait indistinguable de « ne marche jamais ».
    test('un repli de compilation à vrai ouvre bien le module', () async {
      AppConfig.eefTeaserEnabledOverride = true;
      when(api.getAppConfig).thenThrow(StateError('boom'));

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isTrue);
    });

    test('l\'espace réel reste FERMÉ quand le serveur est muet', () async {
      when(api.getAppConfig).thenThrow(StateError('boom'));

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isFalse);
    });
  });

  // `eefSpace` : l'ouverture de l'espace réel pour la seule build 54. L'ancien
  // commutateur `eef` retire la vitrine des builds 49 à 53 ; la clé neuve, elle,
  // ne touche à rien d'autre.
  group('eefSpace — l\'ouverture de l\'espace pour CETTE build', () {
    test('ouvre l\'espace sans toucher à la vitrine ni à l\'ancien drapeau',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{
              'eefTeaser': true,
              'eef': false,
              'eefSpace': true,
            },
          });

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isTrue);
      expect(flags.eefTeaserEnabled, isTrue);
      expect(flags.eefEnabled, isFalse);
    });

    test('l\'ancien commutateur ouvre aussi l\'espace — un serveur plus ancien',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eef': true},
          });

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isTrue);
    });

    test('une clé absente ou fausse laisse l\'espace fermé', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefTeaser': true},
          });
      await flags.refresh(api);
      expect(flags.eefSpaceEnabled, isFalse);

      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefSpace': false},
          });
      await flags.refresh(api);
      expect(flags.eefSpaceEnabled, isFalse);
    });

    test('une valeur non booléenne est ignorée, pas interprétée', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefSpace': 'true'},
          });

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isFalse);
    });

    test(
        'le repli de compilation à vrai ouvre l\'espace quand le serveur ne dit rien',
        () async {
      AppConfig.eefSpaceEnabledOverride = true;
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{},
          });

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isTrue);
    });
  });

  // Build 56 : `eefHelpBubble` (la bulle « Une question ? ») et
  // `eefPrivateSchools` (la mention des écoles privées). Deux clés NOUVELLES,
  // fermées par défaut, qui ne dérivent d'AUCUN autre drapeau : en particulier
  // PAS de l'ancien commutateur `eef`, qui ouvre l'espace — ouvrir l'espace ne
  // doit pas allumer, par ricochet, un canal de contact.
  group('les interrupteurs de la 56 — bulle et écoles privées', () {
    // Les deux getters, sous leur clé serveur : une seule table pour que chaque
    // propriété soit éprouvée sur les DEUX, sans que l'une serve d'alibi à l'autre.
    final switches = <String, bool Function()>{
      'eefHelpBubble': () => flags.eefHelpBubbleEnabled,
      'eefPrivateSchools': () => flags.eefPrivateSchoolsEnabled,
    };
    final overrides = <String, void Function(bool?)>{
      'eefHelpBubble': (v) => AppConfig.eefHelpBubbleEnabledOverride = v,
      'eefPrivateSchools': (v) =>
          AppConfig.eefPrivateSchoolsEnabledOverride = v,
    };

    for (final key in switches.keys) {
      final read = switches[key]!;

      test('$key : fermé avant toute lecture', () {
        expect(flags.loaded, isFalse);
        expect(read(), isFalse);
      });

      test('$key : fermé quand le serveur est injoignable (échec fermé)',
          () async {
        when(api.getAppConfig).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/config/app'),
          type: DioExceptionType.connectionError,
        ));

        await flags.refresh(api);

        expect(flags.loaded, isFalse);
        expect(read(), isFalse);
      });

      test('$key : clé absente = fermé (ancien backend)', () async {
        // Un backend d'avant la 56 sert les drapeaux qu'il connaît, pas ceux-là.
        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'features': <String, dynamic>{
                'eefTeaser': true,
                'eef': false,
                'eefSpace': true,
              },
            });

        await flags.refresh(api);

        expect(flags.loaded, isTrue);
        expect(flags.eefSpaceEnabled, isTrue);
        expect(read(), isFalse);
      });

      test('$key : servi à vrai = ouvert, à faux = fermé', () async {
        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'features': <String, dynamic>{key: true},
            });
        await flags.refresh(api);
        expect(read(), isTrue);

        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'features': <String, dynamic>{key: false},
            });
        await flags.refresh(api);
        expect(read(), isFalse);
      });

      test('$key : une valeur non booléenne est ignorée, pas interprétée',
          () async {
        for (final bad in <Object?>['true', 1, 'yes', null]) {
          when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
                'features': <String, dynamic>{key: bad},
              });

          await flags.refresh(api);

          expect(read(), isFalse, reason: '$key=$bad ne doit rien ouvrir');
        }
      });

      test('$key : le repli de compilation à vrai ne vaut que serveur muet',
          () async {
        overrides[key]!(true);

        // Serveur injoignable : le repli s'applique.
        when(api.getAppConfig).thenThrow(StateError('boom'));
        await flags.refresh(api);
        expect(read(), isTrue);

        // Serveur qui répond SANS la clé : le repli s'applique encore (même
        // règle que les autres drapeaux).
        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'features': <String, dynamic>{},
            });
        await flags.refresh(api);
        expect(read(), isTrue);

        // Serveur qui dit NON : la valeur servie PRIME sur le repli.
        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'features': <String, dynamic>{key: false},
            });
        await flags.refresh(api);
        expect(read(), isFalse);
      });
    }

    test('le repli de compilation est FERMÉ sans dart-define', () {
      expect(AppConfig.eefHelpBubbleEnabled, isFalse);
      expect(AppConfig.eefPrivateSchoolsEnabled, isFalse);
    });

    test('ne dérivent NI de `eef` NI de `eefSpace`, ni l\'un de l\'autre',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eef': true, 'eefSpace': true},
          });

      await flags.refresh(api);

      expect(flags.eefEnabled, isTrue);
      expect(flags.eefSpaceEnabled, isTrue);
      expect(flags.eefHelpBubbleEnabled, isFalse);
      expect(flags.eefPrivateSchoolsEnabled, isFalse);

      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefHelpBubble': true},
          });
      await flags.refresh(api);
      expect(flags.eefHelpBubbleEnabled, isTrue);
      expect(flags.eefPrivateSchoolsEnabled, isFalse);
      // Et allumer la bulle n'ouvre PAS l'espace.
      expect(flags.eefSpaceEnabled, isFalse);
    });
  });

  // Onboarding « la valeur d'abord » (chantier I3) : FERMÉ tant que le
  // serveur ne l'ouvre pas explicitement — l'ancien parcours est le repli.
  group('onboardingV2 — fermé par défaut', () {
    test('fermé avant toute lecture', () {
      expect(flags.onboardingV2Enabled, isFalse);
    });

    test('fermé quand le serveur est injoignable', () async {
      when(api.getAppConfig).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/config/app'),
        type: DioExceptionType.connectionError,
      ));
      await flags.refresh(api);
      expect(flags.onboardingV2Enabled, isFalse);
    });

    test('clé absente (ancien backend) ou non booléenne = fermé', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'scholarshipMatch': true},
          });
      await flags.refresh(api);
      expect(flags.onboardingV2Enabled, isFalse);

      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'onboardingV2': 'true'},
          });
      await flags.refresh(api);
      expect(flags.onboardingV2Enabled, isFalse);
    });

    test('servi à vrai = ouvert, à faux = fermé', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'onboardingV2': true},
          });
      await flags.refresh(api);
      expect(flags.onboardingV2Enabled, isTrue);

      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'onboardingV2': false},
          });
      await flags.refresh(api);
      expect(flags.onboardingV2Enabled, isFalse);
    });
  });

  group('la lecture de la charge', () {
    test('la valeur servie PRIME sur le repli de compilation', () async {
      AppConfig.eefTeaserEnabledOverride = true;
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefTeaser': false, 'eef': true},
          });

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isTrue);
      expect(flags.loaded, isTrue);
    });

    // Une clé non booléenne est IGNORÉE, pas devinée. Une lecture laxiste
    // allumerait une fonctionnalité sur la foi d'une chaîne non vide — c'est-à
    // -dire sur rien.
    test('une valeur non booléenne est ignorée, pas interprétée', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{
              'eefTeaser': 'true',
              'eef': <String, dynamic>{'enabled': true},
            },
          });

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isFalse);
    });

    test('un bloc features absent ou malformé ne fait pas lever', () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => <String, dynamic>{'features': 'nope'});

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.loaded, isTrue);
    });

    test('incrémente flagsVersion pour que les écrans se reconstruisent',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefTeaser': true},
          });

      expect(flags.flagsVersion.value, 0);
      await flags.refresh(api);
      expect(flags.flagsVersion.value, 1);
    });
  });

  group('la fenêtre de campagne', () {
    test('décode deux instants ISO', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': '2026-08-26T00:00:00.000Z',
              'closesAt': '2026-12-15T23:59:00.000Z',
            },
          });

      await flags.refresh(api);

      expect(flags.eefCampaign.opensAt, isNotNull);
      expect(flags.eefCampaign.closesAt, isNotNull);
      expect(flags.eefCampaign.opensAt!.toUtc().month, 8);
    });

    // Aucune date de repli : une échéance inventée est indistinguable d'une
    // information pour qui la lit.
    test('une date illisible devient null, jamais une date de repli', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': 'pas-une-date',
              'closesAt': '',
            },
          });

      await flags.refresh(api);

      expect(flags.eefCampaign.opensAt, isNull);
      expect(flags.eefCampaign.closesAt, isNull);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });

    test('null explicite du serveur est accepté sans lever', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': null,
              'closesAt': null,
            },
          });

      await flags.refresh(api);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });
  });

  // ── Ce que /config/app sert d'autre que des drapeaux ──
  group('les valeurs servies avec les drapeaux', () {
    test('la version recommandée est lue, et seulement si elle est x.y.z',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'recommendedVersion': ' 2.3.0 ',
          });
      await flags.refresh(api);
      expect(flags.recommendedVersion, '2.3.0');

      for (final bad in <Object?>['latest', '2.3', '', null, 3, true]) {
        when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
              'recommendedVersion': bad,
            });
        await flags.refresh(api);
        expect(flags.recommendedVersion, isNull, reason: '$bad');
      }
    });

    test('un serveur plus ancien (sans la clé) ne produit aucune invitation',
        () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => <String, dynamic>{'minVersion': '0.0.0'});
      await flags.refresh(api);
      expect(flags.recommendedVersion, isNull);
    });

    test('les liens de store ne gardent que des adresses ouvrables', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'iosStoreUrl': 'https://apps.apple.com/app/id1128659292',
            'androidStoreUrl': 'exemple.org/sans-schema',
          });
      await flags.refresh(api);

      // Seul l'iOS est ouvrable : on le prouve plateforme par plateforme, au
      // lieu d'une assertion qui passerait aussi quand le lien est perdu.
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(flags.storeUrl, 'https://apps.apple.com/app/id1128659292');
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(flags.storeUrl, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('un refresh qui échoue garde la dernière valeur connue', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'recommendedVersion': '2.3.0',
          });
      await flags.refresh(api);

      when(api.getAppConfig).thenThrow(StateError('hors ligne'));
      await flags.refresh(api);

      expect(flags.recommendedVersion, '2.3.0');
    });

    test('la mention de source du catalogue est lue en entier, ou pas du tout',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCatalog': <String, dynamic>{
              'producer':
                  "Ministère de l'Enseignement supérieur et de la Recherche",
              'licence': 'Licence Ouverte 2.0',
              'updatedAt': '2026-09-21',
              'sources': <String>['Parcoursup', 'Trouver mon master'],
            },
          });
      await flags.refresh(api);

      final attribution = flags.catalogAttribution;
      expect(attribution, isNotNull);
      expect(attribution!.updatedAt, DateTime(2026, 9, 21));
      expect(attribution.sources, ['Parcoursup', 'Trouver mon master']);

      // Une charge incomplète : pas de mention à moitié vraie.
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCatalog': <String, dynamic>{
              'producer': 'Ministère',
              'licence': 'Licence Ouverte 2.0',
            },
          });
      await flags.refresh(api);
      expect(flags.catalogAttribution, isNull);
    });

    test('un 30 février n\'est pas une date de mise à jour', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCatalog': <String, dynamic>{
              'producer': 'Ministère',
              'licence': 'Licence Ouverte 2.0',
              'updatedAt': '2026-02-30',
            },
          });
      await flags.refresh(api);
      expect(flags.catalogAttribution, isNull);
    });
  });

  group('les liens officiels de la campagne', () {
    test('la plateforme et les sources de suspension sont lues', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'suspendedCountries': <String>['Niger'],
              'platformUrl': 'https://www.campusfrance.org/fr',
              'suspendedSources': <Map<String, String>>[
                {
                  'country': 'Niger',
                  'url': 'https://ne.diplomatie.gouv.fr/informations-visas',
                },
              ],
            },
          });
      await flags.refresh(api);

      expect(flags.eefCampaign.platformUrl, 'https://www.campusfrance.org/fr');
      expect(
        flags.eefCampaign.suspensionSourceFor('NIGER'),
        'https://ne.diplomatie.gouv.fr/informations-visas',
      );
    });

    // La source d'une suspension ne doit jamais voyager vers quelqu'un qui n'est
    // pas concerné : un lien « voici pourquoi » sans suspension est une
    // accusation sans objet.
    test('aucune source pour un pays qui n\'est pas suspendu', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'suspendedCountries': <String>['Niger'],
              'suspendedSources': <Map<String, String>>[
                {'country': 'Niger', 'url': 'https://ne.exemple.test/'},
              ],
            },
          });
      await flags.refresh(api);

      expect(flags.eefCampaign.suspensionSourceFor('Mali'), isNull);
      expect(flags.eefCampaign.suspensionSourceFor(null), isNull);
      expect(flags.eefCampaign.suspensionSourceFor(''), isNull);
    });

    test('une entrée illisible est ignorée sans perdre les autres', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'suspendedCountries': <String>['Niger', 'Mali'],
              'platformUrl': 'javascript:alert(1)',
              'suspendedSources': <Object>[
                'pas un objet',
                {'country': 'Niger', 'url': 'javascript:alert(1)'},
                {'country': 'Mali', 'url': 'https://ml.exemple.test/'},
                {'url': 'https://sans-pays.test/'},
              ],
            },
          });
      await flags.refresh(api);

      expect(flags.eefCampaign.platformUrl, isNull);
      expect(flags.eefCampaign.suspensionSourceFor('Niger'), isNull);
      expect(
        flags.eefCampaign.suspensionSourceFor('Mali'),
        'https://ml.exemple.test/',
      );
    });

    // Ce sont des sources OFFICIELLES : un `http://` ne doit pas atteindre un
    // bouton parce qu'un serveur plus ancien ou mal configuré l'aurait laissé
    // passer. (Les liens de store, eux, gardent leur règle propre.)
    test('http:// n\'est pas une source officielle', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'suspendedCountries': <String>['Niger'],
              'platformUrl': 'http://www.campusfrance.org/fr',
              'suspendedSources': <Map<String, String>>[
                {'country': 'Niger', 'url': 'http://ne.exemple.test/'},
              ],
            },
          });
      await flags.refresh(api);

      expect(flags.eefCampaign.platformUrl, isNull);
      expect(flags.eefCampaign.suspensionSourceFor('Niger'), isNull);
    });

    test('un serveur plus ancien (sans ces clés) n\'affiche aucun lien',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': '2026-10-01',
              'suspendedCountries': <String>['Niger'],
            },
          });
      await flags.refresh(api);

      expect(flags.eefCampaign.platformUrl, isNull);
      expect(flags.eefCampaign.suspensionSourceFor('Niger'), isNull);
    });
  });
}
