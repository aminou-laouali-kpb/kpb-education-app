#!/usr/bin/env bash
# Opérations de production, liste FERMÉE. Voir .github/workflows/vps-ops.yml
# pour le pourquoi. Ce script ne lit aucune commande depuis l'extérieur :
# `ACTION` est comparé à quatre littéraux et rien d'autre n'est exécuté.
#
# Aucune valeur de secret n'est affichée. Le `.env` n'est jamais imprimé — on
# n'en montre que les trois clés KPB_EEF_*, qui sont des drapeaux publics.
set -euo pipefail

: "${VPS_PATH:?VPS_PATH manquant}"
: "${ACTION:?ACTION manquante}"
DRY_RUN="${DRY_RUN:-true}"

cd "$VPS_PATH"

# ── Garde-fou : sans le relais dans compose, écrire le .env n'a AUCUN effet ──
# C'est exactement le défaut mesuré en août (LIV-T15) : les variables posées
# dans .env, absentes du bloc `environment:`, et un opérateur envoyé chercher
# une faute de frappe dans un fichier qui n'en avait pas.
#
# Sans argument : les trois clés de la vitrine. Avec des arguments : ces clés-là
# (l'espace réel n'a besoin que de la sienne).
require_relay() {
  local missing=0
  local keys=("$@")
  [ "${#keys[@]}" -gt 0 ] || keys=(KPB_EEF_TEASER_ENABLED KPB_EEF_CAMPAIGN_OPENS_AT KPB_EEF_SUSPENDED_COUNTRIES)
  for key in "${keys[@]}"; do
    grep -q -- "- ${key}=\${${key}" docker-compose.yml || { echo "::error::${key} n'est pas relayée dans docker-compose.yml — poser le .env n'aurait aucun effet. Le VPS tourne un checkout antérieur au correctif du relais."; missing=1; }
  done
  [ "$missing" -eq 0 ] || exit 1
}

# Pose ou REMPLACE une clé dans .env. Remplacer plutôt qu'ajouter : un .env
# avec deux fois la même clé garde la dernière, et devient illisible pour la
# personne qui le relit.
set_env_key() {
  local key="$1" value="$2"
  if grep -qE "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" .env
  else
    # Un .env dont la dernière ligne n'est pas terminée : sans ce saut de ligne,
    # la clé se collerait au bout de cette ligne (souvent un secret) et le
    # conteneur repartirait avec une valeur altérée.
    if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
      printf '\n' >> .env
    fi
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

# Recrée le conteneur api SANS RIEN RECONSTRUIRE.
#
# `docker compose up -d --no-deps api` seul a été une erreur, payée le
# 30/08/2026 : compose résout `image: kpb-backend:${KPB_IMAGE_TAG:-local}`, ne
# trouve pas `kpb-backend:local`, échoue à le tirer (registre privé), et
# RECONSTRUIT depuis la source. Le conteneur repart alors sur une image sans
# tag ni `KPB_BUILD_SHA` : `/health/version` rend `sha: unknown`, et l'empreinte
# immuable de la release — que `deploy.yml` construit et vérifie soigneusement —
# est perdue.
#
# Le code tournant restait le bon (le checkout du VPS est au SHA déployé), mais
# la traçabilité, non. Une opération de drapeau ne doit JAMAIS changer l'artefact.
#
# On relit donc le tag et le SHA sur le conteneur EN COURS, et on recrée avec
# exactement les mêmes. `--no-build` est la ceinture : si le tag ne résout pas,
# on veut un échec franc, pas une reconstruction silencieuse.
# Le tag lu ici est MUTABLE : `deploy.yml` réécrit `kpb-backend:<tag>` pendant
# `docker compose build`. La parade principale est ailleurs — `vps-ops.yml`
# partage désormais le groupe de concurrence `deploy-vps`, donc une opération de
# drapeau ne peut plus s'entrelacer avec une release. Le contrôle ci-dessous est
# la ceinture : on relève l'ID d'image (lui, immuable) avant et après, et on
# échoue franchement s'il a bougé. Sans lui, une sérialisation cassée un jour
# par une renommée de groupe repasserait inaperçue — et c'est précisément ce
# genre de silence qui a coûté l'empreinte de release le 30/08/2026.
recreate_api_same_image() {
  local cur tag sha id_before id_after sha_after
  cur=$(docker inspect -f '{{.Config.Image}}' kpb_api 2>/dev/null || true)
  [ -n "$cur" ] || { echo "::error::conteneur kpb_api introuvable — ne pas recréer à l'aveugle"; exit 1; }
  tag="${cur##*:}"
  [ -n "$tag" ] && [ "$tag" != "$cur" ] || { echo "::error::image sans tag exploitable : $cur"; exit 1; }
  sha=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null | sed -n 's/^KPB_BUILD_SHA=//p' | head -1)
  id_before=$(docker inspect -f '{{.Image}}' kpb_api)
  echo "recréation à l'identique — image $cur, id ${id_before}, build sha ${sha:-<absent>}"
  KPB_IMAGE_TAG="$tag" KPB_BUILD_SHA="$sha" \
    docker compose up -d --no-deps --no-build api

  id_after=$(docker inspect -f '{{.Image}}' kpb_api)
  if [ "$id_before" != "$id_after" ]; then
    echo "::error::l'image a CHANGÉ pendant la recréation : ${id_before} -> ${id_after}. Le tag ${tag} a été réécrit entre-temps (release concurrente ?). Relancer « Deploy backend (VPS) » scope=full pour repartir d'un état connu."
    exit 1
  fi
  sha_after=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null | sed -n 's/^KPB_BUILD_SHA=//p' | head -1)
  if [ "$sha" != "$sha_after" ]; then
    echo "::error::KPB_BUILD_SHA perdu à la recréation : « ${sha:-<absent>} » -> « ${sha_after:-<absent>} ». L'empreinte de release ne serait plus lisible sur /health/version."
    exit 1
  fi
  echo "image et empreinte inchangées — id ${id_after}, build sha ${sha_after:-<absent>}"
}

# La valeur EFFECTIVEMENT vue par l'API, pas celle qu'on devine.
#
# Deux façons de se tromper, et le script tombait dans les deux :
#
#   1. Lire `.env` avec `head -1`. Une clé posée deux fois garde la DERNIÈRE —
#      `set_env_key` le documente à quatre lignes d'ici — donc le premier
#      assignement peut dire exactement le contraire de la configuration
#      réelle. Un rapport qui ment sur ce qu'il a lu est pire qu'un rapport
#      absent.
#   2. Lire `.env` tout court. Une variable peut y être posée sans être
#      relayée dans le bloc `environment:` de compose : elle existe dans le
#      fichier et n'atteint jamais le processus. C'est le défaut mesuré en
#      août (LIV-T15), et `require_relay` existe déjà à cause de lui.
#
# On interroge donc le CONTENEUR EN COURS, qui est la seule source de vérité :
# c'est l'environnement que Node lit réellement. Repli sur `.env` avec
# `tail -1` si le conteneur est introuvable, en le DISANT.
effective_env() {
  local key="$1" value
  value=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null \
    | sed -n "s/^${key}=//p" | tail -1 || true)
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi
  # Le conteneur ne porte pas la clé : soit elle est absente, soit il n'est pas
  # là. On distingue les deux, parce que « absente » et « illisible » n'appellent
  # pas le même geste.
  if docker inspect kpb_api >/dev/null 2>&1; then
    return 1
  fi
  grep -E "^${key}=" .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'"'"'\r' | xargs || true
}

