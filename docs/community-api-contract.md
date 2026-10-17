# Communauté KPB — contrat d'API (C1 + C2, bot Vérif C3, bot Passerelle C3 bis)

Version du contrat : **community-api v1 — 17/10/2026** (révision 1 le même jour : identité réelle
réservée à Admin/SuperAdmin, liste des sanctions, classement des signalements d'un membre,
lecture des discussions pour le conseiller, valeurs du journal, deux indicateurs de tableau de bord ;
**révision 2** le même jour, additive : bot « Vérif » C3 — auteur et badge `kpb_assistant`, champ
`Reply.assistant`, routes `/admin/community/bot/*` (§8.9), deux codes d'erreur, §14 ;
**révision 3** le même jour, additive : bot « Passerelle » C3 bis — notification privée
`assist_bridge`, clé de désinscription `assist_bridge`, `POST /me/assist-bridge/events/:id`,
routes `/admin/community/assist-bridge/*` (§8.10), `features.assistBridge`, code
`assist_bridge_event_not_found`, §15). Statut : **stable** — l'app (Flutter) et
l'admin (Next.js) se construisent sur ce document. Toute évolution est **additive** (champ
nouveau, valeur d'énumération nouvelle tolérée par les clients) ; une rupture exige une v2.

Serveur : `backend/src/modules/community/` (NestJS 11, Prisma 6). Préfixe global : `/api`
(les chemins ci-dessous l'omettent, comme le reste de `docs/api-contracts.md`).

Sommaire : §1 principes · §2 drapeau et portes · §3 erreurs · §4 pagination et limites ·
§5 modèles JSON · §6 visibilité · §7 routes élève · §8 routes admin · §9 modération et
anti-arnaque · §10 fil « Pour toi » · §11 notifications · §12 RGPD · §13 ce qui ne change pas ·
§14 bot « Vérif » (révision 2) · §15 bot « Passerelle » (révision 3).

---

## 1. Principes

- Une communauté d'entraide **branchée sur le catalogue** : chaque bourse, pays, école et
  formation a un **espace** = les publications qui la **mentionnent**.
- Trois types de publication : `question`, `experience` (retour d'expérience), `advice` (conseil).
- Réponses **à un seul niveau** sous une publication (pas de réponse à une réponse).
- **Aucun message privé**, **aucune mention d'utilisateur** (seulement d'entités du catalogue),
  aucune géolocalisation. Profil public minimal : prénom + initiale, pays de résidence, badges,
  nombre de réponses utiles. **Jamais** e-mail, téléphone, âge, date de naissance.
- **Pas de lecture invité** en v1 : toutes les routes élève exigent un jeton (§2). Raisons :
  blocage et signalement exigent une identité ; mineurs ; aspiration de contenu. *(À VALIDER)*
- Toutes les dates sont des chaînes ISO 8601 UTC (`2026-10-17T09:30:00.000Z`).
- Les textes renvoyés suivent `?lang=fr|en` (défaut `fr`) pour les seuls **libellés serveur**
  (libellés d'entités mentionnées, charte, notifications). Le contenu écrit par les membres
  n'est jamais traduit.

## 2. Drapeau et portes

### 2.1 Drapeau distant `features.community`

| Clé `/config/app` | Variable | Défaut |
|---|---|---|
| `features.community` | `KPB_COMMUNITY_ENABLED` | **`false`** (seule la valeur `true`, casse et espaces tolérés, l'ouvre) |

Booléen **strict**, toujours présent dans `features`. Un backend plus ancien ne le sert pas :
l'app lit une clé absente comme `false`. La **même variable** coupe toutes les routes élève
`/community/*` de ce contrat. Les routes **admin** `/admin/community/*` ne sont **jamais**
coupées (l'équipe prépare, modère et peut fermer puis rouvrir sans perdre la file).

Les routes historiques `GET /community/forum-categories` et `GET /community/forum-tags`
(gardées par `MvpGuard` / `KPB_MVP_ONLY`) ne changent pas — voir §13.

### 2.2 Ordre des portes (routes élève)

1. Drapeau coupé → **404** `{ "statusCode": 404, "disabled": true, "code": "community_disabled", "message": "Community is disabled." }`,
   **avant** toute authentification (aucun appel Supabase pour une fonction éteinte).
2. Jeton élève absent ou invalide → **401** (`StudentAuthGuard`, forme standard).
3. Compte non élève (`accountType` ≠ `student` : parent, partenaire) → **403** `community_students_only`.
   *(À VALIDER : ouvrir la lecture aux parents.)*
4. Écritures seulement : charte non acceptée ou version périmée → **403** `community_charter_required`
   (sauf `POST /community/charter/accept`, signalement, blocage, suivi — §6.4).
5. Écritures seulement : membre sanctionné → **403** `community_read_only`.
6. Écritures seulement : quotas → **429** `community_rate_limited`.

Le premier appel authentifié à une route `/community/*` crée la fiche membre (`CommunityMember`)
si elle n'existe pas : il n'y a pas d'inscription séparée.

## 3. Erreurs

Forme (filtre global) : `{ statusCode, message, code?, details?, requestId, timestamp }`.
Seule l'erreur « drapeau coupé » a la forme spéciale du §2.2 (`disabled: true` au premier niveau).
Les erreurs de validation de forme (ValidationPipe, `forbidNonWhitelisted`) sont des **400** sans
`code` (`message` = tableau de messages).

| HTTP | `code` | Quand | `details` |
|---|---|---|---|
| 404 | `community_disabled` | drapeau coupé (forme spéciale) | — |
| 403 | `community_students_only` | compte parent / partenaire | — |
| 403 | `community_charter_required` | écriture sans charte acceptée (ou version périmée) | `{ charterVersion }` |
| 409 | `community_charter_outdated` | `POST /community/charter/accept` avec une autre version que la courante | `{ charterVersion }` |
| 403 | `community_read_only` | membre en lecture seule ou banni | `{ kind: "read_only" \| "ban", until: string \| null }` |
| 429 | `community_rate_limited` | quota dépassé (§4.3) — le délai est dans `details.retryAfterSeconds` (pas d'en-tête `Retry-After`, réservé au limiteur HTTP) | `{ scope, limit, retryAfterSeconds }` |
| 404 | `community_post_not_found` | publication absente, supprimée, invisible pour ce lecteur, ou d'un membre bloqué | — |
| 404 | `community_reply_not_found` | idem pour une réponse | — |
| 404 | `community_member_not_found` | membre inconnu ou relation de blocage | — |
| 404 | `community_entity_not_found` | entité du catalogue inconnue ou non publique | — |
| 403 | `community_not_author` | modifier / supprimer le contenu d'un autre | — |
| 403 | `community_edit_window_closed` | modification au-delà de 15 min | `{ editableUntil }` |
| 409 | `community_post_not_open` | répondre à sa propre publication masquée / en attente | — |
| 400 | `community_invalid_mention` | jeton de mention mal formé, entité inexistante ou non publique | `{ type, id }` |
| 400 | `community_too_many_mentions` | > 10 mentions dans un contenu | `{ max: 10 }` |
| 400 | `community_too_many_hashtags` | > 10 hashtags dans une publication | `{ max: 10 }` |
| 400 | `community_invalid_cursor` | curseur illisible ou d'un autre fil | — |
| 400 | `community_cannot_react_own` | « utile » sur son propre contenu | — |
| 400 | `community_cannot_block_self` | se bloquer soi-même | — |
| 400 | `community_cannot_report_self` | se signaler soi-même ou son contenu | — |
| 400 | `community_cannot_block_team` | bloquer l'équipe KPB (contenu admin) | — |
| 409 | `community_pin_limit` | (admin) plus de 3 publications épinglées | `{ max: 3 }` |
| 409 | `community_invalid_transition` | (admin) action impossible dans l'état courant (ex. rétablir un contenu supprimé par son auteur) | `{ status }` |
| 404 | `community_bot_draft_not_found` | (admin, révision 2) brouillon du bot inconnu | — |
| 409 | `community_bot_draft_obsolete` | (admin, révision 2) publier un brouillon dont la publication n'est plus visible ou dont les faits ont changé depuis sa rédaction (le brouillon passe `obsolete`) | `{ reason: "post_not_visible" \| "facts_changed" \| … }` |
| 404 | `assist_bridge_event_not_found` | (élève, révision 3) clic sur une suggestion qui n'existe pas, n'est pas la sienne ou n'a jamais été envoyée | — |

## 4. Pagination, limites, quotas

### 4.1 Pagination par curseur

Toutes les listes : `{ "items": [...], "nextCursor": string | null }`. `nextCursor` est
**opaque** (base64url) : le client le renvoie tel quel dans `?cursor=` et ne l'interprète
jamais. `null` = fin de liste. Un curseur porte le fil qui l'a émis : le réutiliser sur un
autre fil → 400 `community_invalid_cursor`.

`?limit=` : défaut **20**, max **50** (listes de publications, recherche, file admin) ;
réponses d'une publication : défaut **30**, max **100**. Au-delà du max : 400 (validation).

Le fil « Pour toi » fige son horloge dans le curseur (`asOf`) : les pages suivantes sont
calculées avec la même heure, donc sans trou ni doublon dû au temps qui passe. Un compteur
qui bouge entre deux pages peut déplacer une publication d'une page à l'autre (accepté).

### 4.2 Limites de contenu (400 si dépassées)

| Champ | Min | Max |
|---|---|---|
| `title` (publication) | 8 | 120 caractères (espaces de bord retirés) |
| `body` (publication) | 20 | 5 000 |
| `body` (réponse) | 2 | 3 000 |
| `details` (signalement) | — | 500 |
| `reason` (action admin) | 3 | 500 |
| Mentions par contenu | — | 10 |
| Hashtags par publication | — | 10 (2 à 40 caractères chacun) |

### 4.3 Quotas (429 `community_rate_limited`)

« Nouveau compte » = `UserProfile.createdAt` il y a moins de **7 jours**.

| `scope` | Nouveau compte | Compte établi | Fenêtre |
|---|---|---|---|
| `posts_per_day` | 3 | 10 | 24 h glissantes |
| `replies_per_hour` | 10 | 30 | 60 min glissantes |
| `reports_per_day` | 20 | 20 | 24 h glissantes |

S'y ajoute une limite HTTP par IP sur toutes les écritures (20 requêtes / min / route, 429
standard du limiteur). Les quotas restants sont lisibles dans `GET /community/me` (`limits`).

### 4.4 Fenêtre de modification

Un contenu (publication ou réponse) est modifiable par son auteur pendant **15 minutes** après
sa création (`viewer.editableUntil`). Une modification repasse le filtre (§9) : elle peut
masquer un contenu visible. Suppression par l'auteur : **toujours** possible.

## 5. Modèles JSON

### 5.1 `Author`

```json
{
  "kind": "member",
  "memberId": "cm_8f2k…",
  "displayName": "Aïcha K.",
  "countryName": "Niger",
  "badges": ["verified_alumni"]
}
```

| Champ | Type | Sens |
|---|---|---|
| `kind` | `"member" \| "kpb_team" \| "kpb_advisor" \| "kpb_assistant"` | membre, « Équipe KPB », conseiller KPB, « Assistant KPB » (bot Vérif, révision 2 — §14) |
| `memberId` | `string \| null` | identifiant public du membre (`null` pour l'équipe) — sert aux routes membre / blocage / signalement |
| `displayName` | `string` | « Prénom I. » pour un membre ; `"Équipe KPB"` ; « Prénom I. » du conseiller ; `"Assistant KPB"` (non traduit, comme « Équipe KPB ») |
| `countryName` | `string \| null` | pays de résidence déclaré, tel que saisi (ex. `"Niger"`, `"Côte d'Ivoire"`) ; `null` pour l'équipe |
| `badges` | `Badge[]` | ordre stable : `kpb_team`, `kpb_advisor`, `kpb_assistant`, `verified_alumni`, `ambassador` |

`Badge` : `"kpb_team"` (contenu de l'équipe), `"kpb_advisor"` (conseiller KPB),
`"verified_alumni"` (`UserProfile.alumniStatus = approved` et badge visible),
`"ambassador"` (ambassadeur activé par l'équipe, `Ambassador.approvedAt` posé),
`"kpb_assistant"` (révision 2 : réponse préparée par le bot Vérif depuis les données vérifiées du
catalogue). Les clients **ignorent** une valeur inconnue de badge ; un `kind` inconnu se lit
`member` — un client d'avant la révision 2 affiche donc « Assistant KPB » comme un nom, sans badge,
sans profil ni blocage (`memberId = null`).

### 5.2 `Mention`

```json
{ "type": "scholarship", "id": "clx…", "label": "Bourse Eiffel", "countryId": "fra" }
```

`type` : `"scholarship" | "country" | "institution" | "program"` (ignorer une valeur inconnue).
`label` : libellé **figé** au moment de la publication, dans la langue `?lang` (FR par défaut).
`countryId` : pays de l'entité (le pays lui-même, ou celui de la bourse / école / formation),
`null` si inconnu. Une entité devenue non publique après coup reste affichée avec son libellé
figé ; le client ouvre la fiche et gère lui-même son absence.

### 5.3 Jetons de mention et segments

**À l'écriture**, le client insère chaque mention dans `body` sous la forme :

```
@[<libellé>](<type>:<id>)        ex. « Qui a eu @[Eiffel](scholarship:clx12ab) en 2026 ? »
```

Expression exacte : `@\[([^\]\n]{1,80})\]\((scholarship|country|institution|program):([A-Za-z0-9_-]{1,64})\)`.
Le serveur valide chaque entité (publique, §7.12), **réécrit le libellé** avec le libellé FR du
catalogue et stocke la mention. Une même entité mentionnée deux fois compte une fois. Un `@`
qui ne suit pas cette forme reste du texte. Mentions **interdites dans le titre** (texte brut).

Hashtags : `#` suivi de 2 à 40 lettres, chiffres ou `_` (Unicode), précédé d'un début de
texte ou d'un caractère qui n'est ni lettre, ni chiffre, ni `_`, `&`, `/`. Clé normalisée :
minuscules sans accents (`#CampusFrance` et `#campusfrance` = `campusfrance`). Indexés pour
les **publications** (titre + corps) ; dans une réponse ils sont rendus mais pas indexés.

**À la lecture**, chaque contenu porte `body` (texte brut **avec** jetons canoniques) et
`segments`, déjà découpés — les clients rendent `segments` et n'ont pas à parser :

```json
[
  { "kind": "text", "text": "Qui a eu " },
  { "kind": "mention", "type": "scholarship", "id": "clx12ab", "label": "Bourse Eiffel" },
  { "kind": "text", "text": " en 2026 ? " },
  { "kind": "hashtag", "tag": "campusfrance", "display": "CampusFrance" },
  { "kind": "link", "url": "https://www.campusfrance.org/fr", "text": "https://www.campusfrance.org/fr" }
]
```

`kind` : `"text" | "mention" | "hashtag" | "link"` (un client rend une valeur inconnue comme
`text` avec le champ `text` s'il existe, sinon l'ignore). `link` n'est produit que pour une URL
`http(s)` dont l'hôte est sur la liste blanche (§9.2) ; toute autre URL reste un segment `text`.

### 5.4 `PostSummary` (listes)

```json
{
  "id": "cp_…",
  "type": "question",
  "title": "Délai de réponse Campus France ?",
  "excerpt": "Bonjour, j'ai déposé mon dossier @Campus France le 2 octobre…",
  "author": { "...": "Author" },
  "createdAt": "2026-10-17T09:30:00.000Z",
  "editedAt": null,
  "lastActivityAt": "2026-10-17T11:02:00.000Z",
  "replyCount": 4,
  "helpfulCount": 2,
  "hasVerifiedAnswer": true,
  "isPinned": false,
  "mentions": [ { "...": "Mention" } ],
  "hashtags": [ { "tag": "campusfrance", "display": "CampusFrance" } ],
  "viewer": {
    "isAuthor": false,
    "hasMarkedHelpful": false,
    "isFollowing": true,
    "canEdit": false,
    "canDelete": false,
    "editableUntil": null
  },
  "moderation": null,
  "forYouReasons": ["followed_scholarship", "verified_answer"]
}
```

| Champ | Sens |
|---|---|
| `excerpt` | texte brut ≤ 240 caractères (mentions rendues `@libellé`), coupé au mot, suffixe `…` |
| `replyCount` | réponses **visibles** (toutes, y compris celles de l'équipe) |
| `helpfulCount` | « utile » sur la publication |
| `hasVerifiedAnswer` | une réponse porte « Réponse vérifiée par KPB » |
| `isPinned` | épinglée par l'équipe |
| `lastActivityAt` | dernière réponse visible, sinon création |
| `viewer.canEdit` | auteur ET dans la fenêtre de 15 min ; `editableUntil` alors renseigné |
| `moderation` | **`null` sauf pour l'auteur** d'un contenu non visible : `{ "status": "pending_review" \| "hidden", "reason": ModerationReason, "since": ISO }` |
| `forYouReasons` | présent **seulement** dans l'onglet `for_you` (sinon absent) : pourquoi la publication est proposée (§10) |

`type` : `"question" | "experience" | "advice"`.
`ModerationReason` : `"auto_filter"` (filtre anti-arnaque, en attente de revue),
`"reports_threshold"` (signalements, en attente de revue), `"new_account_review"`
(compte à e-mail jetable, en attente de revue), `"moderation"` (masqué par l'équipe).

### 5.5 `Post` (détail)

`PostSummary` + :

```json
{
  "body": "Bonjour, j'ai déposé mon dossier @[Campus France](institution:…) …",
  "segments": [ { "...": "Segment" } ]
}
```

### 5.6 `Reply`

```json
{
  "id": "cr_…",
  "postId": "cp_…",
  "body": "…",
  "segments": [ { "...": "Segment" } ],
  "mentions": [ { "...": "Mention" } ],
  "author": { "...": "Author" },
  "createdAt": "…",
  "editedAt": null,
  "helpfulCount": 3,
  "isVerified": true,
  "verifiedAt": "…",
  "assistant": null,
  "viewer": { "isAuthor": false, "hasMarkedHelpful": true, "canEdit": false, "canDelete": false, "editableUntil": null },
  "moderation": null
}
```

`assistant` (révision 2) : `null`, sauf pour une réponse de l'« Assistant KPB » (`author.kind =
"kpb_assistant"`) : `{ "sourceVerifiedAt": ISO | null }` = date de vérification la plus ancienne
des fiches citées. L'app l'affiche sous la réponse : « Réponse préparée à partir des données
vérifiées de KPB · vérifié le JJ/MM/AAAA ». Un client plus ancien ignore le champ.

`isVerified` : « Réponse vérifiée par KPB » (une seule par publication ; la poser sur une autre
réponse la retire de la précédente). Ordre des réponses : la réponse vérifiée **en tête**, puis
ordre chronologique croissant.

### 5.7 `MemberProfile`

```json
{
  "member": { "kind": "member", "memberId": "cm_…", "displayName": "Aïcha K.", "countryName": "Niger", "badges": [] },
  "stats": { "helpfulAnswersCount": 12, "postsCount": 3, "repliesCount": 27 },
  "memberSince": "2026-10",
  "viewer": { "isMe": false, "isBlocked": false }
}
```

`helpfulAnswersCount` = réponses visibles du membre ayant reçu au moins un « utile » ou marquées
vérifiées. `postsCount` / `repliesCount` : contenus **visibles**. `memberSince` : mois `AAAA-MM`
(jamais la date exacte).

### 5.8 `Me`

```json
{
  "member": { "...": "Author" },
  "charter": {
    "currentVersion": "2026-10-v1",
    "acceptedVersion": "2026-10-v1",
    "acceptedAt": "…",
    "required": false,
    "title": "Charte de la communauté",
    "rules": [
      { "id": "kind", "title": "Bienveillance", "body": "…" },
      { "id": "no_money", "title": "Jamais d'argent", "body": "…" },
      { "id": "no_contact", "title": "Pas de coordonnées", "body": "…" },
      { "id": "truth", "title": "Des infos vérifiables", "body": "…" }
    ]
  },
  "restriction": null,
  "limits": {
    "newAccount": true,
    "postsPerDay": 3, "postsToday": 1,
    "repliesPerHour": 10, "repliesThisHour": 0
  },
  "stats": { "helpfulAnswersCount": 0, "postsCount": 1, "repliesCount": 0 },
  "notificationsOptedOut": false
}
```

`restriction` : `null` ou `{ "kind": "read_only" | "ban", "until": ISO | null, "reason": string }`
(`reason` = motif rédigé par l'équipe, montré au seul intéressé). `charter.required` = vrai tant
que `acceptedVersion` ≠ `currentVersion`. `notificationsOptedOut` = la clé `community` est dans
`UserProfile.disabledNotificationTypes` (§11). Textes de la charte dans la langue `?lang`.

### 5.9 `EntitySpace`

```json
{
  "entity": { "type": "scholarship", "id": "clx…", "label": "Bourse Eiffel", "countryId": "fra" },
  "discussionCount": 12,
  "items": [ { "...": "PostSummary" } ],
  "nextCursor": null
}
```

`discussionCount` (ici et dans les compteurs) = publications **visibles** qui mentionnent
l'entité (sans tenir compte des blocages du lecteur).

### 5.10 `Report`

```json
{ "id": "crp_…", "targetType": "post", "targetId": "cp_…", "reason": "scam", "status": "open", "createdAt": "…" }
```

`reason` : `"scam" | "harassment" | "inappropriate" | "spam" | "personal_info" | "misinformation" | "other"`.
`status` : `"open" | "actioned" | "dismissed"`.

## 6. Visibilité

### 6.1 États d'un contenu

| `status` (serveur) | Qui le voit | Dans les fils / espaces / recherche / compteurs |
|---|---|---|
| `visible` | tout membre (hors blocage) | oui |
| `pending_review` (masqué automatiquement, « en attente de revue ») | **son auteur seul** (avec `moderation`) + l'équipe | non |
| `hidden` (masqué par la modération) | **son auteur seul** (avec `moderation`) + l'équipe | non |
| `deleted` (supprimé par l'auteur ou l'équipe) | l'équipe seule (30 jours, puis purge — §12) | non |

Une **réponse** n'est jamais visible si sa publication ne l'est pas pour ce lecteur.

### 6.2 Blocage

`A` bloque `B` ⇒ **dans les deux sens**, aucun des deux ne voit plus les publications ni les
réponses de l'autre (fils, espaces, recherche, détail → 404, liste des réponses → omises,
profil → 404), et aucun ne reçoit de notification causée par l'autre. Un contenu de l'équipe
KPB n'est jamais filtré (on ne bloque pas l'équipe). Les compteurs (`replyCount`,
`discussionCount`) ne retranchent pas les contenus filtrés par blocage.

### 6.3 Sanctions

`read_only` (N jours) et `ban` (sans fin, jusqu'à levée) : le membre **lit** normalement mais
toute écriture répond 403 `community_read_only`. Ses contenus restent visibles, sauf si
l'équipe les masque (option `hideContent` du bannissement). `warning` : aucune restriction,
une notification.

### 6.4 Ce qui reste permis sans charte et sous sanction

Signaler (`POST /community/reports`), bloquer / débloquer, suivre / ne plus suivre, supprimer
son propre contenu, lire. Tout le reste (publier, répondre, modifier, « utile ») exige la
charte courante et l'absence de sanction.

## 7. Routes élève

Toutes : portes du §2.2, `Cache-Control: private, no-store`. Paramètre commun `?lang=fr|en`.

### 7.1 Membre, charte, préférences

| Méthode et chemin | Corps | Réponse |
|---|---|---|
| `GET /community/me` | — | 200 `Me` |
| `POST /community/charter/accept` | `{ "version": "2026-10-v1" }` | 200 `{ "acceptedVersion", "acceptedAt" }` ; 409 `community_charter_outdated` si autre version. Idempotent. |
| `GET /community/me/posts?cursor&limit` | — | 200 liste de `PostSummary` de l'auteur, **tous états sauf `deleted`**, récents d'abord |
| `GET /community/me/following?cursor&limit` | — | 200 liste de `PostSummary` suivies et visibles, par `lastActivityAt` décroissant |
| `GET /community/blocks?cursor&limit` | — | 200 liste de `{ "member": Author, "blockedAt" }` |

L'opt-out des notifications passe par le mécanisme existant (`PATCH /profiles/me`,
`disabledNotificationTypes` avec la clé `community`, §11) — pas de route dédiée.

### 7.2 Fils

`GET /community/feed?tab=for_you|recent|unanswered&type=question|experience|advice&hashtag=<clé>&cursor&limit`

- `tab` obligatoire. `type` et `hashtag` facultatifs (filtres combinables).
- `recent` : publications visibles, `createdAt` décroissant.
- `unanswered` : `type = question` (le filtre `type` est ignoré), visibles, **sans réponse
  visible d'un autre membre que l'auteur ni de l'équipe**, sans réponse vérifiée, `createdAt`
  décroissant.
- `for_you` : score du §10, fenêtre de 60 jours, **hors publications du lecteur**.
- Réponse : `{ "tab", "items": PostSummary[], "nextCursor", "pinned": PostSummary[] }` —
  `pinned` (≤ 3, épinglées visibles, plus récentes d'abord) **seulement sur la première page**
  (sans `cursor`) ; ailleurs `[]`. Une publication épinglée n'apparaît **jamais** dans `items`
  (sur aucune page de ce fil), seulement dans `pinned`.

### 7.3 Espaces d'entités et compteurs

| Méthode et chemin | Réponse |
|---|---|
| `GET /community/entities/:type/:id?sort=recent\|unanswered&cursor&limit` | 200 `EntitySpace` ; 404 `community_entity_not_found` si l'entité n'est pas publique |
| `GET /community/entities/:type/:id/count` | 200 `{ "type", "id", "discussionCount" }` (léger, pour les fiches ; 0 pour une entité sans publication, **sans** vérifier qu'elle existe) |
| `GET /community/entities/counts?refs=scholarship:id1,country:fra,…` | 200 `{ "items": [{ "type", "id", "discussionCount" }] }` — 50 références max (400 au-delà), dans l'ordre demandé, doublons retirés |

`:type` ∈ `scholarship | country | institution | program` (400 sinon).

### 7.4 Recherche

`GET /community/search?q=<texte>&type=&cursor&limit` — 2 à 100 caractères (400 sinon).
Texte normalisé (minuscules, sans accents, ponctuation = espace — la règle de
`normalizeSearchText`, comme `Program.searchText`) ; chaque mot doit apparaître dans le titre,
le corps, les hashtags ou les libellés des mentions (ET logique). Un `q` qui commence par `#`
cherche le hashtag exact. Publications visibles seulement, `createdAt` décroissant.
Réponse : liste de `PostSummary`.

### 7.5 Autocomplétion

| Méthode et chemin | Réponse |
|---|---|
| `GET /community/mentions/suggest?q=<1..60>&types=scholarship,country,institution,program&limit=8` | 200 `{ "items": [{ "type", "id", "label", "subtitle", "countryId" }] }` — `limit` ≤ 20 ; `types` facultatif (tous) ; seulement des entités **publiques** (bourses : `publicScholarshipWhere` ; pays, écoles, formations : `isActive`) ; `subtitle` = pays (bourse, école) ou école (formation), `null` pour un pays |
| `GET /community/hashtags/suggest?q=<0..40>&limit=10` | 200 `{ "items": [{ "tag", "display", "postCount" }] }` — par préfixe de la clé normalisée ; `q` vide = les plus utilisés ; `limit` ≤ 20 |

### 7.6 Publications

| Méthode et chemin | Corps | Réponse |
|---|---|---|
| `POST /community/posts` | `{ "type", "title", "body" }` | **201** `Post`. Si le filtre masque : 201 quand même, avec `moderation = { status: "pending_review", reason: "auto_filter" }`. L'auteur suit automatiquement sa publication. |
| `GET /community/posts/:id` | — | 200 `{ "post": Post, "replies": { "items": Reply[], "nextCursor" } }` (première page des réponses) |
| `GET /community/posts/:id/replies?cursor&limit` | — | 200 liste de `Reply` |
| `PATCH /community/posts/:id` | `{ "type"?, "title"?, "body"? }` (au moins un) | 200 `Post` ; 403 `community_not_author` / `community_edit_window_closed` |
| `DELETE /community/posts/:id` | — | **204** (statut `deleted` ; les réponses disparaissent avec ; les signalements ouverts sur la publication et ses réponses sont classés `dismissed`) |

### 7.7 Réponses

| Méthode et chemin | Corps | Réponse |
|---|---|---|
| `POST /community/posts/:id/replies` | `{ "body" }` | **201** `Reply` (filtre identique ; un répondant suit automatiquement la discussion) ; 409 `community_post_not_open` |
| `PATCH /community/replies/:id` | `{ "body" }` | 200 `Reply` |
| `DELETE /community/replies/:id` | — | **204** |

### 7.8 « Utile »

| Méthode et chemin | Réponse |
|---|---|
| `PUT /community/posts/:id/helpful` · `DELETE /community/posts/:id/helpful` | 200 `{ "helpfulCount", "hasMarkedHelpful" }` — idempotents |
| `PUT /community/replies/:id/helpful` · `DELETE /community/replies/:id/helpful` | idem |

Unique par personne et par contenu. 400 `community_cannot_react_own` sur son propre contenu.

### 7.9 Suivre une discussion

`PUT /community/posts/:id/follow` · `DELETE /community/posts/:id/follow` → 200 `{ "isFollowing" }`
(idempotents, sans charte, permis sous sanction).

### 7.10 Signaler

`POST /community/reports` — `{ "targetType": "post" | "reply" | "member", "targetId", "reason", "details"? }`
→ **201** `Report` ; un même membre qui re-signale la même cible reçoit **200** et le signalement
existant (pas de doublon). `targetId` = id de publication, de réponse, ou `memberId`. Signaler un
contenu de l'équipe est accepté (file admin) mais ne déclenche jamais de masquage automatique.

### 7.11 Bloquer

`POST /community/members/:memberId/block` → 200 `{ "isBlocked": true }` ;
`DELETE /community/members/:memberId/block` → 200 `{ "isBlocked": false }`. Idempotents.
Bloquer ne retire pas les suivis de discussion : les réponses de l'autre y sont filtrées et ne
notifient plus.

### 7.12 Profil public d'un membre

`GET /community/members/:memberId` → 200 `MemberProfile` ; 404 si inconnu ou si une relation
de blocage existe dans un sens ou dans l'autre — **sauf** pour le bloqueur, qui doit pouvoir
débloquer : il reçoit 200 avec `viewer.isBlocked = true`.

## 8. Routes admin

Toutes : `AdminAuthGuard` + `RolesGuard`, `Cache-Control: private, no-store`, **jamais coupées
par le drapeau**. Chaque écriture écrit un `AdminAuditEvent` (`purposeCode = community_moderation`,
`requestId` = en-tête `X-Request-Id` ou généré, renvoyé dans `X-Request-Id`) **et**, pour les actions
de modération, une ligne `ForumModerationAction` (journal lisible par l'équipe).

Rôles : **R** = Moderator, ContentManager, Admin, SuperAdmin (lecture, actions sur contenu,
réponse d'équipe, vérification, épinglage). **S** = Moderator, Admin, SuperAdmin (sanctions).
**C** = Admin, SuperAdmin (configuration du filtre). Le rôle **Counselor** (conseiller) a accès à
`GET /admin/community/posts`, `GET /admin/community/posts/:id` (lire les discussions) et
`POST /admin/community/posts/:id/replies` (répondre) — **jamais** à la file, aux membres, aux
sanctions, aux statistiques ni au filtre.

### 8.1 Modèles admin

`AdminAuthor` = `Author` + `{ "userId": string | null, "fullName": string | null, "email": string | null, "isMinor": boolean | null, "isNewAccount": boolean | null, "accountCreatedAt": ISO | null, "adminId": string | null }`.
**`fullName` et `email` ne sont renseignés que pour Admin et SuperAdmin** ; pour Moderator,
ContentManager et Counselor ils valent `null` (ils gardent nom public, pays, badges et les drapeaux).
`isMinor` d'après la date de naissance (`null` si inconnue) ; `isNewAccount` = compte de moins de
7 jours (§4.3) ; `null` pour un contenu de l'équipe.

Pour une réponse de l'« Assistant KPB », `adminId` = l'admin qui l'a publiée, ou
`"kpb-verif-bot"` pour une publication automatique (mode `auto`, §14).

`AdminPost` = `Post` (sans `viewer`, avec `author: AdminAuthor`) + `{ "status", "statusReason", "filterFlags": string[], "openReportCount", "deletedAt", "pinnedAt" }`.
`AdminReply` = `Reply` (idem) + `{ "status", "statusReason", "filterFlags", "openReportCount", "deletedAt" }`.

`status` : `"visible" | "pending_review" | "hidden" | "deleted"`.
`statusReason` : `ModerationReason` (§5.4) ou `"author_deleted"` / `"moderation_deleted"` pour `deleted`, `null` si visible.
`filterFlags` : sous-ensemble de `"phone" | "email" | "whatsapp" | "money_request" | "mobile_money" | "external_link" | "profanity" | "blocked_term" | "disposable_email"` (§9).

`AdminReport` = `Report` + `{ "details", "reporter": { "memberId", "displayName" } | null, "resolvedAt", "resolvedBy": string | null, "resolutionNote" }`.

`AdminMember` = `AdminAuthor` + `{ "charterVersion", "charterAcceptedAt", "restriction": Me.restriction, "stats": MemberProfile.stats, "sanctions": Sanction[], "openReportCount" }`.

`Sanction` = `{ "id", "kind": "warning" | "read_only" | "ban", "reason", "endsAt": ISO | null, "createdAt", "createdBy": { "adminId", "name" }, "revokedAt": ISO | null, "revokedBy": string | null, "active": boolean }`.

`ModerationLogEntry` = `{ "id", "action", "targetType": "post" | "reply" | "member", "targetId", "reason", "moderatorName", "moderatorRole", "createdAt", "postId": string | null }`.

Valeurs de `action` (journal `ForumModerationAction`, actions humaines seulement ; un client affiche
une valeur inconnue telle quelle) :

| `action` | Cible | Origine |
|---|---|---|
| `restore`, `hide`, `delete`, `dismiss_reports` | post / reply | §8.4 |
| `verify_answer`, `unverify_answer` | reply | §8.6 |
| `sanction_warning`, `sanction_read_only`, `sanction_ban` | member | §8.5 |
| `sanction_revoke` | member | §8.5 |
| `member_reports_dismissed` | member | §8.5 |

Les réponses et publications d'équipe, l'épinglage et le filtre ne vont **pas** dans ce journal
(ce ne sont pas des décisions de modération) ; ils sont tracés dans `AdminAuditEvent`
(`action` = `community.team_reply`, `community.team_post`, `community.pin`, `community.unpin`,
`community.filter_add`, `community.filter_delete`, et `community.<action du journal>` pour le reste).
Révision 2 (bot Vérif, `entityType = community_bot_draft`) : `community.bot_publish`,
`community.bot_auto_publish` (`actorAdminId = null`), `community.bot_reject`,
`community.bot_regenerate`. « Publier et marquer vérifiée » écrit en plus `verify_answer` au journal.

### 8.2 File de modération

`GET /admin/community/queue?kind=all|auto_hidden|reported|members&cursor&limit` — **R**.

- `auto_hidden` : contenus `pending_review` (filtre, e-mail jetable, seuil de signalements).
- `reported` : contenus (tous états sauf `deleted`) ayant au moins un signalement `open`.
- `members` : membres ayant au moins un signalement `open`.
- `all` : union, sans doublon.

Tri : **le plus ancien d'abord** (date du premier signalement ouvert, sinon du masquage) — l'équipe
s'engage à traiter sous **24 h** (*délai d'action exigé par les stores — À VALIDER*).

Réponse :

```json
{
  "counts": { "autoHidden": 3, "reported": 5, "members": 1 },
  "items": [
    {
      "key": "post:cp_…",
      "targetType": "post",
      "post": { "...": "AdminPost" },
      "reply": null,
      "member": null,
      "parentPost": null,
      "reports": [ { "...": "AdminReport" } ],
      "openReportCount": 2,
      "flaggedAt": "…",
      "waitingHours": 5
    }
  ],
  "nextCursor": null
}
```

Pour une réponse : `reply` renseigné et `parentPost` = `{ id, title, status }`. Pour un membre :
`member` = `AdminMember`. `reports` : les 10 plus récents ouverts.

### 8.3 Navigation et détail

| Méthode et chemin | Rôle | Réponse |
|---|---|---|
| `GET /admin/community/posts?status=&type=&q=&cursor&limit` | R + Counselor | liste d'`AdminPost` (tous états), récents d'abord |
| `GET /admin/community/posts/:id` | R + Counselor | `{ "post": AdminPost, "replies": AdminReply[] (tous états, ordre chronologique), "reports": AdminReport[], "log": ModerationLogEntry[] }` |
| `GET /admin/community/members/:memberId` | R | `AdminMember` + `{ "recentPosts": AdminPost[] (10), "recentReplies": AdminReply[] (10) }` |
| `GET /admin/community/moderation-log?cursor&limit` | R | liste de `ModerationLogEntry`, récents d'abord |
| `GET /admin/community/stats?days=30` | R | §8.7 |

### 8.4 Actions sur un contenu

`POST /admin/community/posts/:id/actions` · `POST /admin/community/replies/:id/actions` — **R**

```json
{ "action": "restore", "reason": "Faux positif : numéro de l'ambassade.", "notifyAuthor": true }
```

| `action` | Effet | Signalements ouverts |
|---|---|---|
| `restore` | → `visible` (depuis `pending_review` ou `hidden`) | clos `dismissed` |
| `hide` | → `hidden` | clos `actioned` |
| `delete` | → `deleted` (`statusReason = moderation_deleted`) | clos `actioned` |
| `dismiss_reports` | statut inchangé, sauf `pending_review` dû au seul seuil de signalements → `visible` | clos `dismissed` |

`notifyAuthor` (défaut `true`) : notification `community_moderation` (§11) pour `restore`,
`hide`, `delete`. Réponse : 200 `AdminPost` / `AdminReply`. 409 `community_invalid_transition`
pour rétablir un contenu supprimé par son auteur.

### 8.5 Sanctions

| Méthode et chemin | Rôle | Corps | Réponse |
|---|---|---|---|
| `POST /admin/community/members/:memberId/sanctions` | S | `{ "kind": "warning" \| "read_only" \| "ban", "reason", "durationDays"?: 1..365, "hideContent"?: boolean }` | 201 `Sanction` |
| `POST /admin/community/sanctions/:id/revoke` | S | `{ "reason" }` | 200 `Sanction` ; 409 `community_invalid_transition` si déjà levée |
| `GET /admin/community/sanctions?status=active\|all&cursor&limit` | R | — | 200 liste de `Sanction` + `{ "member": AdminAuthor }`, récentes d'abord ; `active` (défaut) = lecture seule / bannissement non levés et non échus |
| `POST /admin/community/members/:memberId/reports/dismiss` | S | `{ "reason" }` | 200 `{ "memberId", "dismissed": number }` — classe **sans suite** les signalements ouverts visant le membre, sans sanction |

`durationDays` **obligatoire** pour `read_only` (400 sinon), interdit pour les autres.
`hideContent` (bannissement seulement) : masque (`hidden`) tous les contenus visibles du membre.
Chaque sanction notifie le membre (`community_moderation`, motif inclus) et **clôt en `actioned`**
tous les signalements ouverts visant ce membre (pas ceux visant ses contenus, traités par §8.4).

### 8.6 Équipe KPB : réponses, vérification, épinglage, publications

| Méthode et chemin | Rôle | Corps | Réponse |
|---|---|---|---|
| `POST /admin/community/posts/:id/replies` | R + Counselor | `{ "body", "as": "kpb_team" \| "kpb_advisor", "verified"?: boolean }` | 201 `AdminReply` — jamais filtrée ; mentions et hashtags traités comme pour un membre ; notifie l'auteur et les abonnés |
| `PUT /admin/community/replies/:id/verified` | R | `{ "verified": boolean }` | 200 `AdminReply` — « Réponse vérifiée par KPB » (une par publication) ; poser notifie l'auteur de la publication et ses abonnés (`community_verified_answer`) |
| `PUT /admin/community/posts/:id/pin` | R | `{ "pinned": boolean }` | 200 `AdminPost` ; 409 `community_pin_limit` au-delà de 3 ; 409 `community_invalid_transition` pour épingler un contenu non visible |
| `POST /admin/community/posts` | R | `{ "type", "title", "body", "as": "kpb_team" \| "kpb_advisor", "pinned"?: boolean }` | 201 `AdminPost` (publication de l'équipe ; le bot « Vérif » a ses propres routes, §8.9) |

Une réponse « en tant que conseiller » affiche « Prénom I. » de l'admin connecté et le badge
`kpb_advisor` ; « Équipe KPB » affiche `"Équipe KPB"` et `kpb_team`. Seule une réponse
**visible** peut être vérifiée (409 `community_invalid_transition` sinon).

### 8.7 Statistiques

`GET /admin/community/stats?days=1..365` (défaut 30) — **R** :

```json
{
  "window": { "from": "…", "to": "…", "days": 30 },
  "posts": { "total": 120, "byType": { "question": 80, "experience": 25, "advice": 15 }, "byStatus": { "visible": 110, "pending_review": 4, "hidden": 3, "deleted": 3 } },
  "replies": { "total": 410, "byTeam": 38 },
  "helpfulReactions": 530,
  "reports": { "opened": 14, "open": 3, "resolved": 11, "medianResolutionHours": 6.5 },
  "autoHidden": 9,
  "autoHiddenMedianHandlingHours": 3.5,
  "unansweredQuestions": 12,
  "unansweredOver48h": 4,
  "verifiedAnswers": 21,
  "activeMembers": 85,
  "newMembers": 40,
  "activeSanctions": 2,
  "daily": [ { "date": "2026-10-17", "posts": 5, "replies": 17 } ]
}
```

Tout sur la fenêtre, sauf `reports.open`, `unansweredQuestions`, `unansweredOver48h` et
`activeSanctions` (instantané). `unansweredOver48h` = questions visibles sans réponse créées il y a
plus de 48 h. `autoHiddenMedianHandlingHours` = médiane, sur les décisions de la fenêtre
(`restore`, `hide`, `delete`), du délai entre la création d'un contenu masqué automatiquement et la
première décision humaine ; `null` sans donnée (comme `reports.medianResolutionHours`).
*Réglage des seuils et de la version de la charte depuis l'admin : non livré (constantes serveur,
`community.constants.ts`).*
`activeMembers` = membres ayant publié, répondu ou réagi dans la fenêtre. `daily` en jours UTC.

### 8.8 Configuration du filtre

| Méthode et chemin | Rôle | Corps | Réponse |
|---|---|---|---|
| `GET /admin/community/filters` | R | — | `{ "allowedDomains": { "builtin": string[], "catalogHostsCount": number, "custom": FilterEntry[] }, "blockedTerms": { "builtinCount": number, "custom": FilterEntry[] } }` |
| `POST /admin/community/filters` | C | `{ "kind": "allowed_domain" \| "blocked_term", "value" }` | 201 `FilterEntry` (doublon → 200 l'existant) |
| `DELETE /admin/community/filters/:id` | C | — | 204 |
| `POST /admin/community/filters/test` | R | `{ "text" }` (≤ 5 000) | 200 `{ "flags": string[], "wouldHide": boolean }` |

`FilterEntry` = `{ "id", "kind", "value", "createdAt", "createdBy": string | null }`. Domaine : hôte
nu (`univ-lyon1.fr`) ou suffixe (`*.univ-lyon1.fr`), en minuscules ; terme : 2 à 60 caractères,
comparé sans accents ni casse, en mot entier. La liste intégrée n'est pas modifiable (code).

### 8.9 Bot « Vérif » — file des brouillons (révision 2)

Rôle **R** (jamais le conseiller seul). Comportement du bot : §14.

`BotDraft` :

```json
{
  "id": "cbd_…",
  "postId": "cp_…",
  "status": "proposed",
  "statusReason": null,
  "lang": "fr",
  "intents": ["status", "deadline"],
  "entities": [{ "type": "scholarship", "id": "clx…", "label": "Bourse Eiffel", "resolvedBy": "mention" }],
  "facts": { "version": 1, "checkedAt": "…", "entities": [ { "kind": "scholarship", "…": "…" } ], "usVisa": null },
  "sources": [{ "type": "scholarship", "id": "clx…", "label": "Bourse Eiffel", "url": "https://www.campusfrance.org/…", "verifiedAt": "…", "stale": false }],
  "factsHash": "…",
  "proposedText": "Bonjour ! Voici ce que disent les données vérifiées de KPB.\n\n…",
  "writer": "template",
  "llmFallbackReason": null,
  "confidence": "high",
  "complete": true,
  "scamCaution": false,
  "createdAt": "…", "generatedAt": "…", "processedAt": null,
  "processedBy": null,
  "rejectReason": null,
  "publishedReplyId": null, "publishedVerified": false, "autoPublished": false,
  "post": { "id": "cp_…", "title": "…", "type": "question", "status": "visible", "createdAt": "…" }
}
```

| Champ | Sens |
|---|---|
| `status` | `queued` (en file) · `skipped` (pas de brouillon, `statusReason` dit pourquoi) · `proposed` · `published` · `rejected` · `obsolete` — valeur inconnue : l'afficher brute |
| `statusReason` | `skipped` : `not_question` \| `no_intent` \| `no_entity` \| `ambiguous_entity` \| `entity_not_public` \| `team_post` \| `error` ; `obsolete` : `post_not_visible` \| `facts_changed` |
| `intents` | motifs repérés : `status`, `deadline`, `truth`, `scam`, `fees`, `partner`, `exists`, `documents`, `intake`, `visa` |
| `facts` | faits extraits du catalogue (§14.2), avec leur source ; `null` hors `proposed` / `published` / `obsolete` |
| `sources` | une ligne par fiche citée : lien officiel (cliquable dans la console), date de vérification, `stale` (> seuil) |
| `writer` | `template` (modèle déterministe) \| `llm` (reformulation acceptée par le contrôle) ; `llmFallbackReason` dit pourquoi le LLM a été écarté |
| `confidence` / `complete` | §14.3 |
| `post` | présent dans la liste seulement |

| Méthode et chemin | Corps | Réponse |
|---|---|---|
| `GET /admin/community/bot/drafts?status=proposed\|published\|rejected\|obsolete\|skipped\|queued\|all&cursor&limit` | — | 200 `{ "mode", "items": BotDraft[], "nextCursor" }` — défaut `proposed`, récents d'abord ; marque d'abord `obsolete` les brouillons dont la publication n'est plus visible |
| `GET /admin/community/bot/drafts/:id` | — | 200 `{ "mode", "draft": BotDraft, "post": AdminPost, "live": { "postVisible", "factsChanged" } }` — `live` re-vérifie les faits à l'instant (indicateur « obsolète » avant publication) |
| `POST /admin/community/bot/drafts/:id/publish` | `{ "text"?: string, "verified"?: boolean }` | 200 `{ "draft": BotDraft, "reply": AdminReply }` — `text` : texte modifié par l'admin (2 à 3 000, mentions validées), sinon le texte proposé ; `verified` : « Réponse vérifiée par KPB ». Faits **re-vérifiés** : changés ou publication plus visible ⇒ 409 `community_bot_draft_obsolete`. Hors `proposed` ⇒ 409 `community_invalid_transition` |
| `POST /admin/community/bot/drafts/:id/reject` | `{ "reason" }` (3 à 500) | 200 `BotDraft` (`rejected`) — depuis `proposed` ou `obsolete` |
| `POST /admin/community/bot/drafts/:id/regenerate` | — | 200 `BotDraft` — refait détection, faits et texte (jamais publié seul) ; interdit sur `published` (409) |
| `GET /admin/community/bot/stats?days=1..365` | — | 200 `{ "mode", "llmEnabled", "window", "current": { queued, skipped, proposed, published, rejected, obsolete }, "created": {… sur la fenêtre}, "autoPublished", "publishedVerified", "llmWritten", "medianHandlingHours" }` — délai humain médian brouillon prêt → décision |

La réponse publiée : `authorKind = kpb_assistant`, jamais filtrée, notifie l'auteur et les abonnés
comme une réponse d'équipe (`community_reply`, et `community_verified_answer` si vérifiée).

### 8.10 Bot « Passerelle » — console (révision 3)

Rôle **R** (jamais le conseiller seul), **lecture seule** : le bot n'écrit rien de public, il
n'attend donc aucune validation. Comportement : §15.

| Méthode et chemin | Réponse |
|---|---|
| `GET /admin/community/assist-bridge/stats?days=1..365` | 200 `{ "mode": "off" \| "shadow" \| "on", "coachSource": bool, "rulesVersion": "ab-1", "window", "totals": Counts, "bySource": { community_post, community_reply, coach_message }, "needs": [{ "needId", "label": { fr, en }, …Counts }] }` — `Counts` = `{ detected, pending, sent, wouldSend, skipped: { <motif>: n }, openedFeature, openedWhatsapp, dismissed }` sur les événements **créés** dans la fenêtre ; `wouldSend` = envois simulés en `shadow` |
| `GET /admin/community/assist-bridge/events?status=all\|detected\|sent\|skipped\|opened_feature\|opened_whatsapp\|dismissed&needId&source&cursor&limit` | 200 `{ "mode", "items": AssistEvent[], "nextCursor" }` — récents d'abord |
| `GET /admin/community/assist-bridge/catalog` | 200 `{ "mode", "coachSource", "version", "minWords", "needs": [{ "id", "label", "feature", "featureLabel", "route", "rules": [{ "id", "selfAsking" }], "title": { fr, en }, "body": { fr, en } }] }` |

`AssistEvent` : `{ id, source, needId, ruleId, ruleVersion, status, statusReason, mode, pushOutcome,
createdAt, processedAt, sentAt, openedFeatureAt, openedWhatsappAt, dismissedAt, excerpt, postId }`.
**Aucune identité d'élève.** `excerpt` (≤ 120 caractères) et `postId` : seulement pour une
publication ou une réponse de la communauté **visible au moment de la lecture** (relue à la volée,
jamais stockée) ; **toujours `null` pour la source coach**.

## 9. Modération et anti-arnaque

### 9.1 Filtre avant publication

Appliqué à toute création et modification **par un membre** (titre + corps). Un seul drapeau
suffit : le contenu naît `pending_review` (`statusReason = auto_filter`), visible de son seul
auteur, et entre dans la file admin. Rien n'est refusé : le message n'est jamais perdu, il
attend la revue.

| Drapeau | Détecte (FR / EN) | Faux positifs évités (testés) |
|---|---|---|
| `phone` | ≥ 8 chiffres en une suite (espaces, points, tirets, parenthèses tolérés), `+` international | montants suivis ou précédés d'une devise (`15 000 000 FCFA`, `1 181 €`), années et plages d'années (`2026-2027`), dates (`15/01/2027`) |
| `email` | adresse e-mail | — |
| `whatsapp` | `wa.me/`, `chat.whatsapp.com`, `t.me/`, ou WhatsApp / Telegram / Signal + invitation (« écris-moi », « ajoute-moi », « contacte-moi », « inbox », « DM », « add me », « text me », « message me ») | « le groupe WhatsApp officiel de Campus France » (sans invitation) |
| `money_request` | « frais d'agent », « paie(z)-moi », « envoie(z) l'argent », Western Union, MoneyGram, Ria, « garantie de bourse / visa / admission », « 100 % garanti », crypto, cartes cadeaux ; *send me money, agent fee, processing fee to me, guaranteed visa*… | « les frais de dossier Campus France sont de 50 000 FCFA », « j'ai payé les frais de visa à l'ambassade » |
| `mobile_money` | Orange Money, MTN / Moov / Airtel Money, MoMo, Flooz, T-Money, Free Money, M-Pesa, Wave **en contexte de paiement** (« par Wave », « sur Wave », « via Wave ») | « a new wave of applications » |
| `external_link` | URL (`http(s)://`, `www.`, ou domaine nu courant) dont l'hôte n'est pas sur la liste blanche | liens de la liste blanche |
| `profanity` | insultes de base FR / EN (mot entier, sans accents ni casse) | sous-chaînes (« Scunthorpe », « dickens » ne déclenchent rien) |
| `blocked_term` | termes ajoutés par l'équipe (§8.8) | — |
| `disposable_email` | compte inscrit avec une adresse jetable (`referrals/campaigns/disposable-email-domains.ts`) → `statusReason = new_account_review` | — |

Le contenu de l'équipe (routes admin) n'est jamais filtré.

### 9.2 Liste blanche des liens

Union de : liste intégrée (domaines officiels : `campusfrance.org`, `*.gouv.fr`,
`service-public.fr`, `parcoursup.fr`, `canada.ca`, `*.gc.ca`, `*.gouv.qc.ca`, `quebec.ca`,
`gov.uk`, `*.gov.uk`, `*.gov`, `*.edu`, `*.ac.uk`, `daad.de`, `*.daad.de`, `chevening.org`,
`*.europa.eu`, `studyinjapan.go.jp`, `mext.go.jp`, `fulbrightonline.org`, `kpbeducation.cloud`…),
**hôtes des liens officiels du catalogue** (sites des écoles, pages sources et de candidature des
bourses, rechargés toutes les 10 min) et ajouts de l'équipe (§8.8). Un sous-domaine `www.` est
toujours accepté.

### 9.3 Signalements et masquage provisoire

À **3 signalements ouverts de membres distincts**, un contenu `visible` d'un membre passe
`pending_review` (`statusReason = reports_threshold`) jusqu'à la décision de l'équipe. Un
signalement de membre (`targetType = member`) ne masque rien : il entre dans la file `members`.

### 9.4 Charte

Quatre règles courtes, versionnées (`2026-10-v1`), servies par `GET /community/me` dans la
langue demandée. Acceptation horodatée et historisée (une ligne par version acceptée). Une
nouvelle version rend `charter.required = true` : l'app ré-affiche la charte avant la prochaine
écriture.

## 10. Fil « Pour toi »

Candidats : publications `visible`, créées il y a moins de **60 jours**, hors publications du
lecteur, hors blocages, avec les filtres `type` / `hashtag`. Score calculé **en SQL** à
l'horloge `asOf` (figée dans le curseur) :

```
âge_h      = max(0, (asOf − createdAt) en heures)
affinité   = 4 × [mentionne une bourse que je suis (favori ou alerte)]
           + 2 × [mentionne une entité d'un de mes pays visés (UserProfile.targetCountryIds)]
           + 1 × [mentionne une bourse ouverte à mon niveau visé (scholarshipTargetLevel)]
           + 1 × [je suis la discussion]
engagement = ln(1 + replyCount + 2 × helpfulCount)
vérifiée   = 2 × [hasVerifiedAnswer]
score      = (1 + affinité + engagement + vérifiée) / (âge_h + 2) ^ 1.2
```

Tri : `score` décroissant, puis `id` décroissant (départage déterministe). `forYouReasons`
(dans cet ordre, seulement ceux qui s'appliquent) : `followed_scholarship`, `target_country`,
`target_level`, `followed_discussion`, `verified_answer`, `popular` (engagement ≥ ln 6, soit
au moins 5 interactions pondérées). Une publication sans aucune raison reste proposée (récence).
Un élève sans suivi ni profil obtient donc un fil « récents pondérés par l'engagement ».

Index : `CommunityPost(status, createdAt DESC, id)`, `CommunityMention(entityType, entityId)`,
`CommunityMention(countryId)`, `CommunityFollow(memberId, postId)` unique.

## 11. Notifications

Écrites dans le fil in-app existant (`UserNotification`, lu par `GET /me/notifications`) et
poussées par le chemin existant (`NotificationDispatchService` : heures calmes, plafond
quotidien). `route` = `/community/posts/<postId>` (ou `/community` pour une sanction ou une suppression par l'équipe) ; `data` =
`{ "postId"?, "replyId"?, "count"?, "event"? }`, **toutes des chaînes** (charge push) — `count` = nombre
de réponses regroupées, `event` (modération) ∈ `hidden | restored | deleted | warning | read_only | ban`.

| `kind` | Destinataire | Déclencheur | Regroupement |
|---|---|---|---|
| `community_reply` | auteur de la publication | réponse visible d'un autre (membre ou équipe) | une ligne non lue par publication et destinataire sur 24 h : les réponses suivantes mettent à jour le texte (« 3 nouvelles réponses ») **sans nouveau push** |
| `community_followed_reply` | abonnés de la discussion (hors auteur de la publication et auteur de la réponse) | idem | idem |
| `community_verified_answer` | auteur + abonnés | réponse marquée vérifiée | une seule fois par réponse |
| `community_moderation` | auteur du contenu / membre sanctionné | masquage, rétablissement, suppression par l'équipe ; sanction (avertissement, lecture seule, bannissement) | aucun (événement rare) |
| `assist_bridge` (révision 3, §15) | l'élève qui a écrit le besoin, **lui seul** | besoin repéré dans sa publication, sa réponse ou (source ouverte) son message au coach | aucun ; garde-fous du §15.3 |

**Désinscription** : nouvelle clé `community` dans `disabledNotificationTypes`
(`src/common/notification-types.ts`). Elle coupe le **push** de `community_reply`,
`community_followed_reply` et `community_verified_answer` ; la ligne du fil est quand même
écrite (même sémantique que `followed_scholarship_updates`). `community_moderation` n'est pas
coupée (elle concerne le compte). Aucune notification causée par un membre bloqué (dans un sens
ou l'autre), ni pour un contenu non visible. **Aucune mention d'utilisateur** n'existe, donc
aucune notification de mention.

**Révision 3** : clé `assist_bridge` dans `disabledNotificationTypes` — elle coupe **tout** de la
passerelle (ni ligne du fil, ni push : la suggestion n'est pas écrite) ; indépendante de
`community`.

## 12. RGPD

- **Suppression du compte** (`DELETE /profiles/me`) : **suppression définitive**, pas
  d'anonymisation. La fiche membre part avec le profil, et avec elle (cascade) : publications
  — y compris les réponses des autres sous ces publications —, réponses, « utile », mentions,
  suivis, blocages (dans les deux sens), acceptations de charte, sanctions. Les signalements
  **visant** ses contenus ou son profil sont supprimés ; ceux qu'il a **rédigés** perdent leur
  auteur (`reporterMemberId → NULL`) et restent dans la file. Les compteurs des publications
  d'autrui touchées sont recalculés. Le journal de modération garde l'action (sans contenu) mais
  perd le lien vers le membre. *Choix motivé : un contenu de forum est souvent un récit personnel
  (dossier, pays, notes) d'un public jeune ; l'effacement total est la direction d'erreur sûre.
  Conséquence acceptée : un fil perd les réponses publiées sous la question d'un compte supprimé.*
- **Suppression d'un contenu par son auteur** : statut `deleted` immédiat (invisible), contenu
  gardé **30 jours** pour la modération (preuve en cas d'arnaque), puis **purge définitive**
  (tâche quotidienne).
- **Export** (`GET /profiles/me/export`) : clé `community` = `{ member, charterAcceptances,
  posts, replies, helpfulReactions, follows, blocks, reportsFiled, sanctions }` — ses contenus
  (tous états, texte complet), ses réactions et suivis (ids), ses blocages (id public du membre
  bloqué), ses signalements (motif, détail, statut), ses sanctions (motif, dates). Les
  signalements **visant** l'élève ne lui sont pas rendus (protection des signaleurs).
- Inventaire : `docs/data-inventory.md` §7 (et §7 bis pour le bot Vérif : le brouillon ne recopie
  aucune donnée de l'élève ; il part avec la publication, en cascade ; §7 ter pour le bot
  Passerelle).
- **Bot « Passerelle »** (révision 3) : `AssistBridgeEvent` (besoin, règle, version, source = type
  + id, statut, dates ; **aucun texte**) part avec le compte (cascade) et est purgé à **12 mois**
  (À VALIDER) ; l'export porte la clé `assistBridgeEvents` (sans `userId`).

## 13. Ce qui ne change pas

- `ForumCategory` / `ForumTopicTag` (taxonomie de l'ancien écran communauté, jamais livré) :
  **non utilisés** par la nouvelle communauté — les espaces automatiques par entité, les trois
  types et les hashtags les remplacent. Tables et routes (`GET /community/forum-*` sous
  `MvpGuard`, `/admin/forum-categories`, `/admin/forum-tags`) gardées telles quelles pour les
  builds installées ; **dépréciées**, à retirer dans un chantier ultérieur.
- `ForumModerationAction` est **réutilisée et étendue** (colonnes nullables `postId`, `replyId`,
  `memberId`, `adminId`, `reportId`) comme journal de modération de la nouvelle communauté ;
  `GET /admin/forum-moderation` (ancienne file en lecture) continue de la lire.
- L'écran communauté actuel de l'app reste masqué par `KPB_MVP_ONLY` ; la nouvelle communauté
  dépend du **drapeau distant** `features.community`.

## 14. Bot « Vérif » (révision 2)

Décision du propriétaire : **validation humaine d'abord** — le bot prépare depuis les données
vérifiées du catalogue, un admin publie en un clic ; l'automatique viendra plus tard par réglage.
Exploitation : `docs/runbook-bot-verif.md`.

### 14.1 Détection

Asynchrone : la publication d'une **question visible d'un membre** (création, modification,
rétablissement) écrit une ligne `queued` (au plus un brouillon par publication, `postId` unique) ;
une tâche à la minute fait le travail. Jamais bloquant pour la publication ; jamais sur un contenu
masqué ou en attente de revue, ni sur une publication de l'équipe ; les réponses ne sont pas
analysées (une réponse du bot par publication). Une question de **vérification** = type
`question` + au moins un motif FR/EN (« ouvert », « date limite », « deadline », « c'est vrai »,
« arnaque », « frais », « gratuit », « partenaire », « existe », « documents », « rentrée »,
« visa »…) + au moins une **entité** : mentionnée, sinon retrouvée en toutes lettres avec un seuil
strict (nom complet en mots entiers, sigle exact, cœur d'un nom de bourse ≥ 5 lettres quand le
texte parle de bourse ; un seul candidat par famille — sinon `ambiguous_entity`, pas de brouillon).
Langue de la réponse : celle de la question (FR par défaut).

### 14.2 Faits

Extraits **déterministiquement** des fiches publiques, sans rien inventer : bourse — statut servi
(mêmes règles que l'app : jamais « ouverte » avant `opensAt`, « fermée » sur une clôture confirmée
seulement, date estimée au mois près), lien officiel, financement, documents, `lastVerifiedAt`,
source (celle du cycle d'abord) ; école — partenaire ou non, rentrées à venir (dates passées
masquées, reconduction « à confirmer »), frais publiés, site ; formation — école et partenariat,
rentrées, date limite, frais de scolarité et de candidature, pièces ; pays — prochaine rentrée ;
avis visa USA (`usVisaSuspension`, même source que `/config/app`) pour une entité des États-Unis.
Une fiche vérifiée il y a plus de **30 jours** (bourse) ou **180 jours** (école, formation, pays)
est dite « à revérifier » ; une donnée absente est dite « non renseignée ».

### 14.3 Rédaction, confiance, modes

Modèle déterministe (tutoiement, niveau B1, aucune promesse, aucun pourcentage) + pied fixe :
« Fiche @… : vérifié le JJ/MM/AAAA, source : … », phrase de prudence standard si la question parle
d'argent ou d'arnaque, rappel de confirmer sur le site officiel. Option LLM
(`KPB_COMMUNITY_VERIF_BOT_LLM=true`) : seul le corps est reformulé, à partir du texte
déterministe (jamais la question de l'élève) ; un chiffre, un mois, un lien ou une mention absents
du modèle, un « % » ou une promesse ⇒ repli sur le modèle (`llmFallbackReason`).

`complete` = tous les motifs ont un fait renseigné ET aucune fiche n'est périmée.
`confidence` : `high` = entités toutes mentionnées et `complete` ; `low` = aucun motif de fond
renseigné, ou fiches toutes périmées ; `medium` sinon.

`KPB_COMMUNITY_VERIF_BOT_MODE` : `review` (**défaut**) — tout attend un admin ; `auto` — publie seul
un brouillon `high` + `complete` (jamais « vérifiée » : c'est un geste humain), le reste attend un
admin ; `off` — aucune détection. Toute autre valeur vaut `review`.

## 15. Bot « Passerelle » (révision 3)

Demande du propriétaire : « quand un étudiant dit qu'il veut ci, qu'il cherche ça, le bot repère ça
et lui envoie un message : "Déjà dans l'application, tu peux faire ça comme ça. Et si tu as besoin
d'une aide supplémentaire, contacte-nous sur WhatsApp." » Code : `backend/src/modules/assist-bridge/`.
Exploitation : `docs/runbook-bot-passerelle.md`.

### 15.1 Sources (toujours un texte écrit par l'élève lui-même)

- **Communauté** : une publication ou une réponse **visible** d'un membre, à sa création (et à son
  rétablissement par l'équipe) — après le filtre de contenu ; jamais un contenu masqué, en revue ou
  supprimé ; jamais un contenu de l'équipe ; le besoin est attribué à l'**auteur** du texte, jamais
  à l'auteur de la publication sous laquelle il répond.
- **Coach IA** (`CoachMessage`, rôle `user`) : donnée **privée**, derrière
  `KPB_ASSIST_BRIDGE_COACH` (**fermé par défaut**, à ouvrir après mise à jour de la politique de
  confidentialité — À VALIDER). Le texte sert à la détection en mémoire puis est oublié : seuls le
  besoin, la règle et l'id du message sont écrits.

Asynchrone : la détection (expressions régulières sur le texte déjà en mémoire) écrit au plus **une**
ligne `AssistBridgeEvent` par texte (`source` + `sourceId` uniques — un même message ne déclenche
jamais deux fois) ; une tâche à la minute applique les garde-fous et envoie. Jamais bloquant pour la
publication ni pour le coach ; une erreur du bot n'empêche rien.

### 15.2 Détection et catalogue (`assist-bridge.rules.ts`, version `ab-1`)

Déterministe, sans LLM : texte normalisé sans accents (`normalizeSearchText`), mots entiers. Rien
si moins de **4 mots**, si une **négation simple** est présente (« je ne cherche pas », « pas
besoin », « don't need »…), ou si l'élève dit l'avoir **déjà fait** (« j'ai déjà… », « déjà
relu », « already… »). Une règle « qui ne demande pas d'elle-même » exige en plus un signe de
demande (« je cherche », « besoin », « comment », « aide », « perdu », « quel… », « help »,
« how »…) ou un « ? ». Ordre = priorité (un besoin par texte).

| Besoin (`needId`) | Repéré par (exemples) | Fonction cible (`feature`) | `route` (vérifiée dans `app_routes.dart`) |
|---|---|---|---|
| `document_review` | « relire / corriger / améliorer mon CV, ma lettre de motivation », « comment rédiger ma lettre » | Relecture de document IA (`POST /document-review`, `DocumentReviewScreen`, tiroir des outils) | `/document-review` : **pas de route nommée** — l'app l'ouvre par la clé ; une build ancienne retombe sur l'accueil |
| `scholarship_match` | « quelle bourse pour moi ? », « je cherche une bourse », « which scholarships » | « Mes 10 bourses » (exige `KPB_SCHOLARSHIP_MATCH_ENABLED`) | `/scholarship-match` |
| `etudes_en_france` | « Campus France », « Études en France », « study in France » + demande | Espace « Études en France » (exige `eefSpace` : `KPB_EEF_ENABLED` ou `KPB_EEF_SPACE_ENABLED`) | `/etudes-en-france` |
| `accompaniment` | « être accompagné », « un conseiller », « monter mon dossier de candidature » | Ouvrir un dossier (cases) | `/new-case` |
| `visa` | « visa » + demande | Services → offre `visa_kit` (exige une offre `visa_kit` active) | `/services` |
| `school_choice` | « quelle école / formation / filière ? », « choisir une université » | Test d'orientation | `/orientation` |

Hors catalogue, faute de fonction à ouvrir : la disponibilité des rendez-vous visa
(`GET /visa-availability`, aucun écran) et l'avis visa USA (affiché seulement dans les fiches
États-Unis, sans route propre).

### 15.3 Garde-fous (dans cet ordre)

`not_student` (compte non élève) · `opt_out` (clé `assist_bridge`) · `sanctioned` (lecture seule ou
bannissement en cours dans la communauté) · `coach_source_off` (source coach refermée depuis la
détection) · `source_not_visible` (texte supprimé, masqué, en revue, ou plus de cet élève) ·
`feature_unavailable` (fonction coupée par son drapeau, offre visa absente) · `feature_used`
(fonction déjà utilisée : quota de relecture consommé < 14 j, run « Mes 10 bourses » < 14 j,
dossier en cours ou rendez-vous à venir, test d'orientation < 14 j, achat visa en cours) ·
`need_cooldown` (même besoin envoyé < **30 jours**) · `user_cap` (une notification passerelle
envoyée < **72 h**) · `shadow` (mode `shadow` : tout est appliqué, rien n'est envoyé) · `expired`
(plus de 48 h sans pouvoir envoyer) · `error` (3 échecs techniques). **Heures calmes** (fenêtre des
push, 21 h → 8 h locale) : l'événement attend (`notBefore`), il n'est jamais envoyé la nuit. Jamais
de réponse publique dans la communauté.

### 15.4 Notification et charge

`UserNotification` `kind = assist_bridge`, `dedupeKey = assist_bridge:<eventId>`, poussée par
`NotificationDispatchService` (plafond quotidien commun). Titre et texte FR/EN tutoyés, sans
promesse, finissent par « Besoin d'aide en plus ? Écris-nous sur WhatsApp. ». `route` = route de
la fonction (repli des builds anciennes, qui ne connaissent pas ce `kind` : elles suivent la route,
ou retombent sur l'accueil). `data` (chaînes) = `{ needId, feature, eventId, whatsapp: "kpb",
sender: "kpb_assistant", ruleVersion }`. **Aucun numéro** dans la charge : `whatsapp: "kpb"` dit à
l'app d'ouvrir la ligne KPB de sa configuration (`AppConfig.whatsappNumber`, la même que la bulle
« Études en France »). Expéditeur affiché : « Assistant KPB » (badge du bot Vérif), au nom de
l'équipe — jamais le mot « bot ».

L'app (build qui connaît ce `kind`) ouvre une feuille « Tu peux le faire directement dans l'app » :
bouton vers la fonction, bouton WhatsApp, « Plus tard ». Chaque geste est mesuré :

| Méthode et chemin | Corps | Réponse |
|---|---|---|
| `POST /me/assist-bridge/events/:id` (élève) | `{ "action": "opened_feature" \| "opened_whatsapp" \| "dismissed" }` | 200 `{ "id", "status" }` — idempotent (première date gardée, statut = dernière action) ; 404 `assist_bridge_event_not_found` si l'événement n'est pas le sien ou n'a pas été envoyé |

### 15.5 Modes

`KPB_ASSIST_BRIDGE_MODE` : `shadow` (**défaut**) — détecte, applique les garde-fous et journalise,
**n'envoie rien** ; `on` — envoie ; `off` — aucune détection, aucun traitement (les événements restent
lisibles). Toute autre valeur vaut `shadow`. `/config/app` → `features.assistBridge` = vrai en mode
`on` seulement (l'app n'affiche l'interrupteur « Suggestions de l'équipe KPB » qu'alors).

