# IGENSIA Education — provenance des faits ajoutés aux fiches

Consultation : **16/10/2026**, sites officiels des écoles et fiches RNCP de
France Compétences. Données dans `src/modules/catalog/igensia-enrichment.ts` et
`igensia-import.ts` (écoles) ; ce fichier en est la version lisible, et le test
`igensia-enrichment.spec.ts` vérifie que chaque URL du code y figure.

Règles :

- **Tarifs et rentrées : la source du propriétaire fait foi** (`igensia_2027.pdf`,
  `abc_2027.xlsx`). Un écart avec le site est signalé ci-dessous, jamais appliqué.
- Rien d'inventé : ce qui est introuvable reste vide (liste en fin de fichier).
- Le `sourceUrl` de chaque fiche est la page officielle de la formation.
- Aucune dépense Treg : le web a suffi.

## Fiches RNCP (France Compétences)

| Formation (intitulé de la source) | Fiche | Intitulé exact | Niveau | Certificateur(s) |
|---|---|---|---|---|
| ISB — Bachelor Business & Marketing - Parcours 360 | [RNCP38808](https://www.francecompetences.fr/recherche/rncp/38808/) | Responsable d'activité commerciale et marketing | 6 | Institut de Gestion Sociale (IGS) |
| ISB — Mastère pro Expert Financier | [RNCP36596](https://www.francecompetences.fr/recherche/rncp/36596/) | Expert financier | 7 | IGS |
| ISB — Mastère pro Management des organisations | [RNCP38825](https://www.francecompetences.fr/recherche/rncp/38825/) | Manager des organisations | 7 | IGS |
| ISB — Bachelor Business Development - Event Sales | [RNCP39556](https://www.francecompetences.fr/recherche/rncp/39556/) | DipViGrL - Responsable du développement commercial et marketing | 6 | IGS ; ministère de l'Enseignement supérieur et de la Recherche |
| ISB — Bachelor Business Development - Sales Stategy | [RNCP39556](https://www.francecompetences.fr/recherche/rncp/39556/) | idem | 6 | idem |
| ISB — Mastère Parcours International business développement | [RNCP42780](https://www.francecompetences.fr/recherche/rncp/42780/) | DIPLOVIS - Management stratégique et commerce international | 7 | IGS ; ministère (diplôme visé) |
| ISB — Bachelor Droit | [RNCP41496](https://www.francecompetences.fr/recherche/rncp/41496/) | Attaché juridique | 6 | ADDSA (branche du personnel des cabinets d'avocats) |
| ISB — Mastère pro Juriste d'Affaires | [RNCP40682](https://www.francecompetences.fr/recherche/rncp/40682/) | Juriste d'affaires | 7 | IGS |
| ISB — Bachelor Gestion et Finance d'entreprise | [RNCP42510](https://www.francecompetences.fr/recherche/rncp/42510/) | Responsable en gestion d'activité | 6 | IGS |
| ISB — Mastère Stratégie Digitale & Business | [RNCP42781](https://www.francecompetences.fr/recherche/rncp/42781/) | DIPLOVIS - Marketing stratégique et développement d’affaires | 7 | IGS ; ministère (diplôme visé) |
| ISB — Mastère Pro Manager international des industries et services en santé | [RNCP42197](https://www.francecompetences.fr/recherche/rncp/42197/) | Manager international des industries et services en santé | 7 | IGS |
| IGENSIA Tech — Bachelor Réseaux Cloud & Cyber | [RNCP41996](https://www.francecompetences.fr/recherche/rncp/41996/) | Administrateur systèmes, réseaux et bases de données | 6 | IGS |
| IGENSIA Tech — Mastère pro IT Project Manager | [RNCP40239](https://www.francecompetences.fr/recherche/rncp/40239/) | Directeur de projets informatiques | 7 | IGS |
| IGENSIA RH — MBA International Human Resource Management | [RNCP41092](https://www.francecompetences.fr/recherche/rncp/41092/) | Manager international des ressources humaines | 7 | IGS |
| IGENSIA RH — Bachelor RH & transfo digitale | [RNCP41181](https://www.francecompetences.fr/recherche/rncp/41181/) | DIPLOVIS - RH et transformation digitale | 6 | IGS ; ministère (diplôme visé) |
| IGENSIA RH — Mastère pro Manager des Ressources Humaines | [RNCP38833](https://www.francecompetences.fr/recherche/rncp/38833/) | Manager des ressources humaines | 7 | IGS |
| ABC — BBA, MSc Luxury Brand Management, MSc Digital Marketing | [RNCP41361](https://www.francecompetences.fr/recherche/rncp/41361/) | Manager international | 7 | IGS |
| ABC — American MBA | [RNCP38825](https://www.francecompetences.fr/recherche/rncp/38825/) | Manager des organisations | 7 | IGS |

Toutes ces fiches étaient **actives** le 16/10/2026.

## Pages officielles des formations (`sourceUrl`) et autres faits

### IGENSIA School of Business

- Bachelor Business & Marketing - Parcours 360 — https://www.igensia-school-of-business.fr/formations/marketing-digital-intelligence-artificielle/bachelor-business-et-marketing-parcours-360
- Mastère pro Expert Financier — https://www.igensia-school-of-business.fr/formations/finance-gestion-audit/mastere-pro-expert-financier
- Mastère pro Management des organisations — https://www.igensia-school-of-business.fr/formations/marketing-digital-intelligence-artificielle/mastere-pro-management-des-organisations
- Bachelor Business Development - Event Sales — https://www.igensia-school-of-business.fr/formations/commerce-vente-achats/bachelor-en-sciences-du-management-event-management
- Bachelor Business Development - Sales Stategy — https://www.igensia-school-of-business.fr/formations/commerce-vente-achats/bachelor-en-sciences-du-management-business-development
  — **langue : français** (« Candidats hors UE : … niveau Français minimum B2 »)
- Mastère Parcours International business développement — https://www.igensia-school-of-business.fr/formations/commerce-vente-achats/mastere-international-business-development
  — **langue : anglais** (« Dispensé 100 % en anglais »)
- Bachelor Droit — https://www.igensia-school-of-business.fr/formations/droit-des-affaires/bachelor-droit
  — **langue : français** (« niveau Français minimum B2 »)
- Mastère pro Juriste d'Affaires — https://www.igensia-school-of-business.fr/formations/droit-des-affaires/mastere-pro-juriste-d-affaires
- Bachelor Gestion et Finance d'entreprise — https://www.igensia-school-of-business.fr/formations/finance-gestion-audit/bachelor-gestion-et-finance-d-entreprise
  — **langue : français** (« niveau Français minimum B2 »)
- Mastère Stratégie Digitale & Business — https://www.igensia-school-of-business.fr/formations/commerce-vente-achats/mastere-strategies-digitales-des-entreprises
- Mastère Pro Manager international des industries et services en santé — https://www.igensia-school-of-business.fr/formations/management-entrepreneuriat/mastere-pro-manager-international-des-industries-et-services-en-sante

### IGENSIA Tech

- Bachelor Réseaux Cloud & Cyber — https://www.igensiatech.fr/formations/bachelors/bachelor-reseaux-cloud-cybersecurite
- Mastère pro IT Project Manager — https://www.igensiatech.fr/formations/masteres-pro/chef-de-projet-informatique

### IGENSIA RH

- MBA International Human Resource Management — https://www.igensia-rh.com/formations/post-bac-4/mba-international-human-resource-management
  — **langue : anglais** (« 100 % taught in English »)
- Bachelor RH & transfo digitale — https://www.igensia-rh.com/formations/post-bac/bachelor-vise-rh-et-transformation-digitale
- Mastère pro Manager des Ressources Humaines — https://www.igensia-rh.com/formations/post-bac-3/master-professionnel-manager-rh-filiere-rh

### American Business College (ABC)

Programmes « Curriculum 100% in English » (déjà dans la source) ; accrédités
aux États-Unis par l'IACBE (pages des programmes et
https://www.american-business-college-paris.com/abc-paris/about-us/abc-paris-accreditations).

| Programme | Page (`sourceUrl`) | Durée | Entrée |
|---|---|---|---|
| BBA | https://www.american-business-college-paris.com/programs/bachelor-degree/bachelor-of-business-administration | 4 ans (8 semestres + stage de 6 mois) | bac / niveau 4 ; transfert après 1–3 ans |
| Bachelor in Fashion & Luxury Retail Management | https://www.american-business-college-paris.com/programs/bachelor-degree/bachelor-luxury-in-paris | 3 ans (5 semestres + stages) | bac / niveau 4 ; transfert après 1–2 ans |
| MSc Luxury Brand Management | https://www.american-business-college-paris.com/programs/master-degree/master-of-science-luxury-brand-management | 2 ans (4 semestres + stage de 6 mois) | diplôme en 3 ans (1re année) ; en 4 ans (2e année) |
| MSc Digital Marketing | https://www.american-business-college-paris.com/programs/master-degree/master-of-science-digital-marketing | 2 ans (4 semestres + stage de 6 mois) | idem |
| American MBA | https://www.american-business-college-paris.com/programs/master-degree/american-mba | 1 ou 2 ans + stage de 6 mois | idem + 2 ans d'expérience |

- Anglais (bachelors) : IELTS 6.0, TOEFL iBT 70, PTE Academic 54, Duolingo 100, Cambridge B2 First.
  Notes minimales : GPA 2.7/4, bac mention AB (12/20), IB 28 ; masters : GPA 2.7 (1re année) / 3.0 (2e année).
- Candidature : en ligne, https://www.american-business-college-paris.com/online-application ;
  étude du dossier, échange Teams/téléphone, entretien en anglais. Hors UE : avant le 1er juillet (automne).
- Frais : candidature 60 € (`applicationFeeEur`), acompte 1 500 € — https://www.american-business-college-paris.com/student-life/finance-studies-tuition
- Contact admissions : admission-abc-paris@igensia.com (même page).
- Mode de candidature : `admissionModes` = Dossier, Entretien ; `procedureType` = `hors_eef` (candidature directe).

## Écarts avec les sources du propriétaire (NON appliqués — À VALIDER)

| Formation | Source du propriétaire | Site officiel (16/10/2026) |
|---|---|---|
| ISB Bachelor Business & Marketing - Parcours 360 | rentrée mars 2027 (Paris) | « Février 2027 ou Septembre 2027 » (Paris) |
| ISB Mastère pro Expert Financier | rentrée mars 2027 (Paris) | « Février 2027 ou septembre 2027 » (Paris) |
| ISB Mastère pro Management des organisations | rentrée mars 2027 (Paris) | « Paris : Février 2027 » |
| ISB Mastère International business développement | campus Paris | Paris, Toulouse |
| ISB Mastère Stratégie Digitale & Business | campus Paris | Paris, Toulouse |
| ISB Mastère Pro Manager int. industries et services en santé | entrée M1, prérequis Bac+3 (durée calculée 2 ans) | « 12 mois », prérequis « Bac+4 scientifique validé dans le domaine de la santé » |
| IGENSIA RH MBA International HRM | rentrées mars et septembre 2027, prérequis Bac+3 | « février 2027 et octobre 2027 », Bac+4 / 240 ECTS et TOEIC 750 ou TOEFL 80 |
| IGENSIA RH Mastère pro Manager des RH | rentrée septembre 2027, Paris et Lyon | « rentrée unique en octobre 2027 », 100 % alternance, Paris, Lyon et Toulouse |
| IGENSIA Tech Mastère pro IT Project Manager | — | « Septembre / Octobre 2027 », en alternance ou formation continue |
| ABC American MBA | 16 000 €/an | 12 900 € (année 1) / 16 000 € (année 2), hors UE |
| ABC MSc Digital Marketing | 12 900 €/an | 12 900 € (année 1) / 14 000 € (année 2), hors UE |
| ABC MSc Luxury Brand Management | 12 900 €/an | 12 900 € (année 1) / 15 500 € (année 2), hors UE |
| ABC (tous) | rentrée FALL 2027 | deux rentrées : septembre (automne) et février (printemps) |

Le PDF IGENSIA demande « B2 minimum dans la langue du programme » : sur les
pages ISB, les candidats hors UE doivent justifier d'un **français B2** pour les
bachelors Droit, Gestion et Finance, Business Development - Sales Strategy.

## Introuvable — reste vide

- **Langue d'enseignement** non publiée : ISB Bachelor Business & Marketing - Parcours 360,
  Bachelor Business Development - Event Sales, Mastère pro Expert Financier, Mastère pro
  Management des organisations, Mastère pro Juriste d'Affaires, Mastère Stratégie Digitale &
  Business, Mastère Pro Manager international des industries et services en santé ; IGENSIA
  Tech (les 2 formations) ; IGENSIA RH Bachelor RH & transfo digitale et Mastère pro Manager
  des RH.
- **ISB Bachelor Data Digital Business** : aucune page officielle trouvée (ni sur le site ISB,
  ni ailleurs) ; ni fiche RNCP (le PDF dit « VISA en cours de validation »), ni langue.
- **ABC Bachelor in Fashion & Luxury Retail Management** : aucune fiche RNCP citée par l'école
  (seule l'accréditation IACBE).
- **ESA Casablanca** (`partner-esa-casa`) : non modifiée (fiche du seed partenaires, hors de
  cet import) ; elle reste citée dans le texte des écoles IGENSIA.
