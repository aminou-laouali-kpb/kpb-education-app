# Catalogue Amérique du Nord — universités non partenaires (Canada, États-Unis)

Demande du propriétaire (16/10/2026) : ajouter au catalogue des universités
**non partenaires** (`isPartner: false`) du Canada et des États-Unis, choisies
pour les élèves d'Afrique francophone, en commençant par les établissements
anglophones. Sources consultées le **16/10/2026** sur les sites officiels ;
provenance fait par fait : `backend/scripts/data/amerique-du-nord-2027.sources.md`.
Import : `npm run import:north-america` (runbook :
`docs/runbook-catalogue-amerique-du-nord.md`).

**Livré : 36 établissements (26 au Canada, 10 aux États-Unis), 172 formations.**
Première passe (16/10/2026) : 20 établissements, 97 formations. Seconde passe
Canada (17/10/2026, décisions du propriétaire) : 16 établissements, 75
formations — Québec d'abord, Nouveau-Brunswick, collèges de l'Ontario à
admission plus accessible avec programme de langue en amont (section
« Canada — seconde passe » ci-dessous).

## Critères de sélection

Aucune source officielle ne publie le nombre d'étudiants africains
francophones **par établissement** (IRCC publie les permis d'études par pays de
citoyenneté et par province, pas par université ; Open Doors ne détaille pas
l'origine par campus). La sélection repose donc sur des critères vérifiables
sur le site de chaque établissement :

1. **Langue** : enseignement en anglais d'abord (demande du propriétaire), puis
   les grandes universités francophones du Québec et du Nouveau-Brunswick.
2. **Accessibilité de l'admission** : Duolingo accepté, niveau d'anglais
   demandé, admission conditionnelle ou parcours d'anglais intensif, SAT/ACT
   non exigés, moyenne minimale publiée.
3. **Coût** : frais de scolarité annuels publiés pour 2026-2027, bourses
   automatiques ou au mérite pour les internationaux, frais de candidature.
4. **Rentrées** : possibilité de commencer en janvier (printemps / hiver) en
   plus de l'automne.
5. **Domaines** demandés par ce public : informatique / IA, data, business /
   finance, ingénierie, santé publique.
6. **Pas de doublon** : l'Université d'Ottawa (bilingue, très demandée) est
   déjà au catalogue (`uottawa`) — elle n'est pas recréée ; aucun autre
   établissement retenu n'existe dans les seeds, les imports, le catalogue
   unique, le CSV des partenaires ni le catalogue EEF (France).

## Canada — seconde passe (17/10/2026)

Décisions du propriétaire : **prioriser le Québec** (réseau UQ et établissements
très demandés par les élèves d'Afrique francophone), **compléter le
Nouveau-Brunswick**, puis, côté anglophone, des **collèges à admission plus
accessible avec un programme de langue en amont**. Relevés du 17/10/2026 ;
provenance : section « Canada — seconde passe » de
`backend/scripts/data/amerique-du-nord-2027.sources.md`.

### Critères (vérifiables sur le site de l'établissement)

1. **Québec / francophonie** : enseignement en français, établissements du
   réseau de l'Université du Québec hors UQAM / UQAC (déjà là), écoles
   d'ingénieurs et de gestion de Montréal, Bishop's (anglophone, au Québec) ;
   au Nouveau-Brunswick, l'université anglophone (UNB) et le collège
   francophone participant au **PPECFSM** (CCNB).
2. **Collèges de l'Ontario** (tous publics) : un **programme d'anglais en
   amont** publié (nom, durée, coût) qui remplit l'exigence d'anglais ou ouvre
   une admission conditionnelle ; frais internationaux 2026-2027 publiés par
   programme ; **rentrées de janvier et/ou mai** ouvertes aux internationaux le
   17/10/2026 ; **programmes alignés sur le PGWP** (code CIP affiché quand la
   fiche le donne) ; domaines demandés (informatique / IA, data, cybersécurité,
   technologie du génie, soins infirmiers auxiliaires, analytique d'affaires).
3. **Pas de doublon** : LaSalle College Montréal est déjà au catalogue unique
   (`lasalle_college_montreal`) ; aucun établissement retenu n'existe dans les
   seeds, les imports, le catalogue de démo, le CSV des partenaires ni le
   catalogue EEF (test-garde `catalog-duplicates.spec.ts`).

### Québec (8)

| Établissement | Ville | Type | Langue | Frais intl 2026-2027 | Langue en amont | Formations |
|---|---|---|---|---|---|---|
| UQTR | Trois-Rivières | université publique (UQ) | français | ≈ 27 300 CAD/an (calculette, frais compris) | non (TIFEI si la lettre l'exige) | 4 |
| UQAR | Rimouski / Lévis | université publique (UQ) | français | 24 552 CAD en 1re année | non (TEF / TCF 460) | 4 |
| UQO | Gatineau | université publique (UQ) | français | 824,56 CAD/crédit (≈ 24 737 CAD/an) | non | 4 |
| UQAT | Rouyn-Noranda | université publique (UQ) | français | 807,68 CAD/crédit (≈ 24 230 CAD/an) | non (test UQAT + rattrapage) | 4 |
| ÉTS | Montréal | école universitaire (UQ) | français | 1 171,18 CAD/crédit (≈ 38 950 CAD/an avec stages) | non | 4 |
| Polytechnique Montréal | Montréal | école universitaire | français | 1 127,57 CAD/crédit (≈ 33 827 CAD/an) | non | 5 |
| HEC Montréal | Montréal | école universitaire | français (B.A.A. bilingue) | 1 077,43 CAD/crédit au B.A.A. ; 34 500 – 39 000 CAD la M. Sc. | non | 4 |
| Université Bishop's | Sherbrooke | université publique | anglais | 983,68 CAD/crédit (29 510 CAD/an) | oui (écoles partenaires, admission conditionnelle) | 4 |

### Nouveau-Brunswick (2)

| Établissement | Ville | Type | Langue | Frais intl 2026-2027 | Langue en amont | Formations |
|---|---|---|---|---|---|---|
| Université du Nouveau-Brunswick (UNB) | Fredericton | université publique | anglais | 22 514 – 25 871 CAD/an selon la faculté | oui : PAEP (admission conditionnelle) | 4 |
| CCNB | Bathurst (5 campus) | collège public | français | 10 258 CAD/an | non (test d'admission du CCNB) | 4 |

### Collèges de l'Ontario (6)

| Collège | Ville | Frais intl (2 semestres) | Programme d'anglais en amont | Rentrées intl ouvertes | Formations |
|---|---|---|---|---|---|
| Humber Polytechnic | Toronto | 20 868 – 24 765 CAD | EAP, 2 semestres, 15 437 CAD | janv. / mai / sept. 2027 | 7 |
| Seneca Polytechnic | Toronto | 16 809 – 22 064 CAD (scolarité seule) | ELI, 8 niveaux de 7 semaines, 3 269,25 CAD/niveau, admission conditionnelle | janv. / mai 2027 | 6 |
| Conestoga College | Kitchener-Waterloo | 18 226 – 21 041 CAD (frais compris) | English Language Studies, 1 an, 11 330 CAD | janv. / mai / sept. 2027 | 6 |
| Centennial College | Toronto | 20 611 – 21 382 CAD (frais compris) | ELL, jusqu'à 5 niveaux de 15 semaines, 4 397,50 CAD/semestre | janv. / mai / sept. 2027 | 6 |
| Fanshawe College | London | 18 212 – 18 920 CAD | EAP, 10 niveaux de 8 semaines, 3 411,36 CAD/niveau | janv. / mai / sept. 2027 | 4 |
| Sheridan College | Oakville / Brampton | 19 700 – 25 792 CAD (assurance et frais compris) | EAP, 5 niveaux de 14 semaines, 16 836,44 CAD / 2 semestres | janv. / mai / sept. 2027 | 5 |

Niveaux : les diplômes et diplômes avancés de l'Ontario et les diplômes du
CCNB sont écrits **« Diplôme collégial »**, les certificats postdiplôme de
l'Ontario **« Graduate certificate »** (`normalizeDegreeLevel`, backend et
admin). L'app les affiche tels quels ; dans son filtre par niveau, ils tombent
dans « Autre » (voir « À VALIDER »).

### Écartés en seconde passe

- **George Brown Polytechnic** : site officiel inaccessible (HTTP 403).
- **Algonquin College** : disponibilités et frais seulement via icônes et
  calculateur, non lisibles.
- **Niagara College** : pages de programmes introuvables (404) ce jour-là.
- **INRS** : uniquement des cycles supérieurs de recherche.
- **Cégeps** (DEC / AEC) : aucune grille internationale 2026-2027 publiée par
  cégep (le règlement de Matane ne donne pas les montants) ; le programme
  d'exemption PEDSS vise les DEC techniques. À compléter avec des sources
  directes (voir « À VALIDER »).

## Contexte à connaître avant de recommander les États-Unis

Depuis le **1er janvier 2026** (proclamation présidentielle du 16/12/2025,
whitehouse.gov), l'entrée et la délivrance de visas sont suspendues pour les
ressortissants de plusieurs pays, dont des pays d'Afrique francophone :

- **suspension totale** (y compris visas étudiants) : Burkina Faso, Mali,
  Niger, Tchad, République du Congo, Guinée équatoriale ;
- **suspension partielle, visas F, M et J compris** : Bénin, Côte d'Ivoire,
  Sénégal, Gabon, Mauritanie ; Burundi et Togo restent sous la restriction
  partielle de la proclamation précédente (classes de visas à revérifier).

Chaque fiche américaine le rappelle sans lister les pays (« vérifie sur
travel.state.gov ») ; la liste peut évoluer. **À VALIDER** avant toute
campagne : la liste en vigueur, et l'opportunité de mettre en avant les
États-Unis auprès d'élèves de ces pays.

Côté Canada : un permis d'études demande en général une attestation
provinciale (au Québec, le CAQ). Les établissements francophones hors Québec
participant au **programme pilote pour les étudiants des communautés
francophones en situation minoritaire (PPECFSM)** offrent une voie dédiée :
l'Université de Moncton et le campus Glendon de York en font partie (liste
IRCC datée du 16/10/2026, avec l'Université d'Ottawa et l'Université de
Saint-Boniface). Au Québec, le programme d'exemption des droits
supplémentaires « selon le programme d'études et la région » **n'est pas
reconduit à partir de 2026-2027** (UQAC) ; les exemptions par entente avec le
pays de citoyenneté demeurent (Sherbrooke, UQAM).

## Canada (10) — anglophones et bilingues d'abord

| Établissement | Ville | Langue | Frais intl 2026-2027 (source) | Pourquoi | Formations |
|---|---|---|---|---|---|
| Université McGill | Montréal (QC) | anglais | 54 000 – 71 687 CAD/an selon le grade | la plus demandée au Québec ; chère, sélective | 4 |
| Université Concordia | Montréal (QC) | anglais | 1 160 – 1 400 CAD/crédit | Duolingo 105, rentrée de janvier, génie et informatique | 4 |
| Université York | Toronto (ON) | anglais ; bilingue (Glendon) | ≈ 38 000 – 47 000 CAD/an | grand choix, Glendon bilingue et PPECFSM, admission conditionnelle (YUELI) | 4 |
| Université Memorial de Terre-Neuve (MUN) | St. John's (NL) | anglais | 22 500 CAD pour 10 cours | parmi les moins chères du Canada, 3 rentrées par an | 4 |
| Université Laval | Québec (QC) | français | ≈ 14 116 CAD par session de 15 crédits | grande université francophone, automne et hiver | 4 |
| Université de Montréal (UdeM) | Montréal (QC) | français | 1 025,76 CAD/crédit, bourse d'exemption jusqu'à 14 436 CAD/an | très demandée, rentrée de janvier 2027 ouverte jusqu'au 1/11/2026 | 5 |
| Université de Sherbrooke | Sherbrooke (QC) | français | 11 975 – 16 070 CAD par trimestre | régime coopératif, bourse d'admission 2 000 CAD | 4 |
| Université du Québec à Montréal (UQAM) | Montréal (QC) | français | base + forfaitaire par crédit (montant à confirmer) | réseau UQ, programmes non contingentés | 4 |
| Université du Québec à Chicoutimi (UQAC) | Saguenay (QC) | français | fixés par le gouvernement (montant sur l'attestation) | réseau UQ, ingénierie et IA | 4 |
| Université de Moncton | Moncton (NB) | français | 15 761 CAD/an | francophone hors Québec la moins chère de la liste, PPECFSM | 4 |

## États-Unis (10) — University of Houston en tête

| Établissement | État | Frais intl 2026-2027 (source) | Duolingo | Accessibilité | Formations |
|---|---|---|---|---|---|
| University of Houston | Texas | ≈ 28 000 – 29 200 USD/an (tarif fixe 4 ans) | 105 | admission garantie (top 10 %, GPA 3.5 ou SAT/ACT), janvier ou automne | 5 |
| University of Texas at Arlington (UTA) | Texas | 27 494 USD/an | 100 (105 ingénierie) | 3 rentrées, ingénierie / data | 6 |
| University of North Texas (UNT) | Texas | ≈ 21 100 – 23 200 USD / 9 mois | 100 | IELTS 6.0, rentrée de janvier ouverte jusqu'au 15/11 | 7 |
| Wichita State University | Kansas | 20 100 USD / 9 mois, bourse Global Select 5 500 USD | 105 (95-104 avec anglais intensif) | 3 rentrées, aéronautique | 6 |
| Minnesota State University, Mankato | Minnesota | 13 137 USD/an avec bourse automatique | 95 | IELTS 5.5 ; bourse pour tous les internationaux en licence | 6 |
| University of Nebraska Omaha (UNO) | Nebraska | 865 – 1 066 USD/crédit | 95 | frais 45 USD, admission conditionnelle | 6 |
| Arizona State University (ASU) | Arizona | 39 062 USD/an | 95 | admission conditionnelle 3 semestres ; **chère** | 4 |
| Kent State University | Ohio | 24 298 USD/an, bourses jusqu'à 68 000 USD / 4 ans | 100 | GPA 2.5, test-optional, admission conditionnelle | 6 |
| University of Toledo | Ohio | 24 160 – 24 760 USD/an, Rocket Award 8 000 USD/an | 105 | bourse automatique (GPA ≥ 3.0), janvier 2027 ouvert jusqu'au 1/11 | 6 |
| University of Central Missouri (UCM) | Missouri | 20 278 USD/an | 95 | IELTS 5.5, GPA 2.0, rentrées janvier / mai / août | 4 |

## Candidats étudiés et écartés (16/10/2026)

- **Georgia State University** : SAT ou ACT exigés pour l'automne 2026 et
  après (campus d'Atlanta), Duolingo non accepté en 1re année.
- **Florida International / University of South Florida** : test d'admission
  exigé par le système floridien ; non retenus faute de temps de vérification.
- **Morgan State University** : Duolingo 115 et pas d'admission conditionnelle.
- **Texas Southern University** : SAT 900 / ACT 17 exigés en 1re année, coût
  non publié.
- **Cleveland State University** : page des frais internationaux inaccessible
  (403) ; seuls les chiffres 2025-2026 trouvés.
- **Western Michigan University** : frais de candidature de 100 USD.
- **University of Memphis**, **University of Louisiana at Lafayette** : seuils
  d'anglais ou coûts non confirmés sur des pages à jour.
- **University of Regina** : multiplicateur international porté à 3,5 en
  2026-2027 (≈ 32 500 CAD/an).
- **Université de Saint-Boniface** : grille 2026-2027 publiée sous forme de
  « majoration » sans que le total international soit explicite — à compléter
  avec l'établissement (voir « À VALIDER »).
- **Carleton, Université d'Ottawa** : Ottawa existe déjà ; Carleton n'a pas
  été instruite (UQTR est ajoutée en seconde passe).

## Conversion en euros

`tuitionMinEur` et `applicationFeeEur` sont calculés à l'import depuis le
montant annuel du JSON, au **taux de référence BCE du 16/10/2026** (aussi pour
la seconde passe : le 17/10/2026 est un samedi, sans fixing BCE) :
1 € = 1,1253 USD ; 1 € = 1,5935 CAD (versionné dans le JSON,
`exchangeRates`). Ce sont des valeurs machine (score budgétaire, filtre) : les
fiches affichent la devise d'origine. Le montant annuel retenu est indiqué en
clair dans chaque libellé de frais (base de calcul comprise).

## Ce que l'app montre

- **Aucun badge partenaire** : `isPartner: false` ; le badge, la section
  « avantages » et « S'inscrire via KPB » restent réservés aux partenaires.
- La présentation de chaque établissement dit « KPB n'est pas partenaire de
  cet établissement : tu candidates directement auprès de lui ».
- Fiche formation : l'étape « Soumission à l'école partenaire » devient, pour
  un non-partenaire, « Envoi de ta candidature à l'établissement (KPB n'en est
  pas partenaire) » ; une rentrée sans prix propre (frais en USD / CAD) n'est
  plus suivie de « Sur demande ».
- Recherche : nom et ville (sigle ajouté au nom pour UQAM, UQAC, UdeM, MUN,
  UTA, UNT, ASU, UNO, UCM) ; filtres pays Canada (`can`) et États-Unis (`usa`).
  L'écran Universités s'ouvre sur « Partenaires » : il faut basculer sur
  « Tous » pour y voir ces établissements.

## Faits manquants (laissés vides)

Seconde passe :

- Frais de candidature : Conestoga, Sheridan, UQO, Polytechnique, HEC, UNB.
- Frais internationaux : Sheridan « Software Development and Network
  Engineering », UNB « Software Engineering » (libellé de l'établissement
  repris), M. Sc. de HEC (coût du programme complet seulement, pas de
  `tuitionMinEur`).
- Crédits des quatre baccalauréats de l'UQAT.
- Codes CIP / mention PGWP : Conestoga, Fanshawe (non affichés sur les fiches
  lues).
- Rentrées internationales de septembre 2027 de Seneca (non publiées) ; dates
  limites internationales chiffrées de l'UQO ; date limite du B.A.A. de HEC.
- Pages de programme de Polytechnique (site protégé) : intitulés et 120
  crédits pris dans le règlement des études 2026-2027.

Première passe :

- Montant des droits internationaux 2026-2027 : **UQAM**, **UQAC** (et la
  maîtrise en santé publique de l'UdeM, la maîtrise en informatique de
  Sherbrooke).
- Frais de candidature : Minnesota State Mankato, University of Toledo,
  Concordia, Memorial, UQAC, Moncton.
- Durée / crédits : BBA Finance et BSME de Houston, Financial Technology (ASU),
  toutes les formations de Toledo et de York, B.Eng. / B.Comm. / B.Sc. de
  Memorial (sauf B.Comm. coop), deux baccalauréats en informatique de l'UQAC,
  B.Ing. de Moncton.
- Coût annuel officiel international de UNO (tarifs par crédit seulement).
- Mois de début de l'automne quand la source ne le donne pas (écrit
  « Automne 2027 »).

## À VALIDER (propriétaire)

Seconde passe :

1. **Filtre par niveau de l'app** : « Diplôme collégial » et « Graduate
   certificate » tombent dans « Autre » (`lib/app/core/utils/study_level.dart`
   n'a pas été modifié dans ce chantier) ; faut-il un filtre « Collège » ?
2. **Garde de production** : si la première passe est déjà en production,
   l'application est refusée sans `KPB_ALLOW_PRODUCTION_SEED=1` (l'opération
   vps-ops ne sait pas le passer) — voir le runbook.
3. **Taille du catalogue** : +75 formations (172 au total) ; vérifier la marge
   sous la limite de 1 000 en production avant d'appliquer.
4. **Cégeps** : souhaites-tu une passe dédiée (sources directes des cégeps) ?
5. HEC Montréal et Polytechnique (≈ 32 000 – 39 000 CAD/an) restent chères
   pour ce public : les garder ?
6. Humber, Conestoga : dépôts et frais de candidature à reconfirmer sur la
   page de candidature au moment de la campagne.

Première passe :

1. Liste des pays visés par les restrictions de visas américains au moment de
   la mise en ligne, et message à tenir aux élèves de ces pays.
2. Ajouter une seconde passe pour atteindre 12 à 15 établissements par pays
   (pistes : Carleton, UQTR, Université de Saint-Boniface, University of
   Houston–Clear Lake, Southeast Missouri State).
3. McGill (54 000 – 71 687 CAD/an) et ASU (39 062 USD/an) sont « très
   regardées » mais peu accessibles financièrement : les garder ?
4. Taille du catalogue : la limite de 1 000 formations servies aux builds
   installées (`verify:catalog`) — vérifier le compte de production avant
   d'appliquer (+97 formations).
5. Wichita State : janvier 2027 n'est encore possible qu'en service
   « Standard » (150 USD, date limite 1/11/2026).
