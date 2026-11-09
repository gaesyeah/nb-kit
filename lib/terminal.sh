# shellcheck shell=bash
# Terminal output shared by nbkit.sh and src/build.sh: colors, language (lang/<id>.lang) and the
# step/ok/info/warn/die helpers. Needs NBKIT_DIR; --lang is read by whoever sources this file (NBKIT_LANG).

if [ -t 1 ]; then B=$'\e[1m'; BL=$'\e[1;34m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else B=; BL=; G=; Y=; R=; D=; N=; fi
# the Python parts of the modules (e.g. check) use the same colors
export NBKIT_G="$G" NBKIT_R="$R" NBKIT_D="$D" NBKIT_N="$N"

# ---------- language ----------
# lang/<id>.lang: one "key=value" per line, # for comments. Values are printf formats (%s, \n) and may use
# {B} {N} {D} {G} {Y} {R} {BL} for bold, normal, dim and colors. pt-BR is the reference: missing keys come from it.
# language: --lang, NBKIT_LANG or the system one (LC_ALL, LC_MESSAGES, LANG); without a file for it, English
lang_pick() {
  local want="${NBKIT_LANG:-}" l c
  if [ -z "$want" ]; then
    l="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"; l="${l%%.*}"; l="${l%%@*}"
    case "$l" in pt*) want=pt-BR ;; ''|C|POSIX) want=en ;; *) want="${l/_/-}" ;; esac
  fi
  for c in "$want" "${want%%-*}" en; do
    if [ -f "$NBKIT_DIR/lang/$c.lang" ]; then echo "$c"; return 0; fi
  done
  echo pt-BR
}
declare -A L=()
lang_load() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    L["${line%%=*}"]="${line#*=}"
  done < "$1"
}
NBKIT_LANG="$(lang_pick)"
export NBKIT_LANG
lang_load "$NBKIT_DIR/lang/pt-BR.lang"
[ "$NBKIT_LANG" = pt-BR ] || lang_load "$NBKIT_DIR/lang/$NBKIT_LANG.lang"
# the Python parts of the modules read the same files
NBKIT_LANG_FILES="$NBKIT_DIR/lang/pt-BR.lang"$'\n'"$NBKIT_DIR/lang/$NBKIT_LANG.lang"
export NBKIT_LANG_FILES
# t <key> [args...]: prints the text of the key, filling %s with the args
t() {
  local f="${L[$1]-$1}"; shift
  f="${f//\{BL\}/$BL}"; f="${f//\{B\}/$B}"; f="${f//\{N\}/$N}"; f="${f//\{D\}/$D}"
  f="${f//\{G\}/$G}"; f="${f//\{Y\}/$Y}"; f="${f//\{R\}/$R}"
  # shellcheck disable=SC2059
  printf -- "$f" "$@"
}

die() { echo "${R}$(t cli.error)${N} $*" >&2; exit 1; }
STEP=0; TOTAL=0
step() {
  STEP=$((STEP + 1))
  # tests only: simulates a failure at this step, to check that everything goes back (tests/engine.sh)
  if [ "${NBKIT_TEST_FAIL_STEP:-}" = "$STEP" ]; then die "NBKIT_TEST_FAIL_STEP=$STEP"; fi
  printf '%s[%d/%d]%s %s\n' "$BL" "$STEP" "$TOTAL" "$N" "$*"
}
ok()   { printf '      %s✓%s %s\n' "$G" "$N" "$*"; }
info() { printf '      %s%s%s\n' "$D" "$*" "$N"; }
warn() { printf '      %s!%s %s\n' "$Y" "$N" "$*"; }

# ---------- yes/no ----------
# yes/no question; the uppercase letter is the Enter default (Y or N in $2)
ask_yn() {
  local a hint; hint="$(t cli.yn_no)"; [ "$2" = Y ] && hint="$(t cli.yn_yes)"
  printf '%s %s ' "$1" "$hint"
  IFS= read -r a </dev/tty || a=""
  a="${a,,}"
  if [ -z "$a" ]; then [ "$2" = Y ]; return; fi
  case "$a" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}
