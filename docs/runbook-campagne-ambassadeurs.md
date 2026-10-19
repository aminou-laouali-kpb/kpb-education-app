# Runbook — Compétition des ambassadeurs (parrainage)

Compétition de **novembre 2026** : du 1er au 10/11 inclus, heure d'Afrique de l'Ouest
(Africa/Lagos, UTC+1), prix 100 000 / 50 000 / 30 000 FCFA, villes Maradi, Niamey, Cotonou,
Abidjan, Douala (pilotables). Décisions du propriétaire du 17/10/2026, complétées le
18/10/2026 (versement sous 7 jours, prix perdu après 15 jours et passé au suivant, résultats le
17 novembre 2026, droit des Émirats arabes unis (Dubaï), proches de l'équipe exclus, pièce
d'identité au versement, empreintes 180 jours). Règlement (texte arrêté le 18/10/2026, à relire
par le propriétaire avant publication) : `docs/reglement-competition-ambassadeurs-novembre-2026.md`.

**Tout fonctionne avec l'app installée (2.3.0, build 56), sans nouvelle build** : le comptage
est serveur, la gestion est dans la console admin, le classement est une page web.

## 0. Ce que voit chacun

| Qui | Où | Quoi |
|---|---|---|
| Ambassadeur (app 2.3.0) | Profil → « Parrainer un ami » | Son **code personnel** (8 caractères), le partage WhatsApp, le nombre d'amis inscrits. Ce code compte pour la compétition. |
| Ambassadeur (app 2.3.0) | Profil → « Devenir ambassadeur » | L'écran de candidature (aucune somme, aucune commission) : l'espace « cash » reste fermé pour un ambassadeur de la compétition (`cashProgramEnabled = false`). |
| Ambassadeur (web) | `kpbeducation.cloud/invite.html?ref=<CODE>` | Lien à partager : code en grand, « Copier le code », boutiques, consigne. |
| Filleul (app 2.3.0) | Profil → « Parrainer un ami » → « Tu as un code de parrainage ? » | Saisit le code (personnel OU « KTOU-… », casse et tirets ignorés). |
| Tout le monde | `kpbeducation.cloud/classement/?c=ambassadeurs-novembre-2026` | Podium, liste, recherche, compte à rebours, « classement provisoire ». |
| Équipe | Console admin → « Compétition ambassadeurs » (`/parrainage`) | Campagnes, ambassadeurs, classement, filleuls, décisions, podium, versements, export. |

## 1. Mise en production (avant le 31/10)

1. Fusionner la PR, puis **déploiement complet** (`deploy.yml`, `scope: full`) : il applique la
   migration additive `20261022120000_referral_campaigns`, remplace l'API et l'admin, et publie
   `web/` (page `/classement/`, `invite.html`, nouvelle CSP nginx).
   - La migration ne touche aucune colonne existante. Rattrapages : code ambassadeur normalisé,
     `cashProgramEnabled = true` pour les ambassadeurs existants (leur app ne change pas),
     `profileCompletedAt` des profils déjà complets.
   - Correctifs 57 (19/10/2026) : le déploiement complet suivant applique aussi la migration
     additive `20261026130000_referral_prize_forfeit` (table neuve, vide) qui porte « Déclarer le
     prix forfait et réattribuer » (§7). À déployer **avant** la validation du podium.
2. Variables (toutes facultatives, défauts sûrs) : `REFERRAL_CODE_HOURLY_LIMIT` (30),
   `REFERRAL_SIGNAL_RETENTION_DAYS` (180), `KPB_REFERRAL_SIGNAL_SECRET` (sinon `KPB_JWT_SECRET`),
   `AMBASSADOR_SELF_ACTIVATION_ENABLED` (faux : laisser faux).
3. Vérifier :
   - `curl -sI https://kpbeducation.cloud/classement/` → 200, en-tête CSP avec
     `connect-src 'self' https://api.kpbeducation.cloud` ;
   - `curl -s https://api.kpbeducation.cloud/api/public/campaigns/nexiste-pas/leaderboard` → 404.

## 2. Créer la campagne

Console admin → **Compétition ambassadeurs** → **Nouvelle campagne**. Le formulaire est
prérempli pour novembre : slug `ambassadeurs-novembre-2026`, 2026-11-01 → 2026-11-10,
`Africa/Lagos`, prix « 100000, 50000, 30000 », villes. Ajouter le lien du règlement (https) ou
son texte une fois validé. **Créer** → la campagne est un **brouillon** (invisible du public).

