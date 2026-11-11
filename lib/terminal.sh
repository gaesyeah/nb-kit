# shellcheck shell=bash
# Terminal output shared by nbkit.sh and src/build.sh: colors, language (lang/<id>.lang) and the
# step/ok/info/warn/die helpers. Needs NBKIT_DIR; --lang is read by whoever sources this file (NBKIT_LANG).

if [ -t 1 ]; then B=$'\e[1m'; BL=$'\e[1;34m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else B=; BL=; G=; Y=; R=; D=; N=; fi
# the Python parts of the modules (e.g. check) use the same colors
export NBKIT_G="$G" NBKIT_Y="$Y" NBKIT_R="$R" NBKIT_D="$D" NBKIT_N="$N"

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

# ---------- events for the graphical interface ----------
# json_str <text>: the text as a JSON string
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\t'/\\t}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\e'/\\u001b}"
  printf '"%s"' "$s"
}
# ui_event <json object>: with the interface (NBKIT_UI_EVENTS = its file), one event per line; otherwise nothing
ui_event() { if [ -n "${NBKIT_UI_EVENTS:-}" ]; then printf '%s\n' "$1" >> "$NBKIT_UI_EVENTS"; fi; return 0; }
STEP=0; TOTAL=0
step() {
  STEP=$((STEP + 1))
  # tests only: simulates a failure at this step, to check that everything goes back (tests/engine.sh)
  if [ "${NBKIT_TEST_FAIL_STEP:-}" = "$STEP" ]; then die "NBKIT_TEST_FAIL_STEP=$STEP"; fi
  printf '%s[%d/%d]%s %s\n' "$BL" "$STEP" "$TOTAL" "$N" "$*"
  ui_event "{\"ev\":\"step\",\"n\":$STEP,\"total\":$TOTAL,\"text\":$(json_str "$*")}"
  # tests only: stops at this step until interrupted (tests/gui.sh closes the window there)
  if [ "${NBKIT_TEST_PAUSE_STEP:-}" = "$STEP" ]; then sleep 120; fi
}
ok()   { printf '      %s✓%s %s\n' "$G" "$N" "$*"; }
info() { printf '      %s%s%s\n' "$D" "$*" "$N"; }
warn() { printf '      %s!%s %s\n' "$Y" "$N" "$*"; }

# ---------- yes/no ----------
# yes/no question; the uppercase letter is the Enter default (Y or N in $2).
# With the interface it also becomes a dialog there, which answers by typing here (see lib/gui/model.py).
ask_yn() {
  local a hint; hint="$(t cli.yn_no)"; [ "$2" = Y ] && hint="$(t cli.yn_yes)"
  printf '%s %s ' "$1" "$hint"
  ui_event "{\"ev\":\"ask\",\"text\":$(json_str "$1"),\"default\":\"$2\"}"
  IFS= read -r a </dev/tty || a=""
  ui_event '{"ev":"answered"}'
  a="${a,,}"
  if [ -z "$a" ]; then [ "$2" = Y ]; return; fi
  case "$a" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}

# ---------- interactive terminal: arrow key menu, spinner, header ----------
# arrow key menu; result in MENU_IDX (-1 = left with Esc or q). MENU_HINT changes the legend.
menu() {
  local -a o=("$@"); local n=$# i=${MENU_START:-0} j k rest
  [ "$i" -lt "$n" ] || i=0
  printf '\e[?25l'; trap 'printf "\e[?25h\n"; exit 130' INT
  while :; do
    for ((j = 0; j < n; j++)); do
      if [ $j -eq $i ]; then printf '\r\e[K  %s> %s%s\n' "$BL$B" "${o[j]}" "$N"
      else printf '\r\e[K    %s\n' "${o[j]}"; fi
    done
    printf '\r\e[K  %s%s%s' "$D" "${MENU_HINT:-$(t cli.menu_hint)}" "$N"
    IFS= read -rsn1 k </dev/tty || k=q
    if [ "$k" = $'\e' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case "$rest" in '[A'|OA) k=up ;; '[B'|OB) k=down ;; '') k=q ;; *) k=x ;; esac
    fi
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      '') break ;;
      q) i=-1; break ;;
    esac
    printf '\r\e[%dA' "$n"
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
  MENU_IDX=$i
}

# spinner until the condition is true; any key cancels (returns 1)
spin_until() {
  local sp='|/-\' i=0 k cancel; cancel="$(t cli.enter_cancels)"
  printf '\e[?25l'; trap 'printf "\r\e[K\e[?25h"; exit 130' INT
  while ! "$2"; do
    printf '\r\e[K  %s%s%s %s  %s%s%s' "$Y" "${sp:i%4:1}" "$N" "$1" "$D" "$cancel" "$N"; i=$((i + 1))
    if IFS= read -rsn1 -t 0.25 k </dev/tty; then
      IFS= read -rsn5 -t 0.05 k </dev/tty || true
      printf '\r\e[K\e[?25h'; trap 'exit 130' INT; return 1
    fi
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
}

HEADER=0
header() { [ $HEADER = 1 ] || echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"; HEADER=1; }