# Rend compte d'un secret SANS le montrer.
#
# La règle est asymétrique et c'est voulu : `ONESIGNAL_APP_ID` est public — il
# voyage dans le binaire de l'app, un `strings` sur l'IPA le donne — donc
# l'afficher permet de comparer. `ONESIGNAL_REST_API_KEY` est un secret : on
# n'en dit que la présence, jamais la valeur ni la longueur.
report_key() {
  local key="$1" mode="${2:-masked}" value
  value=$(effective_env "$key")
  if [ -z "$value" ]; then
    printf '  %-26s ABSENTE\n' "$key"
    return 1
  fi
  if [ "$mode" = "public" ]; then
    printf '  %-26s %s\n' "$key" "$value"
  else
    printf '  %-26s posée\n' "$key"
  fi
}

# Le push est-il seulement CAPABLE de partir, et vers la bonne application ?
#
# `PushSenderService` se dégrade en silence : sans aucune de ces variables,
# chaque envoi devient un no-op journalisé, le fil d'actualité s'écrit quand
# même, et le dispatcher rend `push_unconfigured`. Rien, nulle part, ne le
# disait — c'est la forme d'échec qui a envoyé la build 50 sans PostHog.
#
# Deux chemins pendant la transition :
#   - FCM (`FCM_SERVICE_ACCOUNT_JSON`) : versions de l'app qui enregistrent un
#     jeton d'appareil — le chemin normal, gratuit ;
#   - OneSignal (`ONESIGNAL_*`) : versions antérieures, encore abonnées chez
#     OneSignal. À retirer quand plus personne ne les utilise.
show_push_state() {
  echo "── Notifications push (FCM + OneSignal en transition) ──"
  docker inspect kpb_api >/dev/null 2>&1 \
    || echo "  (conteneur kpb_api introuvable — valeurs lues dans .env, pas dans le processus)"
  local fcm=0 onesignal=0
  report_key FCM_SERVICE_ACCOUNT_JSON masked || fcm=1
  report_key ONESIGNAL_APP_ID public || onesignal=1
  report_key ONESIGNAL_REST_API_KEY masked || onesignal=1
  if [ "$fcm" -ne 0 ] && [ "$onesignal" -ne 0 ]; then
    echo "  → push DÉSACTIVÉ : le fil s'écrira, aucune notification ne partira."
  elif [ "$fcm" -ne 0 ]; then
    echo "::warning::FCM_SERVICE_ACCOUNT_JSON absente : seules les anciennes versions de l'app (OneSignal) reçoivent le push. Les nouvelles versions ne reçoivent RIEN."
  elif [ "$onesignal" -ne 0 ]; then
    echo "  → push configuré (FCM seul) — les versions de l'app antérieures à FCM ne reçoivent plus rien."
  else
    echo "  → push configuré (FCM, et OneSignal pour les anciennes versions)."
  fi

  # Comparaison INDICATIVE, et jamais bloquante.
  #
  # `EXPECTED_ONESIGNAL_APP_ID` est l'App ID que les builds ANTÉRIEURES à FCM
  # embarquent. L'app courante n'embarque plus OneSignal : la valeur est donc
  # figée dans le workflow, comme ces artefacts le sont dans les boutiques.
  #
  # Un écart mérite un REGARD, pas une action. En faire une erreur aurait
  # invité à basculer le serveur — et à couper le push pour tous les clients
  # déjà installés. La vérité vit dans l'artefact distribué :
  # `strings App.framework/App | grep -o '[0-9a-f-]\{36\}'`.
  if [ -n "${EXPECTED_ONESIGNAL_APP_ID:-}" ] && [ "$onesignal" -eq 0 ]; then
    local server
    server=$(effective_env ONESIGNAL_APP_ID)
    if [ "$server" = "$EXPECTED_ONESIGNAL_APP_ID" ]; then
      echo "  App ID OneSignal identique à celui des anciennes builds ✅"
    else
      echo "::warning::l'App ID du serveur ($server) diffère de celui des builds antérieures à FCM ($EXPECTED_ONESIGNAL_APP_ID). Ce n'est PAS forcément une panne : une build peut avoir été construite avec --dart-define. NE PAS basculer le serveur sans avoir lu l'App ID de l'artefact réellement distribué."
    fi
  fi
  echo
}

# Vers QUI partent réellement les invites IA ?
#
# La question n'est pas cosmétique : `docs/CONSOLE_ANSWERS.md` §5 porte la
# mention « recopier au formulaire destinataires ». Nommer le mauvais
# sous-traitant dans une déclaration de confidentialité est une déclaration
# fausse, pas une coquille.
#
# On REJOUE ici la précédence exacte de `LlmService.provider`
# (backend/src/modules/ai/llm.service.ts) plutôt que de la résumer : un résumé
# se désynchronise du code en silence, et c'est précisément ce qu'on cherche à
# éviter. `LLM_API_KEY` l'emporte (OpenRouter sauf `LLM_PROVIDER=groq`) ; à
# défaut, `GROQ_API_KEY` fait tomber sur Groq ; sans clé, aucun fournisseur.
#
# Asymétrie habituelle : les CLÉS sont des secrets (présence seulement), le
# fournisseur, le modèle et l'URL sont de la configuration — les afficher est
# tout l'intérêt de la manoeuvre.
show_llm_state() {
  echo "── Fournisseur LLM (destinataire des invites) ──"
  docker inspect kpb_api >/dev/null 2>&1 \
    || echo "  (conteneur kpb_api introuvable — valeurs lues dans .env, pas dans le processus)"

  # `|| true` sur CHAQUE lecture optionnelle : sous `set -e`, une affectation
  # dont la substitution rend 1 tue le script. `effective_env` rend justement 1
  # quand la clé est absente du conteneur — et `LLM_PROVIDER`, `LLM_MODEL` et
  # `LLM_CHAT_COMPLETIONS_URL` sont TOUTES optionnelles par construction. Sans
  # ces gardes, `show-state` mourait pile sur l'installation la plus banale.
  local llm_key groq_key name model url
  llm_key=$(effective_env LLM_API_KEY || true)
  groq_key=$(effective_env GROQ_API_KEY || true)

  if [ -n "$llm_key" ]; then
    report_key LLM_API_KEY masked
    local declared
    declared=$(effective_env LLM_PROVIDER || true)
    if [ "$(printf '%s' "$declared" | tr '[:upper:]' '[:lower:]')" = "groq" ]; then
      name=groq
      model=$(effective_env LLM_MODEL || true); model="${model:-llama-3.3-70b-versatile (défaut)}"
      url=$(effective_env LLM_CHAT_COMPLETIONS_URL || true); url="${url:-https://api.groq.com/openai/v1/chat/completions (défaut)}"
    else
      name=openrouter
      model=$(effective_env LLM_MODEL || true); model="${model:-deepseek/deepseek-v4-flash (défaut)}"
      url=$(effective_env LLM_CHAT_COMPLETIONS_URL || true); url="${url:-https://openrouter.ai/api/v1/chat/completions (défaut)}"
    fi
  elif [ -n "$groq_key" ]; then
    echo "  LLM_API_KEY                ABSENTE (repli sur les variables GROQ_* héritées)"
    report_key GROQ_API_KEY masked
    name=groq
    model=$(effective_env GROQ_MODEL || true); model="${model:-llama-3.3-70b-versatile (défaut)}"
    url="https://api.groq.com/openai/v1/chat/completions (fixe sur ce chemin)"
  else
    echo "  aucune clé LLM posée"
    echo "  → IA NON configurée : les outils rendront une réponse locale de repli."
    echo
    return 0
  fi

  printf '  %-26s %s\n' "fournisseur résolu" "$name"
  printf '  %-26s %s\n' "modèle" "$model"
  printf '  %-26s %s\n' "URL appelée" "$url"
  echo "  → destinataire à déclarer dans les formulaires : $name"

  # La fiche consoles déclare un destinataire ; la production en utilise un.
  # Les deux doivent coïncider, sinon le formulaire Play Data Safety / App
  # Privacy nommera le mauvais sous-traitant.
  #
  # Le nom attendu est LU dans la fiche par le workflow et passé ici — jamais
  # écrit en dur. Une constante se désynchronise de la fiche à la première
  # migration de fournisseur : c'est exactement ce qui s'est produit, la garde
  # annonçant « la fiche dit Groq » après que la fiche eut été corrigée.
  local expected="${EXPECTED_LLM_PROVIDER:-}"
  if [ -z "$expected" ]; then
    echo "  (destinataire déclaré non transmis — comparaison impossible)"
  elif [ "$name" != "$expected" ]; then
    echo "::warning::docs/CONSOLE_ANSWERS.md déclare « ${expected} » comme destinataire des invites IA, or la production route vers « ${name} ». Corriger la fiche AVANT de recopier la table des destinataires dans Play Data Safety / App Privacy."
  else
    echo "  → conforme à la fiche consoles (${expected})."
  fi
  echo
}

