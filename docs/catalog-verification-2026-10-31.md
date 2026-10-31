# Relecture de trois bourses aux sources officielles — 31/10/2026

> Journal de ce qui a été **réellement lu** le 31/10/2026 (18 h 44–18 h 46 UTC),
> et de ce qui ne l'a pas été. Méthode : `docs/catalog-verification-sop.md`
> (« La relecture mensuelle des bourses »). Ce lot ne couvre que les trois
> fiches que la relecture du 24/10 n'avait pas pu lire (`docs/catalog-verification-2026-10-24.md`,
> § « Fiches NON relues ») et qui sont passées sous le seuil de 30 jours le
> 30/10 : le test de fraîcheur du backend (`reste importable à la date du jour`)
> était rouge sur `main` depuis cette date.

## Méthode

- Les pages HTML ont été lues dans le **navigateur intégré** (lecture du texte de
  la page affichée). Aucun anti-robot n'est apparu ; rien n'a été contourné.
- Les PDF (appel Stipendium Hungaricum, appel DAAD, formulaires UP 2027) ont été
  téléchargés par `curl` avec un User-Agent de navigateur, puis convertis en texte
  (`pdftotext`). daad.de répondait 403 et 503 le 24/10 ; il répond 200 aujourd'hui.
- **20 citations** de PDF, retrouvées mot pour mot (espaces et guillemets
  normalisés) dans les textes extraits : `docs/evidence/catalog-2026-10-31/citations-pdf.json`.
  Les pages HTML lues dans le navigateur n'ont pas été enregistrées sur disque :
  ce que ce journal en dit n'est pas vérifiable mécaniquement.
- `checkedAt` de chaque fiche = l'heure de fin de lecture de ses sources
  (`date -u`) : SH 18:44:36, DAAD 18:44:50, UP 18:46:00. Aucune date n'a été posée
  sur une fiche non relue.

## Résultat

| Fiche | Verdict | Changement |
|---|---|---|
| `stipendium_hungaricum_2027_forecast` | confirmée | « Au 29 septembre 2026 » → « Au 31 octobre 2026 » ; `checkedAt` |
| `daad_helmut_schmidt_2027` | confirmée | `checkedAt` seulement |
| `up_mastercard_scholars_2027` | **corrigée** | éligibilité alignée sur les formulaires 2027 ; `checkedAt` |

### Stipendium Hungaricum (prévision 2027-2028)

Lu : `/about/`, `/apply/`, le portail `apply.stipendiumhungaricum.hu`, l'appel BA/MA 2026-27.

- Aucun appel 2027-28 n'est publié : `/apply/` renvoie encore à l'appel 2026-27 et
  la dernière actualité du portail date du 25/02/2026. La fiche reste une prévision.
- Rythme des trois derniers cycles, d'après les actualités du portail : ouverture
  du système le 15/11/2023, le 15/11/2024, le 17/11/2025 ; « une semaine » avant la
  clôture le 8/01. L'ouverture estimée (novembre-décembre 2026) et la clôture
  estimée vers le 15/01/2027 restent cohérentes.
- Confirmés dans l'appel : allocation de 43 700 HUF, logement de 40 000 HUF,
  assurance complémentaire jusqu'à 65 000 HUF, deux programmes au plus, minimum de
  56 points sur 100, clôture 2026-27 « 15 January 2026, 2 p.m. », certificat
  médical exigé des seuls boursiers.

### DAAD Helmut-Schmidt 2027

Lu : page de présentation (`…/ppgg/`) et appel officiel ST42 (édition 05/2026).

- Confirmés mot pour mot : période du 1ᵉʳ juin au 31 juillet 2026, 992 € par mois,
  « upper third », sélection en octobre-novembre, réponses en décembre-janvier,
  taux « sur place » de 500 € au 4ᵉ semestre du Master « Social Protection »,
  cours d'allemand préalable d'au plus 4 mois, **sept** Masters listés.
- Le cycle reste `closed` (clôture passée).

### University of Pretoria — Mastercard Foundation Scholars 2027

Lu : les quatre pages `up.ac.za` de la fiche et les deux formulaires 2027.

- Statut confirmé : `closed`. Dates publiées : Licence 31/08/2026, postgrade
  30/09/2026 ; admission à UP « 30 June 2026 ».
- **Corrigé** d'après les formulaires 2027 (liés depuis la page officielle
  « How to apply », mis en ligne en avril 2026) :
  - moyenne (GPA) d'**au moins 70 %** (Licence et Master) ;
  - postgrade : **première année de Master** seulement, sans Master déjà obtenu
    (la fiche annonçait « Licence, Honours et Master ») ;
  - première année d'études **en 2027** ;
  - facultés financées : Economic and Management Sciences, Natural and
    Agricultural Sciences, Engineering Built Environment and IT, Humanities
    (hors Psychologie en postgrade), Law, Education ; **Droit en Licence réservé
    aux candidats de la SADC**.
- **Désaccord entre deux pages officielles, non tranché ici.** La page
  `application-instructions` (liens vers des annuaires 2018) cite encore
  « Honours » et une liste de facultés plus courte (Humanities : Political ou
  International Studies seulement). La fiche suit les formulaires 2027, plus
  récents et propres au cycle. Une personne de l'équipe doit demander à
  `mcfsp@up.ac.za` laquelle fait foi si un élève vise un Honours.

## Ce qui n'a pas été fait

- Les critères d'éligibilité **structurés** (`scholarship-catalog.eligibility.v1.ts`) n'ont pas
  été relus : leurs lignes sont rattachées aux mêmes indices (0 à 5) de la fiche,
  le critère « niveaux-ouverts » est une simple note, et ils n'excluent
  personne tant qu'ils ne sont pas tamponnés.
- Une seule lecture, par une seule personne : pas de deuxième relecteur
  indépendant comme le 29/09 et le 24/10.
- **`cmu_africa_mastercard_2027` passe sous le seuil le 07/11/2026** (relue le
  07/10 ; erreur TLS et 503 le 24/10). À relire avant cette date, sinon le test
  de fraîcheur repasse au rouge.
- Déploiement : après fusion, `publish-catalog` (import → reconcile → switch).
  Sans `reconcile`, les lignes en base gardent l'ancien contenu.
