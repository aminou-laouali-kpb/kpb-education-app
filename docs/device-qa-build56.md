# Fiche de QA appareil — build 56 : bulle WhatsApp, visite guidée, écoles privées

> **⚠️ REMPLACÉE par la 57 le 18/10/2026 : suivre `docs/mise-a-jour-57-checklist.md`.**
> La 2.3.0 est en vente (App Store depuis le 07/10/2026, et Google Play : constat du 16/10/2026) ;
> la build suivante est la `2.3.1 (57)` (`pubspec.yaml`, préflights et registre posés le 18/10/2026).
> À VALIDER (propriétaire) : que la build en vente est bien la 56, sa date de téléversement et le
> SHA archivé (`docs/release-ledger.md`, ligne `56`). Le contenu ci-dessous est conservé tel
> qu'écrit ; pour tout numéro de version ou de build à venir, lire 57. Les papiers de la 57 :
> `docs/release-57-store-pack.md`, `docs/device-qa-build57.md`.

> **Pour qui.** Le propriétaire, sur **un iPhone et un Android physiques**, avec la
> **build soumise** (TestFlight / Play Internal) — pas un build de debug : le contrat de
> soumission exige que la preuve vienne de l'artefact. Cette fiche est la **suite de
> `docs/device-qa-build55.md`** (Aide-18 à Aide-44) et de la fiche 54 (§A, §B, §B-filtres,
> §B-aide) : elle ne les remplace pas. Elle couvre ce que la **56** ajoute — la **bulle verte
> WhatsApp**, la **visite guidée** du hub, la **feuille « écoles privées »** — et les gardes
> de boutiques qui s'y rattachent.
>
> **Écrite le 05/10/2026 d'après le code (PR #319 à #322) et JAMAIS jouée sur appareil** : le
> simulateur iOS ne compile pas avec Flutter 3.44.1 + Xcode 27, seuls des tests de widgets ont
> tourné. Un « attendu » qui se révèle faux se corrige ici, on ne plie pas la recette à la build.
>
> **Où et comment tester.** Tout est derrière `features.eefSpace`, éteint en production, et deux
> éléments ont **en plus** leur propre interrupteur, fermé par défaut :
> `features.eefHelpBubble` (la bulle) et `features.eefPrivateSchools` (la feuille). Mêmes trois
> voies que le §B de la fiche 54 (voie 2, la fenêtre de recette sur la production, est la seule
> qui teste l'artefact soumis sur le vrai catalogue) ; les actions sont
> `eef-space-on`, `eef-bubble-on`, `eef-private-schools-on` et leurs `-off`
> (`docs/runbook-ouverture-espace-reel.md`). **Tuer et relancer l'app** après chaque bascule
> (les drapeaux sont lus au démarrage), **aucune notification** pendant la fenêtre, et **tout
> éteindre AVANT « Soumettre pour vérification »**. **⚠️ Le drapeau `eefSpace` est global**, mais
> aucune build qui contient le hub n'est en vente (la 55 n'a jamais été soumise, la 56 la
> remplace : `docs/release-56-store-pack.md` §1.2) : la fenêtre n'ouvre le hub qu'aux testeurs.
> L'ordre des opérations d'archive et de recette : `docs/mise-a-jour-56-checklist.md`.
>
> **Comptes à avoir sous la main.** Un compte étudiant **hors Niger** (le Sénégal convient), un
> compte étudiant du **Niger**, un **invité**, un compte **parent**. Pour la visite : une
> installation **neuve** (ou supprimer l'app puis la réinstaller), car le drapeau « vue » est
> local à l'appareil.
>
> **Langue.** La build soumise est **en français seulement** : `kShippedLocale = 'fr'`
> (`lib/app/core/i18n/app_locale.dart`) ramène toute préférence au français et le sélecteur FR/EN
> est masqué. Les textes anglais de la bulle, de la visite et de la feuille existent et sont
> gardés par des tests de parité, mais **aucun appareil ne peut les afficher avec l'artefact
> soumis**. Les cas « FR + EN » des fiches 54 et 55 ne sont donc pas jouables en anglais sur
> cette build ; ici, un cas marqué **[EN, build de travail]** ne se joue que sur un build
> local dont `kShippedLocale` vaut `'en'` (ce n'est pas l'artefact : le dire dans la
> signature). Ne pas le compter comme preuve de l'artefact.
>
> **Ce qui ne se teste pas sur appareil, et pourquoi.** Le **thème sombre** n'est pas branché
> (clair seulement). L'état « Le catalogue arrive » n'existe plus en production. **Les outils IA
> masqués** (`KPB_AI_TOOLS_ENABLED=false`) ne s'obtiennent pas sur la build soumise (actifs par
> défaut) : le cas Visite-4 se joue sur un build de travail.
>
> **Numérotation.** Elle continue après Aide-44 avec trois préfixes pour les trois nouveautés
> — **Bulle-**, **Visite-**, **Privé-** — et trois pour les sections transversales :
> **Serveur-**, **Compte-**, **Boutique-**.

