 
// ─────────────────────────────────────────────────────────────────────────────
// AUTO-GENERATED — KPB "Parcours & Témoignages" seed data.
//
// Sources merged & enriched from the two original KPB apps:
//   • kind:"video"  → 55 curated bilingual videos (Vidéos_et_Tags_FR_EN.xlsx)
//   • kind:"text"   → written Q&A interviews imported from the first KPB app's
//                     MongoDB backup (collection `exemplesdeparcours`), HTML-
//                     sanitized, with person-level duplicates of the videos
//                     removed (Fadji Maina, Tahirou Hamani, Moussa Sanoussi).
//
// `fieldId` maps to the catalog field domains (d01..d12). Regenerate rather
// than hand-editing bulk changes. Editable in the admin panel once seeded.
// ─────────────────────────────────────────────────────────────────────────────

export interface ParcoursQa {
  question: string;
  answer: string;
}

export interface ParcoursSeedItem {
  slug: string;
  kind: 'video' | 'text';
  fieldId: string | null;
  tags: string[];
  personName: string;
  roleFr: string;
  roleEn: string;
  titleFr: string;
  titleEn: string;
  hookFr: string;
  hookEn: string;
  summaryFr: string;
  summaryEn: string;
  thumbnailUrl: string;
  photoUrl: string;
  youtubeId: string | null;
  durationMinutes: number | null;
  interviewFr: ParcoursQa[] | null;
  interviewEn: ParcoursQa[] | null;
  status: 'draft' | 'published' | 'archived';
  isActive: boolean;
  featured: boolean;
  displayOrder: number;
  popularity: number;
  source: string;
}

