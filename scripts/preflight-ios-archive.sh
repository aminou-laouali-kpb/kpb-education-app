#!/usr/bin/env bash
# Préflight iOS strict — valide l'artefact signé, pas seulement ses métadonnées.
#
# Usage, APRÈS une archive App Store créée dans Xcode Organizer :
#   scripts/preflight-ios-archive.sh \
#     --xcconfig ios/Flutter/Generated.xcconfig \
#     --archive-plist path/to/Runner.xcarchive/Products/Applications/Runner.app/Info.plist
#
# `--app path/to/Runner.app` peut remplacer `--archive-plist`. Lorsque les deux
# sont fournis, ils doivent désigner le même bundle. Le script ne construit rien,
# ne lit aucun trousseau et n'affiche aucune valeur de secret.
#
# Contrôle de la seule clé PostHog, JUSTE APRÈS `flutter build ios` (avant Xcode,
# sans bundle ni outil de signature) :
#   scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --posthog-only
# Sort en 0 avec la longueur et le verdict ; en 1 si la clé est absente, vide,
# doublée ou mal formée, ou si un repli compilé KPB_EEF_*_ENABLED est à true.
# La clé n'est JAMAIS affichée.

set -euo pipefail

XCCONFIG=""
ARCHIVE_PLIST=""
APP_PATH=""
POSTHOG_ONLY=0

EXPECTED_BUILD="57"
EXPECTED_VERSION="2.3.1"
EXPECTED_BUNDLE_ID="Karatou.karatou"
EXPECTED_TEAM_ID="DNPB788LKX"

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcconfig) XCCONFIG="${2:-}"; shift 2 ;;
    --archive-plist) ARCHIVE_PLIST="${2:-}"; shift 2 ;;
    --app) APP_PATH="${2:-}"; shift 2 ;;
    --posthog-only) POSTHOG_ONLY=1; shift ;;
    -h|--help) usage ;;
    *) echo "Argument inconnu : $1" >&2; usage ;;
  esac
done

fail() { echo "PREFLIGHT ÉCHEC : $*" >&2; exit 1; }

[[ -n "$XCCONFIG" ]] || usage
[[ -f "$XCCONFIG" ]] || {
  echo "Generated.xcconfig introuvable : $XCCONFIG" >&2
  echo "Ce script ne construit rien. Passez le fichier produit par Flutter." >&2
  exit 2
}

# ── DART_DEFINES et clé PostHog ──────────────────────────────────────────────
#
# Décodé en mémoire, jamais affiché : il peut porter des clés de service.
#
# UN define = UNE ligne de DECODED, toujours. Une valeur peut contenir un saut de
# ligne (une clé PostHog en deux lignes dans le presse-papiers, `$(pbpaste)`) :
# imprimée telle quelle, elle devenait plusieurs « lignes », la garde ne lisait que
# la première, et « phc_<43>\nphc_<43> » sortait « une seule clé … OK » pour une
# valeur compilée de 95 caractères. Chaque \r et \n d'une valeur est donc remplacé
# par U+001F (un caractère de contrôle qui n'est pas une fin de ligne) : la longueur
# reste exacte, la valeur ne passe plus aucune expression de format, et elle ne peut
# pas fabriquer une seconde définition « NOM=… ».
DECODED=""
decode_dart_defines() {
  local defines
  defines=$(grep -E '^DART_DEFINES=' "$XCCONFIG" | head -1 | cut -d= -f2-) || true
  [[ -n "$defines" ]] || fail "DART_DEFINES vide dans $XCCONFIG"
  DECODED=$(python3 - "$defines" <<'PY'
import base64
import sys

for chunk in sys.argv[1].split(","):
    chunk = chunk.strip()
    if not chunk:
        continue
    padding = "=" * (-len(chunk) % 4)
    value = base64.b64decode(chunk + padding).decode("utf-8", "strict")
    print(value.replace("\r", "\x1f").replace("\n", "\x1f"))
PY
  ) || fail "DART_DEFINES n'est pas un ensemble base64 valide"
}