Pour chaque ✗ : noter l'écran, la langue, le pays du compte, l'appareil.

## Les messages de la bulle (à lire avant Bulle-5 et suivants)

Chaque message de la bulle est **statique** et ne nomme que l'**écran** et le **sujet choisi** :
`@place` vaut « l'espace Études en France de l'app » dans le hub et « le catalogue de l'espace
Études en France de l'app » dans le catalogue. Ni formation, ni filtre, ni nom, ni pays. (Les
aides de la 55, elles, citent des données **publiques** du catalogue — intitulé, université,
ville, filtres posés, outil : fiche 55, Aide-18 et suivants. Aucune de ces données n'est
personnelle.)

| Sujet | Libellé | Message (hub) |
|---|---|---|
| Assistance | Contacter l'équipe KPB pour une assistance | *Bonjour KPB Education, je suis dans l'espace Études en France de l'app et j'aimerais de l'aide de l'équipe KPB.* |
| Dossier | Je veux de l'aide pour mon dossier | *Bonjour KPB Education, je suis dans l'espace Études en France de l'app et j'aimerais de l'aide pour préparer mon dossier de candidature.* |
| Choisir | Je ne sais pas quelle formation choisir | *Bonjour KPB Education, je suis dans l'espace Études en France de l'app. J'hésite sur le choix de ma formation et j'aimerais en parler.* |
| Écoles privées | Je veux en savoir plus sur les écoles privées + pastille « Service KPB » | *(n'envoie rien : ouvre la feuille d'information, Privé-3)* |
| Autre question | J'ai une autre question | *Bonjour KPB Education, j'ai une question sur l'espace Études en France de l'app.* |

**Compte dont le pays est suspendu (Niger) — menu neutre à deux lignes** : « Parler à un
conseiller » → *Bonjour KPB Education, je suis dans l'espace Études en France de l'app. La
procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent.* ; « J'ai
une autre question » → *…La procédure est suspendue dans mon pays et j'ai une question.* Aucun
pays nommé, jamais « dossier » ni « démarrer ».

**Longueur.** Le message le plus long fait **183** points de code, **260** caractères une fois
encodé et **291** pour le lien complet `https://wa.me/33768674292?text=…` (calculé le
05/10/2026, `docs/release-56-store-pack.md` §1.1). Le code borne à 520 / 1 800.

## Bulle : apparition et menu

