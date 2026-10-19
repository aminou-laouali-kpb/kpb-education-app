# Build 56 — pack de soumission : ce que la 56 ajoute, notes de revue recomptées, réponses de console, décisions ouvertes

> **⚠️ REMPLACÉE par la 57 le 18/10/2026 : suivre `docs/mise-a-jour-57-checklist.md`.**
> La 2.3.0 est en vente (App Store depuis le 07/10/2026, et Google Play : constat du 16/10/2026) ;
> la build suivante est la `2.3.1 (57)` (`pubspec.yaml`, préflights et registre posés le 18/10/2026).
> À VALIDER (propriétaire) : que la build en vente est bien la 56, sa date de téléversement et le
> SHA archivé (`docs/release-ledger.md`, ligne `56`). Le contenu ci-dessous est conservé tel
> qu'écrit ; pour tout numéro de version ou de build à venir, lire 57. Les papiers de la 57 :
> `docs/release-57-store-pack.md`, `docs/device-qa-build57.md`.

> **À quoi sert ce fichier.** La 56 est la build qui porte, en plus de ce que portait la 55
> (abandonnée, voir ci-dessous), trois éléments **dormants** de l'espace « Études en France » : la **bulle verte WhatsApp**, la
> **visite guidée** du hub et la **feuille « écoles privées »**. Ce fichier rassemble ce
> qu'il faut *coller* dans les consoles pour elle — notes de revue Apple **recomptées**,
> « What to Test », réponses aux formulaires de confidentialité — et la liste des
> **décisions du propriétaire** qui restent ouvertes avant d'allumer les interrupteurs. Il
> **complète** `docs/release-55-store-pack.md` (notes de version, fiche Google Play, preuves,
> décision XC-03) et **remplace son §3** : le bloc du §3 ci-dessous est le texte COMPLET de
> « Notes for Review » (bloc de `store-listing-copy.md` §7.1 raccourci **et** addendum), à
> coller seul — ne pas y ajouter l'ancien addendum.
>
> **État au 05/10/2026.** Décision du propriétaire (« 56 ») : la 56 est la **seule build 2.3.0
> à envoyer** ; la 55 — téléversée sur App Store Connect le 04/10/2026, **jamais soumise**, AAB
> jamais importé dans Play — est abandonnée (`docs/release-ledger.md`, ligne `56` sous
> « Courant »). `pubspec.yaml` porte la version de la 56 ; elle est **non archivée, non
> soumise**, et part avec la version marketing **2.3.0** (§1.2). Le code : interrupteurs serveur
> (#319), bulle (#320), feuille « écoles privées » (#321), visite guidée (#322), retrait de
> l'avertissement de suspension (#324, #326) ; les papiers (#323) et la préparation de la
> version, des préflights, du registre et de `docs/mise-a-jour-56-checklist.md` (l'ordre exact
> des opérations d'archive) viennent ensuite.
>
> **Règle qui gouverne tout le reste** (`store-listing-copy.md`, « Règle appliquée à chaque
> phrase ») : *toute fonctionnalité vantée doit être atteignable le jour de l'approbation.* La
> 56 part **espace fermé**, comme la 55 (décision XC-03, état A) : les notes de version ne
> citent ni la bulle, ni la visite, ni les écoles privées.
>
> **Rien de ce qui suit ne s'envoie sans le feu vert explicite du propriétaire.** Ce fichier
> prépare des textes ; il ne soumet rien, n'archive rien, n'allume aucun interrupteur.

---

## 1. Ce que la 56 ajoute — et ce qu'on en voit le jour de l'approbation

| Élément | Où | Il faut, pour le voir | Ce qu'en voit le relecteur Apple (état A) |
|---|---|---|---|
| **Bulle verte WhatsApp** : un cercle de 56 dp qui ouvre une liste de messages prêts à envoyer (4 sujets (5 avec les écoles privées), 2 pour un compte dont le pays est suspendu) | Hub et catalogue **seulement** (jamais la vitrine, les outils, l'écran des parents) | `features.eefSpace` **et** `features.eefHelpBubble` vrais, compte étudiant ou invité | **Rien** : `eefSpace` est faux |
| **Visite guidée** : 3 ou 4 cartes, une seule fois, rejouables par « ? » | Hub réel, à sa première ouverture | `features.eefSpace` vrai. **Pas d'interrupteur à elle** : elle s'allume avec le hub | **Rien** |
| **Feuille « écoles privées »** : information (conditions, frais, démarches officielles, qui est KPB) puis bouton vers WhatsApp | Ligne de l'état « aucun résultat » du catalogue, et option du menu de la bulle | `features.eefSpace` **et** `features.eefPrivateSchools` vrais, **compte dont le pays n'est pas suspendu** | **Rien** |

Les deux interrupteurs sont **fermés par défaut** (clé absente = faux ; ancien backend = faux ;
repli compilé = faux) et **indépendants** l'un de l'autre et de l'espace : les allumer ne passe
que par `vps-ops` (`eef-bubble-on` / `-off`, `eef-private-schools-on` / `-off`), sans nouvelle
soumission (`docs/runbook-ouverture-espace-reel.md`). **La 56 n'ajoute donc rien de visible
hors drapeau** : le relecteur voit la vitrine de la 53 comme avec la 55. C'est précisément ce
que la guideline 2.3.1 demande de **déclarer** (§3).

**Ce que la 56 n'ajoute pas** : aucune dépendance Flutter ni native, aucun changement de
`pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock`, `ios/Runner/Info.plist`,
`android/app/src/main/AndroidManifest.xml` (à prouver sur le SHA final, §6) ; aucun nouvel hôte ;
aucun formulaire ; aucune transmission aux écoles.

### 1.1 Longueur réelle des liens WhatsApp de la 56

Mesurée le 05/10/2026 par script sur `lib/app/core/translations/app_translations.dart`, puis
recomptée le 06/10/2026 après le retrait de la phrase de rémunération (les 70
clés `eef_help_bubble_*` et `eef_help_private_*` — 72 avant le retrait, en FR et en EN, de
la clé de la phrase de rémunération —, les messages des deux langues, des deux
écrans — hub et catalogue — et des deux jeux, standard et neutre) :

| | Valeur |
|---|---|
| Message le plus long | **183** points de code (écoles privées, catalogue, français) |
| Le même, encodé dans le lien (`Uri.encodeComponent`) | **260** caractères |
| Lien complet `https://wa.me/33768674292?text=…` le plus long | **291** caractères |
| Bornes du code (`EefHelpMessages`) | 520 points de code, 1 800 encodés |

Les messages de la 56 sont **statiques** (aucune formation, aucun filtre cité) et très en
dessous des bornes. La limite réelle de `wa.me` n'a, elle, **jamais été mesurée sur
appareil** : c'est le cas Bulle-11 de `docs/device-qa-build56.md`.

### 1.2 La 55 n'a jamais été soumise : la 56 garde 2.3.0

État réel d'App Store Connect au 05/10/2026 : la 55 est **téléversée seulement** (TestFlight,
04/10/2026 à 01 h 20) et **jamais soumise** à la revue. Décision du propriétaire : on n'envoie
que la 56 (décisions f et g, §7).

| Question | Réponse retenue |
|---|---|
| Version marketing | **2.3.0** reste valable : la 2.2.0 est en vente depuis le 13/09/2026 et aucune 2.3.0 n'a été soumise, donc 2.3.0 > version en vente (**ITMS-90062** ne se produit pas) |
| Fiche de version App Store Connect | La version **2.3.0** reçoit la **build 56 à la place de la 55** (dans la fiche, choisir la 56) ; la 55 reste dans TestFlight, non rattachée |
| Notes de version | Celles de la 55, à l'identique (`release-55-store-pack.md` §2.1) : la 56 n'ajoute rien de visible hors drapeau |
| AAB Android | Celui du run de `RELEASE` (la 56). **Jamais** celui de la 55 (run 37322572087) ni celui de la 54 (run 36945000021) |

Les autres états possibles de la 55 (en revue, approuvée) ne se sont pas produits et ne sont
pas traités ici : si la 55 devait un jour être soumise, la version marketing de la 56 devrait
être strictement supérieure (ITMS-90062) et ce pack serait à rouvrir.

---

## 2. Notes de version

### 2.1 Notes de version de la 56 (la 55 n'a jamais été soumise)

**Reprendre à l'identique `docs/release-55-store-pack.md` §2.1** (App Store FR/EN, Google
Play ≤ 500 caractères) : la 56 n'ajoute rien de visible hors drapeau, donc **rien à
ajouter** — ni la bulle, ni la visite, ni les écoles privées (guidelines 2.3.1 / 2.3.3). Les
lignes facultatives A et B du pack de la 55 (§2.2) restent au choix du propriétaire.

### 2.2 Les textes « stabilité et performance » ne servent pas

Ils étaient prévus pour une 56 publiée **après** une 55 déjà en vente. La 55 n'ayant jamais été
soumise, c'est la 56 qui est la première 2.3.0 : ses notes de version sont celles du §2.1, pas
une simple mention de stabilité.

### 2.3 TestFlight — « What to Test » (testeurs internes)

Pour des testeurs **internes** seulement. Le hub, la bulle, la visite et la feuille sont
**invisibles** tant que `eefSpace` est faux en production : voir la fenêtre de recette
(`docs/device-qa-build54.md` §B, voie 2 ; `docs/device-qa-build56.md`, « États serveur »).

```
FR — Build 56
En plus de la 55 (docs/device-qa-build54.md, docs/device-qa-build55.md) :
1. Hub (espace ouvert) : à la PREMIÈRE ouverture, une visite de 3 ou 4 cartes s'affiche. « Passer » la ferme ; le « ? » de la barre la rejoue. Elle ne revient pas après avoir tué et relancé l'app.
2. Hub et catalogue (bulle allumée) : un cercle vert en bas à droite. Tap : 4 sujets (5 avec les écoles privées, 2 pour un compte du Niger), chacun montre le message qui sera écrit. WhatsApp s'ouvre avec ce message, modifiable ; rien n'est envoyé sans toi.
3. Catalogue, recherche sans résultat (écoles privées allumées, compte hors Niger) : une ligne « Les écoles privées : ce qu'il faut savoir » ouvre une feuille d'information, puis un bouton « En parler à un conseiller ».
4. Compte du Niger : ni mention d'école privée, ni sujet « dossier ».
Chaque message doit arriver ENTIER dans WhatsApp et WhatsApp Business.
```

```
EN — Build 56
On top of build 55:
1. Hub (space open): on FIRST open, a 3 or 4 card tour appears. "Skip" closes it; the "?" in the bar replays it. It must not come back after killing and relaunching the app.
2. Hub and catalogue (bubble on): a green circle at the bottom right. Tap: 4 topics (5 with private schools, 2 for a Niger account), each showing the message that will be written. WhatsApp opens with that message, editable; nothing is sent without you.
3. Catalogue, search with no result (private schools on, non-Niger account): a "Private schools: what to know" line opens an information sheet, then a "Talk to an advisor" button.
4. Niger account: no private-school mention, no "application" topic.
Each message must arrive WHOLE in WhatsApp and WhatsApp Business.
Note: the app interface is French only on the submitted build.
```

---

## 3. « Notes for Review » Apple — le texte COMPLET (guideline 2.3.1)

Le champ est limité à **4 000 caractères** (à vérifier à la saisie dans App Store Connect). Le
pack de la 55 laissait une cinquantaine de caractères ; la 56 doit y décrire **en plus** la
bulle, la visite et la feuille « écoles privées » comme des éléments **dormants**, activables
à distance. Le texte ci-dessous **remplace** le bloc de `store-listing-copy.md` §7.1 **et**
l'addendum du pack 55 : à coller **seul**, en anglais (les relecteurs lisent l'anglais). Les
paragraphes sont continus (sans retour à la ligne forcé : chaque retour compte pour un
caractère).

