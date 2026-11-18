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
# yes/no question; the uppercase letter is the Enter default (Y or N in $2). An optional third argument is a
# detail (why, what happened) sent to the interface dialog (see lib/gui/model.py): the terminal output is the
# caller's, so the caller decides what to show above the question.
ask_yn() {
  local a hint d=""; hint="$(t cli.yn_no)"; [ "$2" = Y ] && hint="$(t cli.yn_yes)"
  if [ -n "${3:-}" ]; then d=",\"detail\":$(json_str "$3")"; fi
  printf '%s %s ' "$1" "$hint"
  ui_event "{\"ev\":\"ask\",\"text\":$(json_str "$1")${d},\"default\":\"$2\"}"
  IFS= read -r a </dev/tty || a=""
  ui_event '{"ev":"answered"}'
  a="${a,,}"
  if [ -z "$a" ]; then [ "$2" = Y ]; return; fi
  case "$a" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}

# ---------- interactive terminal: arrow key menu, spinner, header ----------
# menu_key: the next key in KEY: up, down, del, '' (Enter), q (Esc, or q itself) or what was typed. Read one character at a
# time: after an Esc, only [ or O make an arrow key; anything else typed right after it (another Esc: pressed twice
# fast, back twice) is its own key, kept in MENU_PENDING for the next read (that may be the menu above, after a
# submenu) instead of being lost
MENU_PENDING=""
menu_key() {
  local k c=""
  if [ -n "$MENU_PENDING" ]; then
    k="$MENU_PENDING"; MENU_PENDING=""
    # a kept Esc is known to be alone: nothing after it belongs to it
    if [ "$k" = $'\e' ]; then KEY=q; return 0; fi
  else
    IFS= read -rsn1 k </dev/tty || { KEY=q; return 0; }
  fi
  if [ "$k" != $'\e' ]; then KEY="$k"; return 0; fi
  IFS= read -rsn1 -t 0.05 c </dev/tty || true
  case "$c" in
    '') KEY=q ;;
    '['|O)
      IFS= read -rsn1 -t 0.05 c </dev/tty || true
      case "$c" in
        A) KEY=up ;;
        B) KEY=down ;;
        3) KEY=del; IFS= read -rsn1 -t 0.05 c </dev/tty || true ;;   # Delete: \e[3~
        *) KEY=x ;;
      esac ;;
    *) KEY=q; MENU_PENDING="$c" ;;
  esac
}
# arrow key menu; result in MENU_IDX (-1 = left with Esc or q). MENU_HINT changes the legend; MENU_TIPS (one per
# option, like the tooltips of the interface) shows what the chosen one does, on a line of its own
menu() {
  local -a o=("$@") tips=(); local n=$# i=${MENU_START:-0} j k l=0 tip
  [ "$i" -lt "$n" ] || i=0
  # each tip folded to the width of the terminal, all with as many lines as the longest one, so the menu keeps
  # its height while the cursor moves (a line wrapped by the terminal would break the redrawing)
  if [ ${#MENU_TIPS[@]} -gt 0 ]; then
    for ((j = 0; j < n; j++)); do
      tips[j]="$(printf '%s' "${MENU_TIPS[j]:-}" | fold -s -w $(( $(tput cols 2>/dev/null || echo 80) - 4 )))"
      k=$(printf '%s\n' "${tips[j]}" | wc -l); [ "$k" -gt $l ] && l=$k
    done
  fi
  printf '\e[?25l'; trap 'printf "\e[?25h\n"; exit 130' INT
  while :; do
    for ((j = 0; j < n; j++)); do
      if [ $j -eq $i ]; then printf '\r\e[K  %s> %s%s\n' "$BL$B" "${o[j]}" "$N"
      else printf '\r\e[K    %s\n' "${o[j]}"; fi
    done
    if [ $l -gt 0 ]; then
      tip="${tips[i]}"
      for ((j = 0; j < l; j++)); do printf '\r\e[K  %s%s%s\n' "$D" "${tip%%$'\n'*}" "$N"; [[ "$tip" == *$'\n'* ]] && tip="${tip#*$'\n'}" || tip=""; done
    fi
    printf '\r\e[K  %s%s%s' "$D" "${MENU_HINT:-$(t cli.menu_hint)}" "$N"
    menu_key; k="$KEY"
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      '') break ;;
      q) i=-1; break ;;
    esac
    printf '\r\e[%dA' $((n + l))
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
  # the tip lines go too: the cursor ends right below the options, as without tips
  for ((j = 0; j < l; j++)); do printf '\e[1A\r\e[K'; done
  MENU_IDX=$i
}

# spinner until the condition is true; any key cancels (returns 1)
spin_until() {
  local sp='|/-\' i=0 k cancel line cols=0; cancel="$(t cli.enter_cancels)"
  [ -t 1 ] && cols="$(tput cols 2>/dev/null || echo 80)"
  printf '\e[?25l'; trap 'printf "\r\e[K\e[?25h"; exit 130' INT
  # the keyboard is read only when someone can answer (a terminal, the interface); otherwise it only waits
  local keys=0; { [ -t 0 ] || [ "${NBKIT_TTY:-}" = 1 ]; } && keys=1
  while ! "$2"; do
    # $3: a function telling how far it got, shown instead of the text once it says something; cut to the width of a
    # terminal (a wrapped line cannot be redrawn in place)
    line=""; [ -n "${3:-}" ] && line="$("$3")"; line="${line:-$1}"
    [ "$cols" -gt 0 ] && [ ${#line} -gt $((cols - ${#cancel} - 8)) ] && line="${line:0:$((cols - ${#cancel} - 9))}…"
    printf '\r\e[K  %s%s%s %s  %s%s%s' "$Y" "${sp:i%4:1}" "$N" "$line" "$D" "$cancel" "$N"; i=$((i + 1))
    if [ $keys = 0 ]; then sleep 0.25; continue; fi
    if IFS= read -rsn1 -t 0.25 k </dev/tty; then
      IFS= read -rsn5 -t 0.05 k </dev/tty || true
      printf '\r\e[K\e[?25h'; trap 'exit 130' INT; return 1
    fi
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
}

HEADER=0
header() { [ $HEADER = 1 ] || echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"; HEADER=1; }
