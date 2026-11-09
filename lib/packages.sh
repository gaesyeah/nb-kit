# shellcheck shell=bash
# System packages: installs what nbkit needs with the package manager of the distro (apt, dnf, pacman or zypper),
# asking first and only with a terminal to ask. Used by nbkit.sh (Python, curl) and tests/run.sh (test tools).

# the package manager of this system
pkg_manager() {
  local m
  for m in apt-get dnf pacman zypper; do
    if command -v "$m" >/dev/null 2>&1; then echo "$m"; return 0; fi
  done
  return 1
}

# pkg_available <manager> <package>: the repositories have it
pkg_available() {
  case "$1" in
    apt-get) [ -n "$(apt-cache policy "$2" 2>/dev/null | sed -n 's/^ *Candidate: *//p' | grep -v '(none)')" ] ;;
    dnf) dnf -q info "$2" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$2" >/dev/null 2>&1 ;;
    zypper) zypper --non-interactive --quiet info "$2" 2>/dev/null | grep -q '^Name' ;;
    *) return 1 ;;
  esac
}

# pkg_for <manager> apt:<package> dnf:<package> pacman:<package> zypper:<package>
# the package for this manager; "a|b" means the first of them the repositories have
pkg_for() {
  local m="$1" spec p IFS
  shift
  for spec in "$@"; do
    case "$spec" in
      "${m%-get}":*)
        IFS='|'
        for p in ${spec#*:}; do
          if pkg_available "$m" "$p"; then echo "$p"; return 0; fi
        done
        echo "${spec#*:}" | cut -d'|' -f1
        return 0 ;;
    esac
  done
  return 1
}

# pkg_run <what> <package...>: asks, installs with progress and says whether it worked
pkg_run() {
  local what="$1" m cmd=() sudo=()
  shift
  m="$(pkg_manager)" || return 1
  case "$m" in
    apt-get) cmd=(apt-get install -y "$@") ;;
    dnf) cmd=(dnf install -y "$@") ;;
    pacman) cmd=(pacman -S --needed --noconfirm "$@") ;;
    zypper) cmd=(zypper --non-interactive install "$@") ;;
  esac
  if [ "$(id -u)" != 0 ]; then command -v sudo >/dev/null 2>&1 || return 1; sudo=(sudo); fi
  { [ -t 0 ] && [ -t 1 ]; } || return 1
  ask_yn "$(t cli.ask_install "$what" "${sudo[*]+${sudo[*]} }${cmd[*]}")" Y || return 1
  echo
  if [ "$m" = apt-get ]; then
    info "$(t cli.pkg_updating)"
    ${sudo[@]+"${sudo[@]}"} apt-get update -qq || true
  fi
  info "$(t cli.pkg_installing "$what")"
  if ${sudo[@]+"${sudo[@]}"} "${cmd[@]}"; then
    ok "$(t cli.pkg_done "$what")"
    echo
  else
    warn "$(t cli.pkg_failed "$what")"
    return 1
  fi
}

# pkg_install <what> apt:<package> dnf:<package> pacman:<package> zypper:<package>
pkg_install() {
  local what="$1" m p
  shift
  m="$(pkg_manager)" || return 1
  p="$(pkg_for "$m" "$@")" || return 1
  pkg_run "$what" "$p"
}