<!-- notes-for-review: chars=3947 bytes=3954 reserve=160 -->

```
SIGN-IN
This app has no password: sign-in is Google OAuth or a one-time code sent by email. Demo account: <ADDRESS> — the code can be read at <METHOD>. Most of the app (Home, Universities, tools, Journeys) works without an account via "Explorer sans compte" on the welcome screen; an account is only needed for the Scholarships tab and to open a case.

LANGUAGE
The interface is French only in this version. The English store listing is a storefront translation.

NO IN-APP PURCHASE
There is no in-app purchase, subscription or checkout anywhere in the app or the backend, and no card details are requested. Paid KPB guidance packages are human services (a counsellor reviews a CV, letters or an application file); their FCFA price is shown for information, the button opens WhatsApp to reach a counsellor, and payment is arranged outside the app. "Premium" is a "coming soon / arrange with an advisor" screen with no price or billing state; its free waiting-list button records only the account id, a timestamp and the consent notice shown, and can be undone from the same screen.

AI FEATURES
Six features call a third-party LLM (OpenRouter and Groq, United States): the assistant "KPB Intelligence", the orientation questionnaire and four writing tools (CV summary, motivation letter, interview practice, document review). All six sit behind an explicit, timestamped in-app AI consent dialog enforced server-side on every route; a declared minor also needs a guardian's recorded consent. The assistant has a weekly free quota. Answers are presented as indicative, not a substitute for a counsellor or official information. Text pasted into the writing tools is forwarded as written to produce the draft (a pasted CV may contain a name); the app never adds the student's name or profile identity to a prompt. Prompts are not used for provider training (zero-data-retention routing, data collection denied).

USER-GENERATED CONTENT
No public feed, forum or user-to-user messaging. A student writes only to the KPB advisor assigned to their own case. A parent can read a case only if the student turns on sharing for it, and cannot post.

AGE
Accounts require 16+. Under 18, a guardian's name, contact and consent are required before the profile can be completed.

REMOTELY ACTIVATED FEATURES (guideline 2.3.1) — "Études en France" space.
This version adds a section to prepare an application to French public universities: a programme catalogue with filters, a short tour shown once on first opening, and "ask for help" buttons that open WhatsApp to a KPB advisor with a prefilled message naming what the student was looking at (programme, university, city, filters, tool or screen) — never their name, email, phone or country name; the student reads, edits and sends it. The section is switched on from our server (flag eefSpace in api.kpbeducation.cloud/api/config/app) and is OFF at review time: the reviewer sees the "coming soon" showcase and a free "I am interested" form.
Two parts have their own server switches, both OFF at review time and effective only when eefSpace is ON: features.eefHelpBubble, a green round button (hub and catalogue) that opens a list of ready-made WhatsApp messages; and features.eefPrivateSchools, an information sheet on private schools (conditions, fees, official steps, who KPB is) with a button to WhatsApp. Neither adds a permission, SDK, host or data type (only analytics events, already declared). Also remote: a dismissible "update available" banner (recommendedVersion, unset now).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service, not affiliated with Campus France or any French administration, and does not process applications. The demo account is a test account: its declarations are excluded from our advisors' call lists.
```

