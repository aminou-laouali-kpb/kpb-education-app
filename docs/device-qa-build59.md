# Fiche de QA appareil — build 59 : la 58 complétée, recette TestFlight en release

> **Pour qui.** Le propriétaire (ou un testeur désigné), sur **un iPhone, dont un iPhone SE**, et
> **un Android d'entrée de gamme en 360 dp**, physiques, avec la **build soumise** `2.3.1 (59)`
> installée depuis TestFlight / Play Internal — **en release**, jamais un build de debug : le
> contrat de soumission et l'audit exigent que la preuve vienne de l'artefact.
>
> **D'où vient cette fiche.** C'est la fiche de la 58 (`docs/device-qa-build58.md`, jamais
> signée), reprise pour la 59, **plus** une section « Ce que la 59 ajoute » (préfixe
> **Nouveau-**) pour l'espace parent sans prix, « Pass Karatou », la carte invité, « Déjà un
> compte ? », la messagerie du dossier et la compétition corrigée. Les conditions de l'audit du
> 28/10/2026 gardent chacune leur ligne (`docs/mise-a-jour-59-checklist.md`, étape 6.1).
>
> **Écrite le 09/11/2026 d'après le code (8279d0ea..claude/build-59), JAMAIS jouée sur appareil.**
> Un « attendu » qui se révèle faux se corrige ici ; on ne plie pas la recette à la build.
>
> **Où et comment tester — deux temps (checklist 59, étapes 1 et 6).**
> - **Temps A — contre la production telle qu'elle est** (`5332a128`, le serveur de la 58) :
>   toute la fiche **sauf** les lignes marquées « serveur 59 ». C'est la preuve du couplage
>   `tolerates-old` : la 59 face à l'ancien serveur, `caseMessaging` absente, WhatsApp seul dans
>   le dossier, compétition sans statut `ineligible`.
> - **Temps B — après le déploiement du serveur de la 59** (checklist 59, étape 1 : dû après
>   l'envoi aux testeurs, au feu vert du propriétaire) : les lignes « serveur 59 ». La messagerie
>   s'ouvre par une **fenêtre** (Actions → **VPS ops** → `case-messaging-on`, simulation puis
>   application) et se **referme avant de soumettre** (`case-messaging-off`, qui agit même
>   `dry_run` coché). Seule la 59 lit `caseMessaging` : la fenêtre ne touche ni la 58 des
>   testeurs ni la 2.3.0 en vente.
> - **Compétition** (`features.referralLeaderboard`, `features.referralOnboardingCode`) : **jamais
>   ouverte en production pour la recette** pendant la préparation de la revue. La jouer contre
>   une préproduction ou un backend local au SHA de la 59, avec une campagne de test (phases à
>   venir, en cours, terminée). À VALIDER (propriétaire) : l'existence et l'adresse de la
>   préproduction.
> - **Test « Mes 10 bourses »** et **carte invité** (`features.scholarshipMatch`) : **jamais en
>   production** tant que la validation juridique de la collecte de la nationalité et la couverture
>   du catalogue (pack 57 §5, étape 4) ne sont pas acquises. Préproduction ou backend local avec
>   `KPB_SCHOLARSHIP_MATCH_ENABLED=true`.
> - **Onboarding V2** (`features.onboardingV2`) : fenêtre en production (`onboarding-v2-on`),
>   **refermée avant de soumettre** (`onboarding-v2-off`).
> - **Tuer et relancer l'app après chaque bascule de drapeau** (lus au démarrage).
> - **Envoyer une notification à un seul compte** : À VALIDER (propriétaire) — le moyen retenu
>   (campagne de l'admin ciblée sur le compte du testeur, annonce d'une bourse de test suivie par ce
>   seul compte, ou, pour Nouveau-9, une réponse de l'équipe dans le dossier du testeur). Jamais
>   une campagne de masse pendant la recette.
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
> **Google** (connexion Google), un compte **existant** (créé avant la 59) pour la réinstallation,
> un compte étudiant qui suit déjà une bourse et a un **dossier ouvert**, un compte de **16 ou 17
> ans** (accord du tuteur), un **invité** sur une **installation neuve**, un compte **parent**, un
> **compte admin** (conseiller attribué au dossier du testeur), un compte **ambassadeur** inscrit à
> la campagne de test, et un **second téléphone** avec la **2.3.0 (56)** du store connecté à un
> **autre** compte.
>
> **Numérotation.** Douze préfixes : **Nouveau-** (la 59), **Audit-**, **Appareil-**, **Texte-**,
> **Lecteur-**, **Push-**, **HorsLigne-**, **Accueil-**, **Suivi-**, **Drapeau-**, **Parrain-**,
> **Boutique-**. Cocher ☐ → ☑ (ou ✗ avec ce qu'on a vu) ; noter l'appareil et l'heure.

## Ce que la 59 ajoute — ce que seul un appareil prouve

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Nouveau-1 | **Espace parent, onglet « Accompagnement »** (compte parent), à 1.0 puis 1,5, sur 360 dp | La barre du bas dit « Accompagnement » (icône conseiller), plus « Paiements » ; les deux formules **sans aucun prix** (ni « FCFA », ni montant) ; plus de bloc « Historique » ; la note dit que tarif et paiement se règlent avec le conseiller KPB sur WhatsApp | ☐ | ☐ |
| Nouveau-2 | **« Demander le tarif »** sur chaque formule | WhatsApp s'ouvre sur la ligne KPB avec « Bonjour, je souhaite connaître le tarif de « … » pour mon enfant. » ; aucun écran de paiement, aucun formulaire de carte | ☐ | ☐ |
| Nouveau-3 | **« Pass Karatou » partout** : Profil → « Pass Karatou », espace « Études en France » (offres « Gratuit et Pass Karatou », « Avec le Pass Karatou », case « Le Pass Karatou m'intéresserait aussi »), fiche d'un établissement (« Accompagnement KPB ») | Aucun « Premium » visible sur ces écrans ; aucun prix | ☐ | ☐ |
| Nouveau-4 | **« Déjà un compte ? »** sur l'écran d'entrée, iPhone SE et 360 dp, à 1,5 | La ligne « Déjà un compte ? Utilise le même Google ou le même e-mail : tu retrouves ton espace. » est lisible en entier ; les trois actions restent visibles sans défiler (Audit-10) | ☐ | ☐ |
| Nouveau-5 | **Compte existant sur une installation neuve** : désinstaller, réinstaller la 59, se connecter avec le **même** Google (puis, sur l'autre appareil, le même e-mail) | Le compte existant revient (profil, bourses suivies, dossiers) ; **aucun** onboarding de nouveau compte, aucun second compte créé | ☐ | ☐ |
| Nouveau-6 | **Carte invité** (préproduction, `scholarshipMatch` ouvert) : installation neuve → « Explorer sans compte » → Accueil | La carte « Découvre les bourses pour lesquelles tu es éligible » au-dessus de la liste neutre ; bouton « Créer mon compte et voir mes bourses » | ☐ | ☐ |
| Nouveau-7 | **Carte invité → inscription → test** (suite de Nouveau-6) | Le bouton mène à la création de compte ; après l'inscription (et l'onboarding), le test « Mes 10 bourses » s'ouvre de lui-même (intention gardée 24 h) ; le consentement à la nationalité est demandé (Lecteur-11) | ☐ | ☐ |
| Nouveau-8 | **Carte invité absente** en production (`scholarshipMatch` fermé), invité | Aucune carte « Découvre les bourses… » ; la liste neutre seule, comme la 58 | ☐ | ☐ |
| Nouveau-9 | **Messagerie fermée** (temps A, production `5332a128`, clé `caseMessaging` absente) : ouvrir un dossier | Aucun champ de saisie ; le bouton WhatsApp (« Écrire à ton conseiller sur WhatsApp », ou « à l'équipe KPB ») ouvre WhatsApp avec la référence ; le tunnel « Être accompagné » ne propose pas « Dans l'application » comme canal — exactement la 58 (Audit-21) | ☐ | ☐ |
| Nouveau-10 | **Messagerie ouverte, de bout en bout** (serveur 59, fenêtre `case-messaging-on`) : l'élève écrit dans son dossier | Le champ de saisie apparaît **et** le bouton WhatsApp reste en dessous ; le message part, s'affiche comme envoyé ; le conseiller attribué reçoit l'alerte e-mail « Nouveau message — <référence> — <nom> » (sans le texte du message) | ☐ | ☐ |
| Nouveau-11 | **Réponse depuis l'administration** (serveur 59) : admin → Dossiers → le dossier → fil → répondre | Le fil de l'admin montre le message de l'élève ; la réponse part au nom de l'agent connecté ; elle apparaît dans le fil de l'admin | ☐ | ☐ |
| Nouveau-12 | **Notification « … t'a répondu »** (serveur 59), app tuée, puis en arrière-plan, puis au premier plan | Notification réelle reçue ; le tap ouvre le dossier ; la réponse est **déjà dans le fil** (dossiers relus à la notification, sans attendre 30 s) ; au premier plan, le fil se met à jour | ☐ | ☐ |
| Nouveau-13 | **Messagerie en vraie 3G et en mode avion** (serveur 59, fenêtre ouverte) | En 3G, un message envoyé n'est pas doublé ; en mode avion, l'échec se dit et le message n'est pas perdu en silence ; au retour du réseau, un seul message côté admin | ☐ | ☐ |
| Nouveau-14 | **Fenêtre refermée** : `case-messaging-off`, relancer l'app | Le champ disparaît, WhatsApp reste ; les messages déjà échangés restent lisibles dans le fil | ☐ | ☐ |
| Nouveau-15 | **Compétition, phase en cours** (préproduction, `referralLeaderboard` ouvert), ambassadeur participant, TalkBack / VoiceOver, 1,5 sur 360 dp | Titre « Compétition des ambassadeurs » ; « Ton code de parrainage » ; règle dite (nouveau compte + profil complété pendant la compétition) ; bouton « règlement » **toujours** présent et qui ouvre le règlement de la campagne ; aucun montant | ☐ | ☐ |
| Nouveau-16 | **Filleul « Ne compte pas »** (serveur 59) : un compte créé AVANT la compétition saisit le code de l'ambassadeur | Côté ambassadeur : la ligne « Ne comptent pas » (1) et son explication ; ni qualifié ni en attente | ☐ | ☐ |
| Nouveau-17 | **Refus expliqués** (écran Parrainage et étape d'onboarding) : code d'un autre parrain alors qu'on en a déjà un ; code saisi après avoir ouvert un dossier ; code de quelqu'un qui a déjà saisi le sien | « Tu es déjà rattaché à un autre parrain. » ; « … tu as déjà ouvert un dossier. » ; « … deux amis ne peuvent pas se parrainer l'un l'autre. » — avec le serveur 59 (codes `referral_*`) **et** avec la production `5332a128` (repli sur le message anglais) | ☐ | ☐ |
| Nouveau-18 | **Fin de compétition** (campagne de test passée en phase terminée) : participant, puis non-participant qui saisit un code | Participant : phase « terminée », classement provisoire ou final ; non-participant : « La compétition des ambassadeurs est terminée : un code saisi maintenant ne compte plus pour elle… » ; le code rattache quand même au parrain | ☐ | ☐ |
| Nouveau-19 | **Compétition fermée** (production, état de soumission) | Aucune carte ni écran « Compétition » ; pas d'étape « code de parrainage » à l'onboarding (Drapeau-1) | ☐ | ☐ |
| Nouveau-20 | **Dossier au long récit** (audit avant l'archive) : tunnel « Être accompagné », dicter ou coller un texte de plus de 2 000 caractères | Le champ s'arrête à 1 900 caractères, le compteur l'indique ; « Envoyer » crée le dossier et il apparaît dans l'administration | ☐ | ☐ |
| Nouveau-21 | **Réouverture sur réseau lent** : ouvrir la 59 une fois en bon réseau, la tuer, passer en vraie 2G/3G (ou limiter le débit), la rouvrir | L'espace « Études en France » est là dès l'ouverture, sans attendre le réseau ; aucun bandeau « Mode hors-ligne » tant que l'API répond | ☐ | ☐ |
| Nouveau-22 | **Interrupteur vu par une app restée ouverte** (serveur 59) : app ouverte sur un dossier, la mettre en arrière-plan, lancer `case-messaging-on`, attendre 5 min, revenir dans l'app | Le champ de message apparaît sans tuer l'app ; `case-messaging-off` puis même geste : il disparaît | ☐ | ☐ |
| Nouveau-23 | **Recherche sans accents** : champ de recherche de l'Accueil, taper « senegal », « ingenierie », « cote d'ivoire » | Les résultats accentués sortent (« Sénégal », « Ingénierie », « Côte d'Ivoire ») ; jamais « aucun résultat » | ☐ | ☐ |
| Nouveau-24 | **Bouton Retour du téléphone** (Android seulement) : onglet Dossiers puis Retour ; onboarding à l'étape 2 puis Retour | L'onglet revient à l'Accueil, l'onboarding à l'étape 1 ; depuis l'Accueil, Retour quitte l'app | — | ☐ |
| Nouveau-25 | **Raccourcis de l'icône sur une installation neuve** (Android : appui long sur l'icône → « Mes dossiers ») avant toute connexion | L'app s'ouvre sur l'écran d'entrée, pas sur un accueil vide ; après « Explorer sans compte », le raccourci ouvre l'onglet Dossiers | — | ☐ |
| Nouveau-26 | **Écran Services** (Profil → « Services KPB », préproduction avec une offre servie) | Chaque offre affiche « Tarif sur demande, auprès de ton conseiller KPB » ; aucun montant | ☐ | ☐ |
| Nouveau-27 | **Parcours rafraîchis** : ouvrir Parcours, tuer l'app, la rouvrir le lendemain (ou avancer la date du téléphone d'un jour) | La liste se met à jour sans tirer l'écran ; hors réseau, la liste gardée reste affichée | ☐ | ☐ |
| Nouveau-28 | **Visite guidée, 1re arrivée** : app désinstallée puis installée, connexion (ou « Explorer sans compte ») jusqu'à l'accueil | Environ 1 s après l'accueil, l'écran s'assombrit : « Bienvenue… », « Étape 1 sur 9 » (8 en invité : pas de KPB Intelligence). Chaque étape éclaire le BON bouton (onglets en bas, ☰ en haut à gauche, KPB Intelligence) et affiche l'onglet dont elle parle ; la liste des outils du ☰ est celle du tiroir ; « J'ai compris » ramène à l'accueil | ☐ | ☐ |
| Nouveau-29 | **Visite : une seule fois** — tuer l'app après « J'ai compris », la rouvrir ; puis réinstaller, quitter l'app au milieu de la visite, la rouvrir | Fermée : ne revient plus. Quittée au milieu : revient au démarrage suivant | ☐ | ☐ |
| Nouveau-30 | **Visite : Passer, Retour, texte 1,5, VoiceOver / TalkBack, 360 dp** | « Passer » ferme et affiche « Tu pourras revoir la visite… » ; Retour du téléphone = étape précédente ; un tap sur le voile ne fait rien ; à 1,5 la bulle reste lisible (elle défile) sans recouvrir le bouton ; le lecteur d'écran lit le titre de chaque étape | ☐ | ☐ |
| Nouveau-31 | **Profil → « Revoir la visite »** (élève et invité) | La visite repart de l'étape 1 et, fermée, rend l'élève au Profil | ☐ | ☐ |

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
| Audit-18 | **Verrou biométrique** (Profil → Biométrie, #403) : Android avec code, Android SANS code de verrouillage, iPhone avec Face ID annulé | Avec code : l'empreinte déverrouille. Sans code : l'interrupteur refuse (« Verrou non activé… »). Face ID annulé : « Authentification échouée », « Déverrouiller » relance ; jamais d'élève enfermé | ☐ | ☐ |
| Audit-19 | **Code e-mail en vraie 3G**, réseau coupé juste après « Valider » (#404) | Message réseau (« ton code est peut-être encore valide »), jamais « Code invalide » ; au retour du réseau, « Valider » connecte sans redemander de code | ☐ | ☐ |
| Audit-20 | **Profil illisible à la connexion** : couper le réseau juste après l'acceptation du code, sur un compte qui a déjà un profil (#404) | Écran « Impossible de récupérer ton compte » avec « Réessayer » ; jamais l'onboarding, profil serveur intact | ☐ | ☐ |
| Audit-21 | **Dossier : écrire au conseiller** (#407), messagerie fermée (voir Nouveau-9) | Pas de champ de saisie ; « Écrire à ton conseiller sur WhatsApp » (ou « à l'équipe KPB » sans conseiller) ouvre WhatsApp avec la référence du dossier ; historique au « tu », rendez-vous daté s'il est fixé | ☐ | ☐ |
| Audit-22 | **Dictée vocale** sur un Android physique (#407) | Le micro du message de dossier n'affiche plus « dictée indisponible » (si la saisie est rouverte plus tard) ; à défaut, vérifier qu'aucun plantage au démarrage ne vient du manifeste | ☐ | ☐ |
| Audit-23 | **Bourses en vraie 3G**, défiler au-delà de 20 fiches, couper le réseau (#405) | « Impossible de charger la suite » + « Réessayer » en bas de liste ; « Réessayer » reprend la suite | ☐ | ☐ |

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
| Push-9 | **Même compte sur une 59 et sur une 56** | Limite connue : seule la 59 reçoit (pas de repli OneSignal quand l'élève a un jeton FCM). Le noter, ce n'est pas un ✗ | ☐ | ☐ |
| Push-10 | **Déconnexion** | Plus aucune notification sur ce téléphone pour ce compte (jeton retiré) | ☐ | ☐ |
| Push-11 | **Autorisation refusée** | L'écran des notifications le dit et propose les réglages ; aucune boucle de demande | ☐ | ☐ |
| Push-12 | **Heures calmes** (mode d'ouverture `outbox_*` seulement, hors lancement) | Rien n'arrive entre 21 h et 8 h locales ; à jouer quand le mode change (pack 57 §6.3, valable pour la 59) | ☐ | ☐ |

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
| Drapeau-1 | **État de soumission** (commande de l'étape 2 de la checklist) | `scholarshipMatch=false`, `onboardingV2=false`, `eefHelpBubble=false`, `eefPrivateSchools=false`, `referralInstallReferrer=false`, `referralOnboardingCode=false`, `referralLeaderboard=false`, `community=false`, `assistBridge=false`, `caseMessaging=false` ; la carte du test et la carte invité n'apparaissent pas ; le dossier n'a pas de champ de saisie ; l'ancien onboarding s'affiche, sans étape « code de ton parrain » | ☐ | ☐ |
| Drapeau-2 | **Un interrupteur d'urgence coupé** (par exemple `KPB_HOME_PARCOURS_ENABLED=false`, en recette) | Après relance, le bloc disparaît ; remis à `true`, il revient | ☐ | ☐ |
| Drapeau-3 | **`KPB_FOLLOW_PUSH_PRIMER_ENABLED=false`** (en recette) | Le premier « Suivre » demande directement l'autorisation, sans feuille ; jamais à l'onboarding | ☐ | ☐ |
| Drapeau-4 | **`KPB_ONBOARDING_V2_ENABLED=true`** (fenêtre de recette) | Aucun champ prérempli sans choix ; « Passer » dès la page 1, sans contourner le plancher de 16 ans ; refermé avant la soumission | ☐ | ☐ |
| Drapeau-5 | **Bandeau de mise à jour** (`recommendedVersion` au-dessus de 2.3.1, en recette seulement) | Bandeau fermable sur la 59 ; fermé, il ne revient pas dans la session ; remis à vide ensuite | ☐ | ☐ |

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
| Parrain-5 | **Écran « Compétition des ambassadeurs »** (`KPB_REFERRAL_LEADERBOARD_ENABLED=true`, compte ambassadeur participant), TalkBack / VoiceOver, texte 1,5 | Phase et compte à rebours, rang (lu « Ton rang : … »), qualifiés / à vérifier / en attente, « provisoire », code, partage, classement public, règlement ; aucun montant ; rien de tronqué à 1,5 sur 360 dp | ☐ | ☐ |
| Parrain-6 | **Non-participant** (drapeau ouvert) | Espace ambassadeur : l'écran de candidature, inchangé ; écran Parrainage : aucune carte « Compétition » | ☐ | ☐ |
| Parrain-7 | **Pied de l'écran « Compétition »** (ajout du 18/10/2026), dans chaque phase | « Organisateur : KPB Global L.L.C-FZ. Apple et Google ne sont ni organisateurs ni partenaires de cette compétition. » lu en bas de l'écran ; le bouton « règlement » ouvre le `rulesUrl` de la campagne | ☐ | ☐ |

## Gardes de boutiques

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| Boutique-1 | **L'installation est la build soumise** | TestFlight : **2.3.1 (59)** (pas la 58 ni la 57, aussi visibles dans TestFlight) ; Play Console / `adb shell dumpsys package com.karatou.android \| grep versionCode` → 59 | ☐ | ☐ |
| Boutique-2 | **Aucun pourcentage, aucune « chance »** | Liste, fiche, accueil, résultats du test : ni « % » de compatibilité, ni « chances » | ☐ | ☐ |
| Boutique-3 | **Aucune permission neuve** | Aucune invite système en dehors de l'autorisation des notifications au premier « Suivre » (la permission d'installation Install Referrer d'Android n'affiche rien) | ☐ | ☐ |
| Boutique-4 | **Politique de confidentialité in-app** | Elle nomme le test (nationalité, date de naissance), dit l'absence de transmission aux écoles, la conservation et les mineurs de 16 et 17 ans, comme `web/public/confidentialite.html` ; depuis le 18/10/2026, les sections « Communauté d'entraide », « Réponses et suggestions automatiques », « Parrainage et compétition des ambassadeurs » et « Votre nationalité » s'affichent et se lisent jusqu'au bout (CGU : « Communauté d'entraide », « Compétition des ambassadeurs ») | ☐ | ☐ |
| Boutique-5 | **Les notes de revue disent la vérité** | Relire le pack 59 §3 point par point contre ce qu'on a vu (espace ouvert ou non, test, onboarding V2, compétition et messagerie éteints, aucun prix, autorisation au premier « Suivre ») | ☐ | ☐ |
| Boutique-6 | **Export de mes données** (Profil → Mes données) | Le JSON partagé contient la clé `notifications` (les notifications reçues dans l'app) en plus des clés existantes | ☐ | ☐ |

## Signature

Appareils (modèle, OS, RAM, taille d'écran en dp), build (numéro, source), date, profil réseau,
voie de recette (temps A contre la production `5332a128`, temps B après le déploiement du serveur de la 59, préproduction, backend local), et ce qui a
échoué ou n'a pas été joué ; pour la 3G, le moyen (SIM 3G, point d'accès bridé, conditionneur). Un ✗ non résolu bloque la soumission. La recette ne vaut pour l'audit que jouée **en release** sur un iPhone SE et un Android de 360 dp. **A9** de la fiche 54 se signe
par Push-3 et Push-4.