export const PARCOURS_SEED: ParcoursSeedItem[] = [
  {
    "slug": "v-becoming-an-airline-pilot-with-a-scholarship-journey-funding-Gijdfc",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Aviation",
      "Pilote de Ligne",
      "Bourse d'Études",
      "Financement",
      "Orientation"
    ],
    "personName": "",
    "roleFr": "Pilote de ligne",
    "roleEn": "Airline Pilot",
    "titleFr": "Devenir pilote de ligne grâce à une bourse : parcours, financement, conseils",
    "titleEn": "Becoming an Airline Pilot with a Scholarship: Journey, Funding, Advice",
    "hookFr": "Devenir pilote de ligne grâce à une bourse : parcours, financement et conseils.",
    "hookEn": "Become an airline pilot on a scholarship: the path, the funding, the advice.",
    "summaryFr": "Découvrez le parcours inspirant de quelqu'un qui a réalisé son rêve de devenir pilote d'avion grâce à une bourse d'études. Cette vidéo explore les étapes clés, les options de financement disponibles, et les conseils pratiques pour poursuivre une carrière dans l'aviation. Un témoignage motivant pour les jeunes intéressés par le secteur aérien.",
    "summaryEn": "Discover the inspiring journey of someone who realized their dream of becoming an airline pilot through a scholarship. This video explores key steps, available funding options, and practical advice for pursuing a career in aviation. A motivating testimonial for young people interested in the aviation sector.",
    "thumbnailUrl": "https://img.youtube.com/vi/Gijdfc_aOC8/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Gijdfc_aOC8",
    "durationMinutes": 60,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 0,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-pilot-training-in-canada-the-path-to-airlines-624vfJ",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Aviation",
      "Pilote De Ligne",
      "Étudier Au Canada",
      "Formation Professionnelle",
      "Orientation"
    ],
    "personName": "",
    "roleFr": "Pilote de ligne",
    "roleEn": "Airline Pilot",
    "titleFr": "Se former comme pilote au Canada : la voie vers les compagnies aériennes",
    "titleEn": "Pilot Training in Canada: The Path to the Airlines",
    "hookFr": "Devenez pilote de ligne : le parcours complet pour se former au Canada.",
    "hookEn": "Become an airline pilot: the full path to training in Canada.",
    "summaryFr": "Explorez les différentes voies de formation pour devenir pilote au Canada. Cette vidéo détaille le parcours académique, les écoles de formation reconnues, les certifications requises et les débouchés professionnels. Un guide complet pour comprendre comment accéder à cette carrière prestigieuse.",
    "summaryEn": "Explore the different training paths to become a pilot in Canada. This video details the academic journey, recognized flight schools, required certifications, and career prospects. A comprehensive guide to understanding how to access this prestigious career.",
    "thumbnailUrl": "https://img.youtube.com/vi/624vfJYX4V8/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "624vfJYX4V8",
    "durationMinutes": 13,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 1,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-how-i-got-a-job-at-google-testimonial-tips-l_0UPS",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Google",
      "Tech",
      "Témoignage",
      "Carrière",
      "Conseils"
    ],
    "personName": "",
    "roleFr": "Ingénieur chez Google",
    "roleEn": "Software Engineer at Google",
    "titleFr": "Comment j'ai décroché un job chez Google : témoignage et conseils",
    "titleEn": "How I Got a Job at Google: Testimonial and Tips",
    "hookFr": "Il a décroché un job chez Google : son parcours et ses conseils pour y arriver.",
    "hookEn": "He landed a job at Google: his path and the tips that got him there.",
    "summaryFr": "Un témoignage captivant d'un professionnel qui a décroché un emploi chez Google. Découvrez son parcours académique, les compétences clés qu'il a développées, les défis rencontrés et les conseils pratiques pour réussir dans les grandes entreprises technologiques. Inspirant pour les aspirants tech.",
    "summaryEn": "A captivating testimonial from a professional who landed a job at Google. Discover their academic background, key skills developed, challenges faced, and practical advice for succeeding in major tech companies. Inspiring for aspiring tech professionals.",
    "thumbnailUrl": "https://img.youtube.com/vi/l_0UPSeH5sU/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "l_0UPSeH5sU",
    "durationMinutes": 77,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 2,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-rebroadcast-inspiring-journey-of-a-young-togolese-at-seattle-nZojVF",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Microsoft",
      "Témoignage",
      "Tech",
      "Études aux États-Unis",
      "Parcours Inspirant"
    ],
    "personName": "",
    "roleFr": "Ingénieur chez Microsoft",
    "roleEn": "Engineer at Microsoft",
    "titleFr": "Parcours inspirant d'un jeune Togolais à Seattle chez Microsoft",
    "titleEn": "Inspiring Journey of a Young Togolese at Microsoft in Seattle",
    "hookFr": "De Lomé à Seattle : comment un jeune Togolais a décroché un poste chez Microsoft.",
    "hookEn": "From Togo to Seattle: how a young man landed a job at Microsoft.",
    "summaryFr": "Le parcours extraordinaire d'un jeune Togolais qui a réussi à travailler chez Microsoft à Seattle. Cette rediffusion explore sa formation, son processus de candidature international, son adaptation à la vie aux États-Unis et les leçons apprises. Une source d'inspiration pour les jeunes africains.",
    "summaryEn": "The extraordinary journey of a young Togolese who successfully worked at Microsoft in Seattle. This rebroadcast explores their training, international application process, adaptation to life in the United States, and lessons learned. A source of inspiration for young Africans.",
    "thumbnailUrl": "https://img.youtube.com/vi/nZojVF0w_Bs/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "nZojVF0w_Bs",
    "durationMinutes": 54,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 3,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-building-a-successful-career-with-anne-rachel-inne-senior-vi-wXk7xq",
    "kind": "video",
    "fieldId": "d02",
    "tags": [
      "Leadership",
      "Carrière",
      "Management",
      "Développement Professionnel",
      "Femmes Leaders"
    ],
    "personName": "Anne-Rachel Inné",
    "roleFr": "Vice-Présidente Senior",
    "roleEn": "Senior Vice President",
    "titleFr": "Construire une carrière réussie avec Anne-Rachel Inné, VP Senior",
    "titleEn": "Building a Successful Career with Anne-Rachel Inné, Senior VP",
    "hookFr": "Ses stratégies pour gravir les échelons et diriger dans les grandes organisations.",
    "hookEn": "Her strategies to climb the ladder and lead in major organizations.",
    "summaryFr": "Une conversation enrichissante avec Anne-Rachel Inné, Vice-Présidente Senior, sur la construction d'une carrière de succès. Découvrez les stratégies de développement professionnel, la gestion de carrière, le leadership et les clés pour progresser dans les grandes organisations.",
    "summaryEn": "An enriching conversation with Anne-Rachel Inné, Senior Vice President, on building a successful career. Discover professional development strategies, career management, leadership, and keys to progressing in major organizations.",
    "thumbnailUrl": "https://img.youtube.com/vi/wXk7xqemrcE/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "wXk7xqemrcE",
    "durationMinutes": 78,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 4,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-his-journey-from-software-engineer-to-product-manager-at-ama-zuGS64",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Product Management",
      "Ingénierie Logicielle",
      "Amazon",
      "AWS",
      "Reconversion Tech"
    ],
    "personName": "",
    "roleFr": "Product Manager chez AWS",
    "roleEn": "Product Manager at AWS",
    "titleFr": "D'ingénieur logiciel à Product Manager chez Amazon Web Services",
    "titleEn": "From Software Engineer to Product Manager at Amazon Web Services",
    "hookFr": "D'ingénieur logiciel à Product Manager chez Amazon : le pivot qui change une carrière tech.",
    "hookEn": "From software engineer to Product Manager at Amazon: the pivot that reshapes a tech career.",
    "summaryFr": "Suivez le parcours d'un ingénieur logiciel qui a évolué vers un poste de Product Manager chez Amazon Web Services. Explorez les compétences transversales nécessaires, les défis de la transition et les opportunités de croissance dans les entreprises technologiques majeures.",
    "summaryEn": "Follow the journey of a software engineer who evolved into a Product Manager role at Amazon Web Services. Explore the cross-functional skills needed, challenges of the transition, and growth opportunities in major tech companies.",
    "thumbnailUrl": "https://img.youtube.com/vi/zuGS64vd10I/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "zuGS64vd10I",
    "durationMinutes": 68,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 5,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-parcoursup-2022-important-parcoursup-tips-for-international--tGkg9Y",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Parcoursup",
      "Orientation",
      "Études en France",
      "Candidature",
      "Étudiants Étrangers"
    ],
    "personName": "",
    "roleFr": "Guide d'orientation Parcoursup",
    "roleEn": "Parcoursup Orientation Guide",
    "titleFr": "Parcoursup 2022 : conseils essentiels pour les étudiants étrangers",
    "titleEn": "Parcoursup 2022: Key Tips for International Students",
    "hookFr": "Parcoursup 2022 : le mode d'emploi complet pour candidater depuis l'étranger sans faux pas.",
    "hookEn": "Parcoursup 2022: the full playbook to apply from abroad without costly mistakes.",
    "summaryFr": "Des conseils essentiels pour les étudiants étrangers naviguant dans le système Parcoursup 2022. Cette vidéo couvre les étapes d'inscription, les stratégies de candidature, les pièges à éviter et les ressources disponibles pour les candidats internationaux.",
    "summaryEn": "Essential advice for international students navigating the Parcoursup 2022 system. This video covers registration steps, application strategies, pitfalls to avoid, and available resources for international applicants.",
    "thumbnailUrl": "https://img.youtube.com/vi/tGkg9YMeYnk/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "tGkg9YMeYnk",
    "durationMinutes": 60,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 6,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-parcoursup-and-campus-france-canada-usa-guidance-q-a-h1npFs",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Parcoursup",
      "Campus France",
      "Orientation",
      "Études à l'étranger",
      "Questions-Réponses"
    ],
    "personName": "",
    "roleFr": "Conseiller en orientation",
    "roleEn": "Guidance Counselor",
    "titleFr": "Parcoursup et Campus France, Canada, USA : orientation, questions-réponses",
    "titleEn": "Parcoursup and Campus France, Canada, USA: Guidance Q&A",
    "hookFr": "Parcoursup, Campus France, Canada, USA : toutes tes questions d'orientation enfin répondues.",
    "hookEn": "Parcoursup, Campus France, Canada, USA: all your study-abroad questions answered.",
    "summaryFr": "Une session de questions-réponses complète sur Parcoursup et Campus France, avec des informations sur les candidatures au Canada et aux États-Unis. Découvrez les différentes voies d'accès, les critères d'admission et les conseils d'orientation pour vos études supérieures.",
    "summaryEn": "A comprehensive Q&A session on Parcoursup and Campus France, with information about applications to Canada and the United States. Discover different access routes, admission criteria, and guidance tips for your higher education.",
    "thumbnailUrl": "https://img.youtube.com/vi/h1npFsMSvMU/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "h1npFsMSvMU",
    "durationMinutes": 41,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 7,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-career-example-software-engineer-at-microsoft-samira-fk6_Oi",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Ingénierie Logicielle",
      "Microsoft",
      "Tech",
      "Témoignage",
      "Parcours Professionnel"
    ],
    "personName": "Samira",
    "roleFr": "Ingénieure logiciel chez Microsoft",
    "roleEn": "Software Engineer at Microsoft",
    "titleFr": "Ingénieure logiciel chez Microsoft : le parcours de Samira",
    "titleEn": "Software Engineer at Microsoft: Samira's Career",
    "hookFr": "De la formation à Microsoft : Samira dévoile les clés pour percer dans la tech.",
    "hookEn": "From training to Microsoft: Samira reveals how to break into big tech.",
    "summaryFr": "Le parcours professionnel de Samira, ingénieur logiciel chez Microsoft. Explorez sa formation, ses expériences clés, les compétences techniques et soft skills développées, et les conseils pour réussir dans les grandes entreprises technologiques.",
    "summaryEn": "Samira's professional journey as a software engineer at Microsoft. Explore her training, key experiences, technical and soft skills developed, and advice for succeeding in major tech companies.",
    "thumbnailUrl": "https://img.youtube.com/vi/fk6_Oi5Fomo/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "fk6_Oi5Fomo",
    "durationMinutes": 69,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 8,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-an-amazing-journey-becoming-a-software-engineer-at-google-ha-d7-j9E",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Google",
      "Ingénierie Logicielle",
      "Informatique",
      "Témoignage",
      "Carrière Tech"
    ],
    "personName": "Hamza",
    "roleFr": "Ingénieur logiciel chez Google",
    "roleEn": "Software Engineer at Google",
    "titleFr": "Devenir ingénieur logiciel chez Google : le parcours de Hamza",
    "titleEn": "Becoming a Software Engineer at Google: Hamza's Journey",
    "hookFr": "De ses études au poste d'ingénieur chez Google : le parcours de Hamza, étape par étape.",
    "hookEn": "From studies to a Google engineer role: Hamza's journey, step by step.",
    "summaryFr": "L'histoire incroyable de Hamza qui est devenu ingénieur logiciel chez Google. Découvrez son parcours académique, son processus de candidature, les défis surmontés et les stratégies qui l'ont mené au succès dans l'une des plus grandes entreprises technologiques du monde.",
    "summaryEn": "Hamza's incredible story of becoming a software engineer at Google. Discover his academic background, application process, challenges overcome, and strategies that led him to success at one of the world's largest tech companies.",
    "thumbnailUrl": "https://img.youtube.com/vi/d7-j9ENQVEM/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "d7-j9ENQVEM",
    "durationMinutes": 77,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 9,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-wednesday-live-guidance-campus-france-interview-and-parcours-aoKYx6",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Campus France",
      "Parcoursup",
      "Orientation",
      "Études en France",
      "Admission"
    ],
    "personName": "",
    "roleFr": "Experts orientation Campus France",
    "roleEn": "Campus France guidance experts",
    "titleFr": "Live orientation : entretien Campus France et dossier Parcoursup",
    "titleEn": "Live Guidance: Campus France Interview and Parcoursup Application",
    "hookFr": "Entretien Campus France et dossier Parcoursup : les conseils d'experts pour réussir ta candidature.",
    "hookEn": "Campus France interview and Parcoursup file: expert tips to nail your application.",
    "summaryFr": "Un live session d'orientation du mercredi avec des experts de Campus France. Explorez les questions fréquentes sur les candidatures, le processus d'admission et recevez des conseils personnalisés pour votre dossier Parcoursup.",
    "summaryEn": "A Wednesday live guidance session with Campus France experts. Explore frequently asked questions about applications, the admission process, and receive personalized advice for your Parcoursup file.",
    "thumbnailUrl": "https://img.youtube.com/vi/aoKYx6FhQy0/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "aoKYx6FhQy0",
    "durationMinutes": 44,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 10,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-career-example-principal-director-insights-data-capgemini-ca-Xt4c3I",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Data Analytics",
      "Conseil Tech",
      "Gestion de Projet",
      "Carrière au Canada",
      "Leadership"
    ],
    "personName": "",
    "roleFr": "Directeur Insights & Data",
    "roleEn": "Principal Director, Insights & Data",
    "titleFr": "Principal Director Insights & Data chez Capgemini Canada",
    "titleEn": "Principal Director, Insights & Data at Capgemini Canada",
    "hookFr": "De la data au conseil : le parcours vers un poste de direction chez Capgemini Canada.",
    "hookEn": "From data to consulting: the path to a director role at Capgemini Canada.",
    "summaryFr": "Découvrez le parcours professionnel d'un Principal Director - Insights & Data chez Capgemini Canada. Explorez les compétences en data analytics, la gestion de projets complexes et les opportunités de carrière dans le secteur du conseil technologique.",
    "summaryEn": "Discover the professional journey of a Principal Director - Insights & Data at Capgemini Canada. Explore data analytics skills, complex project management, and career opportunities in the tech consulting sector.",
    "thumbnailUrl": "https://img.youtube.com/vi/Xt4c3IX9pr4/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Xt4c3IX9pr4",
    "durationMinutes": 62,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 11,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-career-example-global-customer-support-manager-OKhvHE",
    "kind": "video",
    "fieldId": "d02",
    "tags": [
      "Management",
      "Support Client",
      "Communication Interculturelle",
      "Gestion d'Équipe",
      "Carrière Internationale"
    ],
    "personName": "",
    "roleFr": "Responsable Support Client International",
    "roleEn": "Global Customer Support Manager",
    "titleFr": "Responsable support client international : le parcours",
    "titleEn": "Global Customer Support Manager: A Career Example",
    "hookFr": "Gérer des équipes à l'international : découvre le métier de responsable support client global.",
    "hookEn": "Lead teams worldwide: discover what it takes to become a Global Customer Support Manager.",
    "summaryFr": "Un exemple de parcours professionnel d'un Global Customer Support Manager. Explorez les compétences en gestion d'équipe, la communication interculturelle et les opportunités de croissance dans les rôles de support client international.",
    "summaryEn": "A professional journey example of a Global Customer Support Manager. Explore team management skills, intercultural communication, and growth opportunities in international customer support roles.",
    "thumbnailUrl": "https://img.youtube.com/vi/OKhvHEsqfPQ/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "OKhvHEsqfPQ",
    "durationMinutes": 56,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 12,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-parcoursup-2023-how-to-create-your-application-file-from-a-t-N4V8Zf",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Parcoursup",
      "Orientation",
      "Admission",
      "Études en France",
      "Conseils"
    ],
    "personName": "",
    "roleFr": "Guide d'orientation Parcoursup",
    "roleEn": "Parcoursup Application Guide",
    "titleFr": "Parcoursup 2023 : comment créer son dossier de A à Z",
    "titleEn": "Parcoursup 2023: How to Build Your Application from A to Z",
    "hookFr": "Parcoursup 2023 : crée ton dossier de A à Z et maximise tes chances d'admission.",
    "hookEn": "Parcoursup 2023: build your application from A to Z and boost your admission odds.",
    "summaryFr": "Un guide complet pour créer votre dossier Parcoursup 2023 de A à Z. Découvrez les étapes essentielles, les documents requis, les stratégies de rédaction et les conseils pour maximiser vos chances d'admission.",
    "summaryEn": "A comprehensive guide to creating your Parcoursup 2023 application file from start to finish. Discover essential steps, required documents, writing strategies, and tips to maximize your admission chances.",
    "thumbnailUrl": "https://img.youtube.com/vi/N4V8Zf0PV2w/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "N4V8Zf0PV2w",
    "durationMinutes": 48,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 13,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-video-games-magazine-discover-teddy-kossoko-s-journey-game-c-JheCv6",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Jeu Vidéo",
      "Entrepreneuriat",
      "Témoignage",
      "Industrie Créative",
      "Développement"
    ],
    "personName": "Teddy Kossoko",
    "roleFr": "Créateur de jeux vidéo",
    "roleEn": "Video Game Creator",
    "titleFr": "Le parcours de Teddy Kossoko, créateur de jeux vidéo",
    "titleEn": "Teddy Kossoko's Journey, Video Game Creator",
    "hookFr": "De l'idée au jeu : le parcours de Teddy Kossoko dans l'industrie du jeu vidéo.",
    "hookEn": "From idea to game: Teddy Kossoko's path in the booming video game industry.",
    "summaryFr": "Un magazine spécial jeux vidéo présentant le parcours de Teddy Kossoko, créateur de jeux. Explorez son cheminement dans l'industrie du jeu vidéo, les compétences requises, les défis créatifs et les opportunités dans ce secteur en pleine expansion.",
    "summaryEn": "A special video games magazine featuring Teddy Kossoko's journey as a game creator. Explore his path in the gaming industry, required skills, creative challenges, and opportunities in this rapidly expanding sector.",
    "thumbnailUrl": "https://img.youtube.com/vi/JheCv64gNSk/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "JheCv64gNSk",
    "durationMinutes": 42,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 14,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-logistique-et-supply-chain-management-parcours-debouches-sal-uYJS9H",
    "kind": "video",
    "fieldId": "d12",
    "tags": [
      "Logistique",
      "Supply Chain",
      "Débouchés",
      "Gestion De Projet",
      "Lean Six Sigma"
    ],
    "personName": "",
    "roleFr": "Chef de projet logistique",
    "roleEn": "Logistics Project Manager",
    "titleFr": "Logistique et supply chain management : parcours, débouchés, salaires",
    "titleEn": "Logistics and Supply Chain Management: Path, Prospects, Salaries",
    "hookFr": "Logistique et supply chain : quels parcours, quels débouchés et quels salaires ?",
    "hookEn": "Logistics and supply chain: which paths, which jobs, and what salaries?",
    "summaryFr": "Résumé pour Logistique et supply chain management : Parcours, débouchés, salaires: Ce contenu traite de Logistique et supply chain management, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Logistique et supply chain management : Parcours, débouchés, salaires: Ce contenu traite de Logistique et supply chain management, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/uYJS9HRFAxw/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "uYJS9HRFAxw",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 15,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-docteure-en-cancerologie-parcours-debouches-remunerat-Z4du74",
    "kind": "video",
    "fieldId": "d04",
    "tags": [
      "Cancérologie",
      "Recherche Médicale",
      "Doctorat",
      "Biologie",
      "Femmes en Science"
    ],
    "personName": "",
    "roleFr": "Docteure en cancérologie",
    "roleEn": "Doctor in Oncology",
    "titleFr": "Docteure en cancérologie : parcours, débouchés, rémunération",
    "titleEn": "Oncology Doctor: Path, Prospects, Pay, Experiences",
    "hookFr": "Docteure en cancérologie : parcours, débouchés et salaire pour percer dans la recherche médicale.",
    "hookEn": "Oncology doctor: the path, career options and pay to break into medical research.",
    "summaryFr": "Résumé pour Métier - Docteure en Cancérologie : Parcours, débouchés, rémunération, expériences: Ce contenu traite de Métier - Docteure en Cancérologie, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier - Docteure en Cancérologie : Parcours, débouchés, rémunération, expériences: Ce contenu traite de Métier - Docteure en Cancérologie, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/Z4du74ppf7g/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Z4du74ppf7g",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 16,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-comment-devenir-data-scientist-ou-data-analyst-metier-format-ApNFs9",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Data Science",
      "Intelligence Artificielle",
      "Big Data",
      "Machine Learning",
      "Orientation"
    ],
    "personName": "",
    "roleFr": "Data Scientist / Data Analyst",
    "roleEn": "Data Scientist / Data Analyst",
    "titleFr": "Devenir data scientist ou data analyst : métier, formation, salaire",
    "titleEn": "Becoming a Data Scientist or Data Analyst: Job, Training, Salary",
    "hookFr": "Métier, formation, salaire : tout pour devenir Data Scientist et percer dans l'IA et le Big Data.",
    "hookEn": "Career, training, salary: everything to become a Data Scientist and break into AI and Big Data.",
    "summaryFr": "Résumé pour COMMENT DEVENIR DATA SCIENTIST ou data analyst : métier, formation, salaire et Big Data !: Ce contenu traite de COMMENT DEVENIR DATA SCIENTIST ou data analyst, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour COMMENT DEVENIR DATA SCIENTIST ou data analyst : métier, formation, salaire et Big Data !: Ce contenu traite de COMMENT DEVENIR DATA SCIENTIST ou data analyst, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/ApNFs9n59g4/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "ApNFs9n59g4",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 17,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-travailler-a-la-silicon-valley-chez-facebook-comme-ingenieur-BvM_6b",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Génie Logiciel",
      "Silicon Valley",
      "Big Tech",
      "Carrière Tech",
      "Ingénieur Africain"
    ],
    "personName": "",
    "roleFr": "Ingénieur logiciel",
    "roleEn": "Software Engineer",
    "titleFr": "Travailler dans la Silicon Valley chez Facebook comme ingénieur logiciel",
    "titleEn": "Working in Silicon Valley at Facebook as a Software Engineer",
    "hookFr": "De l'Afrique à la Silicon Valley : ingénieur logiciel chez Facebook, c'est possible.",
    "hookEn": "From Africa to Silicon Valley: how to land a software engineer role at Facebook.",
    "summaryFr": "Résumé pour Travailler à la Silicon Valley Chez Facebook comme Ingénieur Logiciel: Ce contenu traite de Travailler à la Silicon Valley Chez Facebook comme Ingénieur Logiciel, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Travailler à la Silicon Valley Chez Facebook comme Ingénieur Logiciel: Ce contenu traite de Travailler à la Silicon Valley Chez Facebook comme Ingénieur Logiciel, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/BvM_6bFffKE/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "BvM_6bFffKE",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 18,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-travailler-a-la-nasa-les-conseils-de-dr-fadji-zaouna-maina-p-kYUHWh",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "NASA",
      "Hydrologie",
      "Recherche Scientifique",
      "Femmes En Science",
      "Doctorat"
    ],
    "personName": "Dr. Fadji Zaouna Maina",
    "roleFr": "Scientifique hydrologue à la NASA",
    "roleEn": "Hydrologist at NASA",
    "titleFr": "Travailler à la NASA : les conseils du Dr Fadji Zaouna Maïna",
    "titleEn": "Working at NASA: Advice from Dr. Fadji Zaouna Maïna",
    "hookFr": "Du Niger à la NASA : le parcours de la première Nigérienne à y travailler.",
    "hookEn": "From Niger to NASA: how the first Nigerien woman got there.",
    "summaryFr": "Travailler à la NASA : Les conseils de Dr. Fadji Zaouna Maina, première Nigérienne à la NASA : Dr. Maina est une scientifique spécialiste en hydrologie à la NASA Goddard Space Flight Center. Originaire du Niger, elle a obtenu un doctorat en hydrologie et a effectué des postdoctorats en France, en Italie et aux États-Unis avant de rejoindre la NASA. Son parcours témoigne de la persévérance, de la détermination et de l'importance de saisir les opportunités. Elle encourage les jeunes à viser haut, à chercher des bourses d'études et à ne jamais sous-estimer leur potentiel.",
    "summaryEn": "Travailler à la NASA : Les conseils de Dr. Fadji Zaouna Maina, première Nigérienne à la NASA : Dr. Maina est une scientifique spécialiste en hydrologie à la NASA Goddard Space Flight Center. Originaire du Niger, elle a obtenu un doctorat en hydrologie et a effectué des postdoctorats en France, en Italie et aux États-Unis avant de rejoindre la NASA. Son parcours témoigne de la persévérance, de la détermination et de l'importance de saisir les opportunités. Elle encourage les jeunes à viser haut, à chercher des bourses d'études et à ne jamais sous-estimer leur potentiel.",
    "thumbnailUrl": "https://img.youtube.com/vi/kYUHWhaeJiw/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "kYUHWhaeJiw",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 19,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-devenir-statisticien-ne-parcours-debouches-avec-rahan-TdadBP",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Statistiques",
      "Data Science",
      "Analyse de Données",
      "Mathématiques",
      "Débouchés"
    ],
    "personName": "Rahana",
    "roleFr": "Statisticienne",
    "roleEn": "Statistician",
    "titleFr": "Devenir statisticien·ne : parcours et débouchés, avec Rahana",
    "titleEn": "Becoming a Statistician: Path and Prospects, with Rahana",
    "hookFr": "Faire parler les chiffres : découvre le métier de statisticien.ne, ses parcours et ses débouchés.",
    "hookEn": "Making numbers talk: discover the statistician's job, training paths and career prospects.",
    "summaryFr": "Résumé pour [METIER] DEVENIR Statisticien.ne, parcours, débouchés - avec Rahana qui fait parler les chiffres: Ce contenu traite de [METIER] DEVENIR Statisticien.ne, parcours, débouchés - avec Rahana qui fait parler les chiffres, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour [METIER] DEVENIR Statisticien.ne, parcours, débouchés - avec Rahana qui fait parler les chiffres: Ce contenu traite de [METIER] DEVENIR Statisticien.ne, parcours, débouchés - avec Rahana qui fait parler les chiffres, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/TdadBPNhqC4/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "TdadBPNhqC4",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 20,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-geomaticien-ne-un-metier-d-avenir-quest-ce-que-la-geo-u8yLWH",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Géomatique",
      "Cartographie",
      "Métier d'Avenir",
      "Femmes dans la Tech",
      "Données Géographiques"
    ],
    "personName": "",
    "roleFr": "Géomaticien.ne",
    "roleEn": "Geomatics Specialist",
    "titleFr": "Géomaticien·ne, un métier d'avenir : qu'est-ce que la géomatique ?",
    "titleEn": "Geomatician, a Career of the Future: What Is Geomatics?",
    "hookFr": "La géomatique : cartographie, data et fibre optique. Un métier d'avenir encore méconnu.",
    "hookEn": "Geomatics: maps, data and fiber optics. A future-proof career few students know about.",
    "summaryFr": "Résumé pour [METIER] Géomaticien.ne, un métier d'avenir : qu’est-ce que la géomatique?: Ce contenu traite de [METIER] Géomaticien.ne, un métier d'avenir, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour [METIER] Géomaticien.ne, un métier d'avenir : qu’est-ce que la géomatique?: Ce contenu traite de [METIER] Géomaticien.ne, un métier d'avenir, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/u8yLWHols74/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "u8yLWHols74",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 21,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-ingenieur-surete-nucleaire-parcours-salaire-debouches-6Q7Vkm",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Ingénierie",
      "Sûreté Nucléaire",
      "Femmes En Science",
      "Carrière Scientifique",
      "Industrie Nucléaire"
    ],
    "personName": "Rayana Mahaman",
    "roleFr": "Ingénieure sûreté nucléaire",
    "roleEn": "Nuclear Safety Engineer",
    "titleFr": "Ingénieur sûreté nucléaire : parcours, salaire, débouchés, avec Rayana",
    "titleEn": "Nuclear Safety Engineer: Path, Salary, Prospects, with Rayana",
    "hookFr": "Parcours, salaire et débouchés d'une ingénieure en sûreté nucléaire au CEA.",
    "hookEn": "Path, salary and career prospects of a nuclear safety engineer at the CEA.",
    "summaryFr": "Résumé pour Métier - Ingénieur Sûreté Nucléaire : Parcours, salaire, débouchés avec Rayana Mahaman: Ce contenu traite de Métier - Ingénieur Sûreté Nucléaire, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier - Ingénieur Sûreté Nucléaire : Parcours, salaire, débouchés avec Rayana Mahaman: Ce contenu traite de Métier - Ingénieur Sûreté Nucléaire, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/6Q7VkmFBldY/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "6Q7VkmFBldY",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 22,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-ingenieur-d-etudes-parcours-salaire-opportunite-est--qHbd1N",
    "kind": "video",
    "fieldId": "d05",
    "tags": [
      "Ingénierie",
      "Génie Civil",
      "BTP",
      "Femmes En Ingénierie",
      "Conseils De Carrière"
    ],
    "personName": "",
    "roleFr": "Ingénieure d'études en génie civil / BTP",
    "roleEn": "Design Engineer in Civil Engineering / Construction",
    "titleFr": "Devenir ingénieur d'études : parcours, salaire, opportunités",
    "titleEn": "Becoming a Design Engineer: Path, Salary, Opportunities",
    "hookFr": "Ingénieur d'études : parcours, salaire et opportunités. Et si c'était fait pour les femmes ?",
    "hookEn": "Design engineer: path, salary and opportunities. And yes, it's for women too.",
    "summaryFr": "Résumé pour DEVENIR Ingénieur d'études : parcours, salaire, opportunité, est-ce fait pour les femmes?: Ce contenu traite de DEVENIR Ingénieur d'études, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour DEVENIR Ingénieur d'études : parcours, salaire, opportunité, est-ce fait pour les femmes?: Ce contenu traite de DEVENIR Ingénieur d'études, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/qHbd1NBAodI/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "qHbd1NBAodI",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 23,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-avocat-en-france-parcours-specialisation-salaire-tSHStv",
    "kind": "video",
    "fieldId": "d07",
    "tags": [
      "Devenir Avocat",
      "Droit des Affaires",
      "Études en France",
      "CAPA",
      "Fusions-Acquisitions"
    ],
    "personName": "Moussa",
    "roleFr": "Avocat en droit des affaires",
    "roleEn": "Business Law Attorney",
    "titleFr": "Devenir avocat en France : parcours, spécialisation, salaire",
    "titleEn": "Becoming a Lawyer in France: Path, Specialization, Salary",
    "hookFr": "Devenir avocat en France : parcours, spécialisation et salaire décryptés",
    "hookEn": "Becoming a lawyer in France: path, specialization and salary decoded",
    "summaryFr": "Résumé pour Devenir AVOCAT en France : Parcours, spécialisation, salaire,: Ce contenu traite de Devenir AVOCAT en France, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir AVOCAT en France : Parcours, spécialisation, salaire,: Ce contenu traite de Devenir AVOCAT en France, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/tSHStvQDsP4/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "tSHStvQDsP4",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 24,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-expert-comptable-la-formation-debouches-le-salaire-e-nJyMZ-",
    "kind": "video",
    "fieldId": "d02",
    "tags": [
      "Expert-Comptable",
      "Comptabilité",
      "Audit",
      "DCG DSCG",
      "Débouchés"
    ],
    "personName": "",
    "roleFr": "Expert-comptable",
    "roleEn": "Chartered Accountant",
    "titleFr": "Devenir expert-comptable : formation, débouchés, salaire et quotidien",
    "titleEn": "Becoming a Chartered Accountant: Training, Prospects, Salary, Daily Life",
    "hookFr": "Expert-comptable : formation, salaire et quotidien du métier décryptés",
    "hookEn": "Chartered accountant: training, salary and daily life of the job revealed",
    "summaryFr": "Résumé pour DEVENIR EXPERT COMPTABLE : la formation, débouchés, le salaire et le quotidien du métier: Ce contenu traite de DEVENIR EXPERT COMPTABLE, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour DEVENIR EXPERT COMPTABLE : la formation, débouchés, le salaire et le quotidien du métier: Ce contenu traite de DEVENIR EXPERT COMPTABLE, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/nJyMZ-Szkto/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "nJyMZ-Szkto",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 25,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-consultante-si-architecture-des-systemes-d-informations-parc-AzsloR",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Systèmes d'Information",
      "Conseil IT",
      "Femme dans la Tech",
      "DUT Réseaux et Télécoms",
      "Carrière IT"
    ],
    "personName": "Olga Abdala",
    "roleFr": "Consultante en architecture des systèmes d'information",
    "roleEn": "Information Systems Architecture Consultant",
    "titleFr": "Consultante architecture des SI : parcours, salaire — Olga Abdala",
    "titleEn": "IT Systems Architecture Consultant: Path, Salary — Olga Abdala",
    "hookFr": "D'un DUT Réseaux à consultante SI : Olga révèle parcours, compétences et salaire dans l'IT.",
    "hookEn": "From a networks diploma to IT systems consultant: Olga reveals her path, skills and salary.",
    "summaryFr": "Résumé pour Consultante (SI) Architecture des systèmes d'informations, parcours, salaire - Olga Abdala: Ce contenu traite de Consultante (SI) Architecture des systèmes d'informations, parcours, salaire - Olga Abdala, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Consultante (SI) Architecture des systèmes d'informations, parcours, salaire - Olga Abdala: Ce contenu traite de Consultante (SI) Architecture des systèmes d'informations, parcours, salaire - Olga Abdala, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/AzsloR3YBEQ/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "AzsloR3YBEQ",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 26,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-devenir-ingenieur-maintenance-et-exploitation-avec-kh-jH46Ql",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Ingénierie",
      "Énergie Photovoltaïque",
      "Classes Préparatoires",
      "Métiers Techniques",
      "Bac Scientifique"
    ],
    "personName": "Khaled",
    "roleFr": "Ingénieur maintenance et exploitation (photovoltaïque)",
    "roleEn": "Maintenance and Operations Engineer (Solar)",
    "titleFr": "Devenir ingénieur maintenance et exploitation, avec Khaled",
    "titleEn": "Becoming a Maintenance and Operations Engineer, with Khaled",
    "hookFr": "Du bac scientifique aux prépas : Khaled raconte son métier d'ingénieur photovoltaïque.",
    "hookEn": "From science track to prep school: Khaled on life as a solar energy engineer.",
    "summaryFr": "Résumé pour Métier : Devenir Ingénieur Maintenance et Exploitation avec Khaled: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier : Devenir Ingénieur Maintenance et Exploitation avec Khaled: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/jH46Qlju650/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "jH46Qlju650",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 27,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-devenir-docteur-en-genie-civil-les-choses-a-savoir-av-24yxFG",
    "kind": "video",
    "fieldId": "d05",
    "tags": [
      "Génie Civil",
      "Doctorat",
      "Béton Armé",
      "Ingénieur",
      "Bac Scientifique"
    ],
    "personName": "",
    "roleFr": "Docteur en génie civil",
    "roleEn": "Doctor in Civil Engineering",
    "titleFr": "Devenir docteur en génie civil : ce qu'il faut savoir avant un doctorat",
    "titleEn": "Becoming a PhD in Civil Engineering: What to Know Before a Doctorate",
    "hookFr": "Doctorat en génie civil : ce qu'il faut savoir avant de se lancer.",
    "hookEn": "A PhD in civil engineering: what to know before you commit.",
    "summaryFr": "Résumé pour [METIER] Devenir Docteur en Génie Civil : Les choses à savoir avant de faire un doctorat: Ce contenu traite de [METIER] Devenir Docteur en Génie Civil, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour [METIER] Devenir Docteur en Génie Civil : Les choses à savoir avant de faire un doctorat: Ce contenu traite de [METIER] Devenir Docteur en Génie Civil, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/24yxFGr6pYU/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "24yxFGr6pYU",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 28,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-ingenieur-statisticien-economiste-formation-debouche-xGI7B-",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Statistiques",
      "Économie",
      "INSEA",
      "Mathématiques",
      "Femmes dans les STEM"
    ],
    "personName": "Lamiyatou",
    "roleFr": "Ingenieure Statisticienne Economiste",
    "roleEn": "Statistician-Economist Engineer",
    "titleFr": "Ingénieur statisticien économiste : formation et débouchés, avec Lamiyatou",
    "titleEn": "Statistician-Economist Engineer: Training and Prospects, with Lamiyatou",
    "hookFr": "De la prépa à l'INSEA : le parcours de Lamiyatou pour devenir ingénieure statisticienne.",
    "hookEn": "From prep school to INSEA: Lamiyatou's path to becoming a statistician-economist engineer.",
    "summaryFr": "Résumé pour Devenir Ingenieur Statisticien Economiste : Formation, débouchés avec le parcours de Lamiyatou.: Ce contenu traite de Devenir Ingenieur Statisticien Economiste, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir Ingenieur Statisticien Economiste : Formation, débouchés avec le parcours de Lamiyatou.: Ce contenu traite de Devenir Ingenieur Statisticien Economiste, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/xGI7B-FME3w/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "xGI7B-FME3w",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 29,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-devenir-docteur-en-traitement-d-image-ingenieur-innov-QgCgoU",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Traitement d'Image",
      "Robotique",
      "Vision Industrielle",
      "Innovation",
      "Femmes dans les STEM"
    ],
    "personName": "",
    "roleFr": "Ingénieur Innovation en vision industrielle et robotique",
    "roleEn": "Innovation Engineer in Industrial Vision and Robotics",
    "titleFr": "Docteur en traitement d'image / ingénieur vision industrielle et robotique",
    "titleEn": "PhD in Image Processing / Innovation Engineer in Industrial Vision & Robotics",
    "hookFr": "De la thèse en traitement d'image à l'innovation robotique : un métier tech d'avenir.",
    "hookEn": "From an image-processing PhD to robotics innovation: a tech career of the future.",
    "summaryFr": "Résumé pour Métier : Devenir Docteur En Traitement d'image/ Ingénieur Innovation Vision industrielle/Robotique: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier : Devenir Docteur En Traitement d'image/ Ingénieur Innovation Vision industrielle/Robotique: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/QgCgoUccZZM/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "QgCgoUccZZM",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 30,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-ingenieur-chimiste-la-formation-les-debouchees-le-sa-5SKOu3",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Ingénierie Chimique",
      "Débouchés",
      "Salaire",
      "Femmes dans les STEM",
      "Industrie Pharmaceutique"
    ],
    "personName": "Habsouta",
    "roleFr": "Ingénieure chimiste",
    "roleEn": "Chemical Engineer",
    "titleFr": "Devenir ingénieur chimiste : formation, débouchés, salaire, avec Habsouta",
    "titleEn": "Becoming a Chemical Engineer: Training, Prospects, Salary, with Habsouta",
    "hookFr": "Habsouta te dévoile la formation, les débouchés et le salaire d'ingénieur chimiste.",
    "hookEn": "Habsouta reveals the training, career prospects and salary of a chemical engineer.",
    "summaryFr": "Résumé pour Devenir Ingénieur Chimiste : La formation, les débouchées, le salaire avec Habsouta: Ce contenu traite de Devenir Ingénieur Chimiste, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir Ingénieur Chimiste : La formation, les débouchées, le salaire avec Habsouta: Ce contenu traite de Devenir Ingénieur Chimiste, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/5SKOu30TA0w/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "5SKOu30TA0w",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 31,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-entretien-avec-un-expert-en-securite-monetique-decouv-AG38VQ",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Sécurité Monétique",
      "Sécurité Informatique",
      "Secteur Bancaire",
      "Mobile Money",
      "Solutions De Paiement"
    ],
    "personName": "",
    "roleFr": "Expert en sécurité monétique",
    "roleEn": "Payment Security Expert",
    "titleFr": "Entretien avec un expert en sécurité monétique : découvre le métier",
    "titleEn": "Interview with a Payment Security Expert: Discover the Job",
    "hookFr": "Il sécurise chaque transaction bancaire : plonge dans le métier d'expert en sécurité monétique.",
    "hookEn": "He secures every bank transaction: discover the payment security expert career.",
    "summaryFr": "Résumé pour Métier : Entretien avec un Expert en Sécurité Monétique - Découvre ce métier: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier : Entretien avec un Expert en Sécurité Monétique - Découvre ce métier: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/AG38VQ62ACw/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "AG38VQ62ACw",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 32,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-comment-devenir-chirurgien-orthopediste-et-traumatologie-dec-Q2NNzs",
    "kind": "video",
    "fieldId": "d04",
    "tags": [
      "Médecine",
      "Chirurgie orthopédique",
      "Traumatologie",
      "Parcours médical",
      "Santé"
    ],
    "personName": "Dr Abdoul Wahab",
    "roleFr": "Chirurgien orthopédiste et traumatologue",
    "roleEn": "Orthopedic and Trauma Surgeon",
    "titleFr": "Chirurgien orthopédiste et traumatologue : le parcours du Dr Abdoul Wahab",
    "titleEn": "Orthopedic and Trauma Surgeon: Dr. Abdoul Wahab's Journey",
    "hookFr": "Le Dr Abdoul Wahab dévoile le parcours pour devenir chirurgien orthopédiste et traumatologue.",
    "hookEn": "Dr Abdoul Wahab reveals the path to becoming an orthopedic and trauma surgeon.",
    "summaryFr": "Résumé pour Comment devenir Chirurgien Orthopédiste et Traumatologie ? découvre le parcours du Dr Abdoul Wahab: Ce contenu traite de Comment devenir Chirurgien Orthopédiste et Traumatologie ? découvre le parcours du Dr Abdoul Wahab, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Comment devenir Chirurgien Orthopédiste et Traumatologie ? découvre le parcours du Dr Abdoul Wahab: Ce contenu traite de Comment devenir Chirurgien Orthopédiste et Traumatologie ? découvre le parcours du Dr Abdoul Wahab, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/Q2NNzsNbvno/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Q2NNzsNbvno",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 33,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-grace-a-mon-metier-je-connais-ton-salaire-mais-je-ne-dirai-r-aoi9VX",
    "kind": "video",
    "fieldId": "d02",
    "tags": [
      "Gestion de la Paie",
      "Entrepreneuriat",
      "Commerce International",
      "Conseils de Carrière",
      "Rémunération"
    ],
    "personName": "",
    "roleFr": "Spécialiste en gestion de la paie",
    "roleEn": "Payroll Specialist",
    "titleFr": "Grâce à mon métier, je connais ton salaire, mais je ne dirai rien !",
    "titleEn": "Thanks to My Job, I Know Your Salary, but I Won't Tell!",
    "hookFr": "Ce métier lui révèle ton salaire, mais il garde le secret. Découvre lequel.",
    "hookEn": "This job reveals everyone's salary, but stays silent. Find out which one.",
    "summaryFr": "Résumé pour Grâce à mon Métier je connais ton SALAIRE, mais je ne dirai RIEN!: Ce contenu traite de Grâce à mon Métier je connais ton SALAIRE, mais je ne dirai RIEN!, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Grâce à mon Métier je connais ton SALAIRE, mais je ne dirai RIEN!: Ce contenu traite de Grâce à mon Métier je connais ton SALAIRE, mais je ne dirai RIEN!, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/aoi9VXZHmUs/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "aoi9VXZHmUs",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 34,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-carriere-d-artiste-les-parcours-defis-et-opportunites-avec-k-uebBOq",
    "kind": "video",
    "fieldId": "d11",
    "tags": [
      "Musique",
      "Carriere Artistique",
      "Industrie Musicale",
      "Femmes dans la Musique",
      "Culture"
    ],
    "personName": "Kitary",
    "roleFr": "Artiste musical",
    "roleEn": "Music Artist",
    "titleFr": "Carrière d'artiste : parcours, défis et opportunités, avec Kitary",
    "titleEn": "An Artist's Career: Path, Challenges and Opportunities, with Kitary",
    "hookFr": "Vivre de sa musique : parcours, obstacles et opportunites d'une carriere d'artiste.",
    "hookEn": "Making a living from music: the path, the hurdles and the breaks of an artist's career.",
    "summaryFr": "Résumé pour Carrière d'artiste : les parcours, défis et opportunités avec Kitary et Majestic Soul MDM CREW: Ce contenu traite de Carrière d'artiste, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Carrière d'artiste : les parcours, défis et opportunités avec Kitary et Majestic Soul MDM CREW: Ce contenu traite de Carrière d'artiste, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/uebBOqpeW4Q/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "uebBOqpeW4Q",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 35,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-ingenieur-travaux-conducteur-de-travaux-parcours-debouches-s-vw6LmH",
    "kind": "video",
    "fieldId": "d05",
    "tags": [
      "Conducteur De Travaux",
      "BTP",
      "Ingénierie",
      "Débouchés",
      "Salaires"
    ],
    "personName": "",
    "roleFr": "Conducteur de travaux",
    "roleEn": "Construction Site Manager",
    "titleFr": "Ingénieur travaux / conducteur de travaux : parcours, débouchés, salaires",
    "titleEn": "Works Engineer / Site Manager: Path, Prospects, Salaries",
    "hookFr": "Ingénieur travaux : parcours, débouchés et salaires du conducteur de chantier.",
    "hookEn": "Construction site engineer: the path, the jobs, and the salaries revealed.",
    "summaryFr": "Résumé pour Ingénieur Travaux (Conducteur de Travaux) - Parcours, débouchés, salaires: Ce contenu traite de Ingénieur Travaux (Conducteur de Travaux) - Parcours, débouchés, salaires, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Ingénieur Travaux (Conducteur de Travaux) - Parcours, débouchés, salaires: Ce contenu traite de Ingénieur Travaux (Conducteur de Travaux) - Parcours, débouchés, salaires, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/vw6LmHa0jS0/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "vw6LmHa0jS0",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 36,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-devenir-responsable-des-produits-et-services-internet-Cw7Z4g",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Télécommunications",
      "Produits Internet",
      "Data & Digital",
      "Femmes dans la Tech",
      "Innovation"
    ],
    "personName": "Saadatou",
    "roleFr": "Responsable Produits & Services Internet (Airtel)",
    "roleEn": "Internet Products & Services Manager (Airtel)",
    "titleFr": "Responsable produits et services internet chez Airtel Niger — Saadatou",
    "titleEn": "Head of Internet Products & Services at Airtel Niger — Saadatou",
    "hookFr": "De la tech au sommet : Saadatou pilote les produits internet chez Airtel Niger.",
    "hookEn": "From tech to the top: Saadatou leads internet products at Airtel Niger.",
    "summaryFr": "Résumé pour Métier : Devenir Responsable des Produits et Services Internet Chez Airtel Niger - Saadatou: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Métier : Devenir Responsable des Produits et Services Internet Chez Airtel Niger - Saadatou: Ce contenu traite de Métier, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/Cw7Z4gLK7iw/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Cw7Z4gLK7iw",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 37,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-etudier-le-genie-industriel-au-canada-a-l-ecole-polytechniqu-Jur2Rs",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Génie Industriel",
      "Étudier au Canada",
      "Polytechnique Montréal",
      "Femmes en Ingénierie",
      "Débouchés"
    ],
    "personName": "",
    "roleFr": "Ingénieure en génie industriel",
    "roleEn": "Industrial Engineer",
    "titleFr": "Étudier le génie industriel à Polytechnique Montréal : débouchés et évolutions",
    "titleEn": "Studying Industrial Engineering at Polytechnique Montréal: Prospects and Careers",
    "hookFr": "Génie industriel à Polytechnique Montréal : débouchés, carrière et femmes en ingénierie.",
    "hookEn": "Industrial engineering at Polytechnique Montréal: careers, prospects and women in engineering.",
    "summaryFr": "Résumé pour ÉTUDIER le Génie industriel au Canada à l'école polytechnique de Montréal : Débouchés et évolutions: Ce contenu traite de ÉTUDIER le Génie industriel au Canada à l'école polytechnique de Montréal, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour ÉTUDIER le Génie industriel au Canada à l'école polytechnique de Montréal : Débouchés et évolutions: Ce contenu traite de ÉTUDIER le Génie industriel au Canada à l'école polytechnique de Montréal, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/Jur2RsUODSg/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Jur2RsUODSg",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 38,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-droit-secteur-prive-politiques-publiques-action-gouvernement-iWMQ0h",
    "kind": "video",
    "fieldId": "d07",
    "tags": [
      "Droit",
      "Politiques Publiques",
      "Secteur Public",
      "Action Gouvernementale",
      "Niger"
    ],
    "personName": "Amadou",
    "roleFr": "Juriste en politiques publiques",
    "roleEn": "Public Policy Legal Advisor",
    "titleFr": "Droit, secteur privé et politiques publiques : le métier d'Amadou",
    "titleEn": "Law, Private Sector and Public Policy: Amadou's Career",
    "hookFr": "Du droit au cabinet du Premier ministre : le parcours atypique d'Amadou au Niger.",
    "hookEn": "From law to the Prime Minister's office: Amadou's atypical path in Niger.",
    "summaryFr": "Résumé pour Droit, Secteur Privé, Politiques Publiques, Action Gouvernementale, découvrez le métier de Amadou: Ce contenu traite de Droit, Secteur Privé, Politiques Publiques, Action Gouvernementale, découvrez le métier de Amadou, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Droit, Secteur Privé, Politiques Publiques, Action Gouvernementale, découvrez le métier de Amadou: Ce contenu traite de Droit, Secteur Privé, Politiques Publiques, Action Gouvernementale, découvrez le métier de Amadou, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/iWMQ0h-8yjU/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "iWMQ0h-8yjU",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 39,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-mine-responsable-minage-decouvre-le-metier-de-tahirou-ancien-nj7sFX",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Génie Minier",
      "Mines ParisTech",
      "Industrie Minière",
      "Ingénieur",
      "Responsable Minage"
    ],
    "personName": "Tahirou",
    "roleFr": "Responsable Minage (Ingénieur des Mines)",
    "roleEn": "Blasting Manager (Mining Engineer)",
    "titleFr": "Responsable minage : le métier de Tahirou, ancien des Mines ParisTech",
    "titleEn": "Blasting Manager: Tahirou's Career, Former Mines ParisTech Student",
    "hookFr": "De Mines ParisTech au terrain : Tahirou dirige le minage dans l'industrie minière.",
    "hookEn": "From Mines ParisTech to the field: Tahirou runs blasting in the mining industry.",
    "summaryFr": "Résumé pour Mine - Responsable Minage, découvre le métier de Tahirou ancien étudiant des Mines ParisTech: Ce contenu traite de Mine - Responsable Minage, découvre le métier de Tahirou ancien étudiant des Mines ParisTech, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Mine - Responsable Minage, découvre le métier de Tahirou ancien étudiant des Mines ParisTech: Ce contenu traite de Mine - Responsable Minage, découvre le métier de Tahirou ancien étudiant des Mines ParisTech, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/nj7sFXg0shI/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "nj7sFXg0shI",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 40,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-ingenieur-travaux-photovoltaique-avec-soumaila-zibo--qRaAIV",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Ingénierie",
      "Énergies Renouvelables",
      "Photovoltaïque",
      "Gestion De Projet",
      "Niger"
    ],
    "personName": "Soumaila Zibo Zakara",
    "roleFr": "Ingénieur Travaux Photovoltaïque",
    "roleEn": "Solar (Photovoltaic) Works Engineer",
    "titleFr": "Devenir ingénieur travaux photovoltaïque, avec Soumaïla Zibo Zakara",
    "titleEn": "Becoming a Photovoltaic Works Engineer, with Soumaïla Zibo Zakara",
    "hookFr": "Du Niger aux chantiers solaires : le parcours d'un ingénieur de la transition énergétique.",
    "hookEn": "From Niger to solar sites: one engineer's path into the energy transition.",
    "summaryFr": "Résumé pour Devenir - Ingénieur Travaux Photovoltaïque avec Soumaila Zibo Zakara: Ce contenu traite de Devenir - Ingénieur Travaux Photovoltaïque avec Soumaila Zibo Zakara, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir - Ingénieur Travaux Photovoltaïque avec Soumaila Zibo Zakara: Ce contenu traite de Devenir - Ingénieur Travaux Photovoltaïque avec Soumaila Zibo Zakara, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/qRaAIVbXIds/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "qRaAIVbXIds",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 41,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-metier-chirurgien-dentiste-specialisation-en-prothese-maxill-rJwP6q",
    "kind": "video",
    "fieldId": "d04",
    "tags": [
      "Chirurgie Dentaire",
      "Prothèse Maxillo-Faciale",
      "Médecine Dentaire",
      "Parcours Académique",
      "Niger"
    ],
    "personName": "",
    "roleFr": "Chirurgien-dentiste, prothèse maxillo-faciale",
    "roleEn": "Dental surgeon, maxillofacial prosthetics",
    "titleFr": "Chirurgien-dentiste, prothèse maxillo-faciale : parcours et salaire",
    "titleEn": "Dental Surgeon, Maxillofacial Prosthetics: Path and Salary",
    "hookFr": "Devenir chirurgien-dentiste : parcours, spécialisation en prothèse maxillo-faciale et salaire.",
    "hookEn": "Becoming a dental surgeon: pathway, maxillofacial prosthetics specialization and salary.",
    "summaryFr": "Résumé pour [Métier] Chirurgien Dentiste - Spécialisation En Prothèse Maxillo-Faciale : Parcours, salaire: Ce contenu traite de [Métier] Chirurgien Dentiste - Spécialisation En Prothèse Maxillo-Faciale, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour [Métier] Chirurgien Dentiste - Spécialisation En Prothèse Maxillo-Faciale : Parcours, salaire: Ce contenu traite de [Métier] Chirurgien Dentiste - Spécialisation En Prothèse Maxillo-Faciale, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/rJwP6qk1-sI/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "rJwP6qk1-sI",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 42,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-architecte-parcours-salaire-le-quotidien-et-les-cont-Higr7B",
    "kind": "video",
    "fieldId": "d05",
    "tags": [
      "Architecture",
      "Parcours Professionnel",
      "Design",
      "Construction",
      "Niger"
    ],
    "personName": "",
    "roleFr": "Architecte",
    "roleEn": "Architect",
    "titleFr": "Devenir architecte : parcours, salaire, quotidien et contraintes du métier",
    "titleEn": "Becoming an Architect: Path, Salary, Daily Life and Constraints",
    "hookFr": "Architecte : le parcours, le salaire et les vraies contraintes du métier.",
    "hookEn": "Architect: the path, the salary and the real constraints of the job.",
    "summaryFr": "Résumé pour DEVENIR ARCHITECTE : parcours , salaire, le quotidien et les contraintes du métier: Ce contenu traite de DEVENIR ARCHITECTE, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour DEVENIR ARCHITECTE : parcours , salaire, le quotidien et les contraintes du métier: Ce contenu traite de DEVENIR ARCHITECTE, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/Higr7BbacbI/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "Higr7BbacbI",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 43,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-decouvre-le-parcours-d-ekaley-joulia-directrice-executive-de-P_DObW",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Éducation",
      "Gestion de l'Éducation",
      "Sorbonne-Assas",
      "Maurice",
      "Parcours Inspirant"
    ],
    "personName": "Ekaley Joulia",
    "roleFr": "Directrice Exécutive, Sorbonne-Assas ILS (Maurice)",
    "roleEn": "Executive Director, Sorbonne-Assas ILS (Mauritius)",
    "titleFr": "Le parcours d'Ekaley Joulia, directrice exécutive de Sorbonne-Assas ILS (Maurice)",
    "titleEn": "Ekaley Joulia's Journey, Executive Director of Sorbonne-Assas ILS (Mauritius)",
    "hookFr": "De la salle de classe à la direction d'une école Sorbonne-Assas à Maurice.",
    "hookEn": "From classroom to running a Sorbonne-Assas campus in Mauritius.",
    "summaryFr": "Résumé pour Découvre le parcours d'Ekaley Joulia - Directrice Exécutive de Sorbonne-Assas ILS (Maurice): Ce contenu traite de Découvre le parcours d'Ekaley Joulia - Directrice Exécutive de Sorbonne-Assas ILS (Maurice), partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Découvre le parcours d'Ekaley Joulia - Directrice Exécutive de Sorbonne-Assas ILS (Maurice): Ce contenu traite de Découvre le parcours d'Ekaley Joulia - Directrice Exécutive de Sorbonne-Assas ILS (Maurice), partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/P_DObWlNMpo/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "P_DObWlNMpo",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 44,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-le-parcours-meritant-d-un-jeune-talent-classe-prepa-ifma-pol-2w4hDZ",
    "kind": "video",
    "fieldId": "d03",
    "tags": [
      "Ingénierie",
      "Classe Préparatoire",
      "Mécatronique",
      "Robotique",
      "Énergies Renouvelables"
    ],
    "personName": "",
    "roleFr": "Ingénieur mécatronique",
    "roleEn": "Mechatronics engineer",
    "titleFr": "Le parcours méritant d'un jeune talent : prépa, IFMA, Polytechnique",
    "titleEn": "The Deserving Journey of a Young Talent: Prep School, IFMA, Polytechnique",
    "hookFr": "De la classe prépa à Polytechnique via l'IFMA : le parcours d'un ingénieur mécatronique.",
    "hookEn": "From prep school to Polytechnique via IFMA: a mechatronics engineer's journey.",
    "summaryFr": "Résumé pour Le parcours méritant d'un jeune talent - classe prépa, IFMA, Polytechnique: Ce contenu traite de Le parcours méritant d'un jeune talent - classe prépa, IFMA, Polytechnique, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Le parcours méritant d'un jeune talent - classe prépa, IFMA, Polytechnique: Ce contenu traite de Le parcours méritant d'un jeune talent - classe prépa, IFMA, Polytechnique, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/2w4hDZDR95Y/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "2w4hDZDR95Y",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 45,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-airtel-money-comment-ca-marche-DKx_7a",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Fintech",
      "Mobile Money",
      "Inclusion Financière",
      "Technologie",
      "Entrepreneuriat"
    ],
    "personName": "",
    "roleFr": "Fintech & Mobile Money",
    "roleEn": "Fintech & Mobile Money",
    "titleFr": "Airtel Money : comment ça marche ?",
    "titleEn": "Airtel Money: How Does It Work?",
    "hookFr": "Airtel Money expliqué : comment la fintech révolutionne l'argent mobile en Afrique.",
    "hookEn": "Airtel Money explained: how fintech is reshaping mobile money across Africa.",
    "summaryFr": "Résumé pour AIRTEL MONEY Comment ça marche ?: Ce contenu traite de AIRTEL MONEY Comment ça marche ?, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour AIRTEL MONEY Comment ça marche ?: Ce contenu traite de AIRTEL MONEY Comment ça marche ?, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/DKx_7alOO7I/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "DKx_7alOO7I",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 46,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-qu-est-ce-qu-un-fablab-decouvre-les-metiers-et-les-projets-d-tYXaUc",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "FabLab",
      "Innovation",
      "Technologie",
      "Fabrication Numérique",
      "Métiers Techniques"
    ],
    "personName": "",
    "roleFr": "Métiers du FabLab et de l'innovation",
    "roleEn": "FabLab and innovation careers",
    "titleFr": "Qu'est-ce qu'un FabLab ? Les métiers et les projets d'un FabLab",
    "titleEn": "What Is a FabLab? The Jobs and Projects Inside a FabLab",
    "hookFr": "Prototype, imprime en 3D, code : découvre les métiers qui font naître l'innovation en FabLab.",
    "hookEn": "Prototype, 3D-print, code: explore the careers that spark innovation inside a FabLab.",
    "summaryFr": "Résumé pour Qu'est-ce qu'un FabLab - Découvre les métiers et les projets dans un FabLab: Ce contenu traite de Qu'est-ce qu'un FabLab - Découvre les métiers et les projets dans un FabLab, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Qu'est-ce qu'un FabLab - Découvre les métiers et les projets dans un FabLab: Ce contenu traite de Qu'est-ce qu'un FabLab - Découvre les métiers et les projets dans un FabLab, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/tYXaUci7-dQ/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "tYXaUci7-dQ",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 47,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-chef-cuisinier-la-passion-le-metier-le-parcours-les-missions-ZJOAqS",
    "kind": "video",
    "fieldId": "d10",
    "tags": [
      "Cuisine",
      "Gastronomie",
      "Hôtellerie",
      "Chef Cuisinier",
      "Formation Professionnelle"
    ],
    "personName": "Ismaël Boullosa",
    "roleFr": "Chef cuisinier",
    "roleEn": "Head Chef",
    "titleFr": "Chef cuisinier : passion, métier, parcours, missions et salaire",
    "titleEn": "Head Chef: Passion, Job, Path, Duties and Salary",
    "hookFr": "De la passion à la brigade : le vrai métier de chef cuisinier, parcours et salaire.",
    "hookEn": "From passion to the kitchen brigade: the real life of a head chef, path and pay.",
    "summaryFr": "Résumé pour Chef cuisinier : La passion, le métier, le parcours, les missions et le salaire: Ce contenu traite de Chef cuisinier, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Chef cuisinier : La passion, le métier, le parcours, les missions et le salaire: Ce contenu traite de Chef cuisinier, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/ZJOAqS4F08Y/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "ZJOAqS4F08Y",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 48,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-interprete-parcours-formation-salaire-le-quotidien-y2FnaE",
    "kind": "video",
    "fieldId": "d09",
    "tags": [
      "Interprétation",
      "Langues Étrangères",
      "Traduction",
      "Carrière Linguistique",
      "Formation"
    ],
    "personName": "",
    "roleFr": "Interprète de conférence",
    "roleEn": "Conference Interpreter",
    "titleFr": "Devenir interprète : parcours, formation, salaire et quotidien",
    "titleEn": "Becoming an Interpreter: Path, Training, Salary and Daily Life",
    "hookFr": "Interprète : formation, salaire et quotidien d'un métier des langues qui fait voyager.",
    "hookEn": "Interpreter: training, salary, and the daily life of a language career that travels.",
    "summaryFr": "Résumé pour Devenir Interprète : parcours, formation, salaire, le quotidien: Ce contenu traite de Devenir Interprète, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir Interprète : parcours, formation, salaire, le quotidien: Ce contenu traite de Devenir Interprète, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/y2FnaEdH4Es/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "y2FnaEdH4Es",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 49,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-decouvre-le-metier-de-gynecologue-obstetricien-avec-le-dr-ma-cdhHCs",
    "kind": "video",
    "fieldId": "d04",
    "tags": [
      "Médecine",
      "Gynécologie",
      "Obstétrique",
      "Formation Médicale",
      "Santé Mère-Enfant"
    ],
    "personName": "Dr Maarouf",
    "roleFr": "Gynécologue Obstétricien",
    "roleEn": "Obstetrician-Gynecologist",
    "titleFr": "Le métier de gynécologue-obstétricien, avec le Dr Maarouf",
    "titleEn": "The Job of an OB-GYN, with Dr. Maarouf",
    "hookFr": "Le Dr Maarouf raconte son métier de gynécologue obstétricien au coeur de la maternité.",
    "hookEn": "Dr Maarouf shares life as an OB-GYN at the heart of the maternity ward.",
    "summaryFr": "Résumé pour Découvre le métier de Gynécologue Obstétricien avec le Dr Maarouf de la maternité Issaka Gazobi: Ce contenu traite de Découvre le métier de Gynécologue Obstétricien avec le Dr Maarouf de la maternité Issaka Gazobi, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Découvre le métier de Gynécologue Obstétricien avec le Dr Maarouf de la maternité Issaka Gazobi: Ce contenu traite de Découvre le métier de Gynécologue Obstétricien avec le Dr Maarouf de la maternité Issaka Gazobi, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/cdhHCs4dRDM/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "cdhHCs4dRDM",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 50,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-les-metiers-de-l-assurance-nLlKZt",
    "kind": "video",
    "fieldId": "d02",
    "tags": [
      "Assurance",
      "Métiers de l'Assurance",
      "Actuariat",
      "Gestion des Sinistres",
      "Souscription"
    ],
    "personName": "",
    "roleFr": "Professionnel de l'assurance",
    "roleEn": "Insurance Professional",
    "titleFr": "Les métiers de l'assurance",
    "titleEn": "Careers in Insurance",
    "hookFr": "Souscripteur, actuaire, courtier : découvre tous les métiers de l'assurance et comment y accéder.",
    "hookEn": "Underwriter, actuary, broker: explore every insurance career and how to break in.",
    "summaryFr": "Résumé pour LES METIERS de l'assurance: Ce contenu traite de LES METIERS de l'assurance, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour LES METIERS de l'assurance: Ce contenu traite de LES METIERS de l'assurance, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/nLlKZtofsZ8/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "nLlKZtofsZ8",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 51,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-comment-ce-jeune-passionne-est-devenu-realisateur-cinema-le--sZZsRC",
    "kind": "video",
    "fieldId": "d11",
    "tags": [
      "Cinéma",
      "Réalisation",
      "Films Africains",
      "Parcours Inspirant",
      "Métiers de l'Art"
    ],
    "personName": "",
    "roleFr": "Réalisateur de cinéma",
    "roleEn": "Film Director",
    "titleFr": "Devenir réalisateur de cinéma : métier, parcours, défis et opportunités",
    "titleEn": "Becoming a Film Director: The Job, Path, Challenges and Opportunities",
    "hookFr": "De passionné à réalisateur : le parcours, les défis et les opportunités du cinéma africain.",
    "hookEn": "From film lover to director: the path, the challenges and the rise of African cinema.",
    "summaryFr": "Résumé pour Comment ce jeune passionné est devenu Réalisateur Cinéma - Le Métier, parcours, défis, opportunités: Ce contenu traite de Comment ce jeune passionné est devenu Réalisateur Cinéma - Le Métier, parcours, défis, opportunités, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Comment ce jeune passionné est devenu Réalisateur Cinéma - Le Métier, parcours, défis, opportunités: Ce contenu traite de Comment ce jeune passionné est devenu Réalisateur Cinéma - Le Métier, parcours, défis, opportunités, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/sZZsRCx3POo/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "sZZsRCx3POo",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 52,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-2-travailler-a-la-nasa-les-conseils-de-dr-fadji-zaouna-maina-uI7Ak_",
    "kind": "video",
    "fieldId": "d08",
    "tags": [
      "Hydrologie",
      "NASA",
      "Ressources en Eau",
      "Changement Climatique",
      "Femmes en Science"
    ],
    "personName": "Dr. Fadji Zaouna Maina",
    "roleFr": "Hydrologue à la NASA",
    "roleEn": "Hydrologist at NASA",
    "titleFr": "Travailler à la NASA : les conseils du Dr Fadji Zaouna Maïna",
    "titleEn": "Working at NASA: Advice from Dr. Fadji Zaouna Maïna",
    "hookFr": "Du Niger à la NASA : comment une hydrologue étudie l'eau de la Terre depuis l'espace.",
    "hookEn": "From Niger to NASA: how a hydrologist studies Earth's water from space.",
    "summaryFr": "Travailler à la NASA : Les conseils de Dr. Fadji Zaouna Maina, première Nigérienne à la NASA : Dr. Maina est une scientifique spécialiste en hydrologie à la NASA Goddard Space Flight Center. Originaire du Niger, elle a obtenu un doctorat en hydrologie et a effectué des postdoctorats en France, en Italie et aux États-Unis avant de rejoindre la NASA. Son parcours témoigne de la persévérance, de la détermination et de l'importance de saisir les opportunités. Elle encourage les jeunes à viser haut, à chercher des bourses d'études et à ne jamais sous-estimer leur potentiel.",
    "summaryEn": "Travailler à la NASA : Les conseils de Dr. Fadji Zaouna Maina, première Nigérienne à la NASA : Dr. Maina est une scientifique spécialiste en hydrologie à la NASA Goddard Space Flight Center. Originaire du Niger, elle a obtenu un doctorat en hydrologie et a effectué des postdoctorats en France, en Italie et aux États-Unis avant de rejoindre la NASA. Son parcours témoigne de la persévérance, de la détermination et de l'importance de saisir les opportunités. Elle encourage les jeunes à viser haut, à chercher des bourses d'études et à ne jamais sous-estimer leur potentiel.",
    "thumbnailUrl": "https://img.youtube.com/vi/uI7Ak_aIl5Y/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "uI7Ak_aIl5Y",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 53,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "v-devenir-entrepreneur-le-parcours-de-habou-bassirou-ceo-dev4s-vCvg-V",
    "kind": "video",
    "fieldId": "d01",
    "tags": [
      "Entrepreneuriat",
      "Startup Tech",
      "Innovation Numérique",
      "Télécommunications",
      "Niger"
    ],
    "personName": "Habou Bassirou",
    "roleFr": "Entrepreneur tech, CEO de Dev4smart",
    "roleEn": "Tech entrepreneur, CEO of Dev4smart",
    "titleFr": "Devenir entrepreneur : le parcours de Habou Bassirou, CEO de Dev4smart",
    "titleEn": "Becoming an Entrepreneur: Habou Bassirou's Journey, CEO of Dev4smart",
    "hookFr": "Du Niger à CEO d'une startup tech : le parcours inspirant de Habou Bassirou dans le numérique.",
    "hookEn": "From Niger to tech startup CEO: Habou Bassirou's inspiring journey in the digital world.",
    "summaryFr": "Résumé pour Devenir Entrepreneur - Le parcours de Habou Bassirou CEO Dev4smart: Ce contenu traite de Devenir Entrepreneur - Le parcours de Habou Bassirou CEO Dev4smart, partageant des conseils et expériences pertinents.",
    "summaryEn": "Résumé pour Devenir Entrepreneur - Le parcours de Habou Bassirou CEO Dev4smart: Ce contenu traite de Devenir Entrepreneur - Le parcours de Habou Bassirou CEO Dev4smart, partageant des conseils et expériences pertinents.",
    "thumbnailUrl": "https://img.youtube.com/vi/vCvg-VeZEhs/hqdefault.jpg",
    "photoUrl": "",
    "youtubeId": "vCvg-VeZEhs",
    "durationMinutes": null,
    "interviewFr": null,
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 54,
    "popularity": 0,
    "source": "excel"
  },
  {
    "slug": "t-idriss-laouali-abdou",
    "kind": "text",
    "fieldId": "d01",
    "tags": [
      "Informatique",
      "INSA Toulouse",
      "Ingénieur Full-Stack",
      "Niger",
      "Orientation scolaire"
    ],
    "personName": "Idriss Laouali Abdou",
    "roleFr": "Ingénieur développeur Full-Stack",
    "roleEn": "Full-Stack Software Engineer",
    "titleFr": "De Niamey à INSA Toulouse : le parcours d'un ingénieur passionné de tech",
    "titleEn": "From Niamey to INSA Toulouse: a tech-driven engineer's journey",
    "hookFr": "De cyber-café à Niamey à ingénieur diplômé de l'INSA Toulouse : une passion devenue métier.",
    "hookEn": "From a Niamey cyber-café to an INSA Toulouse engineer: turning passion into a career.",
    "summaryFr": "Né à Niamey, Idriss Laouali Abdou a suivi toute sa scolarité au Niger avant d'intégrer l'Institut National des Sciences Appliquées (INSA) de Toulouse. Passionné de nouvelles technologies dès le collège, il est aujourd'hui ingénieur développeur Full-Stack, coach en orientation scolaire, Directeur Général de ILAN TS et créateur de l'application Karatou Post Bac. Il préside également l'Association des Nigériens de Toulouse.",
    "summaryEn": "Born in Niamey, Idriss Laouali Abdou completed all his schooling in Niger before earning his degree at the National Institute of Applied Sciences (INSA) in Toulouse. Passionate about technology since middle school, he is now a Full-Stack software engineer, an academic guidance coach, Managing Director of ILAN TS and the creator of the Karatou Post Bac app. He also chairs the Association of Nigeriens in Toulouse.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Mon parcours en synthèse",
        "answer": "Aujourd'hui, Je suis ingénieur développeur FullStack, coach en orientation scolaire, Président de l'Association des Nigériens de Toulouse, Directeur Général de ILAN TS et créateur de l'application Karatou Post Bac. Je suis diplômé de l'Institut National des Sciences Appliquées (INSA) de Toulouse. Je suis né il y a 29 ans à Niamey, où j’ai effectué toute ma scolarité jusqu’à mon baccalauréat. J’ai commencé l’école primaire auprès de l’école Canada garçons. Puis, suite à un déménagement, j’ai terminé mes études primaires à l’école mission Goudel. J’ai également réalisé mes classes de 6ème et 5ème (collège) dans cette école. Après l’obtention de mon BEPC au CSP (Cours Secondaire du Progrès), j’ai postulé auprès de l’Eau Vive : il s’agit de l’une des meilleures écoles préparatoires au baccalauréat du Niger, avec un taux de réussite de 100% au bac depuis plus de 8 ans."
      },
      {
        "question": "Le choix de l’informatique",
        "answer": "« Influencé par mes cours d’informatique au collège, ainsi que par mes recherches personnelles, je me suis investi tôt dans le domaine. Passionné par les nouvelles technologies, je passais alors beaucoup de temps dans les cyber-cafés.D’une nature très curieuse, c’est à ce moment-là que j’ai commencé à réaliser des dépannages simples sur ordinateur : installation de système d’exploitation, changement de mémoire RAM, disque dur, etc. Cette petite expérience a été déterminante dans mon choix de l’informatique. »"
      },
      {
        "question": "Je n’ai pas obtenu la bourse de coopération",
        "answer": "J’ai déposé une demande de financement auprès de l’ANAB pour la bourse de coopération au Maroc, ainsi que pour la bourse nationale. Dans le même temps, je me renseignais sur les écoles d’ingénieurs au Maroc et les modalités d’inscription. En effet, le Maroc était alors le seul pays étranger dans lequel je connaissais quelqu’un : je n’osais pas partir là ou je ne connaissais personne ! Le coût de la vie a également été un critère de choix déterminant. Je n’ai pas obtenu la bourse de coopération, mais étant convaincu de ce que je voulais, je n’ai pas baissé les bras. J’ai obtenu une pré-inscription à l’Ecole Supérieure des Télécommunications de Rabat. Par la suite, j’ai obtenu la bourse nationale de l’ANAB qui était transférable au Maroc sous certaines conditions, conditions que je remplissais. Cette bourse comprenait un remboursement partiel des frais d’inscription. L’école proposait par ailleurs une réduction des frais de scolarité pour les trois premiers reçus au concours d’entrée : j’ai accepté le challenge et je l’ai gagné ! Le plus important a été le soutien de mes parents qui ont cru en moi. C’est ce soutien qui m’a toujours apporté la motivation nécessaire pour me dépasser dans mes résultats universitaires. »"
      },
      {
        "question": "Mon parcours du Niger au Maroc puis en France",
        "answer": "Après le bac, j’ai quitté le Niger pour rejoindre l’Ecole Supérieure des Télécommunications (SupTélécom) à Rabat. Au Maroc, j'ai passé 4 ans à l'école d'ingénieurs SUP TELECOM. Quand je suis arrivé, j'avais entendu dire que les trois meilleurs étudiants de troisième année ont la possibilité d’aller en France pour un stage à Télecom Bretagne, l'une des meilleures écoles d'ingénieurs dans ce domaine. J'ai travaillé très dur pour y arriver. Je suis allé en France pour le stage.Avant d’aller en France pour mon stage, afin de me mettre au défi et de poursuivre mes études en France, j'ai postulé dans certaines des meilleures écoles d'ingénieurs en France. l'Institut National des Sciences Appliquées (INSA) de Toulouse m'a accepté. L'INSA est l'une des écoles d'ingénieurs les plus prestigieuses (top 3) en France. J'étais le deuxième Nigérien à y étudier depuis sa création en 1963. Les études étaient plus compliquées à l'INSA qu'à SUP TELECOM. Le rythme des des cours n'était pas le même. J'ai dû travailler dur pour combler mes lacunes. Cette expérience m'a permis de développer ma capacité d'adaptation et j'ai réussi à m'adapter très rapidement pour ensuite me porter volontaire pour soutenir les associations locales afin de développer des compétences pouvant m'aider à avoir un impact social dans mon pays. Je suis diplômé de l'INSA en tant qu'ingénieur logiciel spécialisé dans les systèmes intelligents innovants. En conséquence, j'ai commencé à travailler tôt: j'ai commencé ma carrière professionnelle un an avant mon diplôme.Depuis que je suis en France, j'ai toujours été très investi dans les associations. Mes meilleurs expériences sont ces 4 années aux côtés d'Article1. Ce que j'ai vécu a dépassé mes attentes. J'ai rencontré des dirigeants inspirants tels les PDG de la plupart des grandes entreprises en France. Je participe à la mise en place de beaucoup d'initiatives."
      },
      {
        "question": "Pourquoi Karatou?",
        "answer": "Cette application est née d'une expérience personnelle ainsi que d'un besoin important. Beaucoup de jeunes n'ont pas accès aux bonnes informations pour s'orienter après leur baccalauréat. Certains échouent à cause de la méconnaissance des filières dans lesquelles ils se sont engagés.Parti du constat que les jeunes sont en permanence sur leurs téléphones et que le mobile est très développé en Afrique, j'ai décidé de créer une application qui pourrait leur être utile. Ainsi est née Karatou Post Bac (KPB), Karatou signifiant études en Haussa (langue du Niger).Notre vision consiste à révolutionner l'éducation en Afrique avec le numérique à travers Karatou Post Bac"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 55,
    "popularity": 294,
    "source": "legacy_db"
  },
  {
    "slug": "t-almoctar-hassoumi",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Aéronautique",
      "Informatique",
      "Doctorat",
      "ENAC",
      "Niger"
    ],
    "personName": "Almoctar Hassoumi",
    "roleFr": "Doctorant en Aéronautique et Informatique, ingénieur (ENAC)",
    "roleEn": "PhD student in Aeronautics and Computer Science, engineer (ENAC)",
    "titleFr": "De Niamey à l'ENAC : le parcours d'un double ingénieur",
    "titleEn": "From Niamey to ENAC: a double-engineering journey",
    "hookFr": "De l'enfant de troupe au Niger au doctorant en aéronautique et informatique en France.",
    "hookEn": "From a military-school kid in Niger to a PhD in aeronautics and computer science in France.",
    "summaryFr": "Almoctar Hassoumi, dit Haiz, a grandi à Niamey et est passé par le Prytanée militaire avant de décrocher une bourse pour étudier au Maroc. Ingénieur aéronautique de l'ENAC à Toulouse avec un Master 2 en Interaction Homme-Machine, il détient aussi un diplôme d'ingénieur en informatique de l'EHTP de Casablanca. Il poursuit aujourd'hui un doctorat mêlant aéronautique et informatique.",
    "summaryEn": "Almoctar Hassoumi, known as Haiz, grew up in Niamey and attended the military Prytanée before earning a scholarship to study in Morocco. An aeronautical engineer from ENAC in Toulouse with a Master's in Human-Machine Interaction, he also holds a computer engineering degree from EHTP in Casablanca. He is now pursuing a PhD bridging aeronautics and computer science.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Moctar Hassoumi?",
        "answer": "Je suis Almoctar Hassoumi, appelé Haiz, j’ai 27 ans. Je suis Doctorant en Aéronautique et Informatique.Je suis ingénieur aéronautique de l’Ecole Nationale de l’Aviation Civile (ENAC) à Toulouse, et j'ai fait un Master 2 Interaction Homme-Machine en parrallèle.J'ai aussi un second diplôme d’ingénieur en Informatique de l’Ecole Hassania des Travaux Publics (EHTP) à Casablanca. Je suis né à Niamey, j’ai grandi dans le quartier Terminus, où j’ai passé mon enfance et suis resté jusqu’au baccalauréat. Je suis ensuite parti vivre et étudier à l’étranger.J’ai fréquenté l’école Canada Garçon à l’école primaire, puis j’ai passé le concours pour entrer en sixième au Prytanée militaire de Niamey à l’âge de 12 ans. Je me souviens que j’étais malade le jour du concours et que je ne voulais pas y aller (rires…). Le fait d’entrer dans cette école fut un tournant très important dans ma vie. En tant qu’« enfant de troupe », j’ai eu la chance de passer 7 années dans un cadre militaire au sein d’une promotion agréable d’une cinquantaine de personnes. Le cursus se structurait autour de l’obtention de diplômes militaires, de secourisme et d’enseignements généraux. Après le bac, j’ai postulé pour une bourse à l’ANAB afin d’étudier au Maroc. Après délibération, j’ai été pris en mathématiques et informatique à la faculté des sciences Ain Chock à Casablanca.J’aimais beaucoup les mathématiques et la physique-chimie. A l’issue de la classe de seconde j’ai été admis en série C (ndlr : filière sciences mathématiques). Nous étions quatre dans la classe en terminale. Ça nous a permis de bénéficier d’un bon suivi. D’ailleurs un de mes meilleurs amis de la classe a pu poursuivre ses études en classes préparatoires et est aujourd’hui actuaire, un domaine très prisé. Un est pilote de l’armée de l’air et l’autre a continue dans l’armée de terre »"
      },
      {
        "question": "Les études supérieures : quel(s) choix, pour quelle(s) raisons ?",
        "answer": "Mon choix de devenir ingénieur ne s’est pas fait au lycée. En effet, à cette époque je montais les marches les unes après les autres.\nAprès les résultats du baccalauréat, je n’avais pas d’idée fixe de ce que je voulais faire vraiment, mais j’avais un penchant pour les filières ayant un rapport avec l’informatique. J’ai candidate auprès de l’ANAB et j’ai obtenu une bourse pour étudier les sciences mathématiques et l’informatique à l’Université Hassan II à Casablanca."
      },
      {
        "question": "Pourquoi le Maroc, à Casablanca ?",
        "answer": "J’ai postulé pour une admission dans une université en France à travers Campus France, mais je n’ai pas eu de réponse. Avec quelques amis du Prytanée, nous avons couru pour déposer le dossier à l’ANAB car nous nous y prenions au dernier moment. Ce dossier était requis pour postuler à la bourse de coopération avec le Maroc, puis nous avons été sélectionnés."
      },
      {
        "question": "L’Université Hassan II Aïn Chock de Casablanca (Maroc)",
        "answer": "Nous étions cinq étudiants Nigériens à l’université Hassan II Ain Chock de Casablanca. Il n’y avait pas de frais d’inscription. Concernant les programmes, l’enseignement se concentrait essentiellement sur les mathématiques, la physique et l’informatique.Côté débouchés, après le DEUG (bac + 2), un étudiant peut passer des concours d’accès aux grandes écoles, continuer en licence (bac + 3) pour passer des concours ou poursuivre en master (bac + 5)."
      },
      {
        "question": "L’École Hassania des Travaux Publics (EHTP, Maroc) ?",
        "answer": "Après la 2ème année à la Faculté des sciences Ain Chock, en 2012, Je ne suis pas rentré en vacances au Niger : je suis resté à Casablanca préparer les concours d’accès aux grandes écoles d’ingénieurs.J’ai réussi plusieurs de ces concours, ce qui m’a permis d’avoir le choix. Parmi les concours que j’ai réussi, il y avait l’Ecole Hassania des Travaux Publics, la plus grande école au Maroc (en concurrence avec l’Ecole Mohammadia d’Ingénieurs). Les premiers au CNC (ndlr : Concours National Commun, concours marocain ouvert aux étudiants des classes préparatoires) viennent généralement s’inscrire dans cette école. Elle a aussi une forte ouverture internationale en partenariat avec plusieurs écoles françaises. Puisqu’il y avait une filière Génie informatique, je n’ai pas hésité.- L’EHTP est accessible uniquement sur concours, avec deux possibilités :le Concours National Commun (CNC) pour les élèves issus des classes préparatoires : il faut alors être bien classé, même si tout dépend de la filière choisie, la plus prisée étant le génie civil. La difficulté pour les classes préparatoires réside dans le fait qu’il n’y ait qu’un seul concours pour toutes les écoles et que l’élève doit choisir une école en fonction de son classement.- le concours parallèle, pour les étudiants titulaires d’un DEUG ou d’une licence universitaire : chaque école d’ingénieurs permet aux élèves des universités marocaines de passer un concours d’accès de ce type. Cela étant dit, cette voie est plus complexe à suivre, dans la mesure où les écoles prennent généralement une dizaine d’étudiants dans tout le Maroc chaque année. En contrepartie, l’avantage est de pouvoir préparer plusieurs concours pour plusieurs écoles.L’EHTP n’est pas une école privée. Les frais d’inscription, de logement, de restauration, de cours, d’accès à internet et autres avantages s’élevaient, au total, quand j’y étais, aux environs de 1.200 Dirhams (moins de 75.000 francs CFA) et ce par an. Il faut avouer que ce n’est vraiment pas cher."
      },
      {
        "question": "L’Ecole Nationale de l’Aviation Civile (ENAC, France) ?",
        "answer": "Comme je l’indiquais plus tôt, je cultive depuis mon enfance un très vif intérêt pour l’aéronautique. Mais ma passion pour l’informatique avait, jusqu’à l’EHTP, déterminé mes choix au fil du temps.L’EHTP entretient des partenariats avec plusieurs écoles, à l’étranger aussi, et parmi elles, l’Ecole Nationale de l’Aviation Civile. Pour s’inscrire il faut avoir un bon dossier d’inscription et le déposer auprès de l’administration de l’ENAC, qui l’étudie. La filière ingénieur aéronautique de l’ENAC m’attirait beaucoup. De plus, à la fin de cette formation, je pouvais obtenir un second diplôme d’ingénieur, donc je n’ai pas hésité à postuler.Les programmes que nous étudions couvrent majoritairement le trafic aérien, les opérations aériennes, la conduite automatique de vol, les radars… Mais aussi beaucoup de programmation pour les logiciels embarqués des avions, des cockpits, des outils des contrôleurs aériens, ou de logiciels dans le secteur aéronautique en général. J’ai aussi profité pour faire un Master 2 interaction Homme-Machine avant de commencer le doctorat."
      },
      {
        "question": "Combien coûte la formation que tu suis à l’ENAC ? Quels sont les débouchés professionnels ?",
        "answer": "Pour les étudiants qui viennent des écoles en partenariat avec L’ENAC, les frais dépendent des accords entre les deux écoles. Néanmoins l’ENAC offre différentes formations, les frais peuvent donc beaucoup varier. Côté débouchés, l’ingénieur ENAC intervient dans la conception et la réalisation de systèmes dans le domaine du transport aérien et de l’aéronautique. Son activité s’exerce en premier lieu dans l’industrie aéronautique et spatiale auprès de concepteurs et constructeurs de systèmes aérospatiaux."
      },
      {
        "question": "Que peux-tu dire pour terminer aux jeunes Nigériens qui cherchent des repères et des modèles ?",
        "answer": "Je dirais tout simplement qu’il faut persévérer dans tout ce que l’on fait, quels que soient les domaines et ne pas oublier d’où l’on vient, c’est le plus important.Pour les jeunes qui cherchent des repères, il convient de s’informer des possibilités et de se rapprocher de leurs ainés pour prendre des renseignements. Il y a de très bons talents dans mon pays. Nous le négligeons peut-être, mais malgré le fait que notre pays soit pauvre, nous avons une très bonne éducation. Nous devons en tirer profit. Il y a beaucoup d’opportunités, mais nous sommes encore mal informés. Heureusement qu’il y a des organisations telles qu’OSE Niger qui mettent des informations utiles à disposition des jeunes Nigériens. Je vous remercie sincèrement d’ailleurs pour votre travail. Source: site Ose-Niger, Propos recueillis par Christian Tsanga"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 56,
    "popularity": 257,
    "source": "legacy_db"
  },
  {
    "slug": "t-youssef-mounkaila",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Génie électrique",
      "IUT",
      "Niger",
      "Études en France",
      "Informatique industrielle"
    ],
    "personName": "Youssef Mounkaila",
    "roleFr": "Étudiant en Génie électrique et informatique industrielle (IUT, France)",
    "roleEn": "Student in Electrical Engineering & Industrial Computing (IUT, France)",
    "titleFr": "De Niamey à un IUT en France : le pari du concret en génie électrique",
    "titleEn": "From Niamey to a French IUT: choosing hands-on electrical engineering",
    "hookFr": "Il a choisi l'IUT pour le concret : robots, automates et câblage plutôt que la théorie pure.",
    "hookEn": "He picked an IUT for the hands-on work: robots, automation and wiring over pure theory.",
    "summaryFr": "Youssef Mounkaila, né à Niamey, obtient son bac scientifique au Lycée La Fontaine avant de partir étudier en France, attiré par la qualité de la formation. Il intègre un IUT en génie électrique et informatique industrielle, séduit par le côté concret : programmation de robots et d'automates, câblage d'armoires électriques. Une formation pluridisciplinaire qui ouvre de nombreuses passerelles pour poursuivre ses études.",
    "summaryEn": "Born in Niamey, Youssef Mounkaila earned his science baccalaureate at Lycée La Fontaine before moving to France, drawn by the quality of its education. He joined an IUT in electrical engineering and industrial computing, won over by its hands-on nature: programming robots and industrial automation systems, wiring electrical cabinets. The multidisciplinary program opens many pathways for continuing his studies.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Donc je me présente, je m’appelle Youssef Mounkaila âgé de 22 ans née à Niamey, j’ai effectué toute ma scolarité dans cette ville, et en 2014 j’ai obtenu mon baccalauréat scientifique au Lycée La fontaine de Niamey. Après cela j’ai donc poursuivi mes études en France, ce qui m’a attiré vers ce pays c’est surtout la qualité de la formation.J’ai intégré un IUT car j’avais clairement plus d’appétence pour la technique et le concret, et j’ai été servi : programmation de robot suiveur de ligne, programmation d’ automates industriels, réaliser le câblage d’armoires électriques etc... ça c’est du concret ! L’avantage de cette formation, c’est qu’elle permet d’acquérir des bases sur des domaines pluridisciplinaires et offre beaucoup de passerelles si l’on veut continuer ses études."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "J’ai toujours été intéressé depuis très petit par les nouvelles technologies, mais je ne voulais pas me cantonner uniquement à l’informatique, donc j’ai intégré la filière GEII (génie électrique et informatique industrielle) car on y aborde différents domaines tels que l’informatique, l’automatique, les énergies renouvelables, le véhicule électrique ou tout simplement les sciences. À la suite de mon DUT j’ai été plutôt attiré par le domaine de l’électricité et plus globalement de l’énergie. Pourquoi ce domaine ? eh bien parce que c’est un secteur qui est en constante mutation avec de nouveaux enjeux de plus en plus importants tels que l’intégration des énergies renouvelables, la transition énergétique mais encore la croissance démographique qui nécessite de produire de plus en plus d’énergie, de gérer plus efficacement l’énergie et finalement d’assurer la stabilité du réseau.C’est une filière qui prépare les étudiants aux métiers de la conception de réseaux électriques. Ils sont formés dans un environnement scientifique de pointe aux composants et grandes fonctions des réseaux, et aux méthodes de modélisation, d’analyse et de conception.Une fois l’obtention du diplôme (Master), vous pourrez intervenir sur des métiers dans le domaine des réseaux d’énergie électrique tels que :Bureau d’études de conception et de dimensionnement ;Responsable/gestionnaire de projet technique ;Chargé d’affaires."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Après l’obtention de mon baccalauréat scientifique, j’ai intégré l’IUT 1 (institut universitaire de technologie) 1 de Grenoble dans lequel j’ai obtenu un DUT GEII pour ensuite poursuivre sur une troisième année de licence générale et enfin un Master en 2 ans en Energie Electrique Automatique au sein de l’UGA (Université Grenoble Alpes)."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "D’abord pour l’IUT1, pour pouvoir intégrer cet institut, il faut s’inscrire sur dossier, les notes de premières et terminales ainsi que les appréciations des enseignants que vous avez eues seront étudiées. La formation est possible en alternance en 1ère et 2ème année.Pour intégrer le cycle licenceLa troisième année de licence est accessible de droit aux étudiants titulaires de 120 crédits obtenus dans le même cursus ou via une passerelle, ce qui a été mon cas.Pour le cycle MasterPour l’entrée en 1ière année il faut être titulaire du grade de licence, et constituer un dossier qui sera examiné en commission d'admission et pour la 2ème année, il faut donc être titulaire d'un diplôme de maîtrise, constituer un dossier qui sera examiné en commission d'admission."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Actuellement je ne suis pas encore salarié, je suis en train d’effectuer un stage de fin d’étude en tant qu’ingénieur R&D au sein de l’entreprise Rte (Réseau de Transport d’électricité).L’avantage d’ Rte, c’est que c’est le seul gestionnaire du réseau de transport, il a une position centrale au cœur du réseau, Pour Rte le numérique sera un levier essentiel pour transformer le développement, la maintenance et l’exploitation du réseau en offrant plus d’innovations, d’agilité et de robustesse.L’objectif sera donc de numériser l’ensemble des postes électriques et superviser les transformateurs et le réseau des lignes électriques, afin d’en optimiser la maintenance, du point de vue de l’électricien que je suis, c’est juste une opportunité extraordinaire de pouvoir participer à ces travaux."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "L’ingénieur R&D participe à la conception et au développement de nouveaux services ou procédés dans le cadre d’un projet innovant, comme c’est le cas ici.Il prend connaissance des contraintes techniques du projet en terme de délai budget etc.. Il définit les différents scénarios de tests.Une grosse partie du travail consiste surtout en de la recherche, et donc beaucoup de lecture sur de la documentation technique, des spécifications, de se mettre à jour sur tout ce qui se fait de nouveau technologiquement, ce qui explique le « R » dans R&D.Ce qui est bien c’est qu’il est amener à travailler sur divers types de projets, donc c’est tout à fait l‘idéal pour ceux qui n’aime pas forcément toujours faire la même chose, actuellement dans le cadre de la numérisation du réseau, pour ne pas trop aller dans le détail je fais beaucoup de programmation C sous Linux, des tests sur des protections de distance et du monitoring de performance, donc on a pas le temps de s’ennuyer."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Pour l’instant je viens juste de finir ma formation, j’ai certaines idées dans la tête mais qui doivent encore être mieux ficelé et être concrétisés."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Pas pour l’instant, je me donne encore du temps pour réfléchir à cette question surtout qu’à long terme je ne me vois pas forcément travailler dans un seul pays, j’aimerais bien découvrir d’autres lieux."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Je dirais que l’essentiel, c’est d’aimer ce que l’on fait, de pouvoir se lever chaque matin en se disant que l’on va s’amuser à apprendre des nouvelles choses aujourd’hui à l’école ou travailler sur des projets intéressants au boulot, il n’y a rien de mieux."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non, il n’y a pas de problème à ce niveau"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 57,
    "popularity": 234,
    "source": "legacy_db"
  },
  {
    "slug": "t-joana",
    "kind": "text",
    "fieldId": "d01",
    "tags": [
      "Informatique",
      "Bourse ANAB",
      "Études au Maroc",
      "Niger",
      "Femme dans la tech"
    ],
    "personName": "Joana",
    "roleFr": "Ingénieure informatique",
    "roleEn": "Computer Engineer",
    "titleFr": "De N'Guigmi au Maroc : le parcours d'une ingénieure informatique",
    "titleEn": "From N'Guigmi to Morocco: a computer engineer's journey",
    "hookFr": "D'une petite ville de Diffa jusqu'aux bancs d'une fac marocaine, portée par une bourse et sa passion du code.",
    "hookEn": "From a small town in Diffa to a Moroccan university, carried by a scholarship and a passion for code.",
    "summaryFr": "Élevée par ses grands-parents à N'Guigmi, dans la région de Diffa, Joana se distingue très tôt et intègre le lycée d'excellence de Niamey où elle décroche un bac C. Grâce à une bourse de l'ANAB, elle part étudier l'informatique et les réseaux à la Faculté des sciences et techniques de Béni Mellal, au Maroc. Elle y confirme sa passion pour l'informatique tout en affrontant le choc culturel, la barrière de la langue arabe et le racisme.",
    "summaryEn": "Raised by her grandparents in N'Guigmi, in Niger's Diffa region, Joana stood out early and earned a place at Niamey's lycée d'excellence, where she obtained a science baccalaureate. With an ANAB scholarship, she left for Morocco to study computer science and networks at the Faculty of Science and Technology in Béni Mellal. There she confirmed her passion for computing while confronting culture shock, the Arabic-language barrier and racism.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Joana?",
        "answer": "L’histoire de Joana débute à N’Guigmi, dans la région de Diffa, où elle grandit auprès de ses grands-parents. Elève à l’école primaire des filles, puis au collège de N’Guigmi, Joana est bonne élève et obtient de très bonnes notes au BEPC. Ses professeurs lui suggèrent de présenter le concours au lycée d’excellence de Niamey, concours qu’elle valide haut la main. C’est ainsi qu’elle rejoint Niamey pour y poursuivre ses études jusqu’à l’obtention d’un bac C (scientifique).Au lycée, j’avais pour projet de travailler dans les énergies renouvelables. » Le temps, agrémenté de son lot de rencontres et de découvertes, allait en décider un peu différemment… Alors qu’elle préparait son baccalauréat au lycée d’excellence, l’Association des Nigériens Etudiant au Maroc (ANEM) lui permet de rencontrer des étudiants et diplômés ayant bénéficié d’une bourse de l’ANAB pour poursuivre leurs études au Maroc. Ils lui parlent de la faculté des sciences et techniques (FST) de Béni Mellal, de l’informatique et des réseaux. « Ca a fait tilt. »"
      },
      {
        "question": "Destination Maroc",
        "answer": "Sa bourse de l’ANAB en poche, Joana quitte Niamey pour Béni Mellal. En première année de fac, elle découvre et confirme sa passion pour l’informatique. Elle découvre également le racisme. Certains cours et travaux dirigés sont en arabe, dont elle ne parle pas la langue. Beaucoup, beaucoup de travail personnel, des sentiments contrastés et un choc culturel auquel Joana n’était pas préparée.Joana obtient un DEUG (bac + 2). A nouveau, elle est bien classée. Elle entend parler de l’INPT (Institut National des Postes etTélécommunications), à Rabat. « Je décide de présenter le concours parallèle de l’école, concours ouvert aux étudiants titulaires de bacs +2, non issus des classes préparatoires… Et je le réussis !Direction Rabat, pour deux années d’études supplémentaires. Côté financement, Joana demande et perçoit des bourses grâce à l’AMCI (Agence Marocaine de Coopération Internationale), qui lui permet ainsi de poursuivre ses études au Maroc. L’ANAB l’aide à faire le complément."
      },
      {
        "question": "L'INPT...la suite",
        "answer": "Au sein de l’INPT, Joana découvre les partenariats de l’institut avec plusieurs écoles françaises d’ingénieurs prestigieuses : Supélec, l’INSA Lyon, Télécom Sud Paris… Et Telecom Bretagne.J’avais envie de poursuivre mes études dans une très bonne école et vivre une expérience qui, au-delà de l’intérêt professionnel, qui reste ma motivation essentielle, me permettrait de m’enrichir sur le plan socioculturel. J’avais entendu et lu des témoignages de personnes ayant vécu une expérience similaire, j’ai eu envie de vivre ça moi aussi. Et puis, dans une époque où la mondialisation prend de plus en plus d’ampleur, une expérience d’étude à l’étranger était, sans aucun doute, un avantage considérable sur un CV !Des diplômés marocains de l’INPT lui parlent de leur expérience au sein de Telecom Bretagne, de leur séjour qu’ils ont vraiment apprécié. C’est décidé, Joana partira effectuer sa quatrième et dernière année d’école en France."
      },
      {
        "question": "Arrivée à Brest… Et Lannion",
        "answer": "Automne 2012, arrivée à Brest. Sur le campus du technopôle de Plouzané pour être précis.Télécom Bretagne, outre le fait d’être l’une des plus grandes écoles d’ingénieurs en télécommunications françaises, c’est aussi des étudiants de 56 nationalités différentes et un campus très sympa. « J’habite sur le campus, parmi d’autres étudiants étrangers. Beaucoup d’activités y sont proposées. Et j’ai deux minutes à pied entre ma chambre et les salles de cours.Télécom Bretagne l’invite à profiter de son année pour réaliser un stage en entreprise. Joana parcourt quelques dizaines de kilomètres supplémentaires pour arriver à Lannion, où elle rejoint l’entité Soft d’Orange Labs, dédiée à l’expertise et à la production logicielles. «L’entité Soft Lannion est constituée de quatre équipes. J’ai effectué mon stage au sein d’une de ces équipes, auprès d’une quinzaine de personnes expertes en Androïd.En septembre 2013, Joana obtient son diplôme de l’INPT, spécialité systèmes logiciels et réseaux. Et décide de rester à Télécom Bretagne pour l’année scolaire 2013/2014. « C’était nécessaire pour me permettre d’être également ingénieure diplômée de Télécom Bretagne. Je me spécialise cette année dans l’ingénierie des services et des affaires. Côté financements, je ne bénéficie plus d’aides pour cette dernière année d’études ; je me suis servie en partie de l’argent gagné au cours de mon stage pour la financer. »"
      },
      {
        "question": "Et après ?",
        "answer": "Le domaine de l’informatique est très peu développé au Niger. Pour autant, les sociétés de télécommunications sont présentes dans la région: Orange, Moov, SahelCom, Airtel… Certaines entreprises font développer leurs applications, mobiles notamment, à l’étranger. D’autres, comme Orange, développent ces mêmes applications en France. Je souhaite poursuivre et développer mon expérience professionnelle dans la conception et les développements des systèmes logiciels au cours des deux prochaines années. Pourquoi pas dans un pays anglophone. Et mûrir, enrichir en parallèle un autre projet pro, travailler à son financement."
      },
      {
        "question": "Tu peux nous en dire un peu plus Joana ?",
        "answer": "J’ai rencontré, au cours de mes études au Maroc notamment, d’autres jeunes d’Afrique sub-saharienne motivés par la création de notre propre structure. On aimerait encourager et travailler au développement d’applications mobiles dans la région."
      },
      {
        "question": "Un dernier message, Joana ?",
        "answer": "Cultivez l’envie, travaillez dur, ne vous découragez pas. Et persévérez. Source: site Ose-Niger, Propos recueillis par Agnès Trevarain."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 58,
    "popularity": 185,
    "source": "legacy_db"
  },
  {
    "slug": "t-ibrahim-mansour",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Pilotage",
      "Ingénierie électrique",
      "États-Unis",
      "Niger",
      "Énergie solaire"
    ],
    "personName": "Ibrahim Mansour",
    "roleFr": "Étudiant en pilotage d'avion et ingénierie électrique",
    "roleEn": "Student in aviation piloting and electrical engineering",
    "titleFr": "Du Niger à la Floride : pilote et ingénieur en devenir",
    "titleEn": "From Niger to Florida: becoming a pilot and engineer",
    "hookFr": "Devenir pilote par curiosité, ingénieur par conviction : son double parcours du Niger aux USA.",
    "hookEn": "Pilot out of curiosity, engineer out of conviction: his dual path from Niger to the USA.",
    "summaryFr": "Bachelier du Lycée La Fontaine de Niamey, Ibrahim Mansour est parti étudier aux États-Unis après six mois de formation en anglais. Il a obtenu son Associate au Daytona State College et sa licence de pilote privé, avant de poursuivre un Bachelor of Science in Electrical Engineering à l'University of South Florida. Il mène de front sa formation de pilotage et l'ingénierie électrique, motivé par les enjeux de l'énergie solaire au Niger.",
    "summaryEn": "A baccalaureate graduate of Lycée La Fontaine in Niamey, Ibrahim Mansour moved to the United States after six months of English-language training. He earned an Associate degree at Daytona State College and a Private Pilot License, then began a Bachelor of Science in Electrical Engineering at the University of South Florida. He pursues both his flight training and electrical engineering, driven by Niger's solar energy challenges.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle Ibrahim Mansour, je suis étudiant en pilotage d’avion et ingénierie électrique, en Floride, USA.J’ai obtenu mon baccalauréat au Lycée La Fontaine de Niamey. Puis, j’ai décidé de poursuivre mes études supérieures aux États-Unis. J’ai d’abord effectué une formation en anglais pendant 6 mois, avant de débuter de façon concrète mes études universitaires. Au bout de deux ans, j’ai obtenu mon Associate (diplôme dans le système américain obtenu après 2 ans d’études) à Daytona State College. J’effectuais en parallèle une formation de pilotage qui m’a permis d’obtenir ma Licence de Pilote Privée, à Air America (un centre de vol). A présent, j’étudie à l’University of South Florida, où je compte obtenir mon «Bachelor of Science in Electrical Engineering», sachant que je poursuis ma formation de pilotage en parallèle."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "Auparavant, j’avais toujours souhaité devenir militaire, jusqu’à ce que j’arrive en terminale et choisisse d’aller dans une direction opposées suite à ma décision de devenir pilote, pour une question de préférence. Contrairement à la majorité des pilotes qui ont rêvés de voler depuis qu’ils étaient enfants, j’ai choisi de devenir pilote parce que c’était diffèrent des autres métiers (rire). Arrivé aux USA durant mes cours d’anglais, avec l’influence de ma mère et de la situation énergétique du Niger, j’ai décidé de poursuivre une filière reliée à l’énergie solaire. C’est ainsi que j’ai décidé de devenir ingénieur électrique, en plus d’être pilote aérien ! L’ironie c’est que j’ai toujours détesté l’idée de devenir ingénieur (rire), mais bon, j’estime que c’est un métier dont on manque au pays dans la mesure où nous exploitons mal notre énergie solaire, donc je maintiens la formation."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Lycée La Fontaine : Bac ScientifiqueDaytona State College (DSC) : Associate of Arts (2 ans)University of South Florida (USF) : Bachelor of Science in Electrical Engineering (actuellement)Air America : Centre de vol où j’ai obtenu ma première licence de pilote, il m’en reste 2."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "DSC et USF : (pour plus de détails, visiter leur site internet)- Remplir le formulaire d’inscription en ligne et payer les frais complémentaires (le formulaire est disponible sur leur site internet)- Créer en envoyer son dossier. Attention, pensez bien à convertir votre relevé de note du bac en système américain (i.e traduire le relevé de note en anglais de façon officielle)- Être capable de payer les frais de scolarité et se prendre en charge pour une année"
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Mes parents ont couvert mes frais d’études. Cependant, pour les étudiants venant de l’Afrique de l’ouest et qui étudient dans des universités publics Floridiennes, il y a possibilité d’avoir une réduction de plus de 50%. Le programme/bourse s’appelle, Florida/West Africa Institute (FLAWI) [lien]."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, j’ai un projet pour mon pays ! Il concerne l’atteinte de l’indépendance énergétique en utilisant des énergies renouvelables, principalement le solaire. Comme ça au moins, nos 45 degrés à l’ombre serviront à quelque chose (rire)."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Oui après avoir terminé mes études et gagné de l’expérience sur le marché du travail Américain, comme ça je serai plus légitime aux yeux de potentiel partenaires au moment où il me faudra mettre en œuvre certains projets au pays."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Peu importe ce que vous choisissez de faire dans l’avenir, faites en sorte qu’il ai un impacte sur la vie de plusieurs, ou si possible de tous les nigériens!"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 59,
    "popularity": 174,
    "source": "legacy_db"
  },
  {
    "slug": "t-nabiya-ali",
    "kind": "text",
    "fieldId": "d04",
    "tags": [
      "Cancérologie",
      "Doctorat",
      "Biologie",
      "Campus France",
      "Niger"
    ],
    "personName": "Nabiya Ali",
    "roleFr": "Doctorante en Cancérologie",
    "roleEn": "PhD Student in Cancer Research",
    "titleFr": "De Niamey à Montpellier : une passion pour le vivant devenue thèse en cancérologie",
    "titleEn": "From Niamey to Montpellier: a passion for biology that became cancer research",
    "hookFr": "Du Lycée Eau Vive de Niamey à une thèse en cancérologie à Montpellier, en passant par Marrakech.",
    "hookEn": "From a Niamey high school to a cancer research PhD in Montpellier, by way of Marrakech.",
    "summaryFr": "Née et scolarisée à Niamey jusqu'au baccalauréat, Nabiya Ali obtient une bourse au mérite du gouvernement marocain pour étudier la biologie à l'Université Cadi Ayyad de Marrakech, où elle décroche une licence en physiologie animale et un master en neurosciences. Passionnée par la biologie-santé, elle poursuit via Campus France jusqu'à une deuxième année de thèse en cancérologie à l'Institut de Recherche sur le Cancer de Montpellier (IRCM). Son parcours illustre comment une passion précoce pour le vivant peut mener à la recherche de haut niveau.",
    "summaryEn": "Born and raised in Niamey until her baccalaureate, Nabiya Ali earned a merit scholarship from the Moroccan government to study biology at Cadi Ayyad University in Marrakech, where she completed a bachelor's in animal physiology and a master's in neuroscience. Driven by a passion for health sciences, she continued through Campus France into her second year of a PhD in cancer research at Montpellier's Cancer Research Institute (IRCM). Her journey shows how an early love of biology can lead to advanced research.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Nabiya ALI?",
        "answer": "Je suis BOUBACAR ALI Nabiya. J’ai 20 ans (ptdrrr), plus sérieusement, j’ai 26 ans, et je suis en deuxième année de thèse en Cancérologie à l’Institut de Recherche sur le Cancer de Montpellier (IRCM) dans le Sud de la France. Je suis née à Niamey où j’ai grandi et suis restée jusqu’au baccalauréat en 2009. Et depuis lors, je vis à l’étranger. j’ai eu un parcours assez classique. J’ai fait l’école primaire Yasmina puis le collège et le Lycée Eau Vive. Après avoir obtenu un baccalauréat avec mention au Lycée Eau Vive de Niamey, j’ai obtenu une bourse au mérite du gouvernement Marocain (gérée par l’Agence nigérienne d’Allocation de Bourses, l’ANAB) pour intégrer la Faculté des Sciences Semlalia de l’Université Cadi Ayyad de Marrakech (Maroc). J’ai toujours eu une facilité et une passion pour la biologie, contrairement aux mathématiques ou à la physique (aucune d’entre elle ne m’aimait rires). Comprendre le domaine du vivant, apprendre le fonctionnement global du corps humain, celui de chaque organe en particulier, connaitre les fonctions vitales et identifier leurs pathologies sont des choses qui m’ont toujours intéressée. C’était donc une évidence pour moi une fois à Marrakech de m’inscrire en 1ère année Biologie. Au cours de mon séjour dans cette université, j’ai obtenu l’équivalent d’une licence en Physiologie Animale et d’un Master en Neurosciences. Mes années de fac au Maroc ne m’ayant donné qu’une vision globale de la biologie, et étant passionnée par la BIOLOGIE-SANTÉ, j’entrepris des démarches via Campus France pour continuer mes études en France. Ma réussite au cours des années au Maroc m’a ouvert la possibilité de rejoindre l’université de Poitiers en master 1 RECHERCHE ET INGENIERIE en BIOLOGIE SANTÉ (RIB) dans la spécialité « Physiologie, Neurosciences, Biologie Moléculaire et Cellulaire ». Il faut noter qu’en France, dans des domaines comme la Biologie, un stage est exigé dès le master 1. Ce Master RIB et ce stage m’ont réellement servie de base pour la suite et qui m’a fait véritablement découvrir et aimer LA RECHERCHE SCIENTIFIQUE. Mon stage de Master 1 était mon premier vrai contact avec la recherche. Je l’ai fait en Neurosciences et l’ai effectué dans l’équipe «Dynamiques corticales et intégration multisensorielle» au Centre National de la Recherche Scientifique (CNRS) à Paris. Lors de ce stage, mon projet a consisté à envoyer des signaux lumineux précis au niveau des différentes zones du cortex auditif des souris et de déterminer le comportement des souris ainsi stimulées par rapport à un test de signal sonore classique; l’idée étant voir si un signal lumineux envoyé dans la zone du cerveau qui analyse les sons a les mêmes effets que l’envoi d’un son classique. A long terme, ce projet devrait nous dire si lors d’une perte de l’ouie, on peut à travers des signaux lumineux envoyés à la zone auditive du cerveau remplacer les signaux sonores."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir la Cancérologie?",
        "answer": "J’adorais les Neurosciences et elles me le rendaient bien mais je voulais faire de la recherche en cancérologie. Le cancer, un mot qui fait peur. Ayant grandi dans un entourage composé de beaucoup d’agents de santé, j’entendais souvent parler de ce mot, de cette maladie qui disait-on n’avait pas de traitement définitif car on ne connaissait même pas les multiples causes. Je voulais au moins comprendre le processus de cancérisation, comment le cancer commence, comment la cellule y fait face au début, comment elle essaye de se préserver et comment au final elle devient incontrôlable et néfaste pour ses voisines et l’organisme tout entier.Donc pour le Master 2, j’ai radicalement changé de thématique de recherche. Les cours de Biologie cellulaire et moléculaire de mon master 1 ne m’ayant donné qu’un avant goût de ce qu’est la physiopathologie, j’ai envoyé mon dossier de candidature au master 2 « Reseach in Oncology- Recherche en Cancérologie » de l’Université Claude Bernard de Lyon. Pour ma plus grande joie, ma candidature a été retenue, alors que je n’avais aucun solide background ni en cancérologie ni en programmation. Ce master 2 « Research in Oncology- Recherche en Cancérologie » est unique en Europe, car elle offre de formation de haut niveau, dispensée en anglais et aborde tous les thèmes en rapport avec la recherche en Cancérologie. Je n’aurai pas su mieux choisir car en plus des cours « normaux » de biologie dispensés par de grands chercheurs dans la lutte contre le cancer, nous avions des cours de programmations pour les analyses de données bio-informatiques. Mon stage de fin d’étude a été effectué au Centre de Recherche sur le Cancer de Lyon et a consisté principalement en un travail bio-informatique d’une part pour automatiser une chaîne de traitement et d’analyses de données de cancers qui doit nous permettre d’identifier les altérations liées spécifiquement à un cancer et où elles se situent dans la cellule. Et d’autre part de vérifier les résultats obtenus en bio-informatique par des approches expérimentales de biologie moléculaire. Ce stage m’a prouvé que 6 mois de stage en recherche n’étaient pas suffisants pour moi, ne me permettaient pas de creuser un peu plus. Ayant une réelle passion pour la recherche fondamentale, comprendre ce monde incroyable du vivant et avoir l’impression que, derrière chaque expérience, on va peut-être découvrir quelque chose qui va révolutionner et améliorer la vie des gens, c’est un sentiment incroyable. Je me suis donc résignée à sauter le pas et continuer les recherches en doctorat. Ayant une réelle passion pour la recherche fondamentale, comprendre ce monde incroyable du vivant et avoir l’impression que, derrière chaque expérience, on va peut-être découvrir quelque chose qui va révolutionner et améliorer la vie des gens, c’est un sentiment incroyable. Je me suis donc résignée à sauter le pas et continuer les recherches en doctorat."
      },
      {
        "question": "Le doctorat c'est quoi?",
        "answer": "Un autre mot qui fait peur. Quand on dit qu’on fait une thèse, les gens vous regardent bizarrement (genre il/elle est fou/folle) ou vous disent : tu aimes étudier hein. Il faut comprendre qu’on n’étudie pas au sens conventionnel du terme lorsqu’on fait une thèse. Elle se prépare généralement après l'obtention du master ou d'un niveau équivalent. Tu travailles sur un projet de recherche pendant 3 ans ou plus et à la fin tu présentes tes résultats devant des chercheurs, tes pairs et l’université qui après ta soutenance t’octroie le grade de docteur. Le doctorat ou PhD est le grade universitaire le plus élevé. Il faut déjà savoir qu’en France et un peu partout, le doctorat (ou thèse) se prépare au sein d’une école doctorale. Les écoles doctorales sont rattachées aux universités, et regroupent les centres et équipes de recherche qui prennent en charge la formation par et pour la recherche des doctorants. Elles offrent au futur docteur un excellent encadrement scientifique ainsi qu’une préparation à son insertion professionnelle.C’est un peu comme un département entier dans la fac dédié juste au doctorat, en se chargeant ainsi des inscriptions/réinscriptions en thèse, des soutenances de thèse, de la délivrance du diplôme..."
      },
      {
        "question": "Où se trouve les écoles doctorale?",
        "answer": "Généralement dans chaque université, il ya une école doctorale pour Chimie/Agronomie/Écologie, une pour la Biologie, une pour Physique/Maths/Informatique, une autre pour Droit/Économie et une en Lettres/Sciences Sociales/Psychologie et une dernière en Sport. La durée de la thèse varie en fonction des pays et des disciplines. En France elle est de 3 ou dans de rares cas 4 ans en biologie/Chimie, 4 ou 5 en Droit et Sciences sociales. Aux États Unis ou au Canada, une thèse en biologie santé se prépare en 5 ans."
      },
      {
        "question": "Comment financer sa thèse/ son doctorat",
        "answer": "ouloir faire un doctorat suppose d’avoir des financements. En fonction de ton domaine, l’école doctorale à laquelle tu es rattaché peut exiger ou pas que tu aies un financement pendant la durée de ta thèse.Une thèse en biologie ou en Economie doit OBLIGATOIREMENT ÊTRE financée ce qui n’est pas le cas pour une thèse en Droit ou en lettres.Le Ministère Français de la recherche offre à peu près 4000 financements de thèses chaque année, repartis entre toutes écoles doctorales de toutes les universités de la France, toutes disciplines confondues.Ça revient généralement à 17 financements par école doctorale. A titre d’exemple, l’université de Montpellier comptant 9 écoles doctorales, le ministère lui octroie 17*9 financements.C’est vous dire le graal que représentent ces 17 petits mais ô combien grands financements de thèses.L’école doctorale entre en scène là aussi en organisant le CONCOURS pour l’octroi des financements du ministère vers Juin/Juillet pour un début de thèse en Octobre.Les fameux concours des écoles doctorales se font en deux parties. La première partie se fait sur sélection de dossier. Les critères varient en fonction de la côte des universités mais généralement il faut déposer un dossier béton avec au minimum 14 de moyenne en Master pour espérer avoir la chance de passer la première sélection. Je me souviens, nous étions 300 à avoir déposé nos dossiers pour le concours à Montpellier juste en biologie. Une fois cette sélection faite, ils prennent en général le 1/6ème donc 50 pour passer le concours oral. C’est un concours qu’il faut vraiment préparer même si moi je ne l’ai préparé que deux jours avant. On était en fin juin, je devais finir la rédaction et soutenance de mon stage master 2, je n’y ai pas consacré du temps pour le préparer Un concours oral s’étalant sur une journée et demi en fin juin. Le jour J, tu présentes ton parcours, tes notes, tu expliques ce que tu as fait dans tes stages précédents, tu essayes de convaincre les 12 chercheurs constituant les 3 groupes de 4 jurys que tu seras un excellent chercheur. Ils délibèrent et classent les étudiants l’après midi de la deuxième journée.Trois jours après en moyenne, tu reçois LE MAIL OFFICIEL DE FÉLICIATIONS du DIRECTEUR DE L’ÉCOLE DOCTORALE (ou pas).Les 17 premiers obtiennent ainsi les fameux financements. Une fois le financement obtenu, tu es assigné à un laboratoire de recherche sous la supervision d’un directeur de thèse, et après inscription dans l’école doctorale, tu commences officiellement la thèse. Ce financement constitue le salaire du doctorant pendant toute la durée de la thèse.Les sources de financements des thèses surtout en Biologie-Santé sont nombreuses. En effet, même si tu n’as pas eu le financement du ministère, tu peux demander d’autres financements comme la ligue contre le cancer, les associations de lutte contre les maladies, et beaucoup d’autres associations qui oeuvrent pour l’avancée de la recherche.Ou dans d’autres cas, ton laboratoire d’accueil peut avoir le financement nécessaire pour te garder 3 ans. Il y a des entreprises aussi qui financent des thèses, ce qu’on appelle thèse Cifre. Tu travailles dans l’entreprise et dans un centre de recherche. C’est l’entreprise qui est ton employeur et donc qui te paie.Du coup en biologie, tu peux faire une thèse sans avoir le financement du ministère. Cependant il faut dejà être dans les 50 premiers et en ayant un financement.L’avantage non négligeable du financement du ministère est que tu peux donner des TD à la fac, être enseignant vacataire, pour te préparer au métier d’enseignant chercheur. Ce qui n’est pas le cas des associations interdisent de donner des cours."
      },
      {
        "question": "Quelles sont les réalités de la thèse ?",
        "answer": "La question qu’aucun thésard n’aime entendre hahahaha. Le projet de thèse c’est une hypothèse que tu dois pendant les 3 ans à venir vérifier. L’hypothèse peut être vraie ou fausse.Je travaille à caractériser le rôle d’une enzyme dans la résistance dans le cas des cancers de pancréas, sein, ovaire et vulve aux traitements actuels et à essayer de trouver un traitement contre cette enzyme afin de le combiner avec la radiothérapie pour augmenter les chances de guérison de ces cancers.La thèse c’est une perpétuelle remise en question. Ce n’est pas comme les études où quand tu bosses, tu as de bonnes notes. Le métier de chercheur est un métier qui exige rigueur et dans lequel tu apprends à te remettre perpétuellement en question. En thèse, tu ne comptes plus tes heures au boulot, tu oublies que tu as des weekends ou des jours fériés. Tu auras des jours et des mois où rien ne va marcher, des traversées du désert, des moments où tu seras des tunnels loooongs et interminables où tu auras l’impression de ne pas en sortir, bref beaucoup de moments difficiles où il faut vraiment s’accrocher. Je me souviens une fois en venant au labo, moi qui travaille avec des plusieurs lignées de cellules cancéreuses, j’ai trouvé que toutes mes cellules sont mortes. J’ai pris mon sac je suis revenue à la maison, pris un bol de glace et me suis couchée. Le lendemain je me suis réveillée, suis repartie à l’hôpital chercher de nouvelles cellules. Ou plus récemment, pendant 4 mois rien de ce que j’ai fait n’a marché, pendant 4 mois. 4 mois dans une thèse c’est énorme. Des moments où après avoir fait une semaine d’expériences, tu présentes ton résultat à ton directeur de thèse qui te dit : recommence, c’est du bullshit… mais rien ne vaut la sensation qu’on ressent quand tu trouves un résultat qui t’ouvre un champ de possibilités, qui te fait comprendre un peu plus comment les cellules fonctionnent. ÇA, c’est PRICELESS. C’est dur mais bon si c’était aussi facile que d’avoir un BEPC, tout le monde sera docteur."
      },
      {
        "question": "Avez vous des projets pour le Niger ?",
        "answer": "Faire en sorte que le Niger ait un centre de recherche en cancérologie. Redonner un coup de jeune à la recherche fondamentale et clinique au Niger. Une émancipation extraordinaire pour moi serait d’avoir à diriger un centre de recherche de pointe en cancérologie au NIGER. Faire en sorte de parvenir à dépister les stades plus précoces, à trouver des biomarqueurs dans un centre de recherche basée à Niamey, serait une consécration. Et donc par conséquent faire en sorte qu’on connaisse le Niger. J’en ai marre que les gens me disent : tu es du Nigeria ? non Niger. Mais ce n’est pas la même chose ? Jai envie de toujours avoir sur moi une carte d’Afrique.A titre d’exemple sur mon financement de thèse, la dame a écrit : née à Niger (Nigéria). Pour elle le Niger était la capitale du Nigeria."
      },
      {
        "question": "Envisagez-vous de rentrer ?",
        "answer": "Rentrer maintenant non. J’ai encore beaucoup beaucoup à apprendre et beaucoup de techniques à maîtriser avant d’aller me mettre au service du Niger et pourquoi pas partager mon expérience si je peux arriver à créer des vocations et à faire comprendre aux gens que faire de la biologie et même une thèse n’inclut pas forcément finir professeur de collège comme je l’ai si souvent entendu. Qu’on peut être une fille et faire un doctorat.Avec une amie docteur, nous avons un projet que nous voulons développer dans le sens du partage d’expérience. On vous dira tout très bientôt."
      },
      {
        "question": "Avez vous des projets professionnels futurs?",
        "answer": "Finir ma thèse en un seul morceau déjà lol… faire un ou deux postdoctorats et en ce moment là on on verra. J’ai encore du temps…Pour info, après une thèse en biologie (ou une thèse tout court), vous pouvez faire un post doctorat, aller dans une entreprise (pharmaceutique, de conseil, d’audit, faire l’école d’avocat), ou pour les biologistes, devenir ingénieur de recherche, attaché de recherche clinique dans les organismes de recherche ou travailler dans les hôpitaux. Il y a aussi une option. Pour les gens courageux, ils peuvent après la thèse intégrer la fac de médecine pour finir médecin (le doctorat te permet de sauter les étapes de concours et même les premières années en fac de médecine), dans ce cas ci je me tâte. Si d’ici la fin de ma thèse je suis toujours aussi motivée, pourquoi pas finir avec un doctorat en recherche et un autre en médecine."
      },
      {
        "question": "Un dernier mot",
        "answer": "Je vous dirai de faire ce que vous voulez faire, ce que vous aimez faire et sortir parfois de votre zone de confort. J’ai commencé mon master 1 à Poitiers, j’ai fait le stage sur Paris, ensuite mon master 2 à Lyon, puis ma thèse à Montpellier. C’est vous dire. Je ne connaissais personne à Lyon, c’était à l’autre bout de la France pour moi qui habitait à Poitiers mais j’y suis allée car je voulais ce master 2, pareil pour Montpellier. Mes parents ont commencé à s’inquiéter pour moi avec mon envie de bouger chaque année au début mais après ils se sont habitués et me soutiennent au final mdr. Donc si vous aimez faire une chose, même si elle se trouve en Alaska allez y. Car cela ne sert à rien de choisir de faire une chose que vous n’aimez pas juste pour vous éviter de sortir de votre zone de confort.Je vous quitte avec ces mots d’ÉLEANOR ROOSEVELT : « Les grands esprits discutent des idées ; les esprits moyens discutent des événements ; les petits esprits discutent des gens ».Soyez de ceux qui discutent des idées."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 60,
    "popularity": 173,
    "source": "legacy_db"
  },
  {
    "slug": "t-issaka-mounkaila",
    "kind": "text",
    "fieldId": "d05",
    "tags": [
      "Architecture",
      "EAMAU",
      "Niger",
      "Orientation",
      "Parcours"
    ],
    "personName": "Issaka Mounkaïla",
    "roleFr": "Architecte (diplômé de l'EAMAU)",
    "roleEn": "Architect (EAMAU graduate)",
    "titleFr": "Du geek au crayon d'architecte : le parcours d'Issaka",
    "titleEn": "From geek to architect's pencil: Issaka's journey",
    "hookFr": "Un « geek » passionné de dessin qui a transformé ses cinq passions d'enfance en un parcours d'architecte.",
    "hookEn": "A self-described geek who turned five childhood passions into a path to architecture.",
    "summaryFr": "Issaka Mounkaïla, jeune Nigérien de 24 ans passionné d'informatique et de dessin, a grandi entre Zinder et Niamey où il a sauté plusieurs classes grâce à d'excellents résultats. Après son Baccalauréat en 2010, deux concours l'attirent : l'IAI (informatique) et l'EAMAU (architecture et urbanisme). Il choisit finalement la voie de l'architecture, alliant sa passion du dessin et sa curiosité technique.",
    "summaryEn": "Issaka Mounkaïla, a 24-year-old Nigerien passionate about computing and drawing, grew up between Zinder and Niamey, skipping several grades thanks to outstanding results. After earning his Baccalauréat in 2010, two entrance exams caught his eye: the IAI (computer science) and the EAMAU (architecture and urban planning). He ultimately chose architecture, blending his love of drawing with his technical curiosity.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Présentez-vous",
        "answer": "Je m’appelle Issaka Mounkaïla. Je suis Nigérien et j’ai 24 ans. Je suis ce que l’on appelle communément un « geek »,c’est-à-dire un technophile passionné d’Informatique. Mon enfance, je l’ai passée à jongler entre mes 5 passions : le dessin, la lecture, le football, les jeux-vidéo et l’informatique. J’ai grandi à Zinder où j’ai fait mes premiers pas à l’école Catholique de Zinder avant de migrer à Niamey et rejoindre l’Ecole Mission. C’est dans cette école que je passe mes classes de CE1 et CE2 avant d’être transféré à l’Ecole ELIM pour ma classe de CM1Suite à d’excellents résultats et sous les conseils de mon professeur de l’époque, mes parents décident de me faire sauter la classe de CM2 et de me présenter directement au C.F.E.P.D. Ayant déjà sauté une classe plus tôt dans ma vie, l’idée ne m’effraya pas plus que ça. Je passe donc l’examen que je réussis avec succès. J’avais dix ans et nous étions en 2003. A cette époque, une école en particulier faisait parler d’elle grâce à ses excellents résultats aux examens nationaux, elle s’appelait « L’Eau Vive » et elle habitait à quelques minutes de marche de chez moi. C’est dans cette école que je fis mes premiers pas au Collège, école que je ne quitterai plus jusqu’à l’obtention de mon Baccalauréat en 2010.L’année de ma Terminale, deux concours d’entrée dans les écoles Supérieures attirèrent mon attention, celle de l’IAI (Institut Africain d’Informatique)et celle de l’EAMAU (Ecole Africaine des Métiers de l’Architecture et de l’Urbanisme). Je décidai donc de passer les deux concours que je passe avec brio.Vint alors l’heure du dilemme. Qui de l’Informatique où de l’Architecture devrai-je choisir ? Les deux domaines m’intéressaient beaucoup même si j’avais un petit penchant pour l’Informatique."
      },
      {
        "question": "Pourquoi ai-je alors choisi l’Architecture, me diriez-vous ?",
        "answer": "Eh bien pour trois raisons.La première est que j’aimais cela. Certes, avant mon année de Terminale la question de l’Architecture ne m’était jamais venue à l’esprit mais j’aimais dessiner, créer, imaginer des choses j’en avais l’habitude. Cerise sur le gâteau, en plus de la capacité à visualiser et matérialiser ses idées sur papier, l’Architecte est amené à maitriser les outils Informatiques à travers des logiciels de conception spécialement prévus à cet effet : les fameux logiciels de DAO (Dessin Assisté par Ordinateur). Et être assis devant un ordinateur, j’aimais ça.La deuxième raison était que le domaine de la construction était un secteur prometteur et il l’est toujours aujourd’hui. Bien plus que l’Informatique à cette époque et c’est peut-être le cas également à l’heure où j’écris ces lignes. J’ai préféré alors jouer la carte de la sureté. La troisième et dernière raison est la plus importante selon moi. L’Architecte est un métier libéral. C’est-à-dire que l’on n’est pas fonctionnaire au sens propre du terme. Nous n’avons pas d’horaires strictes à respecter, on travaille quand le besoin se présente. Et c’est excellent dans le sens où, cela nous permet de vaquer également à d’autres occupations, se consacrer à d’autres passions et éventuellement générer d’autres sources de revenus. Rien ne m’empêche donc tout en étant Architecte de me former à l’Informatique et d’exercer simultanément dans les deux domaines. Une pierre deux coups, donc. Après une longue introspection donc, mon choix se porta finalement sur l’Architecture. C’est ainsi que je pose mes bagages à Lomé en 2010 dans le sympathique quartier d’Adewui, petit quartier non loin du campus, à cinq minutes de marche environ de mon école."
      },
      {
        "question": "l'EAMAU, dis nous en plus",
        "answer": "L’EAMAU est une école inter-état qui regroupe en son 14 nationalités d’Afrique. Elle propose trois formations : l’Architecture, l’Urbanisme et la Gestion Urbaine, toutes d’une durée de 5 ans (Système LMD).L’entrée se fait sur concours, concours se déroulant généralement durant le mois de Mai. Pour les étudiants Nigériens, il est généralement facile d’obtenir des bourses d’Etat. Pour y étudier en privé, il faudra prévoir la coquette somme de 2.500.000 l’année."
      },
      {
        "question": "Après l'EAMAU, quels sont les débouchés?",
        "answer": "Ma formation s’est déroulée sans trop d’accrocs. Arrivé en 2010, je soutiens 3 ans plus tard ma Licence que je passe avec succès puis deux années plus tard, en 2015, mon Master, couronné de succès également. Aujourd’hui je réside à Niamey où je travaille actuellement pour un Bureau d’Etude de la place. L’objectif sur le long terme, comme tout le monde, est de s’installer à mon propre compte. On verra ce que l’avenir nous réserve. Parallèlement, je poursuis ces autres passions que je cultive depuis l’enfance. De mes 5 passions, trois ont survécu jusqu’à aujourd’hui : le dessin, la lecture et l’Informatique. Récemment j’ai découvert un moyen de jumeler ces 3 passions autour d’une même activité : le Web 2.0."
      },
      {
        "question": "As-tu des projets au Niger?",
        "answer": "En 2016, après avoir lu le roman d’un jeune auteur Nigérien, je décide de poster sur mon mur Facebook une critique littéraire de ce dernier.La publication rencontre alors un grand succès sur les réseaux sociaux, me permettant au passage de rencontrer l’auteur en question. L’idée me vient alors d’ouvrir un site personnel. Ainsi naît « Le Cactus Sahélien », blog que je vous conseille au passage de visiter. Le blog rencontre alors un certain succès, un article en particulier fait le tour des réseaux sociaux (celui des 10 classiques de la littérature Africaine à lire au moins une fois dans sa vie), me donnant un peu plus de visibilité et me permettant au passage de faire partie des heureux lauréats de l’édition 2017 du concours Mondoblog, parrainé par Radio France International (RFI). Le blog me permit également de me faire remarquer par d’autres médias en ligne, m’ouvrant certaines portes et m’aidant à tisser des liens. Je reçois régulièrement des messages de personnes me sollicitant en tant que collaborateur pour leurs projets. Actuellement, quand je ne suis pas en train de concevoir des maisons, j’écris pour Mondoblog ou pour « Irawo », un média ambitieux avec lequel je travaille depuis quelques mois et dont l’objectif est de faire la promotion du talent Africain. Avec un ami, nous sommes en train de jeter les bases d’un projet qui, je l’espère, profitera au Peuple Nigérien et pourquoi, pas à l’Afrique en général.Cela prendra du temps et beaucoup d’efforts mais la plus-value potentielle que ce projet pourrait apporter est, je pense, inestimable."
      },
      {
        "question": "Quel est ton conseil pour les jeunes?",
        "answer": "Pour finir, si j’ai un conseil à donner aux jeunes Nigériens, principalement ceux qui sont encore sur le banc de l’école, c’est de ne pas rester statique. Trouvez-vous des passions et cultivez-les ! Vous ne saurez jamais laquelle vous sera la plus utile dans les années à venir. Etre jeune est une chance inestimable que l’on ne réalise souvent qu’après coup, alors profitez-en !"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 61,
    "popularity": 168,
    "source": "legacy_db"
  },
  {
    "slug": "t-hassan-mathieu-roufai",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Génie mécanique",
      "Airbus",
      "Niger",
      "EMIG",
      "Étudier en France"
    ],
    "personName": "Hassan Mathieu Roufai",
    "roleFr": "Ingénieur mécanique (design/stress), stagiaire chez Airbus",
    "roleEn": "Mechanical engineer (design/stress), intern at Airbus",
    "titleFr": "De Maradi à Airbus : le parcours d'un ingénieur mécanique",
    "titleEn": "From Maradi to Airbus: a mechanical engineer's journey",
    "hookFr": "Du bricoleur de Maradi à l'ingénieur design/stress chez Airbus, en passant par l'EMIG et Poitiers.",
    "hookEn": "From a Maradi tinkerer to a design/stress engineer at Airbus, via EMIG Niger and Poitiers.",
    "summaryFr": "Passionné de mécanique depuis l'enfance, Hassan Mathieu Roufai a suivi le lycée technique de Maradi puis l'École des Mines (EMIG) au Niger, obtenant un Diplôme de Technicien Supérieur en Maintenance Industrielle. Faute de formation en conception mécanique au Niger, il rejoint le Master Génie Mécanique de l'Université de Poitiers. Il termine aujourd'hui son cursus par un stage de fin d'études chez l'avionneur Airbus comme ingénieur design/stress.",
    "summaryEn": "Passionate about mechanics since childhood, Hassan Mathieu Roufai attended the technical high school of Maradi then the School of Mines (EMIG) in Niger, earning a Higher Technician Diploma in Industrial Maintenance. With no mechanical design program available in Niger, he joined the Master's in Mechanical Engineering at the University of Poitiers. He now caps his studies with a final internship at aircraft manufacturer Airbus as a design/stress engineer.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes-vous ?",
        "answer": "Je m’appelle HASSAN MATHIEU Roufai, je suis étudiant Nigérien en fin de cursus d’un Master Génie Mécanique à l’Université de Poitiers (FR). Passionné de mécanique depuis ma tendre enfance, bricoleur aguerri, c’est bien naturellement qu’après le collège, mon choix s’est très vite porté vers le lycée technique LTDK de Maradi où j’ai décroché le baccalauréat série E (Mathématiques et Technique). Après le lycée, je suis entré sur concours à l’Ecole des Mines, de l’Industrie et de la Géologie (EMIG-NIGER).Après trois ans d’études à l’EMIG, j’ai obtenu un Diplôme de Technicien Supérieur en Maintenance Industrielle.Voulant me spécialiser en conception mécanique et cette formation n’existant nulle part au Niger, j’ai dû quitter. C’est ainsi que j’ai entrepris des démarches pour intégrer le Master Génie Mécanique de l’Université de Poitiers en France. A l’heure où j’écris ces lignes, je suis en stage de fin d’études chez l’avionneur AIRBUS en qualité d’ingénieur ‘’design/stress’’ (j’y reviendrai)."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "Par une formation en Génie Mécanique, je voulais acquérir des connaissances et des compétences tant sur le plan scientifique que technologique, susceptibles de favoriser l’émergence des produits industriels innovants et à forte valeur ajoutée. De plus, la mécanique est un domaine très vaste, je vais simplement vous dire ici que j’ai choisi ce métier, essentiellement, pour la polyvalence qu’il apporte. Or, c’est ce que, je pense, recherchent aujourd’hui les employeurs.Un diplômé en Génie Mécanique peut travailler dans le secteur du BTP, dans l'automobile, la biomécanique, les constructions navales, l'aérospatial et l'aéronautique, les chemins de fer, la mécanique et la métallurgie, la robotique, la machinerie textile, etc."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Lycée Technique du Niger, EMIG-NIGER, Université de Poitiers (FR)"
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "Comme toutes les universités françaises, l’Université de Poitiers s’intègre par étude de dossier. Les candidats sont invités à soumettre leurs dossiers de candidature directement sur l’application Ecandidat de l’Université (https://ecandidat.appli.univ-poitiers.fr/ecandidat/#!accueilView). Une commission de recrutement se réunit au mois de Mai pour effectuer une sélection. Les places étant limitées, il vaut mieux prendre tout son temps pour soumettre un très bon dossier afin de maximiser ses chances."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Je suis boursier de l’Etat Nigérien mais il est clair que la bourse qui m’est versée est insuffisante et ne couvre pas tous mes besoins. J’ai le soutien financier de ma famille. Le coût des études en France dépend fortement de la zone où l’on étudie. En île de France par exemple, il vaut mieux être béton financièrement (rires). Je dirais, 800 euros/mois en île de France et 600 euros/mois en province."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Actuellement, je suis en stage de fin d’études. Le métier que j’exercerai à l’issue de ce stage sera celui d’ingénieur design/stress. C’est mon rêve depuis tout petit."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Tout d’abord, un ingénieur est d’abord un excellent technicien, détenteur de solides compétences techniques et méthodologiques. Afin d’être capable d’appréhender l’activité industrielle dans sa globalité (avec à la fois ses dimensions technique et technologique, économique et sociale), il doit bénéficier d’un haut niveau de culture générale et d’une large ouverture vers le monde industriel.Pour ma part, l'ingénieur design/stress assure la conception d'un assemblage mécanique, son dimensionnement ainsi que le suivi de sa réalisation. Il se charge de fabriquer un prototype et de développer de nouveaux produits pour l'entreprise, le plus souvent au sein d'un bureau d'études. Il gère aussi la production de ce produit de A à Z. En gros, c’est un forgeron des temps modernes (rire)."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Bien évidemment ! J’ai eu la chance de faire des études pointues, il serait égoïste de ne pas en faire profiter l’Afrique. N’oublions pas que le patriotisme est un devoir."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Rentrer et entreprendre, ça a été mon projet dès le début de cette aventure ! Venir en France n’y a rien changé, bien au contraire."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Croyez en vous ! Vous êtes l’avenir de l’Afrique !"
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 62,
    "popularity": 168,
    "source": "legacy_db"
  },
  {
    "slug": "t-annar-mouddour",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Expertise comptable",
      "Audit",
      "Campus France",
      "Bourse",
      "Master CCA"
    ],
    "personName": "Annar Mouddour",
    "roleFr": "Consultant en expertise-comptable et audit",
    "roleEn": "Accounting and audit consultant",
    "titleFr": "De Niamey à un cabinet parisien : le parcours d'un expert-comptable",
    "titleEn": "From Niamey to a Paris firm: an accountant's journey",
    "hookFr": "Sans rêve d'enfance précis, il a suivi le vent jusqu'à devenir expert-comptable à Paris.",
    "hookEn": "With no childhood dream to guide him, he followed the wind all the way to a Paris accounting firm.",
    "summaryFr": "Né à Niamey, Annar Mouddour a étudié entre l'Arabie Saoudite, le Maroc et le Niger avant d'obtenir son Bac série D. Grâce à une bourse de coopération, il décroche un diplôme en Audit et Contrôle de gestion à Agadir, puis un Master CCA à l'Université de Lille 2 via Campus France. Il est aujourd'hui consultant en expertise-comptable et audit dans un cabinet parisien.",
    "summaryEn": "Born in Niamey, Annar Mouddour studied across Saudi Arabia, Morocco and Niger before earning his science baccalaureate. A cooperation scholarship took him to Agadir for a degree in Audit and Management Control, followed by a Master's in Accounting-Control-Audit at the University of Lille 2 through Campus France. He now works as an accounting and audit consultant in a Paris firm.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Annar ?",
        "answer": "Je suis né à Niamey il y a 25 ans de cela. Très tôt, je vais vivre à Djeddah en Arabie Saoudite avec ma famille. C’est là que débute ma scolarité dans une école française. 5 ans plus tard, c’est au Maroc que je poursuis mes études à Rabat 2 années durant. Puis, retour au bercail : le Cours Voltaire puis l’école Mission Evangélique de Goudel avant d’enfin me stabiliser dans un établissement : Le complexe scolaire l’Eau vive, 6 années, jusqu’à l’obtention du Bac en série D. C’est aussi là où j’ai vécu les années les plus intenses de mon parcours, avec de très longues heures de travail dans une atmosphère de rigueur et de discipline. Ce fût aussi le lieu de rencontres avec des professeurs inspirants et des camarades que j’ai la chance de compter aujourd’hui encore parmi mes amis.En 2009, j’obtiens une bourse de coopération et pose mes bagages à Agadir, à l’Ecole Nationale de Commerce et de Gestion. J’en ressors diplômé 5 ans plus tard en spécialité Audit & Contrôle de gestionMalgré cela, je nourris l’ambition d’aller plus loin, d’étancher une soif de savoir encore vive. Ainsi, via Campus France, j’obtins une inscription à l’Université de Lille 2 où j’effectue un Master CCA Comptabilité-Contrôle-Audit pendant 2 ans. Aujourd’hui, je suis consultant en expertise-comptable et audit dans un cabinet parisien."
      },
      {
        "question": "L’expertise comptable : un rêve d’enfance ?",
        "answer": "Non, pas du tout. Je dirais que je suis plutôt allé où le vent m’a porté. Plus jeune, je m’intéressais beaucoup à la géographie, l’histoire de l’Afrique et du monde. Je suivais l’actualité politique avec mes parents et m’étais fixé comme challenge de connaître toutes les capitales, les monnaies et les drapeaux du monde.J’ai aussi développé un intérêt pour les chiffres : les comprendre et les interpréter. De là, mon orientation vers l’économie s’est dessinée. Quant à l’expertise comptable, l’ambition est née des différents stages que j’ai eu à faire, tant au Niger qu’au Maroc. Passer de la théorie au monde pratique a été déterminant. Quant à l’expertise comptable, l’ambition est née des différents stages que j’ai eu à faire, tant au Niger qu’au Maroc. Passer de la théorie au monde pratique a été déterminant."
      },
      {
        "question": "Quelle est la procédure pour devenir expert-comptable ?",
        "answer": "L’expertise comptable correspond à un parcours bac + 8. Ce sont d’abord 5 années d’études, de préférence avec une spécialisation dès le Master. Puis 3 années de travail en tant que « expert-comptable stagiaire » auprès d’un expert-comptable en général au sein d’un cabinet.Un 1er examen se présente sur le parcours : le Diplôme Supérieur de Comptabilité et de Gestion DSCG, équivalent Bac + 5. Et durant les années de stage d’expertise-comptable, nous sommes amenés à suivre des formations et rendre des rapports réguliers. Le parcours se termine avec le passage du Diplôme d’Expert-Comptable DEC et la soutenance d’un mémoire. Dès lors, on devient officiellement Expert-comptable et aussi Commissaire aux comptes."
      },
      {
        "question": "Quels conseils donneriez-vous à un étudiant qui aimerait faire l’expertise comptable ?",
        "answer": "Je lui dirai de très tôt intégrer le monde professionnel à travers des stages et des emplois à temps partiel. Ceci vaut pour n’importe quel discipline : c’est en exerçant qu’on développe ses compétences, mais aussi et surtout qu’on se positionne sur son projet professionnel en répondant à la question fondamentale : Est-ce le bon choix de carrière ? En postulant pour le Master CCA, j’ai essuyé une pluie de refus pour une seule acceptation.Que ce soit au Niger ou ailleurs, si c’est ce que vous voulez faire, foncez !"
      },
      {
        "question": "Avez-vous des projets pour le Niger ? Quelle est la suite ?",
        "answer": "Oui comme beaucoup d’expatriés, j’ambitionne de rentrer chez moi au Niger. N’as-t-on pas coutume de dire chez nous « Fu...fu dey no »? Mais avant cela, étant un amoureux du monde, je veux continuer à voyager et avoir des expériences professionnelles dans le monde anglo-saxon.Au Niger, j’ambitionne de créer une voire des structures innovantes avec d’autres jeunes comme moi, pas forcément dans mon domaine professionnel, mais le plus important sera de créer de la valeur !"
      },
      {
        "question": "Avez-vous des conseils aux jeunes lecteurs ?",
        "answer": "Ne vous sous-estimez pas ! Passez moins de temps à parler & écouter les autres, mais plus à construire vos rêves. Aller à l’extérieur est certes une belle opportunité, mais pas une obligation pour réussir."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 63,
    "popularity": 165,
    "source": "legacy_db"
  },
  {
    "slug": "t-abdoul-kader",
    "kind": "text",
    "fieldId": "d05",
    "tags": [
      "Génie civil",
      "Niger",
      "Lycée d'Excellence",
      "Parcours inspirant",
      "Ingénierie"
    ],
    "personName": "Abdoul Kader",
    "roleFr": "Ingénieur en génie civil",
    "roleEn": "Civil Engineer",
    "titleFr": "De Tchirozérine au génie civil : le parcours d'Abdoul Kader",
    "titleEn": "From Tchirozérine to Civil Engineering: Abdoul Kader's Journey",
    "hookFr": "D'une petite ville minière du Niger jusqu'au génie civil, un parcours porté par l'excellence.",
    "hookEn": "From a small Niger mining town to civil engineering, a journey driven by excellence.",
    "summaryFr": "Né en 1987 à Tchirozérine, près d'Agadez, Abdoul Kader a suivi tout son cursus de base dans sa ville natale avant de réussir le concours du prestigieux Lycée d'Excellence de Niamey. Ces trois années formatrices, marquées par l'excellence et la fraternité entre jeunes talents nigériens, ont jeté les bases de sa carrière d'ingénieur en génie civil.",
    "summaryEn": "Born in 1987 in Tchirozérine, near Agadez, Abdoul Kader completed his early schooling in his hometown before earning a place at the prestigious Lycée d'Excellence in Niamey. Those three formative years, defined by excellence and camaraderie among Niger's brightest students, laid the foundation for his career as a civil engineer.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Présentez-vous",
        "answer": "Mon histoire débute un matin de l’été 1987 à Tchirozérine, une petite ville située à 73 km au Nord-Ouest de la ville d’Agadez. Tchirozérine est connue pour son usine de production d’électricité à partir de la houille (communément appelée charbon minéral ou charbon fossile), exploitée par la Société Nigérienne du Charbon d’Anou Araren (SONICHAR SA). Elève de ma mère dès l’âge de deux ans au jardin d’enfants, j’ai rejoint l’école primaire Anou Araren à l’âge de 7 ans, où j’ai réalisé tout mon cursus scolaire de base I. A l’obtention de mon certificat d’études primaires, j’ai intégré le CEG (Collège d’Enseignement Général) de Tchirozérine. Suite à l’obtention de mon brevet d’étude du premier cycle, j’ai opté pour le concours du Lycée d’Excellence de Niamey. Les résultats s’avérant positifs, je me suis embarqué pour trois années d’aventure sur la rive droite du fleuve Niger."
      },
      {
        "question": "Le Lycée d’Excellence de Niamey",
        "answer": "Trois magnifiques années ! Trois années au cours desquelles, j’ai côtoyé des jeunes nigériennes et nigériens très brillants venant des quatre coins du Niger. Il faut croire que le Lycée d’Excellence de Niamey n’est pas seulement une école, c’est aussi une famille : on se découvre le premier jour et on se méfie les uns des autres (concurrences scolaires obligent !), ensuite on galère ensemble, on bosse ensemble, pour finalement triompher ensemble. J’avoue que ce climat de fraternité, d’une part, et de persévérance collective, d’autre part, a fortement contribué à ma réussite scolaire, aussi bien au Lycée d’Excellence qu’après le lycée. Permettez-moi de rendre ici un hommage mérité à toute la promotion 9 LEX."
      },
      {
        "question": "La Faculté des Sciences et Techniques d’Errachidia (Maroc)",
        "answer": "Mon baccalauréat en poche, je me suis envolé avec certains de mes frères de la terminale C pour le Maroc. En effet, à l’obtention de mon bac, j’ai bénéficié d’une bourse de coopération Nigéro-Marocaine (gérée à l’époque par l’ANAB), afin de poursuivre mes études en maths – informatique – physique à la Faculté des Sciences et Techniques (FST) d’Errachidia. Le choix de poursuivre notamment vers les mathématiques et la physique était étroitement lié à mon cursus lycéen orienté vers les matières scientifiques. Il faut noter que dès mon plus jeune âge, mon rêve était de devenir ingénieur : quoi de plus naturel quand on a grandi au sein d’une cité industrielle ?»"
      },
      {
        "question": "L’Ecole Nationale de l’Industrie Minérale de Rabat (Maroc)",
        "answer": "Après deux années à la FST d’Errachidia, et suite aux concours des grandes écoles d’ingénieurs, j’ai rejoint l’Ecole Nationale de l’Industrie Minérale de Rabat (ou ENIM, aujourd’hui renommée « Ecole Nationale Supérieure des Mines de Rabat »), une des plus prestigieuses écoles d’ingénieurs du Royaume Chérifien. En effet, il est possible d’intégrer un cursus d’ingénieurs sans pour autant passer par les classes préparatoires classiques ; à l’instar de mon propre parcours, il suffit de valider son DEUG ou son DEUST (équivalent bac + 2 années d’études supérieures) avec une bonne moyenne (une très bonne, ma foi, c’est encore mieux !) et bien sûr de réussir aux concours. Donc pour les plus motivés, armez-vous de courage !Le choix de l’ENIM a été sans appel : je voulais être ingénieur des mines et assurer la relève dans les mines nigériennes. Il faut dire qu’à l’époque le contexte minier était des plus prometteurs, des investissements colossaux étaient au rendez-vous, notamment avec le groupe Areva. Dès mes premiers jours à l’ENIM, j’ai tout de suite apprécié l’école ; à l’exception, bien entendu, de l’horrible période de bizutage. Notons qu’en plus d’offrir une scolarité gratuite à ses élèves ingénieurs, l’ENIM fait partie de la liste des écoles reconnues pour la richesse des activités socioculturelles qu’elle propose.Après deux année d’études à l’ENIM, étant très bien classé, j’ai été retenu pour une formation permettant l’obtention d’un double diplôme d’ingénieurs en France, dans le cadre d’un partenariat entre l’ENIM et certaines grandes écoles françaises. L’idée de ce partenariat est de réaliser deux années dans chacune des deux écoles pour finalement obtenir les deux diplômes des deux écoles : une opportunité à saisir sans trop se poser de questions ! L’inscription offre d’office une scolarité gratuite (à l’exception des frais d’assurance maladies qui demeurent obligatoires en France) aux heureux retenus. J’avais alors le choix dans une panoplie d’écoles toutes aussi prestigieuses les unes des autres : l’Ecole Centrale de Lyon, L’Ecole des Mines de Saint-Etienne, l’INSA de Lyon, les Mines d’Alès, etc. Mon choix s’est finalement porté vers l’Ecole Centrale de Lyon, et ce pour deux raisons : la première porte sur le classement de l’école parmi les écoles les mieux cotées (6ème derrière les plus prestigieuses écoles parisiennes, selon le palmarès L’Etudiant 2010 des écoles d’ingénieurs que j’avais consulté alors ; l’école se place aujourd’hui en 3ème place en terme d’excellente académique, selon le même classement) et la deuxième sur l’option génie civil qu’elle proposait. Je souhaitais en effet préparer un second diplôme dans un domaine aussi proche possible que celui du premier."
      },
      {
        "question": "L’Ecole Centrale de Lyon (France)",
        "answer": "A la rentrée 2011-2012, j’effectuais mes premiers pas à l’Ecole Centrale de Lyon. L’accueil et le suivi d’intégration lors de la première semaine sont assurés chaleureusement par le BDE (Bureau des Elèves) : inscription, remise de livrets d’information, visite découverte à travers Lyon, pique-nique au parc de Miribel, etc.Des cours magistraux aux travaux dirigés, en passant par les travaux pratiques, la formation centralienne est très dense. Cette formation dite généraliste, permet aux élèves centraliens d’étudier et de découvrir plusieurs domaines dans un temps resserré : mécanique, mathématiques, informatique, matériaux, management, électronique-électrotechnique-automatique, biologie, nanotechnologies, etc. L’objectif est de former de futurs responsables capables de s’adapter à toutes les situations. L’Ecole Centrale de Lyon offre par ailleurs la possibilité d’accéder à la bourse CMIRA (Bourse de Coopération et Mobilité Internationale de la région Rhône-Alpes), dont j’ai pu bénéficier pendant ma seconde année d’études à l’école.A l’instar de toutes les formations d’ingénieurs de renom, les stages d’été sont obligatoires : 1 mois minimum en première année, 3 mois minimum en deuxième année et 6 mois en dernière année. Ayant intégré l’école en deuxième année, j’ai réalisé mon premier stage, d’une durée de quatre mois, et mon stage de fin d’étude (6 mois) au sein de l’entreprise SCANSCOT Technology. Il s’agit d’un bureau d’étude suédois implanté à Lyon, très à la pointe en matière de calcul par la méthode des éléments finis (vérification de résistance des structures, résistance aux séismes, calcul thermique, calcul d’impact, résistance à la fatigue, etc.), dans le secteur du génie civil. Ces stages m’ont offert l’opportunité de percer le secret des éléments finis, au travers de l’utilisation du progiciel ABAQUS, mais également de découvrir la Suède grâce à plusieurs séjours au siège social de l’entreprise. »"
      },
      {
        "question": "Entrée dans la vie professionnelle",
        "answer": "Fin septembre 2013, je parachevais ma formation par l’obtention de mes deux diplômes : ingénieur des mines de l’Ecole Nationale de l’Industrie Minérale et ingénieur généraliste de l’Ecole Centrale de Lyon. En octobre 2013, je suis recruté en tant qu’ingénieur structure et mécanique par le bureau d’étude SCANSCOT Technology, avec lequel j’avais donc déjà collaboré pendant presque deux années. Je poursuis aujourd’hui mon parcours professionnel au sein de l’entreprise APTISKILLS, implantée principalement en Ile de France, Rhône-Alpes et PACA (région Provence Alpes Côte d’Azur), en tant qu’ingénieur calcul (code éléments finis ANSYS) orienté génie civil. Comme dans de nombreuses entreprises françaises, le processus de recrutement s’est déroulé en deux étapes : entretien avec les ressources humaines, puis validation technique avec les managers et / ou chefs de projets. »"
      },
      {
        "question": "Mes projets et suggestions",
        "answer": "A court terme, je me concentre sur l’acquisition d’expériences professionnelles me permettant d’atteindre le niveau de chef de projet confirmé. A plus long terme, j’envisage de développer au Niger l’utilisation de la méthode des éléments finis, où elle demeure aujourd’hui quasi inexistante, en créant, par exemple, une entreprise spécialisée en la matière.Pour conclure ce portrait, je dirais qu’en chacun de nous se trouvent des potentialités. Chez certains, ces potentialités se matérialisent naturellement avec une certaine aisance, mais chez la plupart d’entre nous il faut travailler à les révéler. Mes suggestions ? Fixons-nous des objectifs, ayons confiance en nous-mêmes, soyons patients, endurants et disciplinés, persévérons et la réussite viendra d’elle-même ! Source:site Ose-Niger, Propos recueillis par Agnès Trevarain."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 64,
    "popularity": 162,
    "source": "legacy_db"
  },
  {
    "slug": "t-temoignage-anonyme2",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "ingénierie aérospatiale",
      "entrepreneuriat",
      "étudier aux USA",
      "Niger",
      "double cursus"
    ],
    "personName": "Témoignage Anonyme",
    "roleFr": "Étudiant en ingénierie aérospatiale et business/économie",
    "roleEn": "Aerospace engineering and business/economics student",
    "titleFr": "De Niamey aux États-Unis : ingénierie aérospatiale et entrepreneuriat",
    "titleEn": "From Niamey to the US: aerospace engineering and entrepreneurship",
    "hookFr": "Du bac à Niamey à un double cursus aérospatial aux USA, en passant par la création de sa boîte.",
    "hookEn": "From a Niamey diploma to a US aerospace double major, with a startup launched along the way.",
    "summaryFr": "Après son bac scientifique à Niamey, ce jeune Nigérien passionné de technologie part six mois à Miami pour perfectionner son anglais, puis lance sa propre entreprise avant de repartir étudier aux États-Unis. Il y suit aujourd'hui un double cursus en ingénierie aérospatiale et business/économie, un choix né de son envie de construire de ses mains et de se spécialiser au-delà de l'informatique théorique.",
    "summaryEn": "After earning his science baccalauréat in Niamey, this tech-passionate young Nigerien spent six months in Miami improving his English, then launched his own company before returning to study in the United States. He now pursues a double major in aerospace engineering and business/economics, a path shaped by his desire to build things with his hands and to specialize beyond theoretical computer science.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle XXXX, je suis suis étudiant en double Major Ingénierie Aérospatiale et Business/Économie. Après avoir obtenu mon bac scientifique à Niamey, je suis parti suivre une formation en anglais pendant 6 mois à Miami, ensuite je suis rentré à Niamey pour un semestre off afin de créer ma boîte. Après l’avoir lancé et que les choses soient bien parties, je suis retourné aux États-Unis pour les études et actuellement, cela fait 3 ans que j’y suis."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "Ça a été au lycée que j’avais commencé à réellement m’intéresser aux ordinateurs, et aux technologies en général. Mais j’ai appris à programmer après le brevet en effectuant notamment des créations de sites web, de la modification de jeux vidéos existants (ajout de fonctionnalités, etc), entre autres. A cette époque, j’ai su que ça allait être à ce domaine que je consacrerais mon avenir. Cela dit, étant donné que j’aime fabriquer les choses de mes mains, je savais que le dimension purement théorique de l’informatique ne me correspondrait pas. J’ai donc dans un premier temps pensé à effectuer des études en ingénierie mécanique, mais la discipline n’étant pas assez spécialisée, je me suis orienté vers l’aérospatial pour mieux affiner ma vision du futur. L’une des choses que j’aime le plus dans ma filière sont les labs (c’est à dire des expériences pratiques) car elles permettent de donner vie à des projets concrets. En guise d’exemple, le semestre précédent nous avions conçus et construit une fusée munie d’une caméra embarquée, ayant la faculté de déployer un parachute pour retomber sans se briser, lorsqu’elle se trouve à une certaine altitude. Ce semestre, nous sommes entrain de concevoir des drones. Avoir sa main dans le processus de fabrication est la chose qui me plaît le plus dans la discipline que j’ai choisi et cela me rassure sur mon choix. Le plaisir acquis permet de combler les frustrations accumulées avec les nuits de révision."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?Comment intégrer cette école/université ?",
        "answer": "Je suis actuellement inscrit dans une université en Californie. Il est possible d’intégrer les universités américaines en général au travers de bourses d’excellence si on détient une certaine note au lycée ou d’autres types de bourse si les parents n’ont pas les moyens. Cependant, le problème avec les bourses américaines est qu’en deçà d’une certaine moyenne (qui varie selon la filière), la bourse est annulée et l’étudiant devra se financer de lui-même s’il souhaite poursuivre ses études."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je suis toujours étudiant mais de gère également mon entreprise qui est une boîte de fourniture de technologies visant à aider les jeunes entreprises et les start-up à digitaliser leurs opérations. Et ce, en plus de mes activités en tant que développeur. Bien sûr que c’est une vocation ! J’ai une réelle passion pour les nouvelles technologies, et ce depuis tout petit."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "De manière concise, disons que je gère la relation entre les employés et les clients, je participe à la conception de logiciels pour nos clients à travers le monde et je me charge d’élargir le réseau de l’entreprise."
      },
      {
        "question": "Avez-vous des projets pour votre pays ? Pour l’Afrique ?",
        "answer": "J’ai quelques projets pour l’Afrique et j’espère qu’avec les différentes compétences et expertises que j’essaye d’acquérir, je pourrai apporter ma pierre à l’édifice du développement africain. Cependant, il ne m’est pas possible de dévoiler ces projets pour le moment, car j’y réfléchis encore."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Oui, absolument."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Il est important de connaître sa passion, mais il est primordial de se développer un réseau, et ce dès le lycée si cela est possible. Je leur conseillerais également de lire beaucoup, et de développer des compétences en essayant le maximum de choses, être curieux donc. Il faut aussi savoir s’écouter, écouter ses parents mais surtout apprendre à faire ses propres choix. Cela peut sembler contradictoire mais pour quelqu’un qui sait ce qu’il veut faire, ça ne l’est pas."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "J’ai un entourage compréhensif vis à vis de ce que je fais et de ce que j’entreprends donc non, aucun problème de ce côté là."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 65,
    "popularity": 161,
    "source": "legacy_db"
  },
  {
    "slug": "t-oumar-issiaka-traore",
    "kind": "text",
    "fieldId": "d01",
    "tags": [
      "Data Science",
      "Mathématiques appliquées",
      "Statistique",
      "Mali",
      "Toulouse School of Economics"
    ],
    "personName": "Oumar Issiaka Traoré",
    "roleFr": "Data Scientist",
    "roleEn": "Data Scientist",
    "titleFr": "Du bac malien au Data Science : le parcours d'un mathématicien appliqué",
    "titleEn": "From Mali to Data Science: an applied mathematician's journey",
    "hookFr": "Du Mali à Toulouse, comment les maths appliquées l'ont mené au métier de Data Scientist.",
    "hookEn": "From Mali to Toulouse: how applied maths led him to a career in data science.",
    "summaryFr": "Oumar Issiaka Traoré, jeune Malien, est aujourd'hui Data Scientist chez Datapole Forecast & Analytics. Après un bac scientifique et une prépa maths-physique au Mali, il enchaîne licence et maîtrise en mathématiques appliquées, puis part en France où il obtient un master en ingénierie mathématique et un master 2 en Statistique et Économétrie à la Toulouse School of Economics. Un parcours éclectique porté par les mathématiques appliquées.",
    "summaryEn": "Oumar Issiaka Traoré, a young Malian, now works as a Data Scientist at Datapole Forecast & Analytics. After a science baccalaureate and a maths-physics prep class in Mali, he earned bachelor's and master's degrees in applied mathematics, then moved to France for a master's in mathematical engineering and a master 2 in Statistics and Econometrics at the Toulouse School of Economics. An eclectic path anchored in applied mathematics.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes-vous ?",
        "answer": "Je suis Oumar Issiaka TRAORE, un jeune malien travaillant actuellement comme data Scientist chez Datapole Forecast & Analytics. Parcours : Mon parcours est plutôt éclectique. Cependant, si je devais le résumer de manière très simple, je dirais qu’il est celui d’un mathématicien appliqué. Après l’obtention de mon baccalauréat en sciences exactes (parcours à dominante mathématiques), j’ai d’abord fait une prépa en mathématiques et physique, avant de poursuivre par une licence en mathématiques appliquées, puis une maîtrise dans la même discipline en 2010. Parallèlement, j’ai également obtenu un DUT en Finance et Comptabilité la même année. Ce dernier diplôme m’a conduit à travailler comme stagiaire pendant environ une année au sein d’un cabinet comptable au Mali. En 2011, à cause essentiellement de ce que je considérais comme un manque de perspectives, j’ai entrepris de poursuivre mes études en postulant en master de mathématiques dans plusieurs universités françaises. Cette démarche m’ a alors conduit à l’université Toulouse 3 Paul Sabatier. Dans un premier temps, j’ai atterri en master de mathématiques fondamentales, parcours que j’ai vite abandonnée pour me réorienter vers le master en ingénierie mathématiques. Après mon master 1, j’ai eu la chance d’être accepté en master 2 Statistique et Économétrie de la Toulouse School of Economics. Dans le cadre du stages obligatoire de ce M2, j’ai choisi d’aller au commissariat à l’énergie atomique (CEA) pour travailler sur un sujet qui me permettait de mettre en application des méthodes de statistique fonctionnelle auxquelles je m’étais initié dans le cadre de mon stage de master 1 à l’institut de mathématiques de Toulouse (IMT). Il s’agissait de proposer des méthodes de machine learning permettant de reconnaître des phénomènes physiques liés au comportement d’un combustible nucléaire en situation accidentelle à partir de signaux d’émission acoustique. A la suite de mon stage de M2, avec le soutien de mon encadrant de stage, j’ai continué à travailler sur les même problématiques dans le cadre d’une thèse effectuée en collaboration entre le CEA, l’IMT et le laboratoire de mécanique et d’acoustique de Marseille (LMA). Quatre mois après cette thèse, j’ai rejoint Datapole comme Data Scientist, poste j’occupe actuellement."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "Mon orientation vers des études à dominante mathématiques s’explique essentiellement par le fait que cette discipline a toujours été celle dans laquelle je me sens le plus à l’aise. En ce qui concerne les études en statistique, pour être honnête, c’est pour des raisons pratiques que je les ai choisi. En effet, j’avais envie de trouver un travail en lien avec les mathématiques, mais dans une discipline qui m’offrirait de belles perspectives de carrière. Dans un pays comme le mien, le métier de statisticien est bien indiqué pour cela. Pour présenter brièvement ce type de formation, comme vous l’avez certainement deviné, il faut avoir de solides bases en mathématiques, notamment en algèbre linéaire et en probabilités. Par ailleurs, de solides compétences en programmation informatique sont également en passe de devenir indispensables."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ? Comment intégrer cette école/université ?",
        "answer": "Comme vous avez pu le constater dans la présentation de mon parcours, je suis passé par plusieurs universités. Cependant, la formation qui a le plus contribué à me donner la casquette que j’ai actuellement est mon master 2 en statistique et économétrie. Ce master a la réputation d’être l’un des meilleurs master professionnels de statistique en France, il est donc plutôt sélectif. Pour y accéder, il faut sortir d’un bon master 1 à dominante mathématiques, avec des résultats très corrects."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Comme la plupart des étudiants africains ne disposant pas d’une bourse, mes études ont été financées en grande partie grâce aux jobs étudiants. J’ai notamment travaillé pendant deux ans comme livreur de Pizza. J’ai également fait de la préparation de commandes dans divers entrepôts de la banlieue Toulousaine. Il faut aussi noter le soutien précieux et vital de la famille pendant les premiers mois de mon séjour en France. Quant au coût des études, comparativement aux pays anglo-saxons et pour la même qualité de formation, je le qualifierais de très abordable. En effet, pendant mes années de master, il fallait moins de 1 000 euros par ans pour payer les frais d’inscription et obtenir une assurance maladie. En ce qui concerne le logement, les étudiants en master pouvaient compter sur l’obtention de places dans les résidences universitaires à loyer très abordable."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Puisque le métier de Data Scientist n’existe que depuis quelques années, on ne peut pas parler de vocation. Cependant, comme souligné précédemment, trouver un job où les mathématiques occupent une place de choix était très important pour moi. En ce sens on peut donc parler de choix cohérent avec mon objectif initial."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Datapole est une entreprise proposant un logiciel dédié au facilty management et c’est aux Data Scientists que revient la tâche de trouver les bons outils d’analyse de données et d’optimisation permettant de répondre aux attentes de l’équipe commerciale. Cette mission comporte à la fois un aspect R&D et un aspect plus orienté consulting et gestion de projet. La partie R&D consiste à penser les évolutions du cœur statistique du logiciel afin de lui assurer une évolution en adéquation avec les objectifs à moyen et long terme de l’entreprise. Quant à la mission de consulting et de gestion de projet, elle consiste à piloter des projets clients en procédant à l’analyse exploratoire des données clients, à leur traitement et au suivi du déploiement du logiciel."
      },
      {
        "question": "Avez-vous des projets pour votre pays?",
        "answer": "Comme partout dans le monde et encore plus pour l’Afrique, les data scientist sont appelés à jouer un rôle majeur dans l’évolution des nouvelles technologies. A long terme, je souhaiterais apporter ma petite contribution. Pour être honnête, pour le moment, je ne connais pas la forme que cette contribution prendra. Cependant, depuis quelques mois, j’ai commencé un travail sur l’histoire de la gestion des données publiques malienne et je pense que j’aurai les idées plus claires à la fin de ce travail. Par ailleurs, je m’intéresse de près à diverses initiatives de start up proposant d’utiliser des données collectées selon divers biais pour améliorer le quotidien des populations."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Il y a quelques années, j’étais un grand partisan du retour immédiat après les études. Avec le temps et en réfléchissant bien aux conditions d’un retour réussi, je suis en train d’arriver à la conclusion que pour des profils comme le mien, il n’est indispensable d’être en Afrique pour apporter une contribution utile. Cependant, j’ai toujours une préférence pour le retour, mais pas à tout prix."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Pour celles et ceux qui entament leur cursus universitaire ou qui sont en manque d’inspiration, je pense qu’une bonne façon d’orienter ses choix est d’aller vers une filière qu’on aime. Ensuite, il faut assumer ses choix et aller jusqu’au bout de sa logique, même en cas de grandes difficultés."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 66,
    "popularity": 159,
    "source": "legacy_db"
  },
  {
    "slug": "t-mahadi-eric-diallo",
    "kind": "text",
    "fieldId": "d01",
    "tags": [
      "Génie logiciel",
      "Développement web",
      "Campus France",
      "Université Clermont-Auvergne",
      "Mathématiques"
    ],
    "personName": "Mahadi Eric DIALLO",
    "roleFr": "Étudiant en Master Génie Logiciel",
    "roleEn": "Software Engineering Master's Student",
    "titleFr": "Du Niger à Clermont-Ferrand : le génie logiciel par conviction",
    "titleEn": "From Niger to Clermont-Ferrand: software engineering by conviction",
    "hookFr": "C'est plus une question de conviction qu'autre chose\" : son parcours vers le génie logiciel.",
    "hookEn": "It was more a matter of conviction than anything else\": his path into software engineering.",
    "summaryFr": "Passionné de mathématiques et de technologies, Mahadi Eric DIALLO a choisi une formation en mathématiques-informatique par pure conviction. Il poursuit aujourd'hui un Master en Génie Logiciel et Intégration d'application à l'Université Clermont-Auvergne, une filière polyvalente mêlant développement web, réseau, sécurité et recherche opérationnelle. Il partage la procédure Campus France (dossier blanc au CCFN de Niamey) pour les étudiants étrangers sans bac français.",
    "summaryEn": "Passionate about mathematics and technology, Mahadi Eric DIALLO chose a math-computer science track out of genuine conviction. He is now pursuing a Master's in Software Engineering and Application Integration at Université Clermont-Auvergne, a versatile program blending web development, networks, security and operational research. He shares the Campus France process (the \"dossier blanc\" at the CCFN in Niamey) for foreign students without a French baccalaureate.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle Mahadi Eric DIALLO et je suis étudiant en master 1 Génie Logiciel et Intégration d’application. C’est une filière qui se focalise sur du développement web et logiciel, mais qui porte aussi une coloration réseau et sécurité des systèmes d’information ainsi que de la recherche opérationnelle, ce qui en fait une filière plus ou moins polyvalente."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "Me considérant comme un scientifique et étant passionné de mathématiques, de technologies, d’astronomie et de biologie a mes heures perdues, j’ai choisi de suivre une formation en mathématiques informatique pour la simple raison que ces dernières sciences pesaient plus dans la balance de mes envies que les autres.C’est donc plus une question de conviction qu’autre chose."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "J’ai effectué mes 3 années de Licence et ma première année de master à université Clermont-Auvergne de Clermont-Ferrand."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "En tant qu’étudiant étranger en France il vous faudra , si vous n’avez pas un bac français, passer par une certaine procédure , il s’agit du dossier blanc que vous pouvez télécharger en ligne, le remplir et le déposer auprès de Campus France au CCFN Jean Roche de Niamey avec les documents requis, sinon il y’aurait aussi une procédure en ligne, mais je ne peux vous renseigner la dessus car je ne la connais pas. Cependant, il est possible d’obtenir toutes les informations que vous souhaitez auprès de Campus France."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Je ne suis pas boursier , mes frais de scolarité sont donc assurés entièrement par ma famille. Vous avez aussi la possibilité, si votre agenda vous le permet, de travailler et de régler vous-même les frais d’études. Cela dit, avec la reforme sur le frais de scolarité pour les étudiants non ressortissants de l’UE , cela s’avèrera plus compliqué car celle-ci rend le coût des études supérieures en France très élevé."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Pour le moment je n’ai pas encore intégré, du moins de manière formelle, le milieu professionnel , je suis stagiaire en développement logiciel et web , et passablement analyste dans une entreprise."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Je travaille sur la partie simulation d’un système, et je veille a ce que ce dernier soit optimal en termes d’exécution , de résultat fournis et de coût. Et je réalise cela un portant des analyses sur des données mise a ma disposition."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Non je n’ai pas de projet a proprement parler."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Pas immédiatement mais oui certainement, nous sommes les seuls a pouvoir bâtir notre nation, nul ne le fera pour nous."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Je n’ai pas vraiment de conseil particulier à donner, faites juste ce qui vous passionne, choisissez bien vos objectifs et donnez tous ce qui est nécessaire pour les atteindre. n’attendez jamais que les choses viennent a vous car le temps dont nous disposons n’est pas infini."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non, aucune."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 67,
    "popularity": 157,
    "source": "legacy_db"
  },
  {
    "slug": "t-amina-batile",
    "kind": "text",
    "fieldId": "d12",
    "tags": [
      "Logistique",
      "Entrepreneuriat",
      "Administration des affaires",
      "Reconversion",
      "Niger"
    ],
    "personName": "Amina BATILE",
    "roleFr": "Logisticienne, interprète et responsable administrative, fondatrice d'une agence de nettoyage",
    "roleEn": "Logistics specialist, interpreter and administrative manager, founder of a cleaning company",
    "titleFr": "De la logistique à l'entrepreneuriat : le parcours d'Amina",
    "titleEn": "From logistics to entrepreneurship: Amina's journey",
    "hookFr": "Logisticienne devenue interprète puis cheffe d'entreprise : un parcours qui se réinvente sans cesse.",
    "hookEn": "A logistics graduate turned interpreter and business owner: a career that keeps reinventing itself.",
    "summaryFr": "Amina BATILE, 32 ans, diplômée en administration des affaires option gestion logistique, a bâti sa carrière dans des multinationales chinoises comme interprète puis responsable administrative (Huawei Niger, Soraz, Soluxe Hotel). Fille de diplomate, elle rêvait de relations internationales avant de se réorienter après le bac. En 2017, elle s'est formée à l'entrepreneuriat et a lancé sa propre agence de nettoyage à Niamey.",
    "summaryEn": "Amina BATILE, 32, holds a degree in business administration with a focus on logistics management and built her career in Chinese multinationals as an interpreter then administrative manager (Huawei Niger, Soraz, Soluxe Hotel). A diplomat's daughter, she once dreamed of international relations before changing paths after her baccalaureate. In 2017 she trained in entrepreneurship and launched her own cleaning company in Niamey.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle Amina BATILE, j’ai 32 ans, maman d’un jeune enfant de 4 ans, née et résidant à Niamey.\n\n*Présentation\nDiplômée en Administration des affaires, option gestion logistique, Je suis logisticienne de formation mais Interprète et Responsable administration dans une multinationale chinoise.\nJe suis aussi la gérante d’une agence de Nettoyage (HOME SERVICES) crée il y a deux (02) ans.\n\n*Parcours\nMon parcours professionnel a commencé en Janvier 2012 en qualité d’interprète d’abord, dans une entreprise sino-nigérienne, pour ensuite gérer la direction de la logistique a la Société des mines d’Azelik. Ensuite, j’ai occupé le poste de Responsable ADMIN dans plusieurs autres structures mais pour la plupart chinoises. (HUAWEI NIGER, SOLUXE HOTEL, SORAZ,)\nCourant 2017, j’ai profité d’un projet pour faire évoluer mon parcours professionnel, j’ai suivi une formation en entreprenariat et j’ai décidé de créer ma propre entreprise en Entretien et Nettoyage, l’idée me tenait à cœur parce que j’ai pris le temps d’étudier le domaine et parce que j’aime tout ce qui est assainissement et hygiène"
      },
      {
        "question": "Qu'est qui vous a motivé à choisir votre filière ?",
        "answer": "Fille de diplomate, j’ai eu l’occasion de découvrir certaines faces du monde et cela m’a donné envie d’étudier les relations internationales.\nMalheureusement, j’ai vite changé d’avis après le BAC une fois en territoire chinois à cause de la barrière linguistique.\nJ’ai opté par plaisir pour l’administration des Affaires, option gestion logistique qui était la tendance, parce que choisit par plusieurs nationalités (donc moins pénibles que les filières ou il n’avait que des étudiants chinois)."
      },
      {
        "question": "Décrire la filière",
        "answer": "Administration des affaires, option gestion logistique.\nLa Maîtrise en administration des affaires, est conçue pour donner aux étudiants une connaissance globale des différents départements d'une organisation et de leurs interrelations, tout en leur permettant de se spécialiser dans un domaine en particulier. Le programme aborde donc de nombreux sujets fondamentaux, notamment la comptabilité, les sciences économiques, la finance, la gestion des ressources humaines, le management des systèmes d'information (on parle aussi parfois de technologies de l'information ou TI), le marketing, la gestion des opérations et de la logistique, les techniques quantitatives de gestion (statistiques, recherche opérationnelle), le management stratégique et l'éthique des affaires. La plupart de ces sujets peuvent faire l'objet d'une spécialisation.\nLe programme d’administration des affaires amène également les étudiants à développer des compétences pratiques, des habiletés de communication et une bonne aptitude à la prise de décision. Cette formation pratique s'effectue notamment à l'aide d'études de cas, de projets, de présentations et de stages en entreprise."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "L’université de JIAO TONG ou SJTU est l'une des plus célèbres universités chinoises de Shanghai, fondée en 1896. Jiaotong ou Jiao Tong est la transcription du mot chinois 交通 (pinyin : Jiāotōng). Ce mot difficile à traduire signifie « trafic », « transports » et « communications » (ce qui relie, connecte). Il est souvent utilisé dans les noms des universités chinoises et a été introduit en anglais.\nÉtablie en 1896 sous le nom de Nanyang Public School par un édit impérial de l'empereur Guangxu, elle a été désignée sous le nom de «The MIT of the East» depuis les années 1930. C'est l'un des neuf membres de l'élite de la Ligue C9, l'équivalent chinois de l'Ivy League.\nElle est célèbre pour avoir établi l'un des plus médiatiques classements académiques des universités mondiales, le classement dit de Shanghai."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "SJTU est l’une des meilleures universités multidisciplinaires, orientée vers la recherche, et internationalisée en Chine.\nDepuis 120 ans, SJTU joue un rôle incontournable dans les développements technologiques et économiques de la Chine. SJTU s’engage de plus en plus dans la recherche scientifique et l’innovation technologique du pays. Plus de 80 centres et laboratoires de recherche s’engagent à différents niveaux de développement. SJTU compte près de 40 000 étudiants, 2 000 étudiants internationaux, 2700 enseignants-chercheurs, dont 890 professeurs, 22 membres de l'Académie des sciences chinoises, 24 membres de l'Académie d'ingénierie chinoise.\nhttp://en.sjtu.edu.cn/\nPour faciliter la venue des étudiants étrangers, le pays a mis en place un site en anglais ! Le portail CUCAS (China's Université and College Admission System) répertorie les formations existant dans plus de 600 établissements et vous accompagne dans chaque étape, de la demande de bourse à la réservation d'un logement. Les inscriptions se font entre décembre et janvier pour la rentrée suivante.\nSi vous ciblez une fac en particulier, n'hésitez pas à postuler directement sur son site Internet. Il vous sera alors demandé de fournir vos diplômes, vos bulletins de notes, une lettre de motivation et une lettre de recommandation.\nPour intégrer un cursus diplômant avec des cours en chinois, vous devez obligatoirement passer le HSK, équivalent du TOEFL. Le niveau 4 (courant) est requis pour s'inscrire en licence (\"xuéshi\") ou en master (\"shuoshi\").\nVos connaissances en chinois ne sont pas suffisantes ? Soyez rassuré(e) : les universités chinoises, désireuses d'attirer des étudiants étrangers, proposent de plus en plus de cours en anglais. En tant qu'étudiant(e) non anglophone, vous devrez cependant justifier votre niveau avec un score minimal de 80 au TOEFL ou de 6,5 à l'IELTS."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "J’ai profité de la bourse de coopération. Mais je trouve le coût un peu élevé."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je suis responsable de l’administration mais aussi interprète dans une entreprise chinoise, et gérante de HOME SERVICES\nCe n’est pas du tout une vocation, j’adore entrepreneuriat, quoique difficile, mais je le gère à mi-temps."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Le métier d’administrateur consiste à la gestion des interrelations entre la différente direction dans une entreprise et à gérer toute la paperasse avec les institutions étatiques."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": ">\n\nCette citation mérite de réveiller le patriotisme et d’encourager les bonnes initiatives.\nC’est dans ce sens que, j’essaie d’aider les veuves et orphelins, les pères de familles sans emploi, à travers mon entreprise HOME SERVICES mais aussi dans des associations ou j’ai adhéré telles que JEUNESSE ACTIVE ET CITOYENNE (JAC/NIGER), LA CHAINE DE L’ESPOIR (CDE) ET +2SOUTIENS (+2S).\nToutes ces associations sont à but no lucratifs et ce sont des structures qui interviennent dans la sensibilisation, le partage de vivres et dans le parrainage des orphelins."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Je pense qu’ils doivent obligatoirement avoir une éducation et une très bonne éducation, après, ils doivent vivre leurs rêves, leurs ambitions. Rien de bon ne se fait sans passion, avec de la passion, vous pouvez conquérir le monde et le malayer à votre guise.\nIl est aussi impératif d’aider sa communauté ne serait-ce que le voisin démuni à coté de vous."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Aucune contrainte. Ma famille m’a toujours supporté dans toutes mes entreprises."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 68,
    "popularity": 156,
    "source": "legacy_db"
  },
  {
    "slug": "t-mahaman-sani-housseyni-issa",
    "kind": "text",
    "fieldId": "d06",
    "tags": [
      "Jeu vidéo",
      "Infographie 2D/3D",
      "Entrepreneuriat",
      "Animation",
      "Niger"
    ],
    "personName": "Mahaman Sani Housseyni Issa",
    "roleFr": "Créateur de jeux vidéo, infographiste 2D/3D et fondateur de MOGMedia Design",
    "roleEn": "Video game creator, 2D/3D graphic designer and founder of MOGMedia Design",
    "titleFr": "Il a créé le tout premier jeu vidéo nigérien",
    "titleEn": "He created the very first Nigerien video game",
    "hookFr": "De passionné autodidacte à créateur du premier jeu vidéo du Niger.",
    "hookEn": "From self-taught enthusiast to creator of Niger's first video game.",
    "summaryFr": "Mahaman Sani Housseyni Issa est un Nigérien de 26 ans, passionné d'art depuis l'enfance, qui a conçu le premier jeu vidéo nigérien, \"Les Héros du Sahel\". Après avoir grandi entre l'Égypte et l'Arabie Saoudite, il rentre au Niger et se forme seul à l'animation et à la programmation. En 2015, après son BTS, il lance MOGMedia Design, un studio dédié aux jeux vidéo, dessins animés et bandes dessinées.",
    "summaryEn": "Mahaman Sani Housseyni Issa is a 26-year-old Nigerien who has been passionate about art since childhood and created the first-ever Nigerien video game, \"Les Héros du Sahel.\" After growing up between Egypt and Saudi Arabia, he returned to Niger and taught himself animation and programming. In 2015, after earning his diploma, he founded MOGMedia Design, a studio focused on video games, animation and comics.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m'appelle Mahaman Sani Housseyni Issa, j'ai 26 ans et je suis un nigérien. J'ai conçu le premier jeu vidéo nigérien : '' Les Héros du Sahel ''. Je suis le Directeur de l'entreprise MOGMedia Design spécialisée dans la conception des jeux vidéos, de la réalisation des dessins animées et de la bande dessinée au Niger. J'ai quitté mon pays à l'âge de 4 ans pour l'Égypte à cause de la profession de mon feu père qui était diplomate en qualité de 1er conseiller et chargé d'affaire à la MAEC. Après être venu au Niger en 2002 j'ai compris qu'il n'y avait rien de ce que j'ai connu et ce sentiment m'a frustré de savoir que mon pays était vide mais riche. En 2009 j'ai quitté mon pays pour l'Arabie Saoudite toujours à cause de la profession de mon paternel. J'y suis resté jusqu'en 2012 mais pendant ce temps je me disais qu'il faut qu'à mon retour que je réalise quelque chose de nouveau qui puisse changer la donne et comme je suis passionné d'art depuis mes 6 ans je me suis intéressé à l'animation et la programmation. Ce qui m'a permis d'apprendre à réaliser des jeux vidéos et des sites web. Une fois rentré, j'ai continué à m'exercer pour ensuite en 2015 après mon BTS d'état lancer ma boîte pour réaliser mon rêve et voir si c'était faisable mais au fond je disais que je devais essayer pour ne plus douter de ce projet et je me suis lancé pendant une année je faisais toujours de la prospection jusqu'à ce que je décide de lancer ma page Facebook officielle et lance juste une image d'un super héros nigérien pour voir la réaction de l'audience et c'est là que j'ai su que la cible était apte à accepter cette idée. J'ai conçu une animation qui aussi a été bien reçue, puis le public a demandé la bande dessinée mais je voulais faire mieux et j'ai conçu en 6 mois le jeu Les Héros du Sahel tout en travaillant comme professeur d'arts plastiques dans une école. Et j'ai choisi une date spéciale pour le lancer, je m'étais dis que si le public voulais lire la bande dessinée, incarner le personnage serait mieux, il serait plus touché et imprégner par l'univers et l'idée. Et j'ai vu juste."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "La filière que j'ai choisi était la communication des entreprises je voulais réaliser mon rêve : celui de créer ma propre entreprise de jeux vidéos, d'animation et de bande dessinée. Comprendre la communication dans un monde de réseau sociaux m'aiderait énormément. La filière consiste en gros à comprendre les bases de la communication tant sur le plan social, psychologique et stratégique lorsqu'il s'agit du business."
      },
      {
        "question": "Quelle école/université avez-vous fréquenté ?",
        "answer": "Aucune, je n'ai fréquenté que 2 écoles professionnelles : l'EST et l'ETEC (à Niamey)."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "Simplement en y déposant vos dossiers après le Bac ou avec le BEPC."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Pour financer ses études, tout dépendra de vos paramètres familiaux et financiers. Si votre famille est pour, alors elle vous aidera en partie au moins pour le déplacement et le logement dans un premier temps mais comme vous êtes amenés à prendre la relève il est important d'avoir un '' mindset'' tel que : ma famille m' aide mais je l'aiderais mieux en l'aidant moi même pour lui diminuer les charges en cherchant un boulot une fois à l'étranger pour joindre les deux bouts jusqu'à finir le cursus scolaire. Si vous êtes seul par contre, n'ayez pas honte, travaillez dans un premier temps pour économiser assez d'argent et allez y tout en prenant compte du fait que vous êtes là pour un laps de temps don vous focaliser sur votre objectif scolaire est primordial. Toutefois, rien ne presse à l'étranger trouver du travail et étudier en parallèle est conciliable, il faut s'organiser."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Le métier que j'exerce aujourd'hui est celui de Game developper, infographiste 2D/3D et de conférencier. C'est ma vocation car de tout temps j'ai toujours voulu vivre de ma passion car c'est le domaine dans lequel j'ai su que je pouvais facilement exceller et me faire remarquer."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Ce métier comme tout métier d'entreprise n'a aucun répit. A vrai dire, arrêter de travailler signifie d’arrêter de gagner votre vie. Une fois cette règle imprégnée dans votre psychique, vous vous devez d'être créatif et de débloquer des contrats tout en anticipant d'autres pour assurer votre budget de dépenses durant au minimum une année. Avoir une stratégie de communication est primordial dans mon domaine. C'est la communication qui fait vivre l'entrepreneur."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Mes projets pour mon pays sont déjà lancés: créer des jeux vidéos, des animations et des bandes dessinées pour représenter le Niger et l'Afrique en Europe. Le but était d'innover dans le domaine de la technologie au Niger et de prouver à la jeunesse africaine la faisabilité, les opportunités et extensions de mon domaine fort utilisable dans l'éducation pour pousser les jeunes à se préparer mentalement à changer les choses. L'éducation est là clé du changement en Afrique."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Revenir aux origines est important pour se rappeler de la provenance et de la direction choisie. Mais de nos jours on a accès au monde même depuis un ordinateur, de ce fait, ce qui compte c'est d'investir dans une/des chose(s) productive(s) pour sa patrie, peu importe la géo-localisation de l'individu. L'étranger nous apprend à voir plus loin et à nous améliorer mais appliquer les choses apprises chez soi c'est éviter l'aliénation culturelle et la colonisation intellectuelle qui font tant souffrir tout africain et garantir un avenir radieux pour nos enfants. Quoi de plus important que la progéniture ?"
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Oui, 5 conseils :- l'avenir ne se prépare ni à l'école ni dans l'atelier mais dans l'esprit et les actions. - Vous n'avez rien mais vous avez une idée ? N'ayez pas peur. Développez-la, unissez-vous s'il le faut, sinon réalisez l’idée seul, mais n'oubliez pas que le facteur temps est primordial à sa réalisation. Quelque fois les moyens et les idées sont là mais la mentalité de la cible ne s'adapte pas alors laissez le temps agir. - Les émotions ne sont pas les bienvenues dans le travail mais les vertus, oui. - La chance n'existe pas, vous la créez en travaillant. Alors travaillez sans relâche. - L'échec n'existe point en entrepreneuriat , on ne tire que des leçons."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Pour ce qui est des contraintes familiales ce sont des aléas de la vie mais comme toute entreprise la famille en est une aussi, il faut savoir anticiper les événements et situations pour ne pas se retrouver dans une situation financière compliquée. En anticipant on prévoit les risques et assure la postérité."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 69,
    "popularity": 139,
    "source": "legacy_db"
  },
  {
    "slug": "t-hafiz-andre",
    "kind": "text",
    "fieldId": "d04",
    "tags": [
      "Médecine",
      "Niger",
      "Université Abdou Moumouni",
      "Vie étudiante",
      "Vocation"
    ],
    "personName": "Hafiz André",
    "roleFr": "Étudiant en médecine (5e année)",
    "roleEn": "Fifth-year medical student",
    "titleFr": "De Niamey au doctorat en médecine : un parcours exigeant",
    "titleEn": "From Niamey to a medical degree: a demanding path",
    "hookFr": "La médecine est l'une des plus belles, mais aussi l'une des plus difficiles disciplines.",
    "hookEn": "Medicine is one of the most beautiful, but also one of the hardest, disciplines I know.",
    "summaryFr": "Hafiz, 23 ans, est en 5e année de médecine à l'université Abdou Moumouni de Niamey, après un parcours scolaire entièrement mené au Niger jusqu'au bac. Il a choisi la médecine pour son côté noble et la possibilité de porter secours aux autres, après avoir renoncé à son rêve de devenir pilote. Il décrit une filière difficile qui exige de sacrifier sa vie sociale, entre stages hospitaliers, cours, révisions et gardes de nuit.",
    "summaryEn": "Hafiz, 23, is a fifth-year medical student at Abdou Moumouni University in Niamey, having completed his entire schooling in Niger through to the baccalaureate. He chose medicine for its noble calling and the chance to help others, after giving up his dream of becoming a pilot. He describes a demanding field that requires sacrificing one's social life, juggling hospital rotations, lectures, revision and overnight shifts.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle Hafiz, je suis âgé de 23ans et je suis en 5ème année d'études médical à l'université Abdou Moumouni de NiameyJ'ai fréquenté l'école primaire croix rouge poudrière jusqu'à l'obtention de mon CFEPD, puis le collège Soni Ali ber de Niamey jusqu'à l'obtention de mon BEPC, ensuite j'ai fréquenté le lycée Mariama où j'ai décroché mon bac, je poursuis à la Faculté des sciences de la santé à la quête d'un doctorat en médecine"
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "C'est un métier noble. En outre, il offre la possibilité d'être au secours des autres et bien évidemment, de sa famille Également, d’autres parts je n’ai pas eu l’opportunité d’effectuer ce que je voulais faire vraiment qui est le métier de pilote, et ce, pour des raisons privées. La médecine est l'une des plus belles, mais aussi l'une des plus difficiles disciplines que je connaisse.La filière est difficile parce qu’elle exige d’oublier sa vie sociale ; une journée type est une journée durant laquelle le matin je participe à des stages hospitalières de 8h à 12h ou au delà, tout dépend des services. Ensuite, il faut assister aux cours de 15h à 18h ; évidemment, après cette longue journée, il faut réviser les cours pour éviter d’avoir un lot de chapitres qui s’entassent et être dans un calvaire impossible à l’approche des examens. En sommes, un rythme régulier et soutenu de travail est absolument nécessaire!A ces journées remplies, n’oublions pas d’ajouter les soirées de garde qui vont de 20h à 8h du matin. Ces dernières débutent à partir de la 4e année au cours de laquelle le rythme de garde est fixé à 6 jours, à savoir que si je garde par exemple la nuit du jeudi, la semaine suivante il me faudra garder le mercredi. En 5e année, c’est selon un rythme de 5 jours, concrètement cela significie que si je garde le jeudi, il me faudra effectuer de nouveau une garde le mardi suivant."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "Il suffit de déposer son dossier, puis lorsqu'on répond aux critères, on est sélectionné sur dossier.Le dossier est composé de l’attestation de réussite au bac, de l’acte naissance, la nationalité, etc. Les critères de choix me sont assez inconnus, mais j’imagine que tout se fait sur base des résultats scolaires."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Aucun, pour l'instant je suis toujours étudiant. En revanche quand je serai médecin, ma journée typique sera fortement semblable à ma vie actuelle, en dehors du fait que je n’aurai plus de cours, ni d’examens. Il me faudra passer toutes mes journées au travail, et tenter de trouver un rythme convenable entre ma vie sociale/familiale et le boulot. Être médecin sans que cela ne soit une vocation revient à être un tueur, à mes yeux. La médecine n’était pas mon premier choix au départ, mais j’ai appris à adorer cette discipline !"
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Ce métier consiste vraiment à s’oublier, afin d’être présent entièrement pour les besoins des autres ; Au quotidien, il faut savoir accueillir ses patients, les examiner cliniquement. Au vu de notre contexte de pauvreté, il faut savoir se baser sur l’examen clinique afin d’orienter ses examens complémentaires. Après cela, il faudra traiter le patient suite au diagnostic."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Des projets j’en ai mais, je suis assez sceptique quant à leurs réalisations, au vu des réalités de mon pays. Dans mon domaine, je souhaiterais faire en sorte que les premiers soins soient offerts à tous et que chacun puisse recevoir des prestations de qualité. Je souhaiterais également alléger la tâche aux étudiants en faisant en sorte que lorsqu’un professeur termine son programme, que ce dernier nous évalue directement là dessus. Malheureusement, ce qui se passe actuellement, c’est que si par exemple un professeur termine son programme en décembre, il nous faudra attendre le mois de février pour être évalué sur son programme, ce qui n’est pas optimal en terme d’apprentissage, de mon point de vu."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "J’habite déjà dans mon pays, j’envisage d’y rester."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Oui !! Après le bac il faut bien choisir sa filière. La choisir avec amour afin de pouvoir exercer avec passion à la fin de ses études. II faut garder à l’esprit que ce choix est personnel ; les parents peuvent vous conseiller mais vraiment, le dernier mot vous appartient, ne le perdez jamais de vu. Également, rapprochez-vous de professionnels qui exercent dans le milieu que vous visez, pour vous rassurer sur le fait que vous êtes à la hauteur du travail à accomplir ou s’il vous faudra développer des compétences supplémentaires de manière autonome."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "De mon côté ce ne sont pas des barrières qu’on me met par rapport aux études, mais une grosse pression. Ma mère compte beaucoup sur moi. Mais cette pression est positive car contribue à me rendre performant et m’incite à mettre en application les conseils qu’on me donne au quotidien."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 70,
    "popularity": 134,
    "source": "legacy_db"
  },
  {
    "slug": "t-souleymane-kamissoko-abraham",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Statistiques",
      "Économie",
      "Finance",
      "ENSEA Abidjan",
      "Côte d'Ivoire"
    ],
    "personName": "Souleymane Kamissoko Abraham",
    "roleFr": "Étudiant en magistère d'ingénieur économiste",
    "roleEn": "Economist-Engineer Master's student",
    "titleFr": "De l'ENSEA d'Abidjan à l'économie à Aix-Marseille",
    "titleEn": "From Abidjan's ENSEA to economics in Aix-Marseille",
    "hookFr": "Il a choisi une grande école plutôt que la fac pour éviter les grèves, puis a filé vers l'économie à Marseille.",
    "hookEn": "He picked a top school over university to dodge the strikes, then set off for economics in Marseille.",
    "summaryFr": "Ivoirien titulaire d'un bac scientifique, Souleymane a intégré l'ENSEA d'Abidjan, centre d'excellence régional de l'UEMOA, où il a obtenu ses diplômes d'agent et d'adjoint technique de la statistique. Passionné par le monde économique et financier, il poursuit désormais un magistère d'ingénieur économiste à l'École d'économie d'Aix-Marseille (AMSE). Son parcours illustre le passage d'une grande école africaine de statistique vers une spécialisation économique en France.",
    "summaryEn": "An Ivorian with a science baccalaureate, Souleymane joined ENSEA in Abidjan, UEMOA's regional center of excellence, where he earned his statistics technician diplomas. Drawn to economics and finance, he is now pursuing an economist-engineer master's degree at the Aix-Marseille School of Economics (AMSE). His journey shows the move from a leading African statistics school to an economics specialization in France.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes-vous ?",
        "answer": "Je suis Souleymane KAMISSOKO Abraham, je suis de nationalité Ivoirienne. Après l’obtention de mon baccalauréat série scientifique en 2014 au lycée classique d’Abidjan , j’ai intégré l’Ecole Nationale de Statistiques et d’Economie Appliquée (ENSEA-ABIDJAN). Après 3 années passées dans cette école, j’ai obtenu les diplômes d’agent et d’adjoint technique de la statistique. Par la suite, étant intéressé par le monde économique et financier, je poursuis ma formation à Marseille précisément à l’école d’économie d’Aix-Marseille (AMSE) où je suis actuellement la formation de magistère ingénieur économiste."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "J’ai choisi de passer le concours de l’ENSEA parce que je trouvais le système LMD de la faculté lent, notamment à cause des grèves. Par ailleurs, je voulais intégré une prestigieuse école après mon bac d’où le fait d’avoir opté pour l’ENSEA centre d’excellence régional de l’UEMOA, qui offre de belles perspectives. Mon choix pour l’AMSE, s’inscrit principalement dans un souci de devenir professionnel, c’est en quelque sorte la formation qu’il me faut pour compléter mon parcours et réaliser mes objectifs professionnels.La formation d’agent technique de la statistique se fait en 1 an, et vise à former des agents d’exécution de l’appareil statistique. La filière offre des connaissances de base de la méthode statistique et, surtout, de se familiariser à la production statistique. l’enseignement comprend à la fois des cours, des travaux dirigés et un mois de stage pratique sur le terrain. Quant à la formation d’adjoint technique de la statistique elle s’étend sur 2 années, et vise à former des cadres d’application qui ont pour rôle la production statistique et l’encadrement des enquêteurs sur le terrain. Elle comprend à la fois des cours théoriques, des travaux dirigés et deux mois de stage pratique sur le terrain.La formation de magistère ingénieur économiste est une formation bilingue( Français et anglais) qui forme aux techniques d’analyse économique et du big data. Elle s’étend sur 3 ans, avec chaque année une possibilité de stage en entreprise. Un semestre à l’international en 1 ère année de magistère est fortement recommandé. Al’issu de ces 3 années, vous disposerez de 3 diplômes : la licence d’économie et de gestion, le master en économie et le diplôme du magistère."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "ENSEA (Ecole Nationale de Statistiques et d’Economie Appliquée)AMSE (Aix-Marseille School of Economics)"
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "ENSEA sur concoursAMSE sur étude de dossier"
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ?",
        "answer": "Je finance mes études à travers des fonds propres. Cependant, il existe des bourses comme la bourse campus France."
      },
      {
        "question": "Comment décririez-vous le coût des études ?",
        "answer": "Abordable en termes de rapport qualité-prix"
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ?",
        "answer": "Etudiant (rire)"
      },
      {
        "question": "Est-ce une vocation ?",
        "answer": "Non, cest un tremplin à la vocation (rire)Plus sérieusement, j’envisage devenir un expert financier et oui, c’est une vocation car j’aurai passé toute ma scolarité à prendre des décisions conscientes afin d’aller dans cette direction."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "En général, ce métier consiste à structurer et mettre en forme la remontée des informations financières, contrôler les comptes, superviser et vérifier les processus et dispositifs mis en place pour le contrôle interne. Il faut aussi être hautement stratégique et un bon négociateur, car vous allez formuler des choix de management stratégiques, et conseiller l’entreprise sur des projets d’investissements. Le métier demande également d’être à l’afflux d’informations financières, d’être imaginatif et curieux, mais aussi d’ avoir un grand sens de la communication."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, nous devons construire nos pays ! J’ai des projets éducatifs, mais surtout humanitaires. Je ne souhaite pas donner plus de détails, je préfère répondre à cette question par des actes le moment venu."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "A long terme, oui, j’ai envie de rentrer définitivement. Mais bon tout dépendra aussi de ce que nous réserve l’avenir."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "La paresse peut paraître attrayante mais c’est au bout l’effort que se trouve la récompense. Il faut travailler pour réussir !"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 71,
    "popularity": 127,
    "source": "legacy_db"
  },
  {
    "slug": "t-mouhamadou-al-amine-sadio-sall",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Finance",
      "Sénégal",
      "UCAO",
      "Analyste financier",
      "Master"
    ],
    "personName": "Mouhamadou Al Amine Sadio Sall",
    "roleFr": "Étudiant en Master Finance, futur analyste financier",
    "roleEn": "Master's student in Finance, aspiring financial analyst",
    "titleFr": "De Dakar à Wall Street : devenir analyste financier",
    "titleEn": "From Dakar toward Wall Street: becoming a financial analyst",
    "hookFr": "« Le Loup de Wall Street » et sa famille l'ont mené vers la finance : cap sur analyste financier.",
    "hookEn": "The Wolf of Wall Street\" and his family drew him to finance: his goal is financial analyst.",
    "summaryFr": "Mouhamadou Al Amine Sadio Sall, Sénégalais de 23 ans, poursuit un Master en sciences économiques et de gestion, spécialité finance, à l'Université Catholique de l'Afrique de l'Ouest (UCAO). Inspiré par sa famille et par le film « Le Loup de Wall Street », il ambitionne de devenir analyste financier. Il détaille son parcours et les étapes concrètes pour intégrer l'UCAO, ouverte à tout bachelier africain.",
    "summaryEn": "Mouhamadou Al Amine Sadio Sall, a 23-year-old Senegalese student, is pursuing a Master's in economics and management with a finance specialization at the Catholic University of West Africa (UCAO). Inspired by his family and the film \"The Wolf of Wall Street,\" he aims to become a financial analyst. He walks through his path and the concrete steps to enroll at UCAO, which is open to any African high-school graduate.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Mouhamadou Al Amine Sadio Sall étudiant en Master 1 sciences économiques et de gestion spécialité finance, au Sénégal, j’ai 23 ans et je suis sénégalais."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "Mon souhait est de devenir Analyste Financier. L’envie m’a pris il y’a plusieurs années et je dirais que «Le loup de Wall-Street» m'a beaucoup motivé (rire). D’autres parts, dans ma famille nous sommes tous d'une façon ou d'une autre liés à cet univers, en particulier mes soeurs et cela a contribué à rendre cette destinée évidente pour moi."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "L'université Catholique de L'Afrique de L'Ouest ( UCAO). C’est une Université Internationale créée par la Conférence Épiscopale Régionale de l’Afrique de l’Ouest (CERAO). Elle est le plus grand réseau universitaire privé décentralisé d’Afrique avec des implantations d’Unités Universitaires spécifiques au Bénin, Burkina Faso, Côte d’Ivoire, Guinée, Mali, Sénégal et au Togo. Le Rectorat International est basé à Ouagadougou (Burkina Faso). La formation est assurée par des Enseignants de haut rang intervenant sur l’ensemble du réseau UCAO et dans les plus grandes Universités d’Afrique et du monde."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "L’université est ouverte à tout détenteur d’un baccalauréat, surtout si vous êtes africain. Pour postuler, 3 étapes :Etape 1: Vous prenez contact avec l'unité universitaire qui correspond à votre domaine d'étude, dans le pays qui vous intéresse.Etape 2: Vous envoyez une demande d'inscription à la faculté concernéeEtape 3: Vous effectuez votre inscription"
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Je ne suis pas parti à l’étranger pour mes études, je suis resté au Sénégal mais il existe de nombreux modes de financement pour quelqu’un qui en recherche, notamment la bourse d'excellence que normalement chaque pays offre à ses ressortissants, les bourses des mairies locales, renseignez-vous. Au niveau international, vous pouvez essayer de prendre contact avec l’ONU ou vous renseigner sur leurs offres de bourses pour les étudiants Ouest-Africains directement sur internet. Renseignez-vous sur le site de la Banque Mondiale également."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Assistant comptable. Ce n'est pas ma vocation. C’est un travail en alternance que j’ai choisi de faire afin de gagner en expérience et de me démarquer sur le marché du travail par rapport à mes camarades, une fois les études terminées. Pensez à vous trouver une façon de vous démarquer également, surtout lorsque vous aspirez à démarrer une carrière compétitive !"
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Mon travail actuel de comptable consiste à assister au quotidien le comptable principal dans ses tâches qui sont de répertorier et de classer les diverses opérations journalières afin d'en faire le compte.Le travail que j’aurai à faire lorsque je serai analyste financier est de procéder à l’évaluation des sociétés sous tous leurs aspects : rentabilité, ressources humaines, restructurations à opérer...Il me faudra rencontrer régulièrement les responsables de la communication financière, les directeurs financiers, directeurs généraux des sociétés du secteur qu’il étudie.En cas d’intervention sur les marchés financiers, il me faudra conseiller les vendeurs de la salle des marchés qui répercuteront ces conseils à leurs clients afin de mieux orienter leurs ordres d’achat ou de vente.Dans le cas où je serais emmené à travailler dans une banque, il me faudra exercer un rôle de conseil aux gestionnaires de portefeuilles sur l’opportunité d’effectuer tel ou tel placement. Dans les deux cas, je devrai suivre de très près les salles de marchés."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, au Sénégal je souhaiterais mettre en place une agence d'intérim, dans le but de faciliter la recherche d'emplois pour les demandeurs d’emploi."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Je ne suis pas à l’étranger, mais si je l’avais été, je répondrais que oui. On est mieux que chez soi. De plus, j’aime savourer cette insouciance qu’on ressent lorsqu’on vit auprès de ses proches (rire)."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Mon conseil est de tourner le dos aux futilités et d’aller à la quête du savoir."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Aucune contrainte, à part que je suis très très attaché à ma famille (rire). Plus sérieusement, non il n’y a rien à signaler à ce niveau."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 72,
    "popularity": 117,
    "source": "legacy_db"
  },
  {
    "slug": "t-temoignage-anonyme1",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Aménagement du territoire",
      "Gouvernance publique",
      "AES",
      "Niger",
      "Développement local"
    ],
    "personName": "Témoignage anonyme",
    "roleFr": "Étudiant en Master 2 Ingénierie du développement du territoire",
    "roleEn": "Master's student in Territorial Development Engineering",
    "titleFr": "De Niamey à l'aménagement du territoire : un choix guidé par l'avenir",
    "titleEn": "From Niamey to Territorial Planning: A Future-Driven Choice",
    "hookFr": "Face à l'urbanisation record du Niger, il a choisi d'étudier l'aménagement du territoire.",
    "hookEn": "Facing Niger's record urbanization, he chose to study territorial planning.",
    "summaryFr": "Étudiant nigérien de bientôt 25 ans, il a obtenu son bac économique et social à Niamey avant de poursuivre une licence AES puis un Master 2 en ingénierie du développement du territoire, aujourd'hui en stage de fin d'études. Il a choisi cette filière dès la seconde, convaincu que l'urbanisation rapide du Niger imposera tôt ou tard de repenser l'aménagement du territoire. Sa formation pluridisciplinaire mêle finances locales, gestion publique, comptabilité, droit et cartographie.",
    "summaryEn": "A Nigerien student soon turning 25, he earned his economics and social sciences baccalaureate in Niamey before completing an AES bachelor's degree and a Master's in territorial development engineering, now in his end-of-studies internship. He chose this path as early as tenth grade, convinced that Niger's rapid urbanization will eventually demand a rethinking of land-use planning. His multidisciplinary training blends local finance, public management, accounting, law, and cartography.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je m’appelle XXXX, j’aurai bientôt 25 ans, je suis nigérien et j’ai un baccalauréat général Economique et Social spécialité mathématiques que j’ai obtenu à Niamey.J’ai une licence AES (administration économique et social) parcours gouvernance des entreprises et des territoires. Aujourd’hui je suis en master 2 de sciences économique et social parcours ingénierie du développement du territoire, en stage de fin d’étude."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "L’idée m’est venue lorsque j’étais en classe de 2nde. Le constat est qu’au Niger on a le taux de croissance de la population la plus élevée au monde et à Niamey dans la capital, on assiste à une prolifération énorme de la population, due au phénomène d’urbanisation. L’évidence est que État ne prend pas cela en considération, on le remarque au fait que l’aménagement du territoire se fait de manière aléatoire. Effectuer une étude en aménagement du territoire permettra de répondre à une problématique qui se posera tôt ou tard dans le pays. Le diplôme est pluridisciplinaire et aborde plusieurs notions, notamment les finances locales, la gestion publique, la comptabilité, le droit et la cartographie. Une base solide en culture générale est de ce fait nécessaire."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Toute ma scolarité Post-Bac a été effectuée à l’université Toulouse Capital I (ARSENAL). L’université bénéficie d’une excellente renommée, que cela soit au niveau national ou international. La rigueur y est de mise."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "Etant donné que j’ai un bac Français, j’avais postulé via admission Post-Bac, c’était le système de l’époque. Aujourd’hui, si vous avez un bac français, il vous faudrait postuler plutôt via ParcoursSup. Pour les non détenteurs d’un bac français, il vous faudra passer par la procédure Campus France."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Mes études ont été pris en charge par ma famille, mais j’ai aussi travaillé en tant que livreur dominos pour alléger ma charge à ces derniers. Vous pouvez faire de même, étant donné qu’en France, contrairement aux Etats-Unis, les étudiants ont la chance de pouvoir travailler durant leurs études. Dans mon cas, au fil des années d’expérience, j’ai été promu assistant manager chez dominos, donc le revenu que je percevais vers la fin de mon contrat me permettait vraiment de vivre confortablement.Etudier en France est quelque chose d’accessible, même avec des financements limités, pour quelqu’un qui n’a pas peur de se donner au travail ! Néanmoins, je garde des réserves avec la hausse des coûts de scolarité, même si l’ordonnance ne concerne pas toutes les universités."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Pour l’instant je suis toujours étudiant mais plus tard, je me vois travailler dans une ONG entrain de réfléchir aux façon d’optimiser l’espace vaste dont on dispose au pays. Je souhaiterais m’assurer que le Niger de demain soit bâtit d’une façon majestueuse et respectueuse de l’environnement."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Question difficile, mais de façon concise, je dirais qu’à mes yeux le métier consistera à éssayer quotidiennement de faire connaître son pays à travers son travail dans le monde entier. Ca me fait mal qu’on soit toujours confondus au Nigéria. Si on rayonne de part notre majestuosité ou toute autre chose, cela changera la donne. Il est important d’utiliser notre territoire de façon rationnelle afin de répondre à la demande. Autrement dit, de répondre au challenge de la surpopulation dans la capital."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, je souhaiterais créer un cabinet de conseil pour les entreprises et les acteurs publics du territoire."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Oui, j’envisage de rentrer mais pas tout de suite, il me faut d’abord acquérir de l’expérience et accumuler une certaine richesse, sinon je risque de me retrouver à poser le thé et à regarder des filles passer dans ma fada alors que j’ai un Master en proche (rire).Je pense que je serai prêt à rentrer de façon définitif dans 5 ans au minimum et 10 ans au maximum."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Oui, j’ai deux conseils : 1) Déjà, il faut comprendre qu’il y’a un temps pour tout : un temps pour l’amusement et un temps pour le travail. 2) Il ne faut jamais abandonner. Dans mon cas, j’ai redoublé à deux reprises. Si j’avais abandonné, je ne serais pas dans mon confort actuel pour lequel je remercie Dieu. J’aurais pu arrêter les études en prétextant que je suis trop âgé pour ça, mais non, j’ai continué et je vous conseille d’en faire de même."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non, aucun pour l’instant"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 73,
    "popularity": 109,
    "source": "legacy_db"
  },
  {
    "slug": "t-sadou-boubacar",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Électronique",
      "Télécommunications",
      "Systèmes embarqués",
      "Bourse ANAB",
      "Niger"
    ],
    "personName": "Sadou Boubacar",
    "roleFr": "Étudiant en Master 2 Électronique, Systèmes Embarqués et Télécommunications",
    "roleEn": "Master's student in Electronics, Embedded Systems and Telecommunications",
    "titleFr": "Du BAC C au Master en Systèmes Embarqués : le parcours de Sadou",
    "titleEn": "From a BAC C to a Master's in Embedded Systems: Sadou's journey",
    "hookFr": "Passionné de maths et de physique, il a transformé un BAC C arraché de haute lutte en études en Europe.",
    "hookEn": "A passion for math and physics turned a hard-won science diploma into studies in Europe.",
    "summaryFr": "Originaire de Birni N'gaouré au Niger, Sadou Boubacar a décroché son BAC C malgré des conditions difficiles, sans cours de soutien ni documents et avec des grèves répétées. Grâce à une bourse de coopération de l'ANAB, il part étudier les sciences en Algérie, puis poursuit en Master 2 Électronique pour les Systèmes Embarqués et Télécommunications à l'Université Toulouse III - Paul Sabatier.",
    "summaryEn": "Born in Birni N'gaouré, Niger, Sadou Boubacar earned his science-track BAC C despite tough conditions, with no tutoring, no textbooks and recurring teacher strikes. Thanks to an ANAB cooperation scholarship, he went to study science in Algeria, then moved on to a Master's in Electronics for Embedded Systems and Telecommunications at Université Toulouse III - Paul Sabatier.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Sadou Aboubacar?",
        "answer": "Je suis né le 01/01/1991 à Birni N’gaouré. Actuellement je suis en master 2 Electronique pour les Systèmes Embarqués et Télécommunications à l’Université Toulouse III- Paul Sabatier. J’ai fait mes études à l’école primaire Birni garçons puis au CES Boboye où j’ai obtenu mon BAC C (scientifique). Ma passion pour les mathématiques et la physique-chimie et aussi mes résultats à l’issue de la classe de seconde m’ont permis d’être admis en série C. Je me rappelle bien, nous étions au nombre de trois en classe de première et cinq en terminale. J’avoue que les conditions n’étaient pas réunies pour faire la série C car nous n’avons pas eu droit aux cours de soutien, nous n’avons pas eu non plus les documents nécessaires à notre disposition sans oublier les grèves récurrentes des enseignants. Il a fallu beaucoup de sacrifice pour pouvoir s’en sortir.Le BAC en poche, j’ai rejoint la faculté des sciences du Centre Universitaire d’Ain temouchent en Algérie."
      },
      {
        "question": "Pourquoi l’Algérie ?",
        "answer": "Après les résultats du baccalauréat, je me suis confronté au dilemme de choix des études supérieures.C’est ainsi que j’ai consulté certains de mes professeurs qui m’ont exhorté de déposer un dossier à l’ANAB pour une bourse de coopération. Je me suis précipité pour chercher le formulaire à l’ANAB car c’était au dernier moment. J’ai déposé deux dossiers l’un pour la bourse de coopération du Maroc et l’autre pour l’Algérie. Finalement, j’ai été retenu pour celle de l’AlgérieAu moment où je préparai mon départ pour l’Algérie, j’ai eu des rumeurs comme quoi, les conditions de vie en Algérie ne sont pas favorables pour les études et là j’étais à un pas de tout laisser tomber. Il a fallu encore l’intervention de l’un de mes professeurs qui m’a mis en contact avec un ancien étudiant en Algérie, auprès duquel j’ai eu quelques informations réconfortantes.Une fois au pays de l’oncle Boudiaf, j’ai réalisé que tout ce qui a été dit sur les conditions de vie n’était pas vrai. En effet, en Algérie, toutes les conditions sont réunies pour étudier : - D’abord il n’y a pas de frais d’inscription, les étudiants sont logés, nourris et soignés gratuitement.- Ensuite, il y a l’accès à la documentation et à l’internet.En Algérie, j’ai connu et côtoyé des étudiants issus de plusieurs pays de l’Afrique et cela a été une expérience très enrichissant. J’ai fait deux ans de tronc commun en Sciences et Technologie (ST) avant de faire une licence en Electronique et Télécommunications"
      },
      {
        "question": "Université Paul Sabatier",
        "answer": "Une fois ma licence en poche, à la recherche d’un nouveau challenge, j’ai postulé pour un master en France notamment à l’Université Paul Sabatier , où je finalise présentement mon Master 2 en Electronique pour les Systèmes Embarqués et Télécommunications, spécialité : Microondes, Electromagnétisme et Optoélectronique."
      },
      {
        "question": "Projets professionnels",
        "answer": "Mon projet à court terme c’est d’avoir mon Master 2 recherche. A long terme, je souhaite faire une thèse en optoélectronique dans le but de devenir enseignant chercheur, si Dieu le veut."
      },
      {
        "question": "Conseils aux jeunes Nigériens",
        "answer": "Je conseille aux jeunes de se fixer des objectifs et de se battre continuellement pour les atteindre quelque soient les conditions de départ. Aussi, il faut oser et avoir confiance en soi. Rien n’est impossible avec la volonté et la détermination. Et enfin, il faut chercher l’information auprès des « bonnes personnes."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 74,
    "popularity": 107,
    "source": "legacy_db"
  },
  {
    "slug": "t-sadia-gado",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Finance",
      "Bourse UWC",
      "Wall Street",
      "Niger",
      "Entrepreneuriat"
    ],
    "personName": "Sadia Gado",
    "roleFr": "Gestionnaire du risque de liquidité chez UBS (New York) et entrepreneure immobilier",
    "roleEn": "Liquidity Risk Manager at UBS (New York) and real estate entrepreneur",
    "titleFr": "De Niamey à Wall Street : la finance grâce à une bourse UWC",
    "titleEn": "From Niamey to Wall Street: finance through a UWC scholarship",
    "hookFr": "Une bourse UWC obtenue en seconde l'a menée de Niamey jusqu'à la finance à New York.",
    "hookEn": "A UWC scholarship in high school took her from Niamey all the way to finance in New York.",
    "summaryFr": "Née à Dosso et grandie à Niamey, Sadia Gado a décroché la bourse des United World Colleges en seconde, un tremplin qui l'a menée jusqu'à Wall Street. Aujourd'hui chargée de la gestion du risque de liquidité pour la banque suisse UBS à New York, elle est aussi entrepreneure dans l'immobilier. Passionnée de business depuis l'enfance, elle a fait de la finance sa vocation.",
    "summaryEn": "Born in Dosso and raised in Niamey, Sadia Gado earned a United World Colleges scholarship in high school, a springboard that eventually took her to Wall Street. She now manages liquidity risk for the Swiss bank UBS in New York and is also a real estate entrepreneur. Fascinated by business since childhood, she turned finance into her calling.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je me nomme Sadia Gado (Mme Zakara) âgée de 30ans, née à Dosso, grandie à Niamey. Je suis chargée de la gestion du risque de liquidité pour la banque Suisse UBS, à New York. Avant UBS, j’ai pratiqué dans le même secteur dans plusieurs autres banques sur Wall Street. Je suis aussi entrepreneure dans le domaine de l’immobilier, mariée et maman de deux adorables petits garçons."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "Le domaine de la finance m’a toujours intrigué, depuis toute petite j’ai toujours été fascinée par le business. Le fait d’apporter de la valeur à la société et d’être rémunérer en conséquence. A mon époque, le commerce n’était pas une vocation encouragée pour ceux qui veulent faire des « études sérieuses ». Je me dis que ça a changé depuis lors (rires)."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "J’ai commencé mon cycle primaire à l’école Yasmina de Yantala avant de quitter pour Dakar avec mes parents. J’y ai obtenu mon certificat et intégré le collège bilingue Enko WACA des Almadies à Dakar. Nous sommes revenus à Niamey en 2003 ou j’ai continué mon cycle secondaire à l’Eau Vive. Je me suis aussi inscrite à certains programmes du Centre Américain de Niamey pour ne pas perdre mon niveau d’Anglais. Après avoir obtenu mon brevet (coucou à ma promotion, la première à réussir 100% au Brevet), j’ai postulé pour la bourse des United World Colleges (UWCs) en classe de seconde.\nJ’ai quitté le Niger à l’âge de 16 ans, pour terminer mon cycle au UWC Li Po Chun de Hong Kong. J’ai suivi le cursus du Bac international et ai obtenu une bourse de l’Université de Richmond en Virginie, aux Etats Unis. J’ai obtenu deux Bacheliers à l’U of R, l’un en Finance et l’autre en Mathématiques pures. Quelques années après, je fais mon Master en Ingénierie financière à l’Université de Fordham à New York."
      },
      {
        "question": "Comment intégrer United World Colleges (UWCs)? et obtenir la bourse ?",
        "answer": "Pour intégrer les UWCs, il vous suffit de postuler pour le concours que nous organisons chaque année à Niamey. L’année passée, nous avons aussi commencer à recruter des élèves dans les autres régions du Niger. Ce sont des écoles formidables qui nous ont offert beaucoup d’opportunités à moi et d’autres Nigériens qui l’ont déjà fréquenté. Les études aux UWCs ne sont pas toujours gratuites (et peuvent même couter très chères), mais le plus c’est que tout étudiant des UWCs a une bourse universitaire Américaine (Davis) garantie après l’obtention de son bac.\nPour y postuler : Il vous suffit d’être Nigérien, âgée d’entre 15 à 18ans et d’avoir une moyenne annuelle de 14/20 pour l’année scolaire 2019/2020.\nPour plus d’information, rendez-vous sur le site du comité national du Niger : www.ne.uwc.org"
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Le coût des études est très cher aux États Unis (comparé à l’Europe), mais si vous excellez dans vos études et avez un bon niveau d’Anglais il y’a toujours des bourses d’études disponibles."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je suis chargée de la gestion du risque de liquidité pour les banques d’investissements. L’activité traditionnelle des banques consiste à emprunter sur les marchés des liquidités (argent) pour financer l’octroi de crédits. En cas de contraction des marchés, ce mécanisme de transformation, s’il est poussé à l’extrême, peut engendrer des difficultés de financement et de refinancement pour la banque. C’est ce qu’on appelle le risque de liquidité."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Mon rôle est d’étudier et de quantifier le risque de liquidité à travers des modèles financiers complexes et d’autres outils à ma disposition."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, je pense qu’on rêve tous d’un Niger meilleur, à l’image de ces pays occidentaux dans lesquels nous vivons. Pour apporter ma petite pierre a l’édifice, nous organisons à travers le comité national du Niger, le concours des UWCs pour identifier les meilleurs élèves lycéens et leur offrir une place dans l’une de ces prestigieuses écoles. Les écoles à leur tour font la détermination du montant des bourses octroyées aux élèves Nigériens\nDans le futur, j’espère aussi devenir une « angel investor » pour financer les bonnes idées des jeunes entrepreneurs Nigériens. Chez nous, ce n’est pas le talent ou l’intellect qui manque, mais plutôt le capital financier."
      },
      {
        "question": "Envisagez-vous de rentrer ?",
        "answer": "Oui, lorsque les conditions seront réunies."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Soyez maître de votre propre destinée, persévérez et osez ! Ne laissez pas la difficulté d’une tâche vous décourager en essayant d’atteindre votre objectif. Et aussi, chose qui peut parfois être difficile, ne laisser pas la famille ou la société vous détraquer. Ce message c’est surtout pour mes sœurs Nigériennes qui sont parfois encouragées à avoir des ambitions « modérées »."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Je ne dirais pas « contraintes » mais plutôt obligations familiales comme toute autre personne mariée. Mon mari et moi travaillons tous les deux pendant de longues heures du Lundi au Vendredi (entre 50 à 80 heures par semaine) donc nous nous partageons les tâches ménagères équitablement. De la cuisine au ménage, en passant par les moindres besoins de nos enfants, nous le faisons à deux."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 75,
    "popularity": 107,
    "source": "legacy_db"
  },
  {
    "slug": "t-moussa-yaye",
    "kind": "text",
    "fieldId": "d08",
    "tags": [
      "géographie",
      "doctorat",
      "eau",
      "recherche",
      "Niger"
    ],
    "personName": "Moussa Yayé",
    "roleFr": "Docteur en Géographie",
    "roleEn": "PhD in Geography",
    "titleFr": "De Dargol au doctorat : la géographie de l'eau au Niger",
    "titleEn": "From Dargol to a PhD: mapping Niger's water challenge",
    "hookFr": "D'une meilleure note en géo au bac à un doctorat sur l'eau en milieu rural nigérien.",
    "hookEn": "From a top high-school geography grade to a PhD on water in rural Niger.",
    "summaryFr": "Né à Dargol dans l'ouest du Niger, Moussa Yayé s'est passionné pour la cartographie et a suivi la géographie de la licence jusqu'à la thèse. Porté par un devoir scientifique autour de la problématique de l'eau en milieu rural nigérien, il a obtenu en 2014 une bourse du gouvernement français pour une thèse en cotutelle entre Toulouse Jean Jaurès et l'université Abdou Moumouni de Niamey. Aujourd'hui docteur, il veut consacrer sa vie à la recherche et à l'enseignement supérieur au Niger.",
    "summaryEn": "Born in Dargol in western Niger, Moussa Yayé fell in love with cartography and pursued geography from his bachelor's all the way to a doctorate. Driven by a scientific commitment to the issue of water in rural Niger, he won a French government scholarship in 2014 for a joint PhD between Toulouse Jean Jaurès and Abdou Moumouni University in Niamey. Now a doctor, he plans to devote his life to research and higher education in Niger.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Moussa Yayé?",
        "answer": "Moussa est de nationalité nigérienne, né à Dargol dans l'ouest du Niger. Il a fait parcours scolaire à Tera puis à Niamey, où il obtient le bac en 2004.J'ai choisi de faire la géographie à l'université parce-que j'avais eu meilleure note en histoire géographie au bac et aussi la cartographie me passionne."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à faire une thèse?",
        "answer": "Inscris en géographie, de diplôme en diplôme, de la licence en passant par la maîtrise puis le master 2, j'avais acquis les compétences techniques et méthodologique. En plus de cela, je ressentais le besoin d'aller jusqu'au bout. J'avais déjà commencé à travailler sur problématique de l'eau en milieu rural nigérien en maîtrise puis en master 2, j'ai senti un devoir scientifique de poursuivre la question en thèse."
      },
      {
        "question": "Avez bénéficié d’une bourse?",
        "answer": "Déjà après la maîtrise j'ai travaille à la fois sur des programmes de recherche avec des chercheurs français et américains. Après le master 2 obtenu en 2013, je me suis mis à chercher un financement pour la thèse. En en avril 2014, j'ai eu la bourse du gouvernement français pour une thèse en cotutelle en l'université Toulouse Jean Jaures et l'université Abdou Moumouni de Niamey."
      },
      {
        "question": "Aujourd’hui Docteur en Géographie, Avez vous des projet pour le Niger?",
        "answer": "Mon projet pour Niger après le doctorat est de participer à la formation et l'encadrement des jeunes nigeriens. Je compte consacrer ma vie à la recherche et à l'enseignement supérieur au Niger."
      },
      {
        "question": "Avez-vous des conseils à donner à nos jeunes nigériens qui envisagent de faire une thèse?",
        "answer": "Mes conseils pour les jeunes nigériens est de faire des études supérieures, de fréquenter les meilleures écoles, universités du monde et surtout de s'y mettre entièrement pour briller.Le développement du Niger suivra tout naturellement après la formation en qualité et en nombre."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 76,
    "popularity": 104,
    "source": "legacy_db"
  },
  {
    "slug": "t-osse-anon-daniel-pascal",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Statistique",
      "Économie",
      "Finance",
      "Côte d'Ivoire",
      "Aix-Marseille"
    ],
    "personName": "Osse Anon Daniel Pascal",
    "roleFr": "Étudiant en magistère ingénieur économiste (spécialité finance)",
    "roleEn": "Economics engineering graduate student (finance track)",
    "titleFr": "D'Abidjan à Aix-Marseille : les chiffres au service de la finance",
    "titleEn": "From Abidjan to Aix-Marseille: numbers as a path to finance",
    "hookFr": "De l'ENSEA d'Abidjan à l'économie quantitative à Aix-Marseille, avec la finance en ligne de mire.",
    "hookEn": "From Abidjan's ENSEA to quantitative economics in Aix-Marseille, with finance as the goal.",
    "summaryFr": "Daniel Pascal, étudiant ivoirien, a débuté par trois ans de statistique à l'ENSEA de Côte d'Ivoire, réputée et accessible sur concours. Il poursuit désormais un magistère d'ingénieur économiste à l'Aix-Marseille School of Economics, en parcours d'économie quantitative, avec pour objectif de se spécialiser en finance. Son parcours illustre comment une base solide en statistique ouvre les portes des études économiques en France.",
    "summaryEn": "Daniel Pascal, an Ivorian student, started with three years of statistics at ENSEA in Côte d'Ivoire, a well-known school entered through competitive exams. He is now pursuing an economics engineering master's (magistère) at the Aix-Marseille School of Economics on a quantitative economics track, aiming to specialize in finance. His journey shows how a strong statistics foundation can open the door to economics studies in France.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes vous ?",
        "answer": "Je suis OSSE Anon Daniel Pascal, étudiant ivoirien en magistère ingénieur économiste au sein de l’université d’Aix-Marseille.Après le BAC, j’ai entamé 3 années d’étude en statistique à l’Ecole Nationale Supérieure de Statistique et d’Economie Appliquée (ENSEA Côte d’Ivoire), puis je suis venu en France continuer en parcours économie quantitatif avec pour objectif de me spécialiser en Finance."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "J’ai choisi le parcours Statistique pour ma préférence pour les chiffres et les méthodes quantitatives ainsi que pour la renommée de l’école ENSEA en Côte d’Ivoire. Au sein de ces études en statistique, j’ai reçu des cours de base en économie, ce qui a motivé mon choix pour la filière économique en vue de me spécialiser en finance."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "J’ai fréquenté à l’Ecole Nationale de Statistique et d’Economie Appliquée (ENSEA Côte d’Ivoire) de 2014 à 2017, et obtenu les diplômes suivants : Agent et Adjoint technique de la statistique.Depuis Septembre 2017, j’étudie le Magistère Ingénieur Economiste à Aix-Marseille School of Economics (AMSE), école d’économie au sein de l’université d’Aix-Marseille."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "L’admission à l’ENSEA se fait par voie de concours. Pour les niveaux dans lesquels j’ai eu à étudier, les épreuves du concours sont : Mathématiques, Calcul numérique et Culture d’ordre général (Dissertation).L’entrée à l’AMSE se fait par études de dossier sur le site de Campus France (Etudes en France)."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "A l’étranger, mes études sont financées par mes parents. Toutefois il existe de nombreux jobs étudiants et d’été pour aider à financer ses études."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je suis toujours étudiant."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Non, pas encore."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Peut-être mais pas directement après les études."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Je conseillerais aux jeunes d’aimer apprendre, de continuer à le faire toujours même après les études car c’est le savoir, la clé du succès. Aussi, il ne faudrait pas abandonner face aux difficultés des études ou de la vie, toujours tenter sa chance quand on désire avoir quelque chose, et ceux même si les opportunités sont réduites. Ainsi, la couronne de la réussite est au bout."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non, je n’ai pas de contraintes familiales."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 77,
    "popularity": 104,
    "source": "legacy_db"
  },
  {
    "slug": "t-mariamou-ibrahim",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Ressources Humaines",
      "CESAG",
      "Études au Ghana",
      "Psychologie",
      "Carrière internationale"
    ],
    "personName": "Mariamou Ibrahim",
    "roleFr": "Responsable Ressources Humaines",
    "roleEn": "Human Resources Manager",
    "titleFr": "Du Ghana au CESAG : devenir responsable RH à l'international",
    "titleEn": "From Ghana to CESAG: becoming an international HR manager",
    "hookFr": "De la psychologie au Ghana à la RH au CESAG : le parcours qui l'a menée à l'international.",
    "hookEn": "From psychology in Ghana to HR at CESAG: the path that took her to an international career.",
    "summaryFr": "Après un BAC D à Niamey, Mariamou Ibrahim part étudier la psychologie et les sciences politiques à l'université du Ghana (Legon), puis se spécialise en gestion des ressources humaines au CESAG (DESS). Guidée dès le lycée par le désir d'un métier ouvert sur l'échange et le voyage, elle est aujourd'hui responsable RH au sein d'une structure internationale au Niger.",
    "summaryEn": "After earning a science-track baccalaureate in Niamey, Mariamou Ibrahim studied psychology and political science at the University of Ghana (Legon), then specialized in human resources management at CESAG (postgraduate DESS). Driven since high school by the wish for a people-facing, mobile career, she is now an HR manager at an international organization in Niger.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Mariamou?",
        "answer": "Je me nomme Mariamou Ibrahim Mamane Jacques. Je suis actuellement responsable RH au sein d’une structure internationale au Niger.J’ai réalisé mes études primaires à l’école Mission, mes études secondaires au collège Soni et au lycée Kouara à Niamey. Suite à l’obtention d’un BAC D, j’ai suivi des études en Psychologie et Sciences Politiques à l’université du Ghana, à Legon, études sanctionnées par un Bachelor (double major) après trois années d’études.Par la suite, j’ai rejoint le CESAG pour un deuxième cycle universitaire où j’ai poursuivi une formation en vue de l’obtention d’un Diplôme d’Études Supérieures Spécialisées (DESS) en gestion des ressources humaines."
      },
      {
        "question": "Jeune, de quelle profession rêviez-vous ? Comment avez-vous bâti votre projet de formation ?",
        "answer": "Déjà au lycée, je rêvais d’une profession qui me permettrait de ne pas rester cloisonnée dans un bureau et de privilégier interactions et échanges d’idées.Je voulais devenir pharmacienne ou consultante, en somme un métier qui me permettrait de voyager, de découvrir d’autres perspectives et de m’enrichir. J’ai en fait très tôt été convaincue de l’importance et de la valeur de l’enrichissement par autrui. Forte de ce que je savais de moi, de mes envies, de mes convictions, je me suis dirigée vers l’étude de la psychologie et des sciences politiques au Ghana."
      },
      {
        "question": "Comment avez-vous eu connaissance du CESAG ?",
        "answer": "J’ai connu le CESAG très tôt car mes parents y avaient réalisé également leur 2ème cycle.Quelles sont les raisons qui vous ont conduit à intégrer le CESAG ? Pour suivre quelle formation ?Je m’étais beaucoup intéressée à la psychologie du comportement et à celle du travail lors de mon premier cycle. J’ai décidé de parfaire mes connaissances en psychologie et de leur trouver une application au monde du travail en suivant une formation spécialisée dans les ressources humaines.Au travers de son DESS en gestion des ressources humaines (GRH), le CESAG m’a ouvert la porte de la GRH en entreprise, tout en s’appuyant et en développant les connaissances générales et psychologiques que j’avais préalablement acquises."
      },
      {
        "question": "Comment avez-vous intégré le CESAG ?",
        "answer": "Intégrer le CESAG demande une préparation certaine. Le succès aux épreuves nécessite culture générale, connaissances dans le domaine de la formation visée, une certaine aisance à l’oral et de la confiance en soi lors des entretiens. Concrètement, il faut se tenir informé de l’actualité du domaine ciblé et du monde de l’entreprise.Pour suivre une formation de type DESS, il faut passer un test écrit et oral après acceptation du dossier de candidature. J’ai préparé ces tests en me documentant beaucoup sur la GRH, le développement personnel et la conduite d’entretiens.ÉTUDIER AU CESAG, LES AVANTAGES D’UNE ÉCOLE AFRICAINE DE RÉFÉRENCE.La qualité des formations proposées par le CESAG et les diplômes afférents concurrencent directement les formations supérieures dispensées dans les universités et écoles d’Amérique, d’Europe ou d’Asie. Le coût de revient des études est largement inférieur pour un niveau d’enseignement équivalent et même mieux adapté à l’environnement socio-économique, juridique et culturel de ses futurs cadres."
      },
      {
        "question": "Quelles sont les possibilités de financement de la formation au CESAG pour un étudiant Nigérien?",
        "answer": "L’ANAB est la source de financement des bourses pour le candidat Nigérien. Le candidat peut également rechercher d’autres bourses internationales comme celles offertes par la Coopération française, la Coopération technique belge (CTB), ou la Confédération Suisse au travers de la CFBE."
      },
      {
        "question": "Quelle est la valeur du diplôme du CESAG sur le marché du travail ? S’agit-il d’un diplôme recherché de manière privilégiée par les recruteurs du Niger / de l’Afrique de l’Ouest ? Lesquels ?",
        "answer": "La valeur du diplôme du CESAG transcende la frontière nigérienne et s’étend aux pays francophones, tout particulièrement en Afrique de l’Ouest, de l’Est et du Centre. Le diplôme du CESAG est également reconnu en France : certains diplômés du CESAG sont ainsi coparrainés par des institutions françaises telles que l’université de Paris-Dauphine (MBA CESAG-Paris-Dauphine).Les diplômés trouvent facilement un travail une fois leur diplôme en poche. Le secteur bancaire est ainsi l’un des premiers employeurs des étudiants issus du CESAG. Les diplômés s’insèrent également aisément dans les secteurs publics et privés, minier en particulier.Quelle profession exercez-vous aujourd’hui et où ? En quoi votre cursus au CESAG vous a-t-il permis d’exercer ce métier / d’occuper ce poste ?Je suis actuellement responsable des ressources humaines auprès d’une ONG américaine présente au Niger. Mes études au CESAG ont forgé ma personnalité et aiguisé mes compétences. Elles m’ont permis de développer rigueur et créativité, atouts importants pour faire la différence sur le marché du travail.Les formations du CESAG mêlent cours théoriques et applications pratiques : travaux de groupe ou personnels, recherches et exposés à partir de cas réels, simulations en entreprise ou échanges entre étudiants sur des sujets donnés. Un stage de fin d’études d’une durée minimale de trois mois est par ailleurs obligatoire. J’ai pour ma part effectué un premier stage de deux mois à l’hôpital FAAN de Dakar, puis un second stage de trois mois au sein de PUBLICOM Dakar (société privée de communication). Ce dernier stage a servi de base à la rédaction de mon mémoire de fin d’études. Il m’a ainsi été très facile de m’adapter au milieu professionnel et d’assumer rapidement les responsabilités inhérentes à mon métier."
      },
      {
        "question": "Quelles sont les possibilités de financement de la formation au CESAG pour un étudiant Nigérien?",
        "answer": "Je recommande vivement le CESAG à tous pour la qualité et la valeur du diplôme tant d’un point vue académique que professionnel. On en sort équipé pour composer avec les réalités du monde du travail.Source: site Ose-Niger. Interview réalisée par Abdoul Moumouni Nouhou."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 78,
    "popularity": 102,
    "source": "legacy_db"
  },
  {
    "slug": "t-fatchima-ali",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Météorologie",
      "Big Data",
      "Ingénierie",
      "Bourse d'études",
      "Niger"
    ],
    "personName": "Fatchima Ali Laouali",
    "roleFr": "Élève ingénieure en météorologie, spécialité statistique et Big Data",
    "roleEn": "Meteorology engineering student, specializing in statistics and Big Data",
    "titleFr": "De Dosso à Toulouse : ingénieure en météorologie et Big Data",
    "titleEn": "From Dosso to Toulouse: becoming a meteorology and Big Data engineer",
    "hookFr": "Du bac série C à Niamey au calcul haute performance à Toulouse : la météo derrière la boîte noire.",
    "hookEn": "From a science bac in Niamey to high-performance computing in Toulouse: the data science behind the weather.",
    "summaryFr": "Fatchima Ali Laouali, née à Dosso au Niger, est élève ingénieure en météorologie spécialité statistique à l'École nationale de la météorologie (ENM) de Toulouse, après un premier cursus à l'EHTP de Casablanca grâce à une bourse de coopération marocaine. Elle suit aujourd'hui le parcours Calcul Haute Performance (HPC) et Big Data à l'ENSEEIHT, où elle passe de la physique de l'atmosphère au calcul scientifique. Son parcours montre que la météo moderne repose sur un vrai travail de traitement des données.",
    "summaryEn": "Fatchima Ali Laouali, born in Dosso, Niger, is a meteorology engineering student specializing in statistics at the National School of Meteorology (ENM) in Toulouse, after a first degree at EHTP in Casablanca funded by a Moroccan cooperation scholarship. She now follows the High-Performance Computing (HPC) and Big Data track at ENSEEIHT, moving from atmospheric physics to scientific computing. Her journey shows that modern meteorology relies on serious data processing behind the scenes.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Fatchima?",
        "answer": "Je me nomme Fatchima Ali Laouali, élève ingénieure en météorologie spécialité Statistique à l’école nationale de la météorologie (ENM) de Toulouse, en prévision de l’obtention d’un second diplôme d’ingénieur. Auparavant, j’étais élève ingénieure en météorologie à l’école Hassania des travaux publics (EHTP) à Casablanca. L’ENM nous donne l’opportunité d’approfondir nos connaissances en partenariat avec d’autres écoles d’ingénieurs. Je passe donc de la physique de l’atmosphère au calcul scientifique. Un large choix de perspectives, des cursus en partenariat avec l'ENSEEIHT. Actuellement je suis le parcours HPC (Calcul Haute Performance) et Big Data à l’ENSEEIHT..Hé oui la météo à la boîte noire, ce n’est pas seulement quel temps fait-il ? Combien de millimètres de pluie sont tombé dans cette zone ? Etc. Il y a tout un traitement derrière...Je suis née le 03 Novembre 1992 à Dosso. J’ai suivi mon cycle primaire à Zinder, Maradi et Niamey. Après l’obtention du Certificat d’Etudes du Premier Degré, j’ai intégré le CEG7 de Niamey où j’ai obtenu mon BEPC. Par la suite, j’ai intégré le collège puis le lycée Mariama. Les trois années au lycée ont été riches en expérience. Après l’obtention de mon baccalauréat série C avec une mention bien, j’ai postulé pour la bourse de coopération Marocaine à l’ANAB. J’ai été accepté en licence Mathématiques Informatique et Physique(MIP) à la faculté des sciences et techniques d’Errachidia. L’avantage de MIP, était que j’avais l’opportunité d’intégré plusieurs grandes écoles d’ingénieur du Maroc."
      },
      {
        "question": "Qu’est ce qui vous a motivé à intégrer la météorologie ?",
        "answer": "Depuis toute petite je me demandais ce qui se passait dans le ciel, me posais des questions du genre pourquoi les nuages ne tombent pas, pourquoi la pluie, pourquoi le ciel est bleu etc... C’est au collège que mon amour pour la physique s’est développé, ma curiosité pour les phénomènes atmosphériques a augmenté. En faisant des recherches j’ai trouvé que la météorologie était la science qui pourrait satisfaire ma curiosité. Dès lors, elle est devenue une passion pour moi. Je voyais, je comprenais les lois de la nature... Au-delà de cela j’ai vu que les météorologues utilisent des supercalculateurs et des appareils sophistiqués comme le radar, l'électronique avec des logiciels performants et spécifiques, mais surtout des images satellites pour étudier les données analogiques. Et après le traitement des informations, le météorologue délivre le résultat final permettant de prévoir le temps. Au vue de tout cela, ma motivation pour le métier de météorologue s’est accentuée. The meteorological dream commence... !"
      },
      {
        "question": "Comment intégrer l’Ecole Nationale de la Météorologie en France et qui peut intégrer cette filière ?",
        "answer": "Il ya plusieurs possibilités pour intégrer l’école nationale de la météorologie de Toulouse : D’une part par concours ouvert aux candidats titulaires d’une licence scientifique ayant validé une première année d’un master scientifique ou aux titulaires d’une maîtrise de sciences ou une qualification reconnue équivalente à l’un de ces titres ou diplômes. D’autre part, par un partenariat entre l’école nationale de la météorologie et d’autres écoles comme l’école Hassania des travaux public (EHTP) de Casablanca. Dans les 2 cas l’accès à la scolarité se fait directement en deuxième année de cycle ingénieur. Par ailleurs le concours externe ouvert au niveau des classes préparatoires aux grandes écoles (CPGE) filières MP, PC et PSI permet de recruter des élèves (ingénieurs des travaux de la météorologie) fonctionnaires et non fonctionnaires (civils). Dans ce dernier cas, l’accès à la scolarité se fait en première année du cycle ingénieur."
      },
      {
        "question": "On fait quoi après des études d’ingénieur en météorologie ?",
        "answer": "Après les études d’ingénieur en météorologie plusieurs choix s’offrent à nous, travailler en : prévision du temps, statistique, informatique, calcul scientifique, modélisation de l’atmosphère, de l’océan, hydrologie qualité de l’air, changement climatique, énergies renouvelables, météorologie aéronautique, météorologie satellitaire, météorologie tropicale, etc. on peut aussi s’orienter vers la recherche. Le métier de météorologue est un travail purement scientifique nécessitant une forte capacité d'analyse, d'interprétation, de calcul et de synthèse des données atmosphériques. Il doit aussi maîtriser parfaitement l'anglais, la langue utilisée en météorologie. En plus d'un diplôme, le professionnel doit s'adapter aux conditions de travail souvent extrêmes, afin de répondre aux besoins de la population et des autres clients."
      },
      {
        "question": "Vie professionnelle ou le doctorat pour vous ?",
        "answer": "Pour le moment c’est la vie professionnelle, j’ai envie d’avoir plus d’expérience dans mon domaine."
      },
      {
        "question": "Avez-vous des projets pour le Niger ? C’est quoi la suite ?",
        "answer": "Oui, en parallèle avec ma vie professionnelle, j’aimerais faire de entrepreneuriat social au Niger. Entrepreneuriat pour moi est un véritable accélérateur dans l’acquisition de compétences et d’expériences. J’élabore déjà des projets pour le Niger, reste la mise en œuvre. Au Niger, les besoins se font ressentir."
      },
      {
        "question": "Avez-vous des conseils à donner aux jeunes Nigériens ?",
        "answer": "Après le bac c’est une large gamme de domaines qui s’offre à eux. Il faut bien réfléchir avant de choisir sa filière. Il est primordial de se poser les bonnes questions avant de se lancer dans l’aventure, par exemple quels sont tes centres d’intérêts ? Quel métier veux tu exercer ? Quelle formation conduit à ce métier ? Le futur c'est maintenant car c'est notre choix qui le conditionne. L'avenir de notre pays repose entre nos mains et par conséquent nous avons l'obligation de se mettre au travail afin de promouvoir un avenir meilleur pour les générations futures."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 79,
    "popularity": 96,
    "source": "legacy_db"
  },
  {
    "slug": "t-claire-moine",
    "kind": "text",
    "fieldId": "d04",
    "tags": [
      "Orthoptie",
      "Santé",
      "Reconversion",
      "Concours",
      "Persévérance"
    ],
    "personName": "Claire Moine",
    "roleFr": "Orthoptiste",
    "roleEn": "Orthoptist",
    "titleFr": "De l'échec en médecine au métier d'orthoptiste",
    "titleEn": "From a med-school setback to becoming an orthoptist",
    "hookFr": "Recalée en médecine, elle a trouvé sa vraie voie dans un métier paramédical méconnu : l'orthoptie.",
    "hookEn": "Turned away from med school, she found her true calling in a little-known field: orthoptics.",
    "summaryFr": "Après un bac en 2010 et une première année de médecine qu'elle a dû accepter comme un échec, Claire a rebondi vers l'orthoptie, un métier paramédical encore peu connu qu'elle a découvert grâce à sa mère. Passée par la fac de médecine, de biologie et de psychologie puis deux ans de prépa concours, elle a intégré une école d'orthoptie et sera diplômée en 2016. Son parcours illustre la persévérance nécessaire pour retrouver sa voie après un revers.",
    "summaryEn": "After earning her baccalaureate in 2010 and facing a setback in her first year of medical school, Claire found her path in orthoptics, a little-known paramedical profession her mother introduced her to. She moved through medicine, biology and psychology faculties, then two years of competitive-exam prep, before entering an orthoptics school and graduating in 2016. Her journey is a lesson in perseverance and reinventing your direction after a failure.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes-vous ?",
        "answer": "Je m’appelle Claire, j’ai 27 ans et dans un mois je serai, si tout va bien, diplômée en tant qu’orthoptiste. J’ai eu mon bac en 2010 et ai ensuite fait une année en faculté de médecine, de biologie et de psychologie pour repartir ensuite sur deux années de préparation aux concours d’orthoptie que j’ai finalement obtenu en 2016."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "J’ai toujours voulu travailler dans le domaine médical/paramédical. Après avoir essuyé un échec en médecine, j’ai mis beaucoup de temps à l’accepter et à retrouver ma voie. Je voulais un métier avec énormément d’activités et de patientèle différentes, que je pouvais exercer à l’hôpital comme dans mon propre cabinet. Le métier d’orthoptiste n’étant encore à ce jour que très peu connu, mes recherches n’aboutissaient pas jusqu’à ce que ma mère, ayant eu des séances de rééducation orthoptique dans son enfance, me parle de ce métier. Après des recherches plus approfondies et un stage effectué en milieu hospitalier j’ai compris que ce métier était fait pour moi, je n’avais plus que cette idée en tête."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Faculté de Médecine (1an) / Faculté de Biologie (1an) / Faculté de Psychologie (1an) / Prépa aux concours d’orthoptie (2ans) / Ecole d’orthoptie (3ans)."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "L’entrée de l’école d’orthoptie se fait sur concours ou sur dossier (selon l’école), il y a une quinzaine d’écoles en France et elles prennent chaque année entre 20 et 30 étudiants (plus pour Paris). Le concours se compose de deux épreuves écrites : biologie et physique, et d’un oral d’une quinzaine de minutes sur la culture g et les motivations personnelles."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "Pour financer mes études j’ai eu la chance de pouvoir compter sur l’aide de mes parents, j’ai également travaillé en parallèle de mes études en tant que saisonnière sur les péages autoroutiers et tout au long de l’année dans la restauration rapide afin d’assurer toutes les dépenses inhérentes à mon statut d’étudiant (logement, nourriture, assurances, voiture, essence, électricité, internet…)."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je vais être orthoptiste et c’est avec un immense plaisir que je vais exercer au mieux ce métier passionnant."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "L’orthoptie est une profession paramédicale qui s’intéresse au dépistage, à la rééducation, à la réadaptation et à l’exploration fonctionnelle des troubles de la vision. En d’autres termes, je m’occupe de vos yeux et des troubles pouvant y être associés.Je peux travailler dans un hôpital et faire la pré consultation d’un ophtalmologiste en effectuant des bilans pour fatigue visuelle, maux de tête, vision double, baisse de la vision, strabisme…mais aussi faire des examens complémentaires comme des champs visuels, des images de la rétine ou le calcul de réfraction pour les lunettes. Je peux également travailler en libéral dans un cabinet, effecteur le même genre de bilan et faire de la rééducation pour soulager au mieux les plaintes de fatigue visuelle, de difficulté à l’école ou dans la vie quotidienne pour les personnes âgées ayant constaté une baisse de vision handicapante."
      },
      {
        "question": "Avez-vous des projets pour votre pays?",
        "answer": "J’aimerais beaucoup travailler à mi-temps en tant que salariée dans une structure médicale et l’autre partie du temps dans mon propre cabinet. Faire quelques dépistages dans les écoles maternelles également."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "De ne jamais rien lâcher ! Après le lycée les échecs concernant les études sont beaucoup plus durs à encaisser, parce que cela remet en question toute une partie de notre vie qu’on pensait avoir tracé. Mais il faut savoir se battre avec soi-même et passer par la fenêtre quand la porte est fermée."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 80,
    "popularity": 88,
    "source": "legacy_db"
  },
  {
    "slug": "t-samira-diallo",
    "kind": "text",
    "fieldId": "d01",
    "tags": [
      "Informatique",
      "Capgemini",
      "Canada",
      "Niger",
      "Gestion de projet"
    ],
    "personName": "Samira Diallo",
    "roleFr": "Cheffe de projet informatique chez Capgemini (Toronto)",
    "roleEn": "IT Project Manager at Capgemini (Toronto)",
    "titleFr": "Du Niger au Canada : cheffe de projet IT chez Capgemini",
    "titleEn": "From Niger to Canada: IT Project Manager at Capgemini",
    "hookFr": "Elle ne connaissait rien à l'informatique en 2003 ; elle pilote aujourd'hui des projets IT chez Capgemini.",
    "hookEn": "She knew nothing about computers in 2003; today she leads IT projects at Capgemini.",
    "summaryFr": "Samira Diallo, Nigérienne née en France et scolarisée au Niger, a fait son Bac Scientifique puis hésité entre médecine, chimie et informatique avant de se lancer dans l'IT presque par hasard, sans jamais avoir eu d'ordinateur. Son parcours l'a menée de la France jusqu'au Canada, où elle est aujourd'hui cheffe de projet informatique chez Capgemini à Toronto.",
    "summaryEn": "Samira Diallo, a Nigerien born in France and raised in Niger, earned a science baccalaureate then hesitated between medicine, chemistry and computer science before falling into IT almost by chance, despite never having owned a computer. Her journey took her from France to Canada, where she is now an IT project manager at Capgemini in Toronto.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui est Samira",
        "answer": "Je m’appelle Samira Diallo. Je suis nigérienne, née en France, grandie au Niger (collège et lycée), repartie en France (université) et là je vis au Canada (travail).  Je suis chef de projet informatique projet chez Capgemini au bureau de Toronto."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "C’était un peu par hasard ! J’ai fait un Bac Scientifique (Lycée Lafontaine de Niamey jusqu’à la 1ere puis la Terminale au Lycée Lumière de Lyon), avec des bonnes notes dans toutes les matières. Au moment d’envoyer mes dossiers post bac, j’hésitais entre une faculté de médecine, une filière informatique ou chimie. Je ne connaissais rien à l’informatique en 2003, je n’avais pas d’ordinateur à la maison et je n’avais aucune connaissance qui exerçait dans le domaine.\n\nHabitant à Lyon j’ai entendu parler de l’ IUT informatique de Lyon1. Je me suis dit pourquoi pas c’était un programme de 2 ans ; J’ai envoyé un dossier et j’ai été prise. C’était mon premier choix.\n\n \n\nJe n’ai pas aimé le côté très technique et programmation de l’IUT informatique. Je voulais en savoir plus sur les TIC mais sans devenir programmeur. J’ai donc intégré une licence puis un Master pour développer des compétences fonctionnelles (gestion de projet, conduite du changement,)"
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "·        DUT informatique à l’IUT Informatique de Lyon 1 (diplôme obtenu en 2006).\n\n·        Licence Professionnelle en alternance gestion des Nouvelles Technologies à l’ IUT GEA de Lyon 1\n\n·        Master Management des systèmes d’information à l IAE de Grenoble (en alternance 3 semaines en entreprise, 1 semaine en cours). Entre mon Master 1 et 2 j’ai effectué une année en échange à l’université York de Toronto (Canada) pour developer mon anglais et devenir bilingue."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "Les modalités d’inscription ont surement changé (je conseille de regarder sur les sites des universités) mais pour ma part j’ai envoyé des dossiers et aussi entretien (pour la License et master). Les notes sont importantes."
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "En France, mes études étaient gratuites à part les frais d’inscriptions (dans les 300 euros). La plupart des universités en France sont gratuites.\n\nPour Toronto, c’était un échange universitaire donc pas de frais a payer au Canada"
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Je travaille chez Capgemini depuis 2011 – en tant que consultant informatique, j’ai eu l’opportunité d’exercer plusieurs postes (Chef de projet, Business Analyst, Scrum Master, Test lead, Engagement Manager,).\n\nMon expérience couvre le conseil informatique, les systèmes d’information, les télécommunications, les services publics, les mines et les assurances pour le compte de clients basés en Europe, Afrique et Amérique du Nord (Areva, Walt Disney World, Rogers Communication, etc..). Mes domaines d'intérêt comprennent les TIC et l’innovation, et les possibilités offertes par le digital pour faire avancer ses sujets de prédilection.\n\n \n\nL’expérience m’a permis à de développer une large expertise en gestion et suivi de projets Agile et Waterfall, en analyse des besoins, en alignement stratégique, et sur l’optimisation des processus métiers et gestion du changement. Ces compétences acquises me permettent d’avoir une vision globale des projets informatiques sur l’approche fonctionnelle."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Le métier de consultant informatique  est de conseiller ses clients sur tout ce qui a trait aux systèmes informatiques : analyse des besoins, conception et mise en place des systèmes, mise en œuvre de procédures et élaboration de recommandations sur un large éventail de problèmes informatiques.\n\n \n\nL’avantage : il y a peu de routine avec la multitude de projets, on devient un expert dans son domaine rapidement, possibilité de voyager pour rencontrer les clients\n\n \nLes inconvénients : les heures de travail sont souvent longues."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "En évoluant dans des milieux internationaux et multiculturels, j’ai développé une passion pour la responsabilité sociale, et s’investi en particulier pour promouvoir la diversité, la mixité et une meilleure parité du genre, surtout dans le domaine informatique\n\n \n\nMon souhait est d’augmenter le nombre de femmes dans les filières informatiques et promouvoir et métiers TIC."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Si l’opportunité se présente oui. Je travaille déjà à distance avec des organisations sur place (mentorat des jeunes dans l’informatique)."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Avoir plus de jeunes dans le monde politique, plus de femmes dans des postes à responsabilités, l’école pour toutes les filles, continuer à former les jeunes dans le domaine numérique\n\n \n\nMes conseils pour les jeunes : une jeunesse qui se prend en charge, qui n’a pas peur du changer et n’hésite pas à devenir entrepreneur si besoin, sortir de sa zone de confort, accorder de l’importance à son « personal branding », améliorer ses compétences de leadership en lisant des livres de développement personnels ou des vidéos, trouver un mentor."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Il y a pas mal de difficultés à être une femme jeune dans un secteur informatique qui est principalement masculin mais je cherche toujours ma place. Comme beaucoup de femmes, je suis souvent victime du syndrome de l’imposteur ( c'est le sentiment d'avoir usurpé une place, de ne pas être à la hauteur du poste qu'on occupe et/ou de ne pas avoir le droit d'y être ).  \n\n Aussi la difficulté pour moi de concilier carrière et famille – on a l’idée en tête que les femmes doivent pouvoir tout gérer.  Du coup je gère mon foyer, une petite fille mais aussi une carrière que j’adore.  J’ai souvent entendu « Il ne faut pas que ta carrière prendre le dessus de ta vie de famille » . Mais pourquoi pas trouver un moyen de concilier les 2 ?"
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 81,
    "popularity": 56,
    "source": "legacy_db"
  },
  {
    "slug": "t-moussa-hamani-magagi-saley",
    "kind": "text",
    "fieldId": "d04",
    "tags": [
      "Médecine vétérinaire",
      "Niger",
      "Sénégal",
      "Santé animale",
      "Études à l'étranger"
    ],
    "personName": "Moussa Hamani Magagi Saley",
    "roleFr": "Étudiant en médecine vétérinaire",
    "roleEn": "Veterinary medicine student",
    "titleFr": "De Dosso à Dakar : sa vocation de vétérinaire",
    "titleEn": "From Dosso to Dakar: his path to veterinary medicine",
    "hookFr": "Un étudiant nigérien devenu vétérinaire en formation à Dakar : son parcours du Niger au Sénégal.",
    "hookEn": "A Nigerien student training as a vet in Dakar: his journey from Niger to Senegal.",
    "summaryFr": "Né à Niamey et ayant grandi à Dosso, Moussa Hamani Magagi Saley poursuit ses études de médecine vétérinaire à l'École Inter-États des Sciences et Médecine Vétérinaires de Dakar, au Sénégal. Son parcours scolaire, du CFEPD à l'université, illustre le chemin d'un étudiant nigérien vers une carrière dans la santé animale à l'étranger.",
    "summaryEn": "Born in Niamey and raised in Dosso, Moussa Hamani Magagi Saley is studying veterinary medicine at the Inter-State School of Sciences and Veterinary Medicine in Dakar, Senegal. His journey, from primary school in Niger to university abroad, shows the path of a Nigerien student toward a career in animal health.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Présentation",
        "answer": "Je m’appelle Moussa HAMANI M AGAGI SALEY, j ’ ai 25 ans je suis né à Niamey\nau Niger.\n\nParcours : J’ai fréquenté le jardin d’enfant cité Fayçal jusqu’à mon CE2 en 2006, où nous\navions quitté Niamey pour Dosso, une région située à 139Km de la capitale où j’ai effectué\ntout mon parcours académique . En 2008, j’obtiens mon CFEPD à l’ école Katan Guiwa.\n\nToujours dans la même lancée, j’ai obtenu mon Brevet en 2012 au CES de Dosso. En 2015,\nj ’ ai obtenu mon baccalauréat série D au CES (2 ème lycée après le lycée Saraounia Mangou).\n\nAprès l’obtention de mon bac la même année , j’ai intégré l’Ecole Inter -Etats des Sciences et\nVétérinaires de Dakar(Sénégal) où j’ étais appelé à faire un cursus de 6 années d’étude\nvétérinaire."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "J’ai toujours rêvé depuis mon jeune âge de faire des études médicales suite à des émissions\nde santé que je suivais et j’ étais inspiré à l’idée de devenir un jour comme ces acte urs de la\nsanté. Un jour alors que je suis dans les tractations comme tout nouveau bachelier, un ami\navec qui on avait cheminé ensemble au lycée m’a fait part de cette école de médecine\nvétérinaire et la sélection était faite par concours. Donc au début, j’ hésitais puisque je n’ai\npas trop de chance à réussir aux concours (préjugés). Bref\nj’ai fini par déposer mes dossiers et j’ai réussi le concours. Ce choix de filière était juste un pur hasard.\n\nIl faut noter que la médecine vétérinaire est une filière comme toute autre. Même étant\nméconnue du grand public, elle fait partie des métiers d'avenir et la formation est\neffectuée sur 6ans (5 année d’études vétérinaires et une année de rédaction de la thèse pour\nl’obtention d’un doctorat d’état comme en médecine humaine). Ce doctorat permettra\nd’ intervenir en santé et productions animales, en santé publique, en nutrition et même dans\nles organismes internationaux (comme la FAO, la PAM, vétérinaires sans frontières ...) bref la\nliste est longue pleins de débouchés pour cette noble profession."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Après l’obtention de mon bac, j’ai intégré l’E.I.S.M.V (Ecole Inter-Etat des Sciences et Médecine Vétérinaires) au Sénégal o ù je suis actuellement en dernière année"
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "D’abord il faut être titulaire d’un bac scientifique ou équivalent. Il faudra passer un concours au Niger dont l’ONECS est l’instance dirigeante pour l’organisation du dit concours, mais dans les autres pays membres de l’UEMOA la sélection se fait sur dossier. Il faut noter que c’est une école privée."
      },
      {
        "question": "Comment financer ses études ? Comment décririez-vous le coût des études ?",
        "answer": "je  bénéficie  d’une bourse complète de l’état Nigérien.\n\nLe coût de la formation est très exorbitant comme toute école de médecine et varie en fonction des\npays (pays membres de l ’ école, pays non membres, et pays africain et autres continents)."
      },
      {
        "question": "Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Le métier de vétérinaire constitue une place importante car il est pluridisciplinaire,\nIl intervient dans la lutte contre l’insécurité alimentaire, l’hygiène des denrées alimentaires d’origine animale, l’inspection des carcasses dans les abattoirs agrées...En résumé, c’est un métier qui participe pleinement dans notre vie quotidienne."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui comme tout fils du Niger, j’envisage de revenir au pays une fois l’expérience acquise pour lui rendre la pareille, en contribuant à l’amélioration génétique de notre race bovine Azawak considérée comme la meilleure productrice laitière en Afrique.\nPour mon cher continent, la sensibilisation sur les différentes maladies zoonotiques (maladies transmissibles de l’homme à l’animal et réciproquement)"
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Le conseil que j’ai l’habitude de donner à mes jeunes frères et sœurs, c’est de ne pas laisser quelqu’un être la clé de votre réussite et surtout soyez l’acteur de vos choix de filières.\n\nSi plusieurs choix se présentent à vous, demander des informations afin de pouvoir se fixer et prendre la filière en fonction de vos ambitions et projets."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 82,
    "popularity": 51,
    "source": "legacy_db"
  },
  {
    "slug": "t-issa-harouna-nouroudine",
    "kind": "text",
    "fieldId": "d03",
    "tags": [
      "Ingénierie pétrolière",
      "Géophysique",
      "Bourse d'études",
      "Étudier en Russie",
      "Hydrocarbures"
    ],
    "personName": "Issa Harouna Nouroudine",
    "roleFr": "Étudiant en master de géophysique des hydrocarbures",
    "roleEn": "Master's student in hydrocarbon geophysics",
    "titleFr": "Du Niger à Kazan : décrocher une bourse en ingénierie pétrolière",
    "titleEn": "From Niger to Kazan: Winning a Scholarship in Petroleum Engineering",
    "hookFr": "De Niamey à la Russie grâce à une bourse : son parcours vers l'ingénierie pétrolière.",
    "hookEn": "From Niamey to Russia on a scholarship: his path into petroleum engineering.",
    "summaryFr": "Après un bac D à Niamey et une licence en exploitation des hydrocarbures, Issa a obtenu une bourse de coopération de la Fédération de Russie. Il poursuit aujourd'hui un master en géophysique des hydrocarbures à l'Université fédérale de Kazan, à cheval entre exploration et production pétrolières, en collaboration avec l'Institut français du pétrole.",
    "summaryEn": "After earning a science baccalaureate in Niamey and a bachelor's degree in hydrocarbon exploitation, Issa secured a cooperation scholarship from the Russian Federation. He is now completing a master's in hydrocarbon geophysics at Kazan Federal University, bridging petroleum exploration and production, in collaboration with the French Petroleum Institute.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Présentation",
        "answer": "Je suis titulaire d’un bac D obtenu au lycée Issa korombé de Niamey en 2014 puis d’une licence en exploitation des hydrocarbures à L’institut africaine de technologie en 2017.\n\nAprès ma licence, j’ai obtenu une bourse coopération de la fédération de la Russie. Après un an de classe préparatoire en langue russe et en science de la terre à l’université fédérale de Kazan, j’ai intégré l’institut de géologie et des technologies pétrolière et gazière où je suis actuellement en 2eme année de master en géophysique des hydrocarbures (complex data analyze in petroleum and gas geology), un programme à cheval entre la production et l’exploration, deux pans de l’ingénierie pétrolière qui m’ont toujours intéressés en collaboration avec l’institut français du pétrole."
      },
      {
        "question": "Comment intégrer l'Université Fédérale de Kazan (Russie)?",
        "answer": "Pour intégrer cet institut pour un étranger, on peut y procéder par deux moyens :\n\nØ Etre titulaire d’une bourse de coopération du gouvernement fédéral de Russie et passer la phase de sélection par l’université sur étude de dossier;   \n\nØ S’inscrire à titre privé sur concours  (financement personnel ou un programme de sponsoring d’une société)."
      },
      {
        "question": "Comment obtenir la Bourse Russe?",
        "answer": "Le processus d’obtention de la bourse est la suivante : durant la période de sélection, l’ambassade de Russie a Bamako adresse une correspondance aux autorités nigériennes, qui passent l’information par l’anab entre janvier et mars. Les participant seront conviés à s’inscrire sur le site du gouvernement fédéral russe (future-in-russia.com) et remplir les formalités en fonction des niveaux académiques (licence master ou doctorat). Les candidats sélectionnés seront amenés à passer un entretien plus un test en français par des représentants de l’ambassade russe. Les modalités sont les suivantes :\n\nØ Etre nigérien ;\n\nØ Disposer d’un passeport ;\n\nØ Avoir le bac, la licence ou un master selon le niveau.\n\n \n\nLe Billets d’avion aller-retour assuré par le gouvernement du Niger, une subvention de 150 000 francs mensuelle au frais de l’état du Niger est accordée aux bénéficiaires de la bourse et une fois sur le sol russe en fonction de l’université, une subvention mensuelle est accordée par le gouvernement russe. Dix places sont attribuées au Niger chaque année.\n\nNB : la subvention de l’état du Niger est  trimestrielle et accuse énormément de retard. Le plus souvent le premier trimestre est perçu 9 mois voir plus après l’arrivée sur le sol russe."
      },
      {
        "question": "Le coût de la vie en Russie",
        "answer": "Le coût de la vie en Russie en  dehors de Moscou, saint Petersburg et Sotchi est relativement bas. La bourse de coopération te donne le plus souvent accès au foyer étudiant (les frais d’hébergement au foyer étudiant varient entre 8 et 50 euros en fonction des villes Moscou compris) ce qui est de nature à amoindrir drastiquement les dépenses. Pour la location hors foyer, il faudra compter au moins 200 euros pour les studios et le prix peut doubler à Moscou. A Kazan il faut compter environ 160 euros en moyenne de budget mensuel pour le transport et la nourriture. Dans les 3 villes cites ci-haut, il faudra compter le double de cette somme. Néanmoins, les boursiers ont des subventions mensuelles qui permettent de boucler le loyer au foyer et le transport. Ça varie en fonction des états, mais c’est proportionnel au coût de la vie dans les différents états qui composent la fédération de Russie. Selon également les législations en vigueurs dans certains états, les étudiants ont la possibilité de travailler soit dans leurs universités ou dans les secteurs d’activités économiques de la ville, car en Russie, le permis de travail est assorti du type de visa qu’on détient (loi en cours de changement pour les étudiants étrangers)."
      },
      {
        "question": "Le retour au Niger?",
        "answer": "Revenir au Niger fait effectivement parti de mes projets, j’ai envie de tenter en premier lieu ma chance au Niger. On a un jeune secteur pétrolier en cours de maturation et j’aimerais apporter ma pierre à l’édifice. Mon choix de master et mon mémoire orienté vers les techniques de récupération assistée pour des réservoirs conventionnels vont dans ce sens. Avoir la chance de faire son parcours dans un pays qui a une histoire très ancienne avec l’industrie pétrolière est une aubaine, parce que ça te permet d’avoir accès à ce que le domaine offre de mieux en termes de savoir académique et d’expérience. On a l’occasion de travailler avec les plus grandes compagnies russes qui ont pour certaines des labos de recherches dans notre institut ou y sous-traitent leurs recherches. Je compte faire bénéficier mon pays de ce que j’aurai appris ici."
      },
      {
        "question": "Conseils",
        "answer": "J’exhorte la jeunesse que nous sommes  à ne jamais arrêter d’apprendre. Les grands résultats viennent quand vous affinez votre cible, trouvez une chose qui vous passionne et faites tout pour exceller dans cette chose. Le Niger de demain aura besoin d’une jeunesse engagée et cultivée pour amorcer sa marche vers le progrès la justice sociale et l’équité."
      },
      {
        "question": "Karatou Post Bac",
        "answer": "L’application Karatou Post Bac est un outil d’aide à la décision qui je pense aidera la jeune génération à choisir un parcours au niveau du supérieur. Etant moi-même quelqu’un qui a été épris de doute lors de mon choix de parcours, je mesure la nécessité d’avoir un tel outil entre les mains. Dans un monde où les choses vont tellement vites, si vous ajoutez à ceci  un environnement comme le notre au Niger : où les chances de reconversion sont minimes, les choix académiques pas assez diversifiés et mis à jour par rapport à l’évolution globale du monde d’aujourd’hui, choisir carrière un parcours est très déterminant au sortir du lycée et les outils pour nous guider dans ce sens sont extrêmement utiles."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 83,
    "popularity": 42,
    "source": "legacy_db"
  },
  {
    "slug": "t-adamou-louche-ibrahim",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Économie",
      "Bourse d'études",
      "Niger",
      "Algérie",
      "France"
    ],
    "personName": "Adamou Louche Ibrahim",
    "roleFr": "Analyste économique et chargé de clientèle",
    "roleEn": "Economic Analyst and Client Relationship Manager",
    "titleFr": "Du Bac G2 à Maradi à analyste économique en France",
    "titleEn": "From a Maradi high school to economic analyst in France",
    "hookFr": "De Maradi à Tizi Ouzou puis Bordeaux : un parcours d'économiste porté par les bourses.",
    "hookEn": "From Maradi to Tizi Ouzou to Bordeaux: an economist's journey powered by scholarships.",
    "summaryFr": "Titulaire d'un Bac G2 « Comptabilité » obtenu en 2006 au Lycée Technique Dan Kassawa de Maradi (Niger), Adamou Louche Ibrahim poursuit ses études en sciences économiques à l'Université Mouloud Mammeri de Tizi Ouzou en Algérie, grâce à une bourse de coopération algérienne. Il complète son parcours à l'Université Bordeaux IV et travaille aujourd'hui comme analyste économique et chargé de clientèle dans une grande entreprise publique française.",
    "summaryEn": "A holder of a G2 accounting baccalaureate earned in 2006 at the Dan Kassawa Technical High School in Maradi (Niger), Adamou Louche Ibrahim went on to study economics at Mouloud Mammeri University in Tizi Ouzou, Algeria, on an Algerian cooperation scholarship. He rounded out his studies at Bordeaux IV University and now works as an economic analyst and client relationship manager at a major French public company.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Qui êtes-vous",
        "answer": "Je suis analyste économique  et Chargé de Clientèle dans une grande entreprise publique française.\n\nJ’ai obtenu mon Bac G2 « Comptabilité » en 2006 dans le\nmythique Lycée Technique Dan Kassawa de Maradi (LTDK) . Dans la foulée, j’ai\ncontinué mes études en Sciences économiques à l ’Université Mouloud Mammeri de\nTizi Ouzou d’Algérie , grâce à la bourse de coopération algérienne"
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "Comme mentionné ci- dessus, j’ai fréquenté le Lycée technique de Maradi (Niger). Ensuite, l’Université de Tizi Ouzou en Algérie, pour finir à l’Universi té Bordeaux IV."
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "L’intégration de l’université d’Algérie était le fruit d’une bourse de coopération. Licencié en Sciences Economiques de l’Université de Tizi Ouzou en Algérie, j'intègre l'Université de Bordeaux (Ex Université Bordeaux IV Montesquieu) en 2011, grâce à l’accompagnement de Campus France afin de mieux connaitre les formations que proposent les Université françaises et peaufiner nos choix. Ma passion pour la recherche et ma curiosité intellectuelle ont davantage motivé mon choix pour le Master II Economie Banque et Finance Internationales avec comme spécialité Mondialisation et Stratégies Internationales."
      },
      {
        "question": "Qu’est-ce qui vous a motivé à choisir votre filière ?",
        "answer": "Après l’obtention de mon bac et faute de conseils et d’accompagnement, c’était difficile de me projeter sur à la filière à choisir. Même si, l’option envisagée, était de poursuivre en comptabilité afin de devenir Expert-Comptable.  Avec l’obtention de la bourse algérienne, je m’étais finalement orienté vers les sciences économiques. Domaine dans lequel j’ai poursuivi mes études jusqu’à obtenir un Master en Mondialisation et Stratégies Internationales à l’Université Bordeaux IV (actuelle Université de Bordeaux)\n\nDécrire la filière aussi :\n\nCe master a pour objectif de former des étudiants dans le domaine de l'économie internationale, afin de leur permettre de comprendre les stratégies des principaux acteurs économiques dans un univers mondialisé.\n\nLe parcours recherche \"Echanges et stratégie des acteurs globaux\", que j’avais suivi, forme, par la recherche et à la recherche, des étudiants dans le domaine de l'économie internationale. Il fournit les connaissances théoriques et d'outils quantitatifs (techniques économétriques, modélisation, statistiques) permettant aux étudiants d'analyser les stratégies des acteurs globaux (firmes nationales, Etats, blocs régionaux, organisations internationales) dans une économie mondialisée"
      },
      {
        "question": "Si vous avez étudié à l’étranger, comment avez-vous financer vos études ? Comment décririez-vous le coût des études ?",
        "answer": "Les études à l’étranger peuvent être sources d’angoisse ou d’opportunité. Angoisse lorsque l’on manque de moyens pour subvenir à ses besoins les plus essentiels (loyer, fournitures scolaires, matériels informatiques…). Opportunité puisque c’est formateur au sens où l’on apprend à devenir autonome. Me concernant, pendant mon séjour en Algérie, je bénéficiais d’une modeste bourse des Etats Algérien et Nigérien et surtout de l’appui financier de mes parents. En revanche, en France, je percevais également la modeste bourse de l’Etat du Niger. Cette bourse étant insuffisante et souvent irrégulière, il fallait compléter avec un petit « job » pour satisfaire ses besoins et financer mes études. Si travailler semble quasiment indispensable, cela requiert cependant une meilleure organisation pour mieux réussir ses études. Autrement, ces dernières risquent d’en pâtir. D’où l’intérêt de trouver le bon équilibre, l’objectif principal étant l’obtention de son diplôme."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Pouvez-vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "Comme mentionné ci-dessus, je suis polyvalent. Cette polyvalence me permet d’intervenir dans les secteurs de l’analyse économique et de la relation clientèle. Pour le premier, il s’agit de produire des études et articles économiques visant à éclairer les choix économiques, financiers d’une entreprise ou d’un Etat. Quant au second, il consiste à contribuer à la qualité du service et au développement commercial du secteur (terrain) sur lequel nous exerçons dans tous les domaines d’activité."
      },
      {
        "question": "Avez-vous des projets pour votre pays ? l’Afrique ?",
        "answer": "Bien qu’installé en France, il m’était naturel de suivre attentivement la situation économique et sociale de notre pays.  Et compte tenu des défis importants auxquels ce dernier est confronté, j’ai créé mon blog ( http://ibrahimadamoulouche.blogspot.com/ ) pour mener des réflexions, principalement en économie, pour explorer les pistes permettant d’y faire face efficacement. A cela s’ajoute le projet « Objectif Savoir ». Un projet consistant à collecter des livres dans les bibliothèques françaises afin d’alimenter les bibliothèques des universités nigériennes et favoriser l’amélioration du système éducatif du pays. De nombreux projets sont en cours d’élaboration et dont la concrétisation nécessitera un retour au pays dans les années à venir."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Le message que j’aime toujours donner aux jeunes consiste à les inviter en permanence à se fixer des objectifs, savoir se projeter, être audacieux et persévérant, de résister à la tentation de l’abandon, de cultiver ses ambitions. Il faudra également poursuivre la voie de nos rêves, même si le chemin est parfois difficile."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Je suis marié et père d’un enfant. La famille restant de nos jours l’un des meilleurs cadeaux au monde, je n’en vois pas en elle une contrainte, même si cela implique une certaine organisation. Ce qui est important, c’est de trouver le bon équilibre entre vie professionnelle et familiale. Dans l’épanouissement total."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 84,
    "popularity": 40,
    "source": "legacy_db"
  },
  {
    "slug": "t-mamoudou-halourou-souley",
    "kind": "text",
    "fieldId": "d02",
    "tags": [
      "Actuariat",
      "Assurances",
      "Mathématiques",
      "Bourse d'études",
      "Maroc"
    ],
    "personName": "Mamoudou Halourou Souley",
    "roleFr": "Actuaire au groupe Coface",
    "roleEn": "Actuary at Coface Group",
    "titleFr": "Du Lycée d'Excellence de Niamey à actuaire chez Coface",
    "titleEn": "From Niamey to actuary at Coface: a math-driven path",
    "hookFr": "Il a transformé sa passion des maths en carrière d'actuaire, de Niamey à Coface.",
    "hookEn": "He turned his love of math into an actuarial career, from Niamey to Coface.",
    "summaryFr": "Mamoudou Halourou Souley a suivi son goût pour les mathématiques du Lycée d'Excellence de Niamey jusqu'à une licence d'économie au Maroc, puis un diplôme d'ingénieur en Actuariat-Finance à l'INSEA de Rabat. Il a ensuite poursuivi en France avec un Mastère Spécialisé en Actuariat et Big Data et un Master 2 au CNAM pour obtenir le titre d'actuaire. Il exerce aujourd'hui au sein de la Direction Actuariat du groupe Coface.",
    "summaryEn": "Mamoudou Halourou Souley followed his passion for mathematics from the Lycée d'Excellence in Niamey to an economics degree in Morocco, then an engineering diploma in Actuarial Science and Finance at INSEA in Rabat. He continued in France with a Specialized Master's in Actuarial Science and Big Data and a Master 2 at CNAM to earn the French actuary title. He now works in the Actuarial Department of the Coface Group.",
    "thumbnailUrl": "",
    "photoUrl": "",
    "youtubeId": null,
    "durationMinutes": null,
    "interviewFr": [
      {
        "question": "Quel est votre parcours?",
        "answer": "J’ai obtenu mon Bac en 2011 au Lycée d’Excellence de Niamey. Après mon Bac, j’ai eu une bourse d’études de l’Agence Marocaine de Coopération Internationale. De 2011 à 2014 j’ai étudié en licence de Science Economique à la Faculté de Sciences Juridiques, Economiques et Sociales de L’université Moulay Ismail. Après ma licence en 2014, j’ai intégré sur concours la 2 e année du cycle d’ingénieur d’Etat en Actuariat-Finance de l’Institut National de Statistique et d’Economie Appliquée de Rabat. Après mon diplôme d’ingénieur en 2016, j’ai décidé de poursuivre mes études en France pour suivre une formation de Mastère Spécialisé en Actuariat et Big-Data. Enfin, dans l’objectif d’avoir le titre d’actuaire français, j’ai intégré le Master 2 Actuariat en formation continue au Conservatoire National des Arts et Métiers (CNAM)."
      },
      {
        "question": "Qu’est ce qui vous a motivé à choisir votre filière ?",
        "answer": "Après mon Bac, j’ai fait un petit bilan sur mes points forts et faibles et il est ressorti que j’avais une forte appétence pour les maths. J’avais le stéréotype de « tu fais des études en maths tu deviens professeur de maths » et je ne voulais pas de ça (sans vouloir vexer les professeurs ou dénigrer le métier noble de professeur). Ce stéréotype m’a fait donc choisir une licence en économie dans l’objectif de poursuivre plus-tard mes études en économétrie ou statistiques.\n\nÁ ma 2 e année d’études, étant toujours à la recherche de mes objectifs de master, j’ai découvert l’INSEA avec ses filières. Au début je voulais faire la filière Statistique et Economie car c’était la seule qui me parlait parmi celles proposées par l’institut. Autour d’une discussion un ami m’a conseillé de voir de plus près la filière actuariat-finance proposée car il a su que ce sont des profils qui manquent au Niger.\n\nJ’ai trouvé dans l’actuariat tout ce que je cherchais. En effet, les études en actuariat ont une forte composante en statistique et finance avec une composante non négligeable  d’apprentissage de la programmation sur certains outils. Je me suis donc beaucoup documenté sur cette filière, posé des questions à des universités ou écoles sur les modes d’admission et au final j’ai fait de l’actuariat mon domaine de prédilection."
      },
      {
        "question": "Pourriez-vous nous décrire votre filière?",
        "answer": "Le cursus universitaire d’un actuaire, de niveau Bac+5, est de nature scientifique, avec un caractère pluridisciplinaire marqué. Spécialiste de la gestion des risques, l’actuaire ou ingénieur du risque est chargé de proposer des modèles stochastiques, basés sur la théorie des probabilités, permettant de gérer l’évolution incertaine de l’environnement assurantiel et financier.\n\nA l’INSEA et dans certaines écoles, le cursus classique se déroule sur 3 ans avec la possibilité d’intégrer le cycle à partir de la 2 e année du cycle. De ce fait :\n\n-   La première année constitue une transition entre les classes préparatoires et les autres cursus et les filières de l’INSEA. Elle vise à harmoniser les connaissances en économie, mathématiques et informatique. L’année se conclut par un stage d’observation d’au moins 4 semaines ;\n\n- La deuxième année est une année de spécialisation. Elle est composée des enseignements de spécialisation (mathématiques actuarielles, finance de marché…) et des enseignements de tronc commun (statistique, économétrie, macroéconomie et microéconomie) qui constituent le socle de la formation. La deuxième année se conclut par un stage d’application d’au moins 6 semaines ;\n\n- La troisième année a le même profile que la deuxième année. Elle complète et renforce les enseignements de spécialisation de la deuxième année. L’année est composée de cours théorique, des séminaires et des projets. L’année se conclut par un stage de fin d’études de minimum 4 mois avec la rédaction d’un rapport."
      },
      {
        "question": "Quelle école/université avez-vous fréquentée ?",
        "answer": "• 2011-2014 : FSEJS Moulay Ismail\n\n    • 2014-2016 : Institut National de Statistique et d’Economie Appliquée\n\n    • 2016-2017 : Ecole Supérieure d’Ingénieurs Léonard de Vinci\n\n    • 2017-2020 : Conservatoire National des Arts et Métiers"
      },
      {
        "question": "Comment intégrer cette école/université ?",
        "answer": "• FSEJS : Pour les étrangers l’inscription se fait suite à l’autorisation obtenue auprès de l’Agence Marocaine de Coopération Internationale. Elle s’inscrit dans le cadre de l’obtention de la bourse marocaine.\n\n    • INSEA : Deux voies d’amissions à l’INSEA sont proposées :\n\n        ◦ Admission en première année : accessible pour les élèves de classes préparatoires ou les étudiants titulaires d’un CUES, DEUG ou DEUST avec mention Bien ou Très Bien ;\n\n        ◦ Admission en deuxième année : ouvert pour les titulaires d’une licence en Science Economique, en mathématique ou diplôme équivalent avec une mention Bien ou Très Bien.\n\n    • ESILV : Admission après études de dossiers et entretien.\n\n    • CNAM : Admission sur études de dossier."
      },
      {
        "question": "Quel est le métier que vous exercez aujourd’hui ? Est-ce une vocation ?",
        "answer": "Aujourd’hui je travaille en tant qu’actuaire au sein de Coface qui est une compagnie d’assurance-crédit. Ce métier s’inscrit parfaitement dans mon projet professionnel que je me suis donné depuis longtemps."
      },
      {
        "question": "Pouvez vous décrire en quoi consiste ce métier au quotidien ?",
        "answer": "A mon sens il n’y a pas de journée type d’actuaire tant le métier est fonction à la fois de l’entreprise ou on exerce, du business de l’entreprise, du poste occupé, des prérogatives de l’actuaire, mais aussi de la période de l’année."
      },
      {
        "question": "Avez-vous des projets pour votre pays? l’Afrique?",
        "answer": "Oui, j’ai des projets pour le Niger. Le Niger est encore un territoire quasiment vierge où beaucoup de choses sont à faire. Il ya certes beaucoup de contraintes mais il ne faut pas s’arrêter aux premiers blocages. Je crois pour ma part fermement en l’agriculture au Niger et je compte œuvrer en conséquence."
      },
      {
        "question": "Si vous êtes à l’étranger, envisagez-vous de rentrer ?",
        "answer": "Oui, mais à un horizon indéterminé."
      },
      {
        "question": "Avez-vous des conseils pour les jeunes ?",
        "answer": "Sachez ce que vous voulez faire plus tard afin de faire vos propres choix. Evitez les stéréotypes comme ce que j’ai pu avoir. Enfin, soyez excellents dans ce que vous faites, que ce soit vos études ou autres.\n\nJe ne vais pas donner le conseil d’étudier pour devenir de bons salariés. Il faut certes acquérir de la connaissance, mais étudier avoir un salaire ne doit plus être la finalité pour laquelle nous allons à l’école ou l’université. Beaucoup de choses sont à faire dans notre pays pour ceux qui s’y intéressent. Il n’y pas suffisamment d’entreprise pour absorber tous les diplômés qui sortent  chaque année des universités. L’Etat non plus ne peut pas être le pourvoyeur d’emplois pour tout le monde.\n\nAlors que faire ? Attendre indéfiniment d’avoir un boulot ? S’expatrier quelque part ? Créer sa propre entreprise pour donner du travail à d’autre ? Les options sont nombreuses, mais il ne faut certainement pas choisir l’inaction. Le pays regorge d’opportunités, il faut savoir les saisir.\n\nSachons être humbles, il n’y a pas sot métier. Tâchons de voir plus loin que le bout de notre nez. Soyons persévérant et surtout toujours excellent dans ce que nous faisons. Je pense que ça nous permettra de réussir."
      },
      {
        "question": "Avez-vous des contraintes familiales ? Comment les gérez-vous ?",
        "answer": "Non, pas de réelles contraintes en tant que tel."
      }
    ],
    "interviewEn": null,
    "status": "published",
    "isActive": true,
    "featured": false,
    "displayOrder": 85,
    "popularity": 32,
    "source": "legacy_db"
  }
];