**Décompte (script, 05/10/2026).** Texte avec les marqueurs `<ADDRESS>` et `<METHOD>`
remplacés par la place qu'on leur réserve — **40** caractères pour l'adresse du compte de
démonstration, **120** pour la méthode de lecture de son code — : **3 947 caractères**
(3 954 octets en UTF-8), soit **53 caractères sous la limite**. Sans les marqueurs :
3 787 caractères. Le test `test/release/store_pack_56_test.dart` refait ce calcul à chaque
exécution, compare au commentaire ci-dessus et exige au moins 50 caractères de marge. **Si
l'adresse ou la méthode dépasse sa réserve, recompter avant de coller.**

**Ce qui a été coupé pour faire de la place** (par rapport au bloc §7.1 + addendum du 03/10,
2 923 + 1 025 = 3 950 caractères) — décision du propriétaire, à relire :

| Coupé ou condensé | Pourquoi c'est sans perte |
|---|---|
| Retours à la ligne forcés (≈ 40) | Les paragraphes sont continus : même texte |
| « NO IN-APP PURCHASE » : formules condensées, détail de la liste d'attente Premium réduit à ce qu'elle enregistre | Les trois faits restent : pas d'achat intégré, prix FCFA affiché à titre d'information et renvoi vers WhatsApp, liste d'attente gratuite sans prix |
| « AI FEATURES » : formules condensées | Restent : six fonctions, destinataire, consentement horodaté et serveur, mineur, quota, caractère indicatif, texte collé transmis tel quel, pas d'entraînement |
| « USER-GENERATED CONTENT », « LANGUAGE » : condensés | Restent : pas de fil public, un étudiant n'écrit qu'à son conseiller, accès parent par partage ; interface en français seulement |
| L'addendum de la 55 : refondu (une seule section « REMOTELY ACTIVATED FEATURES ») | Il décrit maintenant les **trois** éléments distants |

