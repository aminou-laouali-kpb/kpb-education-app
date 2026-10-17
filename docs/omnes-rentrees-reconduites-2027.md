# Rentrées OMNES reconduites en 2027 — à faire confirmer par OMNES

Remplace l'ancienne liste « Formations OMNES sans rentrée à venir »
(`omnes-formations-sans-rentree-2027.md`), devenue caduque.

**Décision du propriétaire (16/10/2026).** Toutes les rentrées d'automne 2026
de la grille OMNES (`backend/scripts/data/omnes_fall_26.xlsx`) sont
reconduites d'un an, même jour et même mois : août, septembre et octobre 2026
→ août, septembre et octobre 2027 (la grille n'a pas d'autre mois d'automne).
Les offres de rentrée décalée de janvier, février et mars 2027 (grille
SPRING 27) ne bougent pas : une formation qui a les deux garde son offre de
printemps, et son offre d'automne passe en 2027.

OMNES n'a publié **ni les dates ni les tarifs 2027-2028**. Chaque offre
reconduite garde son campus et ses prix (tarifs 2026-2027) et porte
`rolledFromIntake` (la date d'origine) et `intakeEstimated: true` ; l'app
affiche sous l'offre « Date reconduite de 2026, à confirmer · tarif
2026-2027 », et « (à confirmer) » à côté de la rentrée sur les cartes.

**À demander à OMNES, pour chaque ligne ci-dessous : la date de rentrée de
l'automne 2027 et le tarif 2027-2028.** Une fois une date ou un prix confirmé,
corriger l'offre dans l'admin en retirant les deux marques (l'API garde
`rolledFromIntake` / `intakeEstimated` tant qu'on les lui renvoie) ; une
nouvelle grille d'automne 2027 se chargera par une opération dédiée.

Comptes (base après `dedupe-omnes`, `import-omnes-spring` puis
`roll-omnes-fall-2027`, rejoués sur Postgres 15 local) : **280 formations,
747 offres** — ECE 54 / 70, ESCE 46 / 55, HEIP 10 / 20, INSEEC 144 / 529,
Sup de Pub 26 / 73 (formations / offres). Dates reconduites : août 19,
septembre 512, octobre 216. 94 de ces formations ont aussi une rentrée
décalée 2027 (ECE 8, ESCE 15, INSEEC 71). Les 12 fiches hors ligne (alias de
`dedupe-omnes`) sont reconduites aussi mais ne figurent pas ici : leurs offres
sont déjà sur la fiche canonique.

Format : intitulé — campus : date 2026 → **date 2027** (prix comptant
2026-2027).

### ECE (54 formations, 70 offres)

- ECE - B1 - Computer Science - 100% English — Paris : 01/10/2026 → **01/10/2027** (8 850 €)
- ECE - B1 - Cybersécurité et réseaux — Paris : 01/10/2026 → **01/10/2027** (8 850 €) — *a aussi une rentrée décalée 2027*
- ECE - B1 - Développeur d'Applications — Paris : 01/10/2026 → **01/10/2027** (8 850 €)
- ECE - B1 - Développeur en intelligence artificielle — Bordeaux, Lyon, Paris : 01/10/2026 → **01/10/2027** (8 850 €)
- ECE - B2 - Computer Science - 100% English — Paris : 14/09/2026 → **14/09/2027** (9 890 €)
- ECE - B2 - Cybersécurité et réseaux — Paris : 14/09/2026 → **14/09/2027** (9 890 €)
- ECE - B2 - Développeur d'Applications — Paris : 14/09/2026 → **14/09/2027** (9 890 €)
- ECE - B2 - Développeur en Intelligence Artificielle — Bordeaux, Lyon, Paris : 14/09/2026 → **14/09/2027** (9 890 €)
- ECE - B3 - Computer Science - 100% English — Paris : 05/10/2026 → **05/10/2027** (10 090 €)
- ECE - B3 - Cybersécurité et réseaux — Paris : 01/10/2026 → **01/10/2027** (10 090 €)
- ECE - B3 - Développeur d'Applications — Paris : 01/10/2026 → **01/10/2027** (10 090 €)
- ECE - B3 - Développeur en intelligence artificielle — Bordeaux, Lyon : 14/09/2026 → **14/09/2027** (10 090 €) ; Paris : 01/10/2026 → **01/10/2027** (10 090 €)
- ECE - ING4 - PGE - Cybersécurité — Paris : 01/09/2026 → **01/09/2027** (12 690 €)
- ECE - ING4 - PGE - Environnement et durabilité - 100% English — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - ING4 - PGE - Finance Corporate — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - ING4 - PGE - Finance de Marché — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - ING4 - PGE - Fintech et macroéconomie — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - ING4 - PGE - Transition énergétique — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - MSc CGE - M1 - AI for Business Transformation - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Artificial Intelligence - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M1 - Cybersecurity Manager - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M1 - Data Management - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Data Management - Mixte Français / Anglais — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Embedded AI & Edge Intelligence - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Information Systems & Digital Sovereignty - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Intelligence Artificielle - Mixte Français / Anglais — Lyon, Paris : 21/09/2026 → **21/09/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M1 - Manager de la Cybersécurité — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M1 - Sustainable Energy Futures (100% English) — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - AI for Business Transformation - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - Artificial Intelligence — Lyon, Paris : 21/09/2026 → **21/09/2027** (12 990 €)
- ECE - MSc CGE - M2 - Artificial Intelligence - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M2 - Cybersecurity Manager - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M2 - Data Management — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M2 - Data Management - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - Embedded AI & Edge Intelligence - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - Information Systems & Digital Sovereignty - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - Manager de la Cybersécurité — Paris : 01/10/2026 → **01/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- ECE - MSc CGE - M2 - Sustainable Energy Futures - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - MSc CGE - M2 - Technology Management and International Entrepreneurship - 100% English — Paris : 01/10/2026 → **01/10/2027** (12 990 €)
- ECE - PGE - ING1 — Bordeaux, Lyon, Marseille, Paris, Rennes : 01/09/2026 → **01/09/2027** (12 690 €)
- ECE - PGE - ING2 — Bordeaux, Lyon, Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING3 — Bordeaux, Lyon, Paris : 11/09/2026 → **11/09/2027** (12 690 €)
- ECE - PGE - ING4 - Cybersécurité — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Data & AI - 100% English — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Data & IA — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Défense & Technologie — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Embedded Systems - 100% English — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Environnement et durabilité — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Système aéronautique et spatial — Bordeaux : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Systèmes Embarqués — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Systèmes d'Energie Nucléaire (50% English - 50% Français) — Lyon : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Transition énergétique - 100% English — Paris : 31/08/2026 → **31/08/2027** (12 690 €)
- ECE - PGE - ING4 - Véhicules Connectés Autonomes — Paris : 01/09/2026 → **01/09/2027** (12 690 €)
- ECE - PGE - Ing4 - Santé & Technologie — Paris : 31/08/2026 → **31/08/2027** (12 690 €)

### ESCE (46 formations, 55 offres)

- ESCE - Bachelor - B1 — Paris : 14/09/2026 → **14/09/2027** (9 690 €)
- ESCE - Bachelor - B1 - 100% English — Paris : 14/09/2026 → **14/09/2027** (9 690 €)
- ESCE - Bachelor - B2 — Paris : 01/10/2026 → **01/10/2027** (9 690 €)
- ESCE - Bachelor - B2 - 100% English — Paris : 01/10/2026 → **01/10/2027** (9 690 €)
- ESCE - Bachelor - B3 - Corporate Finance — Paris : 14/09/2026 → **14/09/2027** (9 690 €)
- ESCE - Bachelor - B3 - International Business - 100% English — Paris : 14/09/2026 → **14/09/2027** (9 690 €)
- ESCE - Bachelor - B3 - Management des Organisations — Paris : 14/09/2026 → **14/09/2027** (7 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - M1 - AI-Driven Marketing & Innovation — Paris : 07/09/2026 → **07/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - M1 - French Luxury & Global Marketing — Paris : 15/09/2026 → **15/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - M1 - Geopolitics for Business Development — Paris : 15/09/2026 → **15/09/2027** (10 650 €)
- ESCE - M1 - International Management & Business Intelligence — Paris : 15/09/2026 → **15/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - M1 - Risk management & International Business Compliance — Paris : 15/09/2026 → **15/09/2027** (10 650 €)
- ESCE - M1 - Stratégie des Entreprises et Management international — Paris : 16/09/2026 → **16/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - M1 - Trade Finance — Paris : 15/09/2026 → **15/09/2027** (10 650 €)
- ESCE - M1 - Visa (Bac +5) - Développement commercial international — Paris : 16/09/2026 → **16/09/2027** (10 650 €)
- ESCE - M2 - AI-Driven Marketing & Innovation - Fast Track — Paris : 07/09/2026 → **07/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - M2 - French Luxury & Global Marketing — Paris : 17/09/2026 → **17/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - M2 - Geopolitics for Business Development — Paris : 17/09/2026 → **17/09/2027** (10 690 €)
- ESCE - M2 - International Management & Business Intelligence - Fast Track — Paris : 17/09/2026 → **17/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - M2 - Risk management & International Business Compliance - Fast Track — Paris : 17/09/2026 → **17/09/2027** (10 690 €)
- ESCE - M2 - Trade Finance - Fast Track — Paris : 17/09/2026 → **17/09/2027** (10 690 €)
- ESCE - MSc - M1 - Global Supply Chain Management (100% English) — Paris : 15/09/2026 → **15/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M1 - International Business Development - 100% English — Paris : 15/09/2026 → **15/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M1 - International Corporate Finance - 100% English — Paris : 15/09/2026 → **15/09/2027** (10 650 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M2 - Global Supply Chain Management - Fast Track (100% English) — Paris : 17/09/2026 → **17/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M2 - International Business Developpement - Fast Track - 100% English — Paris : 17/09/2026 → **17/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M2 - International Corporate Finance - Fast Track - 100% English — Paris : 17/09/2026 → **17/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- ESCE - MSc - M2 - Technology Management and International Entrepreneurship - Fast Track - 100% English — Paris : 22/09/2026 → **22/09/2027** (10 650 €)
- ESCE - PGE - AN1 - International business (standard track) — Lyon, Paris : 15/09/2026 → **15/09/2027** (12 890 €)
- ESCE - PGE - AN1 - International business (standard track) - 100% English — Lyon, Paris : 15/09/2026 → **15/09/2027** (12 890 €)
- ESCE - PGE - AN1 - Management international, IA et Data — Paris : 15/09/2026 → **15/09/2027** (prix non publié)
- ESCE - PGE - AN1 - Sciences politiques internationales — Lyon, Paris : 15/09/2026 → **15/09/2027** (12 890 €)
- ESCE - PGE - AN2 - Cursus expert America/Asia/Europe — Lyon, Paris : 07/09/2026 → **07/09/2027** (12 890 €)
- ESCE - PGE - AN2 - Cursus expert America/Asia/Europe - 100% English — Paris : 07/09/2026 → **07/09/2027** (12 890 €)
- ESCE - PGE - AN2 - International business (standard track) — Lyon, Paris : 07/09/2026 → **07/09/2027** (12 890 €)
- ESCE - PGE - AN2 - International business (standard track) - 100% English — Lyon, Paris : 07/09/2026 → **07/09/2027** (12 890 €)
- ESCE - PGE - AN2 - Sciences politiques internationales — Lyon, Paris : 07/09/2026 → **07/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Communication, Luxury and Prestige Marketing - 100% English — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Digital & Sustainable Supply Chain - 100% English — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Finance Investment & Banking, parcours Corporate Finance - 100% English — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Finance Investment & Banking, parcours Financial Markets - 100% English — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Ingénierie d'affaires — Lyon, Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - International Business Development - 100% English — Lyon, Paris : 14/09/2026 → **14/09/2027** (12 890 €) — *a aussi une rentrée décalée 2027*
- ESCE - PGE - AN4 - International Digital Marketing - 100% English — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - International Entrepreneurship & Consulting (50% English - 50% Français) — Paris : 14/09/2026 → **14/09/2027** (12 890 €)
- ESCE - PGE - AN4 - Trade Finance — Paris : 14/09/2026 → **14/09/2027** (12 890 €)

### HEIP (10 formations, 20 offres)

- HEIP - B1 - Relations Internationales et Sciences Politiques — Bordeaux, Lyon, Paris : 17/09/2026 → **17/09/2027** (9 690 €)
- HEIP - B2 - Relations Internationales et Sciences Politiques — Bordeaux, Lyon, Paris : 18/09/2026 → **18/09/2027** (9 690 €)
- HEIP - B3 - Bachelor of Arts in Humanities - 100% English — Paris : 14/09/2026 → **14/09/2027** (9 690 €)
- HEIP - B3 - Relations Internationales et Sciences Politiques — Bordeaux, Lyon, Paris : 11/09/2026 → **11/09/2027** (9 690 €)
- HEIP - M1 - Diplomatie économique et développement international des entreprises — Lyon, Paris : 10/09/2026 → **10/09/2027** (11 050 €)
- HEIP - M1 - Manager des institutions et des affaires publiques — Lyon, Paris : 10/09/2026 → **10/09/2027** (11 050 €)
- HEIP - M1 - Politiques et coopérations internationales de défense et de sécurité — Paris : 10/09/2026 → **10/09/2027** (11 050 €)
- HEIP - M2 - Diplomatie économique et développement international des entreprises — Lyon, Paris : 14/09/2026 → **14/09/2027** (11 050 €)
- HEIP - M2 - Manager des institutions et des affaires publiques — Lyon, Paris : 14/09/2026 → **14/09/2027** (11 050 €)
- HEIP - M2 - Politiques et coopérations internationales de défense et de sécurité — Paris : 14/09/2026 → **14/09/2027** (11 050 €)

### INSEEC (144 formations, 529 offres)

- BBA - AN1 — Bordeaux, Lyon, Paris : 16/09/2026 → **16/09/2027** (12 550 €)
- BBA - AN1 - 100% English — Bordeaux, Lyon, Paris : 16/09/2026 → **16/09/2027** (12 550 €)
- BBA - AN2 — Bordeaux, Lyon, Paris : 14/09/2026 → **14/09/2027** (12 650 €)
- BBA - AN2 - 100% English — Lyon, Paris : 14/09/2026 → **14/09/2027** (12 650 €)
- BBA - AN3 — Bordeaux, Lyon, Paris : 09/09/2026 → **09/09/2027** (13 000 €)
- BBA - AN3 - 100% English — Bordeaux, Lyon, Paris : 09/09/2026 → **09/09/2027** (13 000 €)
- BCh - B1 - Activités commerciales à l'International — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Activités commerciales à l'International - 100% English — Paris : 16/09/2026 → **16/09/2027** (10 050 €)
- BCh - B1 - Banque Assurance — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Business Développement & Start-up — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €)
- BCh - B1 - Evénementiel — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Finance d'entreprise — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Luxe — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Lyon : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris : 16/09/2026 → **16/09/2027** (10 050 €)
- BCh - B1 - Marketing Comm en Digital — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €)
- BCh - B1 - Marketing Comm et Développement de produits — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon, Toulouse : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Sport Business — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Chambéry : 01/09/2026 → **01/09/2027** (8 350 €) ; Lyon : 15/09/2026 → **15/09/2027** (10 050 €) ; Marseille : 21/09/2026 → **21/09/2027** (10 050 €) ; Paris, Rennes : 16/09/2026 → **16/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B1 - Sport Business - Fall 2026 — Toulouse : 15/09/2026 → **15/09/2027** (10 050 €)
- BCh - B1 - Vins & Spiritueux — Bordeaux : 08/09/2026 → **08/09/2027** (10 050 €) ; Lyon : 15/09/2026 → **15/09/2027** (10 050 €) — *a aussi une rentrée décalée 2027*
- BCh - B2 - Activités commerciales à l'International — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Activités commerciales à l'International - 100% English — Paris : 09/09/2026 → **09/09/2027** (10 550 €)
- BCh - B2 - Banque Assurance — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Business Développement & Start-up — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €)
- BCh - B2 - Evénementiel — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Finance d'entreprise — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Luxe — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris : 09/09/2026 → **09/09/2027** (10 550 €)
- BCh - B2 - Marketing Comm en Digital — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Marketing Comm et Développement de produits — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €) ; Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Responsable des activités commerciales en Business Development — Toulouse : 08/09/2026 → **08/09/2027** (10 550 €)
- BCh - B2 - Sport Business — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Chambéry : 03/09/2026 → **03/09/2027** (8 350 €) ; Lyon, Marseille : 14/09/2026 → **14/09/2027** (10 550 €) ; Paris, Rennes : 09/09/2026 → **09/09/2027** (10 550 €)
- BCh - B2 - Vins & Spiritueux — Bordeaux : 15/09/2026 → **15/09/2027** (10 550 €) ; Lyon : 14/09/2026 → **14/09/2027** (10 550 €)
- BCh - B3 - Activités commerciales à l'International — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (11 090 €) ; Chambéry : 08/09/2026 → **08/09/2027** (8 850 €) ; Lyon : 28/09/2026 → **28/09/2027** (11 090 €) ; Marseille : 29/09/2026 → **29/09/2027** (11 090 €) ; Paris : 17/09/2026 → **17/09/2027** (11 090 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Activités commerciales à l'International - 100% English — Paris : 23/09/2026 → **23/09/2027** (11 090 €)
- BCh - B3 - Banque Assurance — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Business Développement & Start-up — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €)
- BCh - B3 - Business Développement & Start-up – Resp. d’activités commerciales — Beaune : 28/09/2026 → **28/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Community Management et Réseaux Sociaux — Bordeaux : 22/09/2026 → **22/09/2027** (10 690 €) ; Lyon : 28/09/2026 → **28/09/2027** (10 690 €) ; Paris : 23/09/2026 → **23/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Corporate Finance — Paris : 23/09/2026 → **23/09/2027** (10 690 €)
- BCh - B3 - Digital Business, IA et Data — Bordeaux : 22/09/2026 → **22/09/2027** (10 690 €) ; Lyon : 28/09/2026 → **28/09/2027** (10 690 €) ; Paris : 23/09/2026 → **23/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Distribution/Export — Beaune, Lyon : 28/09/2026 → **28/09/2027** (10 690 €) ; Bordeaux : 22/09/2026 → **22/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Evénementiel — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Finance d'entreprise — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) ; Paris : 23/09/2026 → **23/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Luxe — Bordeaux : 22/09/2026 → **22/09/2027** (10 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Marketing Comm et Développement de produits — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €)
- BCh - B3 - Oenotourisme — Beaune : 28/09/2026 → **28/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Sommellerie, Gastronomie — Beaune, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Bordeaux : 22/09/2026 → **22/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Sport Business — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 08/09/2026 → **08/09/2027** (8 690 €) ; Lyon, Paris : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- BCh - B3 - Web Marketing — Bordeaux, Rennes, Toulouse : 22/09/2026 → **22/09/2027** (10 690 €) ; Chambéry : 21/09/2026 → **21/09/2027** (8 690 €) ; Lyon : 28/09/2026 → **28/09/2027** (10 690 €) ; Marseille : 29/09/2026 → **29/09/2027** (10 690 €) ; Paris : 23/09/2026 → **23/09/2027** (10 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Achats & Supply Chain Management — Bordeaux, Chambéry, Lyon, Marseille, Paris, Toulouse : 19/10/2026 → **19/10/2027** (13 350 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Analyse Financière Internationale — Bordeaux, Lyon, Paris : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Audit & Contrôle de Gestion — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Banque d’Affaires & Ingénierie Financière — Bordeaux, Paris : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Business Development & Ingénierie d'Affaires — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Business Development - Trade Marketing & Distribution — Bordeaux, Marseille, Paris : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Chef de Projet Marketing & IA — Bordeaux, Lyon, Paris : 28/09/2026 → **28/09/2027** (12 090 €)
- IMSc - M1 - Communication, Marketing d'Influence & RP — Bordeaux, Chambéry, Lyon, Marseille, Paris : 28/09/2026 → **28/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Communication, Publicité & Stratégie Digitale — Bordeaux, Chambéry, Lyon, Marseille, Paris : 28/09/2026 → **28/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Data Management & AI for Business — Paris : 28/09/2026 → **28/09/2027** (12 090 €)
- IMSc - M1 - Data Management & Finance — Paris : 12/10/2026 → **12/10/2027** (12 990 €)
- IMSc - M1 - Digital Marketing & E-Commerce - 100% English — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Digital Supply Chain, Achats & IA — Paris : 19/10/2026 → **19/10/2027** (12 090 €)
- IMSc - M1 - Directeur des Etablissements de Santé — Bordeaux, Lyon, Marseille, Paris, Toulouse : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Expert en management immobilier — Bordeaux, Chambéry, Lyon, Marseille, Paris : 12/10/2026 → **12/10/2027** (12 090 €)
- IMSc - M1 - Finance d’Entreprise & Ingénierie Financière — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Fiscalité, Droit des Affaires, Conseil & Gestion d’Entreprise — Bordeaux, Paris : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Food & Beverage Management — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Gestionnaire patrimoine — Bordeaux, Chambéry, Lyon, Marseille, Paris : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Hospitality Management, Marketing du Tourisme & Expérience Client — Bordeaux, Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Human Resources Manager — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - International Business Management — Bordeaux, Lyon, Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - International Financial Analyst — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Luxury and Fashion Marketing & Customer Experience — Bordeaux, Lyon, Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Management & Conseil en Transformation Digitale & IA — Paris : 28/09/2026 → **28/09/2027** (12 090 €)
- IMSc - M1 - Management & Marketing des Industries Agroalimentaires — Paris : 05/10/2026 → **05/10/2027** (12 090 €)
- IMSc - M1 - Management & Marketing des Industries Pharmaceutiques — Paris : 05/10/2026 → **05/10/2027** (12 090 €)
- IMSc - M1 - Management Commercial & Marketing du Vin — Bordeaux : 19/10/2026 → **19/10/2027** (12 090 €)
- IMSc - M1 - Management International — Chambéry, Marseille, Rennes, Toulouse : 19/10/2026 → **19/10/2027** (13 350 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Management de Projet & Ingénierie Commerciale — Bordeaux, Chambéry, Lyon, Paris, Rennes, Toulouse : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Management, Conseil & Stratégie — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Manager Financier, Banque & Assurance — Bordeaux, Marseille, Paris : 12/10/2026 → **12/10/2027** (12 990 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Manager des Ressources Humaines — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Manager du Développement Durable & de la Transition Ecologique — Bordeaux, Paris : 05/10/2026 → **05/10/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Manager en Data Marketing — Bordeaux, Chambéry, Lyon, Marseille, Paris : 28/09/2026 → **28/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Marchés Financiers, Trading & Risk Management — Paris : 12/10/2026 → **12/10/2027** (12 990 €)
- IMSc - M1 - Marketing & Brand Management — Bordeaux, Lyon, Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Marketing Digital & E-Commerce — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 28/09/2026 → **28/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Marketing de la Santé & Innovation — Paris : 05/10/2026 → **05/10/2027** (12 090 €)
- IMSc - M1 - Marketing du Luxe et de la Mode & Expérience Client — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Marketing du Sport & Expérience Client — Bordeaux, Chambéry, Lyon, Marseille, Paris : 28/09/2026 → **28/09/2027** (12 090 €)
- IMSc - M1 - Marketing du Sport Outdoor & Expérience Client — Chambéry : 07/09/2026 → **07/09/2027** (12 090 €)
- IMSc - M1 - Marketing, Communication & Stratégie de Marque — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 28/09/2026 → **28/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M1 - Project Management — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Purchasing & Supply Chain Management — Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - QHSE - Management de la Qualité & Gestion de Projet — Paris : 05/10/2026 → **05/10/2027** (12 090 €)
- IMSc - M1 - Risk Management, Contrôle & Compliance — Paris : 12/10/2026 → **12/10/2027** (12 990 €)
- IMSc - M1 - Spirits Marketing & Business Development — Bordeaux : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M1 - Start-Up & Transformation Digitale — Bordeaux, Lyon, Marseille, Paris : 05/10/2026 → **05/10/2027** (12 090 €)
- IMSc - M1 - Wine Marketing & Business Development — Bordeaux, Paris : 19/10/2026 → **19/10/2027** (13 350 €)
- IMSc - M2 - Achats & Supply Chain Management — Bordeaux, Chambéry, Lyon, Marseille, Paris : 05/10/2026 → **05/10/2027** (14 850 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Analyse Financière Internationale — Bordeaux, Lyon, Paris : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Audit & Contrôle de Gestion — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Banque d’Affaires & Ingénierie Financière — Bordeaux, Paris : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Business Development & Ingénierie d’affaires — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Business Development - Trade Marketing & Distribution — Bordeaux, Lyon, Marseille, Paris : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Communication, Marketing d'Influence & RP — Bordeaux, Chambéry, Lyon, Marseille, Paris : 21/09/2026 → **21/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Communication, Publicité & Stratégie Digitale — Bordeaux, Chambéry, Lyon, Marseille, Paris : 21/09/2026 → **21/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Digital Marketing & E-Commerce — Paris : 05/10/2026 → **05/10/2027** (14 850 €)
- IMSc - M2 - Directeur des Etablissements de Santé — Bordeaux, Lyon, Marseille, Paris : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Expert en management immobilier — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes : 28/09/2026 → **28/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Finance d’Entreprise & Ingénierie Financière — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Fiscalité, Droit des Affaires, Conseil & Gestion d’Entreprise — Bordeaux, Lyon, Paris : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Gestionnaire patrimoine — Bordeaux, Chambéry, Lyon, Marseille, Paris : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Hospitality Management, Marketing du Tourisme & Expérience Client — Bordeaux, Lyon, Paris : 05/10/2026 → **05/10/2027** (14 850 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Human Resources Manager — Paris : 14/09/2026 → **14/09/2027** (14 850 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - International Business Management — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 05/10/2026 → **05/10/2027** (14 850 €)
- IMSc - M2 - International Financial Analyst — Paris : 05/10/2026 → **05/10/2027** (14 850 €)
- IMSc - M2 - Luxury and Fashion Marketing & Customer Experience — Bordeaux, Lyon, Paris : 05/10/2026 → **05/10/2027** (17 250 €)
- IMSc - M2 - Management Commercial & Marketing du Vin — Bordeaux, Lyon : 05/10/2026 → **05/10/2027** (17 250 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Management de Projet & Ingénierie Commerciale — Bordeaux, Chambéry, Lyon, Paris, Rennes : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Management, Conseil & Stratégie — Bordeaux, Chambéry, Lyon, Marseille, Paris, Toulouse : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Manager Financier, Banque & Assurance — Bordeaux, Marseille, Paris, Toulouse : 28/09/2026 → **28/09/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Manager des Ressources Humaines — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Manager du Développement Durable & de la Transition Ecologique — Bordeaux, Paris : 14/09/2026 → **14/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Manager en Data Marketing — Bordeaux, Lyon, Marseille, Paris : 21/09/2026 → **21/09/2027** (14 150 €) ; Chambéry : 21/09/2026 → **21/09/2027** (12 090 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Marchés Financiers, Trading & Risk Management — Paris : 05/10/2026 → **05/10/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Marketing & Brand Management — Bordeaux, Lyon : 05/10/2026 → **05/10/2027** (14 850 €) ; Paris : 21/09/2026 → **21/09/2027** (14 850 €)
- IMSc - M2 - Marketing Digital & E-Commerce — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 21/09/2026 → **21/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Marketing du Luxe et de la Mode & Expérience Client — Paris : 05/10/2026 → **05/10/2027** (17 250 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Marketing du Sport & Expérience Client — Bordeaux, Chambéry, Marseille : 21/09/2026 → **21/09/2027** (14 150 €) ; Lyon, Paris : 05/10/2026 → **05/10/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Marketing du Sport Outdoor & Expérience Client — Chambéry : 21/09/2026 → **21/09/2027** (14 150 €)
- IMSc - M2 - Marketing, Communication & Stratégie de Marque — Bordeaux, Chambéry, Lyon, Marseille, Paris, Rennes, Toulouse : 21/09/2026 → **21/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Risk Management, Contrôle & Compliance — Paris : 05/10/2026 → **05/10/2027** (14 690 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Spirits Marketing & Business Development — Bordeaux : 05/10/2026 → **05/10/2027** (17 250 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Start-Up & Transformation Digitale — Bordeaux, Lyon, Marseille : 14/09/2026 → **14/09/2027** (14 150 €) ; Paris : 21/09/2026 → **21/09/2027** (14 150 €) — *a aussi une rentrée décalée 2027*
- IMSc - M2 - Wine Marketing & Business Development — Bordeaux, Paris : 05/10/2026 → **05/10/2027** (17 250 €)
- INSEEC - AN4 - MScCGE - Sustainable Tourism — Paris : 01/09/2026 → **01/09/2027** (prix non publié)
- INSEEC MSc CGE - AN5 - International Business Management - 100% English — Paris : 04/09/2026 → **04/09/2027** (10 650 €)
- INSEEC MSc CGE - AN5 - Sustainable Tourism — Paris : 04/09/2026 → **04/09/2027** (prix non publié)
- INSEEC MSc CGE / PGE - AN4 - International Business Management - 100% English (Double diplôme) — Paris : 01/09/2026 → **01/09/2027** (10 650 €)
- PGE - AN3 — Bordeaux, Lyon : 03/09/2026 → **03/09/2027** (13 650 €) ; Paris : 04/09/2026 → **04/09/2027** (13 650 €)
- PGE - AN4 - 100% English - Pré spécialisation Finance — Paris : 01/09/2026 → **01/09/2027** (14 290 €)
- PGE - AN4 - 100% English - Pré spécialisation Management — Paris : 01/09/2026 → **01/09/2027** (14 290 €)
- PGE - AN4 - Pré spécialisation Finance — Bordeaux, Lyon, Paris : 01/09/2026 → **01/09/2027** (14 290 €)
- PGE - AN4 - Pré spécialisation Management — Bordeaux, Lyon, Paris : 01/09/2026 → **01/09/2027** (14 290 €)
- PGE - AN4 - Pré spécialisation Marketing — Bordeaux, Lyon, Paris : 01/09/2026 → **01/09/2027** (14 290 €)

### Sup de Pub (26 formations, 73 offres)

- SDP - SP1 - Communication, Marketing Digital et Création — Bordeaux, Lyon : 29/09/2026 → **29/09/2027** (9 050 €) ; Paris : 29/09/2026 → **29/09/2027** (9 250 €)
- SDP - SP4 - Brand Experience & Event - 100% English — Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Communication Publicitaire et Stratégie Média — Bordeaux, Lyon, Marseille, Rennes, Toulouse : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Communication and Media Strategy - Luxury - 100% English — Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Communication du Luxe — Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Communication et Marketing des Industries Culturelles et Créatives — Lyon : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - E-business et Data marketing — Lyon : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Expérience de Marque et Evénementiel — Bordeaux, Lyon, Marseille, Rennes, Toulouse : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Marketing digital et Stratégie Social Média — Bordeaux, Lyon, Rennes, Toulouse : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Production visuelle - Communication Publicitaire et Stratégie Média - Classe dédiée — Bordeaux : 18/09/2026 → **18/09/2027** (11 490 €) ; Lyon, Rennes, Toulouse : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Relations Publics et Influence — Bordeaux, Lyon : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Stratégie Créative et Planning Stratégique — Bordeaux, Lyon : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Stratégie de Contenus et Conception Rédaction — Bordeaux : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP4 - Traffic Management et Régie Média — Lyon : 02/10/2026 → **02/10/2027** (11 490 €) ; Paris : 02/10/2026 → **02/10/2027** (11 690 €)
- SDP - SP5 - Communication Corporate et Relations Publics — Bordeaux, Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Communication des Industries Culturelles et Créatives — Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Communication du Luxe et de la Mode — Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Communication et Production Visuelle — Bordeaux, Rennes, Toulouse : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Communication et Stratégie Média — Bordeaux, Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Creative strategies and strategic planning - 100% English — Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Data Marketing et IA — Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Marketing digital et e-commerce — Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Planning Stratégique et Stratégie Créative — Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Stratégie de Contenu et Brand Culture — Bordeaux, Lyon : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Stratégie digitale et social média — Lyon, Rennes : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
- SDP - SP5 - Stratégie et Production Evénementielle — Bordeaux, Lyon, Rennes, Toulouse : 25/09/2026 → **25/09/2027** (12 090 €) ; Paris : 25/09/2026 → **25/09/2027** (12 290 €)