# Fait passer le fichier de test EICAR par le protocole INSTREAM, depuis le
# conteneur `api` — même réseau, même résolution de nom, même chemin que les
# envois réels.
#
# INSTREAM et pas PING. Un PONG ne prouve que le canal de CONTRÔLE : un clamd
# qui répond peut refuser INSTREAM (limite de taille) ou tourner sans base
# chargée, et rendre 503 sur chaque fichier — soit exactement la panne qu'on
# prétend détecter. Seul un verdict prouve qu'on analyse.
#
# Rend sur stdout : ANALYSE | NE_DETECTE_RIEN | INJOIGNABLE (…) | …
#
# La chaîne EICAR est assemblée en guillemets SIMPLES et transmise par
# l'environnement : elle contient `$` et `\`, que des guillemets doubles
# feraient interpréter par bash. Le JS ne fait donc aucune interpolation.
clamd_verdict() {
  local host="$1" port="$2" eicar
  eicar='X5O!P%@AP[4\PZX54(P^)7CC)7}'
  eicar="${eicar}"'$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

  docker compose exec -T \
    -e AV_HOST="$host" -e AV_PORT="$port" -e AV_EICAR="$eicar" \
    api node -e '
      const net = require("net");
      const eicar = Buffer.from(process.env.AV_EICAR, "ascii");
      const s = net.createConnection({
        host: process.env.AV_HOST,
        port: Number(process.env.AV_PORT),
      });
      let out = "";
      const done = (v) => {
        try { s.destroy(); } catch (e) {}
        console.log(v);
        process.exit(0);
      };
      s.setTimeout(15000, () => done("INJOIGNABLE (delai depasse)"));
      s.on("error", (e) => done("INJOIGNABLE (" + e.code + ")"));
      s.on("connect", () => {
        s.write("zINSTREAM\0");
        const len = Buffer.alloc(4);
        len.writeUInt32BE(eicar.length, 0);
        s.write(Buffer.concat([len, eicar, Buffer.from([0, 0, 0, 0])]));
      });
      s.on("data", (d) => {
        out += d.toString();
        if (out.includes("FOUND")) done("ANALYSE");
        else if (/\bOK\b/.test(out)) done("NE_DETECTE_RIEN");
        else if (out.includes("ERROR")) done("ERREUR (" + out.trim() + ")");
      });
      s.on("close", () =>
        done(out.trim() ? "REPONSE INATTENDUE (" + out.trim() + ")" : "FERME SANS REPONSE"));
    ' 2>/dev/null | tr -d '\r' | tail -1 || true
}

# L'analyse antivirus des documents envoyés fonctionne-t-elle VRAIMENT ?
#
# On SONDE clamd, on ne se contente pas de lire `CLAMAV_HOST`. La distinction
# est tout l'objet de cette fonction : le 15/08/2026 à 09h55, clamd est mort
# dans le conteneur `kpb_clamav` sans que rien ne le dise. Le conteneur est
# resté « Up » pendant vingt jours parce que `freshclam`, lui, tournait
# toujours — il a consciencieusement mis à jour des signatures pour un daemon
# absent. `docker ps` affichait « unhealthy », personne ne regarde `docker ps`,
# et la configuration, elle, restait parfaitement valide.
#
# Une garde qui aurait affiché `CLAMAV_HOST=clamav` aurait donc été aussi
# aveugle que l'absence de garde. On envoie un vrai PING au daemon, depuis le
# conteneur `api` — même réseau, même résolution de nom, même chemin que les
# envois réels.
#
# `AntivirusService` est FAIL-CLOSED : configuré mais sans verdict, il rend 503
# et l'envoi est refusé. Les deux issues d'une panne sont donc opposées, et il
# faut savoir laquelle : hôte posé + daemon mort ⇒ plus aucun envoi de document
# ne passe ; hôte vide ⇒ les fichiers passent SANS ÊTRE ANALYSÉS.
show_antivirus_state() {
  echo "── Analyse antivirus des documents (ClamAV) ──"
  local host port
  host=$(effective_env CLAMAV_HOST || true)
  port=$(effective_env CLAMAV_PORT || true); port="${port:-3310}"

  if [ -z "$host" ]; then
    echo "  CLAMAV_HOST                VIDE"
    echo "::warning::CLAMAV_HOST est vide : les documents envoyés sont persistés SANS analyse antivirus. C'est un choix valide en local, jamais en production."
    echo
    return 0
  fi

  printf '  %-26s %s\n' "CLAMAV_HOST" "$host"
  printf '  %-26s %s\n' "CLAMAV_PORT" "$port"

  # `|| true` : une sonde qui échoue est un RÉSULTAT, pas une raison de faire
  # échouer une lecture d'état.
  local verdict
  verdict=$(clamd_verdict "$host" "$port" || true)

  case "$verdict" in
    ANALYSE)
      echo "  → EICAR détecté : la chaîne complète analyse réellement. ✅"
      ;;
    NE_DETECTE_RIEN)
      echo "  → clamd répond mais NE DÉTECTE PAS le fichier de test."
      echo "::error::clamd répond sur $host:$port mais déclare EICAR propre : les signatures ne sont pas chargées. Un fichier réellement infecté PASSERAIT. Ce n'est pas un service sain."
      ;;
    "")
      echo "  → sonde impossible (conteneur api injoignable). État INCONNU."
      ;;
    *)
      echo "  → pas de verdict : $verdict"
      echo "::error::ClamAV est configuré ($host:$port) mais ne rend aucun verdict. AntivirusService étant fail-closed, TOUT envoi de document est refusé en 503. Vérifier le conteneur kpb_clamav : freshclam peut tourner (conteneur « Up ») alors que clamd est mort — c'est le mode de panne du 15/08/2026."
      ;;
  esac
  echo
}

