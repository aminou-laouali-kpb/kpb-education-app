# Runbook — Compétition des ambassadeurs (parrainage)

Compétition de **novembre 2026** : du 1er au 10/11 inclus, heure d'Afrique de l'Ouest
(Africa/Lagos, UTC+1), prix 100 000 / 50 000 / 30 000 FCFA, villes Maradi, Niamey, Cotonou,
Abidjan, Douala (pilotables). Décisions du propriétaire du 17/10/2026. Règlement (brouillon) :
`docs/reglement-competition-ambassadeurs-novembre-2026.md`.

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
4. Verser par Wave, puis **Noter le versement** : référence Wave, date, bénéficiaire. Le serveur
   refuse « l'ambassadeur » comme bénéficiaire d'un lauréat mineur.
5. **Clore** : résultats définitifs, plus aucun recalcul ; la page publique retire la mention
   « provisoire ».
6. **Export CSV** (classement ou filleuls) pour archive — fichiers à données personnelles, à
   garder hors des canaux publics.

## 8. Option build 57 (préparée côté serveur, rien d'activé côté app)

Rien n'est obligatoire dans l'app pour la compétition. Ce qui est prêt côté serveur :

- `POST /referrals/redeem` lit l'en-tête facultatif **`X-KPB-Device-Id`** (identifiant
  d'installation, haché) : un compte qualifié par appareil sans dépendre du jeton push.
- Le lien Google Play d'`invite.html` porte `referrer=utm_source=invite&utm_medium=referral&ref=<CODE>`.
- `GET /referrals/campaigns/current` (élève connecté) : campagne en cours, rang, nombre de
  qualifiés, à vérifier, en attente, compte à rebours.

Non fait dans l'app (choix délibéré : la build 57 a déjà son pack store figé, et ajouter un
plugin natif change la déclaration des SDK) — à faire dans une build ultérieure, derrière un
drapeau fermé (`KPB_REFERRAL_INSTALL_REFERRER_ENABLED`, `features.referralLeaderboard`) :

1. **Play Install Referrer** : paquet `play_install_referrer` (Android seulement). Au premier
   lancement, lire `referrer`, extraire `ref`, le garder en local ; à la fin de l'onboarding,
   proposer le code prérempli dans l'écran Parrainage (l'utilisateur confirme : pas de
   rattachement silencieux). Déclarer « identifiants d'appareil / source d'installation » dans
   la fiche Data safety si nécessaire. iOS n'a pas d'équivalent : garder la saisie manuelle.
2. **Champ « code de ton parrain »** en dernière étape d'onboarding, facultatif, appelant
   `POST /referrals/redeem` après la synchro du profil.
3. **Identifiant d'installation** : UUID aléatoire stocké en local (pas l'IMEI, pas l'ID
   publicitaire), envoyé en `X-KPB-Device-Id` sur `POST /referrals/redeem` seulement.
4. **Écran classement in-app** : `GET /referrals/campaigns/current` + lien vers la page
   publique ; le remplacer par l'écran ambassadeur actuel pour un ambassadeur sans espace
   « cash ».

## 9. Exploitation et données

- Conservation des empreintes anti-fraude : 180 jours (purge quotidienne à 03 h 17), durée
  **À VALIDER (propriétaire)**. Autres données de campagne : tant que le compte existe ;
  suppression du compte → participation, filleul et empreintes purgés (un prix versé garde sa
  trace, nom public figé). Voir `docs/data-inventory.md` §6.
- Toutes les actions de l'équipe écrivent un `AdminAuditEvent` (`purposeCode =
  referral_campaign`).
- Code : `backend/src/modules/referrals/campaigns/` ; contrats : `docs/api-contracts.md`,
  section « Compétition ambassadeurs ».