**Jamais coupé, et gardé par le test** : la déclaration d'activation à distance pour `eefSpace`,
`features.eefHelpBubble` et `features.eefPrivateSchools` (état *OFF at review time*), la
bannière « mise à jour disponible », la **non-affiliation** (« NOT AFFILIATED WITH ANY
GOVERNMENT »), l'exclusion du compte de démonstration des listes d'appel.

**À contrôler avant de coller**, sur le SHA final (les cinq points du §3 de la 55 valent
toujours — `release-55-store-pack.md` §3) :

1. « a prefilled message naming what the student was looking at (programme, university, city,
   filters, tool or screen) — never their name, email, phone or country name » : les aides de
   la 55 citent l'intitulé, l'université, la ville, les filtres ou l'outil (données publiques du
   catalogue) ; les messages de la bulle et de la feuille (56) ne nomment que l'**écran**
   (« l'espace Études en France de l'app » ou « le catalogue… ») et le **sujet choisi**. Pour un
   compte dont le pays est suspendu, ils disent que la procédure est suspendue « dans mon pays »
   **sans nommer le pays**. À vérifier : `docs/device-qa-build56.md`, Bulle-5 à Bulle-9 et Privé-6.
2. « Neither adds a permission, SDK, host or data type (only analytics events,
   already declared) » : les commandes du §6 (aucun changement de dépendance ni de manifeste) et
   `docs/analytics-event-contract.md` (propriétés fermées). La phrase ne dit **pas** « ne
   collecte rien » : la bulle, la feuille et la visite émettent des événements d'analytique
   (`eef_bubble_opened`, `eef_private_info_opened`, `eef_help_cta_tapped`, `whatsapp_handoff`,
   `eef_tour_shown`, `eef_tour_completed`), déjà couverts par « Activité dans l'app ». La
   bulle dessine une icône Material et n'ouvre que `wa.me`, déjà utilisé.
