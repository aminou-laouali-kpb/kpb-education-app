# Build 59 — pack de soumission : ce qui change par rapport aux packs 57 et 58

> **À quoi sert ce fichier.** La 59 remplace la 58 (téléversée le 08/11/2026, jamais soumise) :
> décision du propriétaire du 09/11/2026, « je veux qu'il y ait tout déjà ». Même version
> marketing `2.3.1`. Le pack `docs/release-57-store-pack.md` **reste la référence** pour tout ce
> que ce fichier ne remplace pas : déclarations Play Data Safety et Apple App Privacy (§4),
> tableau des drapeaux (§5, qui liste désormais `caseMessaging`), déploiement par étapes et
> paliers (§6), décisions (§7). Le pack `docs/release-58-store-pack.md` est **entièrement
> remplacé** par celui-ci : notes de version (§2 ci-dessous) et « Notes for Review » (§3
> ci-dessous). L'ordre des opérations est dans `docs/mise-a-jour-59-checklist.md` ; la recette
> dans `docs/device-qa-build59.md`.
>
> **Pourquoi un pack 59, et pas le pack 58 tel quel.** Deux phrases des notes de revue de la 58
> deviennent fausses ou incomplètes sur la 59 :
> 1. « their FCFA price is shown for information » : la 59 n'affiche **plus aucun prix**
>    (l'onglet parent « Paiements » devient « Accompagnement », le bouton « Réserver » devient
>    « Demander le tarif » et ouvre WhatsApp avec une demande de tarif) ;
> 2. la liste des fonctions activées à distance ne connaît pas **`features.caseMessaging`**, la
>    messagerie du dossier pilotée par le serveur (guideline 2.3.1 : toute fonction activable à
>    distance se déclare, même fermée à la revue).
>
> **Rien de ce qui suit ne s'envoie sans le feu vert explicite du propriétaire.**

---

## 1. Ce que la 59 ajoute à la 58

Le détail est au registre, entrée « Préparation de la build 59 (09/11/2026) ».

| Commit | Contenu | Visible à la revue ? |
|---|---|---|
| 7b6804ad | **Espace parent sans prix** : onglet « Accompagnement », « Demander le tarif » (WhatsApp, « Bonjour, je souhaite connaître le tarif de … »), historique de paiements retiré ; **« Premium » → « Pass Karatou »** (espace « Études en France », fiche établissement) ; **carte invité** « Découvre les bourses pour lesquelles tu es éligible » → « Créer mon compte et voir mes bourses » ; **« Déjà un compte ? »** sur l'écran d'entrée | Oui, sauf la carte invité : elle suit `features.scholarshipMatch` (**fermé** à la revue) |
| 39fcd758, ce0138d7, 595a1813, c263f322 | **Messagerie du dossier dans les deux sens** : l'élève écrit dans son dossier, l'équipe lit et répond depuis l'administration (`/admin/cases/:id/messages`), l'élève reçoit une notification « … t'a répondu » ; alerte e-mail au conseiller ; WhatsApp reste proposé | **Non** : `features.caseMessaging` **fermé** (nouvelle clé, défaut `false`) ; fermé, le dossier renvoie vers WhatsApp comme la 58 |
| 0c19e934 | **Compétition des ambassadeurs corrigée** : règlement toujours visible, filleuls « Ne comptent pas » (statut `ineligible`), refus expliqués (autre parrain, dossier déjà ouvert, parrainage croisé), fin de compétition annoncée ; modèle de règlement `docs/reglement-competition-ambassadeurs-TEMPLATE.md` | **Non** : `features.referralLeaderboard` et `features.referralOnboardingCode` **fermés** à la revue. Les messages d'erreur de l'écran Parrainage, eux, sont visibles |

