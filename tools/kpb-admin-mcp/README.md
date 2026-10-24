# KPB Admin MCP

Serveur MCP (stdio) qui expose l'API admin de KPB Education à l'agent
notifications (`.claude/agents/kpb-notifications.md`) : contenu publié,
détection des nouveautés, campagnes push et leurs statistiques.

L'envoi passe par les **campagnes du backend** (`/admin/notifications`) : chaque
élève a sa trace de livraison, reçoit le texte dans sa langue, et la campagne
apparaît dans l'admin. Le backend livre par FCM (OneSignal seulement pour les
versions de l'app antérieures à FCM). Les taux d'ouverture sont dans
`kpb_campaign_stats` (`opened`, `openRate`) : l'app signale chaque tap.

## Installation

```bash
cd tools/kpb-admin-mcp
npm install
cp .env.example .env   # puis renseigner le mot de passe
```

Créer d'abord, dans l'admin (page Users), un **compte dédié à l'agent** :
rôle `ContentManager` pour le contenu et les campagnes, ou `Admin` si l'agent
doit aussi pouvoir envoyer un push de test à un seul compte.

## Enregistrement dans Claude Code

Installer une copie hors du dépôt (un worktree peut disparaître), comme
`kpb-mautic` :

```bash
mkdir -p ~/.claude/mcp/kpb-admin
cp tools/kpb-admin-mcp/{index.mjs,package.json,package-lock.json,.env.example} ~/.claude/mcp/kpb-admin/
cd ~/.claude/mcp/kpb-admin && npm install && cp .env.example .env && chmod 600 .env
claude mcp add kpb-admin --scope user -- node ~/.claude/mcp/kpb-admin/index.mjs
```

Après une mise à jour de `index.mjs` dans le dépôt, recopier le fichier.

Ne mets **jamais** `mcp__kpb-admin__kpb_send_notification` dans la liste
d'autorisation : la demande de permission de Claude Code sert de second verrou,
en plus de la phrase de confirmation exigée par l'outil.

## Outils

| Outil | Rôle | Écrit ? |
|---|---|---|
| `kpb_session` | Vérifie la connexion admin | non |
| `kpb_dashboard` | Compteurs globaux | non |
| `kpb_list_scholarships` | Bourses par statut de modération | non |
| `kpb_list_institutions` | Établissements du catalogue | non |
| `kpb_list_parcours` / `kpb_list_articles` / `kpb_youtube_playlist` | Contenu éditorial | non |
| `kpb_whats_new` | Ce qui est apparu depuis le dernier passage | état local |
| `kpb_announcement_history` | Annonces faites par l'agent, plafond sur 7 jours | non |
| `kpb_list_campaigns` / `kpb_campaign_stats` | Campagnes et livraisons | non |
| `kpb_preview_audience` | Nombre de destinataires, sans envoi | non |
| `kpb_draft_notification` | Brouillon + contrôles + aperçu | état local |
| `kpb_send_test_push` | Push de test vers un seul compte | push unitaire |
| `kpb_send_notification` | **Envoi réel** (modèle + campagne) | **oui** |

## Garde-fous appliqués par le MCP

- Envoi en deux étapes : brouillon, puis `confirmation: "ENVOYER <draftId>"`. L'agent
  `kpb-notifications` (sous-agent) ne fait que le brouillon : c'est la session principale qui
  envoie, après le feu vert écrit de l'humain.
  Un brouillon expire au bout de 24 h.
- Route au tap vérifiée contre les routes que l'app sait ouvrir (miroir de
  `AppRoutes.normalizeExternalRoute`). Une route inconnue dépose l'élève sur
  l'accueil, sans erreur visible : le MCP la refuse avant l'envoi.
- 3 diffusions par 7 jours glissants au plus (`KPB_AGENT_MAX_BROADCASTS_7D`).
- Aucun envoi entre 20 h et 8 h UTC (`KPB_AGENT_QUIET_START_UTC` / `_END_UTC`) ;
  il faut alors programmer l'envoi avec `scheduledFor`.
- Un contenu déjà annoncé est refusé.
- Audience vide ou filtre manquant : refusé.
- **Finalité obligatoire** (`purpose`, sans défaut) : `informational` (message de
  service — politique, compte, maintenance — envoyé à toute l'audience) ou
  `promotional` (offre, nouvelle bourse, mise en avant — seulement aux comptes
  ayant accepté « Nouvelles et offres de KPB »). Une annonce de contenu
  (`reason` autre que `other`) ne peut pas partir en `informational`. Le
  récapitulatif affiche `reachable` : les comptes réellement joignables après
  le filtre de consentement ; 0 joignable est refusé.

État local (nouveautés vues, annonces, brouillons) :
`~/.kpb-agent/state.json` (`KPB_AGENT_STATE_DIR`). Au premier appel,
`kpb_whats_new` enregistre une base de référence : l'existant n'est pas
annoncé comme nouveau.

## Dépendance backend

`route` sur les campagnes et `POST /admin/notifications/campaigns/preview`
arrivent avec la migration `20260922120000_notification_campaign_route`. Tant
qu'elle n'est pas déployée, `kpb_draft_notification` échoue sur l'aperçu
d'audience.
