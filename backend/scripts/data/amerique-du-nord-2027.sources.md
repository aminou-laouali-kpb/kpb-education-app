# Provenance — catalogue Amérique du Nord (`amerique-du-nord-2027.json`)

Relevés faits le **16/10/2026** sur les sites officiels des établissements (et
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

## Contexte (doc, pas dans les fiches)

- Restrictions de visas américains en vigueur au 1/1/2026 (proclamation du 16/12/2025) : <https://www.whitehouse.gov/presidential-actions/2025/12/restricting-and-limiting-the-entry-of-foreign-nationals-to-protect-the-security-of-the-united-states/>
- PPECFSM, liste des établissements participants (page datée du 16/10/2026) : <https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/fmc-student-pilot/eligibility/participating-dlis.html>