**Ce que la 59 ne change pas dans le binaire** : `pubspec.lock`, `Info.plist`,
`PrivacyInfo.xcprivacy`, `AndroidManifest.xml`, `android/app/build.gradle`, `ios/Podfile.lock`
identiques à la 58 ; aucun SDK, aucune permission, aucun hôte nouveau (checklist 59, étape 0.3).

---

## 2. Notes de version

La 2.3.1 n'a jamais été en vente : les notes décrivent toujours l'écart avec la 2.3.0. On n'y
annonce **aucune** fonction fermée à la revue (messagerie du dossier, compétition, carte invité).
**Proposition** : le texte du pack 58 §2, plus une puce « Parents ». À VALIDER (propriétaire) : la
garder, ou coller le texte du pack 57 §2 ou du pack 58 §2 tel quel (tous sont vrais).

**App Store — FR**
```
Nouveautés :
• Suivre une bourse : un bouton « Suivre » sur chaque bourse pour être prévenu de son ouverture et avant sa date limite. Retrouve tes bourses dans « Mes suivis ».
• Notifications : une liste de tes notifications dans l'app, et un envoi plus fiable.
• Bourses : une liste plus lisible (statut, date de clôture, filtres et tri) ; les bourses déjà consultées restent lisibles sans connexion.
• Accueil : une seule carte « Ta prochaine étape » te dit quoi faire maintenant.
• Connexion : le code reçu par e-mail se colle plus facilement et se valide dès le 6e chiffre.
• Stabilité : la synchronisation de ton compte résiste mieux aux coupures de réseau.
• Parents : un onglet « Accompagnement » pour demander le tarif d'un accompagnement à un conseiller KPB.
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
• Parents: a "Support" tab to ask a KPB counsellor for the price of a guidance package.
• Fixes: back navigation after "Follow", the ☰ menu on a first visit, and a false "cannot reach the server" banner at launch.
```

**Google Play — FR (500 caractères au plus)**
```
• Suivre une bourse : sois prévenu de son ouverture et avant sa date limite, retrouve-la dans « Mes suivis ».
• Une liste de tes notifications dans l'app, et un envoi plus fiable.
• Liste des bourses plus lisible (statut, filtres, tri), lisible hors connexion.
• Accueil : une carte « Ta prochaine étape ».
• Code de connexion plus simple à coller.
• Parents : tarifs sur demande au conseiller KPB.
• Corrections : retour après « Suivre », menu ☰ en 1re visite, faux bandeau de connexion.
```

Décompte du bloc Google Play : **488 caractères** (limite 500 ; la puce « Synchronisation » du
pack 58 cède la place à « Parents »), refait par `test/release/mise_a_jour_59_checklist_test.dart`.

---

## 3. « Notes for Review » Apple — le texte COMPLET (guideline 2.3.1)

Le texte ci-dessous **remplace** celui des packs 57 §3 et 58 §3 : à coller **seul**, en anglais.
Ce qui change par rapport au pack 58 :

- **NO IN-APP PURCHASE** : `no price is shown in the app: the button opens WhatsApp to ask a
  counsellor` au lieu de `their FCFA price is shown for information` ;
- **REMOTELY ACTIVATED FEATURES** : `features.caseMessaging` ajouté à la liste « OFF at review
  time » ;
- pour tenir sous la limite avec sa marge : la phrase « LANGUAGE » en une seule, « NEW IN THIS
  VERSION » resserré, et « (Home, Universities, tools, Journeys) » retiré de « SIGN-IN » (le
  sens ne change pas).

`"Pass Karatou" is a "coming soon" screen` reste : l'écran s'appelle « Pass Karatou » depuis #389,
et la 59 retire les derniers « Premium » visibles des textes de l'espace « Études en France » et
des fiches établissement. Les contrôles « à faire avant de coller » du pack 57 §3 (points 1 à 5 :
espace « Études en France », drapeaux « OFF at review time », autorisation au premier « Suivre »,
réponses du test, compte de démonstration) valent pour la 59, à refaire le jour même.

