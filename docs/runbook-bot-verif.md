# Runbook — bot « Vérif » de la communauté (C3)

Le bot repère, dans la communauté, les **questions de vérification** sur une ressource du
catalogue (« cette bourse est-elle ouverte ? », « date limite ? », « c'est vrai que… ? », « cette
école est partenaire ? », « quels documents ? »), extrait les **faits vérifiés** du catalogue et
prépare une réponse signée **« Assistant KPB »**. Décision du propriétaire : **validation humaine
d'abord** — un admin relit et publie en un clic.

Contrat : `docs/community-api-contract.md` §8.9 (routes) et §14 (comportement). Code :
`backend/src/modules/community/community-verif-bot*.ts`. Console : Communauté → onglet **Bot Vérif**.

## 1. Les modes

| `KPB_COMMUNITY_VERIF_BOT_MODE` | Effet |
|---|---|
| `review` (**défaut**) | Le bot prépare ; rien n'est publié sans un admin. |
| `auto` | Publie **seul** un brouillon de confiance **haute** (entités mentionnées par l'élève) dont les faits demandés sont **tous renseignés et frais** ; jamais « Réponse vérifiée » (geste humain). Le reste attend un admin comme en `review`. |
| `off` | Aucune détection, aucun brouillon. La file reste lisible et les brouillons existants publiables. |

Toute autre valeur (faute de frappe) vaut `review`. `KPB_COMMUNITY_VERIF_BOT_LLM=true` allume la
reformulation par le LLM existant (clé `LLM_API_KEY`) ; défaut `false`. Le LLM ne reçoit **que** le
texte déterministe bâti sur les faits — jamais la question de l'élève — et toute sortie qui ajoute
un chiffre, un mois, un lien, une mention, un « % » ou une promesse retombe sur le modèle.

Le bot ne travaille que si la communauté reçoit des publications (`KPB_COMMUNITY_ENABLED=true`).

## 2. Changer de mode (sans build)

Sur le VPS, dans le `.env` lu par `docker-compose.yml` :

```bash
KPB_COMMUNITY_VERIF_BOT_MODE=auto     # ou review / off
docker compose up -d api              # recrée le conteneur avec la nouvelle valeur
```

La console affiche le mode en tête de l'onglet Bot Vérif (`GET /admin/community/bot/stats` →
`mode`). Retour arrière : remettre `review` et recréer le conteneur ; les réponses déjà publiées
restent (les masquer ou supprimer depuis Contenus si besoin, avec motif).

### Avant de passer en `auto` (À VALIDER par le propriétaire)

1. Au moins **4 semaines** en `review` avec la file traitée sous 24 h.
2. Sur les 30 derniers jours (`GET /admin/community/bot/stats?days=30`) : taux de rejet des
   brouillons `high` + `complete` **< 5 %**, et aucun rejet pour « fait faux ».
3. Catalogue frais : la plupart des bourses citées vérifiées depuis moins de 30 jours (sinon le
   bot reste prudent et n'auto-publie presque rien — c'est voulu).
4. Relire 20 brouillons `high` au hasard : ton (tutoiement, B1), sources cliquables, aucune promesse.

## 3. Le cycle d'un brouillon

`queued` (publication repérée) → tâche de la minute → `skipped` (pas une question de
vérification, aucune entité sûre…) **ou** `proposed` (texte prêt) → `published` / `rejected`.
`obsolete` : la publication n'est plus visible (supprimée, masquée, en revue) ou les faits ont
changé avant publication — les faits sont **re-vérifiés au clic sur Publier** ; « Régénérer »
refait le brouillon sur les données du moment. Au plus un brouillon par publication. Une
publication modifiée ou rétablie refait son brouillon s'il n'est ni publié ni rejeté.

## 4. Surveillance

- **Journaux** du conteneur `api` : `Bot Vérif : N traité(s), N proposé(s), N publié(s) seul(s).`
  à chaque passage utile ; `Bot Vérif : brouillon … en échec (…)` sur une erreur (3 tentatives,
  puis `skipped / error`).
- **Statistiques** (onglet Bot Vérif, ou `GET /admin/community/bot/stats?days=30`) : brouillons
  par statut, publiés seuls, publiés « vérifiés », rédigés par le LLM, **délai médian** brouillon
  prêt → décision. Alerte si des `proposed` attendent plus de 24 h (même engagement que la file de
  modération) ou si `skipped / error` grimpe.
- **Audit** : `AdminAuditEvent` (`purposeCode = community_moderation`, `entityType =
  community_bot_draft`) — `community.bot_publish`, `community.bot_auto_publish` (sans acteur),
  `community.bot_reject`, `community.bot_regenerate` ; « marquer vérifiée » écrit aussi
  `verify_answer` au journal de modération.
- **Réponse fausse publiée** : Contenus → la réponse « Assistant KPB » → Masquer (motif), puis
  corriger la fiche du catalogue ; repasser en `review` si c'était une publication automatique.

## 5. Ce que le bot ne fait pas

- Il ne répond pas aux réponses, ni aux publications de l'équipe, ni aux contenus masqués.
- Il n'invente aucun fait : une donnée absente est dite « non renseignée », une fiche ancienne
  « à revérifier » (30 jours pour une bourse, 180 pour une école, une formation ou un pays).
- Sans entité du catalogue sûre (mentionnée, ou nom complet / sigle exact, un seul candidat), il
  ne propose rien.
