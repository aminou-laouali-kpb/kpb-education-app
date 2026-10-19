#!/usr/bin/env bash
# Validate the signed Android App Bundle that will be uploaded to Play.
#
# Usage:
#   scripts/preflight-android-aab.sh \
#     --aab build/app/outputs/bundle/release/app-release.aab \
#     --expected-cert-sha256 AA:BB:...:FF
#
# The expected SHA-256 is the PUBLIC upload-certificate fingerprint shown in
# Play Console → App integrity. It may alternatively be supplied through
# KPB_ANDROID_UPLOAD_CERT_SHA256. This script never opens a keystore.

set -euo pipefail

AAB=""
EXPECTED_CERT="${KPB_ANDROID_UPLOAD_CERT_SHA256:-}"
EXPECTED_PACKAGE="com.karatou.android"
EXPECTED_VERSION_NAME="2.3.1"
EXPECTED_VERSION_CODE="57"
EXPECTED_TARGET_SDK="36"

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aab) AAB="${2:-}"; shift 2 ;;
    --expected-cert-sha256) EXPECTED_CERT="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Argument inconnu : $1" >&2; usage ;;
  esac
done

fail() { echo "PREFLIGHT ÉCHEC : $*" >&2; exit 1; }

[[ -n "$AAB" && -f "$AAB" ]] || usage
[[ -s "$AAB" ]] || fail "AAB vide : $AAB"
[[ -n "$EXPECTED_CERT" ]] || \
  fail "empreinte publique absente (--expected-cert-sha256 ou KPB_ANDROID_UPLOAD_CERT_SHA256)"

for tool in openssl unzip python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Outil requis introuvable : $tool" >&2
    exit 2
  }
done

# macOS exposes /usr/bin/jarsigner and /usr/bin/keytool even when no system JDK
# is configured; those stubs then fail at runtime. Prefer the configured JDK,
# with Android Studio's bundled JDK as the local fallback.
JAVA_RUNTIME_HOME="${JAVA_HOME:-}"
if [[ -z "$JAVA_RUNTIME_HOME" || ! -x "$JAVA_RUNTIME_HOME/bin/java" ]]; then
  if [[ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]]; then
    JAVA_RUNTIME_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  elif command -v java >/dev/null 2>&1; then
    JAVA_BIN=$(command -v java)
    JAVA_RUNTIME_HOME=$(cd "$(dirname "$JAVA_BIN")/.." && pwd)
  fi
fi
[[ -n "$JAVA_RUNTIME_HOME" && -x "$JAVA_RUNTIME_HOME/bin/jarsigner" && \
   -x "$JAVA_RUNTIME_HOME/bin/keytool" ]] || {
  echo "JDK requis introuvable. Définissez JAVA_HOME vers un JDK 17+." >&2
  exit 2
}
JARSIGNER_BIN="$JAVA_RUNTIME_HOME/bin/jarsigner"
KEYTOOL_BIN="$JAVA_RUNTIME_HOME/bin/keytool"

normalize_fingerprint() {
  printf '%s' "$1" | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]'
}

EXPECTED_CERT=$(normalize_fingerprint "$EXPECTED_CERT")
[[ "$EXPECTED_CERT" =~ ^[0-9A-F]{64}$ ]] || \
  fail "l'empreinte SHA-256 attendue doit contenir 64 chiffres hexadécimaux"

# AABs use JAR signing. Self-signed upload certificates are normal, so do not
# use jarsigner -strict (it promotes that expected condition to an error).
"$JARSIGNER_BIN" -verify "$AAB" >/dev/null 2>&1 || fail "signature JAR de l'AAB invalide"
CERT_DETAILS=$("$KEYTOOL_BIN" -printcert -jarfile "$AAB" 2>/dev/null) || \
  fail "certificat de signature absent de l'AAB"
printf '%s\n' "$CERT_DETAILS" | grep -Eiq 'Owner:.*Android Debug|Owner:.*CN=Android Debug' && \
  fail "l'AAB est signé avec le certificat Android Debug"
