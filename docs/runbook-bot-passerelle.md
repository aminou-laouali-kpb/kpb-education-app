# Runbook — bot « Passerelle » (communauté → fonctions de l'app → assistance KPB, C3 bis)

Le bot repère un **besoin** dans ce que l'élève a écrit **lui-même** (« je cherche à faire relire
mon CV », « Campus France, je suis perdu », « quelle bourse pour moi ? ») et lui envoie une
**notification privée** : « Tu peux déjà le faire dans l'app » → bouton vers la bonne fonction, puis
« Besoin d'aide en plus ? Écris-nous sur WhatsApp. ». Jamais de réponse publique dans la communauté.

Contrat : `docs/community-api-contract.md` §15 (comportement) et §8.10 (console). Code :
`backend/src/modules/assist-bridge/`. Console : Communauté → onglet **Bot Passerelle**.

## 1. Les réglages

| Variable | Valeurs | Effet |
|---|---|---|
| `KPB_ASSIST_BRIDGE_MODE` | `shadow` (**défaut**) | Détecte, applique tous les garde-fous, **journalise** ; n'envoie rien. La console montre ce qui serait parti (`wouldSend`). |
| | `on` | Envoie (fil in-app + push par le chemin commun : heures calmes, plafond quotidien). |
| | `off` | Aucune détection, aucun traitement. Les événements déjà écrits restent lisibles. |
| `KPB_ASSIST_BRIDGE_COACH` | `false` (**défaut**) / `true` | Source **privée** : messages de l'élève au coach IA. Fermée tant que la politique de confidentialité n'en parle pas (À VALIDER). |

Toute autre valeur de mode vaut `shadow` (jamais `on` par accident) ; seule `true` ouvre la source
coach. La source communauté ne produit rien tant que `KPB_COMMUNITY_ENABLED` est fermé.

Sur le VPS, dans le `.env` lu par `docker-compose.yml` :

```bash
KPB_ASSIST_BRIDGE_MODE=on        # ou shadow / off
docker compose up -d api         # recrée le conteneur avec la nouvelle valeur
curl -s https://api.kpbeducation.cloud/api/config/app | jq .features.assistBridge   # true en mode on
```

## 2. Le parcours conseillé : `shadow` → lecture des stats → `on`

1. **Shadow (défaut)**, au moins **2 semaines** de communauté ouverte (À VALIDER).
2. Lire l'onglet Bot Passerelle (ou `GET /admin/community/assist-bridge/stats?days=14`) :
   - **Détectés par besoin** : un besoin à zéro → motifs trop étroits ; un besoin qui écrase tout
     → motifs trop larges.
   - **Derniers événements** (filtre « source = publication / réponse ») : relire une trentaine
     d'extraits ; chaque besoin repéré doit être juste. Un faux positif récurrent ⇒ corriger
     `assist-bridge.rules.ts`, monter `ASSIST_BRIDGE_RULES_VERSION`, livrer.
   - **Ignorés par motif** : beaucoup de `feature_unavailable` ⇒ la fonction cible est coupée
     (« Mes 10 bourses », espace Études en France, aucune offre `visa_kit`) — l'ouvrir ou accepter
     que ce besoin reste muet ; beaucoup de `user_cap` / `need_cooldown` ⇒ les seuils jouent.
   - **`wouldSend`** : ce que `on` aurait envoyé — l'ordre de grandeur des notifications à venir.
3. Critères pour passer à `on` (À VALIDER) : < 10 % de faux positifs sur l'échantillon relu, textes
   relus par le propriétaire (onglet → Catalogue), numéro WhatsApp de l'app vérifié (§5).
4. **On** : suivre les clics (« ouvertures fonction », « ouvertures WhatsApp », « fermées ») ; un
   taux de « fermées » très supérieur aux ouvertures sur un besoin ⇒ revoir son texte ou ses motifs.

## 3. Retour arrière

- **Couper l'envoi** : `KPB_ASSIST_BRIDGE_MODE=shadow` (ou `off`) puis `docker compose up -d api`.
  Les notifications déjà envoyées restent dans le fil des élèves (elles sont privées, aucun contenu
  public à retirer). `features.assistBridge` repasse à `false` : l'interrupteur des préférences
  disparaît, la clé `assist_bridge` déjà posée reste respectée.
- **Refermer la source coach** : `KPB_ASSIST_BRIDGE_COACH=false` ; les événements coach encore en
  attente sont abandonnés (`coach_source_off`).
- Effacer les événements (si demandé) : ils sont purgés à 12 mois ; une suppression anticipée se
  fait en SQL sur `AssistBridgeEvent` (aucun texte n'y est stocké).

## 4. Garde-fous (rappel)

Une notification passerelle **par élève sur 72 h** ; un même besoin **pas avant 30 jours** ; rien si
l'élève a déjà utilisé la fonction (relecture, « Mes 10 bourses » ou orientation dans les 14 jours,
dossier en cours ou rendez-vous à venir, achat visa en cours) ; rien pour un compte sanctionné
(lecture seule, bannissement) ; rien pour un texte masqué, supprimé ou d'un autre ; rien la nuit
(21 h → 8 h locale : l'envoi attend le matin, abandonné après 48 h) ; désinscription : préférences
de l'app → « Suggestions de l'équipe KPB » (clé `assist_bridge`, coupe tout). Seuils : À VALIDER.

## 5. Le lien WhatsApp

Le serveur n'envoie **aucun numéro** : la charge dit `whatsapp: "kpb"`, et l'app ouvre la ligne KPB
de sa propre configuration (`KPB_WHATSAPP_NUMBER` au build, `AppConfig.whatsappNumber`) — la même
que la bulle « Études en France » et les autres boutons WhatsApp. Changer de numéro = nouvelle build
(À VALIDER : le propriétaire confirme que cette ligne est bien celle de l'assistance).

## 6. Surveillance

- **Journaux** du conteneur `api` : `Passerelle (on) : N traité(s), N envoyé(s), N ignoré(s), N
  reporté(s).` ; `Passerelle : événement … en échec (…)` (3 tentatives, puis `skipped / error`).
- **Statistiques** : onglet Bot Passerelle, ou `GET /admin/community/assist-bridge/stats?days=30`.
- **Données** : `AssistBridgeEvent` ne contient aucun texte (besoin, règle, version, type et id de
  la source, statut, dates). La console ne montre un extrait que d'un contenu **public** de la
  communauté, relu à la volée ; jamais rien pour la source coach.

## 7. Ce que le bot ne fait pas

- Il ne lit jamais le texte d'un autre élève pour le compte de quelqu'un : le besoin d'une réponse
  est attribué à l'auteur de la réponse.
- Il ne répond jamais en public, n'utilise aucun LLM, ne promet rien (ni admission, ni bourse).
- Il ne propose que des fonctions qui existent et sont ouvertes (§15.2 du contrat) ; la
  disponibilité des rendez-vous visa et l'avis visa USA n'ont pas d'écran propre et ne sont pas
  des cibles.
