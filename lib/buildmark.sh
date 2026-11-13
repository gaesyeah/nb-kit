# shellcheck shell=bash
# Whether the jars are up to date with the code in src/: src/build.sh writes in the manifest of each jar a mark of
# what built it (NbKit-Source-Hash: the module's src/, res/ and manifest.mf, and src/build.sh); the menu, the
# interface and src/build.sh compare it with the code as it is now. The mark goes in the jar, so it travels with it
# in git: after a pull the jars and the code are compared as they came. The NetBeans version is not in it: the same
# jars serve every NetBeans (the ones in the repository are used everywhere), so a new NetBeans needs no new build.

# module of src/ and the jar it builds, relative to the nbkit folder
BUILD_MODULES=(nbkit-core:lib/jars/nbkit-core.jar nbkit-colors:lib/jars/nbkit-colors.jar nbkit-jsf:modules/tools/jsf/nbkit-jsf.jar)

# source_mark <module>: what the build of that module is made of, as it is now (32 hex: fits a manifest line)
source_mark() {
  (cd "$NBKIT_DIR" && {
    find "src/$1/src" "src/$1/res" "src/$1/manifest.mf" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 sha256sum
    sha256sum src/build.sh
  } | sha256sum | cut -c1-32)
}

# jar_mark <jar>: the mark in its manifest (empty: none)
jar_mark() {
  python3 -c '
import sys, zipfile
try:
    m = zipfile.ZipFile(sys.argv[1]).read("META-INF/MANIFEST.MF").decode("utf-8", "replace")
except Exception:
    sys.exit(0)
for line in m.splitlines():
    if line.startswith("NbKit-Source-Hash:"):
        print(line.split(":", 1)[1].strip())
' "$1" 2>/dev/null || true
}

# build_stale: one line "<module><TAB><reason>" per jar that needs a build; reason: missing (no jar), unmarked (built
# before the mark existed) or changed (the code is not the one it was built from). Nothing: all up to date
build_stale() {
  local e name jar m
  for e in "${BUILD_MODULES[@]}"; do
    name="${e%%:*}"; jar="$NBKIT_DIR/${e#*:}"
    if [ ! -f "$jar" ]; then printf '%s\tmissing\n' "$name"; continue; fi
    m="$(jar_mark "$jar")"
    if [ -z "$m" ]; then printf '%s\tunmarked\n' "$name"
    elif [ "$m" != "$(source_mark "$name")" ]; then printf '%s\tchanged\n' "$name"; fi
  done
}

# build_stale_text: the stale modules in words ("nbkit-jsf (code changed), ..."), for the messages
build_stale_text() {
  local name reason k out=""
  while IFS=$'\t' read -r name reason; do
    case "$reason" in
      changed) k=build.reason_changed ;;
      missing) k=build.reason_missing ;;
      *) k=build.reason_unmarked ;;
    esac
    out="${out:+$out, }$(t "$k" "$name")"
  done < <(build_stale)
  printf '%s' "$out"
}