ACTUAL_CERT=$(printf '%s\n' "$CERT_DETAILS" | sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -1)
ACTUAL_CERT=$(normalize_fingerprint "$ACTUAL_CERT")
[[ "$ACTUAL_CERT" == "$EXPECTED_CERT" ]] || \
  fail "le certificat de l'AAB ne correspond pas au certificat d'importation Play"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kpb-android-preflight.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
"$KEYTOOL_BIN" -printcert -rfc -jarfile "$AAB" >"$TMP_DIR/upload-cert.pem" 2>/dev/null || \
  fail "impossible d'extraire le certificat public"
openssl x509 -in "$TMP_DIR/upload-cert.pem" -checkend 0 -noout >/dev/null 2>&1 || \
  fail "certificat d'importation expiré"

unzip -tq "$AAB" >/dev/null || fail "conteneur AAB corrompu"
unzip -Z1 "$AAB" | grep -Fxq 'base/manifest/AndroidManifest.xml' || \
  fail "manifeste base absent de l'AAB"

BUNDLETOOL_JAR="${BUNDLETOOL_JAR:-}"
[[ -n "$BUNDLETOOL_JAR" && -f "$BUNDLETOOL_JAR" ]] || {
  echo "bundletool-all introuvable. Définissez BUNDLETOOL_JAR vers le JAR CLI autonome." >&2
  exit 2
}

# An AAB is not an APK: its base manifest is protobuf XML, which aapt2 cannot
# read from the bundle archive. bundletool-all is the Android-supported,
# standalone decoder supplied explicitly by the release workflow.
MANIFEST_DUMP="$TMP_DIR/manifest.xml"
"$JAVA_RUNTIME_HOME/bin/java" -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$AAB" >"$MANIFEST_DUMP" || \
  fail "manifeste AAB illisible par bundletool"

grep -Fq "package=\"$EXPECTED_PACKAGE\"" "$MANIFEST_DUMP" || \
  fail "applicationId différent de $EXPECTED_PACKAGE"
grep -Fq "android:versionCode=\"$EXPECTED_VERSION_CODE\"" "$MANIFEST_DUMP" || \
  fail "versionCode différent de $EXPECTED_VERSION_CODE"
grep -Fq "android:versionName=\"$EXPECTED_VERSION_NAME\"" "$MANIFEST_DUMP" || \
  fail "versionName différent de $EXPECTED_VERSION_NAME"
grep -Fq "android:targetSdkVersion=\"$EXPECTED_TARGET_SDK\"" "$MANIFEST_DUMP" || \
  fail "targetSdkVersion différent de $EXPECTED_TARGET_SDK"

grep -Fq 'com.google.android.gms.permission.AD_ID' "$MANIFEST_DUMP" && \
  fail "permission publicitaire AD_ID présente dans le manifeste fusionné"
grep -Fq 'android.permission.QUERY_ALL_PACKAGES' "$MANIFEST_DUMP" && \
  fail "permission QUERY_ALL_PACKAGES interdite présente"

python3 - "$MANIFEST_DUMP" <<'PY' || fail "collecteurs natifs non désactivés par défaut"
import sys
import xml.etree.ElementTree as ET

android = '{http://schemas.android.com/apk/res/android}'
root = ET.parse(sys.argv[1]).getroot()
for key in (
    "google_analytics_adid_collection_enabled",
    "firebase_analytics_collection_enabled",
    "firebase_crashlytics_collection_enabled",
):
    entries = [
        entry for entry in root.findall('.//meta-data')
        if entry.get(android + 'name') == key
    ]
    if len(entries) != 1 or entries[0].get(android + 'value') != 'false':
        raise SystemExit(1)
PY

# Le message se compose à partir des valeurs VÉRIFIÉES. Il annonçait « (49) »
# en dur alors que le script exigeait déjà la 51 : un rapport de succès qui
# ment sur ce qu'il a contrôlé est pire qu'un rapport absent.
echo "Préflight Android OK — ${EXPECTED_VERSION_NAME} (${EXPECTED_VERSION_CODE}), ${EXPECTED_PACKAGE}, SDK ${EXPECTED_TARGET_SDK}, certificat Play concordant, AD_ID absent."
