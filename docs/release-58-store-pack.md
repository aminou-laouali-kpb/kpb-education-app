# Build 58 — pack de soumission : ce qui change par rapport au pack 57

> **⚠️ REMPLACÉE par la 59 le 09/11/2026 : suivre `docs/mise-a-jour-59-checklist.md`.**
> La `2.3.1 (58)` a été téléversée le 08/11/2026 (App Store Connect pour TestFlight, AAB en test
> interne Play ; commit archivé `5332a128`) et n'a jamais été soumise. Décision du propriétaire du
> 09/11/2026 : la version de lancement doit contenir davantage ; la build suivante est la
> `2.3.1 (59)`, même version marketing. Le contenu ci-dessous est conservé tel qu'écrit.

> **À quoi sert ce fichier.** La 58 est la 57 corrigée (audit UX externe du 28/10/2026) : même
> version marketing `2.3.1`, mêmes fonctions, mêmes drapeaux, mêmes déclarations. Le pack
> `docs/release-57-store-pack.md` **reste la référence** pour tout ce que ce fichier ne remplace
> pas : ce que la 57 embarque (§1), déclarations Play Data Safety et Apple App Privacy (§4),
> tableau des drapeaux (§5), déploiement par étapes et paliers (§6), décisions (§7). Ce fichier
> remplace **seulement** : les notes de version (§2 ci-dessous) et les « Notes for Review »
> (§3 ci-dessous), parce qu'un texte de la 57 n'est plus vrai sur la 58. L'ordre des opérations
> est dans `docs/mise-a-jour-58-checklist.md` ; la recette dans `docs/device-qa-build58.md`.
>
> **Pourquoi un pack 58, et pas le pack 57 tel quel.** Les notes de revue de la 57 disent
> `"Premium" is a "coming soon" screen`. Depuis #389, cet écran s'appelle **« Pass Karatou »**
> (titre de l'écran, carte du Profil, entrée parent) : le relecteur ne voit plus d'écran nommé
> « Premium » (le mot reste dans le corps de l'écran, §5). Rien d'autre dans le texte de la 57 n'est contredit par #387 ou #389 (relu phrase par
> phrase le 07/11/2026). Aucun numéro de build n'y figure.
>
> **Rien de ce qui suit ne s'envoie sans le feu vert explicite du propriétaire.**

---

## 1. Ce que la 58 ajoute à la 57

Tout est **app** et visible sans drapeau (sauf mention) ; le détail est au registre, entrée
« Préparation de la build 58 (07/11/2026) ».

| PR | Contenu |
|---|---|
| #387 | Les 9 correctifs app du top 10 de l'audit : plus de flèche ← fantôme ni d'écran noir après « Suivre » (n° 1) ; plus de faux bandeau « Données d'exemple » au lancement (n° 2) ; ☰ « Outils KPB » actif dès la 1re visite invité (n° 3) ; ni programme rémunéré proposé, ni profil « déjà partagé » promis, « Réponse sous 24 h » (n° 4 et 5a) ; feuille « Être accompagné » opaque (n° 5b) ; « Mes échéances » sans étapes génériques ni faux « 7 jours » (n° 7) ; une seule étiquette et frais en FCFA sur les écoles « compatibles » (n° 8) ; invité renvoyé au mur au lieu de « Erreur de connexion » (n° 9) |
| #389 | Quick wins A, B et C : murs invités « Créer mon compte gratuit », code par e-mail, boutons « Site officiel pour postuler », « Revoir le tutoriel » retiré, écran **« Pass Karatou »**, « Tableau d'impact » et « Estimateur de logement » masqués quand ils mènent à une impasse, contrastes, dossiers (filtre vide, un seul bandeau), indicatifs d'Afrique centrale, e-mails universitaires acceptés, heures des dossiers en heure locale, synchro du profil seulement s'il a changé, mur propre à KPB Intelligence, trois actions de l'écran d'entrée visibles sans défiler, liens légaux avant l'inscription, champ de recherche en tête de l'Accueil, barre d'état lisible, « tirer pour rafraîchir » qui garde la liste, chat au texte agrandi, nouvel essai de `/config/app` après un échec |

Côté serveur, déjà en production (sans build) : #392 (dossiers en français, clôtures à 20:59:59Z,
filières OMNES, nom « KPB Intelligence ») et #397 (réattribution des dossiers sans boucle).

**Ce que la 58 ne change pas dans le binaire** : `pubspec.lock`, `Info.plist`,
`PrivacyInfo.xcprivacy`, `AndroidManifest.xml`, `android/app/build.gradle` identiques à la 57 ;
aucun SDK, aucune permission, aucun hôte nouveau (checklist 58, étape 0.3).