Contrôle : l'en-tête affiche « UTC : 2026-10-31T23:00:00.000Z → 2026-11-10T23:00:00.000Z
(exclu) ». La borne de fin est exclusive : le 10/11 à 23 h 59 locale compte, minuit non.

En brouillon, tout est modifiable (onglet Paramètres). **Au lancement, les dates, les prix et
les villes sont figés** ; seuls les noms et le règlement restent modifiables.

## 3. Activer et inscrire les ambassadeurs

Onglet **Ambassadeurs et inscriptions** :

1. L'ambassadeur crée son compte dans l'app (e-mail vérifié) et complète son profil.
2. **Activer un ambassadeur** : e-mail du compte + ville. L'activation crée son code
   « KTOU-… », alloue son code personnel s'il n'existait pas, et trace l'action
   (`AdminAuditEvent`). C'est la **seule** voie : l'auto-activation renvoie 403.
3. **Inscrire à la campagne**. Le nom public est calculé « Prénom I. » (modifiable, ni e-mail ni
   numéro accepté), la ville doit être dans la liste éligible, l'âge vient de la date de
   naissance.
4. **Mineur** (ou âge inconnu) : il apparaît « Mineur : autorisation parentale à vérifier » et
   **n'est ni affiché au public ni primé**. Quand l'autorisation signée est reçue : clic sur
   la ligne → « Autorisation parentale » = **Vérifiée** + note (« formulaire reçu par WhatsApp le
   … »). La date et l'admin qui a vérifié sont enregistrés. « Âge » corrige un âge inconnu.
5. Donner à l'ambassadeur son lien : `https://kpbeducation.cloud/invite.html?ref=<code>` (affiché
   dans sa fiche) — ou lui dire d'utiliser son code personnel de l'écran Parrainage.

## 4. Lancer

**Lancer** (confirmation). La page publique devient visible avec un compte à rebours jusqu'au
1er novembre ; le comptage tourne toutes les 5 minutes (rien ne compte avant le 1er à 00 h
UTC+1).

## 5. Tester avant le 31/10 (parcours propriétaire)

Avec deux téléphones (ou un téléphone et des comptes de test) et l'app 2.3.0 du store :

1. Créer une campagne de **test** : slug `test-interne-oct-2026`, du **jour même** au jour même,
   prix « 1, 1, 1 », aucune ville (toutes). Créer.
2. Activer un compte « ambassadeur » de test (son e-mail, ville Niamey) et l'inscrire. S'il est
   mineur ou sans date de naissance, mettre « Âge » = Majeur (c'est un test) ou vérifier
   l'autorisation.
3. **Lancer** la campagne de test.
4. Téléphone B : installer l'app, **créer un nouveau compte** (code e-mail), terminer
   l'onboarding (téléphone, date de naissance, un domaine, un pays visé, consentement).
5. Téléphone B : Profil → « Parrainer un ami » → saisir le code de l'ambassadeur (essayer en
   minuscules ou « KTOU-… » : ça marche) → message de succès.
6. Admin : **Recalculer maintenant** → la ligne de l'ambassadeur passe à 1 qualifié ; clic → le
   filleul est « Qualifié » avec l'heure.
7. Ouvrir `https://kpbeducation.cloud/classement/?c=test-interne-oct-2026` : l'ambassadeur
   apparaît (« Prénom I. — Niamey », 1), compte à rebours « Fin de la compétition dans ».
8. Tester l'anti-fraude : sur le téléphone B, se déconnecter, créer un second compte, saisir le
   même code → après recalcul, le second filleul est « À vérifier — même téléphone » (signal
   disponible si les notifications sont autorisées sur ce téléphone : l'app 2.3.0 n'a pas
   d'autre identifiant d'appareil). Le
   **Valider** puis **Exclure** (motif demandé) : les compteurs suivent.
9. **Geler** → **Valider le podium** → onglet « Podium et versements » : noter un versement de
   test (référence « TEST ») → **Clore**. La page publique n'affiche plus « provisoire ».
10. La campagne de test reste en base (pas de suppression) : son slug n'est lié nulle part.

## 6. Pendant la compétition (1er–10/11)

