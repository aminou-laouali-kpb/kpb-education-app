# Cours Academy (préparation HSK…) : backend et admin

Ajouté le 21/11/2026 pour le cours de préparation au HSK (bourse CSC), dont
les vidéos sont produites avec HyperFrames. Prouvé par
`academy.postgres.spec.ts` (filtres de publication, import rejoué) et joué de
bout en bout dans l'admin sur une base locale : import, réimport, publication,
réordonnancement, ajout d'une leçon, lecture publique.

## La chaîne

| Maillon | Où |
|---|---|
| Écran | Admin → **Cours (Academy)** (`/academy`) : Admin, SuperAdmin, Contenu |
| Écriture | `/admin/academy/courses/*` (`AdminAcademyController`) |
| Stockage | tables `AcademyCourse` et `AcademyLesson` |
| Lecture app | `GET /academy/courses`, `GET /academy/courses/:idOrSlug` |
| App mobile | Profil → « Cours de langue (HSK, TOEFL…) », affiché seulement si le drapeau distant `academy` est ouvert (VPS ops → `academy-on`, fermé par défaut). Écrans : `lib/app/features/academy/` |

Les routes publiques n'ont pas de `MvpGuard` : elles ne servent que ce que
l'équipe a publié, et rien ne l'est par défaut. La publication dans l'admin est
la vraie porte.

## Ce que l'app voit

Un cours n'apparaît que s'il est **publié** ET qu'il a **au moins une leçon
publiée**. Dans un cours visible, seules les leçons publiées sont servies, dans
l'ordre de leur position. L'admin affiche l'état réel sur chaque cours :
« Visible dans l'app », « Invisible dans l'app » ou « Invisible : aucune leçon
publiée ».

Sans image de couverture, l'API renvoie la miniature YouTube de la première
leçon lisible sans Pass. L'API d'admin n'accepte aucun prix : l'app n'a aucun
parcours d'achat. Un cours peut en revanche être **réservé au Pass Karatou**
(accordé hors de l'app) : voir `docs/pass-karatou.md`.

## Importer les vidéos produites avec HyperFrames

1. Mettre chaque MP4 sur YouTube, en **non répertorié**.
2. Dans `manifest.json`, ajouter à chaque leçon son lien dans `youtubeUrl`.
3. Admin → Cours (Academy) → **Importer un manifeste** → coller → **Vérifier**
   → **Importer**.
4. Ouvrir le cours, relire les leçons, passer le cours en **Publié**.

Forme lue (un module = un cours) :

```json
{
  "id": "hsk-1",
  "titleFr": "Préparation HSK 1",
  "titleEn": "HSK 1 preparation",
  "descriptionFr": "…",
  "descriptionEn": "…",
  "lessons": [
    {
      "order": 1,
      "youtubeUrl": "https://youtu.be/XXXXXXXXXXX",
      "titleFr": "Pinyin et les 4 tons",
      "titleEn": "Pinyin and the 4 tones",
      "durationSeconds": 312,
      "file": "out/hsk1/01-pinyin.mp4",
      "type": "vocab",
      "hskLevel": 1
    }
  ]
}
```

L'admin accepte aussi une liste de modules ou `{ "modules": [...] }`. Il ignore
les champs de rendu (`file`, `type`, `hskLevel`), qu'il retire avant l'envoi :
le serveur refuse toute clé inconnue. « Vérifier » liste, en français, tout ce
qui bloquerait : lien manquant ou illisible, position en double, même vidéo à
deux positions, titre ou durée absents. Le bouton « Importer » n'apparaît que
si la liste est vide.

### Ce que fait un import

- Le cours est retrouvé par son identifiant (`id` ou `slug`, ex. `hsk-1`).
  Absent : il est **créé en brouillon**. Présent : il **garde son statut**.
- Une leçon est retrouvée par sa **vidéo YouTube**. Son titre, sa durée et sa
  position sont réalignés sur le manifeste. Son statut n'est touché que si le
  manifeste en donne un : une leçon retenue en brouillon le reste.
- Un champ absent du manifeste ne modifie rien sur un cours existant.
- Une leçon du cours absente du manifeste n'est **ni supprimée ni masquée** :
  le rapport la liste, à trier à la main.
- Tout ou rien : une transaction par cours. Rejouer le même manifeste ne
  change rien (« 0 créée · 0 mise à jour · N inchangées »).

## Les pièges

1. **Le brouillon.** Un cours créé, à la main ou par import, est en brouillon :
   invisible tant qu'on ne le publie pas.
2. **Publié mais vide.** Un cours publié dont aucune leçon n'est publiée
   n'apparaît pas. L'admin l'affiche en orange.
3. **L'identifiant.** C'est lui qui relie un import au cours existant. Le
   changer après un import fait créer un second cours à l'import suivant.
4. **Une vidéo remise en ligne change d'identifiant YouTube.** L'import la voit
   comme une nouvelle leçon et liste l'ancienne comme « absente du manifeste ».
   Supprimez l'ancienne.
5. **Supprimer** un cours efface ses leçons, jamais les vidéos YouTube. Pour
   seulement le retirer de l'app, passez-le en « Archivé ». Un cours qui a des
   achats ne peut pas être supprimé (409).

## API

| Route | Effet |
|---|---|
| `GET /academy/courses` | `{items, source}` : cours visibles, `title`/`description` `{fr, en}`, `coverImageUrl`, `isFree`, `lessonCount`, `totalDurationSeconds`. 503 `ACADEMY_UNAVAILABLE` sans base |
| `GET /academy/courses/:idOrSlug` | Le même cours + `lessons` publiées (`title`, `videoUrl` canonique, `youtubeVideoId`, `thumbnailUrl`, `durationSeconds`, `order`). 404 si invisible |
| `GET /admin/academy/courses` | Tous les cours + `lessonCount`, `publishedLessonCount`, `publishedDurationSeconds`, `purchaseCount`, `visibleInApp` |
| `POST /admin/academy/courses` | `{slug, titleFr, titleEn?, descriptionFr?, descriptionEn?, coverImageUrl?, status?, displayOrder?}`. Brouillon et gratuit par défaut ; EN vide = FR. 409 si le slug est pris |
| `POST /admin/academy/courses/import` | Un module de manifeste (voir plus haut). Rend `{course, lessons: {created, updated, unchanged}, notInManifest}` |
| `GET/PATCH/DELETE /admin/academy/courses/:id` | Détail avec leçons ; édition (`coverImageUrl: null` retire l'image) ; suppression (409 si achats) |
| `POST /admin/academy/courses/:id/lessons` | `{youtubeUrl, titleFr, titleEn?, durationSeconds, status?}`. Ajoutée en dernier, `published` par défaut. 409 si la vidéo est déjà dans le cours |
| `PATCH/DELETE /admin/academy/courses/:id/lessons/:lessonId` | Édition ou suppression d'une leçon |
| `PUT /admin/academy/courses/:id/lessons/order` | `{lessonIds}` : TOUS les identifiants du cours, une fois chacun. Renumérote 1…n |

Le lien YouTube suit les règles des vidéos de bourse : HTTPS, `youtube.com` ou
`youtu.be`, identifiant de 11 caractères. Il est stocké sous la forme canonique
`https://www.youtube.com/watch?v=<id>`, celle que lit le lecteur de l'app.

## Déploiement

Migration additive `20261121120000_academy_course_admin` : `slug` (nullable,
unique), `displayOrder` (défaut 0) sur les cours, `status` (défaut `published`)
sur les leçons, et deux index. Elle est appliquée par le `prisma migrate deploy`
du workflow de déploiement. Un code plus ancien ignore ces colonnes.
