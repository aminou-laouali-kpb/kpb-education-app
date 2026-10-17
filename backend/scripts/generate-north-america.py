#!/usr/bin/env python3
# Génère backend/scripts/data/amerique-du-nord-2027.json depuis les relevés
# faits sur les sites officiels (provenance fait par fait :
# scripts/data/amerique-du-nord-2027.sources.md). Première passe consultée le
# 16/10/2026 ; seconde passe Canada (Québec, Nouveau-Brunswick, collèges de
# l'Ontario) consultée le 17/10/2026 (`consultedAt` propre à l'établissement).
# Rien n'est calculé ici hors des arrondis de libellés : la conversion en
# euros est faite par le module TypeScript (taux BCE versionné), pas par ce
# script.
#
#   python3 scripts/generate-north-america.py            # réécrit le JSON
#   python3 scripts/generate-north-america.py out.json   # ailleurs
import json, os, sys

def fr_num(n):
    return f"{int(round(n)):,}".replace(',', ' ')

def en_num(n):
    return f"{int(round(n)):,}"

def tu(amount, cur, fr_basis, en_basis):
    """Libellé annuel lisible par l'app (devise en code, entier, pas de '$')."""
    return (f"{fr_num(amount)} {cur}/an ({fr_basis})", f"{cur} {en_num(amount)}/year ({en_basis})",
            {"amount": int(round(amount)), "currency": cur})

LANG = {"en": ("Anglais", "English"), "fr": ("Français", "French")}

US_VISA_FR = ("Avant de candidater, vérifie sur travel.state.gov que ton pays n'est pas visé par les restrictions "
              "de visas en vigueur : depuis le 1er janvier 2026, plusieurs pays d'Afrique francophone n'ont plus accès "
              "au visa étudiant F-1.")
US_VISA_EN = ("Before you apply, check on travel.state.gov that your country is not covered by the visa restrictions in force: "
              "since 1 January 2026, several French-speaking African countries no longer have access to the F-1 student visa.")
NOT_PARTNER_FR = "KPB n'est pas partenaire de cet établissement : tu candidates directement auprès de lui. L'admission reste sa décision."
NOT_PARTNER_EN = "KPB is not a partner of this institution: you apply directly to it. Admission remains its decision."
QC_FR = "Au Québec, il te faudra aussi un Certificat d'acceptation du Québec (CAQ) avant de demander ton permis d'études."
QC_EN = "In Quebec, you will also need a Québec Acceptance Certificate (CAQ) before applying for your study permit."

def inst(**k):
    k.setdefault("institutionType", "universite_publique")
    return k

def pathway(nameFr, nameEn, durationFr, durationEn, costFr, costEn, sourceUrl):
    """Programme de langue en amont (anglais ou français) publié par l'établissement."""
    return {"nameFr": nameFr, "nameEn": nameEn, "durationFr": durationFr, "durationEn": durationEn,
            "costFr": costFr, "costEn": costEn, "sourceUrl": sourceUrl}

def prog(slug, nameFr, nameEn, level, fieldId, lang, durFr, durEn, tuition, sourceUrl, reqFr=(), reqEn=(), offerings=None):
    tFr, tEn, annual = tuition if tuition else ("", "", None)
    p = {"slug": slug, "nameFr": nameFr, "nameEn": nameEn, "level": level, "fieldId": fieldId,
         "language": lang, "durationFr": durFr, "durationEn": durEn,
         "tuitionFr": tFr, "tuitionEn": tEn, "tuitionAnnual": annual,
         "requirementsFr": list(reqFr), "requirementsEn": list(reqEn), "sourceUrl": sourceUrl}
    if offerings:
        p["offerings"] = offerings
    return p

def off(campus, *pairs):
    return [{"campus": campus, "intake": i, "session": s} for i, s in pairs]

I = []

