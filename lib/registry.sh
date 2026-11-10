# shellcheck shell=bash
# Module registry: every theme and tool registers here (nbkit_register), and the helpers the engines
# share (version, files, jars, NetBeans module xml, check results). Used by nbkit.sh.

# ---------- module registry ----------
# nbkit_register <id> <function prefix> <category: theme|tool> <name> <description> <version>
MODS=()
declare -A MOD_FN=() MOD_CAT=() MOD_NAME=() MOD_DESC=() MOD_VER=()
nbkit_register() {
  MODS+=("$1"); MOD_FN[$1]="$2"; MOD_CAT[$1]="$3"; MOD_NAME[$1]="$4"; MOD_DESC[$1]="$5"; MOD_VER[$1]="$6"
}
# calls <prefix>_<function> of the module; returns 0 doing nothing if the module does not have it
mod_call() {
  local id="$1" fn="${MOD_FN[$1]}_$2"; shift 2
  if declare -F "$fn" >/dev/null; then "$fn" "$@"; fi
}
mod_has() { declare -F "${MOD_FN[$1]}_$2" >/dev/null; }
mod_status() { mod_call "$1" status; }  # no | ok | old:<v> | new:<v>
# compares the installed version (file nbkit/<id>.version, or the legacy one given in $2) with this nbkit's
version_status() {
  local v; v="$(cat "$(mod_version_file "$1")" 2>/dev/null || echo "${2:-}")"
  if [ -z "$v" ]; then echo "old:?"
  elif [ "$v" = "${MOD_VER[$1]}" ]; then echo ok
  elif [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -gt "${MOD_VER[$1]}" ]; then echo "new:$v"
  else echo "old:$v"; fi
}
mod_installed() { [ "$(mod_status "$1")" != no ]; }
mod_label() {
  local id="$1"
  if [ "${MOD_CAT[$id]}" = theme ]; then t cli.theme_label "${MOD_NAME[$id]}"; echo; else echo "${MOD_NAME[$id]}"; fi
}


# ---------- files shared by the engines ----------
# copies a file and checks its sha256 (catches a broken download of nbkit)
file_copy() { cp "$1" "$2" && echo "$3  $2" | sha256sum -c --quiet -; }
# copies one of the base jars of lib/jars/, checked against lib/jars/SHA256SUMS
jar_copy() {
  local sum; sum="$(awk -v f="$1" '$2 == f {print $1}' "$NBKIT_DIR/lib/jars/SHA256SUMS")"
  [ -n "$sum" ] && file_copy "$NBKIT_DIR/lib/jars/$1" "$2" "$sum"
}
# config/Modules/<name>.xml that turns a module on in NetBeans
module_xml() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="$1">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/${1//./-}.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
}

# ---------- helpers for the engines ----------
# file with the installed version of a module in the userdir
mod_version_file() { echo "$STATEDIR/$1.version"; }
# temporary folder deleted at the end
tmpdir() { local d; d="$(mktemp -d)"; CLEAN+=("$d"); echo "$d"; }
res() {
  if [ "$1" = 0 ]; then printf '  %s%-9s%s%s\n' "$G" "$(t cli.res_ok)" "$N" "$2"
  else printf '  %s%-9s%s%s\n' "$R" "$(t cli.res_problem)" "$N" "$2"; fi
}
log_has_module() { grep -qE "^\s+$1 \[" "$UD/var/log/messages.log" 2>/dev/null; }
log_module_errors() { grep -E "$1" "$UD/var/log/messages.log" 2>/dev/null | grep -E 'could not|cannot|Exception|SEVERE|disabled|requires' | head -5 || true; }