# Redémarre le SEUL conteneur antivirus, et vérifie que clamd revient.
#
# Cible délibérément étroite : `docker compose restart clamav`, pas la pile.
# Redémarrer les six conteneurs pour ranimer un sidecar couperait l'API et la
# base pour rien — et la panne du 15/08 n'a jamais concerné qu'un processus.
#
# Le redémarrage ne vaut RIEN sans la vérification qui suit : c'est tout
# l'enseignement de cette panne. Un conteneur qui repart « Up » ne prouve pas
# que clamd écoute — pendant vingt jours il était « Up » sans clamd. On attend
# donc un PONG, avec une borne : clamd charge 3,3 M de signatures au démarrage,
# ce qui prend des minutes, mais une attente non bornée transformerait une
# opération en blocage.
# Recréer le conteneur antivirus — PAS le redémarrer.
#
# `docker compose restart` relance le processus dans le conteneur EXISTANT :
# il ne relit pas `docker-compose.yml`. Une limite mémoire n'est appliquée
# qu'à la CRÉATION du conteneur.
#
# Le 08/09/2026, ça s'est payé : `mem_limit` était passé de 1536m à 3g (PR
# #267), fusionné et déployé, et pourtant le conteneur tournait toujours avec
# 1536 Mo — même identifiant `06f8130a6da2` qu'avant le déploiement. La
# limite était juste dans le fichier et fausse dans la réalité. clamd est
# remort trois jours plus tard, et l'ancienne version de cette fonction
# l'aurait ranimé sans jamais lui donner sa mémoire : un correctif qui ne
# pouvait pas s'appliquer, servi par un outil qui ne pouvait pas l'appliquer.
#
# D'où `up -d --force-recreate` — et surtout la VÉRIFICATION de la limite
# effectivement posée, plus bas. Croire la configuration sur parole est
# exactement ce qui a coûté ces trois jours.
recreate_clamav() {
  echo "── Recréation de kpb_clamav ──"
  echo "  état AVANT :"
  show_antivirus_state | sed 's/^/  /'

  local mem_before mem_after
  mem_before=$(docker inspect -f '{{.HostConfig.Memory}}' kpb_clamav 2>/dev/null || echo 0)

  # `--no-build` : clamav vient d'une image publique, rien à construire ici.
  # Une reconstruction accidentelle est le mode d'échec que `deploy.yml`
  # documente déjà pour la recréation de l'API.
  docker compose up -d --force-recreate --no-build clamav
  echo

  mem_after=$(docker inspect -f '{{.HostConfig.Memory}}' kpb_clamav 2>/dev/null || echo 0)
  printf '  %-26s %s Mo\n' "limite AVANT" "$((mem_before / 1024 / 1024))"
  printf '  %-26s %s Mo\n' "limite APRÈS" "$((mem_after / 1024 / 1024))"
  if [ "$mem_after" -le "$mem_before" ] && [ "$mem_before" -gt 0 ]; then
    echo "::warning::La limite mémoire n'a pas changé. Si docker-compose.yml annonce une autre valeur, la recréation n'a pas pris — vérifier que le fichier du VPS est bien à jour."
  fi
  echo

  echo "  attente d'un VERDICT de clamd (jusqu'à 5 min — chargement des signatures)"
  local waited=0 verdict
  while [ "$waited" -lt 300 ]; do
    sleep 15
    waited=$((waited + 15))
    verdict=$(clamd_verdict clamav 3310 || true)
    if [ "$verdict" = "ANALYSE" ]; then
      echo "  clamd analyse après ${waited}s."
      echo
      show_antivirus_state
      return 0
    fi
    echo "  ...${verdict:-pas de réponse} (${waited}s)"
  done

  echo
  show_antivirus_state
  echo "::error::clamd n'a rendu aucun verdict dans les 5 minutes suivant la RECRÉATION. La limite mémoire affichée ci-dessus est celle réellement appliquée : si elle est correcte, la mémoire n'est pas la cause et il faut chercher ailleurs (journal du conteneur, base de signatures corrompue). Les envois de fichiers restent refusés en 503."
  return 1
}

# ── Fenêtre de campagne « Études en France » ───────────────────────────────
#
# Les valeurs sont ÉCRITES ICI, en clair, et non saisies au déclenchement : le
# workflow n'accepte aucune valeur libre (un secret de déploiement ne devient
# pas un shell distant). Les changer passe donc par une PR, relue — c'est voulu
# pour ce qui s'affiche à des étudiants comme une date ou un pays « suspendu ».
#
#   • OPENS_AT  : le jour d'ouverture de la campagne, `AAAA-MM-JJ` (jour nu).
#   • CLOSES_AT : VIDE tant qu'aucune clôture GLOBALE n'est annoncée. Elle varie
#                 par pays (Maroc, Sénégal…) et un jour unique serait faux pour
#                 la plupart des étudiants. À renseigner par PR, pas avant.
#   • SUSPENDED : les pays où le service ne traite pas les dossiers — à
#                 revérifier sur les sources officielles avant chaque usage.
EEF_CAMPAIGN_OPENS_AT="2026-10-01"
EEF_CAMPAIGN_CLOSES_AT=""
EEF_CAMPAIGN_SUSPENDED="Niger,NE"

# La version RECOMMANDÉE (bandeau doux « une mise à jour est disponible »). Écrite
# ici, relue en PR : l'action n'accepte aucune valeur libre.
#
# **VIDE par défaut, et c'est voulu.** Le bandeau n'existe que dans les builds
# 2.3.0 (54) et suivantes ; il compare la version installée à celle-ci. Poser
# « 2.3.0 » ne ferait donc rien : la 54 est déjà à 2.3.0, et les builds 49 à 53
# ne lisent pas cette clé. Le levier sert aux passages SUIVANTS (54 → 55 → forum) :
# la veille de chaque build, mettre ici sa version — par PR — et seulement quand
# elle est DISPONIBLE sur les deux stores, sinon le bandeau envoie vers un store
# qui n'a encore rien. Vide = aucun bandeau (et l'action RETIRE la clé du .env).
RECOMMENDED_APP_VERSION=""

# Nombre de formations de l'import que la recherche SERVIRAIT : active, sous un
# établissement actif, du périmètre de l'import (même définition que
# `eefProgramWhere` côté serveur). Zéro = un espace qui s'ouvrirait VIDE.
eef_visible_programs() {
  docker compose exec -T db psql -v ON_ERROR_STOP=1 -tA \
    -U "$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2-)" \
    -d "$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2-)" \
    -c "SELECT count(*) FROM \"Program\" p JOIN \"Institution\" i ON i.id = p.\"institutionId\" WHERE p.\"isActive\" AND i.\"isActive\" AND (p.id LIKE 'eef-prog-%' OR i.id LIKE 'eef-univ-%');"
}

# ── Les interrupteurs de la build 56 : bulle et écoles privées ─────────────
#
# Deux drapeaux serveur, `features.eefHelpBubble` (KPB_EEF_HELP_BUBBLE_ENABLED) et
# `features.eefPrivateSchools` (KPB_EEF_PRIVATE_SCHOOLS_ENABLED). Même modèle
# qu'`eef-space-on` / `eef-space-off` : l'ouverture SIMULE par défaut, la
# fermeture agit tout de suite, et seule LEUR clé est écrite dans le `.env` —
# jamais l'espace, la vitrine, ni l'autre interrupteur. Ouvrir l'espace n'allume
# aucun des deux ; chaque ouverture est une décision à part.
#
# Les deux fonctions prennent : la variable du `.env`, la clé servie par
# `/config/app` (pour les messages), et le nom de l'action (idem).

# Ouverture. Contrôle d'abord, écrit ensuite — et n'écrit que sur un « false »
# EXPLICITE : tout autre valeur de DRY_RUN (vide, faute de frappe) simule, comme
# `eef-publish` et `eef-reconcile`. Une action qui ouvre une surface aux
# étudiants ne se déclenche pas sur une coquille.
eef_flag_on() {
  local env_key="$1" json_key="$2" action="$3"
  require_relay "$env_key"
  # Le backend déployé doit SERVIR la clé. Sans ce contrôle l'action « réussit »
  # (le `.env` est écrit, le conteneur recréé) et `/config/app` ne dit rien :
  # l'app lit « clé absente » et la bascule n'a aucun effet. C'est le piège de
  # l'ordre : fusionner sur main ne déploie rien, et un déploiement d'un commit
  # antérieur à la build 56 ne porte pas ces clés. On cherche la clé dans le
  # contrôleur COMPILÉ du conteneur, comme `eef-space-on` cherche son fichier.
  if ! docker compose exec -T api grep -q "$json_key" dist/modules/config/app-config.controller.js; then
    echo "::error::Le backend déployé ne sert pas features.${json_key} (dist/modules/config/app-config.controller.js ne la contient pas) : ${action} n'aurait aucun effet visible. Déployer d'abord le backend de la build 56 (deploy.yml, scope=full)."
    exit 1
  fi
  # L'app exige l'espace ouvert EN PLUS : cette clé seule n'affiche rien. On le
  # dit, sans bloquer — la recette allume et éteint dans l'ordre qui l'arrange.
  if ! grep -qE '^KPB_EEF_SPACE_ENABLED=true' .env; then
    echo "::warning::KPB_EEF_SPACE_ENABLED n'est pas à true dans le .env : l'espace est fermé, et ${json_key} seul n'affichera rien. Ordre d'ouverture : eef-space-on d'abord."
  fi
  if [ "$DRY_RUN" != "false" ]; then
    echo "── SIMULATION : les contrôles passent, rien n'est écrit. Décocher « dry_run » pour appliquer ${action}. ──"
    exit 0
  fi
  cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  set_env_key "$env_key" true
  echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
  recreate_api_same_image
}