# La clé PostHog COMPILÉE, jouée et non seulement lue.
#
# Le 04/10/2026, deux constructions de la 55 ont été faites avec une clé fausse : la
# première VIDE, la seconde DOUBLÉE (« phc_…phc_… » : la saisie de `read -rs` et la
# commande de construction collées d'un coup). L'ancien contrôle — préfixe `phc_`
# et 40 caractères au moins — acceptait la seconde, et `strings … | grep -c '^phc_'`
# n'y voit qu'une clé. Une clé de projet réelle est `phc_` suivi d'une quarantaine
# de lettres et de chiffres, rien d'autre : le format est donc exigé en entier.
#
# La clé n'est JAMAIS affichée, même refusée : un message donne sa longueur et
# son verdict, jamais sa valeur (le journal d'un préflight se partage).
check_posthog_key() {
  local count key len occurrences
  count=$(printf '%s\n' "$DECODED" | grep -c '^POSTHOG_API_KEY=' || true)
  [[ "$count" != "0" ]] || \
    fail "DART_DEFINES sans choix explicite POSTHOG_API_KEY="
  [[ "$count" == "1" ]] || \
    fail "POSTHOG_API_KEY définie $count fois dans DART_DEFINES : une seule définition est permise, laquelle l'emporte n'est pas garanti."
  key=$(printf '%s\n' "$DECODED" | sed -n 's/^POSTHOG_API_KEY=//p' | tail -1)
  len=${#key}
  # La clé doit être PRÉSENTE, pas seulement « choisie explicitement ».
  #
  # Le contrôle acceptait la chaîne vide — un « choix explicite » de désactiver
  # PostHog. C'était juste tant que la clé n'existait pas. Elle existe depuis le
  # 26/08 (secret GitHub), et la build 50 est quand même partie sans elle :
  # `flutter build ios` a régénéré le xcconfig sans le define, l'archive a été
  # construite par-dessus, et le préflight a dit oui. La télémétrie produit de
  # cette build est perdue, définitivement.
  #
  # Accepter le vide, c'est laisser le même oubli passer une seconde fois — et
  # l'oubli est silencieux par nature : rien, dans l'app, ne signale que PostHog
  # ne parle pas. Pour désactiver PostHog volontairement, il faut désormais
  # éditer cette garde, ce qui laisse une trace en revue.
  [[ -n "$key" ]] || \
    fail "POSTHOG_API_KEY VIDE. La build 50 est partie ainsi et sa télémétrie est perdue. Reconstruire avec --dart-define=POSTHOG_API_KEY=phc_…"
  [[ "$key" == phc_* ]] || \
    fail "POSTHOG_API_KEY renseignée ($len caractères) mais format public phc_… invalide"
  # Un `phc_` de trois caractères passerait le préfixe et livrerait une clé morte
  # — le mode d'échec que DEPLOYMENT.md met en garde en toutes lettres.
  [[ $len -ge 40 ]] || \
    fail "POSTHOG_API_KEY trop courte ($len caractères) : ressemble à un exemple recopié, pas à une clé de projet"
  if ! printf '%s' "$key" | LC_ALL=C grep -Eq '^phc_[A-Za-z0-9]{30,60}$'; then
    occurrences=$(printf '%s' "$key" | grep -o 'phc_' | wc -l | tr -d '[:space:]')
    if [[ "$occurrences" -gt 1 ]]; then
      fail "POSTHOG_API_KEY invalide : $len caractères et $occurrences occurrences de phc_ — la clé a été collée deux fois. Une clé de projet n'en porte qu'une. Refaire la saisie SEULE, puis la construction (docs/mise-a-jour-57-checklist.md, étape 4)."
    fi
    fail "POSTHOG_API_KEY invalide : $len caractères ; attendu phc_ suivi de 30 à 60 lettres ou chiffres, sans espace, tiret, guillemet ni autre caractère."
  fi
  echo "POSTHOG_API_KEY : $len caractères, une seule clé phc_ au format attendu — OK"
}

# Aucun repli COMPILÉ « Études en France » allumé.
#
# `AppConfig.eefSpaceEnabled`, `eefHelpBubbleEnabled`, `eefPrivateSchoolsEnabled`
# lisent `bool.fromEnvironment('KPB_EEF_…')` quand `/config/app` ne sert pas la clé
# ou est injoignable ; or le backend de production (couplage `tolerates-old`) ne
# sert ni `eefHelpBubble` ni `eefPrivateSchools`. Un binaire compilé avec l'un de
# ces defines à `true` montrerait donc l'espace, la bulle ou la feuille « écoles
# privées » au relecteur Apple, quoi qu'on écrive côté serveur (`eef-bubble-off`
# n'écrit que dans le .env d'un backend qui ne sert pas la clé). La checklist dit
# « aucun define » ; ce contrôle le REFUSE, et il tourne aussi en `--posthog-only`
# pour que la vérification juste après `flutter build ios` l'attrape.
#
# Seul `=true` compte : `bool.fromEnvironment` ne lit que la chaîne exacte « true ».
# Une définition répétée n'a pas de gagnante garantie : un seul `true` suffit à
# refuser, même précédé d'un `false`. Les valeurs ne sont jamais affichées : seul
# le NOM du define l'est.
check_no_open_eef_defines() {
  local name offenders=""
  for name in KPB_EEF_ENABLED KPB_EEF_SPACE_ENABLED \
              KPB_EEF_HELP_BUBBLE_ENABLED KPB_EEF_PRIVATE_SCHOOLS_ENABLED; do
    if printf '%s\n' "$DECODED" | grep -Fxq "$name=true"; then
      offenders="$offenders $name"
    fi
  done
  [[ -z "$offenders" ]] || \
    fail "repli compilé EEF allumé :$offenders=true. Ces interrupteurs sont SERVEUR : la 57 se construit sans aucun --dart-define KPB_EEF_* (l'espace, la bulle et les écoles privées s'ouvrent par /config/app). Reconstruire sans eux (docs/mise-a-jour-57-checklist.md, étape 4)."
  echo "Replis compilés EEF : aucun define KPB_EEF_*_ENABLED à true — OK"
}

if [[ "$POSTHOG_ONLY" == "1" ]]; then
  command -v python3 >/dev/null 2>&1 || {
    echo "Outil requis introuvable : python3" >&2
    exit 2
  }
  decode_dart_defines
  check_posthog_key
  check_no_open_eef_defines
  exit 0
fi

if [[ -z "$APP_PATH" && -n "$ARCHIVE_PLIST" ]]; then
  [[ "$(basename "$ARCHIVE_PLIST")" == "Info.plist" ]] || \
    fail "--archive-plist doit désigner le Info.plist racine d'un .app"
  APP_PATH="$(dirname "$ARCHIVE_PLIST")"
fi
[[ -n "$APP_PATH" ]] || usage
[[ -d "$APP_PATH" && "${APP_PATH##*.}" == "app" ]] || \
  fail "bundle .app introuvable : $APP_PATH"

APP_PLIST="$APP_PATH/Info.plist"
[[ -f "$APP_PLIST" ]] || fail "Info.plist absent du bundle : $APP_PLIST"
if [[ -n "$ARCHIVE_PLIST" ]]; then
  [[ -f "$ARCHIVE_PLIST" ]] || fail "Info.plist d'archive introuvable : $ARCHIVE_PLIST"
  cmp -s "$ARCHIVE_PLIST" "$APP_PLIST" || \
    fail "--archive-plist ne correspond pas au bundle donné par --app"
fi

for tool in codesign security plutil python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Outil macOS requis introuvable : $tool" >&2
    exit 2
  }