| # | À vérifier | Attendu |
|---|---|---|
| Bulle-1 | **Apparition, hub** (`eefSpace` et `eefHelpBubble` vrais ; compte étudiant hors Niger ; tuer et relancer) | Un **cercle vert** de 56 dp en bas à droite, marge de 16 dp, avec un glyphe de **bulle de conversation marine** — **pas** le logo WhatsApp. **Aucune étiquette, aucune pulsation, aucune pastille.** Il suit la zone sûre : jamais sous l'indicateur d'accueil de l'iPhone ni sous la barre de navigation Android. Cible tactile ≥ 48 dp. |
| Bulle-2 | **Apparition, catalogue** | Même cercle. Il est **au-dessus** de la rangée « Sources des données et mentions » (qui n'est PAS déplacée) et ne la recouvre pas. Faire défiler la liste **jusqu'au bout** : la **dernière carte** et la rangée des sources ne sont **jamais** cachées par la bulle (la marge basse de la liste est portée à 104 dp quand la bulle est là). |
| Bulle-3 | **Absence** | **Jamais** de bulle : sur la vitrine (état A), sur les écrans CV / Lettres / Entretien, sur l'écran « Un espace pour les étudiants » (parent), sur l'accueil et le reste de l'app (le coach IA y a son propre bouton), ni sur une feuille. |
| Bulle-4 | **Le menu** : tap sur la bulle | Une feuille « **Écrire à l'équipe KPB** » et son sous-titre « Choisis ton sujet. WhatsApp s'ouvre avec un message déjà écrit : tu peux le modifier, et rien n'est envoyé sans toi. » Les **sujets** dans l'ordre du tableau ci-dessus : **5** (écoles privées allumées) ou **4** (éteintes) ; chaque tuile fait ≥ 56 dp, montre son **libellé ET, dessous, le message exact qui partira** (sauf « écoles privées », qui montre la pastille « Service KPB »). Dessous : « Numéro officiel de KPB Education : +33768674292 », « Copier le numéro », « Pas de WhatsApp ? Écris-nous à contact@kpbeducation.com », la mise en garde anti-arnaque (« KPB ne demande JAMAIS de paiement sur un numéro Mobile Money personnel… ») et « Un accompagnement n'est pas une garantie… ». |
| Bulle-5 | **Chaque message, hub** | Taper **chaque** sujet de messagerie (assistance, dossier, choisir, autre question), un par un : la feuille **se ferme d'abord**, puis WhatsApp s'ouvre sur la ligne du conseiller avec **exactement** le message du tableau. Rien n'est envoyé tout seul. |
| Bulle-6 | **Chaque message, catalogue** | Même chose depuis le catalogue : `@place` devient « le catalogue de l'espace Études en France de l'app ». |
| Bulle-7 | **Le menu neutre (Niger)** | Compte du Niger : la bulle est **présente** (on ne bloque personne) ; le menu n'a que **deux** lignes (« Parler à un conseiller », « J'ai une autre question »), **aucune** option « dossier », « choisir » ni « écoles privées ». Les messages sont ceux du bloc ci-dessus. Le pays n'est jamais nommé. |
| Bulle-8 | **Le message arrive ENTIER et modifiable** — WhatsApp | Pour **chacun** des sujets (hub **et** catalogue) : dans le champ de saisie de WhatsApp, la phrase finale est **lisible avant envoi** (« …de l'équipe KPB. », « …mon dossier de candidature. », « …en parler. », « …de l'app. »), le texte est **modifiable** (ajouter un mot, supprimer un mot). **Accents et apostrophes intacts** : « Études », « j'aimerais », « l'aide », « pour préparer ». iPhone **et** Android. |
| Bulle-9 | **WhatsApp Business** | Même chose avec **WhatsApp Business seul** installé (désinstaller WhatsApp), sur iPhone puis Android. Android avec les **deux** installés : noter ce que le système propose. Le message arrive entier et modifiable. |
| Bulle-10 | **[EN, build de travail]** Les mêmes messages en anglais (*Hello KPB Education, I'm in the Études en France space of the app and I'd like help from the KPB team.* …) | Entiers, apostrophes droites intactes. **Non jouable sur la build soumise** (voir « Langue ») : à signer « non joué » si on n'a pas de build de travail. |
| Bulle-11 | **Longueur réelle d'un lien `wa.me`** (à MESURER ici, jamais mesurée ailleurs ; suite d'Aide-38) | Envoyer le **plus long** message de la 56 : écoles privées, catalogue (Privé-6), 183 points de code, lien de 291 caractères ; puis le plus long **neutre** (assistance neutre depuis le catalogue, 174 points de code). Les deux arrivent **entiers**. Si l'un est tronqué : noter le nombre de caractères reçu — ce qui décide de resserrer les messages. |
| Bulle-12 | **La limite de `wa.me` elle-même** (facultatif, hors app) | Dans les Notes ou un message à soi-même, écrire un lien `https://wa.me/33768674292?text=` suivi de 300, 600, 1 000 puis 1 800 caractères encodés, et l'ouvrir : relever à partir de quelle longueur WhatsApp tronque ou refuse. Donne la marge réelle des bornes 520 / 1 800 du code. |
| Bulle-13 | **WhatsApp absent** | Désinstaller WhatsApp **et** WhatsApp Business. Tap sur un sujet : la feuille se ferme, le lien est **tenté** (jamais de « WhatsApp est-il installé ? » avant) et s'ouvre **dans le navigateur** (page wa.me) : c'est correct. Avec **aucune application capable d'ouvrir le lien** (navigateur désactivé sur Android) : le toast « Impossible d'ouvrir WhatsApp… » s'affiche, **après** la fermeture de la feuille, visible et jamais muet. |
| Bulle-14 | **Mode avion** | La bulle et le menu **s'ouvrent** (ils sont statiques). Tap sur un sujet : noter ce qui se passe — WhatsApp s'ouvre et met le message en file, ou (WhatsApp absent) le navigateur échoue. Aucun écran vide, aucune erreur muette. |
| Bulle-15 | **Clavier ouvert** (champ de recherche du catalogue) | Dès que le clavier s'ouvre, la bulle **disparaît** ; elle **revient** à sa fermeture. Le champ de recherche reste utilisable, rien ne le masque. |
| Bulle-16 | **Double tap** | Deux taps très rapides sur la bulle : **une seule** feuille. Deux taps très rapides sur un sujet : **un seul** WhatsApp, pas de feuille qui se ferme deux fois ni d'écran dépilé en trop. |
| Bulle-17 | **Fermer sans choisir** | Glisser la feuille vers le bas, ou toucher le fond : **rien ne part**, aucun WhatsApp. La bulle reste cliquable. |
| Bulle-18 | **Le pied de la feuille** | « Copier le numéro » : le bouton devient « Copié » ; le presse-papiers contient `+33768674292` (le coller dans une note). L'adresse e-mail de repli est lisible. Le numéro affiché est celui de `AppConfig.whatsappNumber` (+33 7 68 67 42 92). |
| Bulle-19 | **VoiceOver / TalkBack** | La bulle est annoncée « Écrire à l'équipe KPB sur WhatsApp, bouton » avec l'indice « Ouvre une liste de messages prêts à envoyer ». Dans le menu, **chaque sujet est un bouton unique** : libellé **et** message lus ensemble (le sujet « écoles privées » dit sa pastille « Service KPB »). « Copié » est annoncé. À la fermeture, le focus **revient à la bulle**. |
| Bulle-20 | **iPhone petit et grand** (SE ou mini, puis Pro Max) | La bulle est entière, ni coupée ni sous l'indicateur d'accueil ; le menu défile si l'écran est court ; rien ne déborde. |
| Bulle-21 | **iPad portrait** | La feuille ne s'étale pas sur 768 dp : elle est limitée à **560 dp**, centrée. La bulle reste en bas à droite. (L'app est verrouillée en portrait.) |
| Bulle-22 | **Android 360 × 640** (ou le plus petit appareil disponible) ; navigation par gestes **et** par trois boutons | La bulle n'est pas sous la barre de navigation ; la dernière carte du catalogue et la rangée des sources restent atteignables. |
| Bulle-23 | **Texte maximal** (réglage système au plus grand, FR) | Libellés et messages **passent à la ligne**, jamais coupés par « … » ; la feuille défile ; la bulle reste un **cercle sans texte** ; la dernière carte et la rangée des sources ne sont pas recouvertes. |
| Bulle-24 | **Analytique** (PostHog → Activity, filtré sur le compte de test ; Android : aussi Firebase DebugView, `adb shell setprop debug.firebase.analytics.app com.karatou.android`) | À l'arrivée sur l'écran : `eef_help_card_shown` (`help_step` = `bubble`, `surface` = `hub` ou `catalog`, `variant` = `bubble`), **une seule fois par visite**. Ouvrir le menu : `eef_bubble_opened` (`surface`). Tap sur un sujet : `eef_help_cta_tapped` (`help_step` = `bubble_assistance` / `bubble_dossier` / `bubble_choose` / `bubble_question`, `surface`, `variant` = `bubble`), **puis** `whatsapp_handoff` (`source` = `eef_help_bubble_<sujet>`, `context_type` = `eef_help`). Fermer sans choisir : **aucun** `eef_help_cta_tapped`. **Aucune autre propriété** : ni message, ni pays, ni « suspendu ». Compte du Niger : **mêmes** identifiants (`bubble_assistance`, `bubble_question`). Contrat : `docs/analytics-event-contract.md`. |
| Bulle-25 | **Toast sur la bulle** | Le toast d'un WhatsApp introuvable (3 s) peut recouvrir la bulle : acceptable, il disparaît seul. |

