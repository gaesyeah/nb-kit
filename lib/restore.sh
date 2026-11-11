# shellcheck shell=bash
# Restore point: before changing the userdir nbkit saves what will change (snapshot); if the change stops
# midway (error or Ctrl+C), the exit trap puts it back. Used by nbkit.sh.

CLEAN=(); SNAP=""; SNAP_OK=0; DONE=0; SNAPPATHS=()
on_exit() {
  local rc=$? p
  if [ "$SNAP_OK" = 1 ] && [ "$DONE" != 1 ]; then
    [ -t 1 ] && printf '\e[?25h'
    echo
    if [ $rc = 130 ]; then t cli.interrupted; echo
    else t cli.stopped_error "$rc"; echo; fi
    for p in "${SNAPPATHS[@]}"; do rm -rf "${UD:?}/$p"; done
    tar -xf "$SNAP" -C "$UD" 2>/dev/null || true
    mod_rollback_extra
    touch "$UD/.lastModified"
    t cli.nothing_changed_nb; echo
  fi
  [ ${#CLEAN[@]} -gt 0 ] && rm -rf "${CLEAN[@]}"
  return 0
}
trap on_exit EXIT
# undoes what lives outside the userdir (e.g. a backup just created); each module may have <prefix>_rollback
mod_rollback_extra() {
  local id
  for id in "${MODS[@]}"; do mod_call "$id" rollback || true; done
}
# one change at a time in a userdir (two windows, or the window and a terminal): the second one stops before
# touching anything; the lock goes with the process, or in after_change once the change is done
lock_userdir() {
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nbkit-$(printf %s "$UD" | md5sum | cut -c1-16).lock"
  flock -n 9 || die "$(t cli.busy "${UD/#$HOME/\~}")"
}
snapshot() {
  local id p have=()
  lock_userdir
  SNAPPATHS=(nbkit modules/nbkit-core.jar config/Modules/nbkit-core.xml)
  for id in "$@"; do
    while IFS= read -r p; do [ -n "$p" ] && SNAPPATHS+=("$p"); done < <(mod_call "$id" paths)
  done
  SNAP="$(mktemp)"; CLEAN+=("$SNAP")
  for p in "${SNAPPATHS[@]}"; do [ -e "$UD/$p" ] && have+=("$p"); done
  if [ ${#have[@]} -gt 0 ]; then tar -cf "$SNAP" -C "$UD" "${have[@]}"; else tar -cf "$SNAP" -T /dev/null; fi
  SNAP_OK=1
}
