# Relecture mensuelle des 36 bourses aux sources officielles — 24/10/2026

> Journal de ce qui a été **réellement lu** le 24/10/2026, et de ce qui ne l'a
> pas été. Les rapports bruts des neuf relecteurs (une entrée par fiche, une
> citation par source) sont versionnés dans
> `docs/evidence/catalog-2026-10-24/G1.json` … `G9.json`. Méthode identique à
> la vague du 29/09 (`docs/catalog-verification-2026-09-29.md`).

## Méthode

- Les 111 pages sources ont d'abord été téléchargées (`curl`, User-Agent de
  navigateur). Ensuite, neuf relecteurs indépendants ont relu chacun quatre
  fiches, en lecture seule sur le dépôt. Ils ont retenté les pages en échec et
  enregistré en texte chaque page relue.
- **199 citations** au total. **188** sont retrouvées mot pour mot (espaces,
  guillemets et casse normalisés) dans les pages enregistrées. Les **11**
  autres viennent toutes de pages lues uniquement par `WebFetch`, qui extrait
  le texte par un modèle : Chevening (5), DAAD EPOS (5) et DAAD
  Helmut-Schmidt (1). Voir les exceptions ci-dessous.
- `checkedAt` de chaque fiche = l'heure de fin de lecture de son lot (heure du
  rapport, `date -u`), entre 07:10 et 07:17 UTC. Aucune date n'a été posée sur
  une fiche non relue.
- Les corrections ont été appliquées par un seul rédacteur, chacune justifiée
  par une citation de la page.

## Résultat

| Verdict | Fiches |
|---|---|
| inchangées (`confirmed`) | 23 |
| corrigées (`needs_changes`) | 9 |
| **non relues — `checkedAt` inchangé** | **4** |

### Fiches NON relues (gardent leur ancienne date)

| Fiche | Cause | Date gardée | Péremption |
|---|---|---|---|
| `stipendium_hungaricum_2027_forecast` | tous les sites Tempus affichent « Karbantartás / Maintenance » ; seul le portail de candidature se lit | 29/09/2026 | **30/10/2026** |
| `daad_helmut_schmidt_2027` | daad.de répond 403 à `curl` et 503 à `WebFetch` ; le PDF de l'appel est illisible | 29/09/2026 | **30/10/2026** |
| `up_mastercard_scholars_2027` | blocage Cloudflare (403) sur tout `www.up.ac.za` ; non contourné | 29/09/2026 | **30/10/2026** |
| `cmu_africa_mastercard_2027` | erreur de certificat TLS côté site (`curl` 60) et 503 en `WebFetch` | 07/10/2026 | 07/11/2026 |

Sans relecture de ces trois premières fiches **dans un navigateur** d'ici le
30/10, le test de fraîcheur (`reste importable à la date du jour`) passera au
rouge et bloquera tout déploiement du backend.