---

## 2. Notes de version

La 2.3.1 n'a jamais été en vente : les notes de la 2.3.1 décrivent toujours l'écart avec la 2.3.0,
c'est-à-dire le texte du pack 57 §2. **Proposition** : y ajouter une dernière puce sur les
corrections visibles. À VALIDER (propriétaire) : la garder ou coller le texte du pack 57 §2 tel
quel (les deux sont vrais).

**App Store — FR**
```
Nouveautés :
• Suivre une bourse : un bouton « Suivre » sur chaque bourse pour être prévenu de son ouverture et avant sa date limite. Retrouve tes bourses dans « Mes suivis ».
• Notifications : une liste de tes notifications dans l'app, et un envoi plus fiable.
• Bourses : une liste plus lisible (statut, date de clôture, filtres et tri) ; les bourses déjà consultées restent lisibles sans connexion.
• Accueil : une seule carte « Ta prochaine étape » te dit quoi faire maintenant.
• Connexion : le code reçu par e-mail se colle plus facilement et se valide dès le 6e chiffre.
• Stabilité : la synchronisation de ton compte résiste mieux aux coupures de réseau.
• Corrections : retour après « Suivre », menu ☰ dès la 1re visite, plus de faux bandeau « connexion impossible » au lancement.
```

**App Store — EN**
```
What's new:
• Follow a scholarship: a "Follow" button on every scholarship to be notified when it opens and before its deadline. Find them in "My follows".
• Notifications: a list of your notifications in the app, and more reliable delivery.
• Scholarships: a clearer list (status, closing date, filters and sorting); scholarships you already viewed stay readable offline.
• Home: a single "Your next step" card tells you what to do now.
• Sign-in: the code received by email is easier to paste and is checked as soon as the 6th digit is typed.
• Stability: account sync copes better with network drops.
• Fixes: back navigation after "Follow", the ☰ menu on a first visit, and a false "cannot reach the server" banner at launch.
```

**Google Play — FR (500 caractères au plus)**
```
• Suivre une bourse : sois prévenu de son ouverture et avant sa date limite, retrouve-la dans « Mes suivis ».
• Une liste de tes notifications dans l'app, et un envoi plus fiable.
• Liste des bourses plus lisible (statut, filtres, tri), lisible hors connexion.
• Accueil : une carte « Ta prochaine étape ».
• Code de connexion plus simple à coller.
• Synchronisation plus robuste quand le réseau coupe.
• Corrections : retour après « Suivre », menu ☰ en 1re visite, faux bandeau de connexion.
```

Décompte du bloc Google Play : **492 caractères** (limite 500), refait par
`test/release/mise_a_jour_58_checklist_test.dart`.

---

## 3. « Notes for Review » Apple — le texte COMPLET (guideline 2.3.1)

Le texte ci-dessous **remplace** celui du pack 57 §3 : à coller **seul**, en anglais. Une seule
phrase change : `"Pass Karatou" is a "coming soon" screen` au lieu de `"Premium" is a "coming
soon" screen`. Les contrôles « à faire avant de coller » du pack 57 §3 (points 1 à 5 : espace
« Études en France », drapeaux « OFF at review time », autorisation au premier « Suivre »,
réponses du test, compte de démonstration) valent pour la 58, à refaire le jour même.

<!-- notes-for-review: chars=3940 bytes=3943 reserve=160 -->