3. « a short tour shown once on first opening » : le drapeau de la visite est **local à
   l'appareil** (`kpb_relaunch_v1.eef_tour_v1`) et n'est jamais transmis.
4. Le texte dit « features.eefPrivateSchools, an information sheet on private schools » : il
   ne dit **ni** que KPB est rémunéré par des écoles, **ni** « partenaire ». La décision (a),
   §7, est **tranchée le 06/10/2026** : la phrase de rémunération est retirée de l'**app** ; la
   feuille et le texte à coller disent la même chose (KPB ne se présente pas comme rémunéré
   par des écoles). Rien à changer ici.
5. **Compte de démonstration** : un compte **étudiant** (le hub n'est pas montré à un parent),
   **exclu des listes d'appel** (admin → liste d'intérêt) — la dernière phrase du texte le
   promet. **Décision D1** de `store-listing-copy.md` §9 (comment lire le code à usage unique)
   toujours ouverte : sans elle, `<METHOD>` n'a pas de valeur.

---

## 4. Google Play

**Un texte propre à la 56 (FR et EN ci-dessous), à coller à la fin des descriptions longues
(`store-listing-copy.md` §5.1 / §6.1)** à la place de celui de `release-55-store-pack.md` §4
(« Government apps » : *non*, inchangé). La non-affiliation et la source officielle y sont
reprises telles quelles ; **la fin de phrase « les dates et suspensions affichées dans l'app
renvoient à leur source officielle » est retirée** : la 56 n'affiche plus aucune suspension
(#324, #326), et le seul lien qui reste dans l'app est « Voir la plateforme officielle ». Une
fiche qui vante une suspension affichée décrirait une fonction absente (guideline 2.3.1).

**FR**
```
KPB Education est un service privé d'accompagnement. Il n'est affilié ni à Campus France, ni à l'État français, ni à aucune administration, et ne représente aucune entité gouvernementale. Les candidatures se déposent auprès des services officiels, selon la procédure de chaque formation (plateforme Études en France, demande d'admission préalable) : https://www.campusfrance.org/fr — l'app renvoie vers la plateforme officielle.
```

**EN**
```
KPB Education is a private guidance service. It is not affiliated with Campus France, the French government or any administration, and does not represent any government entity. Applications are submitted through the official channels, depending on each programme (Études en France platform, pre-admission request): https://www.campusfrance.org/fr — the app links to the official platform.
```

Ne pas annoncer
la bulle, la visite ni les écoles privées dans la fiche tant que l'espace est fermé (même règle
que le §2).

---

## 5. Réponses de console : ce qui change, et ce qui ne change PAS

**Data Safety (Play) et App Privacy (Apple) : inchangés pour la 56**, *sous réserve* que les
six faits ci-dessous restent vrais sur le SHA final (le §6 dit comment le prouver). Si l'un
tombe, le « inchangé » tombe avec lui.

