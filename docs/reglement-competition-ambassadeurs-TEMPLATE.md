# Règlement — Compétition des ambassadeurs KPB Education ({{PERIODE}})

> **MODÈLE pour une relance — ne pas publier tel quel.** Copie du règlement de novembre 2026
> (`docs/reglement-competition-ambassadeurs-novembre-2026.md`, texte arrêté le 18/10/2026)
> dont **chaque date est remplacée par un champ à remplir**. Les dates de la relance (alignée
> sur la sortie de la build 59) ne sont **pas décidées** : rien ici ne doit être deviné.
>
> | Champ | À remplir avec | Exemple (novembre 2026) |
> |---|---|---|
> | `{{PERIODE}}` | mois et année, pour le titre | novembre 2026 |
> | `{{DATE_DEBUT}}` | 1er jour, en toutes lettres | 1er novembre 2026 |
> | `{{DATE_FIN}}` | dernier jour inclus, en toutes lettres | 10 novembre 2026 |
> | `{{DATE_DEBUT_ABIDJAN}}` | la veille de `{{DATE_DEBUT}}` (UTC+0) | 31 octobre |
> | `{{DATE_FIN_ABIDJAN}}` | `{{DATE_FIN}}` sans l'année | 10 novembre |
> | `{{DATE_RESULTATS}}` | date d'annonce des résultats définitifs | 17 novembre 2026 |
> | `{{AAAA-MM}}` | année-mois du fichier publié | 2026-11 |
>
> À **reconfirmer** avec le propriétaire avant publication, même sans changement : les prix
> (§7), les villes (§3), le délai de versement (7 jours) et de réclamation (15 jours).
>
> Publication : copier ce modèle en `docs/reglement-competition-ambassadeurs-<période>.md`,
> remplir les champs, en tirer la page `web/public/reglement-ambassadeurs-{{AAAA-MM}}.html`
> (même texte, sans ce cadre ni les notes internes ni les mentions de décision), puis poser
> son lien `https://kpbeducation.cloud/reglement-ambassadeurs-{{AAAA-MM}}.html` dans « Lien du
> règlement (https) » de la nouvelle campagne (`rulesUrl`). C'est lui que la page publique du
> classement et l'écran « Compétition » de l'application ouvrent par « Lire le règlement » ;
> le lancement de la campagne est refusé sans lui. Vérifier après remplissage :
> `grep -n '{{' <fichier>` ne doit rien rendre.

## 1. Organisateur

La compétition est organisée par **KPB Global L.L.C-FZ**, société à responsabilité limitée
de zone franche immatriculée auprès de la Meydan Free Zone (Meydan City Corporation, Émirat
de Dubaï) sous la licence n° 2537631.01, éditrice de l'application **KPB Education**
(décision du propriétaire du 17/10/2026 : l'application s'appelle KPB Education ; le volet
commercial, dont cette compétition, relève de KPB Global L.L.C-FZ).

KPB Global L.L.C-FZ est aussi le responsable du traitement des données personnelles
(voir la politique de confidentialité).

## 2. Dates

La compétition se déroule **du {{DATE_DEBUT}} à 00 h 00 au {{DATE_FIN}} à
23 h 59, heure d'Afrique de l'Ouest (UTC+1, heure de Niamey, Lagos, Cotonou, Douala)**.
À Abidjan (UTC+0), cela correspond au {{DATE_DEBUT_ABIDJAN}} à 23 h 00 jusqu'au {{DATE_FIN_ABIDJAN}} à 22 h 59.

## 3. Qui peut participer

- Les **ambassadeurs activés par l'équipe KPB** et inscrits à la compétition. On ne
  s'inscrit pas seul : l'équipe active l'ambassadeur à partir de son compte dans
  l'application.
- Villes concernées : Maradi, Niamey, Cotonou, Abidjan, Douala (liste que l'équipe peut
  compléter avant le début de la compétition).
- **Mineurs (16–17 ans)** : acceptés avec une **autorisation parentale signée**, vérifiée
  par l'équipe KPB avant le classement. Sans cette autorisation vérifiée, l'ambassadeur
  mineur n'apparaît pas au classement et ne peut pas recevoir de prix. Si l'âge n'est pas
  connu, l'équipe le confirme avant de classer.
- Les membres de l'équipe KPB ne participent pas, ni leurs proches (famille proche,
  conjoints) (décision du propriétaire, 18/10/2026).

## 4. Comment on gagne des points

Chaque ambassadeur a un code de parrainage : celui affiché dans l'écran Parrainage et dans
l'écran « Compétition » de l'application. Son ancien code d'ambassadeur « KTOU-… », s'il en a
un, compte de la même façon.

Un filleul compte pour **1 point** quand, **pendant la compétition** :

1. il **crée son compte** dans l'application ;
2. il **vérifie son e-mail** (code reçu par e-mail, ou connexion Google) ;
3. il **complète son profil** : nom, téléphone, date de naissance (accord d'un parent s'il
   est mineur), au moins un domaine d'études et un pays visé, et l'acceptation des
   conditions ;
4. il **saisit le code de l'ambassadeur** dans l'écran Parrainage de l'application.

