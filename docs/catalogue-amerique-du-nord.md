# Catalogue Amérique du Nord — universités non partenaires (Canada, États-Unis)

Demande du propriétaire (16/10/2026) : ajouter au catalogue des universités
**non partenaires** (`isPartner: false`) du Canada et des États-Unis, choisies
pour les élèves d'Afrique francophone, en commençant par les établissements
anglophones. Sources consultées le **16/10/2026** sur les sites officiels ;
provenance fait par fait : `backend/scripts/data/amerique-du-nord-2027.sources.md`.
Import : `npm run import:north-america` (runbook :
`docs/runbook-catalogue-amerique-du-nord.md`).

**Livré : 20 établissements (10 au Canada, 10 aux États-Unis), 97 formations.**
L'objectif était de 12 à 15 par pays : les candidats écartés et la raison sont
listés plus bas, et la liste peut être complétée par une seconde passe.

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
- **Carleton, UQTR, Université d'Ottawa** : Ottawa existe déjà ; Carleton et
  UQTR n'ont pas été instruites dans cette passe.

## Conversion en euros

`tuitionMinEur` et `applicationFeeEur` sont calculés à l'import depuis le
montant annuel du JSON, au **taux de référence BCE du 16/10/2026** :
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
