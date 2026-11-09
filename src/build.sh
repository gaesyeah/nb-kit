#!/usr/bin/env bash
# Builds the NetBeans modules of nbkit from the Java code in src/, against the jars of an Apache NetBeans
# installation, and updates their sha256 (lib/jars/SHA256SUMS and modules/jsf/module.toml).
#   bash src/build.sh [netbeans folder]
# Without the folder: NB_HOME, or the NetBeans that last used ~/.netbeans. Needs a JDK 17 or newer (javac, jar).
set -euo pipefail
trap 'exit 130' INT TERM HUP
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NBKIT_DIR="$(dirname "$SRC")"
NB=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lang=*) NBKIT_LANG="${1#--lang=}" ;;
    --lang) NBKIT_LANG="${2:-}"; [ $# -gt 1 ] && shift ;;
    *) NB="$1" ;;
  esac
  shift
done
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/terminal.sh"

# ---------- NetBeans and JDK ----------
find_netbeans() {
  local f inst d logs=()
  if [ -n "${NB_HOME:-}" ]; then echo "$NB_HOME"; return 0; fi
  # newest log first
  mapfile -t logs < <(find "$HOME"/.netbeans -path '*/var/log/messages.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
  for f in ${logs[@]+"${logs[@]}"}; do
    inst="$(sed -n 's/^ *Installation *= *//p' "$f" | tail -1)"
    if [ -n "$inst" ] && [ -d "$(dirname "$inst")/platform" ]; then dirname "$inst"; return 0; fi
  done
  if command -v netbeans >/dev/null 2>&1; then
    d="$(dirname "$(dirname "$(readlink -f "$(command -v netbeans)")")")"
    [ -d "$d/platform" ] && { echo "$d"; return 0; }
  fi
  return 1
}
[ -n "$NB" ] || NB="$(find_netbeans || true)"
[ -n "$NB" ] && [ -d "$NB/platform" ] || die "$(t build.no_netbeans)"
NB="$(readlink -f "$NB")"
JAVAC="${JAVA_HOME:+$JAVA_HOME/bin/}javac"
JAR="${JAVA_HOME:+$JAVA_HOME/bin/}jar"
command -v "$JAVAC" >/dev/null 2>&1 && command -v "$JAR" >/dev/null 2>&1 || die "$(t build.no_jdk)"
JV="$("$JAVAC" -version 2>&1 | sed -n 's/^javac \([0-9][0-9]*\).*/\1/p' | tail -1)"
[ -n "$JV" ] && [ "$JV" -ge 17 ] || die "$(t build.old_jdk "${JV:-?}")"
info "$(t build.using "$NB" "$("$JAVAC" -version 2>&1 | grep '^javac' | tail -1)")"

# NetBeans API jars to compile against
mapfile -t JARS < <(find "$NB" -name '*.jar' \( -path '*/modules/*' -o -path '*/core/*' -o -path '*/lib/*' \) | sort)
[ ${#JARS[@]} -gt 0 ] || die "$(t build.no_netbeans)"
CP="$(IFS=:; echo "${JARS[*]}")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# build <src folder> <output jar>
build() {
  local name="$1" out="$2" dir="$TMP/$1"
  step "$(t build.step "$name")"
  mkdir -p "$dir"
  mapfile -t java < <(find "$SRC/$name/src" -name '*.java' | sort)
  "$JAVAC" --release 17 -encoding UTF-8 -nowarn -d "$dir" -cp "$CP" "${java[@]}"
  cp -r "$SRC/$name/res/." "$dir/"
  rm -f "$out"
  (cd "$dir" && "$JAR" cfm "$out" "$SRC/$name/manifest.mf" .)
  ok "$(t build.done "${out#"$NBKIT_DIR"/}")"
}
sum_of() { sha256sum "$1" | cut -d' ' -f1; }

TOTAL=4
build nbkit-core "$NBKIT_DIR/lib/jars/nbkit-core.jar"
build nbkit-colors "$NBKIT_DIR/lib/jars/nbkit-colors.jar"
build nbkit-jsf "$NBKIT_DIR/modules/jsf/nbkit-jsf.jar"

step "$(t build.step_sums)"
(cd "$NBKIT_DIR/lib/jars" && sha256sum nbkit-colors.jar nbkit-core.jar > SHA256SUMS)
sed -i "s/^sha256 = \"[0-9a-f]*\"/sha256 = \"$(sum_of "$NBKIT_DIR/modules/jsf/nbkit-jsf.jar")\"/" "$NBKIT_DIR/modules/jsf/module.toml"
ok "lib/jars/SHA256SUMS, modules/jsf/module.toml"
echo
t build.finished; echo