```
SIGN-IN
This app has no password: sign-in is Google OAuth or a one-time code sent by email. Demo account: <ADDRESS> — the code can be read at <METHOD>. Most of the app (Home, Universities, tools, Journeys) works without an account via "Explorer sans compte" on the welcome screen; an account is needed for the Scholarships tab, to follow a scholarship and to open a case.

LANGUAGE
The interface is French only in this version. The English store listing is a storefront translation.

NO IN-APP PURCHASE
There is no in-app purchase, subscription or checkout in the app or the backend, and no card details are requested. Paid KPB guidance packages are human services; their FCFA price is shown for information, the button opens WhatsApp to reach a counsellor, and payment is arranged outside the app. "Pass Karatou" is a "coming soon" screen with no price; its free waiting-list button records only the account id, a timestamp and the consent notice shown.

AI FEATURES
Six features call a third-party LLM (OpenRouter and Groq, United States): the assistant "KPB Intelligence", the orientation questionnaire and four writing tools. All six sit behind an explicit, timestamped in-app AI consent enforced server-side; a declared minor also needs a guardian's recorded consent. Answers are presented as indicative. The app never adds the student's name to a prompt. Prompts are not used for provider training.

USER-GENERATED CONTENT
None reachable at review time: a student writes only to the KPB advisor of their own case, which a parent reads only if the student shares it. The community below is declared in the age rating and privacy answers.

AGE
Accounts require 16+. Under 18, a guardian's name, contact and consent are required before the profile can be completed.

NEW IN THIS VERSION
"Follow" on a scholarship saves it and sends a notification when it opens and before its deadline. Notification permission is never asked at launch: only after a short explanation, at the first "Follow". A "My follows" screen and an in-app notification list are added; viewed scholarships stay readable offline; Home shows one "next step" card. Push notifications now use Firebase Cloud Messaging; the OneSignal SDK is removed.

REMOTELY ACTIVATED FEATURES (guideline 2.3.1)
Switched from our server (api.kpbeducation.cloud/api/config/app). The "Études en France" space is open (flag eefSpace). OFF at review time: features.scholarshipMatch, a scholarship eligibility test (nationality, date of birth, diploma, grades, languages) that shows up to 10 scholarships, never a percentage; features.onboardingV2, a shorter sign-up flow; features.eefHelpBubble and features.eefPrivateSchools, WhatsApp help inside the space; features.referralOnboardingCode and features.referralLeaderboard, an optional referral-code step after sign-up and a referral contest screen for ambassadors registered by our team (organiser KPB Global L.L.C-FZ, official rules linked, Apple is not a sponsor, no prize amount shown in the app); features.community, a student Q&A (posts and replies seen by signed-in students; pre-publication filter holding contact details, money requests and links for staff review; report; block; rules accepted before posting; staff moderation; no private messages); features.assistBridge, a settings switch for private KPB-team suggestions. None adds a permission, SDK or host on iOS. Test answers are not sent to schools, analytics or notifications. Also remote: a dismissible "update available" banner (recommendedVersion).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service, not affiliated with Campus France or any French administration, and does not process applications. The demo account is a test account: its declarations are excluded from our advisors' call lists.
```

**Décompte (script, 07/11/2026).** Marqueurs `<ADDRESS>` et `<METHOD>` remplacés par la place
qu'on leur réserve — **40** et **120** caractères — : **3 940 caractères** (3 943 octets en
UTF-8), soit **60 caractères sous la limite** de 4 000. Le test
`test/release/mise_a_jour_58_checklist_test.dart` refait ce calcul et exige au moins 50 caractères
de marge.

**Drapeaux « OFF at review time »** : `community`, `assistBridge`, `referralOnboardingCode` et
`referralLeaderboard` valaient `true` le 27/10/2026 ; ils ont été **refermés le 07/11/2026**
(condition 2 de l'audit). Ils doivent valoir `false` le jour de la soumission (checklist 58,
étapes 2 et 8). Si la compétition doit être ouverte pendant la revue, le texte change : le
reformuler et le recompter (pack 57 §3, point 2).

---

## 4. Déclarations de confidentialité

**Inchangées** : pack 57 §4. La 58 n'ajoute aucune donnée collectée, aucun SDK, aucun hôte et
aucune permission (diff `lib/` et manifestes de `ba84fedf` à la préparation). Aucun champ
nouveau ne part au serveur ; la synchro du profil envoie même **moins** (seulement quand il a
changé, T8-07). Si les formulaires n'ont pas été envoyés avec la 57 (jamais soumise), les envoyer
avec la 58, tels que le pack 57 §4 les décrit.

---

## 5. Ce que ce pack ne tranche pas

| Point | Qui | Où |
|---|---|---|
| La puce « Corrections » des notes de version | À VALIDER (propriétaire) | §2 |
| Les choix compilés faits par défaut (« Pass Karatou », « sous 24 h », champ de recherche, téléphone de 7 à 12 chiffres) | À VALIDER (propriétaire), **avant l'archive** | checklist 58, §0.1 b |
| L'écran « Pass Karatou » dit encore « Premium » dans son corps (`premium_hero_sub` « Premium arrive bientôt », `premium_compare_title` « Gratuit vs Premium », `premium_compare_premium`, `premium_value_more_soon`) : unifier ou laisser. Les notes de revue restent vraies dans les deux cas (le titre de l'écran est « Pass Karatou ») | À VALIDER (propriétaire), **avant l'archive** (texte compilé) | `lib/app/core/translations/app_translations_fr.dart` |
| #401 (« Autre indicatif ») dans la 58 ou après | À VALIDER (propriétaire), **avant `RELEASE`** | checklist 58, §0.1 c |
| L'état de la fiche de version 2.3.1 dans App Store Connect (créée ou non pour la 57) | À VALIDER (propriétaire) | checklist 58, §8 |
| Les cas de `docs/device-qa-build58.md` | **Jamais joués sur appareil** : écrits d'après le code et l'audit | Recette TestFlight / Play Internal |