| # | Fait | Preuve | Effet sur les consoles |
|---|---|---|---|
| 1 | Chaque envoi est un **lien `wa.me` dont le texte ne contient aucune donnée personnelle** (ni nom, ni e-mail, ni téléphone, ni pays, ni niveau, ni budget). Il porte l'écran (« l'espace Études en France de l'app », « le catalogue… »), le **sujet choisi** (dossier, choisir, écoles privées, procédure suspendue) et, pour les **aides de la 55**, des données **publiques** du catalogue : intitulé de la formation, université, ville, filtres posés, outil (`EefHelpMessages`). Le chemin est le point d'entrée commun (`kpbWhatsAppPrefill(custom:)` puis `openWhatsAppOrToast`) | `lib/app/features/etudes_en_france/eef_help_bubble.dart`, `eef_private_schools_sheet.dart`, tests `eef_help_bubble_test.dart`, `eef_private_schools_test.dart` | Aucun. Même ligne « WhatsApp / Meta » du §5 de `CONSOLE_ANSWERS.md` : remise externe, pas un sous-traitant, **aucun SDK Meta** |
| 2 | Les **identifiants analytiques sont fermés** : `eef_bubble_opened` {`surface`}, `eef_private_info_opened` {`entry`}, `eef_tour_shown` {`tour_trigger`}, `eef_tour_completed` {`tour_exit`, `tour_cards_seen`}, et les deux événements existants `eef_help_card_shown` / `eef_help_cta_tapped` qui gardent **exactement** leurs trois propriétés. Valeurs en liste close (`hub`/`catalog`, `bubble_assistance`…), jamais un texte libre, un pays, ni la suspension : un compte suspendu produit les **mêmes** identifiants | `docs/analytics-event-contract.md`, `analytics_event_contract_test.dart` | Aucun : « Activité dans l'app » est déjà déclarée (PostHog et Firebase) |
| 3 | **Aucun nouvel hôte** : la bulle dessine une icône Material, la feuille et la visite sont locales ; la seule sortie est `wa.me` | `git diff` sans nouvelle URL ; pas de `Image.network` neuf | Aucun nouveau destinataire (§5 de `CONSOLE_ANSWERS.md` inchangé) |
| 4 | **Aucune transmission aux écoles**, aucun formulaire, aucun champ : la feuille informe puis ouvre WhatsApp. Elle n'ouvre pas `FrancePrivateAdmissionScreen` (dont le bouton crée un dossier et envoie des coordonnées aux commerciaux) ; la liste d'intérêt et le profil EEF ne servent pas à cibler | tests `eef_private_schools_test.dart` ; `docs/eef-consent-v1.md` (note de la 56) | Aucun. **Ne pas** confondre avec XC-06 ci-dessous |
| 5 | **L'état de la visite est local** : un booléen dans les préférences de l'appareil (`kpb_relaunch_v1.eef_tour_v1`), jamais transmis, non personnel (il survit à la suppression du compte, sans conséquence) | `eef_tour_store.dart`, `eef_tour_test.dart` | Aucun |
| 6 | **Aucune dépendance, aucun manifeste** ne bouge | `git diff` vide, §6 | Aucun |

**Ce qui change dans les papiers** (pas dans les formulaires) : le texte de « Notes for
Review » (§3) ; la ligne « WhatsApp / Meta » de `CONSOLE_ANSWERS.md` §5, qui nomme maintenant
aussi le **sujet choisi** dans la bulle (toujours sans donnée personnelle) ; la note de
`docs/eef-consent-v1.md`.

**Deux points restent ouverts et doivent être tranchés AVANT la soumission** (§7, e) :

- **XC-06 — finalité « Marketing »** (`CONSOLE_ANSWERS.md` §0quater). La politique publiée dit
  que l'équipe commerciale lit les déclarations d'intérêt. Les consoles déclarent « Fonctionnalité
  / Compte » seulement. Recommandation inchangée : ajouter la finalité *Marketing* (Play :
  « Advertising or marketing » ; Apple : « Developer's Advertising or Marketing »). La 56 ne
  change pas la question, mais la feuille « écoles privées » (un service privé, sans mention de
  rémunération par les écoles : décision a, tranchée) la rend plus visible à un lecteur attentif.
- **D5 — prix FCFA affichés** (`store-listing-copy.md` §9). Les notes de revue disent que le prix
  des paquets est affiché à titre d'information et que le bouton ouvre WhatsApp ; c'est le
  point que la revue regardera. La bulle et la feuille n'affichent **aucun prix** (garde de
  tests) et ne s'approchent d'aucun bouton d'achat.

