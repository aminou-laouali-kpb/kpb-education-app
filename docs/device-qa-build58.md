# Fiche de QA appareil — build 58 : la 57 corrigée, recette TestFlight en release

> **Pour qui.** Le propriétaire (ou un testeur désigné), sur **un iPhone, dont un iPhone SE**, et
> **un Android d'entrée de gamme en 360 dp**, physiques, avec la **build soumise** `2.3.1 (58)`
> installée depuis TestFlight / Play Internal — **en release**, jamais un build de debug : le
> contrat de soumission et l'audit exigent que la preuve vienne de l'artefact.
>
> **D'où vient cette fiche.** C'est la fiche de la 57 (`docs/device-qa-build57.md`, jamais jouée :
> la 57 n'a pas été recettée), reprise pour la 58, **plus** une section « Correctifs de l'audit »
> pour ce que #387 et #389 corrigent et que seul un appareil prouve. Les conditions de l'audit du
> 28/10/2026 (vraie 3G, vrai mode avion, VoiceOver réel, notifications réelles, connexion Google,
> ☰ invité, « Suivre » puis retour, « Être accompagné ») ont chacune leur ligne
> (`docs/mise-a-jour-58-checklist.md`, étape 6.1). Les fiches 54, 55 et 56 restent valables pour
> l'espace « Études en France ».
>
> **Écrite le 07/11/2026 d'après le code (PR #351 à #389) et l'audit, JAMAIS jouée sur appareil.**
> Un « attendu » qui se révèle faux se corrige ici ; on ne plie pas la recette à la build.
>
> **Où et comment tester.**
> - **Backend** : la production, qui sert déjà le backend de la 58 (`99d5f11a` au 07/11/2026,
>   checklist 58, étapes 1 et 2). Aucun déploiement n'est nécessaire pour la recette.
> - **Test « Mes 10 bourses »** (`features.scholarshipMatch`) : **jamais en production** tant que la
>   collecte de la nationalité n'est pas ouverte. Le jouer contre une **préproduction** ou un backend
>   local (voie 1 de la fiche 54, §B) avec `KPB_SCHOLARSHIP_MATCH_ENABLED=true`. À VALIDER
>   (propriétaire) : l'existence et l'adresse de la préproduction.
> - **Onboarding V2** (`features.onboardingV2`) : une fenêtre en production (Actions → **VPS ops** →
>   `onboarding-v2-on`) touche aussi les 57 installées chez les testeurs. **La refermer avant de
>   soumettre** : `onboarding-v2-off`.
> - **Tuer et relancer l'app après chaque bascule de drapeau** (lus au démarrage).
> - **Envoyer une notification à un seul compte** : À VALIDER (propriétaire) — le moyen retenu
>   (campagne de l'admin ciblée sur le compte du testeur, ou annonce d'ouverture d'une bourse de
>   test suivie par ce seul compte). Jamais une campagne de masse pendant la recette. Exclure le
>   compte de test de l'audit des campagnes.
>
> **Réglages de l'appareil à préparer.**
> - **Petit écran** : un Android de **360 × 640 dp** avec **2 Go de RAM** ; un **iPhone SE** (2e ou
>   3e génération). La preuve vient de ces appareils, pas d'un émulateur.
> - **Vraie 3G** : une carte SIM en 3G (réglage « 3G seulement » du téléphone) ou un point d'accès
>   bridé ; à défaut, *Network Link Conditioner* → « 3G » (iOS) ou profil réseau lent (Android).
>   Noter le moyen utilisé : l'audit demande une vraie 3G.
> - **Vrai mode avion** : le réglage système, pas une coupure du Wi-Fi seul.
> - **Taille de texte** : réglage système à **1.0** puis à **1.5**. **L'app plafonne
>   l'agrandissement à 1,5** (`maxScaleFactor: 1.5`, `lib/main.dart`).
> - **Lecteurs d'écran** : TalkBack (Android), **VoiceOver réel** (iOS).
>
> **Langue.** La build soumise est en français seulement (`kShippedLocale = 'fr'`,
> `lib/app/core/i18n/app_locale.dart`).
>
> **Comptes à avoir sous la main.** Un compte étudiant neuf (pour l'onboarding), un compte
> **Google** (connexion Google), un compte étudiant qui suit déjà une bourse, un compte de **16 ou
> 17 ans** (accord du tuteur), un **invité** sur une **installation neuve**, un compte **parent**,
> et un **second téléphone** avec la **2.3.0 (56)** du store connecté à un **autre** compte.
>
> **Numérotation.** Onze préfixes : **Audit-** (nouveau), **Appareil-**, **Texte-**, **Lecteur-**,
> **Push-**, **HorsLigne-**, **Accueil-**, **Suivi-**, **Drapeau-**, **Parrain-**, **Boutique-**.
> Cocher ☐ → ☑ (ou ✗ avec ce qu'on a vu) ; noter l'appareil et l'heure.

## Correctifs de l'audit (#387, #389) — ce que seul un appareil prouve

Les numéros entre parenthèses renvoient au rapport d'audit du 28/10/2026 (top 10 : « n° » ;
constats : « T… »). Chaque correctif a son test automatique ; ces lignes prouvent le rendu et les
gestes sur l'artefact.

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Audit-1 | **« Suivre » puis retour** (n° 1) : onglet Bourses → une fiche → « Suivre » → retour système, puis retour de nouveau | Aucune flèche ← sur l'onglet Bourses après le retour ; **jamais d'écran noir** ; un second retour ne dépile rien | ☐ | ☐ |
| Audit-2 | **Lancement en vraie 3G**, compte connecté, serveur joignable (n° 2) | Aucun bandeau « Données d'exemple » ni « connexion au serveur impossible » pendant la première synchro. Noter la durée jusqu'à l'accueil utilisable | ☐ | ☐ |
| Audit-3 | **☰ invité en 1re session** (n° 3) : installation neuve → « Explorer sans compte » → ☰ | Le tiroir « Outils KPB » s'ouvre **au premier tap**, sans relancer l'app | ☐ | ☐ |
| Audit-4 | **Tunnel « Être accompagné »** depuis une fiche bourse (n° 5b, T4-16) | La feuille a un **fond opaque** (la fiche ne transparaît pas) ; le tunnel va jusqu'à l'envoi ; **un seul** bandeau, sans référence inventée ; « Voir » ouvre le dossier créé | ☐ | ☐ |
| Audit-5 | **« Mes échéances »** après un « Suivre » (n° 7) | Aucune étape générique (J-60…J-15) ajoutée, aucune étape « Passée » ; pas de faux « 7 jours » | ☐ | ☐ |
| Audit-6 | **Invité** : « Suivre » sur une fiche, puis une fiche réservée (n° 9, T6-07) | Le mur « Créer mon compte gratuit », **jamais** « Erreur de connexion » | ☐ | ☐ |
| Audit-7 | **Connexion Google** (T1-19, jamais jouée par l'audit), en vraie 3G | La feuille Google s'ouvre, le retour dans l'app aboutit sur l'accueil connecté. Noter la durée du retour de Google | ☐ | ☐ |
| Audit-8 | **Vrai mode avion** en cours d'usage, puis retour du réseau | Bandeau hors ligne global ; toast « Hors ligne », puis « Connexion rétablie » au retour, sans relance | ☐ | ☐ |
| Audit-9 | **KPB Intelligence en vraie 3G**, puis à 1,5 (T1-03, T7-08) | Invité : le mur propre au chat (pas celui des outils). Connecté : noter la durée des réponses ; à 1,5, les réponses suivent la taille du texte, le champ ne rogne pas | ☐ | ☐ |
| Audit-10 | **Écran d'entrée sur iPhone SE et 360 dp**, à 1.0 puis 1,5 (T1-04, T7-13) | Les trois actions visibles **sans défiler** ; liens Confidentialité et Conditions atteignables avant l'inscription (T1-20) | ☐ | ☐ |
| Audit-11 | **Écoles « compatibles »** de l'écran « aha » (n° 8) | Une seule étiquette par carte ; frais en **FCFA** | ☐ | ☐ |
| Audit-12 | **Carte conseiller** et Profil (n° 4, 5a) | « Réponse sous 24 h » ; aucun « profil déjà partagé » ; aucune tuile « Espace ambassadeur » ni « parrainage rémunéré » quand le programme rémunéré est fermé | ☐ | ☐ |
| Audit-13 | **Écran « Pass Karatou »** (Profil) (T5-14, T4-08, T7-19) | Titre « Pass Karatou » ; bouton vert à texte bleu nuit lisible ; aucun prix ; le retour est annoncé « Retour » par le lecteur d'écran | ☐ | ☐ |
| Audit-14 | **Barre d'état** sur les écrans clairs (T6-16) | Heure et batterie lisibles (icônes sombres sur fond clair) | ☐ | ☐ |
| Audit-15 | **« Tirer pour rafraîchir »** sur la liste des bourses en vraie 3G (T8-06) | La liste reste affichée pendant le rafraîchissement, pas de squelettes à la place | ☐ | ☐ |
| Audit-16 | **Recherche** : champ en tête de l'Accueil, loupe de l'onglet Bourses (T6-04) | Les deux ouvrent la recherche ; le champ ne casse pas la salutation à 360 dp | ☐ | ☐ |
| Audit-17 | **Démarrage hors ligne, puis réseau** (T2-06, complète HorsLigne-1) | Après le retour du réseau, la carte « Études en France » (et la Communauté si ouverte) revient **sans relancer** l'app (nouvel essai de `/config/app` à 5 s puis 30 s) | ☐ | ☐ |

## Petit appareil, mémoire et réseau lent (360 × 640, 2 Go, vraie 3G)

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Appareil-1 | **Démarrage à froid en 3G** sur l'Android 360 × 640 / 2 Go | L'écran de démarrage puis l'accueil ; des squelettes (`KpbSkeleton`), **jamais un spinner seul** ; pas d'écran blanc. Noter le temps jusqu'à l'accueil utilisable | ☐ | ☐ |
| Appareil-2 | **Accueil à 360 dp** | « Ta prochaine étape », puis les blocs : rien ne déborde à droite, aucun texte coupé au milieu d'un mot, en-tête de 48 dp lisible | ☐ | ☐ |
| Appareil-3 | **Liste des bourses à 360 dp** | Ligne de statut lisible (« Ouverte · clôture … », « Ouvre le … », « Date à confirmer »…), drapeau ou 🌍, boutons « Filtrer » et « Trier » visibles ; carte guide sans débordement | ☐ | ☐ |
| Appareil-4 | **Fiche d'une bourse à 360 dp** | Bouton « Suivre » entièrement visible et atteignable sans faire défiler horizontalement | ☐ | ☐ |
| Appareil-5 | **Mémoire** : ouvrir 10 fiches de suite, revenir à la liste, basculer d'onglet | Pas de fermeture de l'app, pas de saccade durable ; la liste garde sa position | ☐ | ☐ |
| Appareil-6 | **Filtre et tri en 3G** | Une seule requête à la validation de la feuille « Filtrer » ; un squelette pendant l'attente ; un échec dit sa cause et propose « Réessayer » | ☐ | ☐ |
| Appareil-7 | **Mode données réduites** de l'app (Profil) | Les animations sont coupées (`KpbMotion`), la liste reste utilisable | ☐ | ☐ |
| Appareil-8 | **Animations système coupées** (Android : « Supprimer les animations » ; iOS : « Réduire les animations ») | Aucun mouvement d'entrée dans les listes ; rien ne reste invisible | ☐ | ☐ |

## Taille de texte 1.0 et 1.5

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Texte-1 | **1.0** : onboarding, accueil, liste et fiche des bourses, « Mes suivis », notifications | Référence : tout est lisible, rien n'est tronqué | ☐ | ☐ |
| Texte-2 | **1.5** : onboarding (les trois étapes, et l'onboarding V2 en fenêtre de recette) | Rendu à 1,5 (plafond de l'app) ; aucun bouton sorti de l'écran ; les erreurs s'écrivent sous le champ, entières | ☐ | ☐ |
| Texte-3 | **1.5** : accueil « Ta prochaine étape » | Titre, sous-titre et bouton d'action entiers ; la carte grandit au lieu de couper | ☐ | ☐ |
| Texte-4 | **1.5** : liste et fiche des bourses, feuille « Filtrer », feuille de tri | Ligne de statut et « Clôture proche · J-n » entières ; feuilles défilables jusqu'au bouton de validation | ☐ | ☐ |
| Texte-5 | **1.5** : « Mes suivis », écran des notifications, feuille d'explication avant la demande d'autorisation | Aucun texte coupé ; bouton « Activer » ou équivalent atteignable | ☐ | ☐ |
| Texte-6 | **1.5** : test « Mes 10 bourses » (préproduction) — questions, récapitulatif, résultats | Chaque question et son aide entières ; le récapitulatif défile jusqu'à « Valider » ; les raisons des résultats lisibles | ☐ | ☐ |
| Texte-7 | **1.5** : politique de confidentialité (Profil → Confidentialité) | Les nouvelles puces (test, suivis, conservation, mineurs) se lisent en entier | ☐ | ☐ |

## Lecteurs d'écran : onboarding → test « Mes 10 bourses » → détail → Suivre → dossier

Jouer le parcours **d'un seul tenant**, TalkBack sur Android, VoiceOver sur iOS, sans regarder
l'écran pour les gestes (balayage, double tap). Le test « Mes 10 bourses » se joue en
préproduction.

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Lecteur-1 | **Onboarding** : chaque champ et chaque puce | Annoncés avec leur libellé et leur état (« sélectionné ») ; l'ordre de lecture suit l'ordre visuel ; une erreur est lue quand elle apparaît | ☐ | ☐ |
| Lecteur-2 | **Code à usage unique** | Le champ est annoncé ; le code collé est validé au 6e chiffre, une seule fois | ☐ | ☐ |
| Lecteur-3 | **Entrée du test** (carte « Test : quelles bourses pour moi ? » de l'onglet Bourses) | Titre, texte et bouton « Faire le test » lus ; la phrase sur la nationalité et la date de naissance, et le lien « Politique de confidentialité », sont atteignables | ☐ | ☐ |
| Lecteur-4 | **Questions du test** : nationalité (recherche de pays), date de naissance, diplôme, moyenne, langues | Chaque question lue avec son aide ; la liste des pays se parcourt et se filtre ; aucune icône muette | ☐ | ☐ |
| Lecteur-5 | **Compte de 16 ou 17 ans** | La question de l'accord du tuteur est posée et lue ; sans accord, aucun résultat n'est calculé | ☐ | ☐ |
| Lecteur-6 | **Récapitulatif puis résultats** | Chaque ligne du récapitulatif lue (« Nationalité », « Date de naissance »…) ; résultats : section, nom de la bourse, statut, raisons ; **aucun pourcentage** annoncé | ☐ | ☐ |
| Lecteur-7 | **Détail d'une bourse** depuis les résultats | Titre, statut, dates, liens officiels lus ; retour à la liste par le geste système | ☐ | ☐ |
| Lecteur-8 | **« Suivre »** | Le bouton est annoncé « Suivre », puis « Suivie » après le double tap ; la feuille d'explication est lue avant la demande système ; la demande système est atteignable | ☐ | ☐ |
| Lecteur-9 | **Ouvrir un dossier** depuis la bourse | Le tunnel de dossier se parcourt jusqu'à l'envoi ; le toast de confirmation (`KpbToast`) est lu ; « Voir » est atteignable pendant ses 4 s | ☐ | ☐ |
| Lecteur-10 | **« Mes suivis »** et l'écran des notifications | La bourse suivie y figure, lue avec son statut ; chaque notification lue avec sa date ; la cloche annonce les non-lus | ☐ | ☐ |
| Lecteur-11 | **Consentement à l'usage de la nationalité** (ajout du 18/10/2026) : récapitulatif sans cocher la case, puis case cochée | Case décochée : « C'est bon, voir mes bourses » est désactivé et « Coche la case de consentement pour voir tes bourses. » est lu ; la case est annoncée avec son libellé et son état ; cochée, l'envoi part. La question « Ta nationalité » dit qu'elle est facultative. Brouillon repris après avoir tué l'app : la case est **redemandée**. Texte 1,5 sur 360 dp : rien de tronqué | ☐ | ☐ |
| Lecteur-12 | **VoiceOver réel** (condition de l'audit) : écran d'entrée, ☰ « Outils KPB », « Pass Karatou », feuille « Être accompagné » | Chaque bouton est annoncé avec son libellé ; le ☰ est annoncé et ouvre le tiroir ; le retour de « Pass Karatou » est annoncé « Retour » ; le focus ne passe pas derrière la feuille | ☐ | ☐ |

## Notifications (FCM, repli OneSignal) — ferme le point A9 de la fiche 54

Le cas **A9** de `docs/device-qa-build54.md` (« Notification reçue app tuée : le tap ouvre la
bonne destination ») n'a jamais été joué jusqu'au bout. La 57 a changé de fournisseur (FCM à la place
de OneSignal, `lib/app/core/services/push_service.dart` : `getInitialMessage` pour l'app tuée,
`onMessageOpenedApp` en arrière-plan) : **Push-3 et Push-4 ferment A9**. Signer A9 ici, pas dans la
fiche 54.

**Condition de l'audit** : des notifications **réelles**, sur l'artefact — la demande d'autorisation (Push-1), une alerte d'ouverture reçue (Push-2 ou Push-3), et le **tap** sur une notification (Push-3 à Push-5). Une notification de test envoyée depuis une console tierce ne compte pas.

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Push-1 | **Autorisation** au premier « Suivre » (condition de l'audit : la vraie demande système) | La feuille d'explication d'abord, puis la demande système ; **jamais** à l'onboarding ni au démarrage | ☐ | ☐ |
| Push-2 | **Réception, app au premier plan** | Une bannière dans l'app ; l'entrée apparaît dans l'écran des notifications | ☐ | ☐ |
| Push-3 | **Tap, app TUÉE** (balayée depuis le sélecteur d'apps) — annonce d'ouverture ou rappel d'une bourse suivie | L'app démarre et ouvre **la fiche de la bourse** (pas l'accueil), une seule fois ; la notification passe en lue | ☐ | ☐ |
| Push-4 | **Tap, app TUÉE** — campagne qui pointe un récit (`/parcours/<slug>`), le cas A9 d'origine | Le **récit** s'ouvre, pas l'accueil | ☐ | ☐ |
| Push-5 | **Tap, app en arrière-plan** | Même destination que Push-3, sans redémarrage | ☐ | ☐ |
| Push-6 | **Tap, app verrouillée par la biométrie** | Le verrou d'abord, puis la destination | ☐ | ☐ |
| Push-7 | **Ouverture mesurée** | Dans l'admin, la ligne de la campagne porte « Ouverte le » pour ce compte (`POST /me/push-opens`) | ☐ | ☐ |
| Push-8 | **Ancienne build** : second téléphone en **2.3.0 (56)** ou 2.2.0, **autre compte** sans 2.3.1 | Il **reçoit** la notification (repli OneSignal, `/api/health` → `push.oneSignal=true`) et le tap ouvre sa destination comme avant | ☐ | ☐ |
| Push-9 | **Même compte sur une 58 et sur une 56** | Limite connue : seule la 58 reçoit (pas de repli OneSignal quand l'élève a un jeton FCM). Le noter, ce n'est pas un ✗ | ☐ | ☐ |
| Push-10 | **Déconnexion** | Plus aucune notification sur ce téléphone pour ce compte (jeton retiré) | ☐ | ☐ |
| Push-11 | **Autorisation refusée** | L'écran des notifications le dit et propose les réglages ; aucune boucle de demande | ☐ | ☐ |
| Push-12 | **Heures calmes** (mode d'ouverture `outbox_*` seulement, hors lancement) | Rien n'arrive entre 21 h et 8 h locales ; à jouer quand le mode change (pack 57 §6.3, valable pour la 58) | ☐ | ☐ |

## Hors ligne

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| HorsLigne-1 | **Démarrage à froid hors ligne** (vrai mode avion, app tuée, compte connecté ayant déjà synchronisé) | L'app démarre jusqu'à l'accueil, sans écran d'erreur bloquant ; la porte de version et les drapeaux échouent ouverts ; au retour du réseau, voir Audit-17 | ☐ | ☐ |
| HorsLigne-2 | **Bandeau hors ligne global** (`KpbOfflineBanner`, coquille de l'app) | Visible en haut sur chaque onglet, avec la fraîcheur des données (« aujourd'hui », « hier », « il y a n jours ») ; il disparaît au retour du réseau, sans relance | ☐ | ☐ |
| HorsLigne-3 | **Liste des bourses hors ligne** | « Hors ligne — données du … » au lieu d'un écran d'erreur ; les fiches à date limite confirmée passée sont masquées | ☐ | ☐ |
| HorsLigne-4 | **Fiche déjà consultée** | Elle s'ouvre hors ligne ; une fiche jamais consultée montre un état d'erreur avec « Réessayer », jamais un écran blanc | ☐ | ☐ |
| HorsLigne-5 | **« Suivre » hors ligne** (condition de l'audit, T8-01) | « Suivie » s'affiche ; au retour du réseau, la bourse est bien suivie côté serveur **avec son alerte d'ouverture** (cloche active dans la fiche après une reconnexion, pas seulement le favori) : rien n'est perdu en silence | ☐ | ☐ |
| HorsLigne-6 | **Résultats du test hors ligne** (préproduction) | Le dernier résultat reste lisible, daté | ☐ | ☐ |
| HorsLigne-7 | **Déconnexion puis reconnexion avec un autre compte** | Aucune bourse suivie, aucun résultat ni cache du premier compte n'apparaît | ☐ | ☐ |

## Accueil « Ta prochaine étape »

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Accueil-1 | **Une seule action** | Une carte « TA PROCHAINE ÉTAPE » avec **un** bouton ; les blocs suivent dans l'ordre : Tes bourses, Tes échéances, écoles partenaires, KPB Intelligence, Parcours, conseiller | ☐ | ☐ |
| Accueil-2 | **Priorités** — dossier qui attend l'élève | « Ouvrir le dossier » passe avant tout le reste | ☐ | ☐ |
| Accueil-3 | **Priorités** — bourse suivie qui clôture bientôt | « Voir la bourse » quand aucun dossier n'attend | ☐ | ☐ |
| Accueil-4 | **Priorités** — profil incomplet | « Compléter mon profil » (drapeau du test fermé) ; « Faire le test » seulement quand `scholarshipMatch` est ouvert (préproduction) | ☐ | ☐ |
| Accueil-5 | **Bloc en panne** (une route qui répond 404, par exemple `/impact/stats`) | Le bloc disparaît, espace compris ; aucun spinner seul | ☐ | ☐ |
| Accueil-6 | **Parent, invité, partenaire** | Leur héros propre ; aucune carte élève | ☐ | ☐ |

## Suivre et Mes suivis

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Suivi-1 | **Suivre / ne plus suivre** depuis la fiche | « Suivre » → « Suivie » ; la bourse apparaît dans « Mes suivis » ; « Ne plus suivre » l'en retire | ☐ | ☐ |
| Suivi-2 | **Cloche « Me prévenir à l'ouverture »** sur la fiche | Couper la cloche garde le favori ; la rallumer le prévient de nouveau | ☐ | ☐ |
| Suivi-3 | **Préférence « Bourses que je suis : ouverture »** | La couper : plus de push d'ouverture, mais l'entrée reste dans l'écran des notifications | ☐ | ☐ |
| Suivi-4 | **Entrée « Mes suivis »** de l'en-tête de l'accueil | Elle ouvre l'écran ; le point de la cloche suit les non-lus du serveur | ☐ | ☐ |

## Drapeaux et états serveur

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Drapeau-1 | **État de soumission** (commande de l'étape 2 de la checklist) | `scholarshipMatch=false`, `onboardingV2=false`, `eefHelpBubble=false`, `eefPrivateSchools=false`, `referralInstallReferrer=false`, `referralOnboardingCode=false`, `referralLeaderboard=false`, `community=false`, `assistBridge=false` ; la carte du test n'apparaît pas ; l'ancien onboarding s'affiche, sans étape « code de ton parrain » | ☐ | ☐ |
| Drapeau-2 | **Un interrupteur d'urgence coupé** (par exemple `KPB_HOME_PARCOURS_ENABLED=false`, en recette) | Après relance, le bloc disparaît ; remis à `true`, il revient | ☐ | ☐ |
| Drapeau-3 | **`KPB_FOLLOW_PUSH_PRIMER_ENABLED=false`** (en recette) | Le premier « Suivre » demande directement l'autorisation, sans feuille ; jamais à l'onboarding | ☐ | ☐ |
| Drapeau-4 | **`KPB_ONBOARDING_V2_ENABLED=true`** (fenêtre de recette) | Aucun champ prérempli sans choix ; « Passer » dès la page 1, sans contourner le plancher de 16 ans ; refermé avant la soumission | ☐ | ☐ |
| Drapeau-5 | **Bandeau de mise à jour** (`recommendedVersion` au-dessus de 2.3.1, en recette seulement) | Bandeau fermable sur la 58 ; fermé, il ne revient pas dans la session ; remis à vide ensuite | ☐ | ☐ |

## Parrainage (ajout du 17/10/2026, trois drapeaux fermés)

Fenêtre de recette en production ou en préproduction : poser le drapeau dans le `.env`, recréer
`api`, **tuer et relancer** l'app ; refermer avant la soumission. Lien d'invitation de test :
`https://kpbeducation.cloud/invite.html?ref=<CODE>` (le bouton Google Play y porte
`referrer=utm_source=invite&utm_medium=referral&ref=<CODE>`).

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Parrain-1 | **Install Referrer** (`KPB_REFERRAL_INSTALL_REFERRER_ENABLED=true` et `KPB_REFERRAL_ONBOARDING_CODE_ENABLED=true`), app désinstallée puis installée depuis le bouton Google Play du lien d'invitation (piste de test interne) | À la fin de l'onboarding, l'étape « Tu as un code de parrain ? » montre le code du lien et « Code repris de ton lien d'invitation » ; **rien n'est rattaché** tant qu'on n'appuie pas sur « Valider le code ». iPhone : champ vide (pas de referrer sur iOS) | ☐ | ☐ |
| Parrain-2 | **Une seule lecture par installation**, et aucune lecture drapeau fermé | Relancer l'app : pas de nouvelle lecture ; drapeau `referralInstallReferrer` fermé : le champ reste vide | ☐ | ☐ |
| Parrain-3 | **Étape du code : « Passer »**, retour système | On arrive sur l'écran « aha » ; le code du lien est proposé ensuite dans Profil → Parrainer un ami | ☐ | ☐ |
| Parrain-4 | **Étape du code : erreurs** — code inconnu, son propre code, mode avion | Inconnu / propre code : message DANS le champ, on peut corriger ou passer ; mode avion : « Pas de connexion. Ton code est gardé… », l'onboarding continue ; le code réapparaît dans Parrainage | ☐ | ☐ |
| Parrain-5 | **Écran « Compétition ambassadeurs »** (`KPB_REFERRAL_LEADERBOARD_ENABLED=true`, compte ambassadeur participant), TalkBack / VoiceOver, texte 1,5 | Phase et compte à rebours, rang (lu « Ton rang : … »), qualifiés / à vérifier / en attente, « provisoire », code, partage, classement public, règlement ; aucun montant ; rien de tronqué à 1,5 sur 360 dp | ☐ | ☐ |
| Parrain-6 | **Non-participant** (drapeau ouvert) | Espace ambassadeur : l'écran de candidature, inchangé ; écran Parrainage : aucune carte « Compétition » | ☐ | ☐ |
| Parrain-7 | **Pied de l'écran « Compétition »** (ajout du 18/10/2026), dans chaque phase | « Organisateur : KPB Global L.L.C-FZ. Apple et Google ne sont ni organisateurs ni partenaires de cette compétition. » lu en bas de l'écran ; le bouton « règlement » ouvre le `rulesUrl` de la campagne | ☐ | ☐ |

## Gardes de boutiques

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Boutique-1 | **L'installation est la build soumise** | TestFlight : **2.3.1 (58)** (pas la 57, aussi visible dans TestFlight) ; Play Console / `adb shell dumpsys package com.karatou.android \| grep versionCode` → 58 | ☐ | ☐ |
| Boutique-2 | **Aucun pourcentage, aucune « chance »** | Liste, fiche, accueil, résultats du test : ni « % » de compatibilité, ni « chances » | ☐ | ☐ |
| Boutique-3 | **Aucune permission neuve** | Aucune invite système en dehors de l'autorisation des notifications au premier « Suivre » (la permission d'installation Install Referrer d'Android n'affiche rien) | ☐ | ☐ |
| Boutique-4 | **Politique de confidentialité in-app** | Elle nomme le test (nationalité, date de naissance), dit l'absence de transmission aux écoles, la conservation et les mineurs de 16 et 17 ans, comme `web/public/confidentialite.html` ; depuis le 18/10/2026, les sections « Communauté d'entraide », « Réponses et suggestions automatiques », « Parrainage et compétition des ambassadeurs » et « Votre nationalité » s'affichent et se lisent jusqu'au bout (CGU : « Communauté d'entraide », « Compétition des ambassadeurs ») | ☐ | ☐ |
| Boutique-5 | **Les notes de revue disent la vérité** | Relire le pack 58 §3 point par point contre ce qu'on a vu (espace ouvert ou non, test et onboarding V2 éteints, autorisation au premier « Suivre ») | ☐ | ☐ |
| Boutique-6 | **Export de mes données** (Profil → Mes données) | Le JSON partagé contient la clé `notifications` (les notifications reçues dans l'app) en plus des clés existantes | ☐ | ☐ |

## Signature

Appareils (modèle, OS, RAM, taille d'écran en dp), build (numéro, source), date, profil réseau,
voie de recette (production au SHA de la release, préproduction, backend local), et ce qui a
échoué ou n'a pas été joué ; pour la 3G, le moyen (SIM 3G, point d'accès bridé, conditionneur). Un ✗ non résolu bloque la soumission. La recette ne vaut pour l'audit que jouée **en release** sur un iPhone SE et un Android de 360 dp. **A9** de la fiche 54 se signe
par Push-3 et Push-4.