# ───────────────────────────── ÉTATS-UNIS ─────────────────────────────
# University of Houston
uh_bus = tu(14602.87 * 2, "USD", "2 semestres, Business/Engineering, non-résident, cohorte 2027 à tarif fixe", "2 semesters, Business/Engineering, non-resident, fixed-rate 2027 cohort")
uh_nsm = tu(14032.64 * 2, "USD", "2 semestres, Sciences (NSM), non-résident, cohorte 2027 à tarif fixe", "2 semesters, Natural Sciences (NSM), non-resident, fixed-rate 2027 cohort")
uh_ms = tu(1464.73 * 18, "USD", "estimation : 18 crédits × 1 465 USD, Business, non-résident 2026-2027", "estimate: 18 credits × USD 1,465, Business, non-resident 2026-2027")
UH_REQ_B_FR = ["Fin d'études secondaires, relevés de notes officiels", "Anglais : TOEFL iBT 4.0 (nouvelle échelle), IELTS 6.5 ou Duolingo 105", "Essai et CV si tu n'entres pas dans l'admission garantie (top 10 %, moyenne 3.5 ou SAT 1250 / ACT 26)"]
UH_REQ_B_EN = ["Secondary-school completion, official transcripts", "English: TOEFL iBT 4.0 (new scale), IELTS 6.5 or Duolingo 105", "Essay and resume if you do not meet assured admission (top 10%, 3.5 GPA or SAT 1250 / ACT 26)"]
UH_REQ_M_FR = ["Licence en 4 ans (ou équivalent international) dans toute discipline", "GMAT ou GRE (dispense possible)", "Anglais : TOEFL 79 (ou 4), IELTS 6.5, Duolingo 105 ou PTE 53", "Frais de candidature : 80 USD"]
UH_REQ_M_EN = ["Four-year bachelor's degree (or international equivalent) in any discipline", "GMAT or GRE (waiver possible)", "English: TOEFL 79 (or 4), IELTS 6.5, Duolingo 105 or PTE 53", "Application fee: USD 80"]
I.append(inst(
    id="na-us-houston", countryId="usa", nameFr="University of Houston", nameEn="University of Houston", acronym="UH",
    locationFr="Houston, Texas", locationEn="Houston, Texas", websiteUrl="https://www.uh.edu/",
    sourceUrl="https://uh.edu/undergraduate-admissions/apply/international/international-freshman/international-freshman-process/",
    overviewFr="Grande université publique de Houston (Texas). En licence, tu peux viser l'admission garantie (top 10 % de ta promotion, moyenne de 3.5 ou SAT 1250 / ACT 26) ; sinon ton essai et ton CV sont étudiés. Duolingo est accepté, et tu peux commencer en août ou en janvier.",
    overviewEn="Large public university in Houston, Texas. For a bachelor's, you can aim for assured admission (top 10% of your class, 3.5 GPA or SAT 1250 / ACT 26); otherwise your essay and resume are reviewed. Duolingo is accepted, and you can start in August or January.",
    languageRequirementsFr="Anglais : TOEFL iBT 4.0 (échelle 1-6), IELTS 6.5 ou Duolingo 105 en licence ; TOEFL 79 / 4, IELTS 6.5, Duolingo 105 ou PTE 53 en master",
    languageRequirementsEn="English: TOEFL iBT 4.0 (1-6 scale), IELTS 6.5 or Duolingo 105 for bachelor's; TOEFL 79 / 4, IELTS 6.5, Duolingo 105 or PTE 53 for master's",
    applicationFee={"amount": 90, "currency": "USD"}, applicationFeeFr="90 USD (licence), 80 USD (masters Bauer)", applicationFeeEn="USD 90 (bachelor's), USD 80 (Bauer master's)",
    tuitionLabelFr="≈ 28 000 – 29 200 USD/an en licence (non-résident, tarif fixe 4 ans) ; 1 465 USD/crédit en master Business",
    tuitionLabelEn="≈ USD 28,000 – 29,200/year for bachelor's (non-resident, 4-year fixed rate); USD 1,465/credit for Business master's",
    intakePeriods=["Janvier 2027", "Automne 2027"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science, B.S.", "Computer Science, B.S.", "Bachelor", "d01", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", uh_nsm, "https://www.uh.edu/nsm/computer-science/about/", UH_REQ_B_FR, UH_REQ_B_EN, off("Houston", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("bba-finance", "Finance, B.B.A.", "Finance, B.B.A.", "BBA", "d02", "en", "", "", uh_bus, "https://bauer.uh.edu/undergraduate/finance/", UH_REQ_B_FR, UH_REQ_B_EN, off("Houston", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("bsme-mechanical-engineering", "Mechanical Engineering, B.S.M.E.", "Mechanical Engineering, B.S.M.E.", "Bachelor", "d03", "en", "", "", uh_bus, "https://www.me.uh.edu/undergraduate", UH_REQ_B_FR + ["Programme accrédité ABET"], UH_REQ_B_EN + ["ABET-accredited programme"], off("Houston", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("ms-business-analytics", "MS Business Analytics (STEM)", "MS Business Analytics (STEM)", "Master", "d01", "en", "", "", uh_ms, "https://bauer.uh.edu/ms-business-analytics/", UH_REQ_M_FR + ["Candidature internationale pour l'automne 2027 : avant le 1er mai 2027"], UH_REQ_M_EN + ["International application for fall 2027: by 1 May 2027"]),
        prog("ms-finance", "MS Finance (STEM)", "MS Finance (STEM)", "Master", "d02", "en", "", "", uh_ms, "https://bauer.uh.edu/msfinance/", UH_REQ_M_FR + ["Candidature internationale pour l'automne 2027 : avant le 1er mai 2027"], UH_REQ_M_EN + ["International application for fall 2027: by 1 May 2027"]),
    ]))

# University of Texas at Arlington
uta_ug = tu(27494, "USD", "frais de scolarité et frais, non-résident, 2026-2027", "tuition and fees, non-resident, 2026-2027")
uta_gr = tu(23486, "USD", "frais de scolarité et frais, master, non-résident, 2026-2027", "tuition and fees, graduate, non-resident, 2026-2027")
UTA_B_FR = ["Fin d'études secondaires équivalente au diplôme américain, relevés officiels", "Anglais : IELTS 6.5, TOEFL iBT 79 ou Duolingo 100 (105 en ingénierie)", "Candidature via Common App, frais 75 USD"]
UTA_B_EN = ["Secondary-school completion equivalent to a U.S. high-school diploma, official transcripts", "English: IELTS 6.5, TOEFL iBT 79 or Duolingo 100 (105 for engineering)", "Apply through the Common App, USD 75 fee"]
UTA_M_FR = ["Licence (ou équivalent)", "Anglais : IELTS 6.5, TOEFL iBT 79 ou Duolingo 100"]
UTA_M_EN = ["Bachelor's degree (or equivalent)", "English: IELTS 6.5, TOEFL iBT 79 or Duolingo 100"]
I.append(inst(
    id="na-us-ut-arlington", countryId="usa", nameFr="University of Texas at Arlington (UTA)", nameEn="University of Texas at Arlington (UTA)", acronym="UTA",
    locationFr="Arlington, Texas", locationEn="Arlington, Texas", websiteUrl="https://www.uta.edu/",
    sourceUrl="https://catalog.uta.edu/academicregulations/admissions/undergraduate/",
    overviewFr="Université publique de la région de Dallas–Fort Worth (Texas), avec une offre large en ingénierie, informatique et data. Duolingo est accepté (100, ou 105 en ingénierie), et les dates de candidature prioritaires pour les internationaux sont le 1er mai (automne), le 1er octobre (printemps) et le 1er mars (été).",
    overviewEn="Public university in the Dallas–Fort Worth area, Texas, with a broad offer in engineering, computing and data. Duolingo is accepted (100, or 105 for engineering), and international priority deadlines are 1 May (fall), 1 October (spring) and 1 March (summer).",
    languageRequirementsFr="Anglais : IELTS 6.5, TOEFL iBT 79 ou Duolingo 100 (105 en ingénierie) ; dispense pour certains pays anglophones",
    languageRequirementsEn="English: IELTS 6.5, TOEFL iBT 79 or Duolingo 100 (105 for engineering); waived for some English-speaking countries",
    applicationFee={"amount": 75, "currency": "USD"}, applicationFeeFr="75 USD (licence)", applicationFeeEn="USD 75 (bachelor's)",
    tuitionLabelFr="≈ 27 494 USD/an en licence, 23 486 USD/an en master (non-résident, 2026-2027)",
    tuitionLabelEn="≈ USD 27,494/year for bachelor's, USD 23,486/year for master's (non-resident, 2026-2027)",
    intakePeriods=["Automne 2027", "Janvier (printemps)", "Été"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Bachelor of Science in Computer Science", "Bachelor of Science in Computer Science", "Bachelor", "d01", "en", "4 ans (123 crédits)", "4 years (123 credit hours)", uta_ug, "https://catalog.uta.edu/engineering/computer/undergraduate/computer-science-bs/", UTA_B_FR, UTA_B_EN),
        prog("bba-finance", "Bachelor of Business Administration in Finance", "Bachelor of Business Administration in Finance", "BBA", "d02", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", uta_ug, "https://catalog.uta.edu/business/finance/undergraduate/finance-bba/", UTA_B_FR, UTA_B_EN),
        prog("bs-mechanical-engineering", "Bachelor of Science in Mechanical Engineering", "Bachelor of Science in Mechanical Engineering", "Bachelor", "d03", "en", "130 crédits", "130 credit hours", uta_ug, "https://catalog.uta.edu/engineering/mechanical/undergraduate/mech-engr-bs/", UTA_B_FR, UTA_B_EN),
        prog("bs-public-health", "Bachelor of Science in Public Health", "Bachelor of Science in Public Health", "Bachelor", "d04", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", uta_ug, "https://catalog.uta.edu/nursing/kinesiology/undergraduate/public-health-bs/", UTA_B_FR, UTA_B_EN),
        prog("ms-data-science", "Master of Science in Data Science", "Master of Science in Data Science", "Master", "d01", "en", "30 crédits", "30 credit hours", uta_gr, "https://catalog.uta.edu/engineering/computer/graduate/data-science-ms/", UTA_M_FR, UTA_M_EN),
        prog("ms-ai-for-business", "Master of Science in Artificial Intelligence for Business", "Master of Science in Artificial Intelligence for Business", "Master", "d01", "en", "33 crédits", "33 credit hours", uta_gr, "https://catalog.uta.edu/business/infosystems/graduate/ai-for-business-ms/", UTA_M_FR, UTA_M_EN),
    ]))

# University of North Texas
def unt(amount, fr, en):
    return tu(amount, "USD", f"frais de scolarité et frais, 9 mois, {fr}, non-résident 2026-2027", f"tuition and fees, 9 months, {en}, non-resident 2026-2027")
UNT_B_FR = ["Fin d'études secondaires, relevés officiels", "Anglais : TOEFL iBT 4 (ou 79 avant le 21/01/2026), IELTS 6.0, Duolingo 100 ou PTE 53", "Frais de candidature : 85 USD"]
UNT_B_EN = ["Secondary-school completion, official transcripts", "English: TOEFL iBT 4 (or 79 before 21/01/2026), IELTS 6.0, Duolingo 100 or PTE 53", "Application fee: USD 85"]
UNT_M_FR = ["Licence (ou équivalent)", "Anglais : TOEFL iBT 4 (ou 79), IELTS 6.0, Duolingo 100 ou PTE 53", "Frais de candidature : 75 USD"]
UNT_M_EN = ["Bachelor's degree (or equivalent)", "English: TOEFL iBT 4 (or 79), IELTS 6.0, Duolingo 100 or PTE 53", "Application fee: USD 75"]
I.append(inst(
    id="na-us-north-texas", countryId="usa", nameFr="University of North Texas (UNT)", nameEn="University of North Texas (UNT)", acronym="UNT",
    locationFr="Denton, Texas", locationEn="Denton, Texas", websiteUrl="https://www.unt.edu/",
    sourceUrl="https://www.unt.edu/admissions/international/deadlines-fees.html",
    overviewFr="Université publique de Denton, au nord de Dallas (Texas). Duolingo est accepté (100) et le niveau d'IELTS demandé est de 6.0. Pour les internationaux, les dates limites en licence sont le 15 juillet (automne) et le 15 novembre (printemps).",
    overviewEn="Public university in Denton, north of Dallas, Texas. Duolingo is accepted (100) and the IELTS requirement is 6.0. International bachelor's deadlines are 15 July (fall) and 15 November (spring).",
    languageRequirementsFr="Anglais : TOEFL iBT 4 (ou 79 avant le 21/01/2026), IELTS 6.0, Duolingo 100 ou PTE 53",
    languageRequirementsEn="English: TOEFL iBT 4 (or 79 before 21/01/2026), IELTS 6.0, Duolingo 100 or PTE 53",
    applicationFee={"amount": 85, "currency": "USD"}, applicationFeeFr="85 USD (licence), 75 USD (master)", applicationFeeEn="USD 85 (bachelor's), USD 75 (master's)",
    tuitionLabelFr="≈ 21 100 – 23 200 USD par année de 9 mois en licence, 17 000 – 19 800 USD en master (non-résident, 2026-2027)",
    tuitionLabelEn="≈ USD 21,100 – 23,200 per 9-month year for bachelor's, USD 17,000 – 19,800 for master's (non-resident, 2026-2027)",
    intakePeriods=["Janvier 2027", "Automne 2027"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science Degree (B.S.)", "Computer Science Degree (B.S.)", "Bachelor", "d01", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", unt(22521, "College of Engineering", "College of Engineering"), "https://www.unt.edu/academics/programs/computer-science-degree.html", UNT_B_FR, UNT_B_EN, off("Denton", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("bs-cybersecurity", "Cybersecurity B.S.", "Cybersecurity B.S.", "Bachelor", "d01", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", unt(22521, "College of Engineering", "College of Engineering"), "https://www.unt.edu/academics/programs/cybersecurity-degree.html", UNT_B_FR, UNT_B_EN, off("Denton", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("bba-finance", "Finance B.B.A.", "Finance B.B.A.", "BBA", "d02", "en", "4 ans (120 crédits)", "4 years (120 credit hours)", unt(21599, "College of Business", "College of Business"), "https://www.unt.edu/academics/programs/finance-degree.html", UNT_B_FR, UNT_B_EN, off("Denton", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("bs-mechanical-energy-engineering", "Mechanical and Energy Engineering Degree (B.S.)", "Mechanical and Energy Engineering Degree (B.S.)", "Bachelor", "d03", "en", "4 ans (127 crédits)", "4 years (127 credit hours)", unt(22521, "College of Engineering", "College of Engineering"), "https://www.unt.edu/academics/programs/mechanical-and-energy-engineering-degree.html", UNT_B_FR, UNT_B_EN, off("Denton", ("01/2027", "spring"), ("FALL 2027", "fall"))),
        prog("ms-data-science", "Data Science Master's", "Data Science Master's", "Master", "d01", "en", "2 ans (36 crédits), format hybride", "2 years (36 credit hours), hybrid", unt(17167, "Data Science", "Data Science"), "https://www.unt.edu/academics/programs/data-science-masters.html", UNT_M_FR, UNT_M_EN),
        prog("ms-artificial-intelligence", "Artificial Intelligence M.S.", "Artificial Intelligence M.S.", "Master", "d01", "en", "2 à 3 ans (33 crédits)", "2-3 years (33 credit hours)", unt(19186, "College of Engineering", "College of Engineering"), "https://www.unt.edu/academics/programs/artificial-intelligence-masters.html", UNT_M_FR, UNT_M_EN),
        prog("ms-business-analytics", "Business Analytics M.S.", "Business Analytics M.S.", "Master", "d02", "en", "1 à 2 ans (36 crédits)", "1-2 years (36 credit hours)", unt(19809, "College of Business", "College of Business"), "https://www.unt.edu/academics/programs/business-analytics-masters.html", UNT_M_FR, UNT_M_EN),
    ]))

# Wichita State University
wsu_ug = tu(20100, "USD", "frais de scolarité et frais, 9 mois, estimation 2026-2027, avant bourse", "tuition and fees, 9 months, 2026-2027 estimate, before scholarship")
wsu_gr = tu(903.59 * 18, "USD", "estimation : 18 crédits × 904 USD, non-résident, automne 2026", "estimate: 18 credits × USD 904, non-resident, fall 2026")
WSU_B_FR = ["Fin d'études secondaires, relevés officiels", "Anglais (plein temps) : TOEFL iBT 4 (ou 72), IELTS 6.0, Duolingo 105 ou PTE 49 ; entre 95 et 104 au Duolingo, tu commences par l'anglais intensif ou à mi-temps"]
WSU_B_EN = ["Secondary-school completion, official transcripts", "English (full-time): TOEFL iBT 4 (or 72), IELTS 6.0, Duolingo 105 or PTE 49; with Duolingo 95-104 you start with intensive English or half-time"]
WSU_M_FR = ["Licence (ou équivalent)", "Frais de candidature : 75 USD (pas de traitement accéléré en master)"]
WSU_M_EN = ["Bachelor's degree (or equivalent)", "Application fee: USD 75 (no expedited processing for master's)"]
I.append(inst(
    id="na-us-wichita-state", countryId="usa", nameFr="Wichita State University", nameEn="Wichita State University", acronym="WSU",
    locationFr="Wichita, Kansas", locationEn="Wichita, Kansas", websiteUrl="https://www.wichita.edu/",
    sourceUrl="https://www.wichita.edu/admissions/international/undergraduate/TotalExpenses.php",
    overviewFr="Université publique de Wichita (Kansas), connue pour l'ingénierie aéronautique. Pour 2026-2027, elle estime les frais de scolarité d'une licence à 20 100 USD sur 9 mois ; la bourse Global Select (5 500 USD si elle t'est attribuée) peut les réduire. Duolingo est accepté.",
    overviewEn="Public university in Wichita, Kansas, known for aerospace engineering. For 2026-2027 it estimates bachelor's tuition and fees at USD 20,100 for 9 months; the Global Select Scholarship (USD 5,500 if awarded) can lower them. Duolingo is accepted.",
    languageRequirementsFr="Anglais (plein temps) : TOEFL iBT 4 (ou 72 avant le 21/01/2026), IELTS 6.0, Duolingo 105, PTE 49, SAT EBRW 410 ou ACT anglais 20",
    languageRequirementsEn="English (full-time): TOEFL iBT 4 (or 72 before 21/01/2026), IELTS 6.0, Duolingo 105, PTE 49, SAT EBRW 410 or ACT English 20",
    applicationFee={"amount": 75, "currency": "USD"}, applicationFeeFr="75 USD (service de base, 4 à 5 semaines) ; 150 ou 250 USD pour un traitement plus rapide", applicationFeeEn="USD 75 (basic service, 4-5 weeks); USD 150 or 250 for faster processing",
    tuitionLabelFr="≈ 20 100 USD sur 9 mois en licence (estimation 2026-2027) ; 904 USD/crédit en master (non-résident)",
    tuitionLabelEn="≈ USD 20,100 for 9 months for bachelor's (2026-2027 estimate); USD 904/credit for master's (non-resident)",
    intakePeriods=["Janvier 2027", "Juin 2027", "Août 2027"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "BS in Computer Science", "BS in Computer Science", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", wsu_ug, "https://catalog.wichita.edu/undergraduate/engineering/school-computing/bs-computer-science/", WSU_B_FR, WSU_B_EN, off("Wichita", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-aerospace-engineering", "BS in Aerospace Engineering", "BS in Aerospace Engineering", "Bachelor", "d03", "en", "129 crédits", "129 credit hours", wsu_ug, "https://catalog.wichita.edu/undergraduate/engineering/aerospace-engineering/aerospace-engineering-bs/", WSU_B_FR, WSU_B_EN, off("Wichita", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-mechanical-engineering", "BS in Mechanical Engineering", "BS in Mechanical Engineering", "Bachelor", "d03", "en", "128 crédits", "128 credit hours", wsu_ug, "https://catalog.wichita.edu/undergraduate/engineering/mechanical-engineering/mechanical-engineering-bs/", WSU_B_FR, WSU_B_EN, off("Wichita", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bba-finance", "BBA - Finance", "BBA - Finance", "BBA", "d02", "en", "120 crédits", "120 credit hours", wsu_ug, "https://catalog.wichita.edu/undergraduate/w-frank-barton-business/finance-real-estate-decision-sciences/bba-finance/", WSU_B_FR, WSU_B_EN, off("Wichita", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("ms-data-science", "MS in Data Science", "MS in Data Science", "Master", "d01", "en", "30 crédits", "30 credit hours", wsu_gr, "https://catalog.wichita.edu/graduate/engineering/school-computing/ms-data-science/", WSU_M_FR, WSU_M_EN),
        prog("ms-business-analytics", "MS in Business Analytics", "MS in Business Analytics", "Master", "d02", "en", "30 crédits", "30 credit hours", wsu_gr, "https://catalog.wichita.edu/graduate/w-frank-barton-business/finance-real-estate-decision-sciences/ms-business-analytics/", WSU_M_FR, WSU_M_EN),
    ]))

# Minnesota State University, Mankato
mnsu_ug = tu(13137, "USD", "frais de scolarité et frais, automne + printemps, avec l'International Maverick Scholarship ; 21 013 USD sans", "tuition and fees, fall + spring, with the International Maverick Scholarship; USD 21,013 without")
mnsu_gr = tu(15822, "USD", "2 semestres de 9 crédits, 2026-2027", "2 semesters of 9 credits, 2026-2027")
MNSU_B_FR = ["Fin d'études secondaires (12 ans), moyenne équivalente à 3.0 sur 4", "Anglais : TOEFL iBT 3.5 (ou 61), IELTS 5.5, Duolingo 95 ou PTE 47"]
MNSU_B_EN = ["Secondary-school completion (12 years), average equivalent to a 3.0 GPA", "English: TOEFL iBT 3.5 (or 61), IELTS 5.5, Duolingo 95 or PTE 47"]
MNSU_M_FR = ["Licence (ou équivalent)", "Preuve de ressources d'au moins 36 980 USD pour 9 mois (I-20, 2026-2027)"]
MNSU_M_EN = ["Bachelor's degree (or equivalent)", "Proof of at least USD 36,980 for 9 months (I-20, 2026-2027)"]
I.append(inst(
    id="na-us-minnesota-state-mankato", countryId="usa", nameFr="Minnesota State University, Mankato", nameEn="Minnesota State University, Mankato", acronym="MNSU",
    locationFr="Mankato, Minnesota", locationEn="Mankato, Minnesota", websiteUrl="https://www.mnsu.edu/",
    sourceUrl="https://www.mnsu.edu/paying-for-college/cost-of-attendance/international-bachelor-student-cost-of-attendance/",
    overviewFr="Université publique de Mankato (Minnesota). Les étudiants internationaux en licence reçoivent automatiquement l'International Maverick Scholarship, qui ramène les frais de scolarité estimés à 13 137 USD par an (21 013 USD sans). Le niveau d'anglais demandé est parmi les plus bas de cette liste (Duolingo 95, IELTS 5.5).",
    overviewEn="Public university in Mankato, Minnesota. International bachelor's students automatically receive the International Maverick Scholarship, which brings estimated tuition and fees to USD 13,137 a year (USD 21,013 without). Its English requirement is among the lowest on this list (Duolingo 95, IELTS 5.5).",
    languageRequirementsFr="Anglais : TOEFL iBT 3.5 (ou 61 avant le 21/01/2026), IELTS 5.5, Duolingo 95, PTE 47, SAT CR 400 ou ACT anglais 15 (plus élevé en soins infirmiers et aviation)",
    languageRequirementsEn="English: TOEFL iBT 3.5 (or 61 before 21/01/2026), IELTS 5.5, Duolingo 95, PTE 47, SAT CR 400 or ACT English 15 (higher for Nursing and Aviation)",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 13 137 USD/an en licence avec la bourse automatique (21 013 USD sans) ; 15 822 USD/an en master (2026-2027)",
    tuitionLabelEn="≈ USD 13,137/year for bachelor's with the automatic scholarship (USD 21,013 without); USD 15,822/year for master's (2026-2027)",
    intakePeriods=["Août 2027", "Janvier (printemps)"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science (BS)", "Computer Science (BS)", "Bachelor", "d01", "en", "120 crédits", "120 credits", mnsu_ug, "https://www.mnsu.edu/academic-catalog/undergraduate/computer-science-bs/", MNSU_B_FR, MNSU_B_EN),
        prog("bs-finance", "Finance (BS) General Finance", "Finance (BS) General Finance", "Bachelor", "d02", "en", "120 crédits", "120 credits", mnsu_ug, "https://www.mnsu.edu/academic-catalog/undergraduate/finance-bs-general-finance/", MNSU_B_FR, MNSU_B_EN),
        prog("bsme-mechanical-engineering", "Mechanical Engineering (BSME)", "Mechanical Engineering (BSME)", "Bachelor", "d03", "en", "128 crédits", "128 credits", mnsu_ug, "https://www.mnsu.edu/academic-catalog/undergraduate/mechanical-engineering-bsme/", MNSU_B_FR, MNSU_B_EN),
        prog("bs-public-health", "Applied Health Science (BS) Public Health", "Applied Health Science (BS) Public Health", "Bachelor", "d04", "en", "120 crédits", "120 credits", mnsu_ug, "https://www.mnsu.edu/academic-catalog/undergraduate/applied-health-science-bs-public-health/", MNSU_B_FR, MNSU_B_EN),
        prog("ms-data-science", "Data Science (MS)", "Data Science (MS)", "Master", "d01", "en", "32 crédits", "32 credits", mnsu_gr, "https://www.mnsu.edu/academic-catalog/graduate/data-science-ms/", MNSU_M_FR, MNSU_M_EN),
        prog("ms-artificial-intelligence", "Artificial Intelligence (MS)", "Artificial Intelligence (MS)", "Master", "d01", "en", "32 crédits", "32 credits", mnsu_gr, "https://www.mnsu.edu/academic-catalog/graduate/artificial-intelligence-ms/", MNSU_M_FR, MNSU_M_EN),
    ]))

# University of Nebraska Omaha
uno_ist = tu(1035 * 24, "USD", "estimation : 24 crédits × 1 035 USD (IS&T), non-résident 2026-2027, hors frais", "estimate: 24 credits × USD 1,035 (IS&T), non-resident 2026-2027, before fees")
uno_cba = tu(1066 * 24, "USD", "estimation : 24 crédits × 1 066 USD (Business), non-résident 2026-2027, hors frais", "estimate: 24 credits × USD 1,066 (Business), non-resident 2026-2027, before fees")
uno_ug = tu(865 * 24, "USD", "estimation : 24 crédits × 865 USD, non-résident 2026-2027, hors frais", "estimate: 24 credits × USD 865, non-resident 2026-2027, before fees")
uno_gr = tu(1231 * 18, "USD", "estimation : 18 crédits × 1 231 USD (IS&T), non-résident 2026-2027, hors frais", "estimate: 18 credits × USD 1,231 (IS&T), non-resident 2026-2027, before fees")
UNO_B_FR = ["Anglais (admission directe) : TOEFL iBT 3.5 (ou 61), IELTS 6.0, Duolingo 95 ou PTE 44", "Si ton score est insuffisant : admission conditionnelle possible via l'Intensive English Program"]
UNO_B_EN = ["English (direct admission): TOEFL iBT 3.5 (or 61), IELTS 6.0, Duolingo 95 or PTE 44", "If your score is too low: conditional admission possible through the Intensive English Program"]
I.append(inst(
    id="na-us-nebraska-omaha", countryId="usa", nameFr="University of Nebraska Omaha (UNO)", nameEn="University of Nebraska Omaha (UNO)", acronym="UNO",
    locationFr="Omaha, Nebraska", locationEn="Omaha, Nebraska", websiteUrl="https://www.unomaha.edu/",
    sourceUrl="https://catalog.unomaha.edu/aboutuno/undergraduate-admissions/international-applicants/",
    overviewFr="Université publique d'Omaha (Nebraska), avec un collège dédié à l'informatique et aux technologies de l'information (IS&T). Les frais de candidature sont de 45 USD, Duolingo est accepté (95), et une admission conditionnelle est possible si ton niveau d'anglais n'est pas encore suffisant.",
    overviewEn="Public university in Omaha, Nebraska, with a college dedicated to information science and technology (IS&T). The application fee is USD 45, Duolingo is accepted (95), and conditional admission is possible if your English is not yet at the required level.",
    languageRequirementsFr="Anglais : TOEFL iBT 3.5 (ou 61), IELTS 6.0, Duolingo 95, PTE 44 ; ingénierie : TOEFL 4.0 (ou 80), IELTS 6.5, Duolingo 110, PTE 53",
    languageRequirementsEn="English: TOEFL iBT 3.5 (or 61), IELTS 6.0, Duolingo 95, PTE 44; engineering: TOEFL 4.0 (or 80), IELTS 6.5, Duolingo 110, PTE 53",
    applicationFee={"amount": 45, "currency": "USD"}, applicationFeeFr="45 USD", applicationFeeEn="USD 45",
    tuitionLabelFr="865 USD/crédit en licence (1 035 USD en IS&T, 1 066 USD en Business) ; 961 USD/crédit en master (non-résident, 2026-2027, hors frais)",
    tuitionLabelEn="USD 865/credit for bachelor's (USD 1,035 in IS&T, USD 1,066 in Business); USD 961/credit for master's (non-resident, 2026-2027, before fees)",
    intakePeriods=["Automne 2027", "Janvier (printemps)"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science, Bachelor of Science", "Computer Science, Bachelor of Science", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", uno_ist, "https://catalog.unomaha.edu/undergraduate/college-information-science-technology/computer-science/computer-science-bs/", UNO_B_FR, UNO_B_EN),
        prog("bs-artificial-intelligence", "Artificial Intelligence, Bachelor of Science in Artificial Intelligence", "Artificial Intelligence, Bachelor of Science in Artificial Intelligence", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", uno_ist, "https://catalog.unomaha.edu/undergraduate/college-information-science-technology/computer-science/ai-bs/", UNO_B_FR, UNO_B_EN),
        prog("bs-cybersecurity", "Cybersecurity, Bachelor of Science", "Cybersecurity, Bachelor of Science", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", uno_ist, "https://catalog.unomaha.edu/undergraduate/college-information-science-technology/school-interdisciplinary-informatics-si2/cybersecurity-bs/", UNO_B_FR, UNO_B_EN),
        prog("bsba-finance", "Finance, Bachelor of Science in Business Administration", "Finance, Bachelor of Science in Business Administration", "Bachelor", "d02", "en", "120 crédits", "120 credit hours", uno_cba, "https://catalog.unomaha.edu/undergraduate/college-business-administration/college-business-administration-finance/", UNO_B_FR, UNO_B_EN),
        prog("bs-public-health", "Public Health, Bachelor of Science", "Public Health, Bachelor of Science", "Bachelor", "d04", "en", "120 crédits", "120 credit hours", uno_ug, "https://catalog.unomaha.edu/undergraduate/college-education/health-kinesiology/public-health-bs/", UNO_B_FR, UNO_B_EN),
        prog("ms-artificial-intelligence", "Artificial Intelligence, MS", "Artificial Intelligence, MS", "Master", "d01", "en", "30 crédits", "30 credit hours", uno_gr, "https://catalog.unomaha.edu/graduate/degree-programs-certificates-minors/aims/", ["Licence (ou équivalent)"], ["Bachelor's degree (or equivalent)"]),
    ]))

# Arizona State University
asu_ug = tu(39062, "USD", "frais de scolarité de base, campus de la région de Phoenix, 2026-2027, hors frais", "base tuition, metro Phoenix campuses, 2026-2027, before fees")
ASU_B_FR = ["Moyenne de 3.00 sur 4 au secondaire (ou équivalent)", "Anglais (hors ingénierie) : IELTS 6.0, TOEFL iBT 3.5 (ou 61), Duolingo 95 ou PTE 53", "Admission conditionnelle possible (valable 3 semestres) si ton dossier est bon mais ton anglais insuffisant"]
ASU_B_EN = ["3.00 GPA in secondary school (or equivalent)", "English (outside engineering): IELTS 6.0, TOEFL iBT 3.5 (or 61), Duolingo 95 or PTE 53", "Conditional admission possible (valid 3 semesters) if your record is strong but your English is not yet sufficient"]
I.append(inst(
    id="na-us-arizona-state", countryId="usa", nameFr="Arizona State University (ASU)", nameEn="Arizona State University (ASU)", acronym="ASU",
    locationFr="Tempe, Arizona", locationEn="Tempe, Arizona", websiteUrl="https://www.asu.edu/",
    sourceUrl="https://admission.asu.edu/apply/international/first-year",
    overviewFr="Grande université publique de l'Arizona (campus de Tempe et de la région de Phoenix). L'admission y est accessible : Duolingo accepté (95 hors ingénierie) et admission conditionnelle possible si ton anglais n'est pas encore au niveau. En revanche, le coût est élevé : 39 062 USD de frais de scolarité de base en licence pour 2026-2027.",
    overviewEn="Large public university in Arizona (Tempe and metro Phoenix campuses). Admission is accessible: Duolingo accepted (95 outside engineering) and conditional admission possible if your English is not there yet. The cost, however, is high: USD 39,062 base tuition for bachelor's in 2026-2027.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL iBT 3.5 (ou 61), Duolingo 95, PTE 53 ; ingénierie (Fulton) : IELTS 6.5, TOEFL 4 (ou 79), Duolingo 105, PTE 58",
    languageRequirementsEn="English: IELTS 6.0, TOEFL iBT 3.5 (or 61), Duolingo 95, PTE 53; engineering (Fulton): IELTS 6.5, TOEFL 4 (or 79), Duolingo 105, PTE 58",
    applicationFee={"amount": 90, "currency": "USD"}, applicationFeeFr="90 USD (75 USD pour les programmes en ligne)", applicationFeeEn="USD 90 (USD 75 for online programmes)",
    tuitionLabelFr="39 062 USD/an en licence, 42 475 USD/an en master (frais de scolarité de base, 2026-2027, hors frais)",
    tuitionLabelEn="USD 39,062/year for bachelor's, USD 42,475/year for master's (base tuition, 2026-2027, before fees)",
    intakePeriods=["Automne 2027", "Janvier (printemps)"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science, BS", "Computer Science, BS", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", asu_ug, "https://degrees.asu.edu/bachelors/major/ASU00/ESCSEBS/computer-science", ASU_B_FR + ["Ingénierie (Fulton) : IELTS 6.5, TOEFL 4 (ou 79), Duolingo 105", "Programme accrédité ABET"], ASU_B_EN + ["Engineering (Fulton): IELTS 6.5, TOEFL 4 (or 79), Duolingo 105", "ABET-accredited programme"]),
        prog("bs-data-science", "Data Science, BS", "Data Science, BS", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", asu_ug, "https://degrees.asu.edu/bachelors/major/ASU00/LADATSCIBS/data-science", ASU_B_FR, ASU_B_EN),
        prog("bs-finance", "Finance, BS", "Finance, BS", "Bachelor", "d02", "en", "120 crédits minimum", "120 credit hours minimum", asu_ug, "https://degrees.asu.edu/bachelors/major/ASU00/BAFINBS/finance", ASU_B_FR, ASU_B_EN),
        prog("bs-financial-technology", "Financial Technology, BS", "Financial Technology, BS", "Bachelor", "d02", "en", "", "", asu_ug, "https://degrees.asu.edu/bachelors/major/ASU00/BAFINTBS/financial-technology", ASU_B_FR, ASU_B_EN),
    ]))

# Kent State University
kent_ug = tu(24298, "USD", "frais de scolarité et frais, 2 semestres, 2026-2027", "tuition and fees, 2 semesters, 2026-2027")
kent_gr = tu(21169, "USD", "frais de scolarité et frais, 2 semestres de 9 crédits, 2026-2027", "tuition and fees, 2 semesters of 9 credits, 2026-2027")
KENT_B_FR = ["Moyenne de 2.5 sur 4 au secondaire ; ACT/SAT non exigés (test-optional)", "Anglais : TOEFL iBT 71, IELTS 6.0, Duolingo 100 ou PTE 48 ; sinon admission conditionnelle possible", "Frais de candidature : 70 USD"]
KENT_B_EN = ["2.5 GPA in secondary school; ACT/SAT not required (test-optional)", "English: TOEFL iBT 71, IELTS 6.0, Duolingo 100 or PTE 48; otherwise conditional admission possible", "Application fee: USD 70"]
I.append(inst(
    id="na-us-kent-state", countryId="usa", nameFr="Kent State University", nameEn="Kent State University", acronym="KSU",
    locationFr="Kent, Ohio", locationEn="Kent, Ohio", websiteUrl="https://www.kent.edu/",
    sourceUrl="https://www.kent.edu/admissions/international-first-year-student-requirements",
    overviewFr="Université publique de Kent (Ohio). En licence, elle demande une moyenne de 2.5 sur 4, n'exige ni ACT ni SAT, accepte Duolingo (100) et peut t'admettre de façon conditionnelle si ton anglais n'est pas encore au niveau. Ses bourses peuvent atteindre, cumulées, 68 000 USD sur une licence de 4 ans.",
    overviewEn="Public university in Kent, Ohio. For a bachelor's it asks for a 2.5 GPA, requires neither ACT nor SAT, accepts Duolingo (100) and can admit you conditionally if your English is not there yet. Combined scholarships can reach USD 68,000 over a four-year bachelor's.",
    languageRequirementsFr="Anglais : TOEFL iBT 71, IELTS 6.0, Duolingo 100, PTE 48, SAT EBRW 510 ou ACT anglais 21",
    languageRequirementsEn="English: TOEFL iBT 71, IELTS 6.0, Duolingo 100, PTE 48, SAT EBRW 510 or ACT English 21",
    applicationFee={"amount": 70, "currency": "USD"}, applicationFeeFr="70 USD", applicationFeeEn="USD 70",
    tuitionLabelFr="≈ 24 298 USD/an en licence, 21 169 USD/an en master (2026-2027)",
    tuitionLabelEn="≈ USD 24,298/year for bachelor's, USD 21,169/year for master's (2026-2027)",
    intakePeriods=["Automne 2027", "Janvier (printemps)"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "Computer Science - B.S.", "Computer Science - B.S.", "Bachelor", "d01", "en", "120 crédits minimum", "120 credit hours minimum", kent_ug, "https://catalog.kent.edu/colleges/sh/cs/computer-science-bs/", KENT_B_FR, KENT_B_EN),
        prog("bba-finance", "Finance - B.B.A.", "Finance - B.B.A.", "BBA", "d02", "en", "120 crédits minimum", "120 credit hours minimum", kent_ug, "https://catalog.kent.edu/colleges/be/fin/finance-bba/", KENT_B_FR, KENT_B_EN),
        prog("bs-aerospace-engineering", "Aerospace Engineering - B.S.", "Aerospace Engineering - B.S.", "Bachelor", "d03", "en", "123 crédits minimum", "123 credit hours minimum", kent_ug, "https://catalog.kent.edu/colleges/ar/engr/aerospace-engineering-bs/", KENT_B_FR, KENT_B_EN),
        prog("bsph-public-health", "Public Health - B.S.P.H.", "Public Health - B.S.P.H.", "Bachelor", "d04", "en", "120 crédits minimum", "120 credit hours minimum", kent_ug, "https://catalog.kent.edu/colleges/pb/public-health-bsph/", KENT_B_FR, KENT_B_EN),
        prog("ms-artificial-intelligence", "Artificial Intelligence - M.S.", "Artificial Intelligence - M.S.", "Master", "d01", "en", "30 crédits minimum", "30 credit hours minimum", kent_gr, "https://catalog.kent.edu/colleges/sh/cs/artificial-intelligence-ms/", ["Licence (ou équivalent)"], ["Bachelor's degree (or equivalent)"]),
        prog("ms-business-analytics", "Business Analytics - M.S.", "Business Analytics - M.S.", "Master", "d02", "en", "30 crédits minimum", "30 credit hours minimum", kent_gr, "https://catalog.kent.edu/colleges/be/isba/business-analytics-ms/", ["Licence (ou équivalent)"], ["Bachelor's degree (or equivalent)"]),
    ]))

# University of Toledo
ut_ug = tu(24160, "USD", "frais de scolarité et frais, 2026-2027, avant bourse ; 24 760 USD en ingénierie", "tuition and fees, 2026-2027, before scholarship; USD 24,760 in engineering")
ut_eng = tu(24760, "USD", "frais de scolarité et frais avec frais d'ingénierie, 2026-2027, avant bourse", "tuition and fees including engineering fees, 2026-2027, before scholarship")
UT_B_FR = ["Anglais : TOEFL iBT 4 (ou 71), IELTS 6.0, Duolingo 105, PTE 48, SAT EBRW 510 ou ACT anglais 21", "International Rocket Award : 8 000 USD/an si ta moyenne est d'au moins 3.0 (attribuée à l'admission, sur la majoration hors État)"]
UT_B_EN = ["English: TOEFL iBT 4 (or 71), IELTS 6.0, Duolingo 105, PTE 48, SAT EBRW 510 or ACT English 21", "International Rocket Award: USD 8,000/year with a GPA of 3.0 or higher (granted on admission, against the out-of-state surcharge)"]
I.append(inst(
    id="na-us-toledo", countryId="usa", nameFr="University of Toledo", nameEn="University of Toledo", acronym="UToledo",
    locationFr="Toledo, Ohio", locationEn="Toledo, Ohio", websiteUrl="https://www.utoledo.edu/",
    sourceUrl="https://www.utoledo.edu/admission/international/tuition/",
    overviewFr="Université publique de Toledo (Ohio). Pour 2026-2027, les frais de scolarité d'une licence sont estimés entre 24 160 et 24 760 USD par an, avant la bourse International Rocket Award (8 000 USD par an si ta moyenne est d'au moins 3.0). Dates limites pour les internationaux : 1er novembre 2026 pour janvier 2027, 1er juillet 2027 pour août 2027.",
    overviewEn="Public university in Toledo, Ohio. For 2026-2027, bachelor's tuition and fees are estimated at USD 24,160 – 24,760 a year, before the International Rocket Award (USD 8,000 a year with a GPA of 3.0 or higher). International deadlines: 1 November 2026 for January 2027, 1 July 2027 for August 2027.",
    languageRequirementsFr="Anglais : TOEFL iBT 4 (ou 71 avant le 21/01/2026), IELTS 6.0, Duolingo 105, PTE 48, Cambridge 170",
    languageRequirementsEn="English: TOEFL iBT 4 (or 71 before 21/01/2026), IELTS 6.0, Duolingo 105, PTE 48, Cambridge 170",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 24 160 – 24 760 USD/an en licence (2026-2027, avant bourse)",
    tuitionLabelEn="≈ USD 24,160 – 24,760/year for bachelor's (2026-2027, before scholarship)",
    intakePeriods=["Janvier 2027", "Août 2027"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science-engineering", "Computer Science and Engineering - Bachelor of Science (B.S.)", "Computer Science and Engineering - Bachelor of Science (B.S.)", "Bachelor", "d01", "en", "", "", ut_eng, "https://www.utoledo.edu/programs/undergrad/computer-science-and-engineering/", UT_B_FR, UT_B_EN, off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-computer-science", "Computer Science - Bachelor of Science (B.S.)", "Computer Science - Bachelor of Science (B.S.)", "Bachelor", "d01", "en", "", "", ut_ug, "https://www.utoledo.edu/programs/undergrad/computer-science/", UT_B_FR, UT_B_EN, off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-data-science", "Data Science - Bachelor of Science (B.S.)", "Data Science - Bachelor of Science (B.S.)", "Bachelor", "d01", "en", "", "", ut_ug, "https://www.utoledo.edu/programs/undergrad/data-science/", UT_B_FR, UT_B_EN, off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bba-finance", "Finance - Bachelor of Business Administration (B.B.A.)", "Finance - Bachelor of Business Administration (B.B.A.)", "BBA", "d02", "en", "", "", ut_ug, "https://www.utoledo.edu/programs/undergrad/finance/", UT_B_FR, UT_B_EN, off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-mechanical-engineering", "Mechanical Engineering - Bachelor of Science (B.S.)", "Mechanical Engineering - Bachelor of Science (B.S.)", "Bachelor", "d03", "en", "", "", ut_eng, "https://www.utoledo.edu/programs/undergrad/mechanical-engineering/", UT_B_FR + ["Ingénierie : ACT 22 / SAT maths 540, ou test ALEKS 76"], UT_B_EN + ["Engineering: ACT 22 / SAT math 540, or ALEKS 76"], off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-public-health", "Public Health - Bachelor of Science (B.S.)", "Public Health - Bachelor of Science (B.S.)", "Bachelor", "d04", "en", "", "", ut_ug, "https://www.utoledo.edu/programs/undergrad/public-health/", UT_B_FR, UT_B_EN, off("Toledo", ("01/2027", "spring"), ("08/2027", "fall"))),
    ]))

# University of Central Missouri
ucm_ug = tu(20278, "USD", "frais de scolarité et frais généraux, 30 crédits, hors État, 2026-2027, avant aide", "tuition and general fees, 30 credit hours, out-of-state, 2026-2027, before aid")
ucm_gr = tu(520 * 18, "USD", "estimation : 18 crédits × 520 USD (masters CS/CIS), 2026-2027, hors frais", "estimate: 18 credits × USD 520 (CS/CIS master's), 2026-2027, before fees")
UCM_B_FR = ["Moyenne de 2.0 au secondaire", "Anglais : TOEFL iBT 61, IELTS 5.5, Duolingo 95, Cambridge 162 ou test d'anglais de l'UCM", "Frais de candidature : 75 USD"]
UCM_B_EN = ["2.0 secondary-school GPA", "English: TOEFL iBT 61, IELTS 5.5, Duolingo 95, Cambridge 162 or the UCM English test", "Application fee: USD 75"]
I.append(inst(
    id="na-us-central-missouri", countryId="usa", nameFr="University of Central Missouri (UCM)", nameEn="University of Central Missouri (UCM)", acronym="UCM",
    locationFr="Warrensburg, Missouri", locationEn="Warrensburg, Missouri", websiteUrl="https://www.ucmo.edu/",
    sourceUrl="https://www.ucmo.edu/future-students/admissions/international-admissions/international-prospective-students/prospective-undergraduate-international/index.php",
    overviewFr="Université publique de Warrensburg (Missouri), réputée pour l'informatique et la cybersécurité. Le niveau d'anglais demandé est bas (Duolingo 95, IELTS 5.5) et tu peux commencer en août, en janvier ou, pour l'informatique et la cybersécurité, en mai.",
    overviewEn="Public university in Warrensburg, Missouri, known for computing and cybersecurity. Its English requirement is low (Duolingo 95, IELTS 5.5) and you can start in August, January or, for computing and cybersecurity, in May.",
    languageRequirementsFr="Anglais : TOEFL iBT 61, IELTS 5.5, Duolingo 95, Cambridge 162 ou test d'anglais de l'UCM",
    languageRequirementsEn="English: TOEFL iBT 61, IELTS 5.5, Duolingo 95, Cambridge 162 or the UCM English test",
    applicationFee={"amount": 75, "currency": "USD"}, applicationFeeFr="75 USD", applicationFeeEn="USD 75",
    tuitionLabelFr="≈ 20 278 USD/an en licence (hors État, 2026-2027) ; 520 USD/crédit en master d'informatique",
    tuitionLabelEn="≈ USD 20,278/year for bachelor's (out-of-state, 2026-2027); USD 520/credit for computing master's",
    intakePeriods=["Janvier 2027", "Mai 2027", "Août 2027"], teachingLanguages=["en"], visaUs=True,
    programs=[
        prog("bs-computer-science", "BS in Computer Science", "BS in Computer Science", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", ucm_ug, "https://www.ucmo.edu/academics/programs/majors/chst/comp-sci-and-cybersecurity/computer-science/computer-science-bachelors/index.php", UCM_B_FR, UCM_B_EN, off("Warrensburg", ("01/2027", "spring"), ("05/2027", "spring"), ("08/2027", "fall"))),
        prog("bs-secure-software-development", "Secure Software Development BS Degree", "Secure Software Development BS Degree", "Bachelor", "d01", "en", "120 crédits", "120 credit hours", ucm_ug, "https://www.ucmo.edu/academics/programs/majors/chst/comp-sci-and-cybersecurity/cybersecurity/cybersecurity-secure-software-development-bs/index.php", UCM_B_FR, UCM_B_EN),
        prog("ms-computer-science", "MS in Computer Science", "MS in Computer Science", "Master", "d01", "en", "30 crédits", "30 credit hours", ucm_gr, "https://www.ucmo.edu/academics/programs/masters-degrees/computer-science-masters/index.php", ["Licence (ou équivalent)"], ["Bachelor's degree (or equivalent)"]),
        prog("ms-data-science-ai", "MS in Data Science & Artificial Intelligence", "MS in Data Science & Artificial Intelligence", "Master", "d01", "en", "30 crédits", "30 credit hours", ucm_gr, "https://www.ucmo.edu/academics/programs/masters-degrees/chst/comp-sci-and-cybersecurity/computer-science/data-science-and-ai-masters/index.php", ["Licence (ou équivalent)"], ["Bachelor's degree (or equivalent)"]),
    ]))

# ───────────────────────────── CANADA ─────────────────────────────
def mcg(amount, fr, en):
    return tu(amount, "CAD", f"droits de scolarité {fr}, nouveaux étudiants internationaux 2026-2027, garantis pour la durée du programme", f"{en} tuition, new international students 2026-2027, guaranteed for the programme")
MCG_FR = ["Anglais : TOEFL iBT 4.5 (ou 90), IELTS 6.5 (6.0 par épreuve), Duolingo 125 ou CAEL 70", "Frais de candidature : 140,16 CAD"]
MCG_EN = ["English: TOEFL iBT 4.5 (or 90), IELTS 6.5 (6.0 per band), Duolingo 125 or CAEL 70", "Application fee: CAD 140.16"]
I.append(inst(
    id="na-ca-mcgill", countryId="can", nameFr="Université McGill", nameEn="McGill University", acronym="McGill",
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.mcgill.ca/",
    sourceUrl="https://www.mcgill.ca/student-accounts/files/student-accounts/new_intl_ugrad_degree_students_admitted_2026-27_0.pdf",
    overviewFr="Université anglophone de Montréal, parmi les plus demandées du Canada. C'est aussi l'une des plus chères pour les internationaux : en 2026-2027, les droits de scolarité d'un B.Sc. sont de 64 786 CAD par an (garantis pour la durée du programme). Tu étudies en anglais dans une ville francophone.",
    overviewEn="English-language university in Montreal, among the most sought-after in Canada. It is also one of the most expensive for international students: in 2026-2027, B.Sc. tuition is CAD 64,786 a year (guaranteed for the programme). You study in English in a French-speaking city.",
    languageRequirementsFr="Anglais : TOEFL iBT 4.5 (ou 90) en sciences, génie et arts, 5.0 (ou 100) en gestion ; IELTS 6.5 ; Duolingo 125 (130 en B.Com.) ; CAEL 70",
    languageRequirementsEn="English: TOEFL iBT 4.5 (or 90) for science, engineering and arts, 5.0 (or 100) for management; IELTS 6.5; Duolingo 125 (130 for B.Com.); CAEL 70",
    applicationFee={"amount": 140.16, "currency": "CAD"}, applicationFeeFr="140,16 CAD", applicationFeeEn="CAD 140.16",
    tuitionLabelFr="54 000 – 71 687 CAD/an selon le diplôme (B.A. 54 000, B.Sc. 64 786, B.Eng. 65 168, B.Com. 71 687 ; 2026-2027)",
    tuitionLabelEn="CAD 54,000 – 71,687/year by degree (B.A. 54,000, B.Sc. 64,786, B.Eng. 65,168, B.Com. 71,687; 2026-2027)",
    intakePeriods=["Automne 2027"], teachingLanguages=["en"], quebec=True,
    programs=[
        prog("bsc-computer-science-major", "Computer Science Major (B.Sc.)", "Computer Science Major (B.Sc.)", "Bachelor", "d01", "en", "Majeure de 63 crédits dans un B.Sc.", "63-credit major within a B.Sc.", mcg(64785.90, "B.Sc.", "B.Sc."), "https://coursecatalogue.mcgill.ca/en/undergraduate/science/programs/computer-science/computer-science-major-bsc/", MCG_FR, MCG_EN),
        prog("bsc-software-engineering-major", "Software Engineering Major (B.Sc.)", "Software Engineering Major (B.Sc.)", "Bachelor", "d01", "en", "Majeure de 63 crédits dans un B.Sc.", "63-credit major within a B.Sc.", mcg(64785.90, "B.Sc.", "B.Sc."), "https://coursecatalogue.mcgill.ca/en/undergraduate/science/programs/computer-science/software-engineering-major-bsc/", MCG_FR, MCG_EN),
        prog("bsc-mathematics-computer-science-major", "Mathematics and Computer Science Major (B.Sc.)", "Mathematics and Computer Science Major (B.Sc.)", "Bachelor", "d01", "en", "Majeure de 72 crédits dans un B.Sc.", "72-credit major within a B.Sc.", mcg(64785.90, "B.Sc.", "B.Sc."), "https://coursecatalogue.mcgill.ca/en/undergraduate/science/programs/mathematics-statistics/mathematics-computer-science-major-bsc/", MCG_FR, MCG_EN),
        prog("beng-mechanical-engineering", "Mechanical Engineering (B.Eng.)", "Mechanical Engineering (B.Eng.)", "Bachelor", "d03", "en", "142 crédits", "142 credits", mcg(65167.50, "B.Eng.", "B.Eng."), "https://coursecatalogue.mcgill.ca/en/undergraduate/engineering/programs/mechanical-engineering/mechanical-engineering-beng/", MCG_FR, MCG_EN),
    ]))

def conc(rate, fr, en):
    return tu(rate * 30, "CAD", f"30 crédits × {fr_num(rate)} CAD ({fr}), internationaux 2026-2027, hors frais", f"30 credits × CAD {en_num(rate)} ({en}), international 2026-2027, before fees")
CON_FR = ["Anglais : Duolingo 105 (aucun sous-score sous 90), IELTS 6.0 (5.5 par épreuve), TOEFL iBT 4.0 (ou 70) ou CAEL 50 ; dispense après 3 ans d'études entièrement en anglais"]
CON_EN = ["English: Duolingo 105 (no subscore below 90), IELTS 6.0 (5.5 per band), TOEFL iBT 4.0 (or 70) or CAEL 50; waived after 3 years of study entirely in English"]
I.append(inst(
    id="na-ca-concordia", countryId="can", nameFr="Université Concordia", nameEn="Concordia University", acronym="Concordia",
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.concordia.ca/",
    sourceUrl="https://www.concordia.ca/students/financial/tuition-fees/rates/undergrad.html",
    overviewFr="Université anglophone de Montréal, avec une grande école de génie et d'informatique (Gina Cody). Duolingo est accepté (105) et la plupart des programmes ouvrent en septembre et en janvier. Pour 2026-2027, compte 1 285 CAD par crédit en génie et informatique, soit environ 38 550 CAD pour une année de 30 crédits.",
    overviewEn="English-language university in Montreal, with a large engineering and computer science school (Gina Cody). Duolingo is accepted (105) and most programmes start in September and January. For 2026-2027, expect CAD 1,285 per credit in engineering and computer science, about CAD 38,550 for a 30-credit year.",
    languageRequirementsFr="Anglais : Duolingo 105 (sous-scores ≥ 90), IELTS 6.0 (≥ 5.5), TOEFL iBT 4.0 (ou 70), CAEL 50, PTE 50",
    languageRequirementsEn="English: Duolingo 105 (subscores ≥ 90), IELTS 6.0 (≥ 5.5), TOEFL iBT 4.0 (or 70), CAEL 50, PTE 50",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="1 160 – 1 400 CAD par crédit selon la faculté (≈ 34 800 – 42 000 CAD pour 30 crédits, internationaux 2026-2027)",
    tuitionLabelEn="CAD 1,160 – 1,400 per credit by faculty (≈ CAD 34,800 – 42,000 for 30 credits, international 2026-2027)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["en"], quebec=True,
    programs=[
        prog("bcompsc-computer-science", "Computer Science (BCompSc)", "Computer Science (BCompSc)", "Bachelor", "d01", "en", "3 à 4 ans", "3 to 4 years", conc(1285, "génie et informatique", "engineering and computer science"), "https://www.concordia.ca/academics/undergraduate/computer-science.html", CON_FR, CON_EN),
        prog("beng-software-engineering", "Software Engineering (BEng)", "Software Engineering (BEng)", "Bachelor", "d01", "en", "4 à 5 ans", "4 to 5 years", conc(1285, "génie et informatique", "engineering and computer science"), "https://www.concordia.ca/academics/undergraduate/software-engineering.html", CON_FR, CON_EN),
        prog("beng-mechanical-engineering", "Mechanical Engineering (BEng)", "Mechanical Engineering (BEng)", "Bachelor", "d03", "en", "4 à 5 ans", "4 to 5 years", conc(1285, "génie et informatique", "engineering and computer science"), "https://www.concordia.ca/academics/undergraduate/mechanical-engineering.html", CON_FR, CON_EN),
        prog("bcomm-finance", "Finance (BComm)", "Finance (BComm)", "Bachelor", "d02", "en", "3 à 4 ans", "3 to 4 years", conc(1400, "John Molson School of Business", "John Molson School of Business"), "https://www.concordia.ca/academics/undergraduate/finance.html", CON_FR, CON_EN),
    ]))

YORK_FR = ["Anglais : TOEFL iBT 4.5 (ou 88), IELTS Academic 6.5, PTE 60, CAEL 60 ou Duolingo 120 ; sinon admission conditionnelle via l'institut d'anglais de York (YUELI)", "Frais de candidature : 140 CAD"]
YORK_EN = ["English: TOEFL iBT 4.5 (or 88), IELTS Academic 6.5, PTE 60, CAEL 60 or Duolingo 120; otherwise conditional admission through the York University English Language Institute (YUELI)", "Application fee: CAD 140"]
york_cs = tu(38000, "CAD", "estimation York, 30 crédits, 2026-2027", "York estimate, 30 credits, 2026-2027")
york_eng = tu(47000, "CAD", "estimation York, 36 crédits en 1re année, 2026-2027", "York estimate, 36 first-year credits, 2026-2027")
york_arts = tu(40000, "CAD", "estimation York, 30 crédits, 2026-2027", "York estimate, 30 credits, 2026-2027")
I.append(inst(
    id="na-ca-york", countryId="can", nameFr="Université York", nameEn="York University", acronym="York",
    locationFr="Toronto, Ontario", locationEn="Toronto, Ontario", websiteUrl="https://www.yorku.ca/",
    sourceUrl="https://futurestudents.yorku.ca/financing-your-degree/tuition-fees",
    overviewFr="Grande université de Toronto, en anglais sur le campus Keele et bilingue (français-anglais) sur le campus Glendon. Glendon participe au programme pilote fédéral pour les étudiants francophones hors Québec (PPECFSM). Pour 2026-2027, York estime les droits des internationaux autour de 38 000 à 47 000 CAD par an selon le programme.",
    overviewEn="Large Toronto university, in English at the Keele campus and bilingual (French-English) at the Glendon campus. Glendon takes part in the federal Francophone Minority Communities Student Pilot. For 2026-2027, York estimates international tuition at about CAD 38,000 – 47,000 a year depending on the programme.",
    languageRequirementsFr="Anglais : TOEFL iBT 4.5 (ou 88), IELTS Academic 6.5, PTE 60, CAEL 60, Cambridge C1 180 ou Duolingo 120 ; admission conditionnelle via YUELI",
    languageRequirementsEn="English: TOEFL iBT 4.5 (or 88), IELTS Academic 6.5, PTE 60, CAEL 60, Cambridge C1 180 or Duolingo 120; conditional admission through YUELI",
    applicationFee={"amount": 140, "currency": "CAD"}, applicationFeeFr="140 CAD (formulaire de York)", applicationFeeEn="CAD 140 (York application)",
    tuitionLabelFr="≈ 38 000 – 47 000 CAD/an selon le programme (estimation York 2026-2027 ; Glendon ≈ 40 574 CAD)",
    tuitionLabelEn="≈ CAD 38,000 – 47,000/year by programme (York 2026-2027 estimate; Glendon ≈ CAD 40,574)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["en", "fr"],
    programs=[
        prog("computer-science", "Computer Science", "Computer Science", "Bachelor", "d01", "en", "", "", york_cs, "https://futurestudents.yorku.ca/program/computer-science", YORK_FR + ["Diplômes : BA, iBA, BSc ou iBSc (campus Keele)"], YORK_EN + ["Degrees: BA, iBA, BSc or iBSc (Keele campus)"]),
        prog("data-science", "Data Science", "Data Science", "Bachelor", "d01", "en", "", "", york_arts, "https://futurestudents.yorku.ca/program/data-science", YORK_FR + ["Diplômes : BA ou BSc (campus Keele) ; rentrée possible en septembre, janvier ou mai"], YORK_EN + ["Degrees: BA or BSc (Keele campus); start in September, January or May"]),
        prog("mechanical-engineering", "Mechanical Engineering", "Mechanical Engineering", "Bachelor", "d03", "en", "", "", york_eng, "https://futurestudents.yorku.ca/program/mechanical-engineering", YORK_FR + ["Diplôme : BEng (campus Keele)"], YORK_EN + ["Degree: BEng (Keele campus)"]),
        prog("international-studies-glendon", "International Studies / Études internationales", "International Studies / Études internationales", "Bachelor", "d07", "bi", "", "", york_arts, "https://futurestudents.yorku.ca/program/international-studies", YORK_FR + ["Diplôme : BA bilingue (campus Glendon)"], YORK_EN + ["Degree: bilingual BA (Glendon campus)"]),
    ]))

mun = tu(22500, "CAD", "droits pour 10 cours (2 semestres), nouveaux étudiants internationaux 2026-2027, hors frais", "tuition for 10 courses (2 semesters), new international students 2026-2027, before fees")
MUN_FR = ["Anglais : IELTS 6.5 (6 en lecture et écriture), TOEFL iBT 4.5 (ou 83), Duolingo 115, CAEL 60 ou PTE 60", "Candidature au moins 12 semaines avant la rentrée visée"]
MUN_EN = ["English: IELTS 6.5 (6 in reading and writing), TOEFL iBT 4.5 (or 83), Duolingo 115, CAEL 60 or PTE 60", "Apply at least 12 weeks before your intended start"]
I.append(inst(
    id="na-ca-memorial", countryId="can", nameFr="Université Memorial de Terre-Neuve (MUN)", nameEn="Memorial University of Newfoundland (MUN)", acronym="MUN",
    locationFr="St. John's, Terre-Neuve-et-Labrador", locationEn="St. John's, Newfoundland and Labrador", websiteUrl="https://www.mun.ca/",
    sourceUrl="https://www.mun.ca/undergrad/money-matters/",
    overviewFr="Université anglophone de St. John's (Terre-Neuve-et-Labrador), parmi les moins chères du Canada pour les internationaux : 22 500 CAD de droits pour une année de 10 cours en 2026-2027 (tarifs gelés au niveau de 2025-2026). Tu peux commencer en septembre, en janvier ou en mai selon le programme.",
    overviewEn="English-language university in St. John's, Newfoundland and Labrador, among the least expensive in Canada for international students: CAD 22,500 tuition for a 10-course year in 2026-2027 (rates frozen at 2025-2026 levels). You can start in September, January or May depending on the programme.",
    languageRequirementsFr="Anglais : IELTS 6.5, TOEFL iBT 4.5 (ou 83), Duolingo 115, CAEL 60, PTE 60, Cambridge 176 ; plus élevé en génie",
    languageRequirementsEn="English: IELTS 6.5, TOEFL iBT 4.5 (or 83), Duolingo 115, CAEL 60, PTE 60, Cambridge 176; higher for engineering",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="22 500 CAD/an pour 10 cours (internationaux, 2026-2027, hors frais)",
    tuitionLabelEn="CAD 22,500/year for 10 courses (international, 2026-2027, before fees)",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("bachelor-of-engineering", "Bachelor of Engineering", "Bachelor of Engineering", "Bachelor", "d03", "en", "", "", mun, "https://www.mun.ca/undergrad/programs/engineering/", MUN_FR + ["Régime coopératif : jusqu'à deux ans d'expérience professionnelle rémunérée"], MUN_EN + ["Co-op: up to two years of paid work experience"]),
        prog("bachelor-of-commerce-coop", "Bachelor of Commerce (Co-operative)", "Bachelor of Commerce (Co-operative)", "Bachelor", "d02", "en", "5 ans, dont 3 stages obligatoires", "5 years, including 3 mandatory work terms", mun, "https://www.mun.ca/undergrad/programs/business/bachelor-of-commerce-co-operative/", MUN_FR, MUN_EN),
        prog("bachelor-of-commerce", "Bachelor of Commerce", "Bachelor of Commerce", "Bachelor", "d02", "en", "", "", mun, "https://www.mun.ca/undergrad/programs/business/bachelor-of-commerce/", MUN_FR, MUN_EN),
        prog("bachelor-of-science", "Bachelor of Science (B.Sc.)", "Bachelor of Science (B.Sc.)", "Bachelor", "d03", "en", "", "", mun, "https://www.mun.ca/undergrad/programs/science/bachelor-of-science/", MUN_FR, MUN_EN),
    ]))

laval = tu(14116.48 * 2, "CAD", "2 sessions de 15 crédits (droits, supplément international et frais), automne 2026 – hiver 2027", "2 terms of 15 credits (tuition, international supplement and fees), fall 2026 – winter 2027")
LAV_FR = ["Si tes études primaires ou secondaires ne se sont pas faites en français : TCF tout public (DELF, TFI ou TEF acceptés avec expression écrite), passé il y a moins de 2 ans", "Frais d'analyse du dossier : 101,49 CAD (automne 2026), 104,53 CAD dès l'hiver 2027"]
LAV_EN = ["If your primary or secondary schooling was not in French: TCF tout public (DELF, TFI or TEF accepted with a writing component), taken less than 2 years ago", "Application review fee: CAD 101.49 (fall 2026), CAD 104.53 from winter 2027"]
I.append(inst(
    id="na-ca-laval", countryId="can", nameFr="Université Laval", nameEn="Université Laval", acronym="ULaval",
    locationFr="Québec, Québec", locationEn="Quebec City, Quebec", websiteUrl="https://www.ulaval.ca/",
    sourceUrl="https://www.ulaval.ca/en/academics/tuition/international-students/undergraduate-programs/fall-2026-winter-2027",
    overviewFr="Grande université francophone de la ville de Québec. Au baccalauréat, une session de 15 crédits coûte 14 116 CAD aux étudiants internationaux en 2026-2027 (droits, supplément et frais). Beaucoup de programmes ouvrent en automne et en hiver.",
    overviewEn="Large French-language university in Quebec City. For a bachelor's, a 15-credit term costs international students CAD 14,116 in 2026-2027 (tuition, supplement and fees). Many programmes start in fall and winter.",
    languageRequirementsFr="Français : TCF tout public si tes études primaires ou secondaires ne se sont pas faites en français (DELF, TFI, TEF acceptés)",
    languageRequirementsEn="French: TCF tout public if your primary or secondary schooling was not in French (DELF, TFI, TEF accepted)",
    applicationFee={"amount": 101.49, "currency": "CAD"}, applicationFeeFr="101,49 CAD (automne 2026), 104,53 CAD dès l'hiver 2027", applicationFeeEn="CAD 101.49 (fall 2026), CAD 104.53 from winter 2027",
    tuitionLabelFr="≈ 28 233 CAD/an (2 sessions de 15 crédits, internationaux 2026-2027)",
    tuitionLabelEn="≈ CAD 28,233/year (2 terms of 15 credits, international 2026-2027)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "3 ans (90 crédits)", "3 years (90 credits)", laval, "https://www.ulaval.ca/etudes/programmes/baccalaureat-en-informatique", LAV_FR, LAV_EN),
        prog("baccalaureat-genie-logiciel", "Baccalauréat en génie logiciel", "Bachelor's in Software Engineering (Baccalauréat en génie logiciel)", "Bachelor", "d01", "fr", "4 ans (120 crédits)", "4 years (120 credits)", laval, "https://www.ulaval.ca/etudes/programmes/baccalaureat-en-genie-logiciel", LAV_FR, LAV_EN),
        prog("baa-administration-affaires", "Baccalauréat en administration des affaires", "Bachelor of Business Administration (Baccalauréat en administration des affaires)", "Bachelor", "d02", "fr", "3 ans (90 crédits)", "3 years (90 credits)", laval, "https://www.ulaval.ca/etudes/programmes/baccalaureat-en-administration-des-affaires", LAV_FR + ["Admission possible en automne, en hiver et en été"], LAV_EN + ["Start in fall, winter or summer"]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "4 ans (120 crédits)", "4 years (120 credits)", laval, "https://www.ulaval.ca/etudes/programmes/baccalaureat-en-genie-mecanique", LAV_FR, LAV_EN),
    ]))

udem = tu(1025.76 * 30, "CAD", "30 crédits × 1 026 CAD, barème international du registraire ; hausse de 3 % annoncée à l'automne 2026", "30 credits × CAD 1,026, registrar's international rate; 3% increase announced for fall 2026")
UDEM_FR = ["Satisfaire à l'exigence de français de l'UdeM (dates sur la fiche du programme)", "Frais d'admission : 83,40 CAD + 23,35 CAD par programme choisi ; dépôt de 1 000 CAD après l'acceptation de l'offre"]
UDEM_EN = ["Meet the UdeM French-language requirement (dates on the programme page)", "Application fee: CAD 83.40 + CAD 23.35 per programme chosen; CAD 1,000 deposit after accepting the offer"]
I.append(inst(
    id="na-ca-montreal", countryId="can", nameFr="Université de Montréal (UdeM)", nameEn="Université de Montréal (UdeM)", acronym="UdeM",
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.umontreal.ca/",
    sourceUrl="https://registraire.umontreal.ca/droits-de-scolarite/couts/",
    overviewFr="Grande université francophone de Montréal. Au baccalauréat, les droits des internationaux sont de 1 025,76 CAD par crédit (barème du registraire ; une hausse de 3 % est annoncée à l'automne 2026). La bourse d'exemption UdeM, attribuée à l'excellence du dossier, peut les réduire jusqu'à 14 436 CAD par an. Plusieurs baccalauréats ouvrent en janvier 2027 : demande d'admission jusqu'au 1er novembre 2026.",
    overviewEn="Large French-language university in Montreal. For a bachelor's, international tuition is CAD 1,025.76 per credit (registrar's rate; a 3% increase is announced for fall 2026). The UdeM exemption scholarship, awarded on academic excellence, can lower it by up to CAD 14,436 a year. Several bachelor's programmes start in January 2027: apply by 1 November 2026.",
    languageRequirementsFr="Français : exigence de français de l'UdeM à satisfaire (preuve ou test selon ton parcours, voir la fiche du programme)",
    languageRequirementsEn="French: the UdeM French-language requirement must be met (proof or test depending on your background, see the programme page)",
    applicationFee={"amount": 106.75, "currency": "CAD"}, applicationFeeFr="83,40 CAD + 23,35 CAD par programme choisi", applicationFeeEn="CAD 83.40 + CAD 23.35 per programme chosen",
    tuitionLabelFr="≈ 30 773 CAD/an (30 crédits × 1 026 CAD, internationaux, avant bourse d'exemption)",
    tuitionLabelEn="≈ CAD 30,773/year (30 credits × CAD 1,026, international, before exemption scholarship)",
    intakePeriods=["Janvier 2027", "Août 2027"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "90 crédits", "90 credits", udem, "https://admission.umontreal.ca/programmes/baccalaureat-en-informatique/", UDEM_FR, UDEM_EN, off("Montréal", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("baccalaureat-mathematiques-informatique", "Baccalauréat en mathématiques et informatique", "Bachelor's in Mathematics and Computer Science (Baccalauréat en mathématiques et informatique)", "Bachelor", "d01", "fr", "91 crédits", "91 credits", udem, "https://admission.umontreal.ca/programmes/baccalaureat-en-mathematiques-et-informatique/", UDEM_FR, UDEM_EN, off("Montréal", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("baccalaureat-sciences-economiques", "Baccalauréat en sciences économiques", "Bachelor's in Economics (Baccalauréat en sciences économiques)", "Bachelor", "d02", "fr", "90 crédits", "90 credits", udem, "https://admission.umontreal.ca/programmes/baccalaureat-en-sciences-economiques/", UDEM_FR, UDEM_EN, off("Montréal", ("01/2027", "spring"), ("08/2027", "fall"))),
        prog("baccalaureat-sciences-biomedicales", "Baccalauréat en sciences biomédicales", "Bachelor's in Biomedical Sciences (Baccalauréat en sciences biomédicales)", "Bachelor", "d04", "fr", "90 crédits", "90 credits", udem, "https://admission.umontreal.ca/programmes/baccalaureat-en-sciences-biomedicales/", UDEM_FR + ["Capacité d'accueil limitée ; rentrée d'août 2027"], UDEM_EN + ["Limited intake; August 2027 start"]),
        prog("maitrise-sante-publique", "Maîtrise en santé publique", "Master's in Public Health (Maîtrise en santé publique)", "Master", "d04", "fr", "45 crédits", "45 credits", None, "https://admission.umontreal.ca/programmes/maitrise-en-sante-publique/", ["Demande d'admission du 1er août 2026 au 1er février 2027, pour août 2027", "Exigence de français de l'UdeM à satisfaire"], ["Apply from 1 August 2026 to 1 February 2027, for an August 2027 start", "UdeM French-language requirement must be met"]),
    ]))

sh_sci = tu(15080 * 2, "CAD", "2 trimestres de 15 crédits sans stage (16 070 CAD par trimestre d'études en régime coopératif), automne 2026", "2 terms of 15 credits without co-op (CAD 16,070 per study term in co-op), fall 2026")
SH_FR = ["Exigence de langue française à l'admission si le programme l'exige et sans dispense", "Bourse d'admission de 2 000 CAD au 1er trimestre (baccalauréat à temps complet)", "Frais d'ouverture du dossier : 106 CAD"]
SH_EN = ["French-language requirement at admission when the programme requires it, unless exempted", "CAD 2,000 admission scholarship in the first term (full-time bachelor's)", "Application file fee: CAD 106"]
I.append(inst(
    id="na-ca-sherbrooke", countryId="can", nameFr="Université de Sherbrooke", nameEn="Université de Sherbrooke", acronym="UdeS",
    locationFr="Sherbrooke, Québec", locationEn="Sherbrooke, Quebec", websiteUrl="https://www.usherbrooke.ca/",
    sourceUrl="https://www.usherbrooke.ca/admission/couts-et-aide-financiere/frais-scolarite/personnes-etudiantes-internationales",
    overviewFr="Université francophone de Sherbrooke, connue pour son régime coopératif (stages rémunérés en alternance). À l'automne 2026, un trimestre de 15 crédits en génie, informatique ou gestion coûte 15 080 CAD aux internationaux (16 070 CAD en trimestre d'études d'un programme avec stages). Une bourse d'admission de 2 000 CAD est déduite du premier trimestre au baccalauréat.",
    overviewEn="French-language university in Sherbrooke, known for its co-op system (paid work terms alternating with study). In fall 2026, a 15-credit term in engineering, computing or management costs international students CAD 15,080 (CAD 16,070 for a study term in a co-op programme). A CAD 2,000 admission scholarship is deducted from the first bachelor's term.",
    languageRequirementsFr="Français : exigence de langue française à l'admission selon le programme, sauf dispense",
    languageRequirementsEn="French: French-language requirement at admission depending on the programme, unless exempted",
    applicationFee={"amount": 106, "currency": "CAD"}, applicationFeeFr="106 CAD", applicationFeeEn="CAD 106",
    tuitionLabelFr="11 975 – 16 070 CAD par trimestre de 15 crédits selon le domaine (internationaux, automne 2026)",
    tuitionLabelEn="CAD 11,975 – 16,070 per 15-credit term by field (international, fall 2026)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "90 crédits", "90 credits", sh_sci, "https://www.usherbrooke.ca/admission/programme/220/baccalaureat-en-informatique/", SH_FR + ["Admission en automne ou en hiver ; régime régulier ou coopératif"], SH_EN + ["Start in fall or winter; regular or co-op"]),
        prog("baccalaureat-genie-informatique", "Baccalauréat en génie informatique", "Bachelor's in Computer Engineering (Baccalauréat en génie informatique)", "Bachelor", "d01", "fr", "120 crédits", "120 credits", sh_sci, "https://www.usherbrooke.ca/admission/programme/236/baccalaureat-en-genie-informatique/", SH_FR + ["Admission en automne ; régime coopératif"], SH_EN + ["Fall start; co-op"]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits", sh_sci, "https://www.usherbrooke.ca/admission/programme/215/baccalaureat-en-genie-mecanique/", SH_FR + ["Admission en automne ; régime régulier ou coopératif"], SH_EN + ["Fall start; regular or co-op"]),
        prog("maitrise-informatique", "Maîtrise en informatique", "Master's in Computer Science (Maîtrise en informatique)", "Master", "d01", "fr", "45 crédits", "45 credits", None, "https://www.usherbrooke.ca/admission/programme/654/maitrise-en-informatique/", ["Admission en automne, en hiver ou en été", "Frais d'ouverture du dossier : 106 CAD"], ["Start in fall, winter or summer", "Application file fee: CAD 106"]),
    ]))

UQAM_FR = ["Frais d'admission 2026 : 155 CAD pour les candidats internationaux"]
UQAM_EN = ["2026 application fee: CAD 155 for international applicants"]
I.append(inst(
    id="na-ca-uqam", countryId="can", nameFr="Université du Québec à Montréal (UQAM)", nameEn="Université du Québec à Montréal (UQAM)", acronym="UQAM",
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://uqam.ca/",
    sourceUrl="https://etudier.uqam.ca/frais-admission",
    overviewFr="Université publique francophone du centre-ville de Montréal, membre du réseau de l'Université du Québec. Les internationaux paient les droits de base et un montant forfaitaire par crédit, qui varie selon le cycle et le programme. Si ton pays a signé une entente de mobilité étudiante avec le Québec, une exemption de ces droits supplémentaires peut être accordée par le gouvernement, dans la limite des places.",
    overviewEn="French-language public university in downtown Montreal, part of the Université du Québec network. International students pay base tuition plus a per-credit lump sum that varies by level and programme. If your country has a student mobility agreement with Quebec, the government may grant an exemption from these extra fees, subject to available places.",
    languageRequirementsFr="Français : programmes enseignés en français ; exigences propres à chaque programme",
    languageRequirementsEn="French: programmes taught in French; requirements set by each programme",
    applicationFee={"amount": 155, "currency": "CAD"}, applicationFeeFr="155 CAD (candidats internationaux, 2026)", applicationFeeEn="CAD 155 (international applicants, 2026)",
    tuitionLabelFr="Droits de base + montant forfaitaire par crédit pour les internationaux (montant 2026-2027 à confirmer)",
    tuitionLabelEn="Base tuition + per-credit lump sum for international students (2026-2027 amount to be confirmed)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique-genie-logiciel", "Baccalauréat en informatique et génie logiciel", "Bachelor's in Computer Science and Software Engineering (Baccalauréat en informatique et génie logiciel)", "Bachelor", "d01", "fr", "90 crédits (96 en régime coopératif)", "90 credits (96 in co-op)", None, "https://etudier.uqam.ca/programme?code=7316", UQAM_FR + ["Admission en automne ou en hiver ; programme non contingenté"], UQAM_EN + ["Start in fall or winter; open-enrolment programme"]),
        prog("baccalaureat-systemes-informatiques-electroniques", "Baccalauréat en systèmes informatiques et électroniques", "Bachelor's in Computer and Electronic Systems (Baccalauréat en systèmes informatiques et électroniques)", "Bachelor", "d03", "fr", "90 crédits", "90 credits", None, "https://etudier.uqam.ca/programme?code=6526", UQAM_FR + ["Admission en automne ou en hiver ; programme non contingenté"], UQAM_EN + ["Start in fall or winter; open-enrolment programme"]),
        prog("baccalaureat-informatique-gestion", "Baccalauréat en informatique de gestion", "Bachelor's in Management Information Systems (Baccalauréat en informatique de gestion)", "Bachelor", "d01", "fr", "96 crédits", "96 credits", None, "https://etudier.uqam.ca/programme?code=7116", UQAM_FR, UQAM_EN),
        prog("maitrise-informatique", "Maîtrise en informatique", "Master's in Computer Science (Maîtrise en informatique)", "Master", "d01", "fr", "45 crédits", "45 credits", None, "https://etudier.uqam.ca/programme?code=3792", UQAM_FR, UQAM_EN),
    ]))

I.append(inst(
    id="na-ca-uqac", countryId="can", nameFr="Université du Québec à Chicoutimi (UQAC)", nameEn="Université du Québec à Chicoutimi (UQAC)", acronym="UQAC",
    locationFr="Saguenay, Québec", locationEn="Saguenay, Quebec", websiteUrl="https://www.uqac.ca/",
    sourceUrl="https://international.uqac.ca/etudier-a-luqac/preparer-son-sejour/budget/",
    overviewFr="Université francophone de Saguenay, membre du réseau de l'Université du Québec. Tes droits de scolarité annuels figurent sur ton attestation d'admission, et tu dois être inscrit à temps complet en automne et en hiver. Attention : le programme d'exemption des droits supplémentaires « selon le programme d'études et la région » n'est pas reconduit à partir de 2026-2027.",
    overviewEn="French-language university in Saguenay, part of the Université du Québec network. Your annual tuition is shown on your letter of admission, and you must study full-time in fall and winter. Note: the extra-fee exemption programme based on the programme and region is not renewed from 2026-2027.",
    languageRequirementsFr="Français : programmes enseignés en français",
    languageRequirementsEn="French: programmes taught in French",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="Fixés par le gouvernement du Québec ; montant annuel indiqué sur l'attestation d'admission",
    tuitionLabelEn="Set by the Quebec government; annual amount shown on the letter of admission",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "", "", None, "https://programmes.uqac.ca/7833", ["Concentration possible en intelligence artificielle appliquée", "Exigences en mathématiques (calcul différentiel et intégral, algèbre linéaire)"], ["Optional concentration in applied artificial intelligence", "Mathematics prerequisites (calculus, linear algebra)"]),
        prog("baccalaureat-science-donnees-intelligence-affaires", "Baccalauréat en informatique de la science des données et de l'intelligence d'affaires", "Bachelor's in Data Science and Business Intelligence (Baccalauréat en informatique de la science des données et de l'intelligence d'affaires)", "Bachelor", "d01", "fr", "", "", None, "https://programmes.uqac.ca/6710", ["Exigence en mathématiques : algèbre linéaire et géométrie vectorielle"], ["Mathematics prerequisite: linear algebra and vector geometry"]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits", None, "https://programmes.uqac.ca/7947", ["Admission en automne ou en hiver ; programme non contingenté", "Jusqu'à cinq stages rémunérés"], ["Start in fall or winter; open-enrolment programme", "Up to five paid internships"]),
        prog("maitrise-informatique-ia", "Maîtrise en informatique (intelligence artificielle)", "Master's in Computer Science – Artificial Intelligence (Maîtrise en informatique (intelligence artificielle))", "Master", "d01", "fr", "45 crédits", "45 credits", None, "https://programmes.uqac.ca/2139", ["Baccalauréat en informatique (ou domaine proche), moyenne d'au moins 3,0 sur 4,3", "Admission en automne, en hiver ou en été"], ["Bachelor's in computer science (or related field), average of at least 3.0/4.3", "Start in fall, winter or summer"]),
    ]))

mon = tu(15761, "CAD", "droits de scolarité, 1er cycle à temps plein, internationaux 2026-2027 ; ≈ 17 728 – 17 839 CAD avec frais et assurances", "tuition, full-time undergraduate, international 2026-2027; ≈ CAD 17,728 – 17,839 with fees and insurance")
I.append(inst(
    id="na-ca-moncton", countryId="can", nameFr="Université de Moncton", nameEn="Université de Moncton", acronym="UMoncton",
    locationFr="Moncton, Nouveau-Brunswick", locationEn="Moncton, New Brunswick", websiteUrl="https://www.umoncton.ca/",
    sourceUrl="https://www.umoncton.ca/couts-annee-universitaire",
    overviewFr="Plus grande université francophone hors Québec, avec des campus à Moncton, Edmundston et Shippagan (Nouveau-Brunswick). En 2026-2027, les droits de scolarité d'un baccalauréat à temps plein sont de 15 761 CAD pour les internationaux. Elle participe au programme pilote fédéral pour les étudiants francophones en situation minoritaire (PPECFSM), une voie de permis d'études propre aux établissements francophones hors Québec.",
    overviewEn="Largest French-language university outside Quebec, with campuses in Moncton, Edmundston and Shippagan, New Brunswick. In 2026-2027, full-time bachelor's tuition is CAD 15,761 for international students. It takes part in the federal Francophone Minority Communities Student Pilot, a study permit route for French-language institutions outside Quebec.",
    languageRequirementsFr="Français : programmes enseignés en français (au moins 6 crédits de français dans chaque programme)",
    languageRequirementsEn="French: programmes taught in French (at least 6 credits of French in every programme)",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="15 761 CAD/an en 1er cycle (internationaux, 2026-2027) ; ≈ 17 728 – 17 839 CAD avec frais et assurances",
    tuitionLabelEn="CAD 15,761/year for undergraduate (international, 2026-2027); ≈ CAD 17,728 – 17,839 with fees and insurance",
    intakePeriods=["Automne 2027"], teachingLanguages=["fr"],
    programs=[
        prog("baccalaureat-informatique-appliquee", "Baccalauréat en informatique appliquée", "Bachelor's in Applied Computer Science (Baccalauréat en informatique appliquée)", "Bachelor", "d01", "fr", "4 ans (120 crédits)", "4 years (120 credits)", mon, "https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25207.pdf", ["Quatre ans à Moncton (les premières années aussi à Edmundston ou Shippagan)"], ["Four years in Moncton (first years also in Edmundston or Shippagan)"]),
        prog("baa-finance", "Baccalauréat en administration des affaires (finance)", "Bachelor of Business Administration – Finance (Baccalauréat en administration des affaires (finance))", "Bachelor", "d02", "fr", "4 ans (120 crédits)", "4 years (120 credits)", mon, "https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25234.pdf", ["Version coopérative aussi proposée"], ["Co-op version also offered"]),
        prog("bing-genie-mecanique", "Baccalauréat en ingénierie (génie mécanique)", "Bachelor of Engineering – Mechanical (Baccalauréat en ingénierie (génie mécanique))", "Bachelor", "d03", "fr", "", "", mon, "https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25194.pdf", ["Version coopérative aussi proposée"], ["Co-op version also offered"]),
        prog("bing-genie-civil", "Baccalauréat en ingénierie (génie civil)", "Bachelor of Engineering – Civil (Baccalauréat en ingénierie (génie civil))", "Bachelor", "d05", "fr", "", "", mon, "https://www.umoncton.ca/institutionnel/modules/repertoire/pdf/25192.pdf", ["Version coopérative aussi proposée"], ["Co-op version also offered"]),
    ]))

# ─────────────────── CANADA — SECONDE PASSE (17/10/2026) ───────────────────
# Décisions du propriétaire : prioriser le Québec (réseau UQ et écoles très
# demandées), compléter le Nouveau-Brunswick, puis des collèges anglophones de
# l'Ontario à admission plus accessible avec un programme de langue en amont.
# Chaque fait : scripts/data/amerique-du-nord-2027.sources.md (section
# « Seconde passe »). Rentrées datées uniquement si la page officielle les
# affichait « Open / Available » pour les internationaux le 17/10/2026.
C2 = "2026-10-17"

def cad(amount, fr, en):
    return tu(amount, "CAD", fr, en)

def offs(*rows):
    """rows = (campus, intake 'mm/aaaa') ; janvier à juin = rentrée décalée (spring)."""
    return [{"campus": c, "intake": i, "session": "spring" if int(i[:2]) <= 6 else "fall"} for c, i in rows]

PGWP_FR = "Admissible au permis de travail post-diplôme (PGWP) selon l'établissement (code CIP {})"
PGWP_EN = "Post-Graduation Work Permit (PGWP) eligible according to the institution (CIP code {})"
def pgwp(cip):
    return PGWP_FR.format(cip), PGWP_EN.format(cip)

# ── Ontario : Humber Polytechnic ──
HUM_FEE_FR, HUM_FEE_EN = "2 semestres, internationaux, 2026-2027", "2 semesters, international, 2026-2027"
HUM_DIP_FR = ["Diplôme d'études secondaires (OSSD ou équivalent) avec anglais et mathématiques de 12e année",
              "Anglais : IELTS 6.0 (aucune bande sous 5.5), TOEFL iBT 4 (2026) ou 80, Duolingo 105, PTE 53"]
HUM_DIP_EN = ["Secondary school diploma (OSSD or equivalent) with Grade 12 English and Mathematics",
              "English: IELTS 6.0 (no band below 5.5), TOEFL iBT 4 (2026) or 80, Duolingo 105, PTE 53"]
HUM_GC_FR = "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL iBT 4.5 (2026) ou 88, Duolingo 125, PTE 61"
HUM_GC_EN = "English: IELTS 6.5 (no band below 6.0), TOEFL iBT 4.5 (2026) or 88, Duolingo 125, PTE 61"
I.append(inst(
    id="na-ca-humber", countryId="can", nameFr="Humber Polytechnic", nameEn="Humber Polytechnic", acronym="Humber",
    institutionType="college_public", consultedAt=C2,
    locationFr="Toronto, Ontario", locationEn="Toronto, Ontario", websiteUrl="https://humber.ca/",
    sourceUrl="https://humber.ca/international/admissions-financial-aid/how-to-apply/admissions-road-map",
    overviewFr="Grand collège public de Toronto (campus North et Lakeshore). Beaucoup de diplômes et de certificats postdiplôme ouvrent en janvier, mai et septembre, et la fiche de chaque programme dit s'il est admissible au permis de travail post-diplôme (PGWP). Si ton anglais n'atteint pas encore le niveau demandé, le programme English for Academic Purposes (EAP) de Humber remplit l'exigence d'anglais une fois réussi.",
    overviewEn="Large public college in Toronto (North and Lakeshore campuses). Many diplomas and graduate certificates start in January, May and September, and each programme page says whether it is eligible for the Post-Graduation Work Permit (PGWP). If your English is not yet at the required level, Humber's English for Academic Purposes (EAP) programme meets the English requirement once you pass it.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL iBT 4 (2026) ou 80, Duolingo 105 ou PTE 53 pour les certificats et diplômes ; IELTS 6.5 et Duolingo 115 pour les baccalauréats ; IELTS 6.5 et Duolingo 125 pour les certificats postdiplôme",
    languageRequirementsEn="English: IELTS 6.0, TOEFL iBT 4 (2026) or 80, Duolingo 105 or PTE 53 for certificates and diplomas; IELTS 6.5 and Duolingo 115 for bachelor's degrees; IELTS 6.5 and Duolingo 125 for graduate certificates",
    languagePathway=pathway("General Arts and Science – English for Academic Purposes (EAP)", "General Arts and Science – English for Academic Purposes (EAP)",
                            "certificat de 2 semestres ; réussi avec 60 % au semestre 2, il remplit l'exigence d'anglais des diplômes", "2-semester certificate; passed with 60% in semester 2, it meets the English requirement for diplomas",
                            "15 437 CAD pour 2 semestres (internationaux, 2026-2027), non admissible au PGWP", "CAD 15,437 for 2 semesters (international, 2026-2027), not PGWP-eligible",
                            "https://humber.ca/explore-programs/programs/general-arts-and-science-english-for-academic-purposes"),
    applicationFee={"amount": 100, "currency": "CAD"}, applicationFeeFr="100 CAD (jusqu'à 2 choix de programme)", applicationFeeEn="CAD 100 (up to 2 programme choices)",
    tuitionLabelFr="≈ 20 868 – 24 765 CAD par année de 2 semestres selon le programme (internationaux, 2026-2027)",
    tuitionLabelEn="≈ CAD 20,868 – 24,765 per 2-semester year by programme (international, 2026-2027)",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("computer-programming", "Computer Programming", "Computer Programming", "Diplôme collégial", "d01", "en", "4 semestres (diplôme de l'Ontario)", "4 semesters (Ontario College Diploma)",
             cad(21735.80, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/computer-programming",
             HUM_DIP_FR + [pgwp("11.0201")[0]], HUM_DIP_EN + [pgwp("11.0201")[1]],
             offs(("North", "01/2027"), ("North", "05/2027"), ("North", "09/2027"), ("Downtown (IGS)", "09/2027"))),
        prog("computer-engineering-technology", "Computer Engineering Technology", "Computer Engineering Technology", "Diplôme collégial", "d03", "en", "6 semestres (diplôme avancé de l'Ontario)", "6 semesters (Ontario College Advanced Diploma)",
             cad(21329.89, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/computer-engineering-technology",
             HUM_DIP_FR + [pgwp("15.1201")[0]], HUM_DIP_EN + [pgwp("15.1201")[1]],
             offs(("North", "01/2027"), ("North", "09/2027"))),
        prog("practical-nursing", "Practical Nursing", "Practical Nursing", "Diplôme collégial", "d04", "en", "4 semestres (diplôme de l'Ontario)", "4 semesters (Ontario College Diploma)",
             cad(20867.55, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/practical-nursing",
             ["Diplôme d'études secondaires (OSSD ou équivalent) avec anglais, mathématiques, biologie et chimie", HUM_DIP_FR[1], pgwp("51.3901")[0]],
             ["Secondary school diploma (OSSD or equivalent) with English, Mathematics, Biology and Chemistry", HUM_DIP_EN[1], pgwp("51.3901")[1]],
             offs(("North", "09/2027"), ("Humber Height (Off Campus)", "09/2027"))),
        prog("artificial-intelligence-with-machine-learning", "Artificial Intelligence with Machine Learning", "Artificial Intelligence with Machine Learning", "Graduate certificate", "d01", "en", "2 semestres (certificat postdiplôme de l'Ontario)", "2 semesters (Ontario Graduate Certificate)",
             cad(20992.84, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/artificial-intelligence-with-machine-learning",
             ["Baccalauréat, diplôme avancé ou diplôme, de préférence en programmation, génie logiciel ou informatique, avec un cours avancé de mathématiques et un cours de programmation", HUM_GC_FR, pgwp("11.0102")[0]],
             ["Bachelor's degree, advanced diploma or diploma, preferably in computer programming, software engineering or computer science, with one advanced mathematics course and one programming course", HUM_GC_EN, pgwp("11.0102")[1]],
             offs(("North", "01/2027"), ("North", "05/2027"), ("North", "09/2027"))),
        prog("data-analytics", "Data Analytics", "Data Analytics", "Graduate certificate", "d01", "en", "2 semestres (certificat postdiplôme de l'Ontario)", "2 semesters (Ontario Graduate Certificate)",
             cad(22781.36, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/data-analytics",
             ["Baccalauréat dans toute discipline, ou diplôme (avancé) dans un domaine proche (affaires, mathématiques / statistique, programmation)", HUM_GC_FR, pgwp("30.7101")[0]],
             ["Bachelor's degree in any discipline, or (advanced) diploma in a related field (business, mathematics / statistics, programming)", HUM_GC_EN, pgwp("30.7101")[1]],
             offs(("Lakeshore", "01/2027"), ("Lakeshore", "05/2027"), ("Lakeshore", "09/2027"))),
        prog("business-insights-and-analytics", "Business Insights and Analytics", "Business Insights and Analytics", "Graduate certificate", "d02", "en", "4 semestres (certificat postdiplôme de l'Ontario), stage de 220 heures", "4 semesters (Ontario Graduate Certificate), 220-hour placement",
             cad(24764.54, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/business-insights-and-analytics",
             ["Baccalauréat dans toute discipline, ou diplôme (avancé) dans un domaine proche (affaires, mathématiques / statistique, programmation)", HUM_GC_FR, pgwp("52.1301")[0]],
             ["Bachelor's degree in any discipline, or (advanced) diploma in a related field (business, mathematics / statistics, programming)", HUM_GC_EN, pgwp("52.1301")[1]],
             offs(("Lakeshore", "01/2027"), ("Lakeshore", "05/2027"), ("Lakeshore", "09/2027"))),
        prog("bachelor-computer-science-cybersecurity", "Bachelor of Computer Science - Cybersecurity", "Bachelor of Computer Science - Cybersecurity", "Bachelor", "d01", "en", "8 semestres (baccalauréat spécialisé)", "8 semesters (Honours Bachelor's Degree)",
             cad(24096.04, HUM_FEE_FR, HUM_FEE_EN), "https://humber.ca/explore-programs/programs/bachelor-of-computer-science-cybersecurity",
             ["Diplôme d'études secondaires avec anglais, physique, calcul et vecteurs de 12e année (65 % minimum par cours exigé)", "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL iBT 4.5 (2026) ou 84, Duolingo 115", "Rentrée de septembre 2027 ; tout baccalauréat est admissible au PGWP selon Humber"],
             ["Secondary school diploma with Grade 12 English, Physics, Calculus and Vectors (at least 65% in each required course)", "English: IELTS 6.5 (no band below 6.0), TOEFL iBT 4.5 (2026) or 84, Duolingo 115", "September 2027 start; every bachelor's degree is PGWP-eligible according to Humber"]),
    ]))

# ── Ontario : Seneca Polytechnic ──
SEN_FEE_FR, SEN_FEE_EN = "frais de scolarité seuls de la 1re année, internationaux, rentrées 2026-2027", "first-year tuition only, international, 2026-2027 intakes"
SEN_DIP_FR = "Anglais : IELTS 6.0 (aucune compétence sous 5.5), TOEFL 4 sur 6 dans chaque compétence, Duolingo 105 à 110, PTE 58"
SEN_DIP_EN = "English: IELTS 6.0 (no skill below 5.5), TOEFL 4 out of 6 in each skill, Duolingo 105 to 110, PTE 58"
SEN_GC_FR = "Anglais : IELTS 6.5 (aucune compétence sous 6.0), TOEFL 4.5 sur 6 dans chaque compétence, Duolingo 120 à 125, PTE 60"
SEN_GC_EN = "English: IELTS 6.5 (no skill below 6.0), TOEFL 4.5 out of 6 in each skill, Duolingo 120 to 125, PTE 60"
I.append(inst(
    id="na-ca-seneca", countryId="can", nameFr="Seneca Polytechnic", nameEn="Seneca Polytechnic", acronym="Seneca",
    institutionType="college_public", consultedAt=C2,
    locationFr="Toronto, Ontario", locationEn="Toronto, Ontario", websiteUrl="https://www.senecapolytechnic.ca/",
    sourceUrl="https://www.senecapolytechnic.ca/international/fees/tuition.html",
    overviewFr="Collège polytechnique public de Toronto (campus Newnham pour l'informatique). Pour les internationaux, plusieurs programmes ouvrent en janvier et en mai 2027 ; les rentrées de septembre 2027 n'étaient pas encore publiées le 17/10/2026. Si ton anglais est insuffisant, tu peux recevoir une admission conditionnelle et commencer par l'English Language Institute (ELI) : une fois le niveau 8 réussi (60 % pour un diplôme), tu entres dans ton programme sans nouveau test.",
    overviewEn="Public polytechnic in Toronto (Newnham campus for computing). For international students, several programmes start in January and May 2027; September 2027 intakes were not yet published on 17/10/2026. If your English is not strong enough, you can receive conditional acceptance and start with the English Language Institute (ELI): once you pass Level 8 (60% for a diploma), you enter your programme with no new test.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL 4 sur 6 par compétence, Duolingo 105 à 110 ou PTE 58 pour les diplômes ; IELTS 6.5 et Duolingo 115 à 120 pour les baccalauréats, 120 à 125 pour les certificats postdiplôme",
    languageRequirementsEn="English: IELTS 6.0, TOEFL 4 out of 6 per skill, Duolingo 105 to 110 or PTE 58 for diplomas; IELTS 6.5 and Duolingo 115 to 120 for degrees, 120 to 125 for graduate certificates",
    languagePathway=pathway("English Language Institute (ELI)", "English Language Institute (ELI)",
                            "8 niveaux de 7 semaines ; admission conditionnelle, niveau 8 réussi à 60 % pour un diplôme", "8 levels of 7 weeks; conditional acceptance, Level 8 passed with 60% for a diploma",
                            "3 269,25 CAD de frais de scolarité par niveau de 7 semaines (hors frais annexes)", "CAD 3,269.25 tuition per 7-week level (before ancillary fees)",
                            "https://www.senecapolytechnic.ca/international/eli/fees-expenses.html"),
    applicationFee={"amount": 90, "currency": "CAD"}, applicationFeeFr="90 CAD, reversés sur ton compte étudiant après l'acceptation et le paiement du 1er semestre", applicationFeeEn="CAD 90, credited to your student account after acceptance and first-semester payment",
    tuitionLabelFr="≈ 16 809 – 22 064 CAD de frais de scolarité en 1re année selon le programme (internationaux, hors frais annexes, 2026-2027)",
    tuitionLabelEn="≈ CAD 16,809 – 22,064 first-year tuition by programme (international, before ancillary fees, 2026-2027)",
    intakePeriods=["Janvier 2027", "Mai 2027"], teachingLanguages=["en"],
    programs=[
        prog("computer-programming", "Computer Programming (CPP)", "Computer Programming (CPP)", "Diplôme collégial", "d01", "en", "4 semestres (2 ans), diplôme de l'Ontario", "4 semesters (2 years), Ontario College Diploma",
             cad(16989, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/CPP.html",
             [SEN_DIP_FR, pgwp("11.0201")[0], "Format hybride au campus Newnham"], [SEN_DIP_EN, pgwp("11.0201")[1], "Hybrid delivery at Newnham Campus"],
             offs(("Newnham", "01/2027"), ("Newnham", "05/2027"))),
        prog("computer-programming-analysis", "Computer Programming & Analysis (CPA)", "Computer Programming & Analysis (CPA)", "Diplôme collégial", "d01", "en", "6 semestres (3 ans), diplôme avancé de l'Ontario", "6 semesters (3 years), Ontario College Advanced Diploma",
             cad(16809, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/CPA.html",
             [SEN_DIP_FR, pgwp("11.0201")[0]], [SEN_DIP_EN, pgwp("11.0201")[1]],
             offs(("Newnham", "01/2027"), ("Newnham", "05/2027"))),
        prog("computer-engineering-technology", "Computer Engineering Technology (ECT)", "Computer Engineering Technology (ECT)", "Diplôme collégial", "d03", "en", "6 semestres (3 ans), diplôme avancé de l'Ontario", "6 semesters (3 years), Ontario College Advanced Diploma",
             cad(16809, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/ECT.html",
             [SEN_DIP_FR, pgwp("15.1201")[0]], [SEN_DIP_EN, pgwp("15.1201")[1]],
             offs(("Newnham", "01/2027"), ("Newnham", "05/2027"))),
        prog("artificial-intelligence", "Artificial Intelligence (AIG)", "Artificial Intelligence (AIG)", "Graduate certificate", "d01", "en", "2 semestres (8 mois), certificat postdiplôme de l'Ontario", "2 semesters (8 months), Ontario College Graduate Certificate",
             cad(22064, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/AIG.html",
             [SEN_GC_FR, pgwp("11.0102")[0], "Rentrée internationale ouverte : janvier 2027"], [SEN_GC_EN, pgwp("11.0102")[1], "International intake open: January 2027"]),
        prog("cybersecurity-threat-management", "Cybersecurity & Threat Management (CYT)", "Cybersecurity & Threat Management (CYT)", "Graduate certificate", "d01", "en", "2 semestres (8 mois), certificat postdiplôme de l'Ontario", "2 semesters (8 months), Ontario College Graduate Certificate",
             cad(17019, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/CYT.html",
             [SEN_GC_FR, pgwp("11.1003")[0]], [SEN_GC_EN, pgwp("11.1003")[1]],
             offs(("Newnham", "01/2027"), ("Newnham", "05/2027"))),
        prog("bachelor-engineering-software-engineering", "Bachelor of Engineering (Software Engineering)", "Bachelor of Engineering (Software Engineering)", "Bachelor", "d03", "en", "8 semestres (4 ans)", "8 semesters (4 years)",
             cad(19691, SEN_FEE_FR, SEN_FEE_EN), "https://www.senecapolytechnic.ca/programs/fulltime/BSA.html",
             ["Anglais : IELTS 6.5 (aucune compétence sous 6.0), TOEFL 4.5 sur 6 par compétence, Duolingo 115 à 120, PTE 60", pgwp("14.0903")[0], "Rentrée internationale ouverte : janvier 2027"],
             ["English: IELTS 6.5 (no skill below 6.0), TOEFL 4.5 out of 6 per skill, Duolingo 115 to 120, PTE 60", pgwp("14.0903")[1], "International intake open: January 2027"]),
    ]))

# ── Ontario : Conestoga College ──
CON_FEE_FR, CON_FEE_EN = "2 trimestres, frais de scolarité et frais annexes, internationaux, 2026-2027", "2 terms, tuition and ancillary fees, international, 2026-2027"
CON_DIP_FR = "Anglais : IELTS 6.0 (aucune bande sous 5.5), TOEFL 4.5 (2026) ou 80, Duolingo 110, PTE 53"
CON_DIP_EN = "English: IELTS 6.0 (no band below 5.5), TOEFL 4.5 (2026) or 80, Duolingo 110, PTE 53"
CON_DEG_FR = "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL 5 (2026) ou 88, Duolingo 120, PTE 58"
CON_DEG_EN = "English: IELTS 6.5 (no band below 6.0), TOEFL 5 (2026) or 88, Duolingo 120, PTE 58"
CON_AD_FR = "Rentrées de janvier et mai en format accéléré (« AD — Accelerated Delivery »)"
CON_AD_EN = "January and May intakes in accelerated delivery (\"AD\")"
I.append(inst(
    id="na-ca-conestoga", countryId="can", nameFr="Conestoga College", nameEn="Conestoga College", acronym="Conestoga",
    institutionType="college_public", consultedAt=C2,
    locationFr="Kitchener-Waterloo, Ontario", locationEn="Kitchener-Waterloo, Ontario", websiteUrl="https://www.conestogac.on.ca/",
    sourceUrl="https://www.conestogac.on.ca/international/apply-to-conestoga/admission-requirements",
    overviewFr="Collège public de la région de Kitchener-Waterloo (campus de Waterloo pour l'informatique, Cambridge pour l'ingénierie). Chaque fiche de programme publie le coût exact d'une année de deux trimestres pour les internationaux, frais annexes compris. Si ton anglais ne permet pas l'entrée directe, tu peux commencer par le programme English Language Studies du collège.",
    overviewEn="Public college in the Kitchener-Waterloo region (Waterloo campus for computing, Cambridge for engineering). Each programme page publishes the exact cost of a two-term year for international students, ancillary fees included. If your English does not allow direct entry, you can start with the college's English Language Studies programme.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL 4.5 (2026) ou 80, Duolingo 110 ou PTE 53 pour les diplômes ; IELTS 6.5, TOEFL 5 ou 88, Duolingo 120 ou PTE 58 pour les baccalauréats et certificats postdiplôme (plus élevé pour certains programmes d'informatique et d'ingénierie)",
    languageRequirementsEn="English: IELTS 6.0, TOEFL 4.5 (2026) or 80, Duolingo 110 or PTE 53 for diplomas; IELTS 6.5, TOEFL 5 or 88, Duolingo 120 or PTE 58 for degrees and graduate certificates (higher for some IT and engineering programmes)",
    languagePathway=pathway("General Arts and Science – English Language Studies", "General Arts and Science – English Language Studies",
                            "1 an (2 trimestres), rentrées en janvier, mai et septembre", "1 year (2 terms), January, May and September intakes",
                            "11 330 CAD de frais de scolarité (14 346 CAD avec frais annexes) pour 2 trimestres, 2026-2027", "CAD 11,330 tuition (CAD 14,346 with ancillary fees) for 2 terms, 2026-2027",
                            "https://www.conestogac.on.ca/fulltime/general-arts-and-science-english-language-studies"),
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 18 226 – 21 041 CAD par année de 2 trimestres selon le programme (internationaux, frais annexes compris, 2026-2027) ; dépôt non remboursable de 2 500 CAD",
    tuitionLabelEn="≈ CAD 18,226 – 21,041 per 2-term year by programme (international, ancillary fees included, 2026-2027); CAD 2,500 non-refundable deposit",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("computer-programming", "Computer Programming", "Computer Programming", "Diplôme collégial", "d01", "en", "2 ans (diplôme de l'Ontario)", "2 years (Ontario College Diploma)",
             cad(18226.26, CON_FEE_FR, CON_FEE_EN), "https://www.conestogac.on.ca/fulltime/computer-programming",
             [CON_DIP_FR, CON_AD_FR], [CON_DIP_EN, CON_AD_EN],
             offs(("Waterloo", "01/2027"), ("Waterloo", "05/2027"), ("Waterloo", "09/2027"))),
        prog("computer-programming-and-analysis", "Computer Programming and Analysis", "Computer Programming and Analysis", "Diplôme collégial", "d01", "en", "3 ans (diplôme avancé de l'Ontario), stage coop facultatif", "3 years (Ontario College Advanced Diploma), optional co-op",
             cad(18226.26, CON_FEE_FR, CON_FEE_EN), "https://www.conestogac.on.ca/fulltime/computer-programming-and-analysis",
             [CON_DIP_FR, CON_AD_FR], [CON_DIP_EN, CON_AD_EN],
             offs(("Waterloo", "01/2027"), ("Waterloo", "05/2027"), ("Waterloo", "09/2027"))),
        prog("cybersecurity-response-planning", "Cybersecurity Response Planning", "Cybersecurity Response Planning", "Graduate certificate", "d01", "en", "1 an (2 trimestres + 1 trimestre coop facultatif), certificat postdiplôme de l'Ontario", "1 year (2 academic terms + 1 optional co-op term), Ontario College Graduate Certificate",
             cad(19558.06, CON_FEE_FR, CON_FEE_EN), "https://www.conestogac.on.ca/fulltime/cybersecurity-response-planning",
             [CON_DEG_FR], [CON_DEG_EN],
             offs(("Waterloo", "01/2027"), ("Waterloo", "09/2027"))),
        prog("applied-artificial-intelligence-machine-learning", "Applied Artificial Intelligence and Machine Learning", "Applied Artificial Intelligence and Machine Learning", "Graduate certificate", "d01", "en", "1 an (2 trimestres + 1 trimestre coop facultatif), certificat postdiplôme de l'Ontario", "1 year (2 academic terms + 1 optional co-op term), Ontario College Graduate Certificate",
             cad(19907.86, "2 trimestres sans coop, frais annexes compris, internationaux, 2026-2027", "2 terms without co-op, ancillary fees included, international, 2026-2027"), "https://www.conestogac.on.ca/fulltime/applied-artificial-intelligence-machine-learning",
             [CON_DEG_FR, "Rentrée internationale ouverte : septembre 2027 (janvier et mai suspendus)"], [CON_DEG_EN, "International intake open: September 2027 (January and May suspended)"]),
        prog("bachelor-of-computer-science-honours", "Bachelor of Computer Science (Honours)", "Bachelor of Computer Science (Honours)", "Bachelor", "d01", "en", "4 ans, dont 2 stages coop rémunérés", "4 years, including two paid co-op terms",
             cad(20176.18, CON_FEE_FR, CON_FEE_EN), "https://www.conestogac.on.ca/fulltime/bachelor-of-computer-science-honours",
             [CON_DEG_FR], [CON_DEG_EN],
             offs(("Waterloo", "01/2027"), ("Waterloo", "09/2027"))),
        prog("bachelor-of-engineering-mechanical-systems-engineering", "Bachelor of Engineering - Mechanical Systems Engineering", "Bachelor of Engineering - Mechanical Systems Engineering", "Bachelor", "d03", "en", "4 ans", "4 years",
             cad(21041.42, CON_FEE_FR, CON_FEE_EN), "https://www.conestogac.on.ca/fulltime/bachelor-of-engineering-mechanical-systems-engineering",
             [CON_DEG_FR, "Rentrée d'août 2027 au campus de Cambridge (Fountain Street) ; 1re année commune à tous les baccalauréats en génie"], [CON_DEG_EN, "August 2027 start at Cambridge (Fountain Street) campus; common first year across all engineering degrees"]),
    ]))

# ── Ontario : Centennial College ──
CEN_FEE_FR, CEN_FEE_EN = "2 semestres dès l'automne 2026, frais de scolarité et frais annexes, internationaux", "2 semesters from fall 2026, tuition and ancillary fees, international"
CEN_DIP_FR = "Anglais : IELTS 6.0 (aucune bande sous 5.5), TOEFL iBT 67, Duolingo 105 à 114, PTE 51 pour les programmes débutant en COMM 160"
CEN_DIP_EN = "English: IELTS 6.0 (no band below 5.5), TOEFL iBT 67, Duolingo 105 to 114, PTE 51 for programmes starting at COMM 160"
CEN_ADV_FR = "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL iBT 81, Duolingo 125, PTE 58 à 60 pour les diplômes avancés débutant en COMM 170 et les certificats postdiplôme (voir la fiche du programme)"
CEN_ADV_EN = "English: IELTS 6.5 (no band below 6.0), TOEFL iBT 81, Duolingo 125, PTE 58 to 60 for advanced diplomas starting at COMM 170 and graduate certificates (see the programme page)"
I.append(inst(
    id="na-ca-centennial", countryId="can", nameFr="Centennial College", nameEn="Centennial College", acronym="Centennial",
    institutionType="college_public", consultedAt=C2,
    locationFr="Toronto, Ontario", locationEn="Toronto, Ontario", websiteUrl="https://www.centennialcollege.ca/",
    sourceUrl="https://www.centennialcollege.ca/international-education/how-to-apply-to-centennial-college",
    overviewFr="Collège public de Toronto (campus Progress pour l'informatique et l'ingénierie, Morningside pour la santé). La plupart des programmes retenus ouvrent en janvier et en septembre, certains aussi en mai. Si ton anglais est insuffisant, le programme English Language Learning (ELL) du collège te prépare : le niveau 5 réussi à 60 % te donne accès à la plupart des programmes sans nouveau test.",
    overviewEn="Public college in Toronto (Progress campus for computing and engineering, Morningside for health). Most programmes listed here start in January and September, some also in May. If your English is not strong enough, the college's English Language Learning (ELL) programme prepares you: passing Level 5 with 60% gives access to most programmes with no new test.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL iBT 67, Duolingo 105 à 114 pour les certificats et diplômes ; IELTS 6.5, TOEFL iBT 81, Duolingo 125 pour les diplômes avancés « COMM 170 », les certificats postdiplôme et les baccalauréats",
    languageRequirementsEn="English: IELTS 6.0, TOEFL iBT 67, Duolingo 105 to 114 for certificates and diplomas; IELTS 6.5, TOEFL iBT 81, Duolingo 125 for \"COMM 170\" advanced diplomas, graduate certificates and degrees",
    languagePathway=pathway("English Language Learning (ELL)", "English Language Learning (ELL)",
                            "jusqu'à 5 niveaux, semestres de 15 semaines ; niveau 5 réussi à 60 % (80 % pour un certificat postdiplôme)", "up to 5 levels, 15-week semesters; Level 5 passed with 60% (80% for a graduate certificate)",
                            "4 397,50 CAD de frais de scolarité par semestre de 15 semaines (barème dès l'automne 2025)", "CAD 4,397.50 tuition per 15-week semester (rates from fall 2025)",
                            "https://www.centennialcollege.ca/programs-courses/full-time/english-language-learning"),
    applicationFee={"amount": 125, "currency": "CAD"}, applicationFeeFr="125 CAD", applicationFeeEn="CAD 125",
    tuitionLabelFr="≈ 20 611 – 21 382 CAD par année de 2 semestres selon le programme (internationaux, frais annexes compris, dès l'automne 2026) ; dépôt d'inscription de 2 000 CAD",
    tuitionLabelEn="≈ CAD 20,611 – 21,382 per 2-semester year by programme (international, ancillary fees included, from fall 2026); CAD 2,000 registration deposit",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("software-engineering-technician", "Software Engineering Technician", "Software Engineering Technician", "Diplôme collégial", "d01", "en", "2 ans / 4 semestres (diplôme de l'Ontario)", "2 years / 4 semesters (Ontario College Diploma)",
             cad(21381.72, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/software-engineering-technician",
             [CEN_DIP_FR, pgwp("15.1204")[0]], [CEN_DIP_EN, pgwp("15.1204")[1]],
             offs(("Progress", "01/2027"), ("Progress", "09/2027"))),
        prog("software-engineering-technology", "Software Engineering Technology (Optional Co-op)", "Software Engineering Technology (Optional Co-op)", "Diplôme collégial", "d01", "en", "3 ans / 6 semestres (diplôme avancé de l'Ontario)", "3 years / 6 semesters (Ontario College Advanced Diploma)",
             cad(21381.72, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/software-engineering-technology",
             [CEN_ADV_FR, pgwp("15.1204")[0]], [CEN_ADV_EN, pgwp("15.1204")[1]],
             offs(("Progress", "01/2027"), ("Progress", "09/2027"))),
        prog("artificial-intelligence-software-engineering-technology", "Artificial Intelligence - Software Engineering Technology (Optional Co-op)", "Artificial Intelligence - Software Engineering Technology (Optional Co-op)", "Diplôme collégial", "d01", "en", "3 ans / 6 semestres (diplôme avancé de l'Ontario)", "3 years / 6 semesters (Ontario College Advanced Diploma)",
             cad(21293.72, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/artificial-intelligence",
             [CEN_ADV_FR, pgwp("11.0102")[0]], [CEN_ADV_EN, pgwp("11.0102")[1]],
             offs(("Progress", "01/2027"), ("Progress", "05/2027"), ("Progress", "09/2027"))),
        prog("mechanical-engineering-technology-design", "Mechanical Engineering Technology - Design and Industrial (Optional Co-op)", "Mechanical Engineering Technology - Design and Industrial (Optional Co-op)", "Diplôme collégial", "d03", "en", "3 ans / 6 semestres (diplôme avancé de l'Ontario)", "3 years / 6 semesters (Ontario College Advanced Diploma)",
             cad(21373.72, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/mechanical-engineering-technology-design",
             [CEN_ADV_FR, pgwp("15.0805")[0]], [CEN_ADV_EN, pgwp("15.0805")[1]],
             offs(("Progress", "01/2027"), ("Progress", "09/2027"))),
        prog("practical-nursing", "Practical Nursing", "Practical Nursing", "Diplôme collégial", "d04", "en", "2 ans / 4 semestres (diplôme de l'Ontario)", "2 years / 4 semesters (Ontario College Diploma)",
             cad(20611.12, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/practical-nursing",
             ["Exigences d'anglais propres au programme (plus élevées), voir la fiche", pgwp("51.3901")[0]], ["Programme-specific (higher) English requirements, see the programme page", pgwp("51.3901")[1]],
             offs(("Morningside", "01/2027"), ("Morningside", "09/2027"))),
        prog("cybersecurity", "Cybersecurity", "Cybersecurity", "Graduate certificate", "d01", "en", "1 an / 2 semestres (certificat postdiplôme de l'Ontario)", "1 year / 2 semesters (Ontario College Graduate Certificate)",
             cad(21101.41, CEN_FEE_FR, CEN_FEE_EN), "https://www.centennialcollege.ca/programs-courses/full-time/cybersecurity",
             [CEN_ADV_FR, pgwp("11.1003")[0], "Rentrée internationale ouverte : septembre 2027"], [CEN_ADV_EN, pgwp("11.1003")[1], "International intake open: September 2027"]),
    ]))

# ── Ontario : Fanshawe College ──
FAN_FEE_FR, FAN_FEE_EN = "2 trimestres, frais de scolarité et frais obligatoires, internationaux, 2026-2027", "2 terms, tuition and mandatory fees, international, 2026-2027"
FAN_DIP_FR = "Anglais : IELTS 6.0 (aucune bande sous 5.5), TOEFL iBT 4.5 (2026) ou 79, Duolingo 105 (aucun score sous 95), PTE 53"
FAN_DIP_EN = "English: IELTS 6.0 (no band below 5.5), TOEFL iBT 4.5 (2026) or 79, Duolingo 105 (no score below 95), PTE 53"
FAN_GC_FR = "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL iBT 5, Duolingo 120 (aucun score sous 105), PTE 58"
FAN_GC_EN = "English: IELTS 6.5 (no band below 6.0), TOEFL iBT 5, Duolingo 120 (no score below 105), PTE 58"
I.append(inst(
    id="na-ca-fanshawe", countryId="can", nameFr="Fanshawe College", nameEn="Fanshawe College", acronym="Fanshawe",
    institutionType="college_public", consultedAt=C2,
    locationFr="London, Ontario", locationEn="London, Ontario", websiteUrl="https://www.fanshawec.ca/",
    sourceUrl="https://www.fanshawec.ca/international/applicants/international-tuition-fees",
    overviewFr="Collège public de London (Ontario). Les certificats postdiplôme en intelligence artificielle et en analyse de données ouvrent en janvier, mai et septembre ; les diplômes avancés en janvier et septembre. Fanshawe propose un programme English for Academic Purposes (EAP) en 10 niveaux ; avec les écoles de langue partenaires, une lettre d'admission conditionnelle peut t'être délivrée si tu remplis les autres conditions.",
    overviewEn="Public college in London, Ontario. Graduate certificates in artificial intelligence and data analytics start in January, May and September; advanced diplomas in January and September. Fanshawe offers a 10-level English for Academic Purposes (EAP) programme; with partner language schools, a conditional letter of admission can be issued if you meet the other requirements.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL iBT 4.5 (2026) ou 79, Duolingo 105 ou PTE 53 pour les diplômes ; IELTS 6.5, TOEFL 5, Duolingo 120 ou PTE 58 pour les certificats postdiplôme",
    languageRequirementsEn="English: IELTS 6.0, TOEFL iBT 4.5 (2026) or 79, Duolingo 105 or PTE 53 for diplomas; IELTS 6.5, TOEFL 5, Duolingo 120 or PTE 58 for graduate certificates",
    languagePathway=pathway("English for Academic Purposes (EAP)", "English for Academic Purposes (EAP)",
                            "10 niveaux de 8 semaines (2 niveaux par semestre)", "10 levels of 8 weeks (2 levels per semester)",
                            "3 411,36 CAD de frais de scolarité par niveau (4 011,43 CAD avec frais annexes), 2026-2027", "CAD 3,411.36 tuition per level (CAD 4,011.43 with ancillary fees), 2026-2027",
                            "https://www.fanshawec.ca/international/applicants/eap"),
    applicationFee={"amount": 100, "currency": "CAD"}, applicationFeeFr="dépôt de 100 CAD avec la candidature, déduit des frais de scolarité", applicationFeeEn="CAD 100 deposit with the application, applied to tuition",
    tuitionLabelFr="≈ 18 212 – 18 920 CAD par année de 2 trimestres selon le programme (internationaux, 2026-2027)",
    tuitionLabelEn="≈ CAD 18,212 – 18,920 per 2-term year by programme (international, 2026-2027)",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("cpa3-computer-programming-and-analysis-co-op", "Computer Programming and Analysis (Co-op)", "Computer Programming and Analysis (Co-op)", "Diplôme collégial", "d01", "en", "90 semaines (diplôme avancé de l'Ontario), stage coop rémunéré", "90 weeks (Ontario College Advanced Diploma), paid co-op",
             cad(9105.84 * 2, FAN_FEE_FR, FAN_FEE_EN), "https://www.fanshawec.ca/programs/cpa3-computer-programming-and-analysis-co-op/next",
             [FAN_DIP_FR], [FAN_DIP_EN],
             offs(("London", "01/2027"), ("London", "09/2027"))),
        prog("cyb1-cyber-security-co-op", "Cyber Security (Co-op)", "Cyber Security (Co-op)", "Diplôme collégial", "d01", "en", "90 semaines (diplôme avancé de l'Ontario)", "90 weeks (Ontario College Advanced Diploma)",
             cad(9105.84 * 2, FAN_FEE_FR, FAN_FEE_EN), "https://www.fanshawec.ca/programs/cyb1-cyber-security-co-op/next",
             [FAN_DIP_FR], [FAN_DIP_EN],
             offs(("London", "01/2027"), ("London", "09/2027"))),
        prog("aim1-artificial-intelligence-and-machine-learning", "Artificial Intelligence and Machine Learning", "Artificial Intelligence and Machine Learning", "Graduate certificate", "d01", "en", "45 semaines (certificat postdiplôme de l'Ontario, 3 trimestres)", "45 weeks (Ontario College Graduate Certificate, 3 terms)",
             cad(9459.96 * 2, FAN_FEE_FR, FAN_FEE_EN), "https://www.fanshawec.ca/programs/aim1-artificial-intelligence-and-machine-learning/next",
             [FAN_GC_FR], [FAN_GC_EN],
             offs(("London", "01/2027"), ("London", "05/2027"), ("London", "09/2027"))),
        prog("daa1-data-analytics", "Data Analytics", "Data Analytics", "Graduate certificate", "d01", "en", "30 semaines (certificat postdiplôme de l'Ontario, 2 trimestres)", "30 weeks (Ontario College Graduate Certificate, 2 terms)",
             cad(9303.66 * 2, FAN_FEE_FR, FAN_FEE_EN), "https://www.fanshawec.ca/programs/daa1-data-analytics/next",
             [FAN_GC_FR], [FAN_GC_EN],
             offs(("London", "01/2027"), ("London", "05/2027"), ("London", "09/2027"))),
    ]))

# ── Ontario : Sheridan College ──
SHE_FEE_FR, SHE_FEE_EN = "2 premiers semestres, scolarité, assurance santé et frais annexes, internationaux, 2026-2027", "first 2 semesters, tuition, health insurance and ancillary fees, international, 2026-2027"
SHE_DIP_FR = "Anglais : IELTS 6.0 (aucune bande sous 5.5), TOEFL iBT 4 (2026) ou 80, Duolingo 105, PTE 58"
SHE_DIP_EN = "English: IELTS 6.0 (no band below 5.5), TOEFL iBT 4 (2026) or 80, Duolingo 105, PTE 58"
SHE_DEG_FR = "Anglais : IELTS 6.5 (aucune bande sous 6.0), TOEFL iBT 4.5 (2026) ou 88, Duolingo 115, PTE 60"
SHE_DEG_EN = "English: IELTS 6.5 (no band below 6.0), TOEFL iBT 4.5 (2026) or 88, Duolingo 115, PTE 60"
SHE_PGWP_FR, SHE_PGWP_EN = "Programme aligné sur le PGWP selon Sheridan", "PGWP-aligned programme according to Sheridan"
I.append(inst(
    id="na-ca-sheridan", countryId="can", nameFr="Sheridan College", nameEn="Sheridan College", acronym="Sheridan",
    institutionType="college_public", consultedAt=C2,
    locationFr="Oakville, Ontario", locationEn="Oakville, Ontario", websiteUrl="https://www.sheridancollege.ca/",
    sourceUrl="https://www.sheridancollege.ca/admissions/how-to-apply/admission-requirements/english-language",
    overviewFr="Collège public de la région de Toronto (campus Trafalgar à Oakville, Davis à Brampton, Hazel McCallion à Mississauga). Les prix publiés pour 2026-2027 incluent l'assurance santé et les frais annexes. Si ton anglais n'est pas encore au niveau, ta lettre d'offre peut indiquer ton niveau de placement dans le programme English for Academic Purposes (EAP) de Sheridan, à réussir avant ton programme.",
    overviewEn="Public college in the Toronto region (Trafalgar campus in Oakville, Davis in Brampton, Hazel McCallion in Mississauga). Published 2026-2027 prices include health insurance and ancillary fees. If your English is not yet at the required level, your offer letter can show your placement level in Sheridan's English for Academic Purposes (EAP) programme, to pass before your programme.",
    languageRequirementsFr="Anglais : IELTS 6.0, TOEFL iBT 4 (2026) ou 80, Duolingo 105 ou PTE 58 pour les certificats et diplômes ; IELTS 6.5, TOEFL iBT 4.5 ou 88, Duolingo 115 ou PTE 60 pour les baccalauréats et certificats postdiplôme",
    languageRequirementsEn="English: IELTS 6.0, TOEFL iBT 4 (2026) or 80, Duolingo 105 or PTE 58 for certificates and diplomas; IELTS 6.5, TOEFL iBT 4.5 or 88, Duolingo 115 or PTE 60 for degrees and graduate certificates",
    languagePathway=pathway("English for Academic Purposes (EAP)", "English for Academic Purposes (EAP)",
                            "5 niveaux de 14 semaines ; niveau 5 réussi à 70 % (diplômes) ou 75 % (baccalauréats)", "5 levels of 14 weeks; Level 5 passed with 70% (diplomas) or 75% (degrees)",
                            "16 836,44 CAD pour 2 semestres (internationaux, 2026-2027)", "CAD 16,836.44 for 2 semesters (international, 2026-2027)",
                            "https://www.sheridancollege.ca/programs/english-for-academic-purposes"),
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 19 700 – 25 792 CAD pour les 2 premiers semestres selon le programme (internationaux, assurance et frais compris, 2026-2027)",
    tuitionLabelEn="≈ CAD 19,700 – 25,792 for the first 2 semesters by programme (international, insurance and fees included, 2026-2027)",
    intakePeriods=["Janvier 2027", "Mai 2027", "Septembre 2027"], teachingLanguages=["en"],
    programs=[
        prog("computer-programming", "Computer Programming", "Computer Programming", "Diplôme collégial", "d01", "en", "2 ans (diplôme de l'Ontario)", "2 years (Ontario College Diploma)",
             cad(19700.40, SHE_FEE_FR, SHE_FEE_EN), "https://www.sheridancollege.ca/programs/computer-programming",
             [SHE_DIP_FR, SHE_PGWP_FR], [SHE_DIP_EN, SHE_PGWP_EN],
             offs(("Davis (Brampton)", "01/2027"), ("Trafalgar (Oakville)", "01/2027"), ("Trafalgar (Oakville)", "05/2027"), ("Davis (Brampton)", "09/2027"), ("Trafalgar (Oakville)", "09/2027"))),
        prog("computer-systems-technology-software-development-network-engineering", "Computer Systems Technology – Software Development and Network Engineering", "Computer Systems Technology – Software Development and Network Engineering", "Diplôme collégial", "d01", "en", "3 ans (diplôme avancé de l'Ontario)", "3 years (Ontario College Advanced Diploma)",
             None, "https://www.sheridancollege.ca/programs/computer-systems-technology-software-development-and-network-engineering",
             [SHE_DIP_FR, SHE_PGWP_FR], [SHE_DIP_EN, SHE_PGWP_EN],
             offs(("Davis (Brampton)", "01/2027"), ("Trafalgar (Oakville)", "01/2027"), ("Trafalgar (Oakville)", "05/2027"), ("Davis (Brampton)", "09/2027"), ("Trafalgar (Oakville)", "09/2027"))),
        prog("practical-nursing", "Practical Nursing", "Practical Nursing", "Diplôme collégial", "d04", "en", "2 ans (diplôme de l'Ontario)", "2 years (Ontario College Diploma)",
             cad(25792.43, SHE_FEE_FR, SHE_FEE_EN), "https://www.sheridancollege.ca/programs/practical-nursing",
             [SHE_PGWP_FR, "Rentrée de janvier 2027 fermée aux internationaux"], [SHE_PGWP_EN, "January 2027 intake closed to international students"],
             offs(("Davis (Brampton)", "05/2027"), ("Davis (Brampton)", "09/2027"))),
        prog("honours-bachelor-computer-science", "Honours Bachelor of Computer Science", "Honours Bachelor of Computer Science", "Bachelor", "d01", "en", "4 ans, stage coop ou en entreprise", "4 years, co-op or internship",
             cad(23010.21, SHE_FEE_FR, SHE_FEE_EN), "https://www.sheridancollege.ca/programs/bachelor-computer-science",
             [SHE_DEG_FR, SHE_PGWP_FR, "Spécialisation au choix (plusieurs codes de programme)"], [SHE_DEG_EN, SHE_PGWP_EN, "Choice of specialization (several programme codes)"],
             offs(("Trafalgar (Oakville)", "01/2027"), ("Trafalgar (Oakville)", "09/2027"))),
        prog("bachelor-cyber-security", "Bachelor of Cyber Security", "Bachelor of Cyber Security", "Bachelor", "d01", "en", "4 ans (baccalauréat spécialisé)", "4 years (Honours Baccalaureate Degree)",
             cad(23823.27, SHE_FEE_FR, SHE_FEE_EN), "https://www.sheridancollege.ca/programs/bachelor-information-sciences-cyber-security",
             [SHE_DEG_FR, SHE_PGWP_FR], [SHE_DEG_EN, SHE_PGWP_EN],
             offs(("Davis (Brampton)", "01/2027"), ("Trafalgar (Oakville)", "01/2027"), ("Trafalgar (Oakville)", "09/2027"))),
    ]))

# ── Québec : réseau de l'Université du Québec ──
uqtr = lambda total, code: cad(total * 2, f"2 trimestres de 15 crédits, frais compris, calculette officielle de l'UQTR, automne 2026, programme {code}", f"2 terms of 15 credits, fees included, UQTR official calculator, fall 2026, programme {code}")
UQTR_FR = ["Diplôme d'études collégiales (DEC) ou l'équivalent (études hors Québec : voir les conditions du programme)", "Ta lettre d'admission indique si tu dois passer le Test institutionnel de français pour étudiants internationaux (TIFEI)", "Dates limites internationales : 1er avril (automne), 1er août (hiver)"]
UQTR_EN = ["Quebec college diploma (DEC) or equivalent (studies outside Quebec: see the programme requirements)", "Your letter of admission says whether you must take the UQTR French test for international students (TIFEI)", "International deadlines: 1 April (fall), 1 August (winter)"]
I.append(inst(
    id="na-ca-uqtr", countryId="can", nameFr="Université du Québec à Trois-Rivières (UQTR)", nameEn="Université du Québec à Trois-Rivières (UQTR)", acronym="UQTR",
    consultedAt=C2,
    locationFr="Trois-Rivières, Québec", locationEn="Trois-Rivières, Quebec", websiteUrl="https://www.uqtr.ca/",
    sourceUrl="https://oraprdnt.uqtr.uquebec.ca/portail/docs/GSC932/O0007294965_2027_2028___R_pertoire_International.pdf",
    overviewFr="Université francophone de Trois-Rivières, à mi-chemin entre Montréal et Québec, membre du réseau de l'Université du Québec ; elle compte 3 035 étudiants internationaux sur 15 129. Pour un baccalauréat à temps complet (15 crédits par trimestre), la calculette officielle estime un trimestre à environ 13 650 CAD pour un étudiant non canadien à l'automne 2026, frais compris. Pour l'automne 2027, la demande d'admission internationale se fait avant le 1er avril 2027.",
    overviewEn="French-language university in Trois-Rivières, halfway between Montreal and Quebec City, part of the Université du Québec network; it has 3,035 international students out of 15,129. For a full-time bachelor's (15 credits per term), the official calculator estimates a term at about CAD 13,650 for a non-Canadian student in fall 2026, fees included. For fall 2027, international applications are due by 1 April 2027.",
    languageRequirementsFr="Français : programmes enseignés en français ; ta lettre d'admission indique si tu dois passer le TIFEI (test institutionnel de français de l'UQTR)",
    languageRequirementsEn="French: programmes taught in French; your letter of admission says whether you must take the TIFEI (UQTR's French test)",
    applicationFee={"amount": 54.87, "currency": "CAD"}, applicationFeeFr="54,87 CAD", applicationFeeEn="CAD 54.87",
    tuitionLabelFr="≈ 27 300 CAD/an (2 trimestres de 15 crédits, frais compris, calculette officielle, automne 2026) ; 17 000 – 25 500 CAD/an selon le répertoire international 2027-2028",
    tuitionLabelEn="≈ CAD 27,300/year (2 terms of 15 credits, fees included, official calculator, fall 2026); CAD 17,000 – 25,500/year according to the 2027-2028 international directory",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "90 crédits", "90 credits",
             uqtr(13650.15, "7833"), "https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=7833",
             UQTR_FR + ["Admission à l'automne et à l'hiver ; programme non contingenté"], UQTR_EN + ["Fall and winter admission; open-enrolment programme"]),
        prog("baccalaureat-genie-informatique", "Baccalauréat en génie informatique", "Bachelor's in Computer Engineering (Baccalauréat en génie informatique)", "Bachelor", "d01", "fr", "4 ans (120 crédits)", "4 years (120 credits)",
             uqtr(13680.15, "6581"), "https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=6581",
             UQTR_FR + ["Admission à l'automne et à l'hiver ; programme non contingenté"], UQTR_EN + ["Fall and winter admission; open-enrolment programme"]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits",
             uqtr(13685.15, "7947"), "https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=7947",
             UQTR_FR + ["Admission à l'automne et à l'hiver ; programme non contingenté"], UQTR_EN + ["Fall and winter admission; open-enrolment programme"]),
        prog("baa-administration-affaires", "Baccalauréat en administration des affaires", "Bachelor of Business Administration (Baccalauréat en administration des affaires)", "Bachelor", "d02", "fr", "90 crédits", "90 credits",
             uqtr(13675.15, "7264"), "https://oraprdnt.uqtr.uquebec.ca/portail/triw082.afficher?owa_cd_pgm=7264",
             UQTR_FR + ["Admission à l'automne, à l'hiver et à l'été ; programme non contingenté"], UQTR_EN + ["Fall, winter and summer admission; open-enrolment programme"]),
    ]))

uqar = cad(24551.86, "1re année, 2 trimestres de 15 crédits, internationaux, montants indicatifs de l'automne 2026", "first year, 2 terms of 15 credits, international, indicative fall 2026 amounts")
UQAR_FR = ["Diplôme étranger : test de français à joindre à la demande (TEF ou TCF 460, ou Bright Language 3,5), puis examen de français de l'UQAR à l'arrivée", "Date limite internationale pour l'automne 2027 : 1er mars 2027"]
UQAR_EN = ["Foreign diploma: French test to attach to the application (TEF or TCF 460, or Bright Language 3.5), then the UQAR French exam on arrival", "International deadline for fall 2027: 1 March 2027"]
I.append(inst(
    id="na-ca-uqar", countryId="can", nameFr="Université du Québec à Rimouski (UQAR)", nameEn="Université du Québec à Rimouski (UQAR)", acronym="UQAR",
    consultedAt=C2,
    locationFr="Rimouski, Québec", locationEn="Rimouski, Quebec", websiteUrl="https://www.uqar.ca/",
    sourceUrl="https://www.uqar.ca/programmes-formations-et-admission/admission/etudiant-es-etrangers/admission-pour-etudiants-internationaux/",
    overviewFr="Université francophone de l'Est-du-Québec, membre du réseau de l'Université du Québec, avec deux campus : Rimouski et Lévis (face à la ville de Québec). Pour un baccalauréat à temps complet, l'UQAR indique environ 24 552 CAD pour la 1re année d'un étudiant international (montants indicatifs de l'automne 2026). Les demandes internationales pour l'hiver 2027 sont closes ; pour l'automne 2027, tu as jusqu'au 1er mars 2027.",
    overviewEn="French-language university in Eastern Quebec, part of the Université du Québec network, with two campuses: Rimouski and Lévis (across from Quebec City). For a full-time bachelor's, UQAR indicates about CAD 24,552 for an international student's first year (indicative fall 2026 amounts). International applications for winter 2027 are closed; for fall 2027, you have until 1 March 2027.",
    languageRequirementsFr="Français : avec un diplôme étranger, TEF ou TCF (seuil 460) ou Bright Language (3,5) à joindre à la demande, puis examen de français de l'UQAR au premier trimestre",
    languageRequirementsEn="French: with a foreign diploma, TEF or TCF (460) or Bright Language (3.5) to attach to the application, then the UQAR French exam in the first term",
    applicationFee={"amount": 90.28, "currency": "CAD"}, applicationFeeFr="90,28 CAD", applicationFeeEn="CAD 90.28",
    tuitionLabelFr="≈ 24 552 CAD en 1re année (2 trimestres de 15 crédits, internationaux, automne 2026), puis ≈ 25 288 CAD en 2e année",
    tuitionLabelEn="≈ CAD 24,552 in first year (2 terms of 15 credits, international, fall 2026), then ≈ CAD 25,288 in second year",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "90 crédits", "90 credits",
             uqar, "https://www.uqar.ca/programmes-domaines-detudes/baccalaureat-en-informatique/",
             UQAR_FR + ["Campus de Lévis et de Rimouski ; admission à l'automne ; programme contingenté"], UQAR_EN + ["Lévis and Rimouski campuses; fall admission; limited-enrolment programme"]),
        prog("baccalaureat-genie-electrique", "Baccalauréat en génie électrique", "Bachelor's in Electrical Engineering (Baccalauréat en génie électrique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits",
             uqar, "https://www.uqar.ca/etudes/etudier-a-l-uqar/programmes-d-etudes/79n4",
             UQAR_FR + ["Base DEC préuniversitaire ou l'équivalent ; admission à l'automne et à l'hiver"], UQAR_EN + ["Pre-university DEC or equivalent; fall and winter admission"]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits",
             uqar, "https://www.uqar.ca/etudes/etudier-a-l-uqar/programmes-d-etudes/79n7",
             UQAR_FR + ["Base DEC préuniversitaire ou l'équivalent ; admission à l'automne et à l'hiver"], UQAR_EN + ["Pre-university DEC or equivalent; fall and winter admission"]),
        prog("baccalaureat-administration", "Baccalauréat en administration", "Bachelor of Business Administration (Baccalauréat en administration)", "Bachelor", "d02", "fr", "90 crédits", "90 credits",
             uqar, "https://www.uqar.ca/etudes/etudier-a-l-uqar/programmes-d-etudes/7464",
             UQAR_FR + ["Campus de Lévis et de Rimouski ; admission à l'automne, à l'hiver et à l'été ; programme non contingenté"], UQAR_EN + ["Lévis and Rimouski campuses; fall, winter and summer admission; open-enrolment programme"]),
    ]))

uqo = cad(30 * 824.56, "30 crédits au tarif international du 1er cycle (droits et montant forfaitaire), automne 2026, hors frais afférents", "30 credits at the international undergraduate rate (tuition and lump sum), fall 2026, before related fees")
UQO_FR = ["Diplôme d'études collégiales (DEC) ou l'équivalent", "Maîtrise du français attestée par un test exigé par les universités francophones"]
UQO_EN = ["Quebec college diploma (DEC) or equivalent", "French proficiency attested by a test required by French-language universities"]
I.append(inst(
    id="na-ca-uqo", countryId="can", nameFr="Université du Québec en Outaouais (UQO)", nameEn="Université du Québec en Outaouais (UQO)", acronym="UQO",
    consultedAt=C2,
    locationFr="Gatineau, Québec", locationEn="Gatineau, Quebec", websiteUrl="https://uqo.ca/",
    sourceUrl="https://uqo.ca/frais-de-scolarite/etudiants-internationaux",
    overviewFr="Université francophone de Gatineau, en face d'Ottawa, membre du réseau de l'Université du Québec, avec un second campus à Saint-Jérôme. Au 1er cycle, un étudiant international paie 824,56 CAD par crédit en 2026-2027 (droits de scolarité et montant forfaitaire), plus les frais afférents. Depuis l'automne 2026, la totalité des frais d'un trimestre doit être payée avant son début.",
    overviewEn="French-language university in Gatineau, across from Ottawa, part of the Université du Québec network, with a second campus in Saint-Jérôme. At undergraduate level, an international student pays CAD 824.56 per credit in 2026-2027 (tuition and lump sum), plus related fees. Since fall 2026, a term's fees must be paid in full before it starts.",
    languageRequirementsFr="Français : maîtrise du français attestée (épreuve ministérielle, test du ministère ou tests exigés par les universités francophones)",
    languageRequirementsEn="French: attested French proficiency (ministry exam, ministry test or tests required by French-language universities)",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 24 737 CAD/an (30 crédits au tarif international du 1er cycle, 2026-2027, hors frais afférents)",
    tuitionLabelEn="≈ CAD 24,737/year (30 credits at the international undergraduate rate, 2026-2027, before related fees)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-informatique", "Baccalauréat en informatique", "Bachelor's in Computer Science (Baccalauréat en informatique)", "Bachelor", "d01", "fr", "90 crédits", "90 credits",
             uqo, "https://uqo.ca/programmes/7833",
             UQO_FR + ["Cours collégiaux de calcul différentiel, calcul intégral et algèbre linéaire (ou cours d'appoint)", "Campus de Gatineau et de Saint-Jérôme ; admission à l'automne et à l'hiver"],
             UQO_EN + ["College courses in differential calculus, integral calculus and linear algebra (or remedial courses)", "Gatineau and Saint-Jérôme campuses; fall and winter admission"]),
        prog("baccalaureat-genie-informatique", "Baccalauréat en génie informatique", "Bachelor's in Computer Engineering (Baccalauréat en génie informatique)", "Bachelor", "d01", "fr", "120 crédits", "120 credits",
             uqo, "https://uqo.ca/programmes/7643",
             UQO_FR + ["Campus de Gatineau ; admission à l'automne"], UQO_EN + ["Gatineau campus; fall admission"]),
        prog("baccalaureat-cybersecurite", "Baccalauréat en cybersécurité", "Bachelor's in Cybersecurity (Baccalauréat en cybersécurité)", "Bachelor", "d01", "fr", "90 crédits", "90 credits",
             uqo, "https://uqo.ca/programmes/6784",
             UQO_FR + ["Campus de Gatineau ; admission à l'automne et à l'hiver ; version coopérative contingentée"], UQO_EN + ["Gatineau campus; fall and winter admission; limited-enrolment co-op version"]),
        prog("baccalaureat-administration", "Baccalauréat en administration", "Bachelor of Business Administration (Baccalauréat en administration)", "Bachelor", "d02", "fr", "90 crédits", "90 credits",
             uqo, "https://uqo.ca/programmes/7127",
             UQO_FR + ["Campus de Gatineau ; admission à l'automne, à l'hiver et à l'été"], UQO_EN + ["Gatineau campus; fall, winter and summer admission"]),
    ]))

uqat = cad(30 * 807.68, "30 crédits au tarif international du 1er cycle (droits et montant forfaitaire), 2026-2027, hors frais afférents", "30 credits at the international undergraduate rate (tuition and lump sum), 2026-2027, before related fees")
UQAT_FR = ["Niveau de français : TFI, TCF, DELF, DALF ou TEF (C1 ou C2) acceptés ; sinon test à l'UQAT et cours de rattrapage au besoin", "Programme offert à temps complet aux internationaux"]
UQAT_EN = ["French level: TFI, TCF, DELF, DALF or TEF (C1 or C2) accepted; otherwise a test at UQAT and remedial courses if needed", "Programme open full-time to international students"]
UQAT_GENIE_FR = "Bourses de l'École de génie : pour les internationaux, jusqu'à 25 % des frais majorés la 1re année"
UQAT_GENIE_EN = "School of Engineering scholarships: for international students, up to 25% of the higher fees in the first year"
I.append(inst(
    id="na-ca-uqat", countryId="can", nameFr="Université du Québec en Abitibi-Témiscamingue (UQAT)", nameEn="Université du Québec en Abitibi-Témiscamingue (UQAT)", acronym="UQAT",
    consultedAt=C2,
    locationFr="Rouyn-Noranda, Québec", locationEn="Rouyn-Noranda, Quebec", websiteUrl="https://www.uqat.ca/",
    sourceUrl="https://www.uqat.ca/admission/frais-de-scolarite/internationaux/",
    overviewFr="Université francophone de l'Abitibi-Témiscamingue (Rouyn-Noranda), membre du réseau de l'Université du Québec, avec un campus à Montréal pour la création numérique. Au 1er cycle, un étudiant international paie 807,68 CAD par crédit en 2026-2027 (droits et montant forfaitaire), plus les frais afférents. En génie, des bourses de l'École de génie peuvent couvrir jusqu'à 25 % des frais majorés de la 1re année.",
    overviewEn="French-language university in Abitibi-Témiscamingue (Rouyn-Noranda), part of the Université du Québec network, with a Montreal campus for digital creation. At undergraduate level, an international student pays CAD 807.68 per credit in 2026-2027 (tuition and lump sum), plus related fees. In engineering, School of Engineering scholarships can cover up to 25% of the first year's higher fees.",
    languageRequirementsFr="Français : TFI, TCF, DELF, DALF ou TEF (C1 ou C2) acceptés ; sans test, évaluation à l'UQAT et cours de rattrapage au besoin",
    languageRequirementsEn="French: TFI, TCF, DELF, DALF or TEF (C1 or C2) accepted; without a test, assessment at UQAT and remedial courses if needed",
    applicationFee={"amount": 161.50, "currency": "CAD"}, applicationFeeFr="161,50 CAD (85 CAD crédités sur les droits si tu t'inscris)", applicationFeeEn="CAD 161.50 (CAD 85 credited to tuition if you enrol)",
    tuitionLabelFr="≈ 24 230 CAD/an (30 crédits au tarif international du 1er cycle, 2026-2027, hors frais afférents)",
    tuitionLabelEn="≈ CAD 24,230/year (30 credits at the international undergraduate rate, 2026-2027, before related fees)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-genie-electrique", "Baccalauréat en génie électrique", "Bachelor's in Electrical Engineering (Baccalauréat en génie électrique)", "Bachelor", "d03", "fr", "", "",
             uqat, "https://www.uqat.ca/etudes/ecole-de-genie/baccalaureat-en-genie-electrique/", UQAT_FR + [UQAT_GENIE_FR], UQAT_EN + [UQAT_GENIE_EN]),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "", "",
             uqat, "https://www.uqat.ca/etudes/ecole-de-genie/baccalaureat-en-genie-mecanique/", UQAT_FR + [UQAT_GENIE_FR], UQAT_EN + [UQAT_GENIE_EN]),
        prog("baccalaureat-administration", "Baccalauréat en administration", "Bachelor of Business Administration (Baccalauréat en administration)", "Bachelor", "d02", "fr", "", "",
             uqat, "https://www.uqat.ca/etudes/gestion/baccalaureat-en-administration/", UQAT_FR, UQAT_EN),
        prog("baccalaureat-sciences-comptables", "Baccalauréat en sciences comptables", "Bachelor's in Accounting (Baccalauréat en sciences comptables)", "Bachelor", "d02", "fr", "", "",
             uqat, "https://www.uqat.ca/etudes/gestion/baccalaureat-en-sciences-comptables/", UQAT_FR, UQAT_EN),
    ]))

# ── Québec : écoles d'ingénieurs et de gestion ──
ets = cad(38950, "moyenne annuelle publiée par l'ÉTS : 30 crédits de cours + 9 crédits de stage, internationaux, 2026-2027", "annual average published by ÉTS: 30 course credits + 9 co-op credits, international, 2026-2027")
ETS_FR = ["Dates limites internationales : 1er mars (automne), 1er juillet (hiver)", "27 crédits de stages coopératifs obligatoires (des frais de scolarité s'appliquent pendant les stages)"]
ETS_EN = ["International deadlines: 1 March (fall), 1 July (winter)", "27 mandatory co-op credits (tuition applies during co-op terms)"]
I.append(inst(
    id="na-ca-ets", countryId="can", nameFr="École de technologie supérieure (ÉTS)", nameEn="École de technologie supérieure (ÉTS)", acronym="ÉTS",
    institutionType="ecole_universitaire", consultedAt=C2,
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.etsmtl.ca/",
    sourceUrl="https://www.etsmtl.ca/etudier-a-lets/bourses-finance-et-budget/cout-des-etudes",
    overviewFr="École d'ingénierie francophone du centre-ville de Montréal, membre du réseau de l'Université du Québec, connue pour ses baccalauréats en génie avec stages coopératifs obligatoires en entreprise. En 2026-2027, un crédit coûte 1 171,18 CAD à un étudiant international au 1er cycle (montant forfaitaire compris), soit environ 38 950 CAD par an selon l'ÉTS ; pendant les stages, des bourses de stage sont créditées à ton compte étudiant.",
    overviewEn="French-language engineering school in downtown Montreal, part of the Université du Québec network, known for engineering bachelor's degrees with mandatory paid co-op terms. In 2026-2027, one credit costs an international undergraduate CAD 1,171.18 (lump sum included), about CAD 38,950 a year according to ÉTS; during co-op terms, co-op scholarships are credited to your student account.",
    languageRequirementsFr="Français : programmes enseignés en français ; relevés et diplômes rédigés dans une autre langue que le français ou l'anglais à faire traduire",
    languageRequirementsEn="French: programmes taught in French; transcripts and diplomas in a language other than French or English must be translated",
    applicationFee={"amount": 141, "currency": "CAD"}, applicationFeeFr="141 CAD (candidats internationaux)", applicationFeeEn="CAD 141 (international applicants)",
    tuitionLabelFr="≈ 38 950 CAD/an en moyenne (30 crédits de cours + 9 crédits de stage, internationaux, 2026-2027)",
    tuitionLabelEn="≈ CAD 38,950/year on average (30 course credits + 9 co-op credits, international, 2026-2027)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-genie-logiciel", "Baccalauréat en génie logiciel", "Bachelor's in Software Engineering (Baccalauréat en génie logiciel)", "Bachelor", "d01", "fr", "116 crédits de cours et 27 crédits de stage", "116 course credits and 27 co-op credits",
             ets, "https://www.etsmtl.ca/programmes-formations/baccalaureat-genie-logiciel", ETS_FR, ETS_EN),
        prog("baccalaureat-genie-electrique", "Baccalauréat en génie électrique", "Bachelor's in Electrical Engineering (Baccalauréat en génie électrique)", "Bachelor", "d03", "fr", "115 à 120 crédits de cours et 27 crédits de stage", "115 to 120 course credits and 27 co-op credits",
             ets, "https://www.etsmtl.ca/programmes-formations/baccalaureat-genie-electrique", ETS_FR, ETS_EN),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "115 crédits de cours et 27 crédits de stage", "115 course credits and 27 co-op credits",
             ets, "https://www.etsmtl.ca/programmes-formations/baccalaureat-genie-mecanique", ETS_FR, ETS_EN),
        prog("baccalaureat-genie-construction", "Baccalauréat en génie de la construction", "Bachelor's in Construction Engineering (Baccalauréat en génie de la construction)", "Bachelor", "d05", "fr", "116 à 119 crédits de cours et 27 crédits de stage", "116 to 119 course credits and 27 co-op credits",
             ets, "https://www.etsmtl.ca/programmes-formations/baccalaureat-genie-construction", ETS_FR, ETS_EN),
    ]))

poly = cad(30 * 1127.57, "30 crédits au tarif international du baccalauréat (base et montant forfaitaire), automne 2026 – été 2027, hors frais", "30 credits at the international bachelor's rate (base and lump sum), fall 2026 – summer 2027, before fees")
POLY_SRC = "https://share.polymtl.ca/alfresco/service/api/node/content/workspace/SpacesStore/2aa44c99-8875-4d86-85a5-c6e46bcbbf3c?a=false&guest=true"
POLY_FR = ["Programme agréé par le Bureau canadien d'agrément des programmes de génie", "Dates limites internationales : 1er février (automne), 1er juin (hiver)", "Connaissance suffisante de la langue française exigée (règlement des études, article 14)"]
POLY_EN = ["Programme accredited by the Canadian Engineering Accreditation Board", "International deadlines: 1 February (fall), 1 June (winter)", "Sufficient knowledge of French required (study regulations, section 14)"]
I.append(inst(
    id="na-ca-polytechnique", countryId="can", nameFr="Polytechnique Montréal", nameEn="Polytechnique Montréal", acronym="Polytechnique",
    institutionType="ecole_universitaire", consultedAt=C2,
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.polymtl.ca/",
    sourceUrl="https://etudiant.polymtl.ca/etudes/droits-de-scolarite/cout-des-etudes/baccalaureat",
    overviewFr="Grande école d'ingénierie francophone de Montréal, sur le campus de l'Université de Montréal. Ses baccalauréats en ingénierie comptent 120 crédits et sont agréés par Ingénieurs Canada. En 2026-2027, un crédit coûte 1 127,57 CAD à un étudiant international (montant forfaitaire compris), plus une assurance maladie obligatoire de 900 CAD par an. Pour l'automne 2027, la demande internationale se fait avant le 1er février 2027.",
    overviewEn="Major French-language engineering school in Montreal, on the Université de Montréal campus. Its engineering bachelor's degrees have 120 credits and are accredited by Engineers Canada. In 2026-2027, one credit costs an international student CAD 1,127.57 (lump sum included), plus mandatory health insurance of CAD 900 a year. For fall 2027, international applications are due by 1 February 2027.",
    languageRequirementsFr="Français : connaissance suffisante de la langue française exigée (règlement des études du baccalauréat, article 14)",
    languageRequirementsEn="French: sufficient knowledge of French required (bachelor's study regulations, section 14)",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 33 827 CAD/an (30 crédits au tarif international, 2026-2027, hors frais et assurance)",
    tuitionLabelEn="≈ CAD 33,827/year (30 credits at the international rate, 2026-2027, before fees and insurance)",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr"], quebec=True,
    programs=[
        prog("baccalaureat-genie-informatique", "Baccalauréat en génie informatique", "Bachelor's in Computer Engineering (Baccalauréat en génie informatique)", "Bachelor", "d01", "fr", "120 crédits", "120 credits", poly, POLY_SRC, POLY_FR, POLY_EN),
        prog("baccalaureat-genie-logiciel", "Baccalauréat en génie logiciel", "Bachelor's in Software Engineering (Baccalauréat en génie logiciel)", "Bachelor", "d01", "fr", "120 crédits", "120 credits", poly, POLY_SRC, POLY_FR, POLY_EN),
        prog("baccalaureat-genie-electrique", "Baccalauréat en génie électrique", "Bachelor's in Electrical Engineering (Baccalauréat en génie électrique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits", poly, POLY_SRC, POLY_FR, POLY_EN),
        prog("baccalaureat-genie-mecanique", "Baccalauréat en génie mécanique", "Bachelor's in Mechanical Engineering (Baccalauréat en génie mécanique)", "Bachelor", "d03", "fr", "120 crédits", "120 credits", poly, POLY_SRC, POLY_FR, POLY_EN),
        prog("baccalaureat-genie-biomedical", "Baccalauréat en génie biomédical", "Bachelor's in Biomedical Engineering (Baccalauréat en génie biomédical)", "Bachelor", "d03", "fr", "120 crédits", "120 credits", poly, POLY_SRC, POLY_FR, POLY_EN),
    ]))

hec_baa = cad(30 * 1077.43, "30 crédits au tarif international du B.A.A., automne 2026 – hiver 2027, hors frais institutionnels et assurance", "30 credits at the B.A.A. international rate, fall 2026 – winter 2027, before institutional fees and insurance")
HEC_MSC_T_FR, HEC_MSC_T_EN = "34 500 – 39 000 CAD pour le programme complet de 45 crédits (internationaux, avec mémoire ou projet supervisé)", "CAD 34,500 – 39,000 for the full 45-credit programme (international, thesis or supervised project)"
HEC_MSC_FR = ["Baccalauréat d'au moins 90 crédits (ou l'équivalent) ; disciplines quantitatives prioritaires selon la spécialisation", "Français : niveau intermédiaire-avancé à un test reconnu si ta scolarité n'atteste pas que tu es francophone", "Dates limites internationales : 1er février (automne), 1er juin (hiver)"]
HEC_MSC_EN = ["Bachelor's degree of at least 90 credits (or equivalent); quantitative fields preferred depending on the specialization", "French: intermediate-advanced level on a recognized test if your schooling does not show you are French-speaking", "International deadlines: 1 February (fall), 1 June (winter)"]
I.append(inst(
    id="na-ca-hec", countryId="can", nameFr="HEC Montréal", nameEn="HEC Montréal", acronym="HEC",
    institutionType="ecole_universitaire", consultedAt=C2,
    locationFr="Montréal, Québec", locationEn="Montreal, Quebec", websiteUrl="https://www.hec.ca/",
    sourceUrl="https://www.hec.ca/en/students/tuition-fees/pdf/tuition-fees-baa.pdf",
    overviewFr="École de gestion francophone de Montréal, sur le campus de l'Université de Montréal, titulaire des agréments AMBA, AACSB et EQUIS. Le B.A.A. (90 crédits) se suit en français ou en cheminement bilingue français-anglais, avec 15 spécialisations dont la science des données et l'analytique d'affaires. Au tarif international, un crédit du B.A.A. coûte 1 077,43 CAD en 2026-2027.",
    overviewEn="French-language business school in Montreal, on the Université de Montréal campus, holding AMBA, AACSB and EQUIS accreditations. The B.A.A. (90 credits) is taught in French or in a French-English bilingual track, with 15 specializations including data science and business analytics. At the international rate, one B.A.A. credit costs CAD 1,077.43 in 2026-2027.",
    languageRequirementsFr="Français : cours en français (B.A.A. aussi en cheminement bilingue) ; en maîtrise, niveau intermédiaire-avancé à un test reconnu si ta scolarité n'atteste pas que tu es francophone",
    languageRequirementsEn="French: courses in French (B.A.A. also in a bilingual track); for master's, intermediate-advanced level on a recognized test if your schooling does not show you are French-speaking",
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 32 323 CAD/an au B.A.A. (30 crédits au tarif international, 2026-2027, hors frais) ; 34 500 – 39 000 CAD pour une M. Sc. complète",
    tuitionLabelEn="≈ CAD 32,323/year for the B.A.A. (30 credits at the international rate, 2026-2027, before fees); CAD 34,500 – 39,000 for a full M.Sc.",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["fr", "en"], quebec=True,
    programs=[
        prog("baa", "Baccalauréat en administration des affaires (B.A.A.)", "Bachelor of Business Administration (Baccalauréat en administration des affaires, B.A.A.)", "BBA", "d02", "bi", "90 crédits, dont 3 stages crédités et rémunérés possibles", "90 credits, with up to 3 paid credit internships",
             hec_baa, "https://www.hec.ca/programmes/baccalaureat/baa",
             ["En français ou en cheminement bilingue français-anglais (mention trilingue avec l'espagnol, sous conditions)", "Les Français et Belges francophones paient le tarif canadien (entente entre gouvernements)"],
             ["In French or in a French-English bilingual track (trilingual mention with Spanish, under conditions)", "French and Belgian Francophone students pay the Canadian rate (intergovernmental agreement)"]),
        prog("msc-science-donnees-analytique-affaires", "Maîtrise en gestion (M. Sc.) – science des données et analytique d'affaires", "Master of Science (MSc) – Data Science and Business Analytics", "Master", "d01", "fr", "45 crédits, 16 à 24 mois", "45 credits, 16 to 24 months",
             (HEC_MSC_T_FR, HEC_MSC_T_EN, None), "https://www.hec.ca/programmes/maitrises/maitrise-science-donnees-analytique-affaires", HEC_MSC_FR, HEC_MSC_EN),
        prog("msc-intelligence-affaires", "Maîtrise en gestion (M. Sc.) – intelligence d'affaires", "Master of Science (MSc) – Business Intelligence (Maîtrise en gestion – intelligence d'affaires)", "Master", "d01", "fr", "45 crédits, 16 à 24 mois", "45 credits, 16 to 24 months",
             (HEC_MSC_T_FR, HEC_MSC_T_EN, None), "https://www.hec.ca/programmes/maitrises/maitrise-intelligence-affaires", HEC_MSC_FR, HEC_MSC_EN),
        prog("msc-finance", "Maîtrise en gestion (M. Sc.) – finance", "Master of Science (MSc) – Finance (Maîtrise en gestion – finance)", "Master", "d02", "fr", "45 crédits", "45 credits",
             (HEC_MSC_T_FR, HEC_MSC_T_EN, None), "https://www.hec.ca/programmes/maitrises/maitrise-finance", HEC_MSC_FR, HEC_MSC_EN),
    ]))

bish = cad(29510.43, "30 crédits, cohorte 2026, internationaux, avant frais obligatoires (32 221 CAD avec)", "30 credits, 2026 cohort, international, before compulsory fees (CAD 32,221 with them)")
BISH_FR = ["Anglais : IELTS 6.5 (aucune composante sous 6.0), TOEFL iBT 4.5 (2026) ou 90, Duolingo 115 (aucun sous-score sous 90), PTE 65", "Date limite internationale pour l'automne 2027 : 1er mars 2027 ; rentrées d'automne et d'hiver"]
BISH_EN = ["English: IELTS 6.5 (no component below 6.0), TOEFL iBT 4.5 (2026) or 90, Duolingo 115 (no sub-score below 90), PTE 65", "International deadline for fall 2027: 1 March 2027; fall and winter entry"]
I.append(inst(
    id="na-ca-bishops", countryId="can", nameFr="Université Bishop's", nameEn="Bishop's University", acronym="Bishop's",
    consultedAt=C2,
    locationFr="Sherbrooke, Québec", locationEn="Sherbrooke, Quebec", websiteUrl="https://www.ubishops.ca/",
    sourceUrl="https://www.ubishops.ca/future-students/fees-and-funding/tuition-and-fees/",
    overviewFr="Petite université anglophone du Québec, dans l'arrondissement de Lennoxville à Sherbrooke. En 2026-2027, un crédit coûte 983,68 CAD à un étudiant international de la cohorte 2026, soit 29 510 CAD pour 30 crédits avant les frais obligatoires. Si ton anglais est insuffisant mais que tu remplis les autres conditions, une lettre d'admission conditionnelle est possible avec un programme de langue d'une école partenaire (ILSC, Lambton College, Universitas…).",
    overviewEn="Small English-language university in Quebec, in the Lennoxville borough of Sherbrooke. In 2026-2027, one credit costs an international student of the 2026 cohort CAD 983.68, i.e. CAD 29,510 for 30 credits before compulsory fees. If your English is not strong enough but you meet the other requirements, a conditional letter of admission is possible with a partner school's language programme (ILSC, Lambton College, Universitas…).",
    languageRequirementsFr="Anglais : IELTS 6.5, TOEFL iBT 4.5 (2026) ou 90, Duolingo 115, PTE 65, Cambridge 176",
    languageRequirementsEn="English: IELTS 6.5, TOEFL iBT 4.5 (2026) or 90, Duolingo 115, PTE 65, Cambridge 176",
    languagePathway=pathway("Programmes de langue des écoles partenaires (English Language School Pathway)", "Partner English Language School Pathway programmes",
                            "admission conditionnelle sur preuve d'inscription dans une école partenaire (Brescia, East Coast Language College, Lambton College, Universitas Language Centre Montreal, Halifax Language Institute, ILSC)", "conditional admission with proof of enrolment at a partner school (Brescia, East Coast Language College, Lambton College, Universitas Language Centre Montreal, Halifax Language Institute, ILSC)",
                            "", "", "https://www.ubishops.ca/admissions/admission-requirements/english-language-school-pathway-students/"),
    applicationFee={"amount": 75, "currency": "CAD"}, applicationFeeFr="75 CAD", applicationFeeEn="CAD 75",
    tuitionLabelFr="≈ 29 510 CAD/an (30 crédits, internationaux, cohorte 2026) ; 32 221 CAD avec les frais obligatoires",
    tuitionLabelEn="≈ CAD 29,510/year (30 credits, international, 2026 cohort); CAD 32,221 with compulsory fees",
    intakePeriods=["Automne 2027", "Janvier (hiver)"], teachingLanguages=["en"], quebec=True,
    programs=[
        prog("bsc-computer-science", "Computer Science (B.Sc.)", "Computer Science (B.Sc.)", "Bachelor", "d01", "en", "3 ou 4 ans", "3 or 4 years",
             bish, "https://www.ubishops.ca/program/computer-science/", BISH_FR, BISH_EN),
        prog("bba-business-technology-analytics", "Business Technology and Analytics (B.B.A.)", "Business Technology and Analytics (B.B.A.)", "BBA", "d02", "en", "3 ou 4 ans", "3 or 4 years",
             bish, "https://www.ubishops.ca/program/business-technology-and-analytics/", BISH_FR, BISH_EN),
        prog("bba-finance", "Finance (B.B.A.)", "Finance (B.B.A.)", "BBA", "d02", "en", "3 ou 4 ans", "3 or 4 years",
             bish, "https://www.ubishops.ca/program/finance/", BISH_FR, BISH_EN),
        prog("msc-computer-science", "Computer Science (M.Sc.)", "Computer Science (M.Sc.)", "Master", "d01", "en", "2,5 ans (stage, cours ou mémoire)", "2.5 years (internship, course-based or thesis)",
             cad(29510.43, "30 crédits, maîtrise par cours, cohorte 2026, internationaux, avant frais obligatoires", "30 credits, course-based master's, 2026 cohort, international, before compulsory fees"),
             "https://www.ubishops.ca/program/computer-science-msc/", ["Rentrées d'automne et d'hiver"], ["Fall and winter entry"]),
    ]))

# ── Nouveau-Brunswick ──
UNB_FEE = lambda total: ("2 trimestres, internationaux, 2026-2027 ; {} CAD avec frais et assurances".format(total), "2 terms, international, 2026-2027; CAD {} with fees and insurance".format(total.replace(" ", ",")))
UNB_FR = ["Anglais : IELTS 6.5, TOEFL iBT 4.5 (2026) ou 85, Duolingo 115, CAEL 60, PTE 59", "Admission conditionnelle possible avec le parcours d'anglais PAEP de UNB Fredericton"]
UNB_EN = ["English: IELTS 6.5, TOEFL iBT 4.5 (2026) or 85, Duolingo 115, CAEL 60, PTE 59", "Conditional admission possible through UNB Fredericton's PAEP English pathway"]
I.append(inst(
    id="na-ca-unb", countryId="can", nameFr="Université du Nouveau-Brunswick (UNB)", nameEn="University of New Brunswick (UNB)", acronym="UNB",
    consultedAt=C2,
    locationFr="Fredericton, Nouveau-Brunswick", locationEn="Fredericton, New Brunswick", websiteUrl="https://www.unb.ca/",
    sourceUrl="https://www.unb.ca/international/admission/english.html",
    overviewFr="Université publique anglophone du Nouveau-Brunswick, avec des campus à Fredericton et Saint John. En 2026-2027, les frais de scolarité d'une année en informatique à Fredericton sont de 22 514 CAD pour un étudiant international (25 871 CAD en génie). Si tu n'as pas encore le score d'anglais demandé, tu peux être admis à condition de suivre d'abord le parcours PAEP (Program of Academic English Preparation) ; dès IELTS 5.5 ou 6.0, tu suis déjà certains cours de ton programme.",
    overviewEn="English-language public university in New Brunswick, with campuses in Fredericton and Saint John. In 2026-2027, a year of computer science tuition in Fredericton is CAD 22,514 for an international student (CAD 25,871 in engineering). If you do not yet have the required English score, you can be admitted on condition that you first follow the PAEP pathway (Program of Academic English Preparation); from IELTS 5.5 or 6.0, you already take some courses in your programme.",
    languageRequirementsFr="Anglais : IELTS 6.5, TOEFL iBT 4.5 (2026) ou 85, Duolingo 115, CAEL 60, PTE 59 (IELTS 7.0 et Duolingo 130 en sciences infirmières)",
    languageRequirementsEn="English: IELTS 6.5, TOEFL iBT 4.5 (2026) or 85, Duolingo 115, CAEL 60, PTE 59 (IELTS 7.0 and Duolingo 130 for Nursing)",
    languagePathway=pathway("Program of Academic English Preparation (PAEP)", "Program of Academic English Preparation (PAEP)",
                            "admission conditionnelle ; anglais académique à temps complet, avec des cours du programme dès IELTS 5.5–6.0", "conditional admission; full-time academic English, with programme courses from IELTS 5.5–6.0",
                            "frais de scolarité de premier cycle à temps complet de UNB", "UNB full-time undergraduate tuition",
                            "https://www.unb.ca/elp/english/paep.html"),
    applicationFee=None, applicationFeeFr="", applicationFeeEn="",
    tuitionLabelFr="≈ 22 514 – 25 871 CAD/an selon la faculté à Fredericton (internationaux, 2026-2027, hors frais et assurances)",
    tuitionLabelEn="≈ CAD 22,514 – 25,871/year by faculty in Fredericton (international, 2026-2027, before fees and insurance)",
    intakePeriods=["Automne 2027"], teachingLanguages=["en"],
    programs=[
        prog("bachelor-computer-science", "Bachelor of Computer Science (BCS)", "Bachelor of Computer Science (BCS)", "Bachelor", "d01", "en", "8 trimestres d'études (au moins 133 heures-crédits)", "8 study terms (at least 133 credit hours)",
             cad(22514, *UNB_FEE("24 365")), "https://www.unb.ca/academics/calendar/undergraduate/current/frederictonprograms/bachelorofcomputerscience.html",
             UNB_FR + ["Programme coop ou PEP (expérience professionnelle) facultatif"], UNB_EN + ["Optional co-op or PEP (professional experience)"]),
        prog("bsc-software-engineering", "Bachelor of Science in Software Engineering (BScSwE)", "Bachelor of Science in Software Engineering (BScSwE)", "Bachelor", "d01", "en", "4 ans (5 avec coop ou PEP), au moins 160 heures-crédits", "4 years (5 with co-op or PEP), at least 160 credit hours",
             None, "https://www.unb.ca/academics/calendar/undergraduate/current/frederictonprograms/bachelorofscienceinsoftwarenegineering.html",
             UNB_FR, UNB_EN),
        prog("bsce-mechanical-engineering", "Bachelor of Science in Engineering – Mechanical Engineering", "Bachelor of Science in Engineering – Mechanical Engineering", "Bachelor", "d03", "en", "160 heures-crédits", "160 credit hours",
             cad(25871, *UNB_FEE("27 722")), "https://www.unb.ca/academics/calendar/undergraduate/current/frederictonprograms/bachelorofscienceinengineering/mechanicalengineering.html",
             UNB_FR, UNB_EN),
        prog("bachelor-of-nursing", "Bachelor of Nursing (BN)", "Bachelor of Nursing (BN)", "Bachelor", "d04", "en", "4 ans", "4 years",
             cad(22959, *UNB_FEE("24 810")), "https://www.unb.ca/academics/calendar/undergraduate/current/frederictonprograms/bachelorofnursing.html",
             ["Anglais : IELTS 7.0, TOEFL iBT 5 (2026) ou 100, Duolingo 130, CAEL 80, PTE 68", "Offert à Fredericton et à Saint John"], ["English: IELTS 7.0, TOEFL iBT 5 (2026) or 100, Duolingo 130, CAEL 80, PTE 68", "Offered in Fredericton and Saint John"]),
    ]))

ccnb = cad(10258, "droit fixe annuel d'un programme de 30 à 40 semaines, internationaux", "annual flat fee for a 30- to 40-week programme, international")
CCNB_FR = ["Personne candidate internationale : diplôme d'études secondaires ou l'équivalent, et réussite du test d'admission du CCNB", "Liste des programmes ouverts au programme pilote PPECFSM pour l'automne 2027"]
CCNB_EN = ["International applicant: secondary school diploma or equivalent, and passing the CCNB admission test", "Listed among programmes open under the FMC Student Pilot for fall 2027"]
I.append(inst(
    id="na-ca-ccnb", countryId="can", nameFr="Collège communautaire du Nouveau-Brunswick (CCNB)", nameEn="Collège communautaire du Nouveau-Brunswick (CCNB)", acronym="CCNB",
    institutionType="college_public", consultedAt=C2,
    locationFr="Bathurst, Nouveau-Brunswick", locationEn="Bathurst, New Brunswick", websiteUrl="https://ccnb.ca/",
    sourceUrl="https://ccnb.ca/frais-et-financement/droits-de-scolarite/",
    overviewFr="Collège public francophone du Nouveau-Brunswick, avec des campus à Bathurst, Campbellton, Dieppe, Edmundston et dans la Péninsule acadienne. Un programme d'un an (30 à 40 semaines) coûte 10 258 CAD aux étudiants internationaux. Le CCNB participe au programme pilote fédéral pour les étudiants francophones en situation minoritaire (PPECFSM) et précise qu'il ne travaille avec aucune agence de recrutement : ne paie pas d'intermédiaire.",
    overviewEn="French-language public college in New Brunswick, with campuses in Bathurst, Campbellton, Dieppe, Edmundston and the Acadian Peninsula. A one-year programme (30 to 40 weeks) costs international students CAD 10,258. CCNB takes part in the federal Francophone Minority Communities Student Pilot and states that it works with no recruitment agency: do not pay intermediaries.",
    languageRequirementsFr="Français : programmes enseignés en français ; réussite du test d'admission du CCNB",
    languageRequirementsEn="French: programmes taught in French; passing the CCNB admission test",
    applicationFee={"amount": 100, "currency": "CAD"}, applicationFeeFr="100 CAD (1 ou 2 choix de programme par année) ; frais de confirmation de 500 CAD + 4 644 CAD une fois admis", applicationFeeEn="CAD 100 (1 or 2 programme choices per year); CAD 500 + CAD 4,644 confirmation fee once admitted",
    tuitionLabelFr="10 258 CAD/an (programme de 30 à 40 semaines, internationaux) ; 301 CAD par semaine pour les autres durées",
    tuitionLabelEn="CAD 10,258/year (30- to 40-week programme, international); CAD 301 per week for other lengths",
    intakePeriods=["Automne 2027"], teachingLanguages=["fr"],
    programs=[
        prog("programmation-developpement-applications", "Programmation et développement d'applications", "Programming and Application Development (Programmation et développement d'applications)", "Diplôme collégial", "d01", "fr", "60 semaines", "60 weeks",
             ccnb, "https://ccnb.ca/programmes/programmation-et-developpement-dapplications/", CCNB_FR + ["Campus de Bathurst"], CCNB_EN + ["Bathurst campus"]),
        prog("techniques-de-comptabilite", "Techniques de comptabilité", "Accounting Techniques (Techniques de comptabilité)", "Diplôme collégial", "d02", "fr", "60 semaines", "60 weeks",
             ccnb, "https://ccnb.ca/programmes/techniques-de-comptabilite/", CCNB_FR + ["Campus de Bathurst et de Dieppe"], CCNB_EN + ["Bathurst and Dieppe campuses"]),
        prog("technologie-instrumentation-automatisation", "Technologie de l'instrumentation et de l'automatisation", "Instrumentation and Automation Technology (Technologie de l'instrumentation et de l'automatisation)", "Diplôme collégial", "d03", "fr", "74 semaines, stage compris", "74 weeks, internship included",
             ccnb, "https://ccnb.ca/programmes/technologie-de-linstrumentation-et-de-lautomatisation/", CCNB_FR + ["Campus de Bathurst"], CCNB_EN + ["Bathurst campus"]),
        prog("techniques-en-pharmacie", "Techniques en pharmacie", "Pharmacy Techniques (Techniques en pharmacie)", "Diplôme collégial", "d04", "fr", "60 semaines, stage compris", "60 weeks, internship included",
             ccnb, "https://ccnb.ca/programmes/techniques-en-pharmacie/", CCNB_FR + ["Campus de Campbellton"], CCNB_EN + ["Campbellton campus"]),
    ]))


# ─── Assemblage des overviews (paragraphes communs) ───
for x in I:
    fr = [x["overviewFr"]]
    en = [x["overviewEn"]]
    lp = x.get("languagePathway")
    if lp:
        # Le programme de langue en amont est aussi écrit dans les exigences
        # linguistiques, seul champ que la fiche de l'app affiche.
        cost_fr = f", {lp['costFr']}" if lp["costFr"] else ""
        cost_en = f", {lp['costEn']}" if lp["costEn"] else ""
        x["languageRequirementsFr"] += f" ; programme de langue en amont : {lp['nameFr']} ({lp['durationFr']}{cost_fr})"
        x["languageRequirementsEn"] += f"; upstream language programme: {lp['nameEn']} ({lp['durationEn']}{cost_en})"
    if x.get("applicationFeeFr"):
        fr.append(f"Frais de candidature : {x['applicationFeeFr']}.")
        en.append(f"Application fee: {x['applicationFeeEn']}.")
    if x.pop("visaUs", False):
        fr.append(US_VISA_FR); en.append(US_VISA_EN)
    if x.pop("quebec", False):
        fr.append(QC_FR); en.append(QC_EN)
    fr.append(NOT_PARTNER_FR); en.append(NOT_PARTNER_EN)
    x["overviewFr"] = "\n\n".join(fr)
    x["overviewEn"] = "\n\n".join(en)

doc = {
    "source": "Relevés sur les sites officiels des établissements, consultés le 16/10/2026 (seconde passe Canada : 17/10/2026) — voir amerique-du-nord-2027.sources.md",
    "consultedAt": "2026-10-16",
    "exchangeRates": {"date": "2026-10-16", "source": "BCE, taux de référence (eurofxref-daily.xml)", "perEur": {"USD": 1.1253, "CAD": 1.5935}},
    "institutions": I,
}
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "amerique-du-nord-2027.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(len(I), "établissements,", sum(len(x["programs"]) for x in I), "formations")