---

## 6. Preuves à joindre, et contrôles à refaire sur la 56

En plus du §5 de `release-55-store-pack.md` (captures **sans** hub, préflights, run de
Flutter CI, préflight de release, dSYM, questionnaires, signalements IA, installation = build
soumise) :

```bash
# La version à archiver est posée (la préparation de la 56 l'a faite) : version: 2.3.0+56
git show "$RELEASE:pubspec.yaml" | grep '^version:'
# Aucune dépendance ni manifeste n'a bougé depuis la production : ne doit RIEN afficher
git diff --stat 0641601 "$RELEASE" -- pubspec.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle
# pubspec.yaml : seule la ligne « version: » change (-2.3.0+54, +2.3.0+56)
git diff -U0 0641601 "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^[+-]#' | grep -v '^+++\|^---'
# Podfile.lock : seule la somme de contrôle du Podfile (voir la checklist, étape 0)
git diff -U0 0641601 "$RELEASE" -- ios/Podfile.lock | grep '^[+-]' | grep -v '^+++\|^---'
# L'espace et les deux interrupteurs sont fermés au moment de soumettre :
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools}'
# attendu : false, true, false, false, false (les deux dernières clés peuvent être ABSENTES
# si le backend déployé est antérieur : absent = fermé)
```

Contrôles **qui dépendent de l'artefact**, à refaire sur la 56 (ils ne se déduisent pas du
dépôt) :

- **Clé PostHog** — trois contrôles complémentaires, depuis la copie propre de `RELEASE` :
  `${#POSTHOG_API_KEY}` **avant** la construction, `scripts/preflight-ios-archive.sh --xcconfig
  ios/Flutter/Generated.xcconfig --posthog-only` **juste après** (une seule clé `phc_`, 30 à 60
  lettres ou chiffres, jamais affichée), et `strings … | grep -c '^phc_'` = **1** sur
  l'archive. Le dernier ne voit **pas** une clé doublée ; c'est pourquoi les deux premiers
  existent (`docs/mise-a-jour-56-checklist.md`, étape 3).
- **`AD_ID` absent** du manifeste fusionné de l'AAB (`scripts/preflight-android-aab.sh`).
- Sorties des deux préflights à la **version de la 56** : les scripts épinglent
  `EXPECTED_BUILD` / `EXPECTED_VERSION` (iOS) et `EXPECTED_VERSION_CODE` (Android) ; ils se
  sont **posés à 56** par la préparation de la version (`pubspec.yaml`, registre) : le test
  `test/release/artifact_signing_contract_test.dart` les lit.

---

## 7. Décisions du propriétaire — encore ouvertes avant d'allumer les interrupteurs

Les décisions **a**, **f** et **g** sont tranchées (a le 06/10/2026, f et g le 05/10/2026) ; les
autres restent ouvertes. Pour chacune : la recommandation retenue dans le plan, ce qui la rend
urgente, et **où** elle s'applique. **Attention au calendrier** : une décision qui change un
texte **compilé** (c) doit être prise **avant l'archive** de la 56 ; après, la seule action
côté serveur est de laisser le drapeau fermé.

