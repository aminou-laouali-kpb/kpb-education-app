# Guide de voix KPB

Ce guide fixe la façon dont l'app parle à l'élève. Il vaut pour tout texte
ajouté dans `lib/app/core/translations/app_translations_{fr,en}.dart`. Les
règles marquées « garde » sont vérifiées par un test : un texte qui les enfreint
fait échouer `flutter test`.

## 1. On tutoie l'élève (garde)

L'app parle à l'élève comme un grand frère ou une grande sœur qui connaît le
sujet : « tu », « ton », « ta », « tes ». Jamais « vous », « votre », « vos ».

| À faire | À ne pas faire |
|---|---|
| Vérifie ta connexion, puis réessaie. | Vérifiez votre connexion, puis réessayez. |
| Ta photo de profil a été mise à jour. | Votre photo de profil a été mise à jour. |
| Connecte-toi pour continuer. | Connectez-vous pour continuer. |
| Choisis une autre photo. | Choisissez une autre photo. |

Le verbe suit le pronom : « Vérifie », « Réessaie », « Choisis », pas
« Vérifiez ». « Rendez-vous » est un nom commun : il reste.

**Exceptions** (listées une par une, avec leur raison, dans
`test/core/voice_tutoiement_guard_test.dart`) :

- l'espace parent (`parent_*`, et l'accueil du compte parent) : on vouvoie
  l'adulte ;
- les textes juridiques (`privacy_*`, `terms_*`) ;
- les comptes partenaires (écoles, structures) ;
- les messages WhatsApp pré-remplis (`*_prefill`) : c'est l'élève qui écrit à
  l'équipe KPB, et il la vouvoie par politesse ;
- les textes de consentement versionnés (liste d'attente du Pass Karatou,
  `premium-waitlist-v1`) : changer un mot change ce que l'élève a accepté. Les
  tutoyer demande une nouvelle version, déployée d'abord côté backend.
  À VALIDER (propriétaire) : planifier cette version.

Les écrans communs à tous les comptes (connexion, erreurs réseau) tutoient
aussi : l'élève est le public principal.

Une nouvelle exception se déclare dans le test, avec sa raison. Une exception
dont le texte ne vouvoie plus fait échouer le test : on la retire.

## 2. Des phrases courtes, niveau B1

L'élève lit souvent en français ou en anglais comme deuxième langue, sur un
petit écran. Vise le niveau B1 (voir `docs/b1-reading-level-pass.md`) :

- une idée par phrase ; coupe une phrase longue en deux ;
- des verbes plutôt que des noms : « Nos experts examinent ton profil », pas
  « Examen de votre profil par nos experts » ;
- des mots courants : « envoyer » plutôt que « transmettre », « aider » plutôt
  que « accompagner » quand le sens le permet ;
- un sigle s'explique la première fois (CAQ, I-20, MEXT…).

## 3. Pas de « % », jamais « chances » (garde)

KPB ne calcule ni compatibilité ni probabilité d'admission. Un « % » se lit
comme l'une ou l'autre ; « chance(s) », « odds », « probabilité » aussi.

| À faire | À ne pas faire |
|---|---|
| Ces bourses correspondent à ton profil. | 78 % de compatibilité |
| Voici ce que demandent les conditions officielles. | Découvre tes chances d'admission |

Les rares exceptions (une progression de profil, une remise tarifaire, une
phrase qui dit justement qu'on NE calcule PAS de chances) sont nommées dans
`test/core/honest_labels_guard_test.dart`. Les conditions officielles d'une
bourse (« 70 % » de moyenne, par exemple) viennent du serveur, citées telles
quelles, jamais des traductions.

## 4. Aucune promesse d'admission ni de bourse

L'admission et la bourse dépendent de l'établissement ou de l'organisme, pas de
KPB. On dit ce que KPB fait (préparer, relire, conseiller), jamais ce que
l'élève obtiendra.

| À faire | À ne pas faire |
|---|---|
| Un conseiller KPB relit ton dossier avant l'envoi. | Ton admission est garantie. |
| Prépare ta candidature avec KPB Intelligence. | Décroche ta bourse à coup sûr. |

On ne promet pas non plus une fonction absente : si l'envoi de documents est
masqué, le texte le dit (voir `test/core/masquage_documents_test.dart`).

## 5. Les termes KPB

Toujours les mêmes mots pour les mêmes choses :

| Terme | Usage |
|---|---|
| KPB Education | Le nom de l'app et de l'organisation. |
| conseiller KPB | La personne qui suit l'élève. Pas « agent » : l'app met en garde contre les « agents » hors du circuit KPB. |
| KPB Intelligence | L'assistant IA. |
| Pass Karatou | L'offre d'accompagnement payante (pas encore ouverte). |
| Études en France | L'espace dédié à la France. |
| dossier / *case* | Une demande suivie par l'équipe KPB (onglet « Dossiers » / « My Cases »). |
| Mon plan, Ta prochaine étape | Les blocs de l'accueil. |

## 6. Où vivent les textes

- Tout texte visible passe par les traductions FR **et** EN (même clé, vérifié
  par `test/core/translations_parity_test.dart`). Pas de texte en dur dans un
  écran ou un contrôleur.
- Un texte enregistré avec une donnée (un dossier créé sur l'appareil, par
  exemple) se lit dans les deux langues depuis les traductions : voir
  `_caseText` dans `lib/app/core/controllers/app_controller/cases.dart`.
- L'anglais suit les mêmes règles : phrases courtes, « you » direct, pas de
  « % », pas de « chances ».
