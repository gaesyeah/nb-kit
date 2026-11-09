# shellcheck shell=bash
# nbkit engine for NetBeans modules: each folder in modules/ with a module.toml and its jar becomes a module
# in the menu, with install, uninstall and check. The Python part is lib/modules.py. See modules/README.md.

declare -A NBMOD_DIR=() NBMOD_JAR=() NBMOD_CODE=() NBMOD_SUM=() NBMOD_HINT=() NBMOD_GOES=() NBMOD_STAYS=()
# nbmod_register <id> <prefix> <name> <description> <version> <folder> <jar> <codename> <sha256> <hint> <goes> <stays>
nbmod_register() {
  local id="$1" p="$2" f
  nbkit_register "$id" "$p" tool "$3" "$4" "$5"
  NBMOD_DIR[$id]="$6"; NBMOD_JAR[$id]="$7"; NBMOD_CODE[$id]="$8"; NBMOD_SUM[$id]="$9"
  NBMOD_HINT[$id]="${10}"; NBMOD_GOES[$id]="${11}"; NBMOD_STAYS[$id]="${12}"
  for f in status paths install_steps uninstall_steps uninstall_summary install uninstall check; do
    eval "${p}_$f() { nbmod_$f $id \"\$@\"; }"
  done
}

# where the module goes in the userdir: modules/<codename with dashes>.jar and config/Modules/<same>.xml
nbmod_files() {
  local n="${NBMOD_CODE[$1]//./-}"
  MJAR="$UD/modules/$n.jar"; MXML="$UD/config/Modules/$n.xml"
}

nbmod_status() {
  nbmod_files "$1"
  if [ -e "$MJAR" ]; then version_status "$1"; else echo no; fi
}

nbmod_paths() {
  local n="${NBMOD_CODE[$1]//./-}"
  printf '%s\n' "modules/$n.jar" "config/Modules/$n.xml"
}

nbmod_install_steps() { echo 1; }
nbmod_uninstall_steps() { echo 1; }

nbmod_uninstall_summary() {
  if [ -n "${NBMOD_GOES[$1]}" ]; then t mod.summary_out "${NBMOD_GOES[$1]}"; echo; fi
  if [ -n "${NBMOD_STAYS[$1]}" ]; then t mod.summary_stays "${NBMOD_STAYS[$1]}"; echo; fi
}

nbmod_install() {
  local id="$1" src
  nbmod_files "$id"
  src="${NBMOD_DIR[$id]}/${NBMOD_JAR[$id]}"
  step "$(t mod.step_install "${MOD_NAME[$id]}")"
  mkdir -p "$UD/modules" "$UD/config/Modules"
  file_copy "$src" "$MJAR" "${NBMOD_SUM[$id]}" || die "$(t mod.corrupt "${src#"$NBKIT_DIR"/}")"
  module_xml "${NBMOD_CODE[$id]}" > "$MXML"
  touch "$UD/.lastModified"
  ok "$(t mod.copied)"
  if [ -n "${NBMOD_HINT[$id]}" ]; then info "${NBMOD_HINT[$id]}"; fi
}

nbmod_uninstall() {
  nbmod_files "$1"
  step "$(t mod.step_uninstall "${MOD_NAME[$1]}")"
  rm -f "$MJAR" "$MXML"
  touch "$UD/.lastModified"
  ok "$(t mod.removed)"
}

nbmod_check() {
  local code="${NBMOD_CODE[$1]}" errs
  errs="$(log_module_errors "${code//./\\.}|${code//.//}")"
  if log_has_module "${code//./\\.}" && [ -z "$errs" ]; then
    res 0 "$(t mod.check_loaded)"
    return 0
  fi
  res 1 "$(t mod.check_missing)"
  [ -n "$errs" ] && printf '%s\n' "$errs" | sed 's/^/           /'
  if grep -qE 'requires|Java' <<<"$errs"; then return 2; fi
  return 1
}

eval "$("$NBKIT_PY" "$NBKIT_DIR/lib/modules.py" "$NBKIT_DIR/modules")"