| | Décision | Recommandation | Ce qu'elle déclenche |
|---|---|---|---|
| **a** | **KPB est-il rémunéré par des écoles privées ?** | Décision **tranchée le 06/10/2026 : la phrase est retirée** (« Pourquoi la question de la rémunération se pose même pour les écoles privées ? » — propriétaire). KPB ne se présente pas comme rémunéré par des écoles ; aucun nom d'école en 56, jamais « partenaire » ni « sponsorisé » non prouvé. Si cela change un jour, une mention de transparence devra être réintroduite AVANT d'allumer l'interrupteur | Rien à faire : la feuille « écoles privées » ne contient plus aucune phrase de rémunération (le point 4 dit seulement que KPB est un service privé, pas un service de l'État). Retirée du code, des tests et des papiers de la 56 ; `eefPrivateSchools` reste fermé jusqu'à la validation juridique des autres textes (b, c) |
| **b** | **Comptes du Niger (pays suspendu) : aucune mention d'école privée** | **Oui, retenu.** Ni ligne, ni option, ni feuille ; bulle présente avec un menu neutre à 2 lignes ; visite : seule l'étape 1 a sa variante neutre | Déjà codé (`EefHelp.isSuspended()`). Reste à demander au juridique si le privé échappe à la suspension : tant que ce n'est pas établi, en parler suggérerait une voie de remplacement non validée |
| **c** | **« Les frais sont en général plus élevés que dans le public »** ou son repli « Les frais varient beaucoup d'une école à l'autre » | Garder la phrase comparative **avec relecture juridique** avant d'allumer `eefPrivateSchools` ; sinon le repli | Compilé (`_useFeesFallback`, clé `eef_help_private_point_fees_fallback`, non affichée par défaut) : à trancher **avant l'archive** |
| **d** | **Qui répond au +33768674292, à quelles heures ?** Étiquettes WhatsApp Business par sujet, message d'absence | Oui aux étiquettes (une par sujet : *assistance, dossier, choisir, écoles privées, autre question*) et au message d'absence, **sans promesse de délai dans l'app**. **Ne pas allumer `eef-bubble-on` tant qu'une personne n'est pas nommée** | Hors app (WhatsApp Business). `whatsapp_handoff` **surévalue** les conversations (le lancement est tenté, jamais précédé de `canLaunchUrl`) : les étiquettes sont le seul moyen de qualifier. Revue humaine à 14 jours après l'ouverture |
| **e** | **XC-06** (finalité Marketing) **et D5** (prix FCFA affichés) | À trancher **avant la soumission** (§5) | Consoles et notes de revue |
| **f** | **Quelle build envoyer, et ouvre-t-on l'espace avec la 55 ?** | **Tranchée le 05/10/2026 : la 56 seule**, puisque la 55 est abandonnée (jamais soumise) ; aucune build qui contient le hub n'est en vente, donc **l'espace s'ouvrira avec la 56** et l'utilisateur a bulle et visite dès l'ouverture | `docs/mise-a-jour-56-checklist.md` ; `docs/ouverture-espace-eef.md` §2.3 et §6 |
| **g** | **Version marketing de la 56** | **Tranchée : 2.3.0 gardée.** Elle est strictement supérieure à la 2.2.0 en vente (**ITMS-90062**) tant qu'aucune 2.3.0 n'a été soumise : c'est le cas, la 55 ne l'ayant jamais été | `pubspec.yaml`, les deux préflights, le registre : posés par la préparation de la 56 |

**Ordre d'allumage** (`docs/runbook-ouverture-espace-reel.md`) : `eef-space-on`, puis
`eef-bubble-on` (après d), puis `eef-private-schools-on` (après a, b, c et idéalement quelques
jours après le hub pour ne pas mêler les signaux). Fermeture dans l'ordre inverse, chacune
indépendante.

---

## 8. Ce que ce pack ne tranche pas, et ce qu'il n'a pas pu vérifier

| Question | Qui | Où |
|---|---|---|
| Les décisions a à g | Propriétaire (a, d, e, f, g), juridique (a, b, c, e) | §7 |
| Tranche d'âge (D2), compte de démonstration (D1) | Propriétaire | `store-listing-copy.md` §9 |
| Revue accélérée Apple | Propriétaire : l'urgence est faible en état A | LIV-10 |
| Que la build 55 reste dans TestFlight, non rattachée, n'empêche pas de choisir la build 56 dans la fiche de version 2.3.0 (§1.2) | À constater dans la console au moment de soumettre | `docs/mise-a-jour-56-checklist.md`, étape 7 |
| Les cas de `docs/device-qa-build56.md` | **Jamais joués sur appareil** : le simulateur iOS ne compile pas avec Flutter 3.44.1 + Xcode 27 (`docs/mise-a-jour-56-checklist.md`, étape 1). Seuls les tests de widgets ont tourné | Recette sur TestFlight / Play Internal |
| **L'anglais n'est pas atteignable sur la build soumise** | Constat : `kShippedLocale = 'fr'` (`lib/app/core/i18n/app_locale.dart`) ramène toute préférence au français et le sélecteur FR/EN est masqué. Les textes anglais de la bulle, de la visite et de la feuille sont gardés par des **tests de parité**, mais aucun appareil ne peut les afficher avec l'artefact soumis | `docs/device-qa-build56.md`, « Langue » |