- Le classement admin se met à jour toutes les 5 minutes (« Recalculer maintenant » à la
  demande ; rejouer n'écrit que les différences).
- Chaque jour, filtrer par ville, ouvrir les ambassadeurs avec des « À vérifier » et décider :
  - **Valider** une rafale légitime (atelier au lycée, même Wi-Fi) — motif facultatif ;
  - **Exclure** un compte douteux — **motif obligatoire**, tracé ;
  - **Retirer** ou **disqualifier** un ambassadeur (fiche → Statut + motif).
- Signaux automatiques : e-mail jetable (liste versionnée
  `backend/src/modules/referrals/campaigns/disposable-email-domains.ts`), même téléphone (jeton
  push déjà enregistré par l'app), rafale même IP (3 en 1 h), même plage réseau (5 en 10 min),
  rafale tous réseaux (10 en 10 min), filleul lui-même ambassadeur. Plafond dur : 30 codes saisis
  par heure et par ambassadeur (429). Seuils réglables par campagne (`qualificationRule`, en
  brouillon).
- Rien n'est supprimé automatiquement : « À vérifier » ne compte simplement pas.

## 7. Fin, gel, podium, versements

1. Le **11/11 à 00 h UTC+1** (23 h UTC le 10/11), la tâche planifiée fait un dernier calcul et
   **gèle** la campagne (`frozen`, audit `referral_campaign.frozen_auto`). Un code saisi après ne
   compte pas (la fenêtre est fermée de toute façon).
2. Revue finale : vérifier les « À vérifier » restants, les autorisations parentales du podium.
   « Recalculer » reste possible pendant le gel.
3. **Valider le podium** : fige les lauréats (nom public, montant, bénéficiaire = **parent pour
   un mineur**). Tant qu'aucun versement n'est noté, on peut revalider ; « Rouvrir » n'est plus
   possible.
4. Demander la **pièce d'identité** du lauréat (du parent pour un mineur), verser par Wave **dans
   les 7 jours** qui suivent la validation des résultats, puis **Noter le versement** : référence
   Wave, date, bénéficiaire. Le serveur refuse « l'ambassadeur » comme bénéficiaire d'un lauréat
   mineur. Lauréat injoignable ou sans informations de versement **15 jours** après la validation :
   il perd son prix, qui **passe au suivant** du classement (décisions du propriétaire,
   18/10/2026). Mécanique (correctifs 57, 19/10/2026) : onglet **Prix** → sur la ligne du prix
   **non versé**, **« Déclarer le prix forfait et réattribuer »**, motif obligatoire (ex.
   « injoignable depuis le 18/11 : 3 appels, 2 messages WhatsApp »). Le serveur :
   - marque le lauréat forfait (motif, date, admin ; audit `referral_campaign.prize_forfeited`) —
     il ne pourra plus recevoir de prix dans cette campagne, même à une revalidation ;
   - fait passer les prix **non versés** à partir de ce rang aux suivants **classés** qui n'ont
     pas de prix (le 3e monte au 2e prix, le 4e entre au 3e prix) ;
   - ne touche **jamais** à un prix déjà versé, et refuse de déclarer forfait un prix versé ;
   - laisse le prix non attribué s'il n'y a plus de candidat classé (la liste « Prix déclarés
     forfait » l'indique) ;
   - ne change pas le classement public (ordre réel) ; une fois la campagne **close**, le podium
     de la page publique montre les lauréats **effectifs**.
   L'action est idempotente (un double clic ne déclare rien deux fois) et marche **avant comme
   après** un premier versement : plus besoin d'attendre ni de traiter hors outil. Elle n'a pas
   de retour arrière dans l'outil : vérifier le délai de 15 jours avant de la lancer. Le nouveau
   lauréat est contacté et versé comme les autres (pièce d'identité, 7 jours).
   Les résultats définitifs sont annoncés le **17 novembre 2026**.
5. **Clore** : résultats définitifs, plus aucun recalcul ; la page publique retire la mention
   « provisoire ».
6. **Export CSV** (classement ou filleuls) pour archive — fichiers à données personnelles, à
   garder hors des canaux publics.

## 8. Parrainage côté app — build 57 (2.3.1), derrière trois drapeaux fermés

**Révisé le 17/10/2026 (décision du propriétaire)** : les parties app entrent dans la build 57
(2.3.1), et non plus dans « une build ultérieure ». Elles partent **fermées** ; chacune s'ouvre
sans build, indépendamment des deux autres, et se referme de même.

| Drapeau (`/config/app`) | Variable | Ce qu'il ouvre dans la 57 |
|---|---|---|
| `features.referralInstallReferrer` | `KPB_REFERRAL_INSTALL_REFERRER_ENABLED` | Android : lecture **une fois par installation** du Play Install Referrer (paquet `play_install_referrer` 0.5.0) ; `ref` extrait avec le format strict des codes réels, gardé **en local** pour préremplir le champ. Rien n'est transmis avant la confirmation de l'élève. iOS, échec, absence : rien, saisie manuelle |
| `features.referralOnboardingCode` | `KPB_REFERRAL_ONBOARDING_CODE_ENABLED` | Étape facultative « Tu as un code de parrain ? » à la fin de l'onboarding élève, **après** la synchro du profil, préremplie par le referrer, bouton « Passer » ; ne bloque jamais l'entrée dans l'app |
| `features.referralLeaderboard` | `KPB_REFERRAL_LEADERBOARD_ENABLED` | Écran « Compétition ambassadeurs » : phase et compte à rebours (heure du serveur), rang, qualifiés / à vérifier / en attente, « un filleul compte quand son profil est complété », code + lien d'invitation à partager, page publique `kpbeducation.cloud/classement/?c=<slug>`, règlement (`rulesUrl` du classement public), mention « provisoire » tant que la campagne n'est pas close |

Ce que fait la 57, drapeaux ou non :

- **Identifiant d'installation** : UUID v4 aléatoire stocké sur l'appareil (jamais l'IMEI, jamais
  l'identifiant publicitaire), envoyé en **`X-KPB-Device-Id` sur `POST /referrals/redeem`
  seulement** ; un nouveau à chaque réinstallation. Le serveur n'en garde que l'empreinte HMAC
  (signal `device_duplicate`, jamais bloquant).
- **Messages clairs** à chaque issue du rattachement (étape d'onboarding et écran Parrainage) :
  code inconnu (404), propre code (403), refus (403 croisé ou dossier existant), déjà parrainé
  (succès silencieux), limite horaire (429 `referral_code_rate_limited`), hors ligne. Sur une
  panne passagère, le code est **gardé** et l'écran Parrainage le repropose.
- L'écran **Parrainage** préremplit le code en attente (lien d'invitation, ou saisi à
  l'onboarding sans réseau), toujours à confirmer.

Points d'entrée de l'écran « Compétition » : l'écran Parrainage (une carte, pour un participant
seulement) et l'**espace ambassadeur** (accès rapide du profil) — pour un ambassadeur **sans
espace « cash »**, le classement **remplace** l'écran de candidature quand il participe ; un
non-participant garde la candidature, sans rien de promis (l'API ne lui donne pas le slug, l'app
ne le code pas en dur : pas de lien vers un classement public). Aucun montant n'est affiché dans
l'app (ni prix, ni commission) ; la mention « Organisateur : KPB Global L.L.C-FZ. Apple et Google
ne sont ni organisateurs ni partenaires de cette compétition. » figure en pied d'écran (texte
retenu le 18/10/2026, gardé par `test/features/referral/ambassador_competition_screen_test.dart`).

**Ordre d'ouverture conseillé** — À VALIDER (propriétaire) — (après la 57 à 100 % sur les deux boutiques, et la politique de
confidentialité / la Data safety à jour — `docs/release-57-store-pack.md` §4 et §5) :

1. `KPB_REFERRAL_LEADERBOARD_ENABLED=true` avant le **1er novembre 2026** (début de la
   compétition) : les participants voient la phase « à venir » et leur code.
2. `KPB_REFERRAL_ONBOARDING_CODE_ENABLED=true` en même temps ou juste après : les filleuls
   saisissent le code dès l'inscription.
3. `KPB_REFERRAL_INSTALL_REFERRER_ENABLED=true` en dernier, une fois la Data safety Play
   reportée (lecture du referrer).

Vérification : `curl -s https://api.kpbeducation.cloud/api/config/app | jq '.features |
{referralInstallReferrer, referralOnboardingCode, referralLeaderboard}'`. Retour arrière :
remettre la variable à `false` (ou la retirer) dans le `.env` de production et recréer le
conteneur `api` ; l'app se replie au prochain démarrage. La recette appareil est dans
`docs/device-qa-build57.md` (section « Parrainage »).

## 9. Exploitation et données

- Conservation des empreintes anti-fraude : 180 jours (purge quotidienne à 03 h 17), durée
  **validée par le propriétaire le 18/10/2026**. Autres données de campagne : tant que le compte existe ;
  suppression du compte → participation, filleul et empreintes purgés (un prix versé garde sa
  trace, nom public figé). Voir `docs/data-inventory.md` §6.
- Toutes les actions de l'équipe écrivent un `AdminAuditEvent` (`purposeCode =
  referral_campaign`).
- Code : `backend/src/modules/referrals/campaigns/` ; contrats : `docs/api-contracts.md`,
  section « Compétition ambassadeurs ».