done

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kpb-ios-preflight.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

plist_get() {
  python3 - "$1" "$2" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    value = plistlib.load(handle)
for part in sys.argv[2].split("."):
    if not isinstance(value, dict) or part not in value:
        raise SystemExit(3)
    value = value[part]
if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, list):
    print("\n".join(str(item) for item in value))
else:
    print(value)
PY
}

# Flutter build contract. Decode in memory and never print DART_DEFINES because
# it can contain client-side service keys.
NUMBER=$(grep -E '^FLUTTER_BUILD_NUMBER=' "$XCCONFIG" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[[ "$NUMBER" == "$EXPECTED_BUILD" ]] || \
  fail "FLUTTER_BUILD_NUMBER=$NUMBER (attendu $EXPECTED_BUILD)"

NAME=$(grep -E '^FLUTTER_BUILD_NAME=' "$XCCONFIG" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[[ "$NAME" == "$EXPECTED_VERSION" ]] || \
  fail "FLUTTER_BUILD_NAME=$NAME (attendu $EXPECTED_VERSION)"

decode_dart_defines

printf '%s\n' "$DECODED" | grep -Fxq 'KPB_APP_ENV=prod' || \
  fail "DART_DEFINES sans KPB_APP_ENV=prod"
WHATSAPP=$(printf '%s\n' "$DECODED" | sed -n 's/^KPB_WHATSAPP_NUMBER=//p' | tail -1)
[[ -n "$WHATSAPP" && "$WHATSAPP" != *'<'* && "$WHATSAPP" != *'>'* ]] || \
  fail "KPB_WHATSAPP_NUMBER absent ou placeholder"

check_posthog_key
check_no_open_eef_defines

API_OVERRIDE=$(printf '%s\n' "$DECODED" | sed -n 's/^KPB_API_BASE_URL=//p' | tail -1)
if [[ -n "$API_OVERRIDE" && "$API_OVERRIDE" != https://* ]]; then
  fail "KPB_API_BASE_URL de production doit utiliser https://"
fi

# Identity and public metadata.
BUNDLE_ID=$(plist_get "$APP_PLIST" CFBundleIdentifier) || fail "CFBundleIdentifier absent"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || \
  fail "CFBundleIdentifier=$BUNDLE_ID (attendu $EXPECTED_BUNDLE_ID)"
VERSION=$(plist_get "$APP_PLIST" CFBundleShortVersionString) || fail "version marketing absente"
[[ "$VERSION" == "$EXPECTED_VERSION" ]] || \
  fail "CFBundleShortVersionString=$VERSION (attendu $EXPECTED_VERSION)"
BUILD=$(plist_get "$APP_PLIST" CFBundleVersion) || fail "CFBundleVersion absent"
[[ "$BUILD" == "$EXPECTED_BUILD" ]] || \
  fail "CFBundleVersion=$BUILD (attendu $EXPECTED_BUILD)"

ORIENTATION=$(plist_get "$APP_PLIST" UISupportedInterfaceOrientations) || fail "orientations absentes"
[[ "$ORIENTATION" == "UIInterfaceOrientationPortrait" ]] || \
  fail "orientations archive = [$ORIENTATION]"
# Famille d'appareils ET orientations iPad : deux règles d'Apple, couplées. Elles
# ne laissent qu'UNE configuration valide, et ce préflight a laissé passer les
# deux bundles qui la violaient — d'où ce contrôle.
#
#  · 90101 — on ne peut PAS retirer une famille d'appareils d'une app DÉJÀ
#    publiée. La fiche (id 1128659292) est universelle depuis toujours, donc
#    UIDeviceFamily doit contenir 2. Tenté en iPhone-only sur la 49 : refusé.
#  · 90474 — un bundle qui embarque l'iPad doit déclarer les QUATRE orientations
#    iPad (multitâche). Tenté en portrait-only sur la 49 : refusé.
#
# Seule issue : famille [1,2] + 4 orientations iPad — exactement la build 48,
# acceptée. L'iPhone reste portrait-only (aucune contrainte de multitâche), et
# le verrou runtime (SystemChrome.portraitUp, lockPortraitOrientation) garde
# l'UI en portrait sur les DEUX familles : déclarer les 4 orientations iPad
# n'autorise donc aucune rotation réelle.
DEVICE_FAMILY=$(plist_get "$APP_PLIST" UIDeviceFamily) || fail "UIDeviceFamily absent"
DEVICE_FAMILY_FLAT=$(printf '%s' "$DEVICE_FAMILY" | tr '\n' ',')
printf '%s\n' "$DEVICE_FAMILY" | grep -Fxq '2' || \
  fail "UIDeviceFamily=[$DEVICE_FAMILY_FLAT] : l'iPad manque. Retirer une famille d'appareils d'une app publiée = rejet 90101. Garder TARGETED_DEVICE_FAMILY=\"1,2\"."
IPAD=$(plist_get "$APP_PLIST" 'UISupportedInterfaceOrientations~ipad') || \
  fail "UISupportedInterfaceOrientations~ipad absent alors que le bundle embarque l'iPad"
IPAD_FLAT=$(printf '%s' "$IPAD" | tr '\n' ',')
IPAD_COUNT=$(printf '%s\n' "$IPAD" | grep -c .)
[[ "$IPAD_COUNT" == "4" ]] || \
  fail "orientations iPad=[$IPAD_FLAT] : un bundle iPad doit déclarer les 4 orientations (multitâche), sinon rejet 90474."
BACKGROUND=$(plist_get "$APP_PLIST" UIBackgroundModes) || fail "UIBackgroundModes absent"
[[ "$BACKGROUND" == "remote-notification" ]] || \
  fail "UIBackgroundModes archive = [$BACKGROUND]"
LOCALIZATIONS=$(plist_get "$APP_PLIST" CFBundleLocalizations) || fail "localisations absentes"
[[ "$LOCALIZATIONS" == "fr" ]] || fail "CFBundleLocalizations = [$LOCALIZATIONS]"
FIREBASE_ANALYTICS_DEFAULT=$(plist_get "$APP_PLIST" FIREBASE_ANALYTICS_COLLECTION_ENABLED) || \
  fail "FIREBASE_ANALYTICS_COLLECTION_ENABLED absent"
[[ "$FIREBASE_ANALYTICS_DEFAULT" == "false" ]] || \
  fail "Firebase Analytics doit démarrer désactivé"
CRASHLYTICS_DEFAULT=$(plist_get "$APP_PLIST" FirebaseCrashlyticsCollectionEnabled) || \
  fail "FirebaseCrashlyticsCollectionEnabled absent"
[[ "$CRASHLYTICS_DEFAULT" == "false" ]] || \
  fail "Firebase Crashlytics doit démarrer désactivé"

# The app-level privacy manifest must survive the archive resource phase.
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "PrivacyInfo.xcprivacy absent du bundle signé"
plutil -lint "$PRIVACY_MANIFEST" >/dev/null || fail "PrivacyInfo.xcprivacy invalide"
TRACKING=$(plist_get "$PRIVACY_MANIFEST" NSPrivacyTracking) || \
  fail "NSPrivacyTracking absent du manifeste de confidentialité"
[[ "$TRACKING" == "false" ]] || fail "NSPrivacyTracking doit être false"

# Verify the actual signature and its identity. An unsigned archive, an ad-hoc
# signature, or Apple Development must never pass a store preflight.
codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1 || \
  fail "signature codesign absente ou invalide"
SIGNING=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1) || fail "signature illisible"
printf '%s\n' "$SIGNING" | grep -Eq '^Authority=(Apple Distribution|iPhone Distribution)' || \
  fail "l'app n'est pas signée avec un certificat Apple Distribution"
printf '%s\n' "$SIGNING" | grep -Fxq "Identifier=$EXPECTED_BUNDLE_ID" || \
  fail "l'identifiant codesign n'est pas $EXPECTED_BUNDLE_ID"
printf '%s\n' "$SIGNING" | grep -Fxq "TeamIdentifier=$EXPECTED_TEAM_ID" || \
  fail "le TeamIdentifier codesign n'est pas $EXPECTED_TEAM_ID"

ENTITLEMENTS="$TMP_DIR/entitlements.plist"
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS" 2>/dev/null || \
  fail "entitlements codesign illisibles"
plutil -lint "$ENTITLEMENTS" >/dev/null || fail "entitlements codesign invalides"
APS=$(plist_get "$ENTITLEMENTS" aps-environment) || fail "aps-environment absent de la signature"
[[ "$APS" == "production" ]] || fail "aps-environment=$APS (attendu production)"
if DEBUGGABLE=$(plist_get "$ENTITLEMENTS" get-task-allow 2>/dev/null); then
  [[ "$DEBUGGABLE" == "false" ]] || fail "get-task-allow=true : build de développement"
fi
APP_IDENTIFIER=$(plist_get "$ENTITLEMENTS" application-identifier) || \
  fail "application-identifier absent des entitlements"
[[ "$APP_IDENTIFIER" == "$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID" ]] || \
  fail "application-identifier inattendu"

# App Store provisioning profile: production push, no registered devices,
# non-debuggable, correct team/bundle, and currently valid.
PROFILE="$APP_PATH/embedded.mobileprovision"
[[ -f "$PROFILE" ]] || fail "embedded.mobileprovision absent"
PROFILE_PLIST="$TMP_DIR/profile.plist"
security cms -D -i "$PROFILE" >"$PROFILE_PLIST" 2>/dev/null || \
  fail "profil de provisioning illisible"
plutil -lint "$PROFILE_PLIST" >/dev/null || fail "profil de provisioning invalide"

PROFILE_TEAM=$(plist_get "$PROFILE_PLIST" TeamIdentifier) || fail "TeamIdentifier absent du profil"
[[ "$PROFILE_TEAM" == "$EXPECTED_TEAM_ID" ]] || fail "profil rattaché à une autre équipe"
PROFILE_APP_ID=$(plist_get "$PROFILE_PLIST" Entitlements.application-identifier) || \
  fail "application-identifier absent du profil"
[[ "$PROFILE_APP_ID" == "$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID" ]] || \
  fail "profil destiné à un autre bundle"
PROFILE_APS=$(plist_get "$PROFILE_PLIST" Entitlements.aps-environment) || \
  fail "aps-environment absent du profil"
[[ "$PROFILE_APS" == "production" ]] || fail "profil APNs non-production"
PROFILE_DEBUG=$(plist_get "$PROFILE_PLIST" Entitlements.get-task-allow) || \
  fail "get-task-allow absent du profil"
[[ "$PROFILE_DEBUG" == "false" ]] || fail "profil de développement (get-task-allow=true)"
PROFILE_BETA=$(plist_get "$PROFILE_PLIST" Entitlements.beta-reports-active) || \
  fail "profil non App Store (beta-reports-active absent)"
[[ "$PROFILE_BETA" == "true" ]] || fail "profil non App Store"
if plist_get "$PROFILE_PLIST" ProvisionedDevices >/dev/null 2>&1; then
  fail "profil Ad Hoc/de développement : ProvisionedDevices présent"
fi
if ALL_DEVICES=$(plist_get "$PROFILE_PLIST" ProvisionsAllDevices 2>/dev/null); then
  [[ "$ALL_DEVICES" == "false" ]] || fail "profil Enterprise : ProvisionsAllDevices=true"
fi
python3 - "$PROFILE_PLIST" <<'PY' || fail "profil de provisioning expiré"
import datetime
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    expiration = plistlib.load(handle).get("ExpirationDate")
if not isinstance(expiration, datetime.datetime):
    raise SystemExit(1)
now = datetime.datetime.now(datetime.timezone.utc)
if expiration.replace(tzinfo=datetime.timezone.utc) <= now:
    raise SystemExit(1)
PY

# Le message se compose à partir des valeurs VÉRIFIÉES. Il annonçait
# « 2.1.0 (49) » en dur alors que le script exigeait déjà la 53 : un
# rapport de succès qui ment sur ce qu'il a contrôlé est pire qu'un rapport
# absent. Même défaut, même correctif que côté Android.
echo "Préflight iOS OK — ${EXPECTED_VERSION} (${EXPECTED_BUILD}), ${EXPECTED_BUNDLE_ID}, Apple Distribution, APNs production, profil App Store, confidentialité embarquée."