Un compte créé avant le {{DATE_DEBUT}} ne compte pas. Un code saisi après le {{DATE_FIN}} à
23 h 59 (UTC+1) ne compte pas. Un filleul ne peut être rattaché qu'à un seul ambassadeur, et
une seule fois.

**Le filleul ne reçoit rien** pendant la compétition.

## 5. Classement

- Le classement est calculé automatiquement toutes les 5 minutes et affiché sur
  `kpbeducation.cloud/classement/` avec le prénom, l'initiale du nom et la ville de chaque
  ambassadeur (par exemple « Aïcha K. — Niamey ») et son nombre de filleuls qualifiés.
- En cas d'égalité, l'ambassadeur qui a atteint ce nombre **le premier** passe devant.
- **Le classement reste provisoire** jusqu'à la vérification finale par l'équipe KPB.

## 6. Loyauté et disqualification

Pour que la compétition reste juste, l'équipe KPB peut **vérifier**, **ne pas compter** ou
**retirer** des filleuls, et **disqualifier** un ambassadeur, notamment en cas de :

- auto-parrainage (utiliser son propre code) ou parrainage croisé ;
- plusieurs comptes créés depuis le **même téléphone** (un seul compte compte par
  téléphone) ;
- **rafales** d'inscriptions suspectes (beaucoup de comptes en très peu de temps, depuis
  la même connexion) ;
- adresses e-mail **jetables** ;
- comptes fictifs, achetés, ou créés sans l'accord de la personne ;
- pression, promesse d'argent ou de cadeau faite aux filleuls ;
- tout autre comportement contraire à l'esprit du jeu.

Les inscriptions signalées automatiquement sont d'abord **mises « à vérifier »**, pas
supprimées : elles ne comptent pas tant que l'équipe ne les a pas validées (par exemple
un atelier dans un lycée où tout le monde utilise le même Wi-Fi). Chaque décision de
l'équipe est enregistrée avec son motif.

Plafond technique : au-delà de 30 codes saisis en une heure pour le même ambassadeur, les
saisies suivantes sont refusées temporairement (le filleul réessaie plus tard).

## 7. Prix

| Rang | Prix |
|---|---|
| 1er | 100 000 FCFA |
| 2e | 50 000 FCFA |
| 3e | 30 000 FCFA |

- Les prix sont versés par **Wave** (ou autre moyen convenu) dans les **7 jours** qui
  suivent la validation des résultats (décision du propriétaire, 18/10/2026).
- **Pour un ambassadeur mineur, le prix est versé à son parent** (ou représentant légal)
  ayant signé l'autorisation.
- Un lauréat qui ne peut pas être joint ou ne fournit pas les informations de versement
  dans un délai de **15 jours** perd son prix ; le prix **passe alors au suivant** du
  classement (le 4e devient 3e, et ainsi de suite) (décision du propriétaire, 18/10/2026).
- Au versement, l'équipe KPB demande une **pièce d'identité** du lauréat, ou du parent
  (représentant légal) pour un lauréat mineur.
- Les prix ne sont ni échangeables ni cessibles. La fiscalité éventuelle du prix est à la
  charge du lauréat (décision du propriétaire, 18/10/2026).

## 8. Résultats

À la fin de la compétition, le classement est gelé, l'équipe vérifie les filleuls et les
autorisations parentales, puis valide le podium. Les résultats définitifs remplacent alors
le classement provisoire sur la même page. Les résultats définitifs sont annoncés le
**{{DATE_RESULTATS}}**.

## 9. Données personnelles

- **Public** : prénom, initiale du nom, ville et nombre de filleuls des ambassadeurs
  classés. Rien d'autre : ni e-mail, ni téléphone, ni nom des filleuls.
- **Équipe KPB seulement** : identité et e-mail des ambassadeurs et de leurs filleuls,
  statut de chaque filleul, autorisation parentale (statut, date, qui l'a vérifiée),
  versements. Pour la lutte contre la fraude : des **empreintes chiffrées** de l'adresse IP
  et du téléphone au moment de la saisie du code (jamais l'adresse ni l'identifiant en
  clair), conservées **180 jours** (durée validée par le propriétaire le 18/10/2026).
- Tu peux demander l'accès à tes données ou leur suppression depuis l'application
  (Profil → exporter / supprimer mon compte) ou en écrivant à l'équipe. Supprimer son
  compte retire sa participation et ses filleuls de la compétition ; la trace d'un prix
  déjà versé est gardée pour la comptabilité.
- La compétition est décrite dans la politique de confidentialité (section « Parrainage et
  compétition des ambassadeurs ») : `https://kpbeducation.cloud/confidentialite.html`.

## 10. Divers

KPB peut modifier, suspendre ou arrêter la compétition en cas de problème technique ou de
fraude massive ; les participants en sont informés sur la page du classement. La
participation implique l'acceptation de ce règlement.

Ce règlement est régi par le **droit des Émirats arabes unis (Émirat de Dubaï)**. Toute
réclamation s'adresse à l'équipe KPB à **contact@kpbeducation.com** (décision du
propriétaire, 18/10/2026).

Apple et Google ne sont ni organisateurs ni partenaires de cette compétition.
