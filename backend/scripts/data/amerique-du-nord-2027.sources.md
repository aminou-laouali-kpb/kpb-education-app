# Provenance — catalogue Amérique du Nord (`amerique-du-nord-2027.json`)

Relevés faits le **16/10/2026** (seconde passe Canada : **17/10/2026**) sur les sites officiels des établissements (et
d'IRCC, de la Maison-Blanche et de la BCE pour le contexte). Un fait = une URL.
Ce qui n'a pas été trouvé est laissé vide dans le JSON et listé en fin de
section (« Introuvable »). Sélection et critères : `docs/catalogue-amerique-du-nord.md`.

## Conventions

- **Taux de change** : BCE, taux de référence du 16/10/2026
  (<https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml>) :
  1 € = **1,1253 USD** = **1,5935 CAD**. `tuitionMinEur` = montant annuel du
  JSON (`tuitionAnnual`) ÷ taux, arrondi à l'euro ; `applicationFeeEur` idem.
  Les libellés affichés (`tuitionFr/En`) restent dans la devise d'origine.
- **Montant annuel** : celui que publie l'établissement quand il en donne un
  (« estimated cost », « coût d'une année ») ; sinon tarif par crédit × nombre
  de crédits indiqué dans le libellé (base écrite en clair : 18 crédits pour un
  master américain = 9 crédits × 2 semestres, la charge minimale F-1 retenue
  par Wichita State, Kent State et Minnesota State ; 24 crédits pour une
  licence à UNO, 30 crédits pour une année canadienne). Hors logement.
- **Rentrées** : mois publié quand la source le donne (« Fall (August) start »,
  « janvier 2027 Début du trimestre ») ; sinon `FALL 2027` (année et session,
  mois non publié). Le semestre de printemps américain et le trimestre d'hiver
  canadien commencent en janvier : `01/2027` n'est écrit que si la date limite
  internationale publiée pour janvier 2027 n'était pas passée le 16/10/2026.
- **Sigle dans le nom** (« … (UQAM) ») : la recherche de l'app ne lit que le
  nom et la ville (même choix que « American Business College (ABC) »).
- **TOEFL** : depuis le 21/01/2026, le TOEFL iBT est noté de 1 à 6 ; les
  établissements publient les deux échelles, recopiées telles quelles.

## États-Unis

### University of Houston (`na-us-houston`)
- Admission 1re année internationale (frais 90 USD, admission garantie top 10 % / GPA 3.5 / SAT 1250-ACT 26, essai + CV sinon, TOEFL 4.0, IELTS 6.5, Duolingo 105, dates Spring 2027 2/11/2026, Summer 2027 2/4/2027, Fall 2027 3/5/2027) : <https://uh.edu/undergraduate-admissions/apply/international/international-freshman/international-freshman-process/>
- Frais licence 2027 (tarif fixe 4 ans, non-résident, par semestre : 14 032,64 USD NSM ; 14 602,87 USD Business/Engineering) : <https://www.uh.edu/financial/undergraduate/tuition-fees/tuition/>
- Master Business non-résident 1 464,73 USD/crédit : <https://www.uh.edu/financial/graduate/tuition-fees/tuition/>
- Anglais master (TOEFL 79 / 4, IELTS 6.5, DET 105, PTE 53) : <https://www.uh.edu/graduate-school/admissions/international-applicants/english-proficiency/index.php>
- Computer Science B.S. (120 heures, fiche de suivi NSM) : <https://www.uh.edu/nsm/computer-science/about/>, <https://www.uh.edu/nsm/students/undergraduate/advising/forms/cosc-bs.pdf>
- Finance B.B.A. : <https://bauer.uh.edu/undergraduate/finance/> ; B.S.M.E. (ABET) : <https://www.me.uh.edu/undergraduate>
- MS Business Analytics (STEM) et MS Finance (STEM) — frais 80 USD intl, GMAT/GRE avec dispense possible, dates Fall 2027 intl 1/5/2027 : <https://bauer.uh.edu/ms-business-analytics/>, <https://bauer.uh.edu/msfinance/>
- Introuvable : durée/crédits du BBA Finance et du BSME ; frais de candidature master hors Bauer ; mois de début de l'automne.

### University of Texas at Arlington (`na-us-ut-arlington`)
- Admission licence (frais 75 USD, IELTS 6.5 / TOEFL 79 / DET 100 ou 105 en ingénierie, dates prioritaires intl 1/5, 1/10, 1/3) : <https://catalog.uta.edu/academicregulations/admissions/undergraduate/>
- Anglais master (IELTS 6.5 / TOEFL 79 / DET 100) : <https://catalog.uta.edu/academicregulations/admissions/graduate/>
- Coût 2026-27 non-résident (frais de scolarité et frais : 27 494 USD licence, 23 486 USD master) : <https://www.uta.edu/administration/fao/average-cost>
- Formations (catalogue, « Total Hours ») : CS BS 123, Finance BBA 120, ME BS 130, Public Health BS 120, MS Data Science 30, MS AI for Business 33 — URLs dans le JSON.
- Introuvable : frais de candidature master international.

### University of North Texas (`na-us-north-texas`)
- Anglais (TOEFL 79 avant le 21/01/2026 / 4, IELTS 6.0, PTE 53, DET 100) : <https://www.unt.edu/admissions/international/english-language-requirements.html>
- Dates et frais (licence 85 USD, master 75 USD ; 15/7 automne, 15/11 printemps) : <https://www.unt.edu/admissions/international/deadlines-fees.html>
- Coût 2026-27 non-résident, 9 mois (licence par collège ; master par collège) : <https://international.unt.edu/international-students/newly-admitted-international-students/estimated-undergraduate-26-27.html>, <https://international.unt.edu/international-students/newly-admitted-international-students/estimated-graduate-26-27.html>
- Formations (pages `unt.edu/academics/programs/…` : durée et crédits) — URLs dans le JSON.
- Introuvable : —

### Wichita State University (`na-us-wichita-state`)
- Coût intl licence 2026-27 (20 100 USD de frais sur 9 mois, bourse Global Select −5 500 USD si attribuée, frais uniques 200 + 150 USD) : <https://www.wichita.edu/admissions/international/undergraduate/TotalExpenses.php>
- Anglais (plein temps : TOEFL 72 / 4, IELTS 6.0, DET 105, PTE 49 ; 95-104 au DET = anglais intensif / mi-temps) : <https://www.wichita.edu/toefl>
- Frais et dates (75 / 150 / 250 USD ; Spring 2027 : 15/9 Basic, 1/11 Standard, 1/12 Premium ; été = juin, automne = mi-août) : <https://www.wichita.edu/admissions/international/service_levels.php>
- Tarifs par crédit automne 2026 (non-résident 645,42 licence / 903,59 master ; Global Select 408,73 / 551,89) : <https://www.wichita.edu/services/finance/ComprehensiveFeeSchedule.php> ; estimation master sur 9 crédits par semestre : <https://www.wichita.edu/admissions/graduate/tuition-international.php>
- Formations (catalogue, crédits) — URLs dans le JSON.
- Introuvable : —. **À VALIDER** : l'offre de janvier 2027 suppose le service Standard (150 USD), la date Basic étant passée.

### Minnesota State University, Mankato (`na-us-minnesota-state-mankato`)
- Admission 1re année (12 ans d'études, GPA 3.0 ; TOEFL 61 / 3.5, IELTS 5.5, DET 95, PTE 47) : <https://www.mnsu.edu/become-a-student/international-students/requirements/international-first-year-students/>
- Dates F-1 (août : 1/5 ; janvier : 1/9) : <https://www.mnsu.edu/become-a-student/international-students/requirements/international-undergraduate-application-process-calendar/>
- Coût licence (13 137 USD avec l'International Maverick Scholarship automatique, 21 013 USD sans) : <https://www.mnsu.edu/paying-for-college/cost-of-attendance/international-bachelor-student-cost-of-attendance/>
- Coût master 2026-27 (7 911 USD par semestre de 9 crédits ; preuve 36 980 USD) : <https://www.mnsu.edu/paying-for-college/cost-of-attendance/international-masters-doctoral-student-cost-of-attendance/>
- Formations (catalogue « Total Credits ») — URLs dans le JSON.
- Introuvable : année exacte du tableau licence (page non datée) ; frais de candidature (20 USD selon la liste de contrôle, non revérifié — laissé vide).

### University of Nebraska Omaha (`na-us-nebraska-omaha`)
- Anglais (général / ingénierie) : <https://www.unomaha.edu/undergraduate-admissions/international-students/english-proficiency.php>
- Frais 45 USD, admission conditionnelle via l'IEP : <https://catalog.unomaha.edu/aboutuno/undergraduate-admissions/international-applicants/>
- Tarifs 2026-27 par crédit (non-résident) : <https://www.unomaha.edu/accounting-services/cashiering-and-student-accounts/tuition-fees-and-refunds/tuition-rates.php>
- Formations (catalogue, crédits) — URLs dans le JSON.
- Introuvable : coût annuel officiel 2026-27 pour les internationaux (page « Costs » en 404) ; dates limites internationales ; mois de l'automne.

### Arizona State University (`na-us-arizona-state`)
- Admission 1re année (tableau des scores par collège, admission conditionnelle 3 semestres, frais 90 USD) : <https://admission.asu.edu/apply/international/first-year>
- Frais de scolarité de base 2026-27 (39 062 USD licence, 42 475 USD master) : <https://students.asu.edu/yourtuition>
- Formations : pages `degrees.asu.edu` (CS BS ABET 120, Data Science BS 120, Finance BS 120 minimum ; Financial Technology BS sans crédits relevés).
- Introuvable : crédits du BS Financial Technology ; dates limites internationales.

### Kent State University (`na-us-kent-state`)
- Admission 1re année (GPA 2.5, test-optional, frais 70 USD, dates 1/6 et 1/10) : <https://www.kent.edu/admissions/international-first-year-student-requirements>
- Anglais (TOEFL 71, IELTS 6.0, DET 100, PTE 48 ; admission conditionnelle) : <https://www.kent.edu/admissions/english-language-proficiency>
- Coût 2026-27 (24 298 USD licence, 21 169 USD master 9 crédits) : <https://www.kent.edu/admissions/international-tuition-and-fees>
- Bourses jusqu'à 68 000 USD sur 4 ans : <https://www.kent.edu/admissions/international-student-aid-tuition>
- Formations (catalogue « Minimum Total Credit Hours ») — URLs dans le JSON.
- Introuvable : —

### University of Toledo (`na-us-toledo`)
- Coût 2026-27 (24 160 – 24 760 USD) et International Rocket Award (8 000 USD/an, GPA ≥ 3.0, sur la majoration hors État) : <https://www.utoledo.edu/admission/international/tuition/>
- Anglais : <https://www.utoledo.edu/admission/international/englishlanguageproficiency/>
- Dates (1/11/2026 pour le 19/01/2027 ; 1/07/2027 pour le 23/08/2027) : <https://www.utoledo.edu/admission/international/>
- Ingénierie (ACT 22 / SAT maths 540 ou ALEKS 76) : <https://www.utoledo.edu/admission/international/how-to-apply.html>
- Formations : pages `utoledo.edu/programs/undergrad/…` — URLs dans le JSON.
- Introuvable : frais de candidature internationaux ; durée/crédits des formations (pages sans total ; ingénierie avec co-op) ; GPA minimal 1re année.

### University of Central Missouri (`na-us-central-missouri`)
- Admission (75 USD, TOEFL 61, IELTS 5.5, DET 95, Cambridge 162 ; dates hors USA 1/7, 1/11, 1/4 ; mai réservé à l'IEP, CS, Data Science, Cybersecurity) : <https://www.ucmo.edu/future-students/admissions/international-admissions/international-prospective-students/prospective-undergraduate-international/index.php>
- Tarifs automne 2026 – été 2027 (621,80 USD/crédit licence non-résident ; 520 USD masters CS/CIS ; 20 278 USD « Tuition & General Fees » hors État pour 30 crédits) : <https://www.ucmo.edu/future-students/tuition-and-costs/>
- Formations (pages programme, « Credit Hours ») — URLs dans le JSON.
- GPA 2.0 au secondaire (« Students must have a 2.0 high school GPA or above to be admissible ») : même page que l'admission.
- Introuvable : —

## Canada

### Université McGill (`na-ca-mcgill`)
- Droits 2026-27 des nouveaux étudiants internationaux de 1er cycle, par grade : <https://www.mcgill.ca/student-accounts/files/student-accounts/new_intl_ugrad_degree_students_admitted_2026-27_0.pdf>
- Anglais (TOEFL 90 / 4.5 ; 100 / 5.0 en gestion ; IELTS 6.5 ; DET 125, 130 en B.Com. ; CAEL 70) : <https://www.mcgill.ca/undergraduate-admissions/apply/english-proficiency>
- Frais 140,16 CAD (non remboursables ; candidatures dès le 1er octobre) : <https://www.mcgill.ca/undergraduate-admissions/apply>
- Formations : catalogue McGill (crédits de la majeure) — URLs dans le JSON.
- Introuvable : durée totale du B.Sc. pour un diplômé du secondaire hors Québec (année préparatoire éventuelle) ; rentrée d'hiver.

### Université Concordia (`na-ca-concordia`)
- Droits internationaux par crédit 2026-27 (1 160 / 1 400 / 1 285 CAD) : <https://www.concordia.ca/students/financial/tuition-fees/rates/undergrad.html>
- Anglais : <https://www.concordia.ca/admissions/undergraduate/requirements/english-language-proficiency.html>
- Formations (durée, « Start term Fall, Winter ») : pages `concordia.ca/academics/undergraduate/…`.
- Introuvable : frais de candidature.

### Université York (`na-ca-york`)
- Droits approximatifs 2026-27 : <https://futurestudents.yorku.ca/financing-your-degree/tuition-fees> ; Glendon 40 573,50 CAD : <https://www.yorku.ca/glendon/future-students/tuition-and-fees/>
- Anglais + YUELI : <https://futurestudents.yorku.ca/requirements/language-tests> ; frais 140 CAD : <https://futurestudents.yorku.ca/requirements/apply>
- PPECFSM (Glendon) : <https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/fmc-student-pilot/eligibility/participating-dlis.html>
- Formations (diplômes, campus, rentrées) : pages `futurestudents.yorku.ca/program/…`.
- Introuvable : durées et crédits des formations ; exigence de français de Glendon.

### Université Memorial de Terre-Neuve (`na-ca-memorial`)
- Droits 2026-27 (22 500 CAD pour 10 cours ; frais intl ~945 + 548 CAD d'assurance) : <https://www.mun.ca/undergrad/money-matters/>
- Anglais : <https://www.mun.ca/undergrad/admissions/i-want-to-apply/english-proficiency-tests/>
- Dates : <https://www.mun.ca/undergrad/admissions/admission-deadlines/>
- Formations : pages `mun.ca/undergrad/programs/…`.
- Introuvable : frais de candidature (120 CAD cité par une recherche, non revérifié — laissé vide) ; durées sauf B.Comm. coop (5 ans).

### Université Laval (`na-ca-laval`)
- Droits 1er cycle intl automne 2026 – hiver 2027 : <https://www.ulaval.ca/en/academics/tuition/international-students/undergraduate-programs/fall-2026-winter-2027>
- Frais d'analyse (101,49 / 104,53 CAD) et acompte 1 000 CAD : <https://www.ulaval.ca/sites/default/files/notre-universite/direction-gouv/Documents_officiels/Reglements/Reglement_frais_admission_inscription.pdf>
- Français (TCF tout public, DELF/TFI/TEF) : <https://www.ulaval.ca/en/admission/prepare-your-application/french-proficiency>
- Formations (crédits, durée, sessions d'admission) : pages `ulaval.ca/etudes/programmes/…`.

### Université de Montréal (`na-ca-montreal`)
- Droits intl (1 025,76 CAD/crédit, tableau « à compter de l'automne 2020 ») : <https://registraire.umontreal.ca/droits-de-scolarite/couts/> ; hausse de 3 % à l'automne 2026 : <https://budget.umontreal.ca/budget-2026-2027/revenus/droits-de-scolarite-et-frais-dadmission/>
- Bourse d'exemption UdeM 2026-27 : <https://admission.umontreal.ca/bourses-pour-etudiants-internationaux/>
- Frais d'admission (83,40 + 23,35 CAD/choix ; dépôt 1 000 CAD) : <https://secretariatgeneral.umontreal.ca/public/secretariatgeneral/documents/doc_officiels/reglements/enseignement/regl20_5-reglement-frais-admission-frais-changement-programme.pdf>
- Formations (crédits, trimestres, dates de demande) : pages `admission.umontreal.ca/programmes/…`.
- Introuvable : barème intl 2026-27 après hausse (non publié sur la page) ; frais de la maîtrise en santé publique (laissés vides).

### Université de Sherbrooke (`na-ca-sherbrooke`)
- Coûts intl automne 2026, bourses, frais de dossier 106 CAD : <https://www.usherbrooke.ca/admission/couts-et-aide-financiere/frais-scolarite/personnes-etudiantes-internationales>
- Exemption des droits majorés (ententes Québec) : <https://www.usherbrooke.ca/international/fr/etudier-a-udes/exemption-droits-scolarite-majores>
- Formations (crédits, trimestres, régimes) : pages `usherbrooke.ca/admission/programme/…`.
- Introuvable : frais de la maîtrise en informatique (laissés vides).

### Université du Québec à Montréal (`na-ca-uqam`)
- Frais d'admission 2026 (155 CAD intl) : <https://etudier.uqam.ca/frais-admission>
- Structure des droits intl (base + forfaitaire par crédit) : <https://comptesetudiants.uqam.ca/ressources/droits-de-scolarite-et-autres-frais/>
- Exemption (pays signataires d'une entente) : <https://bourses.uqam.ca/droits-de-scolarite-exemption-pour-les-etudiantes-et-etudiants-internationaux-bac/>
- Formations : `etudier.uqam.ca/programme?code=…`.
- Introuvable : **montant 2026-27 des droits intl** (non affiché ; dernier montant vu : procédure 2024-25, non utilisé) → `tuitionMinEur` nul.

### Université du Québec à Chicoutimi (`na-ca-uqac`)
- Droits fixés par le gouvernement, montant sur l'attestation, temps complet obligatoire : <https://international.uqac.ca/etudier-a-luqac/preparer-son-sejour/budget/>
- Fin du programme d'exemption « selon le programme d'études et la région » à compter de 2026-27 : <https://sae.uqac.ca/bourses-detudes/exemption-des-droits-de-scolarite-supplementaires-selon-le-programme-detudes-et-la-region/>
- Formations : `programmes.uqac.ca/<code>`.
- Introuvable : **montant des droits** ; frais de candidature ; crédits des deux baccalauréats en informatique.

### Université de Moncton (`na-ca-moncton`)
- Droits 2026-27 (15 761 CAD ; total 17 728,30 – 17 839,30 CAD) : <https://www.umoncton.ca/couts-annee-universitaire>
- PPECFSM (participant, Moncton / Edmundston / Shippagan) : page IRCC ci-dessus ; parcours de permis : <https://www.umoncton.ca/international/frais>
- Feuilles de route (4 ans × 30 crédits) : <https://www.umoncton.ca/feuilles-de-route>
- Introuvable : frais de candidature ; durée des B.Ing. (5 ans selon une recherche, non revérifié — laissé vide).

## Canada — seconde passe (17/10/2026)

Relevés du **17/10/2026** (`consultedAt` de chaque établissement ; même taux
BCE que la première passe : le 17/10/2026 est un samedi, sans fixing BCE, le
dernier taux publié est celui du 16/10/2026). Rentrées datées (`campusOfferings`)
seulement quand la page officielle affichait le statut « Open » / « Available »
pour les internationaux ce jour-là ; janvier et mai = `spring` (rentrée
décalée), août-septembre = `fall`. Générateur versionné :
`scripts/generate-north-america.py`.

### Humber Polytechnic (`na-ca-humber`)
- Frais de candidature 100 CAD (2 choix) : <https://humber.ca/international/admissions-financial-aid/how-to-apply/admissions-road-map>
- Anglais par diplôme (IELTS / TOEFL 2026 / Duolingo / PTE) et parcours EAP : <https://humber.ca/study-at-humber/apply/english-proficiency-requirements>
- Programme EAP (EA111, certificat, 2 semestres, 15 436,70 CAD pour 2 semestres 2026/2027, PGWP « N/A ») : <https://humber.ca/explore-programs/programs/general-arts-and-science-english-for-academic-purposes>
- Formations (code, CIP, PGWP, crédential, durée, frais « 2026/2027 fee for two semesters », disponibilité internationale) : `humber.ca/explore-programs/programs/<slug>` — computer-programming (CP221, 21 735,80), computer-engineering-technology (03501, 21 329,89), practical-nursing (07041, 20 867,55), artificial-intelligence-with-machine-learning (AI511, 20 992,84), data-analytics (DA511, 22 781,36), business-insights-and-analytics (BI511, 24 764,54), bachelor-of-computer-science-cybersecurity (CS411, 24 096,04).
- Introuvable : dépôt de confirmation (3 000 CAD cité par un tiers, non retenu).

### Seneca Polytechnic (`na-ca-seneca`)
- Frais de scolarité internationaux 2026/2027 par programme (année 1, scolarité seule) : <https://www.senecapolytechnic.ca/international/fees/tuition.html> (données : `seneapi-apims-pd.azure-api.net/…/2026_27_Tuition_Fees_International.json`)
- Frais de candidature 90 CAD, reversés après acceptation : <https://www.senecapolytechnic.ca/international/apply/how-to-apply.html>
- Anglais par niveau : <https://www.senecapolytechnic.ca/international/apply/how-to-apply/admission-requirements/english-requirements.html>
- ELI (8 niveaux de 7 semaines, 3 269,25 CAD par niveau ; acceptation conditionnelle, niveau 8 à 60 % pour un diplôme) : <https://www.senecapolytechnic.ca/international/eli/fees-expenses.html>, <https://www.senecapolytechnic.ca/international/eli/faq.html>, <https://senecapolytechnic.ca/international/eli/levels-test-scores.html>
- Formations (durée, crédential, CIP, disponibilité internationale) : `senecapolytechnic.ca/programs/fulltime/<CODE>.html` — CPP, CPA, ECT, AIG, CYT, BSA.
- Introuvable : rentrées internationales de septembre 2027 (non publiées le 17/10/2026).

### Conestoga College (`na-ca-conestoga`)
- Anglais par niveau et programme English Language Studies : <https://www.conestogac.on.ca/international/apply-to-conestoga/admission-requirements>
- English Language Studies (1 an, 2 trimestres, 11 330 CAD + frais annexes = 14 345,92 CAD, 2026-2027) : <https://www.conestogac.on.ca/fulltime/general-arts-and-science-english-language-studies>
- Dépôt de 2 500 CAD : <https://www.conestogac.on.ca/international/apply-to-conestoga/fees-and-payment>
- Formations (code, durée, frais 2026-2027 pour 2 trimestres, rentrées internationales) : `conestogac.on.ca/fulltime/<slug>`.
- Introuvable : frais de candidature (candidature via OCAS International) ; codes CIP / mention PGWP sur les fiches.

### Centennial College (`na-ca-centennial`)
- Frais de candidature 125 CAD, dépôt 2 000 CAD : <https://www.centennialcollege.ca/international-education/how-to-apply-to-centennial-college>
- Anglais et parcours (ELL, EAP, écoles partenaires) : <https://www.centennialcollege.ca/admissions/language-proficiency-information>
- ELL (jusqu'à 5 niveaux, 15 semaines, 4 397,50 CAD de scolarité par semestre de 15 semaines, barème dès l'automne 2025) : <https://www.centennialcollege.ca/programs-courses/full-time/english-language-learning>
- Formations (code, CIP, PGWP, frais « two semesters, beginning Fall 2026 », disponibilité internationale) : `centennialcollege.ca/programs-courses/full-time/<slug>`.
- Introuvable : exigence d'anglais précise de Practical Nursing (« additional requirements »).

### Fanshawe College (`na-ca-fanshawe`)
- Dépôt de candidature 100 CAD : <https://www.fanshawec.ca/international/applicants/international-tuition-fees>
- EAP (10 niveaux de 8 semaines, 3 411,36 CAD + 600,07 CAD par niveau, 2026-27 ; admission conditionnelle via les EAP partenaires) : <https://www.fanshawec.ca/international/applicants/eap>
- Formations (code, durée, disponibilité internationale, anglais) : `fanshawec.ca/programs/<slug>/next` ; frais par trimestre 2026/27 : `fanshawec.ca/node/<id>/international/fees/next` (CPA3 3990081, CYB1 275588, AIM1 6377096, DAA1 6432846).
- Introuvable : codes CIP / mention PGWP.

### Sheridan College (`na-ca-sheridan`)
- Anglais par niveau et EAP niveau 5 : <https://www.sheridancollege.ca/admissions/how-to-apply/admission-requirements/english-language>
- EAP (5 niveaux de 14 semaines, 16 836,44 CAD pour 2 semestres 2026-2027 ; niveau de placement indiqué dans la lettre d'offre) : <https://www.sheridancollege.ca/programs/english-for-academic-purposes>
- Formations (frais 2026-2027 des 2 premiers semestres, assurance et frais annexes compris ; disponibilité internationale ; « PGWP-aligned ») : `sheridancollege.ca/programs/<slug>`.
- Introuvable : frais de candidature ; frais internationaux de Computer Systems Technology – Software Development and Network Engineering.

### Université du Québec à Trois-Rivières (`na-ca-uqtr`)
- Répertoire international 2027-2028 (dates limites 1er avril / 1er août / 1er décembre, TIFEI, frais d'admission 54,87 CAD, 17 000 – 25 500 CAD/an) : <https://oraprdnt.uqtr.uquebec.ca/portail/docs/GSC932/O0007294965_2027_2028___R_pertoire_International.pdf>
- Calculette officielle (non canadien, automne 2026, 15 crédits : 1 558,80 + 11 345,25 CAD + frais = 13 650,15 à 13 685,15 CAD par trimestre selon le programme) : <https://oraprdnt.uqtr.uquebec.ca/portail/finw006>
- Effectifs (15 129 étudiants, 3 035 internationaux) : <https://oraprdnt.uqtr.uquebec.ca/portail/docs/GSC960/O0006996847_Factsheet_2026_2027_sans_BCI_FR.pdf>
- Formations : `oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=<code>` (7833, 6581, 7947, 7264).

### Université du Québec à Rimouski (`na-ca-uqar`)
- Frais internationaux 1er cycle (12 275,93 CAD par trimestre de 15 crédits, 24 551,86 CAD en 1re année, automne 2026) : <https://www.uqar.ca/programmes-formations-et-admission/frais-de-scolarite/>
- Admission internationale (TEF / TCF 460, Bright 3,5, frais d'admission 90,28 CAD) : <https://www.uqar.ca/programmes-formations-et-admission/admission/etudiant-es-etrangers/admission-pour-etudiants-internationaux/>
- Hiver 2027 clos, automne 2027 jusqu'au 1er mars 2027 : <https://www.uqar.ca/programmes-formations-et-admission/admission/programmes-ouverts-a-ladmission/>
- Formations : <https://www.uqar.ca/programmes-domaines-detudes/baccalaureat-en-informatique/>, `uqar.ca/etudes/etudier-a-l-uqar/programmes-d-etudes/<code>` (79n4, 79n7, 7464).

### Université du Québec en Outaouais (`na-ca-uqo`)
- Grille 1er cycle internationaux automne 2026 – été 2027 (103,92 + 720,64 CAD/crédit) : <https://uqo.ca/sites/default/files/2026-08/420934608droits-de-scolarite-et-frais-afferents-etudiants-internationaux-1er-cycle.pdf>, page : <https://uqo.ca/frais-de-scolarite/etudiants-internationaux>
- Formations (crédits, campus, trimestres, conditions) : `uqo.ca/programmes/<code>` (7833, 7643, 6784, 7127) et <https://uqo.ca/recherche-programmes>.
- Introuvable : frais d'admission ; dates limites internationales chiffrées.

### Université du Québec en Abitibi-Témiscamingue (`na-ca-uqat`)
- Frais internationaux 1er cycle 2026-2027 (103,92 + 703,76 CAD/crédit) : <https://www.uqat.ca/admission/frais-de-scolarite/internationaux/>
- Niveau de français, programmes offerts aux internationaux : <https://www.uqat.ca/futurs-etudiants-internationaux/>
- Frais d'admission 161,50 CAD (85 CAD crédités) : <https://www.uqat.ca/admission/deposez-votre-demande/> (relevé par la recherche, page « Déposez votre demande »)
- Bourses de l'École de génie (jusqu'à 25 % des frais majorés pour les internationaux) : pages des baccalauréats en génie.
- Introuvable : nombre de crédits des quatre baccalauréats.

### École de technologie supérieure (`na-ca-ets`)
- Coût 2026-2027 (1er cycle international : 1 067,26 + 103,92 = 1 171,18 CAD/crédit ; bourses de stage créditées au compte) : <https://www.etsmtl.ca/etudier-a-lets/bourses-finance-et-budget/cout-des-etudes> ; moyenne annuelle internationale 38 950 CAD (30 + 9 crédits de stage) : <https://www.etsmtl.ca/en/study-at-ets/scholarships-finances-and-budget/costs-of-studies>
- Dates limites internationales, frais de demande (141 CAD) : <https://www.etsmtl.ca/etudier-a-lets/admission>
- Formations (code, crédits, sessions) : `etsmtl.ca/programmes-formations/baccalaureat-<slug>`.

### Polytechnique Montréal (`na-ca-polytechnique`)
- Droits 2026-2027 (international : 1 127,57 CAD/crédit ; assurance 900 CAD/an) : <https://etudiant.polymtl.ca/etudes/droits-de-scolarite/cout-des-etudes/baccalaureat>
- Spécialités, 120 crédits, agrément, maîtrise du français (art. 14) : règlement des études du baccalauréat 2026-2027 <https://share.polymtl.ca/alfresco/service/api/node/content/workspace/SpacesStore/2aa44c99-8875-4d86-85a5-c6e46bcbbf3c?a=false&guest=true>
- Dates limites internationales (1er février / 1er juin) : <https://www.polymtl.ca/admission/baccalaureat/dates-limites-de-reception-des-demandes-dadmission> (lue via la recherche : le site `polymtl.ca` refuse les lecteurs automatiques).
- Introuvable : frais d'admission ; pages de programme (site protégé).

### HEC Montréal (`na-ca-hec`)
- Grille B.A.A. automne 2026 – hiver 2027 (tarif international 1 077,43 CAD/crédit) : <https://www.hec.ca/en/students/tuition-fees/pdf/tuition-fees-baa.pdf>
- B.A.A. (90 crédits, langues, spécialisations, agréments) : <https://www.hec.ca/programmes/baccalaureat/baa>
- M. Sc. (45 crédits, 34 500 – 39 000 CAD pour les internationaux, dates limites, français) : <https://www.hec.ca/programmes/maitrises/maitrise-science-donnees-analytique-affaires>, <https://www.hec.ca/programmes/maitrises/maitrise-intelligence-affaires>, <https://www.hec.ca/programmes/maitrises/maitrise-finance>, <https://www.hec.ca/en/programs/masters/master-data-science-and-business-analytics>
- Introuvable : frais d'admission ; date limite internationale du B.A.A.

### Université Bishop's (`na-ca-bishops`)
- Droits 2026-2027 (cohorte 2026 : 983,68 CAD/crédit, 29 510,43 CAD pour 30 crédits, 32 221,28 CAD avec frais) : <https://www.ubishops.ca/future-students/fees-and-funding/tuition-and-fees/>
- Frais de candidature 75 CAD, dates limites : <https://www.ubishops.ca/admissions/admission-process/>
- Anglais : <https://www.ubishops.ca/admissions/providing-proof-of-english-language-proficiency/> ; parcours écoles partenaires (admission conditionnelle) : <https://www.ubishops.ca/admissions/admission-requirements/english-language-school-pathway-students/>
- Formations : `ubishops.ca/program/<slug>/`.

### Université du Nouveau-Brunswick (`na-ca-unb`)
- Frais Fredericton 2026-2027 (internationaux) : `unb.ca/finance/_assets/documents/financial-services/fredericton-tuition/undergrad/fred_ug_{compsci,eng,nurs}_ft.pdf`
- Anglais, admission conditionnelle : <https://www.unb.ca/international/admission/english.html> ; PAEP : <https://www.unb.ca/elp/english/paep.html>
- Formations (durée, heures-crédits) : calendrier `unb.ca/academics/calendar/undergraduate/current/frederictonprograms/…`.
- Introuvable : frais de candidature ; frais du BScSwE (aucune grille propre publiée) ; rentrée de janvier.

### Collège communautaire du Nouveau-Brunswick (`na-ca-ccnb`)
- Droits 2026-2027 (10 258 CAD/an, 301 CAD/semaine ; frais d'admission 100 CAD ; confirmation 500 + 4 644 CAD) : <https://ccnb.ca/frais-et-financement/droits-de-scolarite/>
- Programmes ouverts au PPECFSM pour l'automne 2027, avertissement sur les agences : <https://ccnb.ca/admission-et-inscription/programme-pilote-ppecfsm/>
- Formations (durée, campus, conditions internationales) : `ccnb.ca/programmes/<slug>/`.

### Écartés en seconde passe (17/10/2026)
- **George Brown Polytechnic** : site officiel inaccessible aux lecteurs (HTTP 403).
- **Algonquin College** : statuts et frais affichés seulement par icônes et calculateur.
- **Niagara College** : pages de programmes introuvables (404) à cette date.
- **INRS** : uniquement des cycles supérieurs de recherche, hors cible.
- **Cégeps** (DEC / AEC) : pas de grille internationale 2026-2027 publiée par cégep (Matane : règlement sans montants) ; **LaSalle College Montréal** est déjà au catalogue unique (`lasalle_college_montreal`).

## Contexte (doc, pas dans les fiches)

- Restrictions de visas américains en vigueur au 1/1/2026 (proclamation du 16/12/2025) : <https://www.whitehouse.gov/presidential-actions/2025/12/restricting-and-limiting-the-entry-of-foreign-nationals-to-protect-the-security-of-the-united-states/>
- PPECFSM, liste des établissements participants (page datée du 16/10/2026) : <https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/fmc-student-pilot/eligibility/participating-dlis.html>


## Troisième passe (12/11/2026) — ajouts, prix complétés, contre-vérification

Relevés du 12/11/2026 sur les sites officiels, puis contre-vérifiés indépendamment le même jour (chaque montant, seuil et date relu à la source ; corrections notées « Vérification indépendante »). Les blocs ci-dessous sont les relevés bruts : un fait = une URL.

### ca-quebec-a

#### Sources — ca-quebec-a (consulté le 2026-11-12)

Format : fait → URL → citation courte.

## Transversal : exemptions des droits supplémentaires (gouvernement du Québec)

- Entente France / Belgique francophone (tarifs préférentiels) → https://www.quebec.ca/education/etudier-quebec/aide-financiere-etudiants-internationaux/exemption-droits-scolarite-ententes → « les étudiantes et étudiants français inscrits à temps plein [en 1er cycle] peuvent obtenir le tarif applicable aux Canadiennes et Canadiens non-résidents du Québec » ; « 2e ou 3e cycle … bénéficient du tarif applicable aux Québécoises et Québécois ».
- Ententes avec « une quarantaine de pays » : même page → « des exemptions des droits de scolarité supplémentaires peuvent être accordées à un nombre défini d'étudiantes et d'étudiants » ; « Votre candidature doit être recommandée par la ou le responsable de la gestion des exemptions de votre pays » ; durée : baccalauréat 3 ans (90 crédits) ou 4 ans (120 crédits), maîtrise 2 ans ; « inscrite ou inscrit en continu et à temps plein durant les trimestres d'automne et d'hiver ».
- Pays africains signataires et nombre d'exemptions (tous cycles / 1er / 2e / 3e) → https://cdn-contenu.quebec.ca/cdn-contenu/adm/min/education/publications-adm/ES/Etudier-quebec/Pays_organisation_internationale_entente.pdf → Algérie 83 ; Bénin 10 (5/5/0) ; Burkina Faso 27 ; Burundi 1 ; Cameroun 16 (8/8/0) ; Congo (Brazzaville) 6 ; Côte d'Ivoire 43 (21/19/3) ; Djibouti 3 ; Égypte 20 ; Gabon 27 ; Guinée 15 ; Madagascar 17 ; Mali 16 (8/8/0) ; Maroc 90 ; Maurice 5 ; Mauritanie 6 ; Niger 14 (7/7/0) ; RDC 12 ; Rwanda 7 ; Sénégal 52 (25/25/2) ; Tchad 4 ; Togo 8 (4/4/0) ; Tunisie 65 ; AUF 20 (organisation internationale).
- Liste des responsables de la gestion des exemptions par pays (janvier 2026) → https://cdn-contenu.quebec.ca/cdn-contenu/adm/min/education/publications-adm/ES/Etudier-quebec/Liste-responsables-gestion-exemptions.pdf (lien présent sur la page quebec.ca ci-dessus ; contenu non relu en détail).
- Critères France / Belgique côté UQAM → https://services-medias.uqam.ca/media/uploads/sites/30/2025/07/07152451/criteres_francais_belges_vf.pdf → « admissibles à l'exemption du montant forfaitaire … 1er cycle : régime des droits applicable aux étudiants canadiens non résidents du Québec ; cycles supérieurs : régime applicable aux résidents du Québec ».

## na-ca-uqam

- Grille 1er cycle internationaux 2026-2027 → https://services-medias.uqam.ca/media/uploads/sites/30/2026/06/15123825/2026-2027_EI_C1.pdf → « Droits de scolarité de base 103,92 $ ; supplémentaires 849,58 $ ; sous-total 953,50 $ par crédit » ; « Montant estimé des frais facturés pour un trimestre à temps complet de 15 crédits : 15 362,65 $ » (FIO 332,21 $ ; associations 60 $, CANO 12,94 $, assurances collectives 655 $). 30 crédits/an = 2 × 15 362,65 = 30 725,30 CAD.
- Grille 2e cycle professionnel classe A 2026-2027 → https://services-medias.uqam.ca/media/uploads/sites/30/2026/06/15123826/2026-2027_EI_C2A.pdf → « Montant estimé des frais facturés pour un trimestre à temps complet de 15 crédits : 13 837,90 $ » ; 2 trimestres = 27 675,80 CAD.
- Grille 2e cycle recherche classe B (45 crédits) 2026-2027 → https://services-medias.uqam.ca/media/uploads/sites/30/2026/06/15123828/2026-2027_EI_C2B.pdf → « Trimestres 1 à 4 : 9 019,57 $ (11,25 crédits) » ; « Trimestres 5 à 6 : 874,90 $ ». Total 4 × 9 019,57 + 2 × 874,90 = 37 828,08 CAD sur 2 ans, soit 18 914 CAD/an en moyenne.
- Page UQAM des droits et frais (référence aux grilles) → https://comptesetudiants.uqam.ca/ressources/droits-de-scolarite-et-autres-frais/ → « Les étudiantes et étudiants internationaux paient les droits de scolarité de base auxquels s'ajoute un montant supplémentaire par montant forfaitaire qui varie selon le cycle d'études et le programme choisi » ; guide de facturation : https://services-medias.uqam.ca/media/uploads/sites/30/2026/06/30161804/V2_2026_06_30_Guide-de-facturation-etudiante_2026-2027.pdf (non relu).
- Maîtrise en informatique (3792) = classe B → https://etudier.uqam.ca/programme?code=3792 → « ce programme est rangé dans la classe B » ; « Mémoire (vingt-sept crédits) » ; « Temps complet : 2 ans ».
- Maîtrise en gestion de projet (2072) = classe A → https://etudier.uqam.ca/programme?code=2072 → « ce programme est rangé dans la classe A » ; « contingent annuel de 60 étudiants » ; « baccalauréat … moyenne d'au moins 3,2 sur 4,3 … expérience professionnelle pertinente d'au moins 2 années » ; documents : texte de motivation, CV, attestation d'emploi.
- Baccalauréat en sciences comptables (6782) → https://etudier.uqam.ca/programme?code=6782 → « 6782 … B.A.A. 90 » ; « Programme non contingenté » ; « Base études hors Québec : … au moins treize années de scolarité … moyenne … 12 sur 20 » ; « 12 années … 24 crédits de mise à niveau » ; exigence d'anglais intermédiaire II ; cours d'appoint MAT1002.
- Baccalauréat en administration, concentration finance (7111) → https://etudier.uqam.ca/programme?code=7111 → « Concentration finance … B.A.A. 90 » ; mêmes conditions hors Québec ; « un refus à une de ces concentrations s'appliquera à toutes les autres ».
- Baccalauréat général en communication (6628) → https://etudier.uqam.ca/programme?code=6628 → « 90 crédits » ; « moyenne inférieure à 12 doivent réussir le cours PHI1000 ou PHI2028 ».
- Dates limites internationaux 1er cycle (mise à jour 4 novembre 2026) → https://www.apps.uqam.ca/Application/AdmissionEnLigne/Traitements/DatesLimites/AfficherDatesLimites.aspx?adm_web_code_centre=Q&adm_web_code_cycle=1C → « Automne : 1er mars (certains programmes ont une date limite plus hâtive) ; Hiver : 1er août (les programmes de droit et psychologie ne sont pas offerts aux candidats internationaux) » ; « les candidats internationaux doivent choisir uniquement des programmes offerts à temps complet ».
- Dates limites cycles supérieurs (mise à jour 10 novembre 2026) → https://www.apps.uqam.ca/Application/AdmissionEnLigne/Traitements/DatesLimites/AfficherDatesLimites.aspx?adm_web_code_cycle=CS → même note internationale ; « Gestion de projet – Profil professionnel … 1er oct. … 1er avril ».
- Tests de français reconnus → https://etudier.uqam.ca/tests-francais-reconnus → « doit démontrer sa connaissance du français en joignant à sa demande d'admission le résultat obtenu à un test de français reconnu » ; TEF, TCF, DELF, DALF, test de l'École de langues UQAM, Bright Language.
- Frais d'admission 155 CAD (déjà dans le catalogue) → https://etudier.uqam.ca/frais-admission.
- Budget de vie type (non utilisé dans le JSON) → https://etudier.uqam.ca/etudiants-internationaux/cout.

## na-ca-montreal (UdeM)

- Droits 2026-2027 internationaux → https://registraire.umontreal.ca/droits-de-scolarite/couts/ → « 1er cycle … Par crédit 1 025,76 $ ; 15 crédits 15 386,40 $ ; 30 crédits 30 772,80 $ » ; « 2e cycle … Maîtrise (stage ou travail dirigé), microprogramme, DESS : plein temps 11 668,77 $ par trimestre » ; « Maîtrise avec mémoire : 10 674,30 $ par trimestre ».
- Baccalauréat en droit → https://admission.umontreal.ca/programmes/baccalaureat-en-droit/ → « 101 crédits », « Temps plein - 3 ans », « Capacité d'accueil limitée », « Vous étudiez (ou avez étudié) à l'université ou hors Québec : 1er février 2027 », « Satisfaire à l'exigence de français … 15 février 2027 », « au minimum C1 en compréhension orale et en compréhension écrite », « L'excellence du dossier constitue le seul critère de sélection », acompte « 1 000 CAD ».
- Baccalauréat en communication et politique → https://admission.umontreal.ca/programmes/baccalaureat-en-communication-et-politique/ → rentrées janvier 2027 / août 2027 / janvier 2028 ; « 90 crédits » ; janvier 2027 : « 1er décembre 2026 » (français « 15 décembre 2026 ») ; août 2027 : « 1er février 2027 » (français « 15 février 2027 ») ; « au minimum B2 en compréhension orale et en compréhension écrite ».
- Maîtrise en sciences économiques → https://admission.umontreal.ca/programmes/maitrise-en-sciences-economiques/ → « 45 crédits », « août 2027 », « Du 1er août 2026 au 1er février 2027 », « Deux lettres de recommandation », « La scolarité minimale du programme est de trois trimestres à temps plein », deux modalités (avec mémoire / sans mémoire avec rapport de recherche).
- Maîtrise en relations industrielles → https://admission.umontreal.ca/programmes/maitrise-en-relations-industrielles/ → août 2027 (« 1er février 2027 » ; français « 15 mai 2027 ») et janvier 2028 (dépôt « à compter du 1er février 2027 » ; français « du 1er février 2027 au 15 décembre 2027 ») ; « Moyenne de C1 en compréhension orale et écrite » ; « Niveau B2 en expression écrite » ; « Curriculum vitæ ».
- Maîtrise en santé publique (déjà au catalogue) → https://admission.umontreal.ca/programmes/maitrise-en-sante-publique/ → « 45 crédits » ; modalités avec mémoire / avec stage.
- Accès au 1er cycle avec le bac, au 2e cycle avec une licence (page Sénégal) → https://admission.umontreal.ca/admission/vous-etes/etudiant-international/senegal/ → « Avec votre baccalauréat sénégalais, vous pouvez directement rejoindre … un programme de 1er cycle. Avec une licence, vous pouvez faire une demande d'admission pour des programmes de 2e cycle ». Pages analogues : .../cameroun/, .../cote-divoire/ (non relues).
- Frais de dossier 83,40 + 23,35 CAD (déjà dans le catalogue) : voir institution ; acompte de 1 000 CAD : texte « un acompte de 1 000 CAD est requis après avoir accepté l'offre d'admission » sur les fiches programme.

## na-ca-sherbrooke (UdeS)

- Frais 2026-2027 internationaux → https://www.usherbrooke.ca/admission/couts-et-aide-financiere/frais-scolarite/personnes-etudiantes-internationales → 1er cycle droit/gestion/génie/informatique : « sans stage 15 080 $ ; avec stage 16 070 $ » par trimestre de 15 crédits ; stage 550 $ ; 2e cycle cours (droit, gestion, génie, informatique…) « sans régime coopératif 13 505 $ » ; recherche « 11 145 $ » ; « Frais d'ouverture et de traitement du dossier 106 $ » (page mise à jour août 2026).
- Génie civil (213) → https://www.usherbrooke.ca/admission/programme-pdf/213/baccalaureat-en-genie-civil/ → « 120 crédits », « Coopératif », « Automne », « Ouvert aux personnes étudiantes internationales avec possibilité de stages rémunérés », « admissibles conditionnellement à la réussite du certificat préparatoire … », « niveau C1 (résultat égal ou supérieur à 500 sur 699) aux quatre compétences » (mise à jour 29 septembre 2026).
- Génie électrique (214) → https://www.usherbrooke.ca/admission/programme-pdf/214/baccalaureat-en-genie-electrique/ → mêmes conditions (120 crédits, automne, coopératif).
- B.A.A. (203) → https://www.usherbrooke.ca/admission/programme-pdf/203/baccalaureat-en-administration-des-affaires/ → « 90 crédits », « Automne, Hiver », « Admission d'hiver au Campus principal de Sherbrooke seulement », « au moins un cours de mathématiques de niveau collégial … 201 ou 360 », niveau 4 d'anglais recommandé pour les cheminements bilingues ; aucune exigence de test de français indiquée.
- Maîtrise en administration (601) → https://www.usherbrooke.ca/admission/programme-pdf/601/maitrise-en-administration/ → « 45 crédits », « Temps complet », « Automne », « moyenne cumulative d'au moins 2,7 … 4,3 », « moyenne cumulative d'au moins 3,0 », niveau C1 (500/699) aux quatre compétences, « essai 6 crédits ».
- Équivalences et années de scolarité → https://www.usherbrooke.ca/admission/da/valider-admissibilite/equivalences-internationales → « vous devez cumuler 13 années de scolarité » ; « Tous les programmes de baccalauréat en génie : … admise conditionnellement à la réussite du certificat préparatoire » ; « Pour être admis en maîtrise … 16 années de scolarité ».
- Dates limites 1er cycle → https://www.usherbrooke.ca/admission/da/planifier-demande/dates-limites/1er-cycle → « Candidat international 15 janvier 1er juin » ; tableau spécifique « Baccalauréat en administration des affaires 1er juillet 1er décembre ».
- Dates limites 2e cycle → https://www.usherbrooke.ca/admission/da/planifier-demande/dates-limites/2e-3e-cycles/personnes-candidates-internationales → « Maîtrise en administration 1er mars ».
- Exemption (même page de frais) → « L'exemption … peut être accordée à un nombre défini d'étudiants » ; page dédiée https://www.usherbrooke.ca/international/fr/etudier-a-udes/exemption-droits-scolarite-majores (non relue).
- Maîtrise en informatique (déjà au catalogue) → https://www.usherbrooke.ca/admission/programme/654/maitrise-en-informatique/ → « 45 crédits » ; cheminements recherche (avec mémoire) et cours (lecture via WebFetch, résumé).

## na-ca-laval (ULaval)

- Droits 1er cycle 2026-2027 → https://www.ulaval.ca/en/academics/tuition/international-students/undergraduate-programs/fall-2026-winter-2027 → « Subtotal 15 credits $14,116.48 » ; assurance « $900 per year ».
- Droits maîtrise de type cours → https://www.ulaval.ca/en/academics/tuition/international-students/course-based-masters-programs/fall-2026-winter-2027 → même tableau (« 15 credits … $14,116.48 »).
- Dates limites internationaux → https://www.ulaval.ca/admission/deposez-votre-demande-dadmission/dates-limites-de-depot → « Candidates et candidats de l'international : Automne … Date limite: 1er février ; Hiver … Date limite: 1er juillet ; Été … 1er décembre ».
- Droit contingenté 2027-2028 → https://www.ulaval.ca/admission/preparez-votre-dossier/programmes-contingentes/programmes-contingentes-en-2027-2028 → « Droit … automne: 240, hiver: 90 … international automne: 1er février, hiver: 1er juillet ».
- Baccalauréat en droit → https://www.ulaval.ca/etudes/programmes/baccalaureat-en-droit → « 99 crédits », « 330 places », « TCF-TP … 400/699 … 14/20 », résultats « 1er mars … 1er novembre », « curriculum vitae et … lettre de motivation ».
- Baccalauréat en génie civil → https://www.ulaval.ca/etudes/programmes/baccalaureat-en-genie-civil → « 120 crédits », « Diplôme d'études préuniversitaires totalisant 13 années ou … 12 années et une année d'études supérieures », « cheminement préparatoire en sciences », TCF tout public.
- B.A.A. expertise comptable → https://www.ulaval.ca/etudes/programmes/baccalaureat-en-administration-des-affaires-expertise-comptable → « 90 crédits », « Automne, Hiver, Été », « 13 années … 12 années ET une année d'études supérieures ou Baccalauréat … français … belge … BI », « moyenne minimale … formation générale et … mathématiques ».
- M.B.A. finance → https://www.ulaval.ca/etudes/programmes/maitrise-en-administration-des-affaires-finance → « 45 crédits », « 2 ans », « moyenne … égale ou supérieure à 3,22 sur 4,33 », « entre 2,8 et 3,21 », « TCF … 600/699 … 14/20 », « CV », « lettre de présentation », « relevé de notes de l'examen du baccalauréat de l'enseignement secondaire ».
- Frais de dossier 101,49 / 104,53 CAD (déjà au catalogue).
- Exemptions (page de frais Laval) → liens vers https://www.quebec.ca/en/education/study-quebec/financial-assistance-international-students/exemptions-tuition-fees-under-international-agreements.

## Vérification indépendante (2026-11-12) — corrections et ajouts

- UdeM maîtrise en sciences économiques, seuil de français : introuvable sur la fiche → https://francais.umontreal.ca/etudier-en-francais/exigence-a-ladmission/ → « Si vous souhaitez étudier dans un des programmes des cycles supérieurs et que l'information relative à l'exigence de français n'apparaît pas dans la description du programme, communiquez avec la faculté, l'école ou le département du programme choisi ou consultez votre avis d'admission ».
- UdeS B.A.A., dates limites : la règle « Si aucune mention pour les candidatures internationales n'est présente, les dates courantes s'appliquent » (https://www.usherbrooke.ca/admission/da/planifier-demande/dates-limites/1er-cycle) tranche le doute : internationaux = 15 janvier (automne) / 1er juin (hiver), le tableau École de gestion (1er juillet / 1er décembre) ne mentionne pas l'international.
- UdeS B.A.A., test de français : tableau des niveaux par programme → https://www.usherbrooke.ca/admission/da/exigences-linguistiques/exigences-relatives-a-la-langue-francaise-pour-admission → génie = C1 ; « Administration des affaires (B.A.A.), gestion et comptabilité ne figurent pas dans le tableau » ; fiche 203 (mise à jour 2 octobre 2026) sans exigence de français.
- UdeS frais (relus) → https://www.usherbrooke.ca/admission/couts-et-aide-financiere/frais-scolarite/personnes-etudiantes-internationales → « avec stage … 16 070 $ » ; « sans stage 15 080 $ » ; « 2e cycle cours sans stage 13 505 $ » ; « Frais d'ouverture et de traitement du dossier d'admission : 106 $ CA ».
- Laval frais de dossier → https://www.ulaval.ca/admission/deposez-votre-demande-dadmission/frais-douverture-et-danalyse-de-dossier → « candidat n'ayant jamais étudié à l'Université Laval : 104,53 $ » (ancien 101,49 $ retiré des bullets).
- Laval dates internationales droit → https://www.ulaval.ca/admission/preparez-votre-dossier/programmes-contingentes/programmes-contingentes-en-2027-2028 → colonne « Candidates et candidats de l'international » : Droit « automne: 1er février ; hiver: 1er juillet ».
- Laval tarif → https://www.ulaval.ca/en/academics/tuition/international-students/undergraduate-programs/fall-2026-winter-2027 (et .../course-based-masters-programs/...) → « Subtotal 15 credits $14,116.48 ».
- Rentrées Laval : « FALL 2027 » / « SPRING 2028 » (mois non publié).
- UQAM tests de français : https://etudier.uqam.ca/tests-francais-reconnus → tableau : « 1000 et plus (C1-C2) ; 510 et plus ; DALF C1-C2 → admise directement » ; niveau 5 « TCF 800 à 849 ; TEF 400 à 427 ; DELF B2 50 à 62 → quatre cours de mise à niveau » ; niveau 6 « Inférieur à 800 / 400 ; DELF A1-A2-B1 → refusée ». TCF et TEF : compréhension écrite + orale.
- UQAM dates limites (grille par programme, 4 nov. 2026) → https://www.apps.uqam.ca/Application/AdmissionEnLigne/Traitements/DatesLimites/AfficherDatesLimites.aspx?adm_web_code_centre=Q&adm_web_code_cycle=1C → 6782 / 7111 / 6628 : AUTOMNE 2027 temps complet « 1er mai » ; note internationale « Automne : 1er mars (certains programmes ont une date limite plus hâtive) ; Hiver : 1er août ». Maîtrise 2072 : « 1er avril » (grille CS, 10 nov. 2026). Le texte donne désormais la grille ET la date internationale générale.
- Grilles de droits UQAM relues (EI_C1 : 15 362,65 $ ; EI_C2A : 13 837,90 $ ; EI_C2B : 9 019,57 $ trimestres 1-4 ; 874,90 $ trimestres 5-6) : OK.
- UdeM tarifs relus (https://registraire.umontreal.ca/droits-de-scolarite/couts/) : 1 025,76 $/crédit, 30 crédits 30 772,80 $ ; maîtrise stage 11 668,77 $/trimestre ; mémoire 10 674,30 $ : OK.

### ca-quebec-b

#### Sources — ca-quebec-b (relevé du 2026-11-12)

Format : fait → URL → citation courte copiée de la page.

## na-ca-uqac — Université du Québec à Chicoutimi

### Grille / calcul des droits 2026-2027 (non canadien, campus Chicoutimi)
- Droits de scolarité, 1er cycle, 15 crédits temps complet, automne 2026 → https://apps.uqac.ca/calculcout/index.html (simulateur officiel ; résultat sur https://apps.uqac.ca/calculcout/afficher_frais.html après envoi du formulaire : non canadien, admis à l'automne 2025 ou après, trimestre automne 2026, premier cycle sur le campus, 15 crédits, temps complet) → « Droits de scolarité 12307.20 $ » ; « TOTAL 13123.25 $ ».
- Même calcul pour l'hiver 2027 (trimestre 20271) → même page → « Droits de scolarité 12307.20 $ » ; « TOTAL 13123.25 $ ».
- Linéarité par crédit (3 crédits) → même simulateur → « Droits de scolarité 2461.44 $ » (= 820,48 $/crédit ; 15 crédits = 12 307,20 $).
- 2e cycle, maîtrise de type A (sans mémoire, classe A) = même tarif → même simulateur → « Études de deuxième cycle sur le campus / Type de maîtrise : Sans mémoire … Droits de scolarité 12307.20 $ ».
- Calcul retenu : 2 trimestres × 15 crédits = 30 crédits = 24 614,40 CAD → 24 614 CAD/an (droits seuls). Avec frais afférents et assurances : 2 × 13 123,25 = 26 246,50 → 26 247 CAD/an. Le total inclut « Ass. maladie - étud. étrangers 300.00 $ » et « Frais assurance étudiants 130.22 $ » par trimestre.
- Principe général → https://www.uqac.ca/srf/droits-de-scolarite-et-autres-frais/ → « Le Gouvernement du Québec fixe le coût des droits de scolarité que chaque université doit faire payer aux étudiantes et étudiants pour suivre des cours. La catégorie d'étudiants détermine le coût à payer pour chaque crédit inscrit. »
- Temps complet obligatoire (automne + hiver) → https://international.uqac.ca/etudier-a-luqac/preparer-son-sejour/budget/ → « Les étudiants internationaux admis à l'UQAC devront obligatoirement être inscrits à temps complet aux trimestres d'automne et d'hiver. »
- Exemples budgétaires 2025 arrondis (pour comparaison) → même page budget → « Pour le premier cycle … Frais de scolarité 25 000 CAD » (tarifs de l'automne 2025, arrondis ; non retenu).
- Classe du programme (A = professionnel) → https://programmes.uqac.ca/2139 → « ce programme est rangé dans la classe A » ; https://programmes.uqac.ca/3249 → « programme est rangé dans la classe A ».

### Frais de dossier
- 100 CAD → https://www.uqac.ca/bdi-docs/incoming/guide-admission.pdf → « Prévoyez une carte de crédit pour le paiement des frais d'étude du dossier (100$) ».
- Dépôt de 900 CAD (demandes avant le 1er septembre 2026) → https://www.uqac.ca/registraire/faq-admission/ → « Qu'advient-il du dépôt de 900 $ exigé pour une demande d'admission soumise avant le 1er septembre 2026? » (voir DOUTES).

### Dates limites internationales
- Automne 2027 → https://www.uqac.ca/registraire/wp-content/uploads/2026/11/20273.pdf → « Période des admissions … Personnes étudiantes internationales 14 septembre 2026 au 1er avril 2027 » ; « Toutes les personnes étudiantes – Programmes contingentés Date limite au 1er mars 2027 ».
- Hiver 2027 (dernier calendrier hiver publié) → https://www.uqac.ca/registraire/wp-content/uploads/2026/10/20271.pdf → « Personnes étudiantes internationales 1er février 2026 au 1er août 2026 ».
- Ancienne mention (1er mars automne / 1er août hiver) → https://www.uqac.ca/registraire/admission/determiner-son-admissibilite/ → « les dates indiquées dans le calendrier universitaire ( 1er mars pour le trimestre d'automne et 1er août pour le trimestre d'hiver ) sont des dates limites » (voir DOUTES).
- Plateforme : portail d'admission en ligne → https://www.uqac.ca/registraire/faq-admission/ → « Pour déposer votre demande d'admission, nous vous invitons à consulter notre site Internet pour créer votre profil en ligne sur notre portail. » (lien du portail : https://admission.uqac.ca/Admission/).

### Français
- https://www.uqac.ca/registraire/admission/tests-de-francais/ → « Toute personne candidate à un programme identifié, dont la langue maternelle n'est pas le français, est tenu de se soumettre à un test de compétence en français reconnu par l'UQAC… » ; « le test doit avoir été passé dans les vingt-quatre (24) mois précédant la date du début du trimestre » ; « Les personnes candidates internationales régulières seront inscrites automatiquement au cours de français identifié par l'UQAC à leur premier trimestre d'inscription. » ; « Le cours de français identifié par l'UQAC est de 3 crédits hors programme ».

### Nouvelles formations
- Baccalauréat en administration (7764) → https://programmes.uqac.ca/7764 → « Être titulaire d'un diplôme approprié obtenu à l'extérieur du Québec après au moins treize années de scolarité ou l'équivalent, avec une moyenne minimale de 12 sur 20 » ; « Réussir les 9 crédits obligatoires de la structure d'accueil » ; « Ce programme comprend quatre-vingt-dix (90) » ; « Le programme complet incluant la structure d'accueil aura une durée de 7 trimestres » ; « Ce programme n'est pas contingenté » ; tableau « Saguenay (campus principal) Automne et hiver Temps complet Présence … Oui » ; concentrations « finance, marketing, gestion des ressources humaines … management et commerce international ».
- Baccalauréat en génie civil (7480) → https://programmes.uqac.ca/7480 → « Être titulaire d'un baccalauréat général ou d'un baccalauréat technologique dans les domaines de la mathématique, de la chimie, de la physique ou des sciences de la Terre » ; « Elle aura deux (2) trimestres pour réaliser cette formation » ; « Ce programme comprend cent vingt (120) crédits » ; « les étudiants peuvent effectuer jusqu'à cinq stages rémunérés » ; « Ce programme n'est pas contingenté » ; Saguenay, Automne et hiver, Temps complet, « Oui ».
- Baccalauréat en sciences comptables (7766) → https://programmes.uqac.ca/7766 → même base hors-Québec (13 années, 12/20, 9 crédits d'accueil) ; « Ce programme comprend quatre-vingt-dix (90) crédits » ; « Admis sur la base d'études hors Québec Automne : durée 8 trimestres / 4 ans » ; « permettant notamment d'accéder au titre de comptable professionnel agréé (CPA) » ; Saguenay, Automne et hiver, Temps complet, « Oui ».
- Maîtrise en gestion de projet (3249) → https://programmes.uqac.ca/3249 → « Être titulaire d'un diplôme approprié obtenu hors Québec après au moins seize (16) années de scolarité » ; « Avoir une moyenne cumulative minimale de 13/20 ou l'équivalent. Une personne candidate ayant une moyenne cumulative entre de 11/20 et 13 /20 pourrait faire l'objet d'une recommandation d'admission » ; dossier « Un curriculum vitæ détaillé … Une lettre de motivation en français … Trois (3) rapports confidentiels ou lettres de recommandation » ; « Il est fortement recommandé de posséder une compréhension suffisante de l'anglais écrit » ; « Ce programme comprend quarante-cinq (45) crédits » ; Saguenay, Automne, Temps complet, « Oui ».

## na-ca-uqtr — Université du Québec à Trois-Rivières

### Frais (calculette officielle, étudiant non canadien, campus, automne 2026, 15 crédits)
- Calculette → https://oraprdnt.uqtr.uquebec.ca/portail/finw006a (formulaire https://www.uqtr.ca/couts-et-financement) ; valeur reproduisant celle du fichier existant : 7833 → « Total 13 650,15$ » (= 27 300 CAD/an, déjà au catalogue).
- 7766 sciences comptables, 1er cycle → « Frais de scolarité 1 558,80$ ; Forf. internationaux (cycle 1) 11 345,25$ … Association sc. comp., adm 40,00$ … Total 13 675,15$ » → ×2 = 27 350,30 → 27 350 CAD/an.
- 7944 génie électrique, 1er cycle → « Association génie 45,00$ ; ITR - Activités parascolaires 5,00$ … Total 13 685,15$ » → ×2 = 27 370,30 → 27 370 CAD/an.
- 3457 MBA, 2e cycle → « Forf. internationaux (cycle 2) 11 345,25$ … Ass. maîtrise gestion projet 5,00$ … Total 13 639,85$ » → ×2 = 27 279,70 → 27 280 CAD/an.
- 3249 maîtrise gestion de projet, 2e cycle → « Total 13 634,85$ » → ×2 = 27 269,70 → 27 270 CAD/an.
- La même calculette renvoie les mêmes montants pour « Automne 2027 » (7833 : 13 650,15$) ; on garde l'automne 2026 comme le reste du fichier.

### Frais de dossier, dépôt, test, dates limites (Répertoire international 2027-2028, à jour au 7 juillet 2026)
- https://oraprdnt.uqtr.uquebec.ca/portail/docs/GSC932/O0007294965_2027_2028___R_pertoire_International.pdf → « Frais d'admission 54,87 $ » ; « Frais de dépôt à l'admission (avance sur vos droits de scolarité) 1 000 $ » ; « Test institutionnel de français pour étudiants internationaux (TIFEI) 150 $ » ; « Dates limites … Automne : 1er avril ; Hiver : 1er août ; Été : 1er décembre » ; « Au 1er cycle, aucune arrivée tardive n'est possible » ; liste des programmes offerts aux internationaux (baccalauréat en sciences comptables, génie électrique, MBA, gestion de projet).
- Plateforme : « Compte admission … Créez un compte admission pour accéder au formulaire en ligne » (même PDF).
- « Les étudiants internationaux doivent obligatoirement être à temps complet afin de faire les démarches de formalités d'immigration. » → pages de programme ci-dessous.

### Nouvelles formations
- Bac sciences comptables (7766) → https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=7766 → « 90 crédits » ; « Non contingenté » ; « Être titulaire d'un diplôme d'études préuniversitaires totalisant 13 années ou d'un diplôme d'études préuniversitaires totalisant 12 années et une année d'études universitaire réussi avec une moyenne supérieure ou égale à 13/20 » ; « entre 12/20 et 13/20 pourraient être admis … cours d'appoint » ; « entre 11/20 et 12/20 sont invitées à déposer une demande … certificat en comptabilité générale » ; « égale ou supérieure à 10/20 mais inférieure à 11/20 … devront suivre une année de mise à niveau » ; « Le cheminement 03 – immersion professionnelle n'est pas offert aux personnes candidates de l'international » ; « répond aux exigences de formation … Ordre des CPA » (« Le programme de baccalauréat en sciences comptables vise l'acquisition des compétences requises par l'Ordre des comptables professionnels agréés (CPA) »).
- Bac génie électrique (7944) → https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=7944 → « 120 crédits » ; « Non contingenté » ; « Admission à l'automne et l'hiver » ; « Être détenteur d'un diplôme d'études préuniversitaires général en sciences totalisant 13 années » ; « tous les candidats ayant 12 ans de scolarité devront compléter une année de mise à niveau » ; « Pour être admis, les candidats hors Québec devront avoir une moyenne d'au moins 12/20 ou l'équivalent » ; « seront étudiés par la direction de programme » (10/20 à 12/20) ; « Accrédité par le Bureau d'agrément d'Ingénieurs Canada ce qui te permet d'être admis directement à l'Ordre des Ingénieurs du Québec » ; « l'étudiant doit avoir réussi le cours GEI1099 – Stage de génie électrique ».
- MBA (3457) → https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=3457 → « 45 crédits » ; « Non contingenté » ; « Admission à l'automne et l'hiver » ; « Être détenteur d'un grade de premier cycle universitaire (baccalauréat nord-américain, licence selon le système LMD, un diplôme de master 1 ou avoir l'équivalent d'au moins Bacc+4) … moyenne cumulative équivalente à 12/20 » ; « expérience pertinente … d'une durée minimale de trois années » ; « Les candidats issus de pays dont le français n'est pas une des langues officielles sont tenus de se soumettre au test de français TCF … moins de six mois » ; « connaissance fonctionnelle de l'anglais écrit ».
- Maîtrise en gestion de projet (3249) → https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=3249 → « 45 crédits » ; « Admission à l'automne et l'hiver » ; « avec une moyenne d'au moins 13/20 ou son équivalent » ; « moyenne de 12/20 à 13/20 verra son dossier étudié par le comité de programme » ; « expérience pertinente d'au moins sept ans en gestion de projet ou disposant d'au moins 10 ans d'expérience de gestion » ; « doit fournir une attestation de réussite du Test de connaissance du français (TCF), lors de sa demande d'admission ».

## na-ca-uqo — Université du Québec en Outaouais

### Frais 2026-2027
- 1er cycle, international → https://uqo.ca/sites/default/files/2026-08/420934608droits-de-scolarite-et-frais-afferents-etudiants-internationaux-1er-cycle.pdf → « Droits de scolarité 103,92 $ / crédit » ; « Forfaitaires 720,64 $ / crédit » (= 824,56 $/crédit × 30 = 24 736,80 → 24 737 CAD/an, hors frais afférents ; identique au catalogue existant).
- 2e cycle profil professionnel (classe A), international → https://uqo.ca/sites/default/files/2026-08/2097121650droits-de-scolarite-et-frais-afferents-etudiants-internationaux-2e-cycle-classe.pdf → « PROGRAMMES D'ÉTUDES DE 2e CYCLE – PROFIL PROFESSIONNEL (CLASSE A) … Droits de scolarité 103,92 $ / crédit … Forfaitaires 720,64 $ / crédit » → 24 737 CAD/an.
- Page de synthèse → https://uqo.ca/frais-de-scolarite/etudiants-internationaux → « FRAIS PAR PROGRAMME D'ÉTUDES 2026-2027 » ; « Deuxième cycle, profil professionnel (classe A) ».
- Classe A des deux maîtrises → https://etudier.uqo.ca/programmes/1524 et https://etudier.uqo.ca/programmes/3249 → « Deuxième cycle - Classe A - Programme professionnel ».

### Frais de dossier, dates limites, français
- 120 CAD → https://uqo.ca/etudiants/admission/etapes → « Pour les personnes ayant un statut de visiteur avec permis de séjour (personnes étudiantes internationales) : 120,00$. »
- Dates limites automne 2027 (internationaux) → https://uqo.ca/etudiants/automne-premier-cycle-gatineau → « 7543 Baccalauréat en génie électrique (T.C.) 5 août 2027 | 1er mars 2027 » ; « 7766 Baccalauréat en sciences comptables (T.C./T.P.) 5 août 2027 | 1er mars 2027 » ; et https://uqo.ca/etudiants/automne-cycles-superieurs-gatineau → « 1524 Maîtrise en administration des affaires (MBA) … 15 mai 2027 | 1er mars 2027 » ; « 3249 Maîtrise en gestion de projet (T.C./T.P.) 15 mai 2027 | 1er mars 2027 ».
- Hiver 2027 fermé aux internationaux → https://uqo.ca/etudiants/hiver-premier-cycle-gatineau (7766 « FERMÉ ») et https://uqo.ca/etudiants/hiver-cycles-superieurs-gatineau (1524, 3249 « FERMÉ »).
- Plateforme : https://admission.uqo.ca/ (lien « Formulaire d'admission en ligne » des fiches https://etudier.uqo.ca/programmes/<code>).
- Français 1er cycle → https://uqo.ca/etudiants/etudier-l-uqo/politique-sur-la-qualite-du-francais → « Si vous ne répondez pas aux critères d'exemption, vous devrez passer le test de français SEL-B en ligne, offert en collaboration avec la TELUQ, durant le premier trimestre de vos études. » ; en cas d'échec « vous devrez alors vous inscrire aux 4 cours prescrits ».
- Français 2e cycle → https://etudier.uqo.ca/programmes/1524 et /3249 → « La personne candidate qui n'entre pas dans ces catégories doit fournir la preuve de la réussite de l'un des tests de français suivants avec un niveau minimal de B2 … DALF … DELF … TCF … TEF ».

### Nouvelles formations
- Bac génie électrique (7543) → https://etudier.uqo.ca/programmes/7543 → « Baccalauréat en génie électrique - 7543 » ; « 120 crédits » ; tableau d'admission : Gatineau, Temps complet, automne seulement ; « Être titulaire d'un diplôme d'études collégiales (DEC) en sciences de la nature … ou l'équivalent, et avoir complété les cours de niveau collégial suivants » (calcul, algèbre, physique, chimie) ; « Toute personne candidate qui ne détient pas l'équivalent d'une 13e année de scolarité au Québec … pourra se voir imposer … des cours de Voie d'accès … cours d'appoint … GEN1953 Systèmes numériques et INF1563 Programmation I … deux (2) trimestres ».
- Bac sciences comptables (7766) → https://etudier.uqo.ca/programmes/7766 → « 90 crédits » ; Gatineau temps complet : automne et hiver ; « Être titulaire d'un diplôme d'études collégiales (DEC) ou l'équivalent et avoir réussi au moins un cours de mathématiques du collégial » ; « MQT1203 Éléments de mathématiques pour la gestion » ; « Avoir réussi un minimum de 15 crédits universitaires, avec une moyenne générale de 2,2 sur 4,3 » ; « Le programme répond aux exigences de formation académique de premier cycle de l'Ordre des CPA du Québec ».
- MBA (1524) → https://etudier.uqo.ca/programmes/1524 → « 45 crédits » ; « Être titulaire d'un baccalauréat en administration ou dans un domaine des sciences de la gestion … d'une université non canadienne obtenu avec une moyenne cumulative d'au moins 3,2 sur 4,3 » ; « Posséder une expérience professionnelle d'au moins trois ans en gestion » (autre domaine) ; « Le candidat devra soumettre un curriculum vitæ accompagné d'un questionnaire dument rempli. Le candidat devra également être disponible pour une entrevue » ; Gatineau, Temps complet et partiel, automne et hiver.
- Maîtrise en gestion de projet (3249) → https://etudier.uqo.ca/programmes/3249 → « 45 crédits » ; « Être titulaire d'un baccalauréat ou l'équivalent obtenu avec une moyenne cumulative d'au moins 3,2 (sur 4,3) » ; « mais supérieure à 2,8 et possédant les connaissances requises et une expérience jugée pertinente de plusieurs années » ; « une expérience pertinente d'au moins sept ans en gestion de projet ou disposant d'au moins 10 ans d'expérience en gestion » ; « Posséder une compréhension suffisante de l'anglais ».

## na-ca-hec — HEC Montréal (3 prix manquants)
- Tarif international projet supervisé, 45 crédits → https://www.hec.ca/etudiants/frais-de-scolarite/pdf/frais-de-scolarite-mm-llm-ps.pdf (« Frais de scolarité – Automne 2026 et hiver 2027 / Maîtrises ès sciences en gestion (M. Sc.) – Projet supervisé ») → « Tarif international 795,34 $ » par crédit ; « 15 crédits : 11 930,10 $ » ; « 45 crédits : 35 790,30 $ » (droits) ; « Total Tarif international … 45 crédits 38 949,46 $ » ; « Ces montants n'incluent pas les frais de l'assurance maladie pour les personnes de l'international (obligatoire) ».
- Calcul retenu : 30 crédits × 795,34 = 23 860,20 → 23 860 CAD/an (droits, hors frais institutionnels ; avec frais institutionnels : 2 × 12 873,21 = 25 746,42).
- Estimation du programme complet de 45 crédits (personnes de l'international) → https://www.hec.ca/programmes/maitrises/maitrise-intelligence-affaires (même bloc sur /maitrise-finance et /maitrise-science-donnees-analytique-affaires) → « Personnes de l'international … Coût du programme complet de 45 crédits à temps plein Mémoire : 34 500 $ Projet supervisé : 39 000 $ » ; « Les frais sont calculés par trimestre au cheminement avec mémoire et par crédit au cheminement avec projet supervisé. »
- Cheminement avec mémoire (tarif international) → https://www.hec.ca/etudiants/frais-de-scolarite/pdf/frais-de-scolarite-msc-memoire.pdf et https://www.hec.ca/en/students/tuition-fees/pdf/tuition-fees-msc-thesis.pdf → « International rate $8,005.73 » par trimestre (4 premiers trimestres), total $8,617.24 ; « Full-time 3 semesters $24,017.18 ».
- Les trois spécialisations offrent mémoire ou projet supervisé → pages /maitrise-finance, /maitrise-intelligence-affaires, /maitrise-science-donnees-analytique-affaires → « Cette spécialisation propose le cheminement avec mémoire ou le cheminement avec projet supervisé pour un total de 45 crédits, sur une durée de 16 à 24 mois. »

## na-ca-sheridan — Computer Systems Technology – Software Development and Network Engineering
- Frais 2026-2027 par semestre (international) → https://myotr.sheridancollege.ca/fees-academic-year.html (« Estimated Full-time Academic Fees for the 2026-2027 Academic Year ») → PCSTS « Year 1, Semester 1 Full Time Tuition: $8768.4 Total Program Fees: $25 Total Ancillary Fees: $839.3 » ; « Year 1, Semester 2 Full Time Tuition: $8768.4 Total Program Fees: $25 Total Ancillary Fees: $694.3 » → 9 632,70 + 9 487,70 = 19 120,40 CAD hors assurance santé.
- Assurance santé : le champ « Program fees » de la fiche https://www.sheridancollege.ca/programs/computer-systems-technology-software-development-and-network-engineering est vide. Pour calibrer l'écart « fiche programme − myOTR » : PCOMP Computer Programmer myOTR 19 120,40 vs https://www.sheridancollege.ca/programs/computer-programming « Fees for International students $19,700.40 » (écart 580,00) ; PCPEN myOTR 19 783,95 vs https://www.sheridancollege.ca/programs/computer-engineering-technician « $20,363.95 » (écart 580,00) ; PPNSG myOTR 25 212,42 vs 25 792 au catalogue (écart 580). PCSTS a les mêmes frais que PCOMP → 19 120,40 + 580 = 19 700,40 → 19 700 CAD (voir DOUTES : valeur déduite, la fiche ne la publie pas).
- Mention de la fiche → « Fees shown here are estimates only. Fees are in Canadian dollars and include tuition, health insurance and ancillary charges. The fees displayed are for the first two (2) academic semesters of study at Sheridan » (page computer-programming).

## na-ca-unb — Bachelor of Science in Software Engineering
- https://www.unb.ca/finance/_assets/documents/financial-services/fredericton-tuition/undergrad/fred_ug_soft_geo_ft.pdf → « UNB Fredericton 2026-2027 Tuition & Fees (effective September 1, 2026) … Undergraduate Full-Time Degree Program: Software or Geological Engineering » ; International « Tuition 12,452.75 12,452.75 24,905.50 » ; « Total for International Students: 13,688.00 13,068.50 26,756.50 ».
- Rattachement du BScSwE à cette grille → https://www.unb.ca/finance/financial-services/undergraduate/fredericton.html (liste « Engineering - Software or Geological ») et titre du PDF Engineering « Engineering (excluding Software or Geological Engineering) » (https://www.unb.ca/finance/_assets/documents/financial-services/fredericton-tuition/undergrad/fred_ug_eng_ft.pdf).
- Calcul : 24 905,50 → 24 906 CAD/an ; 26 756,50 → 26 757 CAD/an avec frais et assurances.

## Vérification indépendante (2026-11-12) — corrections et ajouts

- Sheridan PCSTS : fiche programme https://www.sheridancollege.ca/programs/computer-systems-technology-software-development-and-network-engineering → bloc « Program fees » sans montant (« Fees shown here are estimates only… include tuition, health insurance and ancillary charges ») ; myOTR https://myotr.sheridancollege.ca/fees-academic-year.html → PCSTS année 1 : 8 768,4 + 25 + 839,3 (sem. 1) et 8 768,4 + 25 + 694,3 (sem. 2) = 19 120,40 CAD. Montant retenu : 19 120 CAD (assurance santé non incluse) ; l'ancien 19 700 (déduit) est supprimé.
- UQAC frais : simulateur relu (POST https://apps.uqac.ca/calculcout/index.html, non canadien, automne 2026, campus, 15 crédits, temps complet) → 1er cycle et maîtrise sans mémoire « Droits de scolarité 12307.20 $ ; TOTAL 13123.25 $ » ; maîtrise avec mémoire « Droits de scolarité 8005.73 $ ; TOTAL 8599.48 $ » par trimestre (ajouté au libellé d'établissement).
- UQAC test de français 1er cycle → https://www.uqac.ca/registraire/wp-content/uploads/2024/12/Grilles_correspondances_Tests_francais_Dec24.pdf → « Niveaux seuils exigés pour l'admission au 1er cycle … TCF 400 / 400 ; TEF 400 / 400 ; … DELF-B2 Diplôme ; B2 » ; « Valide 2 ans ». Aucun seuil publié pour le 2e cycle.
- UQAC calendrier automne 2027 relu → https://www.uqac.ca/registraire/wp-content/uploads/2026/11/20273.pdf → « Personnes étudiantes internationales 14 septembre 2026 au 1er avril 2027 » ; « Programmes contingentés … 1er mars 2027 » : OK. Hiver 2028 : pas encore publié (20281.pdf introuvable : 404 sur uploads/2026/11, 2026/12, 2027/01, 2027/06, 2027/09).
- UQAC pages programmes relues (programmes.uqac.ca/7764, 7480, 7766, 3249, 2139) : 13 années / 12 sur 20, 16 années / 13 sur 20 pour la maîtrise, « n'est pas contingenté », « Ouvert aux candidatures de l'international », 2139 classe A : OK.
- UQAC frais de dossier 100 CAD relus → https://www.uqac.ca/bdi-docs/incoming/guide-admission.pdf → « frais d'étude du dossier (100$) » : OK.
- UQTR répertoire 2027-2028 relu → https://oraprdnt.uqtr.uquebec.ca/portail/docs/GSC932/O0007294965_2027_2028___R_pertoire_International.pdf → « Frais d'admission 54,87 $ » ; « Automne : 1er avril » « Hiver : 1er août » « Été : 1 décembre » ; « 1 000 $ » (dépôt) : OK. Calculette UQTR (page dynamique, non rejouable en HTTP simple) : montants non revérifiés, conservés.
- UQO relus : PDF 1er cycle « 103,92 $ / crédit ; Forfaitaires 720,64 $ / crédit » ; PDF 2e cycle classe A idem ; https://uqo.ca/etudiants/admission/etapes « 120,00$ » ; dates https://uqo.ca/etudiants/automne-premier-cycle-gatineau (7543, 7766 « 1 er mars 2027 » international) et .../automne-cycles-superieurs-gatineau (1524, 3249 « 1 er mars 2027 ») : OK.
- HEC relus → https://www.hec.ca/etudiants/frais-de-scolarite/pdf/frais-de-scolarite-mm-llm-ps.pdf « Tarif international 795,34 $ » ; .../frais-de-scolarite-msc-memoire.pdf « 8 005,73 $ » : OK.
- UNB relu → https://www.unb.ca/finance/_assets/documents/financial-services/fredericton-tuition/undergrad/fred_ug_soft_geo_ft.pdf → « International Tuition 24,905.50 » ; « Total for International Students 26,756.50 » : OK.

### ca-franco

#### Sources — établissements francophones hors Québec (relevé du 2026-11-12)

Format : fait → URL → citation courte. Seules des sources officielles (établissements, IRCC).

## IRCC (commun à tous)
- Liste officielle des EED participants au PPECFSM (tous les 5 établissements y figurent) → https://www.canada.ca/fr/immigration-refugies-citoyennete/services/etudier-canada/permis-etudes/programme-pilote-etudiants-cfsm/eed-participants.html → « Université de Saint-Boniface | Manitoba | A | September 2026 » ; « Université Saint-Anne | Nova Scotia | E | January 2026 » ; « Université de l'Ontario français | Ontario | A | September 2025 » ; « Collège Boréal | Ontario | B | September 2025 » ; « Collège La Cité | Ontario | A | May 2025 ». Également listés mais non repris : Université d'Ottawa, York (Glendon), Université de Moncton, CCNB (déjà au catalogue) ; Université Laurentienne (B), Université de Hearst (E), Université Saint Paul (A), Université de Regina (B), Université de l'Alberta (A), Collège de l'Île (E), Collège Éducacentre (A), Collège Mathieu (E).
- Critères d'admissibilité PPECFSM → https://www.canada.ca/fr/immigration-refugies-citoyennete/services/etudier-canada/permis-etudes/programme-pilote-etudiants-cfsm/admissibilite.html → « se situent au moins au niveau 5 de l'échelle des Niveaux de compétence linguistique canadiens (NCLC) » ; programme « d'une durée de 2 ans ou plus », « à temps plein », « plus de 50 % des cours sont offerts en français » ; pays admissibles : liste de 33 pays dont Bénin, Burkina Faso, Cameroun, Côte d'Ivoire, Gabon, Guinée, Mali, Maroc, Niger, RCA, RDC, Rép. du Congo, Sénégal, Tchad, Togo.

## Université de Saint-Boniface (na-ca-saint-boniface)
- Frais collégiaux internationaux 2026-2027 → https://ustboniface.ca/sites/default/files/2026-08/Frais-ETP-ESIES.pdf → « Majoration - Étudiantes et étudiants internationaux … Technologies de l'information 1ère année 14 890,00 $ ; 2e année 15 365,00 $ » ; « Administration des affaires 1ère année 13 160,00 $ ; 2e année 14 385,00 $ » ; « Baccalauréat en sciences infirmières 1ère année 14 850,00 $ ; 2e 14 410,00 $ ; 3e 14 850,00 $ ; 4e 13 965,00 $ » ; « Ils comprennent tous les frais » ; « Demande d'admission … international : 130,00 $ ».
- Frais universitaires internationaux 2026-2027 → https://ustboniface.ca/sites/default/files/2026-08/Frais-USB.pdf → « Majoration … Arts et Traduction 30 crédits 14 345,00 $ ; Sciences 15 415,00 $ ; Administration des affaires 16 455,00 $ ; Éducation 14 830,00 $ ; Travail social 15 850,00 $ » ; « Ils comprennent tous les frais sauf les frais de laboratoire ».
- Frais de dossier → https://ustboniface.ca/demande-admission → « 130 $ CAD pour la population internationale et demandeuse d'asile » ; portail MonUSB.
- Dates limites internationales → https://ustboniface.ca/dates-limites → « Population internationale … Diplôme en technologies de l'information / administration des affaires / Baccalauréat en sciences infirmières : 1er mars (demande) ; 15 mai (documents) » ; « Baccalauréat en éducation … 1er février ; 1er mars ».
- Test de français → https://ustboniface.ca/tests-de-francais-normalises → « DALF C1 ; DELF B2 ; TCF B2 ; TEF B2 » ; « Un test est requis même si tu proviens d'un pays francophone » ; exemptions (bac de l'Académie française, BI Français A ≥ 4).
- Conditions générales → https://ustboniface.ca/exigences-admission → « Tu as obtenu l'équivalent du diplôme d'études secondaires du Manitoba » ; anglais requis pour sciences infirmières, travail social, etc.
- TI → https://ustboniface.ca/programmes/diplome-en-technologies-de-linformation → « Durée 2 ans ; Nombre de crédits 90 » ; admission internationale 1er mars / 15 mai.
- Administration des affaires (diplôme) → https://ustboniface.ca/programmes/diplome-en-administration-des-affaires → « 2 ans ; 84 crédits » ; la page affiche 12 060 $ / 13 180 $ (voir DOUTES).
- BSI → https://ustboniface.ca/programmes/baccalaureat-en-sciences-infirmieres → « 4 ans ; 120 » ; « moyenne minimale équivalent à 70 % » ; « IELTS Academic … 7,0 … 6,5 ».
- Éducation → https://ustboniface.ca/programmes/baccalaureat-en-education → « Évaluation WES ICAP Course-by-Course obligatoire » ; « moyenne cumulative d'au moins 2,50 » ; « critères modifiés en novembre 2026 … automne 2027 ».
- Permis / LAP → https://ustboniface.ca/permis-etude → « dépôt de 3 000 $ CAD … déduit de ta première session » ; mention PPECFSM « les documents requis sont différents ».
- Baccalauréat en administration des affaires non ouvert en admission directe aux internationaux → https://ustboniface.ca/programmes/baccalaureat-en-administration-des-affaires → « Aucune admission directe. Admission uniquement par la voie Université 1. » (donc non retenu).

## Université de l'Ontario français (na-ca-uof)
- Frais 2026-2027 → https://uofinternational.ca/je-veux-etudier-a-luof/droits-de-scolarite-et-droits-accessoires-obligatoires → « B.A.A. … international : coût par crédit 574 $ ; coût annuel (30 crédits) 17 220 $ » ; « Santé mentale / Travail social … 433,33 $ par crédit ; 12 999,90 $ » ; « Communication et médias numériques … 433,33 $ ; 12 999,99 $ » ; droits accessoires « Total … 610,00 $ » par an ; AEUOF « 1 $ par crédit » ; « RAMU … 12 mois 948 $ » ; « dépôt de 2 000 $ … lettre d'attestation provinciale ».
- Conditions d'admission 2026-2027 et tests → https://uofinternational.ca/je-veux-etudier-a-luof/conditions-dadmission → « DELF B2 (70 % minimum) ; TFI 700 ; TEF 600 ; TCF 450 » ; bac français « 12/20 » ; IB « 26 points » ; B.A.A. « MCV4U ; MHF4U ».
- Dates et frais de dossier → https://uofinternational.ca/je-veux-etudier-a-luof/comment-deposer-une-demande-dadmission → « Automne 2026 : 30 mai, date finale … candidates et candidats internationaux » ; « 156 $ par demande … OUAC ».
- Calendrier → https://uofinternational.ca/je-veux-etudier-a-luof/calendrier-des-dates-importantes → « 30 mai 2026 Date limite pour soumettre une demande d'admission ».
- PPECFSM → https://uofinternational.ca/je-veux-etudier-a-luof/programme-pilote → « Les frais de demande d'admission sont de 156 $ CA + 70 $ CA de frais supplémentaires » ; « payer la totalité des frais de scolarité de la 1re année » ; « TEF Canada … TCF Canada » ; « groupe A 20 635 $ CA ».
- B.A.A. 4 ans / 120 crédits → https://uof.ca/programmes/baccalaureats-specialises/baccalaureat-en-administration-des-affaires → « Le B.A.A. est un programme de 120 crédits réalisable en 4 ans ».
- Travail social stages → https://uofinternational.ca/programmes/baccalaureat-en-travail-social → « deux stages supervisés de 700 heures ».
- Communication, passerelle La Cité → https://uofinternational.ca/programmes/baccalaureat-specialise-en-communications-et-medias-numeriques → « entente de passerelle (2+2) avec le Collège La Cité ».
- Éducation fermée aux internationaux → https://uof.ca/admission-et-droits-de-scolarite/droits-de-scolarite-et-frais-afferents → « Les étudiantes internationales et étudiants internationaux ne sont pas admissibles au programme d'études en Éducation ».

## Université Sainte-Anne (na-ca-sainte-anne)
- Frais 2026-2027 → https://www.usainteanne.ca/etudiants/questions-financieres/frais-detudes → « Droits de scolarité universitaires (étudiantes et étudiants internationaux) … Baccalauréat – Arts, Service Social (B.S.S.), Administration et Sciences (par 3 crédits sans laboratoire) 1 619,00 $ » ; « Bourse international … réduits par 125,40 $ pour chaque cours » ; « Administration des affaires (par unité) … International 240,00 $ » ; « Frais laboratoire par cours 132,00 $ ».
- Dépôt de candidature, dates, frais → https://www.usainteanne.ca/futurs-etudiants/demande-dadmission → « pour la session d'automne, avant le 1er mai … pour la session d'hiver, avant le 1er août de l'année précédente » ; « coût d'étude de dossier de 150 $ (non remboursable) » ; deux voies LAP / PPECFSM.
- Collégial int'l (Administration des affaires seulement), 150 $, PPECFSM → https://www.etudescollegiales.ca/demande-admission → « Étudiantes et étudiants internationaux (programme Administration des affaires seulement) » ; « aucun de nos programmes collégiaux ne donne accès à un permis de travail postdiplôme ».
- DAA durée, unités, conditions → https://www.etudescollegiales.ca/programmes/administration/administration-des-affaires → « 2 ans (septembre à juin) ; 1 500 heures ; 95 unités » ; année 1 « 54 » unités, année 2 « 41 » ; « DELF B1 » ; « CLB 4 … Oxford ELLT ».
- Avances → https://www.usainteanne.ca/futurs-etudiants/etudiants-internationaux/avant-de-venir-au-canada → « avance obligatoire de 10 000,00 $ pour les études universitaires … 4 000,00 $ pour les études collégiales ».
- LAP → https://www.usainteanne.ca/futurs-etudiants/etudiants-internationaux/avant-de-venir-au-canada/lettre-dattestation-provinciale-lap → « avance non remboursable de 3 000,00 $ CAN ».
- PPECFSM (programmes éligibles, dépôts, TEF/TCF niveau 5) → https://www.usainteanne.ca/futurs-etudiants/etudiants-internationaux/avant-de-venir-au-canada/ppecfsm → « Pour l'année 2025-2026, le montant du dépôt de participation au PPECFSM est de 20 000 $ » ; « 10 500 $ » (Halifax collégial) ; liste : Administration des affaires collégial, B.A. / B.Sc. (biologie), BAA, BAA coop, B.Éd.
- BAA → https://www.usainteanne.ca/etudes/universitaires/programmes/bac-administration-des-affaires → « Durée 4 ans » ; « 126 crédits - 4 ans » ; « Moyenne de 65 % … pour les 5 cours » ; « test de classement ».
- Biologie → https://www.usainteanne.ca/etudes/universitaires/programmes/bsc-biologie → « Durée 4 ans » ; « Moyenne de 60 % ou plus pour les 5 cours » ; « 2 sciences ».
- Service social → https://www.usainteanne.ca/etudes/universitaires/programmes/bss → « Diplôme décerné par l'Université Laurentienne » ; « 120 crédits - 4 ans (1 + 3) » ; « Aucun test linguistique » ; stages 300 h / 400 h.

## Collège La Cité (na-ca-la-cite)
- Voies d'admission, 350 $, dépôts → https://www.collegelacite.ca/international → « 350 $ frais de demande d'admission ; Dépôt minimal de 4 000 $ CAD » ; PPECFSM « Frais d'études d'une année scolaire (16 500 $ à 21 000 $ CAD) ».
- Guide international (dépôts 4 000 / 16 500, Flywire, programmes, durées) → https://www.collegelacite.ca/documents/10315/30925002/Guide-des-programmes-international.pdf → « Coût de la demande : 350 $ CAD » ; « 16 500 $ CAD pour l'admission au … PPECFSM » ; « LAP non requis pour le PPECFSM » ; « Programmation informatique DÉCO 2 ans / 4 étapes OT Sept – Janv – Mai PPECFSM – PTPD » ; « Commerce – comptabilité … PPECFSM » ; « Technologie du génie informatique DÉCOA 3 ans / 6 étapes PPECFSM ».
- Procédure OCAS / Flywire / TEF-TCF → https://www.collegelacite.ca/procedure-demande-admission-internationaux et https://www.collegelacite.ca/comment-faire-demande-admission-ppecfsm → « plateforme OCAS » ; « (N.B. : Vous devez avoir le NCLC 5 dans les quatre compétences) ».
- Liste PPECFSM → https://www.collegelacite.ca/ppecfsm → « Programmation informatique », « Commerce – comptabilité », « Électroneurodiagnostic », « Technologie du génie informatique » ; « Être admis dans un programme … d'au moins deux ans ».
- Programmation informatique → https://www.collegelacite.ca/programmes/51046 → « Candidat international (2027-2028) … Frais de scolarité 1 412,24 $ … Frais étudiant international 6 071,80 $ … Total 8 792,09 $ | 8 664,09 $ … Total année 1 17 456,18 $ » ; « Les candidats internationaux doivent … détenir un baccalauréat/diplôme d'études secondaires ; être en dernière année du secondaire ou lycée ».
- Commerce – comptabilité → https://www.collegelacite.ca/programmes/51705 → « Total 8 777,09 $ | 8 649,09 $ … Total année 1 17 426,18 $ ».
- Électroneurodiagnostic → https://www.collegelacite.ca/programmes/51606 → « Total * 8 791,09 $ ».
- Technologie du génie informatique → https://www.collegelacite.ca/programmes/61001 → « Total * 8 792,09 $ ».
- Dates OCAS (rentrée sept. 2026 / janv. 2027) → https://www.collegelacite.ca/dates-admission → « Septembre 2026 automne : 10 octobre 2025 … Dès le 1er novembre 2025 » ; « Janvier 2027 hiver 10 octobre 2025 ».

## Collège Boréal (na-ca-boreal)
- Admission internationale (350 $, pas de date limite, 1er juin / 1er octobre, tests) → https://collegeboreal.ca/futurs-etudiants/candidats-internationaux/ → « frais de dossier (350 $ CA) » ; « Il n'y a pas de date limite … le 1er juin pour l'Étape d'automne … le 1er octobre pour l'Étape d'hiver » ; « pas à présenter le résultat d'un test de français » (études en institution francophone).
- Droits int'l automne 2026 → https://collegeboreal.ca/wp-content/uploads/2026/04/droits-de-scolarite-automne-2026-international.pdf → « Techniques des systèmes informatiques … 16,292.53 $ » ; « Techniques en administration des affaires 1re année 16,362.53 $ / 2e 16,292.53 $ » ; « Soins infirmiers auxiliaires 17,031.97 $ / 16,981.97 $ » ; « Techniques du génie électrique 16,842.53 $ / 16,292.53 $ » ; « Baccalauréat en sciences de l'informatique 20,015.83 $ ».
- Droits hiver 2027 → https://collegeboreal.ca/wp-content/uploads/2026/04/droits-de-scolarite-hiver-2027-international.pdf → « Techniques en administration des affaires … 16,284.90 $ ».
- Droits accessoires int'l → https://collegeboreal.ca/wp-content/uploads/2026/04/droits-accessoires-2026-2027-international.pdf → « Assurance maladie et juridique … 1,183.53 $ » ; « Total par année scolaire typique 3,338.43 $ ».
- Publication des droits → https://collegeboreal.ca/etudiants-diplomes/droits-frais/ → « publiés au plus tard le 1er mai pour la prochaine année scolaire ».
- Tests de français → https://collegeboreal.ca/wp-content/uploads/2024/01/1801-189_tableau_evaluation_registraire-francais.pdf → « DELF B2 ; TFI 650 ; TEF B2 (niveau 6) ; TCF B2 (niveau 4) 400 à 499 ».
- Tests d'anglais → https://collegeboreal.ca/wp-content/uploads/2026/06/niveaux_tests_anglais_vf_2026-06-04.pdf → « IELTS Academic … note globale min. 5,5 » ; « Soins infirmiers auxiliaires … 6,0 (aucune compétence sous 5,5) ».
- PPECFSM → https://collegeboreal.ca/futurs-etudiants-et-etudiantes/candidats-internationaux/programme-pilote-pour-les-etudiants-dans-les-communautes-francophones-en-situation-minoritaire-ppecfsm/ → « Programmes admissibles pour la rentrée de septembre 2026 : … Techniques en administration des affaires … Baccalauréat en informatique … » ; « lettre de motivation (maximum de 500 mots) » ; « paiement complet des droits de scolarité pour la première année » ; « Une lettre d'attestation provinciale (LAP) n'est pas requise ».
- Programmes → https://collegeboreal.ca/programme/baccalaureat-en-informatique/ (« 7 étapes ; Sudbury, Toronto ; Sept 2027 ; Calcul différentiel et vecteurs 12U ») ; https://collegeboreal.ca/programme/techniques-en-administration-des-affaires/ (« 4 étapes ; Hearst, Kapuskasing, Sudbury, Timmins, Toronto, Windsor ; Sept 2027, Jan 2028, Jan 2027 ») ; https://collegeboreal.ca/programme/soins-infirmiers-auxiliaires/ (« 4 étapes ; Sept 2027 ; 65 % … NCLC 7 ») ; https://collegeboreal.ca/programme/techniques-du-genie-electrique/ (« 4 étapes ; Sudbury, Toronto ; Sept 2027, Jan 2027 »).

## Vérification indépendante (2026-11-12) — corrections et ajouts

- UOF date limite internationale 2027 (comblé) → https://uof.ca/programmes/programme/baccalaureat-en-sante-mentale/demande-admission (idem .../baccalaureat-specialise-en-communication-et-medias-numeriques/demande-admission) → « Automne 2027 : 17 septembre 2026 au 1 er août 2027 … Canadiens ; 17 septembre 2026 au 30 mai 2027: pour déposer une demande d'admission pour les candidates et candidats internationaux ». Remplace « 30 mai 2026 (dates 2027 non publiées) ».
- UOF tarifs et accessoires relus (https://uofinternational.ca/je-veux-etudier-a-luof/droits-de-scolarite-et-droits-accessoires-obligatoires) : 574 $/crédit, 17 220 $ ; 433,33 $, 12 999,90 $ ; accessoires « Total* … 610,00 $ » par année : OK. Tests (https://uofinternational.ca/je-veux-etudier-a-luof/conditions-dadmission) : DELF B2 (70 %), TFI 700, TEF 600, TCF 450 : OK. Frais OUAC 156 $ (comment-deposer-une-demande-dadmission) : OK.
- UOF durées des 3 bacs : toujours introuvables (pages /programmes/programme/<bac>/description, /conditions-admission, /demande-admission, /droits-scolarite, /avantages, /carriere de uof.ca ; uofinternational.ca/programmes/...).
- La Cité tuitionAnnual (Électroneurodiagnostic, Technologie du génie informatique) : https://www.collegelacite.ca/programmes/51606 « Candidat international (2027-2028) … Étape 1 … Total * 8 791,09 $ » ; https://www.collegelacite.ca/programmes/61001 « Total * 8 792,09 $ ». L'étape 2 n'est pas affichée. Montant annuel = 2 × étape 1 (17 582 / 17 584 CAD), indiqué « ≈ » dans le libellé ; pour Programmation informatique (51046) l'étape 2 est inférieure de 128 CAD (carte étudiante 13 $ + pratique à l'emploi 115 $ seulement à l'étape 1), donc le vrai total peut être un peu plus bas.
- La Cité dates : https://www.collegelacite.ca/dates-admission affiche encore « Septembre 2026 » / « Janvier 2027 » : aucune date 2027-2028 publiée.
- USB relus : PDF https://ustboniface.ca/sites/default/files/2026-08/Frais-ETP-ESIES.pdf (13 160 / 14 385 ; 14 890 / 15 365 ; 14 850 / 14 410 / 14 850 / 13 965 ; « 130,00 $ ») et Frais-USB.pdf (Éducation 14 830 $) ; dates https://ustboniface.ca/dates-limites (tableau « Population internationale et demandeuse d'asile » : TI, administration, sciences infirmières « 1 er mars / 15 mai » ; éducation « 1 er février / 1 er mars ») ; tests https://ustboniface.ca/tests-de-francais-normalises (DALF C1, DELF B2, TCF B2, TEF B2) : OK.
- Sainte-Anne relus : https://www.usainteanne.ca/etudiants/questions-financieres/frais-detudes (1 619 $ ; 240 $ int'l ; 125,40 $ ; 132 $) ; https://www.usainteanne.ca/futurs-etudiants/demande-dadmission (« avant le 1er mai » automne, « avant le 1er août de l'année précédente » hiver, « 150 $ ») : OK. Test de langue d'admission : aucun publié (fiche BAA : seulement « test de classement » en français/anglais après admission ; guide de la demande d'admission sans exigence ; page https://www.usainteanne.ca/futurs-etudiants/etudiants-internationaux/avant-de-venir-au-canada sans test).
- Boréal relu : https://collegeboreal.ca/wp-content/uploads/2026/04/droits-de-scolarite-automne-2026-international.pdf → BINF 1re année « 20,015.83 $ » ; AAFQ « 16,362.53 $ / 16,292.53 $ » ; SIAX « 17,031.97 $ / 16,981.97 $ » ; ELTQ « 16,842.53 $ / 16,292.53 $ » ; https://collegeboreal.ca/futurs-etudiants/candidats-internationaux/ « frais de dossier (350 $ CA) », « Il n'y a pas de date limite » : OK.
- IRCC liste EED relue : USB groupe A (sept. 2026), Sainte-Anne groupe E (janv. 2026), UOF A, Boréal B, La Cité A : OK.
- tuitionAnnual arrondis à l'entier (ex. 12 999,9 → 13 000 ; 20 015,83 → 20 016).

### us

#### Sources US (relevé du 2026-11-12) — fait → URL → citation

## Southeast Missouri State University (na-us-southeast-missouri-state)
- Frais de dossier 60 USD → https://semo.edu/international/admissions/policies → « Submission of the $60 application fee (non-refundable) is required for all international applicants. » / « SEMO does not offer application fee waivers for international applicants. »
- Dates limites (août : 1er juillet ; janvier : 1er novembre) → même URL → « Fall (August) Regular international applicants: July 1 … Spring (January) Regular international applicants: November 1 »
- Anglais licence (TOEFL 3.5 / 61, IELTS 5.5, Duolingo 95, PTE 45) → même URL → « TOEFL iBT ( test date on or after January 21, 2026 ): 3.5 IELTS Academic: 5.5 … Duolingo English Test: 95 »
- Pathway (Duolingo 80-90, IELTS 5.0, TOEFL 3.0) → même URL → « Duolingo English Test: 80-90 » (section English Proficiency Pathway Applicants)
- Anglais master (TOEFL 4.0 / 79, IELTS 6.0, Duolingo 110) → même URL → « Duolingo English Test: 110 » (section Graduate/Master's)
- SAT/ACT non exigés (licence) → https://semo.edu/international/admissions/freshman → « ACT/SAT scores are not required for admissions but may be used to qualify for merit-based scholarships »
- Frais de dossier 60 USD, plateforme → https://semo.edu/international/admissions/freshman et https://semo.edu/international/admissions/grad → « pay the $60 non-refundable application fee before our posted Application Deadlines » ; portail : https://app.semoadmissions.org/ (lien « Apply » de https://semo.edu/international/)
- English Program Pathway → https://semo.edu/international/english-pathway → « All bachelor's (undergraduate) majors accept the IEP Pathway for admission. » / « You will start your studies in August or January. » / « Most English Program Pathway students take 12 credit hours in their first semester »
- Admission conditionnelle master (IEP) → https://semo.edu/student-support/academic-support/registrar/_pdfs/graduate-bulletins/graduate-bulletin-25-26.pdf → « Conditional Admission - International students who need additional English language training may be conditionally admitted to participating graduate programs through the Intensive English Program (IEP). »
- Tarifs 2026-2027 : licence non-résident 647 USD/crédit (600 + 47), master 832 (785 + 47) ; 30 crédits = 19 410 USD ; master 18 crédits = 14 976 USD → https://semo.edu/student-support/financial-services/cost/index → « Non-Domestic Students $600.00 $47.00 $647.00 » ; « Tuition and General Fees (Fall and Spring) $19,410.00 (30 hours per year) … $14,976.00 (18 hours per year) » ; « Non-Domestic Students $785.00 $47.00 $832.00 »
- Frais de programme (CS 40 USD UG / 50 USD grad ; BSBA core 40 ; MBA core 50 ; Nursing UG 40) → même URL → « Computer Science Undergraduate (CS/IS/CY) $40.00 », « Computer Science Graduate (CS/IS/CY) $50.00 », « BSBA Core Courses $40.00 », « MBA Core Courses $50.00 », « Nursing Undergraduate (NC/NS) $40.00 »
- Bourses automatiques → https://semo.edu/student-support/financial-services/financial-aid/international-scholarships → « International academic scholarships are awarded at the time of admission … No separate application is required. » ; « International Achievement Award … Value $8,850.00 … GPA 3.25 (high school) » ; « International Student Scholarship - Freshmen … Value $2,000 … GPA 2.5 » ; « International Student Scholarship – Graduate … Value $1,000 … GPA 3.0 »
- BS Computer Science (120 crédits min., ABET) → https://semo.edu/academics/programs/business-computing/computer-science/computer-science.html → « You'll complete a minimum of 120 credit hours »
- BSBA Accounting → https://semo.edu/academics/programs/business-computing/accounting-economics-finance/accounting → « Business Administration Core – 30 Hours Required »
- BS Industrial and Systems Engineering (ABET-EAC, 120 crédits min.) → https://semo.edu/academics/programs/stem/engineering-tech/industrial-systems → « The engineering, industrial, and systems degree is an ABET-EAC-accredited program »
- BSN (121,5 crédits ; moyenne 2.80 ; 45 crédits de prérequis ; HESI A-2 ; entrée en 2e semestre de l'année 2) → https://semo.edu/academics/programs/education-health/nursing/nursing → « Minimum cumulative GPA of 2.80 » ; « (121.5 hours required for the BSN) » ; « Application and admission are required in the second semester of year two. »
- MBA 33 crédits, pas de GMAT/GRE, GPA 3.0 / 2.5-2.99 → https://semo.edu/academics/programs/business-computing/graduate/mba/mba-general → « (33 Hours Required) » ; « No GMAT/GRE Required » ; https://semo.edu/colleges-departments/business-computing/mba/admission-requirements → « Bachelor's degree* with a cumulative GPA of > or equal to 3.0 »
- MS Applied Computer Science (30 crédits, GPA 3.0, 6 h sciences + 6 h maths, dates internationales 1er mars / 1er octobre) → https://semo.edu/student-support/academic-support/registrar/_pdfs/graduate-bulletins/graduate-bulletin-25-26.pdf → « The deadline for submission of all application materials for international applicants is March 1 for fall … and October 1 for the spring semester. » ; https://semo.edu/academics/programs/business-computing/graduate/ms-applied-cs → « Applied Computer Science (MS) Curriculum Checklist (30 hours) »
- Diplôme de 3 ans à faire évaluer (MBA) → https://semo.edu/colleges-departments/business-computing/mba/admission-requirements → « International students applying with a three-year bachelor's degree must have their transcripts evaluated for equivalency by an outside agency with AICE or NACES certification. »
- Documents par pays (Bénin, Cameroun listés ; baccalauréat accepté) → https://semo.edu/international/admissions/academic-requirements → « Benin Undergraduate Baccalauréat de l'Enseignement Secondaire »

## Fort Hays State University (na-us-fort-hays-state)
- Frais de dossier 50 USD, dates limites UG on-campus (1er juin / 1er novembre ; I-20 15 juin / 15 novembre), moyenne min. 2.5, plateforme → https://www.fhsu.edu/international/admissions/admission-requirements/on-campus → « Students must pay a $50 non-refundable application fee for application submission. » ; « Fall Semester Deadlines June 1 … Spring Semester Deadlines November 1 » ; « The GPA … minimum requirement for international transcripts is 2.5 on a 4.0 grading scale. »
- Frais 50 USD non annulables ; SAT/ACT non requis ; dates (version FAQ) → https://www.fhsu.edu/international/admissions/FAQ/index → « Yes, there is a $50 application fee. No, it cannot be waived. » ; « Is the ACT or SAT exam required? No » ; « Spring semester (January-May) - October 15 » ; « Graduate … Spring semester … October 1 »
- Dates master (1er juin / 1er novembre) → https://www.fhsu.edu/international/admissions/ → « Graduate International Students Semester Deadline Fall Semester June 1st Spring Semester November 1st »
- Anglais (UG TOEFL 61, IELTS 5.5, iTEP 3.6, Duolingo 95 ; grad 79 / 6.5 / 3.9 / 110 ; TLC niveau 9) → https://www.fhsu.edu/international/admissions/Language-Requirements/index → « Duolingo 95 110 » ; « The Language Company (TLC) Successful completion of Level 9 Successful completion of Level 9 plus 2 Advanced English modules » ; « "Online" Intensive English Program offered by The Language Company »
- Frais 2026-2027 : non-résident 651,23 USD/crédit ; master non-résident 778,81 USD/crédit → https://www.fhsu.edu/sfs/students_parents/tuition/fy-27-tuition-and-fees.pdf → « 1 215.84 651.23 302.29 … » (ligne 1 crédit ; colonnes Undergraduate Non-Resident 651.23, Graduate Non-Resident 778.81) ; « An international student is a Non-Resident student for tuition calculation purposes. »
- Tuition UG on-campus 19 536,90 USD (15 crédits × 2) → https://www.fhsu.edu/international/admissions/financial/tuition/index → « Tuition $19,536.90 » ; « Based on 15 credit hours per semester »
- Coût master 2026-27 : tuition 18 crédits 14 022 USD → https://www.fhsu.edu/academic/gradschl/admission/international/estimated-cost/index → « Tuition & Fees (2 semesters, 18 hours) $14,022 »
- Bourses (Freshman 1 500-3 750 USD automatique ; World Ready International sans dossier) → https://www.fhsu.edu/international/admissions/financial/scholarships/index → « Award $1,500 to $3,750 per year … Scholarship is automatically awarded if student meets the criteria » ; « FHSU WORLD READY INTERNATIONAL SCHOLARSHIP … No application required. Eligible students will automatically be awarded »
- Liste des masters sur campus (CS, MBA Finance…) → https://www.fhsu.edu/academic/gradschl/admission/international/index → « Computer Science ( MS) » ; « Finance ( MBA ) » (section On-Campus Academic Programs)
- BS Computer Science 120 h → https://www.fhsu.edu/programs/computer-science/index → « Hours: 120 On-Campus Online »
- BBA Accounting 120 h → https://www.fhsu.edu/programs/accounting/index → « Hours: 120 On-Campus Online »
- BBA Finance 120 h → https://www.fhsu.edu/programs/finance/index → « Hours: 120 On-Campus Online »
- BSN on-campus (3.00 major GPA ; 1er septembre / 1er février) → https://www.fhsu.edu/programs/nursing/index → « A major GPA of 3.00 on a 4.00 scale is required. » ; « by September 1 for spring semester admission or February 1 for fall semester admission »
- MS Computer Science 33 h → https://www.fhsu.edu/programs/computer-science/masters → « Hours: 33 On-Campus Online »
- MBA Finance 33 h → https://www.fhsu.edu/programs/finance/mba → « Hours: 33 On-Campus Online »
- Intakes août/janvier → https://www.fhsu.edu/international/admissions/ → « Fall Semester … Spring Semester »

## Missouri State University (na-us-missouri-state)
- Frais de dossier 40 USD (licence), moyenne min. 2.5, anglais (TOEFL 61, IELTS 5.5, Duolingo 95 ; Tier 2 B1), SAT/ACT non requis → https://international.missouristate.edu/Services/IntlFreshApp.htm → « Complete the online application for admission with the $40 application fee (non-refundable) » ; « The minimum GPA requirement is 2.5/4.0 » ; « Duolingo English Test (DET) 95 and up » ; « Tier 2 Admission … admitted in full … Duolingo English Test (DET) 60-90 » ; « The SAT and ACT tests are not required for international students. »
- Dates limites (UG 1er juin / 1er novembre ; grad 1er mai / 1er octobre ; I-20) → https://www.missouristate.edu/InternationalServices/future.htm → « Fall Graduate: May 1 Undergraduate: June 1 … Spring Graduate: October 1 Undergraduate: November 1 »
- Anglais master (TOEFL 79, IELTS 6.0, Duolingo 110) → https://international.missouristate.edu/Services/english-proficiency.htm → « Duolingo English Test (DET) 110 and up » (Graduate Students)
- Master : GradCAS, GPA 2.75, conditional via institut de langues → https://www.missouristate.edu/InternationalServices/IntlGradApp.htm → « The minimum GPA requirement is 2.75/4.0. It varies by program. » ; https://graduate.missouristate.edu/FutureStudents/international_graduate_students.htm → « conditional admission is offered, on a case-by-case basis and with the approval of the graduate program director, through the Foreign Language Institute »
- Frais master variables selon le CAS → https://international.missouristate.edu/Services/international-graduate.htm → « Pay the application fee through the CAS » ; « Required materials and fees vary by academic program. »
- Frais 2026-2027 internationaux (UG 23 760 USD ; master 17 694 USD) → https://international.missouristate.edu/Services/international-costs.htm → « Tuition & Fees $11,880 $23,760 » ; « Tuition and Fees $8,847 $17,694 »
- Tarif non-résident par crédit (UG 678, grad 825) → https://www.missouristate.edu/Costs/detailed-tuition-and-fees.htm → « Undergraduate Courses numbered 1-599 $317.00 $678.00 » ; « Graduate Courses numbered 600-999 $414.00 $825.00 »
- Étudiants de 91 pays → https://www.missouristate.edu/InternationalServices/ → « 1,600 students from 91 countries »
- BS Computer Science → https://computerscience.missouristate.edu/ → « Computer science (BS) »
- BS Finance → https://www.MissouriState.edu/FERM/Finance/Default.htm → « Bachelor of Science in Finance »
- Génie mécanique coopératif Missouri S&T (132 h min., 2.5) → https://www.missouristate.edu/EGR/Mechanical/default.htm et https://www.missouristate.edu/EGR/FAQ.htm → « Your degree will be awarded by Missouri S&T in cooperation with Missouri State. » ; « You must complete the freshman engineering curriculum with a 2.5 GPA or higher »
- MBA (GMAT/GRE suspendu) → https://MBA.MissouriState.edu/AdmissionRequirements.htm → « The GMAT/GRE requirement has been temporarily suspended for all applicants. »
- Durées MBA / MPH : non reprises (page de catalogue chargée en JavaScript, crédits non vérifiables)
- MS Computer Science → https://ComputerScience.MissouriState.edu/Graduate/default.htm → « Master's Degree in Computer Science » ; candidature GradCAS → https://ComputerScience.MissouriState.edu/Graduate/Requirements.htm
- MPH → https://www.MissouriState.edu/SHS/PublicHealth/default.htm → « The accredited Master of Public Health (MPH) degree » ; https://www.missouristate.edu/SHS/PublicHealth/admission.htm → « Apply to this program through a central application: GradCAS. »

## Vérification indépendante (2026-11-12) — ajouts et corrections
- SEMO : frais d'inscription internationaux 200 USD → https://semo.edu/student-support/financial-services/cost/index → « Enrollment Fee (International Students) $200.00 »
- SEMO : crédits BS CS / BSBA Accounting / ISE : « a minimum of 120 credit hours » → pages programmes déjà citées ; BSN : « 120 credit hours (121.5 hours required for the BSN) » ; MBA « 33 Hours Required » ; MS Applied CS « (30 hours) »
- SEMO : coût du English Program Pathway : NON PUBLIÉ (page https://semo.edu/international/english-pathway : « How much does the English Program Pathway cost? » renvoie à Student Financial Services ; la page https://semo.edu/student-support/financial-services/cost/index ne liste aucun tarif Pathway)
- FHSU : master → 14 022 USD (chiffre officiel) → https://www.fhsu.edu/academic/gradschl/admission/international/estimated-cost/index → « Tuition & Fees (2 semesters, 18 hours) $14,022 » (18 × 778,81 = 14 019 : écart ignoré, chiffre publié retenu)
- FHSU : frais de dossier master 50 USD → https://www.fhsu.edu/academic/gradschl/admission/international/index → « 4.) Pay the $50.00 non-refundable application fee. » ; dates master 1er juin / 1er novembre (I-20 15 juin / 15 novembre) → même page → « June 1st for Fall Semester Start … November 1st for Spring Semester Start »
- FHSU : dates licence sur campus (page la plus spécifique) 1er juin / 1er novembre → https://www.fhsu.edu/international/admissions/admission-requirements/on-campus ; la FAQ (15 oct. licence, 1er oct. master) est contredite par les pages spécifiques : non retenue.
- FHSU : coût de l'anglais intensif (TLC) NON PUBLIÉ sur https://www.fhsu.edu/international/admissions/Language-Requirements/index ni sur https://www.tlc.edu/ (pas de tarif lisible)
- MSU : durée MPH « approximately 2-2.5 years » → https://www.missouristate.edu/SHS/PublicHealth/faq.htm
- MSU : frais de dossier master non publiés (« Application fees vary depending on the program or CAS ») → https://graduate.missouristate.edu/FutureStudents/applying-for-admission.htm
- MSU : crédits MBA / MPH / durée licence : NON TROUVÉS (pages https://mba.missouristate.edu/ProgramRequirements.htm et https://www.missouristate.edu/SHS/PublicHealth/default.htm chargées en JavaScript ; catalog.missouristate.edu renvoie une réponse vide aux requêtes automatiques)
- Janvier 2027 : toutes les dates limites de janvier 2027 (SEMO 1er nov., FHSU 1er nov., MSU 1er nov./1er oct.) sont passées au 12/11/2026 : offerings supprimés (une seule rentrée ouverte), intakePeriods = Automne 2027.


### Durées complétées (12/11/2026)

Durées des formations publiées sans durée : fait → URL → citation. Toledo et Missouri State n'affichent pas le total d'heures par programme (catalogues inaccessibles aux robots) : le minimum officiel de l'université est retenu, écrit « au moins ».

- na-us-houston / bba-finance : 120 crédits → https://www.bauer.uh.edu/undergraduate/documents/2025-2026-BBA-Degree-Plan.pdf → « Total Degree Requirements 120 hours minimum »
- na-us-houston / bsme-mechanical-engineering : 128 crédits → https://www.me.uh.edu/sites/me-new/files/flowcharts/BSME_Degree_Plan_May2023.pdf → « Effective: Fall 2023 (128 Total Credit Hours) »
- na-us-houston / ms-business-analytics : 36 crédits → https://www.bauer.uh.edu/ms-business-analytics/curriculum.php → « The MS degree in Business Analytics requires 36 semester credit hours »
- na-us-houston / ms-finance : 30 crédits → https://bauer.uh.edu/msfinance/ → « The program requires completing 30 credits (the equivalent of 10 full-semester courses) »
- na-us-arizona-state / bs-financial-technology : 120 crédits → https://degrees.asu.edu/bachelors/major/ASU00/BAFINTBS/financial-technology → « Courses 120 credit hours »
- na-us-toledo / bs-mechanical-engineering : 128 crédits → https://www.utoledo.edu/engineering/mechanical-industrial-manufacturing-engineering/pdfs/bsme-flowchart-version-19-march-2023.pdf → « Total hours: 128 Required »
- na-us-toledo / bba-finance : 120 crédits → https://catalog.utoledo.edu/undergraduate/business-innovation/department-finance/bba-finance/bba-finance.pdf → « Total Hours 120 (via search excerpt of catalog PDF; direct fetch blocked by WAF) »
- na-us-toledo / bs-public-health : 120 crédits → https://catalog.utoledo.edu/undergraduate/health-human-services/population-health/bs-public-health/bs-public-health.pdf → « requires 120 credit hours for graduation (via search excerpt of catalog PDF; direct fetch blocked by WAF) »
- na-ca-york / computer-science : 4 ans (120 crédits) → https://calendars.students.yorku.ca/faculty/lassonde-school-of-engineering → « Honours and Specialized Honours Bachelor of Science (BSc) programs, which are usually completed in four years of full-time study, require at least 120 credits »
- na-ca-york / data-science : 4 ans (120 crédits) → https://calendars.students.yorku.ca/faculty/science → « Honours Bachelor of science (Honours BSc) programs are usually completed in four years of full-time study, require at least 120 credits »
- na-ca-york / mechanical-engineering : 4 ans (140 crédits) → https://calendars.students.yorku.ca/faculty/lassonde-school-of-engineering → « The Specialized Honours Bachelor of Engineering (BEng) program requires at least four years of full-time study and at least 140 credits »
- na-ca-york / international-studies-glendon : 120 crédits → https://calendars.students.yorku.ca/faculty/glendon-college/en → « Honours Bachelor of Arts (120 Credits) ... must have successfully completed at least 120 credits »
- na-ca-memorial / bachelor-of-engineering : 5 ans → https://www.mun.ca/undergrad/programs/engineering/ → « Campus: St. John's Length: Five years »
- na-ca-memorial / bachelor-of-commerce : 4 ans (120 crédits) → https://www.mun.ca/undergrad/programs/business/bachelor-of-commerce/ → « Length: Four years ... 40 courses (120 credit hours) »
- na-ca-memorial / bachelor-of-science : 4 ans → https://www.mun.ca/undergrad/programs/science/bachelor-of-science/ → « Faculty: Science Length: Four years »
- na-ca-uqac / baccalaureat-informatique : 90 crédits → https://www.uqac.ca/programme/7833-baccalaureat-en-informatique/ → « Nombre de crédit : 90 »
- na-ca-uqac / baccalaureat-science-donnees-intelligence-affaires : 90 crédits → https://www.uqac.ca/programme/6710-bacc-info-sciences-donnees-intelligence-daffaires/ → « Nombre de crédit : 90 »
- na-ca-moncton / bing-genie-mecanique : 5 ans (150 crédits) → https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25194.pdf → « CRÉDITS REQUIS : 150 (1ère à 5e année - 30 crédits par année) »
- na-ca-moncton / bing-genie-civil : 5 ans (150 crédits) → https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25192.pdf → « CRÉDITS REQUIS : 150 (1ère à 5e année - 30 crédits par année) »
- na-ca-uqat / baccalaureat-genie-electrique : 120 crédits → http://programmes.uqat.ca/programmes/pdf/6513abrg.pdf → « Baccalauréat en génie électrique - 6513 ... 120 crédits, Premier cycle »
- na-ca-uqat / baccalaureat-genie-mecanique : 120 crédits → http://programmes.uqat.ca/programmes/pdf/7947abrg.pdf → « Baccalauréat en génie mécanique - 7947 ... 120 crédits, Premier cycle »
- na-ca-uqat / baccalaureat-administration : 90 crédits → http://programmes.uqat.ca/programmes/pdf/7764abrg.pdf → « Baccalauréat en administration - 7764 ... 90 crédits, Premier cycle (base collégiale) »
- na-ca-uqat / baccalaureat-sciences-comptables : 90 crédits → http://programmes.uqat.ca/programmes/pdf/7766abrg.pdf → « Baccalauréat en sciences comptables - 7766 ... 90 crédits, Premier cycle »
- na-ca-uof / baccalaureat-sante-mentale : 120 crédits → https://uontario.ca/fileadmin/user_upload/PV_CG_2023-05-25_signe.pdf → « la structure du programme proposé comprend 120 crédits, requis pour un baccalauréat spécialisé (procès-verbal du Conseil de gouvernance) »
- na-ca-uof / baccalaureat-travail-social : 120 crédits → https://uontario.ca/fileadmin/user_upload/PV_CG_2023-09-20_signe2.pdf → « Au niveau du cursus, le programme comprend 120 crédits (procès-verbal du Conseil de gouvernance) »
- na-ca-uof / baccalaureat-communication-medias-numeriques : 120 crédits → https://uontario.ca/fileadmin/Site_Corpo/Annuaire/Annuaire_universitaire_2024.2025.pdf → « Pour obtenir un baccalauréat spécialisé de 120 crédits offert par l'Université (règle générale de l'annuaire; page programme sans durée) »
- na-us-missouri-state / mba : 34 crédits → https://mba.missouristate.edu/MBAvsSTEM.htm → « 34 credit hours (12 courses without foundation courses) »
- na-us-missouri-state / ms-computer-science : 4 semestres (environ 1,5 an) → https://ComputerScience.MissouriState.edu/Graduate/default.htm → « It's possible to finish in just four semesters (about 1.5 years) »
- na-us-missouri-state / bs-computer-science : 4 ans (au moins 120 crédits, minimum de l'université) → https://catalog.missouristate.edu/content.php?catoid=6&navoid=319 → « Completed a total of at least 120 semester hours of credit »
- na-us-missouri-state / bs-finance : 4 ans (au moins 120 crédits, minimum de l'université) → https://catalog.missouristate.edu/content.php?catoid=6&navoid=319 → « Completed a total of at least 120 semester hours of credit »
- na-us-toledo / bs-computer-science : 4 ans (au moins 120 crédits, minimum de l'université) → https://catalog.utoledo.edu/pdf/UToledo-General-Section-2024-2025.pdf → « A minimum of 120 semester hours must be earned to be awarded a bachelor's degree »
- na-us-toledo / bs-data-science : 4 ans (au moins 120 crédits, minimum de l'université) → https://catalog.utoledo.edu/pdf/UToledo-General-Section-2024-2025.pdf → « A minimum of 120 semester hours must be earned to be awarded a bachelor's degree »
- na-us-toledo / bs-computer-science-engineering : 4 ans (au moins 120 crédits ; davantage pour ce programme accrédité ABET) → https://catalog.utoledo.edu/pdf/UToledo-General-Section-2024-2025.pdf → « some colleges/programs require more than the minimum for accreditation »