<!-- notes-for-review: chars=3947 bytes=3950 reserve=160 -->

```
SIGN-IN
This app has no password: sign-in is Google OAuth or a one-time code sent by email. Demo account: <ADDRESS> — the code can be read at <METHOD>. Most of the app works without an account via "Explorer sans compte" on the welcome screen; an account is needed for the Scholarships tab, to follow a scholarship and to open a case.

LANGUAGE
The interface is French only in this version; the English store listing is a translation.

NO IN-APP PURCHASE
There is no in-app purchase, subscription or checkout in the app or the backend, and no card details are requested. Paid KPB guidance packages are human services; no price is shown in the app: the button opens WhatsApp to ask a counsellor, and payment is arranged outside the app. "Pass Karatou" is a "coming soon" screen with no price; its free waiting-list button records only the account id, a timestamp and the consent notice shown.

AI FEATURES
Six features call a third-party LLM (OpenRouter and Groq, United States): the assistant "KPB Intelligence", the orientation questionnaire and four writing tools. All six sit behind an explicit, timestamped in-app AI consent enforced server-side; a declared minor also needs a guardian's recorded consent. Answers are presented as indicative. The app never adds the student's name to a prompt. Prompts are not used for provider training.

USER-GENERATED CONTENT
None reachable at review time: a student writes only to the KPB advisor of their own case, which a parent reads only if the student shares it. The community below is declared in the age rating and privacy answers.

AGE
Accounts require 16+. Under 18, a guardian's name, contact and consent are required before the profile can be completed.

NEW IN THIS VERSION
"Follow" on a scholarship saves it and sends a notification when it opens and before its deadline. Notification permission is never asked at launch: only after a short explanation, at the first "Follow". Also: a "My follows" screen, an in-app notification list, offline reading of viewed scholarships, one "next step" card on Home. Push notifications now use Firebase Cloud Messaging; the OneSignal SDK is removed.

REMOTELY ACTIVATED FEATURES (guideline 2.3.1)
Switched from our server (api.kpbeducation.cloud/api/config/app). The "Études en France" space is open (flag eefSpace). OFF at review time: features.scholarshipMatch, a scholarship eligibility test (nationality, date of birth, diploma, grades, languages) that shows up to 10 scholarships, never a percentage; features.onboardingV2, a shorter sign-up flow; features.eefHelpBubble and features.eefPrivateSchools, WhatsApp help inside the space; features.referralOnboardingCode and features.referralLeaderboard, an optional referral-code step after sign-up and a referral contest screen for ambassadors registered by our team (organiser KPB Global L.L.C-FZ, official rules linked, Apple is not a sponsor, no prize amount shown in the app); features.community, a student Q&A (posts and replies seen by signed-in students; pre-publication filter holding contact details, money requests and links for staff review; report; block; rules accepted before posting; staff moderation; no private messages); features.assistBridge, a settings switch for private KPB-team suggestions; features.caseMessaging, a student's messages to the KPB team inside their own case. None adds a permission, SDK or host on iOS. Test answers are not sent to schools, analytics or notifications. Also remote: a dismissible "update available" banner (recommendedVersion).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service, not affiliated with Campus France or any French administration, and does not process applications. The demo account is a test account: its declarations are excluded from our advisors' call lists.
```

**Décompte (script, 09/11/2026).** Marqueurs `<ADDRESS>` et `<METHOD>` remplacés par la place
qu'on leur réserve — **40** et **120** caractères — : **3 947 caractères** (3 950 octets en
UTF-8), soit **53 caractères sous la limite** de 4 000. Le test
`test/release/mise_a_jour_59_checklist_test.dart` refait ce calcul et exige au moins 50 caractères
de marge : une phrase ajoutée oblige à en raccourcir une autre.

