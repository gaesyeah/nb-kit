# shellcheck shell=bash
# nbkit tools engine: each folder in modules/tools/ is a tool, described in tool.toml (no code). The engine
# gives every tool the whole nbkit contract (status, install, uninstall, check, restore point...). What a tool
# installs:
#   [netbeans_module] in tool.toml   a NetBeans module (jar): copied, enabled, checked in the log, removed
#   tool.sh next to it (optional)    anything specific: it redefines the contract functions it needs and can call
#                                    the tool_* helpers below (see modules/README.md)
# The Python part is lib/tools/load.py.

declare -A TOOL_DIR=() TOOL_HINT=() TOOL_JAR=() TOOL_CODE=() TOOL_SUM=() TOOL_GOES=() TOOL_STAYS=()
# tool_register <id> <name> <description> <version> <folder> <hint> <jar> <codename> <sha256> <goes> <stays>
tool_register() {
  local id="$1" p f
  p="tool_${id//-/_}"
  nbkit_register "$id" "$p" tool "$2" "$3" "$4"
  TOOL_DIR[$id]="$5"; TOOL_HINT[$id]="$6"; TOOL_JAR[$id]="$7"; TOOL_CODE[$id]="$8"; TOOL_SUM[$id]="$9"
  TOOL_GOES[$id]="${10}"; TOOL_STAYS[$id]="${11}"
  # the contract of every tool points to the engine; tool.sh (loaded right after) may redefine any of them
  for f in status paths install_steps uninstall_steps uninstall_summary install uninstall check; do
    eval "${p}_$f() { tool_$f $id \"\$@\"; }"
  done
}

# ---------- the NetBeans module of the tool ----------
# where it goes in the userdir: modules/<codename with dashes>.jar and config/Modules/<same>.xml
tool_module_name() { local n="${TOOL_CODE[$1]}"; echo "${n//./-}"; }
tool_has_module() { [ -n "${TOOL_CODE[$1]}" ]; }

tool_module_install() {
  local id="$1" n src
  n="$(tool_module_name "$id")"; src="${TOOL_DIR[$id]}/${TOOL_JAR[$id]}"
  mkdir -p "$UD/modules" "$C/Modules"
  file_copy "$src" "$UD/modules/$n.jar" "${TOOL_SUM[$id]}" || die "$(t tool.corrupt "${src#"$NBKIT_DIR"/}")"
  module_xml "${TOOL_CODE[$id]}" > "$C/Modules/$n.xml"
  touch "$UD/.lastModified"
  ok "$(t tool.copied)"
}

tool_module_uninstall() {
  local n; n="$(tool_module_name "$1")"
  rm -f "$UD/modules/$n.jar" "$C/Modules/$n.xml"
  touch "$UD/.lastModified"
  ok "$(t tool.removed)"
}

# with NetBeans open: the module is among the enabled ones and the log has no error about it
tool_module_check() {
  local code="${TOOL_CODE[$1]}" errs
  errs="$(log_module_errors "${code//./\\.}|${code//.//}")"
  if log_has_module "${code//./\\.}" && [ -z "$errs" ]; then
    res 0 "$(t tool.check_loaded)"
    return 0
  fi
  res 1 "$(t tool.check_missing)"
  [ -n "$errs" ] && printf '%s\n' "$errs" | sed 's/^/           /'
  if grep -qE 'requires|Java' <<<"$errs"; then return 2; fi
  return 1
}

# ---------- nbkit contract (the default of every tool) ----------
# installed: its module is in the userdir, or (a tool without one) nbkit recorded its version
tool_status() {
  if tool_has_module "$1"; then
    if [ -e "$UD/modules/$(tool_module_name "$1").jar" ]; then version_status "$1"; else echo no; fi
  elif [ -f "$(mod_version_file "$1")" ]; then version_status "$1"
  else echo no; fi
}

tool_paths() {
  local n
  tool_has_module "$1" || return 0
  n="$(tool_module_name "$1")"
  printf '%s\n' "modules/$n.jar" "config/Modules/$n.xml"
}

tool_install_steps() { echo 1; }
tool_uninstall_steps() { echo 1; }

tool_uninstall_summary() {
  if [ -n "${TOOL_GOES[$1]}" ]; then t tool.summary_out "${TOOL_GOES[$1]}"; echo; fi
  if [ -n "${TOOL_STAYS[$1]}" ]; then t tool.summary_stays "${TOOL_STAYS[$1]}"; echo; fi
}

tool_install() {
  if tool_has_module "$1"; then step "$(t tool.step_install "${MOD_NAME[$1]}")"; else step "$(t tool.step_install_plain "${MOD_NAME[$1]}")"; fi
  if tool_has_module "$1"; then tool_module_install "$1"; fi
  if [ -n "${TOOL_HINT[$1]}" ]; then info "${TOOL_HINT[$1]}"; fi
}

tool_uninstall() {
  step "$(t tool.step_uninstall "${MOD_NAME[$1]}")"
  if tool_has_module "$1"; then tool_module_uninstall "$1"; fi
}

tool_check() {
  if tool_has_module "$1"; then tool_module_check "$1"; else res 0 "$(t tool.check_nothing)"; fi
}

eval "$("$NBKIT_PY" "$NBKIT_DIR/lib/tools/load.py" "$NBKIT_DIR/modules/tools")"