# Fermeture : le retour arrière. Pas de simulation, il doit agir tout de suite,
# et il ne dépend PAS du code déployé — on doit toujours pouvoir fermer.
eef_flag_off() {
  local env_key="$1"
  require_relay "$env_key"
  cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  set_env_key "$env_key" false
  echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
  recreate_api_same_image
}

show_state() {
  echo "── Drapeaux EEF dans le .env ──"
  grep -E '^KPB_EEF' .env || echo "(aucune variable KPB_EEF posée)"
  echo
  echo "── Portes de version dans le .env (jamais de valeur libre ici) ──"
  grep -E '^KPB_(MIN|RECOMMENDED)_APP_VERSION=' .env || echo "(aucune : minVersion 0.0.0, aucun bandeau)"
  echo
  show_push_state
  show_llm_state
  show_antivirus_state
  echo "── Ce que compose interpolera ──"
  docker compose config 2>/dev/null | grep -E 'KPB_EEF' || echo "(interpolation indisponible)"
  echo
  echo "── Bourses en base ──"
  docker compose exec -T db psql -v ON_ERROR_STOP=1 -tA \
    -U "$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2-)" \
    -d "$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2-)" \
    -c 'SELECT "moderationStatus", "isActive", count(*) FROM "Scholarship" GROUP BY 1,2 ORDER BY 1,2;'
}