Pour UP, les formulaires officiels 2027
(`drupalwebprod-files.up.ac.za/Public/2026-04/…`) se lisent. Ils confirment le
statut `closed` (31/08 en Licence, 30/09 en postgrade). Ils **contredisent**
cependant l'éligibilité de la fiche, qui est donc à revoir lors de la
relecture au navigateur :
- moyenne d'au moins 70 % ;
- première année de Master seulement (pas d'Honours) ;
- liste de facultés différente ;
- droit en Licence réservé à la SADC.

## Exceptions à la règle « cinq sources lues et citées mot pour mot »

- **`chevening_2027`** : `curl` échoue (HTTP/2, puis coupure). Les cinq pages
  ont été lues par `WebFetch` à **deux reprises indépendantes** (relecteur,
  puis rédacteur à 07:17), avec des citations concordantes : campagne close,
  « 2,800 hours », « A contribution of up to £75 for TB testing, where this is
  required », offre inconditionnelle « 17:00 BST (UK time) on 8 July 2027 ».
  La page ne donne plus les jours exacts de la campagne 2026 (« August 2026 »,
  « October 2026 ») : les dates de la fiche (04/08, 06/10 à 11 h UTC) restent
  celles relues le 29/09.
- **`daad_epos_2027`** : daad.de refuse `curl` ; lecture par `WebFetch`, comme le
  29/09.
  - Le passage en `open` proposé par le relecteur n'est **pas appliqué** : il
    n'y a pas de date limite centrale, et le validateur exige une clôture
    confirmée pour un cycle ouvert.
  - L'ajout « after the Bachelor's degree » n'est pas appliqué non plus : la
    citation vient de `WebFetch` seul.
- **`kazakhstan_foreign_students_2027_forecast`** : `studyin.kz/admission` reste
  une application JavaScript (502 ce jour). Le relecteur proposait de la
  remplacer par la page Bolashak. Ce remplacement est **refusé** : c'est
  toujours le portail officiel de dépôt, cité tel quel par Bolashak (« at the
  following link: https://studyin.kz/admission »).
- **`ashesi_scholarship_2027`** : deux pages lues sur l'instantané du jour.
  Une nouvelle tentative a ensuite été bloquée par l'anti-robot Sucuri (307).

## Corrections appliquées

| Fiche | Correction | Preuve |
|---|---|---|
| `york_pise_2027_forecast` | `opensAt` = 01/11/2026 00:00 heure de Toronto ; libellé et description (« le formulaire ouvre le 1er novembre ») | « Application opens November 1, 2026 ! » |
| `uoft_lester_b_pearson_2027` | libellé : ouvert aux seuls élèves déjà nommés ; nomination (09/10) et OUAC (16/10) closes ; dossier avant le 06/11 | « School nomination deadline: October 9, 2026 Student OUAC admission application deadline: October 16, 2026 » |
| `turkiye_isdb_joint_2027_forecast` | financement Licence : « prêt remboursable après les études et l'emploi », et non plus « sans intérêt » (non publié) | « required to repay the loan after graduation and employment, in easy installments » |
| `si_global_professionals_2027_forecast` | appel 2027 publié, voir le détail sous le tableau | « Submit your SI Scholarship application here between 8-24 February 2027. » |
| `auc_excellence_2027` | réussite académique de 20 % jusqu'à 100 % (au lieu de 20–60 %) ; autres catégories « jusqu'à 30 % » ; « Music » remplace Music Technology / Musical Arts ; page mise à jour le 15/10 | « Coverage starts at 20% and can reach 100% … », « Coverage up to 30%. », « Last Updated : Oct 15, 2026 » |
| `australia_awards_africa_2028_forecast` | source `eligibility` = profil Afrique 2027 (PDF, inchangé), la page « apply » n'affichant plus les critères | « Not already hold or be undertaking a Master’s degree or equivalent » |
| `open_doors_russia_2027` | source `benefits` = accueil (FAQ), l'allocation n'étant plus décrite sur /about | « The scholarship covers tuition fees and provides a monthly stipend. » |

Détail de la correction `si_global_professionals_2027_forecast` :
- `dateConfidence` passe à `confirmed`, avec ouverture le 08/02/2027 et clôture le 24/02/2027 à 14:59 CET ;
- le statut reste `forecast` jusqu'à l'ouverture ;
- libellé, description, éligibilité (3 000 h chez trois employeurs au plus), pièces et étapes sont alignés sur l'appel 2027-2028.

## Rien à changer (pages relues, identiques à la fiche)

UWC Burkina Faso, Kenya et Tanzanie, Türkiye Burslari, Roumanie, Brunei,
Heydar Aliyev, TaiwanICDF, Qatar University, McCall MacBain, Schwarzman,
Gates Cambridge, Knight-Hennessy, Rhodes Afrique australe, ETH ESOP, JJ/WBGSP,
Ashesi, ALU, Eiffel, Erasmus Mundus, Mastercard Foundation, UCT (toujours
`suspended`).

Pour Eiffel, seule la date interne UTBM (28/10) citée dans le libellé n'a pas de
source dans la fiche. Elle avait été vérifiée sur la page de l'UTBM le 07/10.

## Après fusion

Déployer le backend, puis lancer `publish-catalog` (VPS ops, `dry_run=false`) :
le déploiement ne publie pas les données.