## Visite guidée

> La visite s'ouvre à la **première ouverture du hub réel** et se rejoue par le « ? » de la
> barre du hub. Elle n'a **pas** d'interrupteur à elle : elle s'allume avec `eefSpace`.

| # | À vérifier | Attendu |
|---|---|---|
| Visite-1 | **Première ouverture seulement** (installation neuve, compte étudiant hors Niger, `eefSpace` vrai) | À l'arrivée sur le hub, une feuille « **Visite de l'espace** » s'ouvre après le premier cadre. Le hub reste **visible derrière** : ce n'est pas un mur. |
| Visite-2 | **Les cartes** (bulle allumée, outils IA actifs) | **4** cartes, « Étape n sur 4 » : « Bienvenue dans Études en France », « Trouve une formation », « Prépare tes documents », « Une question ? Écris-nous ». Un pictogramme dans un disque, un titre, deux phrases. « Suivant » à chaque carte, **« Compris » à la dernière**. **Aucune** carte ne cite un prix, une école privée ni une promesse d'admission. |
| Visite-3 | **Carte « bulle » omise, bulle éteinte** (`eefHelpBubble` faux) | **3** cartes (« sur 3 ») : celle du « bouton vert en bas à droite » n'existe pas — la visite ne nomme jamais un élément absent. |
| Visite-4 | **Sans outils IA** (build de travail, `KPB_AI_TOOLS_ENABLED=false`) | **3** cartes, sans « Prépare tes documents ». Avec la bulle éteinte **et** les outils masqués : **2** cartes. *Non jouable sur la build soumise.* |
| Visite-5 | **« Passer »** | Présent sur **chaque** carte, ≥ 48 dp. Il ferme la visite ; **elle ne revient pas** (Visite-9). |
| Visite-6 | **Retour Android** (geste ou bouton) | Équivaut à « Passer » : la visite se ferme, le drapeau est posé. |
| Visite-7 | **Voile et glissement** | Toucher le voile ou glisser la feuille vers le bas ferme la visite (comme « Passer »). |
| Visite-8 | **Le « ? » de la barre du hub** | Une icône « ? » (tooltip « Revoir la visite »), ≥ 48 dp. Elle **rejoue** la visite à volonté, **sans toucher** au drapeau « vue ». |
| Visite-9 | **Elle ne revient pas après kill / relance** | Tuer l'app **au milieu** de la carte 2, relancer : **pas de visite**. Le drapeau est posé à l'**affichage**, pas à la fin. Idem après « Passer » puis kill. |
| Visite-10 | **Compte suspendu (Niger) : la carte 1 est neutre** | Texte : « Ici, tu explores des formations et tu prépares ton projet d'études. Les démarches officielles se font sur les plateformes de l'État : KPB est un service privé d'accompagnement, pas un service de l'État. » — **ni** « candidature », **ni** « dossier », **aucun** pays. Les cartes 2 à 4 sont **identiques** à celles des autres comptes. |
| Visite-11 | **Invité** | La visite s'affiche aussi pour un invité. |
| Visite-12 | **Jamais ailleurs** | Pas de visite sur la vitrine (état A), ni sur l'écran « Un espace pour les étudiants » (parent), ni dans le catalogue ou les outils. |
| Visite-13 | **Pas au-dessus d'un dialogue** | Cas difficile à provoquer à la main (couvert par un test de widget) : si un dialogue, une feuille ou un écran de l'app est déjà au-dessus du hub quand la visite devrait s'ouvrir (lien profond, notification), elle **ne s'empile pas**. La visite **ne s'ouvre pas** et le drapeau « vue » n'est **PAS posé** (le code vérifie que le hub est au sommet *avant* d'écrire le drapeau) : elle s'affichera à la **prochaine ouverture du hub** sans rien dessus, et le « ? » (Visite-8) la rejoue à volonté. Seule une écriture du drapeau en panne, ou un dialogue qui arrive *pendant* l'écriture, laisse le drapeau posé sans visite affichée. Une demande de permission **du système** n'entre pas dans ce cas. |
| Visite-14 | **Mise à jour depuis la 55 de TestFlight** (fenêtre de recette, testeur qui a déjà ouvert le hub avec la 55, jamais soumise) | La visite s'affiche à la **première ouverture du hub après la mise à jour** (clé neuve `kpb_relaunch_v1.eef_tour_v1`). |
| Visite-15 | **Suppression puis réinstallation** | La visite revient : le drapeau est local à l'appareil. Il survit à la suppression du **compte** (valeur non personnelle), pas à celle de l'app. |
| Visite-16 | **Après la visite : la bulle** | À la fermeture, la bulle fait **une** entrée en échelle (0,8 à 1,0 en 250 ms) ; aucune animation si les animations sont réduites. La carte 4 dit « en bas à droite » : c'est bien là. |
| Visite-17 | **VoiceOver / TalkBack** | La feuille est une route nommée « Visite de l'espace » ; le titre de chaque carte est un **en-tête** ; « Étape n sur N » est annoncé quand il change ; les points indicateurs ne sont **pas** lus ; le focus reste dans la feuille puis **revient au hub**. |
| Visite-18 | **Texte maximal sur petit écran** | Le contenu défile, les boutons restent épinglés et visibles, les libellés passent à la ligne (jamais « … »). |
| Visite-19 | **Animations réduites** (Réglages → Accessibilité → Réduire les animations ; Android : supprimer les animations) | Les cartes changent **sans glisser** (saut direct). |
| Visite-20 | **Analytique** | À l'affichage : `eef_tour_shown` (`tour_trigger` = `first_open`, ou `replay` pour le « ? »). À la fermeture : `eef_tour_completed` (`tour_exit` = `finished` pour « Compris », `skipped` pour tout le reste ; `tour_cards_seen` = le nombre de cartes **atteintes**). Compte du Niger : **mêmes** événements, mêmes valeurs. Une visite qui ne s'ouvre pas n'émet **rien**. |

## Écoles privées

> Éteintes par défaut. Pour ces cas : `eefSpace` **et** `eefPrivateSchools` vrais (la bulle,
> elle, n'est nécessaire que pour Privé-3).

| # | À vérifier | Attendu |
|---|---|---|
| Privé-1 | **Porte du catalogue vide** (compte hors Niger) | Chercher une suite de lettres sans résultat (« zzzz ») : « Aucune formation ne correspond », la carte « Tu ne trouves pas ta formation ? », puis **sous elle et avant le bloc des données** une **ligne secondaire** : pastille « Service KPB », « Les écoles privées ont d'autres conditions et un autre calendrier. » et le lien « Les écoles privées : ce qu'il faut savoir ». **Une ligne, pas une seconde carte pleine, aucun second bouton WhatsApp.** |
| Privé-2 | **Pas ailleurs** | Aucune ligne dans une liste **non vide**, dans le hub, dans les outils, ni près de la mention des données ou de la non-affiliation. |
| Privé-3 | **Porte de la bulle** | Le menu de la bulle (hub **et** catalogue) a une option « Je veux en savoir plus sur les écoles privées » + pastille « Service KPB », en **4e position** (entre « choisir » et « autre question »). Elle n'affiche **pas** de message : le tap ferme le menu et ouvre la **feuille d'information** ; **WhatsApp ne s'ouvre pas**. |
| Privé-4 | **La feuille** | Pastille « Service KPB » ; titre « Les écoles privées : ce qu'il faut savoir » ; quatre points — (1) « Chaque école privée fixe ses propres conditions d'admission, ses frais et son calendrier. » (2) « Les frais sont en général plus élevés que dans le public. Demande-les par écrit avant de t'engager. » (3) « Les démarches officielles (admission, visa) dépendent de ton pays et de l'école. Vérifie-les sur les sites officiels. » (4) « KPB Education est un service privé d'accompagnement, pas un service de l'État. » **et rien d'autre : aucune phrase de rémunération** (décision du propriétaire, 06/10/2026) ; puis « Un accompagnement n'est pas une garantie : l'admission et le visa dépendent des établissements et des autorités. » ; le bouton « En parler à un conseiller » ; « Message qui sera écrit : » suivi du message ; « Pas maintenant ». La feuille défile si l'écran est court. **Pas de mention de rémunération, ni en FR ni en EN** (décision (a) du pack, tranchée) ; si la décision (c) retient le repli, le point (2) devient « Les frais varient beaucoup d'une école à l'autre. Demande-les par écrit avant de t'engager. » |
| Privé-5 | **Les boutons** | « En parler à un conseiller » : la feuille **se ferme d'abord**, puis WhatsApp s'ouvre sur la ligne du conseiller avec le message affiché. « Pas maintenant » (et le voile, et le glissement) : ferme, **rien ne part**, WhatsApp ne s'ouvre pas. |
| Privé-6 | **Le message, entier et modifiable** — WhatsApp et WhatsApp Business | Depuis le hub : *Bonjour KPB Education, je suis dans l'espace Études en France de l'app. J'aimerais en savoir plus sur les écoles privées : conditions d'admission, frais et calendrier.* Depuis le catalogue : « …dans le catalogue de l'espace… ». Il est **le plus long de la 56** (183 points de code, lien de 291 caractères, catalogue) : il arrive **entier**, sa fin « …frais et calendrier. » est lisible, modifiable, accents et apostrophes intacts. iPhone **et** Android. **Aucun** budget, niveau, pays ni champ « Mon niveau : … » à compléter. |
| Privé-7 | **Absence : compte du Niger** | Compte du Niger : **aucune ligne** dans le catalogue vide (la carte neutre reste seule), **aucune option** dans le menu de la bulle (2 lignes), et l'expression « école(s) privée(s) » (ou « private school ») n'apparaît **nulle part** dans le hub, le catalogue, la visite ni la bulle. Le mot « privé » de « organisme privé d'accompagnement » (pied du hub, non-affiliation) et de « service privé d'accompagnement » (carte 1 neutre de la visite) est **attendu** : c'est la non-affiliation, qui doit rester lisible (Boutique-1). La feuille est inatteignable. |
| Privé-8 | **Absence : drapeau éteint** | `eefPrivateSchools` faux (compte hors Niger) : ni ligne, ni option (le menu de la bulle a 4 sujets). `eef-private-schools-off` + `curl` (`eefPrivateSchools` → `false`) + tuer et relancer : tout disparaît, **sans** nouvelle build. |
| Privé-9 | **Invité** | Un invité (sans profil, donc sans pays, donc jamais « suspendu ») voit la version standard : la ligne et l'option, avec les mêmes textes. Rien ne parle de procédure ni de suspension. |
| Privé-10 | **Aucune donnée, aucun dossier** | La feuille n'a ni champ, ni formulaire, et **ne mène pas** à l'écran « Demande d'admission » d'une école privée (celui dont le bouton crée un dossier et envoie des coordonnées aux commerciaux). Aucune ligne ne s'ajoute dans l'admin (liste d'intérêt) ; le profil Études en France n'est ni lu ni modifié. |
| Privé-11 | **Aucun montant, aucune devise, aucun nom d'école** | Ni dans la ligne, ni dans la feuille, ni dans le message : pas de prix, pas d'euro, pas de FCFA, pas de nom d'école, pas de « partenaire » ni « sponsorisé », pas de « Campus France ». |
| Privé-12 | **Texte maximal, 360 dp, iPad, lecteur d'écran** | La ligne du catalogue passe à la ligne (pastille, phrase, lien) ; la feuille défile et ses boutons restent à portée (≥ 48 dp) ; sur iPad elle est limitée à 560 dp ; VoiceOver / TalkBack : le titre est un en-tête, les boutons sont annoncés comme boutons, le lien du catalogue aussi. |
| Privé-13 | **Analytique** | La ligne montée : `eef_help_card_shown` (`help_step` = `private_note`, `surface` = `catalog`, `variant` = `note`), **une fois par visite** du catalogue. Ouverture de la feuille : `eef_private_info_opened` (`entry` = `catalog_empty` ou `bubble`). « En parler à un conseiller » : `eef_help_cta_tapped` (`help_step` = `private_sheet`, `surface` = `hub` ou `catalog`, `variant` = `sheet`), **puis** `whatsapp_handoff` (`source` = `eef_help_private_sheet`). « Pas maintenant » : rien d'autre que l'ouverture déjà comptée. Choisir l'option dans le menu de la bulle ne produit **aucun** `eef_help_cta_tapped`. |

## États serveur

> Chaque bascule : l'action `vps-ops` (simulation d'abord pour les `-on`), puis la **preuve par
> `/config/app`**, puis **tuer et relancer l'app**.
> `curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools}'`

| # | À vérifier | Attendu |
|---|---|---|
| Serveur-1 | **État de départ** (`eefSpace` faux, les deux autres faux ou absents) | La 56 montre la **vitrine** : ni hub, ni visite, ni bulle, ni ligne « écoles privées ». État étanche, comme A19 de la fiche 54. |
| Serveur-2 | **`eefSpace` vrai seul** | Le hub s'ouvre et la **visite** s'affiche (**3 cartes** : pas de carte « bulle »). **Pas de bulle**, pas de ligne, pas d'option. |
| Serveur-3 | **+ `eefHelpBubble` vrai, `eefPrivateSchools` faux** | La bulle apparaît (hub, catalogue) ; le menu a **4** sujets ; pas de ligne dans le catalogue vide. Une installation neuve montre la visite à **4** cartes. |
| Serveur-4 | **+ `eefPrivateSchools` vrai** | Le menu a **5** sujets ; la ligne apparaît dans le catalogue vide ; la feuille s'ouvre. |
| Serveur-5 | **`eefHelpBubble` vrai SANS `eefSpace`** | **Rien** : la bulle n'ouvre rien seule. Idem `eefPrivateSchools` seul. |
| Serveur-6 | **Retour arrière prouvé** | `eef-private-schools-off` → `/config/app` dit `eefPrivateSchools: false` → relance : la ligne et l'option ont disparu. Puis `eef-bubble-off` → la bulle disparaît (hub **et** catalogue) et la carte « bulle » de la visite aussi. Puis `eef-space-off` → vitrine. Chaque retour est **indépendant** des autres. |
| Serveur-7 | **Simulation** | `eef-bubble-on` et `eef-private-schools-on` lancés avec `dry_run` **coché** : les contrôles passent, **rien n'est écrit** (le `curl` avant et après est identique). Les `-off` n'ont pas de simulation et agissent tout de suite. |
| Serveur-8 | **Ancien backend** | Un backend antérieur à la 56 ne sert pas les deux clés : la 56 les lit « faux » — pas de bulle, pas de ligne (voie 1 de la fiche 54, backend local ancien). |
| Serveur-9 | **Drapeaux qui arrivent tard** | Réseau lent : les drapeaux arrivent après le premier cadre ; la bulle **apparaît** à ce moment-là et la marge basse de la liste suit ; si `eefPrivateSchools` passe à faux, la ligne disparaît. Aucune erreur. **À noter explicitement** : les cartes de la visite sont décidées **à l'affichage** (la carte « bulle » dépend de `eefHelpBubble` à cet instant) — sur une première ouverture à froid et lente, vérifier que le nombre de cartes (3 ou 4) correspond à l'état de la bulle qui apparaît ensuite. Un écart se note, il ne bloque pas. |
| Serveur-10 | **Avant « Soumettre pour vérification »** | Les deux interrupteurs **et** `eefSpace` sont éteints (`curl`), sinon le relecteur voit l'état B. |

## Comptes

| # | À vérifier | Attendu |
|---|---|---|
| Compte-1 | **Étudiant hors Niger** (Sénégal) | La version standard complète : visite (carte 1 standard), bulle à 5 (ou 4) sujets, ligne et option « écoles privées » (drapeau allumé). |
| Compte-2 | **Étudiant du Niger** | Bulle **présente** à 2 lignes neutres ; **aucune** école privée nulle part ; visite : seule la carte 1 est neutre ; **plus aucun avertissement de suspension** nulle part : ni la vitrine, ni le hub, ni le catalogue (retiré le 05/10/2026 à la demande du propriétaire ; la vitrine et le héros du hub ne montrent alors ni la date ni la mise en garde) ; les aides neutres de la fiche 55 inchangées. |
| Compte-3 | **Invité** (app ouverte sans compte) | Visite, bulle et ligne « écoles privées » (si allumées) : version standard. Aucun message ne parle de procédure ni de suspension. |
| Compte-4 | **Parent / partenaire** (lien profond `kpb://etudes-en-france`) | « Un espace pour les étudiants » et son bouton conseiller **seulement** : ni bulle, ni visite, ni ligne. |
| Compte-5 | **Autre pays** (Côte d'Ivoire, Cameroun, France…) | Version standard. |
| Compte-6 | **Liens profonds** `kpb://etudes-en-france` et `kpb://etudes-en-france/catalogue` | Mêmes règles que par le menu : visite à la première ouverture du hub, bulle selon les drapeaux. |
| Compte-7 | **Limite connue** : un Nigérien dont le profil indique un autre pays | Il voit la version standard. Vérifier que **rien** de ce qu'il lit ne parle de procédure, de suspension ou de l'État : les messages standard n'en parlent pas. |
| Compte-8 | **La suspension arrive pendant la lecture** | Menu ouvert, puis le pays du profil passe à un pays suspendu : le message est **recalculé au tap** et c'est le message neutre (assistance) qui part, avec l'identifiant `bubble_assistance`. |

## Gardes de boutiques

| # | À vérifier | Attendu |
|---|---|---|
| Boutique-1 | **Non-affiliation toujours lisible** (A20 et B7 de la fiche 54) | Hub, catalogue (pied de page, rangée « Sources des données et mentions »), vitrine : la mention de non-affiliation et son lien restent lisibles et atteignables **bulle allumée**, à toutes les tailles de texte. |
| Boutique-2 | **Aucun prix, aucun verbe d'achat près du bouton** | La bulle, le menu, la feuille et la visite n'affichent ni prix, ni « acheter », « payer », « gratuit », « offre », « promotion ». |
| Boutique-3 | **Rien ne se charge ni ne s'envoie sans geste** | Ouvrir hub, catalogue, menu et feuille avec un outil de capture réseau côté serveur ou PostHog Activity : **aucun** appel neuf ; les seuls événements neufs sont ceux de Bulle-24, Visite-20 et Privé-13, à propriétés fermées. |
| Boutique-4 | **Aucune permission neuve** | « Copier le numéro » ne demande rien ; aucune invite système n'apparaît pour la bulle, la visite ou la feuille. |
| Boutique-5 | **Data Safety / App Privacy inchangés** — les six faits du pack | Lien `wa.me` sans donnée personnelle (écran, sujet choisi et, pour les aides de la 55, des données publiques du catalogue) ; identifiants fermés ; aucun nouvel hôte ; aucun formulaire ; aucune transmission aux écoles ; état de la visite local (`docs/release-56-store-pack.md` §5). Un seul ✗ et « inchangé » tombe : prévenir avant de remplir les consoles. |
| Boutique-6 | **Clé PostHog et `AD_ID`** (à refaire sur la 56) | `${#POSTHOG_API_KEY}` avant la construction ; `scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --posthog-only` juste après (une seule clé, longueur plausible) ; `strings … \| grep -c '^phc_'` = **1** sur l'archive ; `AD_ID` absent du manifeste fusionné de l'AAB. |
| Boutique-7 | **Aucune dépendance, aucun manifeste** | `git diff` vide sur `pubspec.lock`, `ios/Runner/Info.plist`, `ios/Runner/PrivacyInfo.xcprivacy`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle` (commandes du pack §6). |
| Boutique-8 | **Les notes de revue disent la vérité** | Relire le texte du pack §3 point par point contre ce qu'on a vu : tout est **éteint** à la soumission (relecteur = vitrine) ; les messages ne contiennent aucune donnée personnelle (écran, sujet choisi ; formation, université, ville et filtres pour les aides de la 55) ; la visite est locale ; la mention de non-affiliation est dans l'app. |
| Boutique-9 | **Captures et compte de démonstration** | Les captures de la soumission **ne montrent ni hub, ni bulle, ni visite, ni feuille** ; le compte de démonstration (étudiant) est **exclu des listes d'appel**. |
| Boutique-10 | **L'installation est la build soumise** | Version lue dans TestFlight / Play Console (pas dans l'app, qui n'affiche pas sa version) : **2.3.0 (56)**, pas la 55 (toujours listée dans TestFlight, abandonnée) ; `versionCode` côté Android : 56, jamais celui de l'AAB de la 55. |

## Signature

Appareils (modèle + OS), build soumise (numéro, source : TestFlight / Play Internal), date,
voie de recette (fenêtre sur la production, backend local, mandataire), et ce qui a échoué ou
n'a pas été joué (**[EN, build de travail]**, Visite-4, WhatsApp Business, iPad…). Un ✗
non résolu bloque la soumission. **Bulle-11** et **Bulle-12** sont les seules vérifications qui
peuvent changer le code (la longueur des messages) : les noter avec le nombre de caractères
observé. Les cas **Privé-4** et **Privé-6** dépendent de la décision (c) du pack
(`docs/release-56-store-pack.md` §7 ; la (a), la rémunération, est tranchée) : les signer avec la version du texte effectivement
installée.