case "$ACTION" in
  show-state)
    show_state
    ;;

  recreate-clamav)
    recreate_clamav
    ;;

  eef-teaser-on)
    require_relay
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_TEASER_ENABLED true
    set_env_key KPB_EEF_CAMPAIGN_OPENS_AT "$EEF_CAMPAIGN_OPENS_AT"
    set_env_key KPB_EEF_SUSPENDED_COUNTRIES "$EEF_CAMPAIGN_SUSPENDED"
    # KPB_EEF_ENABLED reste ABSENT à dessein : il retire la vitrine de lui-même
    # et afficherait l'espace réel aux builds 49 à 53, qui n'ont qu'une coquille
    # vide. L'espace de la build 54 s'ouvre par `eef-space-on`, pas par là.
    if grep -qE '^KPB_EEF_ENABLED=true' .env; then
      echo "::error::KPB_EEF_ENABLED=true est posé : il désactive la vitrine et afficherait un espace VIDE. Le retirer avant de continuer."
      exit 1
    fi
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  eef-space-on)
    # Ouvre l'espace RÉEL pour la seule build 54 (`features.eefSpace`). N'écrit
    # QUE `KPB_EEF_SPACE_ENABLED` : la vitrine des builds 49 à 53 n'est pas
    # touchée, et c'est tout l'intérêt de cette clé.
    #
    # Par défaut, SIMULATION : les contrôles sont faits, rien n'est écrit.
    require_relay KPB_EEF_SPACE_ENABLED
    if grep -qE '^KPB_EEF_ENABLED=true' .env; then
      echo "::error::KPB_EEF_ENABLED=true est posé : c'est l'ANCIEN commutateur, que lisent aussi les builds 49 à 53 — il retire leur vitrine et leur montre un espace vide. Le retirer, puis utiliser cette action."
      exit 1
    fi
    visible="$(eef_visible_programs | tr -d '[:space:]')"
    case "$visible" in
      ''|*[!0-9]*) echo "::error::décompte des formations publiées illisible (« ${visible:-<vide>} ») — ne pas ouvrir à l'aveugle"; exit 1 ;;
    esac
    # Le backend doit porter CE que l'espace de la 54 lit : la mention de paternité
    # du catalogue (`eefCatalog`), les liens officiels, la mise à jour de profil.
    # Sans lui, l'action « réussit » (elle ne vérifiait que `eefSpace`) et la
    # 54 s'ouvre sur un catalogue SANS la mention exigée par la Licence Ouverte.
    # Même contrôle que `eef-import` : le fichier compilé dans le conteneur.
    if ! docker compose exec -T api test -f dist/modules/etudes-en-france/catalog/eef-catalog-attribution.js; then
      echo "::error::Le backend déployé ne porte pas la build 54 côté serveur (eef-catalog-attribution.js absent) : l'espace s'ouvrirait sans la mention de paternité du catalogue. Déployer le backend (scope=full) d'abord."
      exit 1
    fi
    echo "formations de l'import que la recherche servirait : ${visible}"
    if [ "$visible" -eq 0 ]; then
      echo "::error::aucune formation de l'import n'est publiée : l'espace s'ouvrirait VIDE. Publier d'abord un établissement relu (admin → « Publication EEF »)."
      exit 1
    fi
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION : les contrôles passent, rien n'est écrit. Décocher « dry_run » pour ouvrir l'espace. ──"
      exit 0
    fi
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_SPACE_ENABLED true
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  eef-space-off)
    # Le retour arrière : pas de simulation, il doit agir tout de suite.
    require_relay KPB_EEF_SPACE_ENABLED
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_SPACE_ENABLED false
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  eef-bubble-on)
    # Ouvre la bulle « Une question ? » (`features.eefHelpBubble`).
    eef_flag_on KPB_EEF_HELP_BUBBLE_ENABLED eefHelpBubble eef-bubble-on
    ;;

  eef-bubble-off)
    eef_flag_off KPB_EEF_HELP_BUBBLE_ENABLED
    ;;

  eef-private-schools-on)
    # Ouvre la mention des écoles privées. À ne lancer qu'après validation
    # juridique (docs/runbook-ouverture-espace-reel.md).
    eef_flag_on KPB_EEF_PRIVATE_SCHOOLS_ENABLED eefPrivateSchools eef-private-schools-on
    ;;

  eef-private-schools-off)
    eef_flag_off KPB_EEF_PRIVATE_SCHOOLS_ENABLED
    ;;

  eef-campaign-set)
    # Pose la fenêtre de campagne ci-dessus (ouverture, clôture, pays suspendus)
    # SANS toucher à la vitrine ni à l'espace : changer une date ou lever la
    # suspension d'un pays ne doit pas dépendre d'un autre interrupteur.
    require_relay KPB_EEF_CAMPAIGN_OPENS_AT KPB_EEF_CAMPAIGN_CLOSES_AT KPB_EEF_SUSPENDED_COUNTRIES
    echo "── Fenêtre à poser (relue en PR) ──"
    echo "KPB_EEF_CAMPAIGN_OPENS_AT=${EEF_CAMPAIGN_OPENS_AT}"
    echo "KPB_EEF_CAMPAIGN_CLOSES_AT=${EEF_CAMPAIGN_CLOSES_AT}"
    echo "KPB_EEF_SUSPENDED_COUNTRIES=${EEF_CAMPAIGN_SUSPENDED}"
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION : rien n'est écrit. Décocher « dry_run » pour appliquer. ──"
      exit 0
    fi
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_CAMPAIGN_OPENS_AT "$EEF_CAMPAIGN_OPENS_AT"
    set_env_key KPB_EEF_CAMPAIGN_CLOSES_AT "$EEF_CAMPAIGN_CLOSES_AT"
    set_env_key KPB_EEF_SUSPENDED_COUNTRIES "$EEF_CAMPAIGN_SUSPENDED"
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  recommended-version-set)
    # Pose (ou, si la constante est vide, RETIRE) la version recommandée. Ne
    # touche ni à la vitrine, ni à l'espace, ni à KPB_MIN_APP_VERSION : inviter à
    # mettre à jour et bloquer l'app sont deux décisions distinctes.
    require_relay KPB_RECOMMENDED_APP_VERSION
    if [ -n "$RECOMMENDED_APP_VERSION" ] && ! printf '%s' "$RECOMMENDED_APP_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "::error::RECOMMENDED_APP_VERSION doit être « x.y.z » (reçu « ${RECOMMENDED_APP_VERSION} ») — le serveur l'ignorerait."
      exit 1
    fi
    echo "── Version recommandée à poser (relue en PR) ──"
    echo "KPB_RECOMMENDED_APP_VERSION=${RECOMMENDED_APP_VERSION}"
    if grep -qE '^KPB_MIN_APP_VERSION=' .env; then
      echo "(KPB_MIN_APP_VERSION n'est pas modifiée par cette action.)"
    fi
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION : rien n'est écrit. Décocher « dry_run » pour appliquer. ──"
      exit 0
    fi
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_RECOMMENDED_APP_VERSION "$RECOMMENDED_APP_VERSION"
    echo "── .env après écriture ──"; grep -E '^KPB_RECOMMENDED_APP_VERSION' .env
    recreate_api_same_image
    ;;

  eef-teaser-off)
    require_relay
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_TEASER_ENABLED false
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  publish-catalog)
    # SOP docs/catalog-verification-sop.md, SANS --confirmed-only : ce drapeau
    # écarte toute fiche à cycle estimé, c'est-à-dire les bourses « à venir ».
    #
    # `reconcile` s'intercale entre `import` et `switch`, et l'ordre est une
    # nécessité, pas une préférence :
    #   • `import` crée les fiches manquantes et NE TOUCHE JAMAIS les autres ;
    #   • `reconcile` réaligne les fiches déjà créées sur le dépôt — sans lui,
    #     une correction relue en PR n'atteint jamais la production (mesuré le
    #     31/08/2026 : deux fiches servaient un cycle « estimated » là où le
    #     dépôt disait « confirmed » depuis le 24/08) ;
    #   • `switch` publie, en dernier, sur des données à jour. Réconcilier APRÈS
    #     aurait publié la version périmée avant de la corriger.
    #
    # `reconcile` ne publie ni n'approuve rien : sa transaction est annulée si
    # l'état de modération d'une seule fiche a bougé pendant l'opération.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run catalog:import -- --dry-run
      docker compose exec -T api npm run catalog:reconcile -- --dry-run
      docker compose exec -T api npm run catalog:switch -- --dry-run
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run catalog:import -- --apply
      docker compose exec -T api npm run catalog:reconcile -- --apply
      docker compose exec -T api npm run catalog:switch -- --apply
    fi
    echo
    echo "── Bourses visibles après opération ──"
    show_state
    ;;

  import-partners)
    # Importe les universités partenaires manquantes et leurs formations depuis
    # `backend/scripts/data/universites-partenaires.csv`.
    #
    # Le périmètre est une LISTE BLANCHE tenue dans le code, pas « tout le
    # fichier » : le CSV contient aussi les écoles OMNES, déjà en production
    # sous `omnes-*`, listées campus par campus là où la base stocke une seule
    # formation portant `campusOfferings[]`. Les importer ré-éclaterait ce
    # regroupement en doublons.
    #
    # L'écriture est un `upsert` dont la partie `update` est VIDE : relancer ne
    # crée rien et n'écrase jamais une fiche retouchée à la main. L'opération
    # est donc rejouable sans risque après une simulation.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run import:partners
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run import:partners -- --apply
      echo
      echo "── Intégrité des références pays ──"
      # `Institution.countryId` et `Program.countryId` sont des colonnes
      # indexées, PAS des clés étrangères : rien en base n'empêche une fiche de
      # pointer vers un pays inexistant, et elle ne remonterait alors sous aucun
      # filtre. Ce contrôle sort en échec s'il trouve un orphelin.
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  import-omnes-spring)
    # Ajoute la rentrée décalée OMNES (grille « SPRING 27 », janvier – mars
    # 2027 : ECE, ESCE, INSEEC) depuis `backend/scripts/data/omnes_spring_27.csv`.
    #
    # ADDITIF : une formation déjà en base reçoit ses offres de printemps
    # manquantes (campus + date, rythme, prix propre à l'offre) à la FIN de
    # `campusOfferings` ; ses offres d'automne et le reste de sa fiche ne sont
    # pas touchés. Une formation inconnue est créée aux conventions de
    # `seed:omnes`. L'école reçoit ses nouvelles dates et formations (`push`).
    #
    # Chaque fiche n'est réécrite que si elle n'a pas bougé depuis la lecture
    # (`WHERE updatedAt = …`) : une retouche faite dans l'admin pendant
    # l'opération est gardée, et la relance la complète. Rejouer après
    # application : « 0 écriture ».
    #
    # Garde de production : la première application passe (aucune offre de
    # printemps en base) ; une relance qui aurait encore quelque chose à écrire
    # est refusée sans KPB_ALLOW_PRODUCTION_SEED=1 — c'est voulu, on regarde
    # d'abord pourquoi. Runbook : docs/runbook-rentrees-partenaires.md.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run import:omnes-spring
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run import:omnes-spring -- --apply
      echo
      echo "── Intégrité du catalogue ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  roll-omnes-fall-2027)
    # Reconduit d'un an les rentrées d'automne OMNES 2026 (décision du
    # propriétaire du 16/10/2026) : « 01/10/2026 » → « 01/10/2027 »,
    # « 14/09/2026 » → « 14/09/2027 », « 31/08/2026 » → « 31/08/2027 ». Campus
    # et prix gardés (tarifs 2026-2027) ; chaque offre reconduite porte
    # `rolledFromIntake` et `intakeEstimated: true`, que l'app affiche « Date
    # reconduite de 2026, à confirmer ». Les offres de rentrée décalée
    # (janvier – mars 2027) ne bougent pas. Les `intakePeriods` des écoles
    # OMNES suivent (date 2026 remplacée à sa place par la date 2027).
    #
    # Seules les offres NON RETOUCHÉES (campus, dates, prix de la grille
    # `backend/scripts/data/omnes_fall_26.xlsx`) sont reconduites ; une offre
    # retouchée dans l'admin est signalée « ⚠ », jamais modifiée. Écriture sous
    # `WHERE updatedAt = …`. Rejouable : « 0 écriture ». À passer APRÈS
    # `dedupe-omnes` et `import-omnes-spring`. Garde de production : la
    # première application passe ; une relance qui aurait encore quelque chose
    # à écrire demande KPB_ALLOW_PRODUCTION_SEED=1. Runbook :
    # docs/runbook-rentrees-partenaires.md.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run roll:omnes-fall-2027
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run roll:omnes-fall-2027 -- --apply
      echo
      echo "── Intégrité du catalogue ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  dedupe-omnes)
    # Fusionne les doublons OMNES déjà en base : la grille d'automne 2026
    # écrivait parfois la même formation de deux façons (casse, accent, campus
    # resté dans l'intitulé : « BCh- Rennes - B1 - Banque Assurance »), d'où
    # deux fiches. Table EXPLICITE alias → fiche canonique :
    # backend/src/modules/catalog/catalog-dedupe.ts (OMNES_PROGRAM_ID_ALIASES).
    #
    # La fiche canonique reçoit, à la FIN de `campusOfferings`, les offres de
    # ses alias qu'elle n'a pas, et perd le campus resté collé dans son
    # intitulé ; chaque alias passe hors ligne (`isActive = false`), rien n'est
    # supprimé. Les ids d'automne ne bougent pas. Écriture sous
    # `WHERE updatedAt = …` (retouche de l'admin gardée). Rejouable : « 0
    # écriture ». À passer AVANT `import-omnes-spring`. Runbook :
    # docs/runbook-rentrees-partenaires.md.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run dedupe:omnes
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run dedupe:omnes -- --apply
      echo
      echo "── Intégrité du catalogue ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  import-igensia)
    # Crée les écoles du groupe IGENSIA Education (IGENSIA School of Business,
    # IGENSIA Tech, IGENSIA RH, American Business College) et leurs formations,
    # depuis `backend/scripts/data/igensia_2027.csv` et `abc_2027.csv`.
    #
    # Même mécanique qu'`import-omnes-spring` : une école déjà en base n'est
    # jamais réécrite (seules ses rentrées et formations manquantes sont
    # ajoutées), une formation déjà en base ne reçoit que ses offres
    # manquantes. Les faits relevés sur les sites officiels (fiche RNCP,
    # langue, durée et admission d'ABC — backend/scripts/data/
    # igensia_2027.sources.md) COMBLENT une colonne déjà en base seulement si
    # elle est vide ou telle que la première version l'avait écrite. ESA Casablanca (`partner-esa-casa`) n'est pas touchée.
    # Rejouable : « 0 écriture » une fois appliqué.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run import:igensia
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run import:igensia -- --apply
      echo
      echo "── Intégrité du catalogue ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  import-north-america)
    # Crée des universités NON partenaires (`isPartner: false`) du Canada et
    # des États-Unis et leurs formations phares, depuis
    # `backend/scripts/data/amerique-du-nord-2027.json` (provenance fait par
    # fait : `amerique-du-nord-2027.sources.md` ; sélection et critères :
    # docs/catalogue-amerique-du-nord.md).
    #
    # CRÉATION SEULE : une ligne déjà en base n'est jamais réécrite (seuls les
    # ids des formations manquantes sont ajoutés à `programIds`), un homonyme
    # déjà en base sous un autre id (Université d'Ottawa, `uottawa`) bloque la
    # création. Rejouable : « 0 écriture » une fois appliqué. Runbook :
    # docs/runbook-catalogue-amerique-du-nord.md.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run import:north-america
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run import:north-america -- --apply
      echo
      echo "── Intégrité du catalogue ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  backfill-tuition-eur)
    # Renseigne `Program.tuitionMinEur` depuis le libellé `tuitionFr`.
    #
    # La colonne est nulle sur les 628 programmes, donc le score budgétaire de
    # matches.service.ts est neutralisé et chaque match est marqué `isEstimate`.
    # 350 programmes portent déjà un montant en euros : il n'y a rien à
    # convertir, seulement à lire.
    #
    # N'écrit que là où la colonne est nulle, et le revérifie à l'instant de
    # l'écriture — une valeur saisie à la main n'est jamais écrasée.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run backfill:tuition-eur
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run backfill:tuition-eur -- --apply
    fi
    ;;

  fix-mundiapolis-levels)
    # Corrige les 4 niveaux hors référentiel écrits par l'import du 16/09.
    #
    # `normalizeDegreeLevel` laisse passer TEL QUEL ce qu'il ne reconnaît pas :
    # « Spécialité » et « Prépa » sont donc arrivés en production, où ils
    # s'affichent dans le filtre par niveau à côté de Bachelor et Master.
    #
    # Les niveaux de remplacement ne sont pas déduits — chacun vient d'une page
    # de l'université, dont l'URL est inscrite dans `sourceUrl` à l'écriture.
    #
    # L'écriture est conditionnée à la valeur actuelle (`WHERE levelFr = …`) :
    # une fiche corrigée entre-temps depuis la page Catalogue du back-office
    # n'est pas écrasée, et l'opération est rejouable.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run fix:mundiapolis-levels
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run fix:mundiapolis-levels -- --apply
    fi
    ;;

  import-universiapolis)
    # Crée Universiapolis et ses 6 formations.
    #
    # Écartée de l'import CSV du 16/09 : ses 15 lignes étaient des ANNÉES
    # D'ENTRÉE tarifées (« 1re année », « 2e année »…), pas des formations.
    # `normalizeDegreeLevel` les aurait laissées passer telles quelles, et l'app
    # aurait affiché « 2e année » comme un niveau de diplôme.
    #
    # Les diplômes viennent des pages de l'université, reportées dans
    # `sourceUrl`. `tuitionMinEur` est calculé au taux dirham que l'université
    # publie elle-même — première fois que ce taux couvre une ligne en base.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run import:universiapolis
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run import:universiapolis -- --apply
      echo
      echo "── Intégrité des références pays ──"
      docker compose exec -T api npm run verify:catalog
    fi
    ;;

  reconcile-program-ids)
    # Réaligne `Institution.programIds` sur les lignes `Program` réelles.
    #
    # Cette liste dénormalisée est LUE par six écrans de l'app : nombre de
    # formations affiché, aperçu des trois premières, navigation depuis la fiche
    # pays — DÉSACTIVÉE quand la liste est vide —, comparateur qui compte et
    # trie dessus, première formation du profil, filtrage de la recherche.
    #
    # Rien en base ne la lie aux lignes `Program` : une formation peut exister
    # sans être atteignable, et aucune erreur ne le signale. Mesuré le 18/09 :
    # 3 établissements sur 68, soit 48 formations invisibles, dont les 46 de
    # Mundiapolis créées par l'import du 16/09.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run reconcile:program-ids
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run reconcile:program-ids -- --apply
    fi
    ;;

  backfill-seed-institutions)
    # Comble overview et location des 2 institutions « seed » créées avant
    # l'import partenaire (ESSEC et uOttawa). L'écriture est conditionnée à
    # un champ VIDE — une saisie manuelle n'est jamais écrasée.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run backfill:seed-institutions
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run backfill:seed-institutions -- --apply
    fi
    ;;

  eef-import)
    # Importe le catalogue « Études en France » (lignes INACTIVES, jamais
    # vérifiées) puis comble les colonnes des versions 1.1 et 1.2.
    #
    # Ce que l'action ne fait PAS : publier. Une ligne importée n'est visible de
    # personne ; la publication, par établissement et par cycle, passe par
    # l'admin (`POST /admin/catalog/eef/institutions/:id/publish`), sous le nom du
    # vérificateur authentifié — pas par un texte libre saisi ici.
    #
    # `eef:import` est CRÉATION SEULE : une ligne dont l'identifiant existe déjà
    # n'est jamais mise à jour (`existingNotUpdated`). Corriger une règle après
    # l'import passe par `eef-purge-pending`, puis un nouvel import.
    #
    # Garde : l'import n'a de sens que sur un backend qui EXCLUT ces lignes du
    # catalogue général, des recommandations et de la file de revérification
    # (`common/eef-provenance`). Sans lui, les ~10 500 lignes s'ajouteraient à la
    # file `/verification` comme « jamais vérifiées ». On refuse donc d'écrire
    # tant que le conteneur ne porte pas ce fichier.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run eef:import:dry-run
      docker compose exec -T api npm run eef:backfill:cycle:dry-run
      docker compose exec -T api npm run eef:backfill:admission:dry-run
      docker compose exec -T api npm run eef:backfill:search:dry-run
      docker compose exec -T api npm run eef:backfill -- --dry-run
    else
      if ! docker compose exec -T api test -f dist/common/eef-provenance.js; then
        echo "::error::Le backend déployé ne porte pas la frontière de l'import « Études en France » (dist/common/eef-provenance.js absent). Déployer le backend d'abord : importer maintenant ajouterait ~10 500 lignes à la file /verification."
        exit 1
      fi
      echo "── APPLICATION ──"
      docker compose exec -T api npm run eef:import
      docker compose exec -T api npm run eef:backfill:cycle
      docker compose exec -T api npm run eef:backfill:admission
      docker compose exec -T api npm run eef:backfill:search
      docker compose exec -T api npm run eef:backfill -- --apply
      echo
      echo "── Preuve : un second passage ne crée plus rien ──"
      docker compose exec -T api npm run eef:import:dry-run
    fi
    ;;

  eef-purge-pending)
    # Supprime les lignes de l'import « Études en France » qui n'ont JAMAIS été
    # publiées ni vérifiées, pour qu'un nouvel `eef-import` les recrée avec les
    # règles corrigées (domaine, procédure…). Voir `eef-pending-purge.ts`.
    #
    # Refuse de toucher une ligne publiée, vérifiée, ou référencée par
    # l'utilisateur (favoris, comparaison, dossiers, correspondances). Une
    # simulation dit exactement ce qui serait supprimé, et ce qui est protégé.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run eef:purge-pending -- --dry-run
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run eef:purge-pending -- --apply
    fi
    ;;

  eef-publish)
    # Publie l'import « Études en France » (établissements, puis formations) POUR
    # LE COMPTE d'un administrateur, par le même service que l'écran admin. Voir
    # `eef-delegated-publication.ts` : même plan, même transaction par
    # établissement, même « tout ou rien ». Ce que l'outil ajoute : une simulation
    # complète d'abord, un total à ressaisir pour écrire, les formations dont la
    # page-source a disparu laissées en attente, et un tampon qui dit « publication
    # déléguée » plutôt que d'attribuer une relecture une à une.
    #
    # Rend le catalogue lisible par l'API publique (`/etudes-en-france/search` n'exige
    # aucune session), mais aucune build ne l'affiche tant que `features.eefSpace` est
    # faux (action `eef-space-on`) : publier n'ouvre pas l'espace.
    #
    # Les valeurs libres sont REVALIDÉES ici : le workflow les a déjà bornées, mais
    # ce script ne fait confiance à aucune variable d'environnement qu'il reçoit.
    check_shape() { # nom valeur motif
      if [ -n "$2" ] && ! [[ "$2" =~ $3 ]]; then
        echo "::error::$1 n'a pas la forme attendue — refus."
        exit 1
      fi
    }
    check_shape EEF_VERIFIER_EMAIL "${EEF_VERIFIER_EMAIL:-}" '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    check_shape EEF_EXPECTED_PROGRAMS "${EEF_EXPECTED_PROGRAMS:-}" '^[0-9]{1,6}$'
    check_shape EEF_INSTITUTION_ID "${EEF_INSTITUTION_ID:-}" '^eef-univ-[A-Za-z0-9-]{1,60}$'
    check_shape EEF_ACTOR "${EEF_ACTOR:-}" '^[A-Za-z0-9][A-Za-z0-9-]{0,38}(\[bot\])?$'
    check_shape EEF_EXCLUDE_PROCEDURE "${EEF_EXCLUDE_PROCEDURE:-}" '^(aucune|hors_eef|dap_jaune|parcoursup)$'
    publish_args=()
    case "${EEF_EXCLUDE_PROCEDURE:-aucune}" in
      aucune) ;;
      *) publish_args+=(--exclude-procedure "$EEF_EXCLUDE_PROCEDURE") ;;
    esac
    [ -z "${EEF_VERIFIER_EMAIL:-}" ] || publish_args+=(--verifier-email "$EEF_VERIFIER_EMAIL")
    [ -z "${EEF_INSTITUTION_ID:-}" ] || publish_args+=(--institution "$EEF_INSTITUTION_ID")
    [ -z "${EEF_ACTOR:-}" ] || publish_args+=(--actor "$EEF_ACTOR")
    # On n'écrit que sur un « false » explicite : toute autre valeur (« True », vide)
    # reste en simulation, parce que l'erreur de frappe doit tomber du côté sûr.
    if [ "$DRY_RUN" != "false" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run eef:publish -- --dry-run ${publish_args[@]+"${publish_args[@]}"}
    else
      if [ -z "${EEF_EXPECTED_PROGRAMS:-}" ]; then
        echo "::error::expected_programs est obligatoire pour écrire : relancer la simulation, puis saisir le « TOTAL publiable » qu'elle annonce."
        exit 1
      fi
      if ! docker compose exec -T api test -f dist/common/eef-provenance.js; then
        echo "::error::Le backend déployé ne porte pas la frontière de l'import « Études en France » (dist/common/eef-provenance.js absent) : publier exposerait ces lignes sans que le catalogue général les écarte."
        exit 1
      fi
      echo "── APPLICATION ──"
      docker compose exec -T api npm run eef:publish -- --apply --expect-programs "$EEF_EXPECTED_PROGRAMS" ${publish_args[@]+"${publish_args[@]}"}
    fi
    ;;

  reviews-purge-orphans)
    # Supprime les avis conseillers ORPHELINS : sans auteur, dossier disparu ou
    # jamais renseigné. Ne touche ni un avis signé ni un avis sans auteur dont le
    # dossier existe encore. N'imprime que des décomptes. Voir
    # `orphan-reviews.ts` pour le pourquoi (et pourquoi supprimer).
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run reviews:purge-orphans -- --dry-run
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run reviews:purge-orphans -- --apply
    fi
    ;;

  eef-reconcile)
    # Réaligne les formations « Études en France » DÉJÀ en base — publiées ou en
    # attente — sur les règles du dépôt : procédure, sélectivité, exigences FR/EN.
    # Voir `eef-catalog.reconcile.ts`. N'écrit ni la publication (`isActive`), ni le
    # tampon de vérification, ni l'intitulé ; une formation retouchée dans l'admin
    # est SIGNALÉE et laissée telle quelle. Une transaction et une trace d'audit par
    # établissement ; l'écriture applique les listes exactes de la simulation.
    #
    # Le backend déployé doit porter les règles à appliquer : c'est le code du
    # conteneur qui calcule le plan. Déployer la PR d'abord, puis simuler.
    check_shape() { # nom valeur motif
      if [ -n "$2" ] && ! [[ "$2" =~ $3 ]]; then
        echo "::error::$1 n'a pas la forme attendue — refus."
        exit 1
      fi
    }
    check_shape EEF_EXPECTED_PROGRAMS "${EEF_EXPECTED_PROGRAMS:-}" '^[0-9]{1,6}$'
    check_shape EEF_INSTITUTION_ID "${EEF_INSTITUTION_ID:-}" '^eef-univ-[A-Za-z0-9-]{1,60}$'
    check_shape EEF_ACTOR "${EEF_ACTOR:-}" '^[A-Za-z0-9][A-Za-z0-9-]{0,38}(\[bot\])?$'
    if ! docker compose exec -T api test -f scripts/reconcile-eef-catalog.ts; then
      echo "::error::Le backend déployé ne porte pas eef:reconcile (scripts/reconcile-eef-catalog.ts absent) : déployer d'abord la PR qui l'apporte."
      exit 1
    fi
    reconcile_args=()
    [ -z "${EEF_INSTITUTION_ID:-}" ] || reconcile_args+=(--institution "$EEF_INSTITUTION_ID")
    [ -z "${EEF_ACTOR:-}" ] || reconcile_args+=(--actor "$EEF_ACTOR")
    # On n'écrit que sur un « false » explicite, comme `eef-publish`.
    if [ "$DRY_RUN" != "false" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run eef:reconcile -- --dry-run ${reconcile_args[@]+"${reconcile_args[@]}"}
    else
      if [ -z "${EEF_EXPECTED_PROGRAMS:-}" ]; then
        echo "::error::expected_programs est obligatoire pour écrire : relancer la simulation, puis saisir le total « À RÉALIGNER » qu'elle annonce."
        exit 1
      fi
      echo "── APPLICATION ──"
      docker compose exec -T api npm run eef:reconcile -- --apply --expect-programs "$EEF_EXPECTED_PROGRAMS" ${reconcile_args[@]+"${reconcile_args[@]}"}
    fi
    ;;

  *)
    echo "::error::ACTION inconnue : $ACTION"
    exit 2
    ;;
esac
