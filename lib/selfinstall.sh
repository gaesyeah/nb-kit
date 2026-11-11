# shellcheck shell=bash
# nbkit installed for the user, without root and the same on any distro: a copy in ~/.local/share/nbkit, the
# nbkit command in ~/.local/bin and the menu entry (with the icon, for the taskbar)
SELF_DEST="${XDG_DATA_HOME:-$HOME/.local/share}/nbkit"
SELF_BIN="$HOME/.local/bin/nbkit"
SELF_DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/io.github.gaesyeah.nbkit.desktop"

# the menu entry, opening the nbkit of the folder $1
write_desktop() {
  mkdir -p "$(dirname "$SELF_DESKTOP")"
  printf '[Desktop Entry]\nType=Application\nName=nbkit\nComment=%s\nExec=bash "%s/nbkit.sh" gui\nIcon=%s\nTerminal=false\nCategories=Development;\nStartupWMClass=nbkit\n' \
    "$(t cli.desktop_comment)" "$1" "$1/lib/gui/icons/hicolor/scalable/apps/io.github.gaesyeah.nbkit.svg" > "$SELF_DESKTOP"
}

self_installed() { [ -f "$SELF_DEST/nbkit.sh" ]; }

# also updates: run it from the folder of a newer zip
install_self() {
  # never over a folder that is not an nbkit
  [ ! -e "$SELF_DEST" ] || self_installed || die "$(t cli.self_not_ours "$SELF_DEST")"
  if [ "$NBKIT_DIR" != "$(readlink -f "$SELF_DEST")" ]; then
    rm -rf "$SELF_DEST.new"; mkdir -p "$SELF_DEST.new"
    # the same as the release zip: what only the repository uses stays out (see .gitattributes)
    tar -C "$NBKIT_DIR" --exclude=./.git --exclude=./tests --exclude=./.github --exclude=./.gitignore \
      --exclude=./.gitattributes -cf - . | tar -C "$SELF_DEST.new" -xf -
    rm -rf "$SELF_DEST"; mv "$SELF_DEST.new" "$SELF_DEST"
  fi
  # the nbkit command runs it directly (a zip opened by Python loses the permissions)
  chmod +x "$SELF_DEST/nbkit.sh"
  mkdir -p "$(dirname "$SELF_BIN")"
  ln -sfn "$SELF_DEST/nbkit.sh" "$SELF_BIN"
  write_desktop "$SELF_DEST"
  ok "$(t cli.self_installed "${SELF_DEST/#$HOME/\~}")"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) info "$(t cli.self_path)" ;;
  esac
}

# the latest release, installed over this one (install-self of the downloaded zip)
NBKIT_RELEASE_URL="${NBKIT_RELEASE_URL:-https://github.com/gaesyeah/nb-kit/releases/latest/download/nbkit.zip}"
update_self() {
  [ "${NBKIT_OFFLINE:-}" != 1 ] || die "$(t cli.self_offline)"
  local tmp new
  # in the temporary folder only while it runs: the exit trap (lib/restore.sh) takes it out on any exit, Ctrl+C included
  tmp="$(mktemp -d)"; CLEAN+=("$tmp")
  info "$(t cli.self_downloading)"
  # Python, which nbkit already needs: no curl, wget or unzip required
  if ! python3 -c 'import sys, urllib.request, zipfile; urllib.request.urlretrieve(sys.argv[1], sys.argv[2] + "/nbkit.zip"); zipfile.ZipFile(sys.argv[2] + "/nbkit.zip").extractall(sys.argv[2])' \
      "$NBKIT_RELEASE_URL" "$tmp" 2>/dev/null || [ ! -f "$tmp/nbkit/nbkit.sh" ]; then
    die "$(t cli.self_download_failed "$NBKIT_RELEASE_URL")"
  fi
  new="$(sed -n 's/^NBKIT_VERSION=//p' "$tmp/nbkit/nbkit.sh")"
  if [ "$new" = "$NBKIT_VERSION" ] && self_installed; then
    ok "$(t cli.self_up_to_date "$new")"; return 0
  fi
  bash "$tmp/nbkit/nbkit.sh" install-self
}

# only what install-self made; the modules stay in NetBeans (nbkit uninstall removes them)
uninstall_self() {
  if [ "$(readlink -f "$SELF_BIN" 2>/dev/null)" = "$(readlink -f "$SELF_DEST/nbkit.sh" 2>/dev/null)" ]; then rm -f "$SELF_BIN"; fi
  if grep -qF "$SELF_DEST/nbkit.sh" "$SELF_DESKTOP" 2>/dev/null; then rm -f "$SELF_DESKTOP"; fi
  if self_installed; then rm -rf "$SELF_DEST"; fi
  ok "$(t cli.self_removed)"
  info "$(t cli.self_modules_kept)"
}