**Drapeaux « OFF at review time »** : `scholarshipMatch`, `onboardingV2`, `eefHelpBubble`,
`eefPrivateSchools`, `referralOnboardingCode`, `referralLeaderboard`, `community`,
`assistBridge` et **`caseMessaging`** doivent valoir `false` le jour de la soumission (checklist
59, étapes 2 et 8). **La compétition doit rester fermée pendant la revue** : les trois drapeaux du
parrainage (`referralInstallReferrer`, `referralOnboardingCode`, `referralLeaderboard`) à
`false`. Si le propriétaire veut une compétition ouverte pendant la revue, ce texte devient
faux : le reformuler (« ON at review time », règlement en ligne, organisateur, Apple non
sponsor) et le recompter **avant** de soumettre (pack 57 §3, point 2). Même règle pour
`caseMessaging` : ouverte pendant la revue, la phrase « None reachable at review time » de
« USER-GENERATED CONTENT » ne l'est plus tout à fait (un élève écrit à l'équipe dans l'app) ; à
reformuler.

---

## 4. Déclarations de confidentialité

**Inchangées** : pack 57 §4. La messagerie du dossier n'ajoute **aucune catégorie** : les
messages de dossier sont déjà déclarés (Play « Messages — In-app (dossiers) », Apple « Support »
dans `docs/CONSOLE_ANSWERS.md`), comme leur destinataire (l'équipe KPB, sans tiers). La
notification de réponse passe par Firebase Cloud Messaging, déjà déclaré ; l'alerte e-mail part
vers l'équipe, pas vers l'élève, par le fournisseur d'e-mail déjà déclaré. Aucun SDK, aucun hôte,
aucune permission nouvelle. La politique de confidentialité n'a pas à changer : À VALIDER
(propriétaire) la relecture de sa section « dossiers » le jour où `caseMessaging` s'ouvre (elle
doit dire que l'équipe peut répondre dans l'app).

---

## 5. Drapeaux

Le tableau complet reste le **pack 57 §5**, qui liste désormais la clé de la 59 :

| Clé | Variable | Défaut | À la soumission de la 59 | Ouverture |
|---|---|---|---|---|
| `caseMessaging` | `KPB_CASE_MESSAGING_ENABLED` | fermé (`enabled`) | `false` | Après l'approbation, quand l'équipe est prête à répondre depuis l'administration : Actions → **VPS ops** → `case-messaging-on` (simulation, puis application) ; retour arrière `case-messaging-off`, qui agit même `dry_run` coché |
| `scholarshipMatch` | `KPB_SCHOLARSHIP_MATCH_ENABLED` | fermé | `false` | Inchangé : étape 4 du pack 57 §5 (nationalité, couverture d'au moins 90 %, recette en préproduction). C'est aussi lui qui montre la **carte invité** de la 59 : tant qu'il est fermé, elle n'apparaît pas |

---

## 6. Ce que ce pack ne tranche pas

| Point | Qui | Où |
|---|---|---|
| La puce « Parents » des notes de version (et sa traduction « Support ») | À VALIDER (propriétaire) | §2 |
| Les textes compilés de la 59 (« Accompagnement », « Demander le tarif », la carte invité, « Déjà un compte ? ») | À VALIDER (propriétaire), **avant l'archive** | checklist 59, §0.1 b |
| La date d'ouverture de `caseMessaging`, et qui répond depuis l'administration (délai promis) | À VALIDER (propriétaire), **après l'approbation** | §5 ; checklist 59, §9 |
| Une compétition ouverte pendant la revue (alors : notes à réécrire et recompter) | À VALIDER (propriétaire), **avant la soumission** | §3 |
| L'état de la fiche de version 2.3.1 dans App Store Connect (créée pour la 57 ou la 58 ?) : y rattacher la 59 | À VALIDER (propriétaire) | checklist 59, §8 |
| Les cas de `docs/device-qa-build59.md` | **Jamais joués sur appareil** : écrits d'après le code | Recette TestFlight / Play Internal |
