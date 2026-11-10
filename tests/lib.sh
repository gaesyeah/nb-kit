# shellcheck shell=bash
# Helpers shared by the test scripts: counters, assertions and a fake home with a NetBeans userdir.
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NBKIT_DIR="$(dirname "$TESTS")"
export LC_ALL=C.UTF-8 NBKIT_LANG=en NBKIT_OFFLINE=1
# no fonts of the machine (tests/bin/fc-list): with the theme font installed the theme files would differ
export PATH="$TESTS/bin:$PATH"
# run from the interface ("Run the tests"): the nbkit runs inside the tests must not send it their steps
unset NBKIT_UI_EVENTS NBKIT_TTY
PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'; else G=; R=; D=; N=; fi

pass() { PASS=$((PASS + 1)); printf '  %sok%s    %s\n' "$G" "$N" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  %sFAIL%s  %s\n' "$R" "$N" "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; return 0; }
# check <description> <command...>: passes when the command succeeds
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi; }
# contains <description> <text> <expected part>
contains() { if grep -qF -- "$3" <<<"$2"; then pass "$1"; else fail "$1" "expected: $3"$'\n'"got:"$'\n'"$(tail -15 <<<"$2")"; fi; }
lacks() { if grep -qF -- "$3" <<<"$2"; then fail "$1" "unexpected: $3"; else pass "$1"; fi; }
finish() {
  echo
  if [ "$FAIL" = 0 ]; then printf '%s%d passed%s\n' "$G" "$PASS" "$N"; else printf '%s%d failed%s, %d passed\n' "$R" "$FAIL" "$N" "$PASS"; fi
  [ "$FAIL" = 0 ]
}

# new_home <dir>: a home with a NetBeans 31 userdir that already has some settings of its own
new_home() {
  local h="$1" u="$1/.netbeans/31"
  rm -rf "$h"
  mkdir -p "$u/var/log" "$u/config/LookAndFeel" "$u/config/Editors/FontsColors/FlatLafDark" \
    "$u/config/Editors/text/x-java/FontsColors/FlatLafDark"
  printf '  Installation            = %s\n  Java Home               = /nonexistent\n  Java; VM; Vendor        = 21.0.5; OpenJDK 64-Bit Server VM\n' \
    "$TESTS/netbeans/platform" > "$u/var/log/messages.log"
  printf '@myKey=#123456\nComponent.arc=8\n' > "$u/config/LookAndFeel/FlatDarkLaf.properties"
  cat > "$u/config/Editors/FontsColors/FlatLafDark/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml" <<'X'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" "https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">
<fontscolors>
    <fontcolor name="default"><font name="Fira Code" size="15"/></fontcolor>
</fontscolors>
X
  cp "$u/config/Editors/FontsColors/FlatLafDark/"*.xml "$u/config/Editors/text/x-java/FontsColors/FlatLafDark/"
}
# NetBeans opened after the install: the log lists the enabled modules ($2...)
nb_opened() {
  local u="$1/.netbeans/31" m
  sleep 1
  { head -3 "$u/var/log/messages.log"; echo 'INFO: Turning on modules:'; for m in "${@:2}"; do printf '\t%s [1.0]\n' "$m"; done; } > "$u/var/log/messages.log.new"
  mv "$u/var/log/messages.log.new" "$u/var/log/messages.log"
}
# fingerprint of the userdir: one "sha1  path" per file (without the log and the backups, which have dates)
fingerprint() {
  (cd "$1/.netbeans/31" && find . -type f ! -path './var/*' ! -name '*.tar.gz' ! -name .lastModified -print0 | sort -z | xargs -0 sha1sum)
}
