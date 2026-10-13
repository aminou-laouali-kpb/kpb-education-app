# KPB Education - Deployment Guide

The authoritative executable go-live gates (immutable SHA, exact-SHA CI,
backup/restore evidence and 24-hour stability) are collected in
[`go-live-operations-gates.md`](go-live-operations-gates.md). This guide remains
the infrastructure runbook; the linked gates decide whether a release may
advance.

Pour l'activation et les incidents du Success Lab, appliquer également le
runbook `docs/kpb-competition-readiness-operations-runbook.md`. Un déploiement
réussi ne vaut pas autorisation de pilote tant que sa checklist terrain n'est
pas signée.

## 0. Production actuelle — VPS Hostinger derrière le Traefik existant

C'est la procédure **de référence** pour le lancement. Le VPS Hostinger
(`72.60.190.175`, domaine `kpbeducation.cloud`) fait déjà tourner un **Traefik
v3** partagé (réseau Docker externe `traefik`, ports 80/443, certificats
Let's Encrypt via resolver `letsencrypt`) devant n8n + Mautic. L'app KPB s'y
**greffe** : pas de nginx, pas de ports 80/443 propres — `api` et `admin`
rejoignent le réseau `traefik` et sont routés par des labels (déjà dans
`docker-compose.yml`). `db` + `clamav` restent sur un réseau privé `internal`.

**DNS** (déjà créés) : `api.kpbeducation.cloud` et `admin.kpbeducation.cloud`
→ `72.60.190.175` (A). Requis avant le 1er déploiement pour l'émission du
certificat (challenge HTTP-01 de Traefik). Le domaine racine
`kpbeducation.cloud` (`@` + CNAME `www`) pointe aussi sur ce VPS et est servi
par le service `web` (pages légales statiques — voir ci-dessous).

**Site légal statique (`web`)** : sert `kpbeducation.cloud` — politique de
confidentialité, CGU et procédure de suppression de compte. Ces URLs sont
référencées dans Play Console (« Privacy policy », « Account deletion ») et
App Store Connect ; elles doivent rester en ligne en permanence. Mise en
service : `docker compose up -d web` (aucun build, image nginx officielle ;
contenu monté depuis `web/public/`).

> ⚠️ `web/nginx.conf` et `web/public/` sont **montés au démarrage** du conteneur.
> Modifier un de ces fichiers ne change rien tant que `kpb_web` n'est pas
> recréé. C'est ce qui est arrivé au bloc `location = /app` ajouté le
> 10/08/2026 : il est resté dans le dépôt pendant 17 jours pendant que
> `https://kpbeducation.cloud/app` — l'URL courte imprimée dans **tous** les
> messages de parrainage WhatsApp — renvoyait un 404 servant le corps de la page
> d'accueil. `deploy.yml` inclut désormais `web` dans son `up -d`, donc un
> déploiement suffit.

**Déploiement (SSH sur le VPS)** :

```bash
# 1. Récupérer le code
git clone <repo> /docker/kpb && cd /docker/kpb   # ou git pull si déjà cloné

# 2. Créer le .env de prod À CÔTÉ du docker-compose.yml (voir §1 pour le
#    contenu complet ; secrets forts, jamais commités). Au minimum :
#    POSTGRES_* , KPB_JWT_* , KPB_ADMIN_REFRESH_SECRET , SUPABASE_URL ,
#    CORS_ORIGINS=https://admin.kpbeducation.cloud , GROQ/RESEND ,
#    FCM_SERVICE_ACCOUNT_JSON (push), ONESIGNAL_* (repli anciennes versions)…

# 3. Utiliser un tag d'image immuable (SHA Git ou version de release).
export KPB_IMAGE_TAG="$(git rev-parse --short=12 HEAD)"
export KPB_BUILD_SHA="$(git rev-parse HEAD)"

# 4. Le réseau Traefik existe déjà (créé par le stack marketing). Sinon :
docker network create traefik

# 5. Construire les images SANS remplacer les conteneurs en cours.
docker compose build api admin

# 6. Vérifier puis copier la dernière sauvegarde hors du VPS.
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-kpb}" \
  --format=custom > "backups/predeploy-${KPB_IMAGE_TAG}.dump"

# 7. Appliquer les migrations une seule fois avec la nouvelle image. Les
#    conteneurs en ligne restent sur l'ancienne image si cette étape échoue.
docker compose run --rm --no-deps api npx prisma migrate deploy

# 8. Remplacer uniquement l'API et l'admin, puis vérifier leur santé.
docker compose up -d --no-deps api admin

# 9. Première installation seulement : seed après migrations.
docker compose exec api npm run prisma:seed

# 10. Vérifs
curl -fsS https://api.kpbeducation.cloud/api/health/live   # 200 attendu
curl -fsS https://api.kpbeducation.cloud/api/health/ready  # 200 attendu
# Quel commit tourne réellement ? Doit valoir $KPB_IMAGE_TAG, jamais "unknown".
curl -fsS https://api.kpbeducation.cloud/api/health/version
curl -fsS https://api.kpbeducation.cloud/api/config/app
#    admin.kpbeducation.cloud doit répondre en HTTPS (cert Let's Encrypt auto)
```

Le démarrage de l'API n'applique volontairement aucune migration. Cette étape
explicite garantit que la sauvegarde est terminée avant toute évolution du
schéma et qu'un échec de migration ne remplace pas les conteneurs sains.

## Déploiement automatisé (KPB-167)

Le workflow **`.github/workflows/deploy.yml`** reproduit la procédure ci-dessus,
et c'est désormais le chemin recommandé. Lancement : onglet **Actions →
« Deploy backend (VPS) » → Run workflow** (ref à déployer, `main` par défaut).

**Volontairement manuel** : déployer est une décision, pas un effet de bord d'un
merge. Pour l'automatiser plus tard, ajouter un déclencheur `workflow_run` sur
un Backend CI vert.

Ce que le workflow ajoute par rapport au manuel :

- il **remplace `api`, `admin` et `web`** — `web` en fait partie parce que
  recréer `kpb_web` est la seule façon de charger un changement de
  `web/nginx.conf` ou de `web/public/`. `clamav` est **volontairement exclu** :
  le scan d'upload est fail-closed, donc le recréer ferait échouer en 503 tout
  envoi de photo de profil pendant les minutes de chargement des signatures ;
- il **échoue si le dump pré-déploiement est vide** (au lieu de le découvrir
  plus tard) ;
- il **vérifie de l'extérieur que le catalogue vient de PostgreSQL**
  (`"source":"database"` dans `/api/catalog/scholarships`) : un `200` prouve
  seulement que quelque chose répond, pas que le code de ce build est en ligne ;
- **health gate** : jusqu'à 100 s d'attente sur `/api/health/ready`, qui vérifie
  aussi la connexion PostgreSQL ;
- **rollback automatique du code** : il mémorise l'image en cours d'exécution
  avant le remplacement et la remet en cas d'échec du health gate, puis publie
  les 80 dernières lignes de logs de l'API ;
- il **exporte `KPB_IMAGE_TAG` dans la même session** que le build et le
  `up -d`, ce qui supprime le piège du tag perdu (redémarrage silencieux de
  l'ancienne image `:local`) ;
- le `pg_dump` expand `$POSTGRES_USER` **dans le conteneur** `db`, donc il ne
  dépend pas de l'environnement du shell appelant.

> Le rollback restaure l'**image**, pas le schéma : les migrations sont
> forward-only. C'est sûr parce que toutes les migrations de ce repo sont
> additives (colonnes nullables ou avec défaut), qu'un code plus ancien ignore.
> Ne restaurer la base qu'en cas de corruption avérée.

**Synchronisation bornée** : le workflow ne lance jamais `rsync --delete` sur la
racine du déploiement. Il synchronise séparément les quatre arbres autorisés
`backend/`, `admin/`, `web/` et `scripts/`, et ne supprime que dans l'arbre en
cours. Un fichier retiré du dépôt est donc retiré du VPS, y compris une ancienne
page de `web/public/`. Des règles explicites protègent les `.env` d'exécution,
`node_modules`, caches de dépendances/build, uploads, stockage et logs. Le `.env`
racine, `backups/`, les volumes Docker et toutes les autres données du VPS sont
hors des destinations de suppression. Le contrat est simulé sans SSH dans
`release-safeguards-ci.yml` via `scripts/sync-deployment-tree.sh`.

## Ordre de livraison : le backend d'abord, le mobile ensuite

**La règle.** Une build mobile ne part jamais avant que la production ne fasse
tourner le commit dont elle est issue. L'inverse met entre les mains des
utilisateurs une app qui appelle des routes que l'API ne connaît pas encore —
et un téléphone déjà mis à jour ne peut pas revenir en arrière, alors qu'un
backend, si.

**Le geste, avant d'ouvrir Xcode Organizer ou de promouvoir une piste Play** :
lancer **Actions → « Release preflight (backend before mobile) » → Run workflow**
avec le ref d'où la build est coupée. Il est rouge si :

- le ref ne résout pas vers un commit de `origin/main`, ou si Backend/Admin/
  Flutter/Release safeguards CI ne sont pas verts pour ce SHA exact ;
- `GET /api/health/version` ne renvoie pas le même SHA court que
  `git rev-parse --short=12 <ref>` — donc la prod est en retard ;
- il renvoie `sha: unknown` — la prod n'a pas été livrée par `deploy.yml` ;
- `https://kpbeducation.cloud/app` ne contient pas l'identifiant App Store ;
- le delivery gate public ou le dernier heartbeat de sauvegarde échoue ;
- la fenêtre de disponibilité de 24 heures contient un échec, moins de 80
  sondes réussies ou un trou supérieur à 30 minutes.

Il est en lecture seule : lectures Git/GitHub et sondes HTTP, sans accès en
écriture au VPS, à la base ou aux stores. La séquence complète et la dérogation
de stabilité explicitement tracée sont décrites dans
[`go-live-operations-gates.md`](go-live-operations-gates.md).

> **Pourquoi un workflow et pas un paragraphe.** Ce document contient depuis des
> semaines la phrase « Mise en service : `docker compose up -d web` ». Elle n'a
> jamais été exécutée, et `/app` a renvoyé 404 pendant 17 jours. Une règle écrite
> nulle part ailleurs que dans une doc n'est pas une règle, c'est un souhait :
> elle doit être **écrite ici ET outillée** par le préflight.

### Avant de relever `KPB_MIN_APP_VERSION`

`KPB_MIN_APP_VERSION` est le seul interrupteur à distance du produit : le relever
force toutes les builds antérieures sur un écran de mise à jour **non
refermable**, dont l'unique bouton est grisé si l'URL de store est vide ou
morte. Le relever avec de mauvaises URLs enferme donc tous les utilisateurs
dehors, sans recours applicatif.

Poser d'abord ces deux variables dans le `.env` du VPS :

```env
KPB_ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=com.karatou.android
KPB_IOS_STORE_URL=https://apps.apple.com/app/id1128659292
```

Puis **constater les deux URLs correctes dans la réponse réelle**, et seulement
ensuite relever la version minimale :

```bash
curl -fsS https://api.kpbeducation.cloud/api/config/app   # lire androidStoreUrl ET iosStoreUrl
```

Les identifiants publiés sont `com.karatou.android` (Play) et `id1128659292`
(App Store) — l'app est **déjà en ligne** sous ces identifiants. Ce sont aussi
les valeurs de repli du contrôleur, verrouillées par un test unitaire
(`backend/src/modules/config/app-config.controller.spec.ts`) : un redéploiement
sans les variables sert donc des URLs valides. Ne pas s'en contenter — vérifier
la réponse.

### Secrets GitHub requis

À créer dans **Settings → Secrets and variables → Actions** (et, si tu utilises
l'environnement `production`, y ajouter éventuellement une règle de validation
manuelle) :

| Secret | Exemple | Rôle |
|---|---|---|
| `VPS_SSH_KEY` | contenu de la clé privée | Clé de déploiement (idéalement **dédiée**, pas ta clé personnelle) |
| `VPS_HOST` | `72.60.190.175` | Hôte SSH |
| `VPS_USER` | `root` | Utilisateur SSH |
| `VPS_PATH` | `/opt/kpb` | Dossier contenant `docker-compose.yml` **et** `.env` |
| `VPS_HEALTH_URL` | `https://api.kpbeducation.cloud` | Base URL des sondes de santé |
| `VPS_ADMIN_URL` | `https://admin.kpbeducation.cloud` | Sonde admin (uptime) |
| `VPS_WEB_URL` | `https://kpbeducation.cloud` | Sonde des pages légales (uptime) |

La clé publique correspondante doit être autorisée sur le VPS
(`~/.ssh/authorized_keys`). Le workflow épingle l'empreinte de l'hôte via
`ssh-keyscan` — il ne désactive jamais la vérification — et supprime la clé
privée du runner en fin de job.

## Surveillance

**`.github/workflows/uptime.yml`** sonde toutes les 15 minutes
`/api/health/live`, `/api/health/ready` (donc aussi la base), l'admin, puis les
pages web : `/app`, `/invite.html`, `/confidentialite.html`, `/conditions.html`
et `/suppression-compte.html`. Un échec fait échouer le run, ce qui déclenche la
notification GitHub habituelle.

Deux propriétés de cette sonde méritent d'être connues, parce qu'elle a
longtemps pu passer au vert sans rien tester :

- **Une sonde sans URL est une sonde cassée, pas une sonde satisfaite.** Chaque
  étape échoue quand son secret manque. Avant, les trois étapes se sautaient en
  silence : les trois secrets absents donnaient un run vert n'ayant rien testé.
- **Les pages web sont vérifiées sur leur CONTENU, jamais sur leur statut.**
  `web/nginx.conf` contient `error_page 404 /index.html` : n'importe quel chemin
  inconnu répond avec le corps de la page d'accueil. Un test de statut est donc
  aveugle deux fois — il lit 404 sur une page qui s'affiche bien, et le jour où
  ce repli deviendrait un 200 il passerait au vert sur la mauvaise page. D'où :
  `/app` doit porter les deux identifiants de store ; `/invite.html` doit charger
  `/invite.js` et ne contenir **ni** `<script>` inline **ni** `style=` (la CSP
  envoyée par ce même nginx les bloque, et le code de parrainage reste alors
  vide) ; chaque page légale est reconnue à son propre `<title>`.

Le nombre d'appels `/api` par run est volontairement limité à deux : l'API
applique un rate limiting par IP cliente, et une sonde bavarde finirait par
mesurer le throttler. Les URLs `web` ne traversent pas l'API et ne comptent pas
dans ce budget.

⚠️ **C'est un filet de sécurité, pas un outil de monitoring** : les crons GitHub
sont *best-effort* (retards de plusieurs minutes, exécutions parfois sautées) et
les workflows planifiés sont **désactivés après 60 jours sans activité** sur le
repo. Il n'y a ni escalade ni SMS. **Garde un moniteur externe comme alerte
primaire** — UptimeRobot ou healthchecks.io suffisent en offre gratuite, sur les
mêmes URLs. Le heartbeat de sauvegarde (KPB-153) doit lui aussi passer par ce
moniteur externe.

Pour un rollback applicatif, remettre tous les flags Competition Readiness à
`false`, le kill switch IA à `true`, `KPB_SUCCESS_LAB_ROLLOUT_PERCENT=0`, puis
revenir au `KPB_IMAGE_TAG` précédent et relancer uniquement `api` et `admin`.
Les migrations de ce lot sont additives : ne restaurer la base qu'en cas de
corruption avérée, après décision opérationnelle et sauvegarde des données
post-déploiement.

Traefik gère le TLS + l'upgrade WebSocket (chat des dossiers) automatiquement —
aucune config nginx à écrire. Les limites `mem_limit` du `docker-compose.yml`
protègent la box 8 Go partagée (une fuite Mautic/n8n ne peut pas tuer l'API).

> Stockage des documents : le fallback disque est persisté sur le volume
> `kpb-uploads` (OK sur VPS). Pour décharger le disque, renseigner les
> `KPB_S3_*` (Scaleway Paris `fr-par`, Bunny, ou R2) — voir §backend.

> ⚠️ Ne pas ajouter un 2ᵉ reverse-proxy : le conteneur `traefik-hctj` en
> crash-loop sur la box est justement un Traefik en doublon à supprimer.

---

## 1. Backend — alternative : VPS dédié avec nginx

*(Procédure historique, pour un VPS dédié SANS Traefik. Sur le VPS Hostinger
actuel, suivre la §0 ci-dessus.)*

We use Docker to ensure the backend environment on the PlanetHoster VPS perfectly matches development.

### Pré-requis sur le VPS:

- Installer `docker` et `docker-compose`.
- Installer `nginx` (pour le reverse proxy et le HTTPS/SSL via Certbot).

### Déploiement :

1. Clonez ce repo sur le VPS.
2. Créez un fichier `.env` à la racine (à côté du `docker-compose.yml`) avec vos variables sécurisées :

> ℹ️ Les noms de variables doivent correspondre exactement à ce que lit le backend
> (voir `backend/.env.example` pour la liste complète et commentée, et
> `docker-compose.yml`). En particulier les secrets sont préfixés `KPB_`.

```env
# Base de données (utilisée par le service `db` et par l'API)
POSTGRES_USER=kpb_admin
POSTGRES_PASSWORD=secure_vps_password
POSTGRES_DB=kpb_prod

# Secrets applicatifs (générer des chaînes longues et aléatoires)
KPB_JWT_SECRET=production_super_secret_jwt
KPB_JWT_REFRESH_SECRET=another_long_random_secret
KPB_ADMIN_REFRESH_SECRET=another_long_random_secret

# Auth Supabase (étudiants/parents) — SUPABASE_URL est obligatoire
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_JWT_SECRET=            # seulement pour les projets HS256 legacy
SUPABASE_SERVICE_ROLE_KEY=      # secret serveur, obligatoire pour supprimer l'identité Auth

# Origines CORS autorisées (app admin web), séparées par des virgules
CORS_ORIGINS=https://admin.kpbeducation.cloud

# L'API est derrière exactement un proxy (Traefik) ; nécessaire au rate limiting
KPB_TRUST_PROXY_HOPS=1
```

`SUPABASE_SERVICE_ROLE_KEY` doit contenir la clé `service_role` historique ou
la clé secrète serveur (`sb_secret_…`), jamais la clé anon/publishable. Compose
refuse maintenant de rendre la configuration si elle manque et l'API refuse de
démarrer en production si elle est absente ou manifestement publique. La
suppression de compte appelle explicitement le hard delete Supabase
(`should_soft_delete: false`) avant toute écriture de purge locale ; une erreur
du fournisseur renvoie 503 et ne peut donc pas être affichée comme un succès.

Supabase supprime alors les sessions et les refresh tokens, mais un JWT d'accès
déjà émis reste cryptographiquement valable jusqu'à son `exp`. Garder une durée
JWT courte dans le Dashboard Auth, faire effacer la session locale par le client
et, pour une opération particulièrement sensible durant cette fenêtre, vérifier
le `session_id` contre `auth.sessions`. Cette limite JWT doit être mentionnée
dans la revue de lancement : aucune API de suppression ne peut révoquer un JWT
autosuffisant déjà distribué.

3. Construisez les images, sauvegardez la base, exécutez explicitement
   `npx prisma migrate deploy` avec la nouvelle image, puis remplacez les
   services comme décrit dans la procédure de référence §0. N'utilisez pas un
   simple `up -d --build` pour une livraison de production.
4. Configurez NGINX pour pointer le domaine de production `api.kpbeducation.cloud` vers `http://127.0.0.1:3000` (le conteneur écoute sur le port `3000` via `PORT=3000` dans `docker-compose.yml`), avec HTTPS/Certbot.

> ⚠️ **Le chat temps réel (WebSocket) exige l'upgrade côté nginx** — sans les
> en-têtes ci-dessous, la connexion socket.io échoue en production. Prévoir aussi
> `client_max_body_size` ≥ 10 Mo pour les uploads de documents.
>
> ```nginx
> server {
>   server_name api.kpbeducation.cloud;
>   client_max_body_size 12m;                 # uploads (limite app = 10 Mo)
>   location / {
>     proxy_pass http://127.0.0.1:3000;
>     proxy_http_version 1.1;                  # requis pour le WebSocket
>     proxy_set_header Upgrade $http_upgrade;  # /socket.io upgrade
>     proxy_set_header Connection "upgrade";
>     proxy_set_header Host $host;
>     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
>     proxy_set_header X-Forwarded-Proto $scheme;
>   }
> }
> ```

> Les documents étudiants ne sont plus servis par un chemin public `/uploads`.
> N'ajoutez donc pas de bloc Nginx qui pointe ce chemin vers le volume : le
> téléchargement passe uniquement par l'API authentifiée. Nginx doit être le
> seul proxy de l'API exposé à Internet ; c'est ce qui rend fiable
> `KPB_TRUST_PROXY_HOPS=1` et le rate limiting par adresse client.

### Vérification de santé après déploiement

L'API expose trois contrôles distincts :

- `GET /api/health/live` vérifie que le processus répond ; Docker l'utilise pour son healthcheck.
- `GET /api/health/ready` vérifie aussi la connexion PostgreSQL. Un répartiteur ou une sonde externe doit exiger un `200` avant de router du trafic vers une nouvelle version.
- `GET /api/health/version` renvoie `{ sha, startedAt }` : le SHA court (12
  caractères de `KPB_BUILD_SHA`, injecté par `docker-compose.yml` et exporté par
  `deploy.yml`) du code **réellement** en ligne, et l'instant de démarrage du
  processus. C'est ce qui rend « la prod est-elle sur ce commit ? » vérifiable
  au lieu d'être présumé ; c'est aussi ce que compare le préflight de release.
  `sha: "unknown"` signifie que la build n'a pas été estampillée — donc qu'elle
  n'est pas passée par `deploy.yml`. La route n'expose rien d'autre : ni versions
  de dépendances, ni chemins.

Après `docker-compose up -d --build`, vérifiez les deux :

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/live
curl -fsS https://api.kpbeducation.cloud/api/health/ready
docker compose ps
```

### Database Migrations & seed :

Lorsque l'API Container est lancé pour la première fois, la base de données est vide. Appliquez le schéma Prisma puis semez le catalogue :

```bash
docker exec -it kpb_api npx prisma migrate deploy
docker exec -it kpb_api npm run seed:catalog   # pays + catalogue unique
docker exec -it kpb_api sh -c 'npm run import:omnes:bundled && npm run seed:omnes'  # formations OMNES
docker exec -it kpb_api npm run seed:partners  # écoles partenaires (annexe 05)
docker exec -it kpb_api npm run prisma:seed    # comptes admin (mots de passe temporaires imprimés une fois) + contenu de démo
docker exec -it kpb_api npm run verify:catalog # confirme 0 référence pays orpheline ; avertit (::warning::) sur fieldId orphelin, partenaire sans formation, > 1 000 formations
```

`seed:omnes`, `seed:partners` et `prisma:seed` **refusent de tourner en
production** (code de sortie 1) dès que la base contient une des lignes qu'ils
écriraient : ils ne passent que sur une première installation. `seed:omnes` et
`seed:partners` ne suppriment ni ne modifient plus jamais une ligne existante
(ils créaient auparavant tout leur espace `omnes-*` / `partner-*` après l'avoir
vidé, Mundiapolis et Universiapolis compris). Pour forcer un seed en
connaissance de cause, et pour ce seul lancement :
`docker compose exec -e KPB_ALLOW_PRODUCTION_SEED=1 api npm run <seed>`.
Détails : `backend/scripts/README.md`.

> ℹ️ Le conteneur API **n'exécute volontairement aucune migration au
> démarrage**. Appliquez `prisma migrate deploy` une seule fois, après la
> sauvegarde et avant le remplacement des conteneurs, conformément à la §0.
> Cette séparation évite qu'un redémarrage automatique modifie le schéma sans
> fenêtre contrôlée. Les seeds ne sont à relancer que pour un premier
> provisioning ou un rafraîchissement explicitement validé du catalogue.

### Sauvegardes de la base de données

Le service `db-backup` (dans `docker-compose.yml`) crée automatiquement un dump
gzippé par jour dans `./backups` sur le VPS (bind mount → les dumps survivent à
`docker-compose down -v`), avec une rétention de `BACKUP_KEEP_DAYS` jours (14 par
défaut ; réglable dans `.env`).

Le conteneur est marqué `unhealthy` si aucun dump quotidien non vide de moins de
30 heures n'existe. Le workflow **Backup readiness** vérifie cet état et
l'intégrité de l'archive toutes les six heures. Le workflow manuel **Backup
restore drill** restaure dans un conteneur et un volume jetables, jamais dans
`kpb_db`.
Voir [`go-live-operations-gates.md`](go-live-operations-gates.md#3-backup-heartbeat-and-safe-restore-evidence).

**Important — copie hors-site :** `./backups` est sur le même disque que la base.
Pour protéger contre une perte totale du VPS, synchronisez ce dossier vers un
stockage externe (les identifiants S3 `KPB_S3_*` existent déjà). Exemple de cron
hôte (quotidien) :

```bash
# crontab -e  (sur le VPS)
30 3 * * * aws s3 sync /chemin/vers/repo/backups s3://VOTRE_BUCKET/db-backups --delete
```

**Restauration** (écrase la base — arrêter l'API d'abord) :

```bash
docker-compose stop api
POSTGRES_USER=kpb_admin POSTGRES_DB=kpb_prod \
  ./backend/scripts/restore-db.sh ./backups/kpb-kpb_prod-AAAAMMJJ-HHMMSSZ.sql.gz
docker-compose up -d api
```

Testez une restauration complète sur un environnement jetable avant le lancement.
La commande sûre par défaut est `BACKUP_DIR=./backups scripts/restore-drill.sh`;
elle ne fait qu'afficher le plan. Utilisez le workflow avec
`execute_restore_drill=true` pour obtenir une preuve Actions horodatée.

---

## 2. Frontend (Flutter CI/CD)

Les pipelines CI/CD sont configurées via GitHub Actions (voir `.github/workflows/flutter-ci.yml`).
À chaque push sur `main`, GitHub teste l'application, construit un APK de
validation et compile iOS sans signature. Lorsqu'un tag `v*` est créé, GitHub
produit un AAB Android signé avec la clé d'upload ; le workflow échoue si l'une
des quatre variables de signature manque.

- L'APK Android de validation (debug).
- Le `.app` iOS (sans signature).
- L'AAB Android signé sur tag `v*`.

### Connexion Google / magic-link (deep link Supabase) :

Le retour d'authentification (Google OAuth et magic-link) utilise le deep link
`io.supabase.kpbeducation://login-callback/` (voir `AppConfig.supabaseOAuthRedirect`).
Ce scheme est enregistré dans `AndroidManifest.xml` et `ios/Runner/Info.plist`.
Il doit **aussi** figurer dans la *Redirect URLs allow-list* du dashboard Supabase
(Authentication → URL Configuration), sinon Google sign-in laisse l'utilisateur
bloqué dans le navigateur. Testez le flux complet sur un appareil physique
Android **et** iOS avant la soumission aux stores.

### API Endpoint :

L'hôte API de production canonique est **`https://api.kpbeducation.cloud/api`**.
La CI compile l'app avec `--dart-define=KPB_APP_ENV=prod`, qui résout cet hôte
via `app_config.dart` (ne pas hardcoder `KPB_API_BASE_URL`). Assurez-vous que le
certificat TLS nginx couvre bien `api.kpbeducation.cloud`.

**⚠️ Attention pour iOS :**
Le GitHub Action actuel compile l'application iOS pour prouver qu'il n'y a pas d'erreur de compilation (`--no-codesign`). Il ne produit pas d'IPA signé.

### Livraison TestFlight (build 49) — jour J

La ligne complète, pour le *build* (pas l'export IPA) :

```bash
# POSTHOG_API_KEY : clé publique phc_… réelle, ou VIDE = PostHog désactivé (état
# valide). Ne collez JAMAIS « phc_… » littéral : il passe le préflight (préfixe
# phc_) mais livre une clé morte — télémétrie de prod perdue en silence.
export POSTHOG_API_KEY="${POSTHOG_API_KEY-}"
flutter build ios --release \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
```

> ### ⚠️ Les trois pièges de la distribution iOS — payés sur la build 49 (28-29/08/2026)
>
> **1. « Copy failed » à l'étape Distribute = conflit rsync/PATH, PAS l'espace du chemin.**
> `IDEDistributionCreateIPAStep` lance `/usr/bin/rsync -8aPhhE --link-dest …`, mais
> `/usr/bin/rsync` est **openrsync** (« 2.6.9 compatible ») qui **ignore `-8`** ; le flag
> n'est ajouté que parce qu'un rsync 3.x (MacPorts `/opt/local/bin`, ou Homebrew) précède
> `/usr/bin` dans le PATH hérité par Xcode. **Lancer Xcode avec un PATH assaini :**
>
> ```bash
> env PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
>   /Applications/Xcode.app/Contents/MacOS/Xcode ios/Runner.xcworkspace
> ```
>
> Une fenêtre rouverte depuis le Dock/Finder réhérite du PATH pollué : le bug revient.
>
> **2. Rejet 90474 — orientations iPad.** Un bundle qui embarque l'iPad doit déclarer les
> **4** orientations dans `UISupportedInterfaceOrientations~ipad` (multitâche iPad).
>
> **3. Rejet 90101 — famille d'appareils.** On ne peut **pas** retirer l'iPad d'une app
> **déjà publiée**. `TARGETED_DEVICE_FAMILY = "1"` est refusé.
>
> 2 et 3 se combinent : la **seule** configuration valide est `"1,2"` **+ 4 orientations
> iPad** (celle de la build 48, acceptée). L'iPhone reste portrait-only et
> `lockPortraitOrientation` verrouille le portrait au runtime sur les deux familles —
> les 4 orientations déclarées n'autorisent **aucune** rotation réelle.
> `scripts/preflight-ios-archive.sh` garde désormais 2 et 3 (garde couplée, vue rouge sur
> les deux archives réellement rejetées). Le faire tourner **avant** « Distribute ».
> Il échoue toujours sur « Apple Distribution » en signature automatique : c'est **normal**,
> Xcode re-signe au moment du Distribute.

`flutter build ipa --release` avec les mêmes defines **échoue à l'export sur
cette machine** (espace dans le chemin du dépôt, « Copy failed »). La voie
réelle est donc : `flutter build ios` ci-dessus, puis **Xcode → Product →
Archive → Organizer → Distribute**.

Avant d'ouvrir Organizer, lancer le préflight sur l'artefact (il ne construit
rien) :

```bash
scripts/preflight-ios-archive.sh \
  --xcconfig ios/Flutter/Generated.xcconfig \
  --archive-plist <Archive>.xcarchive/Products/Applications/Runner.app/Info.plist
```

Cinq assertions : `FLUTTER_BUILD_NUMBER` / `CFBundleVersion` = 49 ;
`DART_DEFINES` décodés contiennent `POSTHOG_API_KEY`, `KPB_APP_ENV=prod`,
`KPB_WHATSAPP_NUMBER` ; orientations = portrait ; `UIBackgroundModes` =
`remote-notification` ; `CFBundleLocalizations` = `fr`.

**dSYM → Crashlytics (LIV-T11).** Le `pbxproj` n'a aucune phase
`upload-symbols`. Après l'archive, téléverser manuellement les dSYM depuis
Organizer (ou `FirebaseCrashlytics/upload-symbols`) avant de Distribuer.
Sans ça, les crashes TestFlight restent illisibles.

Ne pas retirer l'iPad (`TARGETED_DEVICE_FAMILY` reste `1,2`) : retirer une
famille d'une app déjà publiée est un refus.

---

## 3. Panneau admin (Next.js)

Le panneau admin est un service du `docker-compose.yml` (`admin`, image Next.js
standalone), à placer derrière nginx sur `https://admin.kpbeducation.cloud` — ce
domaine doit figurer dans `CORS_ORIGINS` (déjà le cas dans l'exemple `.env`).

- **Build/déploiement** : `docker-compose up -d --build admin`. L'URL de l'API
  est **inlinée au build** via l'argument `NEXT_PUBLIC_KPB_API_BASE_URL`
  (défaut `https://api.kpbeducation.cloud/api`, surchargable par
  `KPB_ADMIN_API_BASE_URL` dans le `.env`) — **rebuild** l'image si l'hôte API
  change.
- **nginx** : proxy `admin.kpbeducation.cloud` → `http://127.0.0.1:3001`, HTTPS via
  Certbot. Pour que le cookie de session admin (httpOnly, `Secure`) fonctionne,
  l'admin et l'API doivent être servis en HTTPS sur le même domaine parent
  (`*.kpbeducation.cloud`).
- Le conteneur tourne en utilisateur non-root et n'expose que le port 3000
  interne (publié sur `127.0.0.1:3001`).
