#!/bin/bash
# TIN-flavored release notes for github.com/tindevelopers/desktop.
#
# Reads already-staged installers from ${DIST_DIR:-./ghr-dist}/, computes
# SHA-256 locally, and emits a body that links to the actual GitHub release
# asset URLs (no releases.mattermost.com 403s, no placeholder SHA strings).
#
# Drop-in replacement for the upstream `scripts/generate_release_markdown.sh`
# invoked from the existing `.github/workflows/release.yaml` `github-release`
# job — workflow file itself does not need to change.

set -euo pipefail

VERSION="${1}"
REPO="tindevelopers/desktop"
DIST_DIR="${DIST_DIR:-./ghr-dist}"

PRERELEASE=""
[[ "$VERSION" == *-* ]] && PRERELEASE=" — Pre-release"

cat <<MD
**TIN Desktop ${VERSION}${PRERELEASE}** — fork of Mattermost Desktop, pre-configured to connect to your **TIN** workspace at [https://mattermost.tin.info](https://mattermost.tin.info).

For a per-arch installer that auto-detects Apple Silicon vs Intel, visit [https://tin.info/download](https://tin.info/download). The asset tables below mirror what's served there.

MD

if [[ "$VERSION" == *-* ]]; then
  cat <<'MD'
> **Pre-release build.** Installers may be unsigned or carry the default developer certificate. Use a stable tag (no `-rc` / `-beta` / `-alpha` suffix) for production distribution.

MD
fi

# Strip electron-builder backup suffix so duplicate-detection suffixes (.~1~ etc.)
# don't fragment output.
clean_name() {
  printf '%s' "$(basename "$1" | sed 's/\.~[0-9]\+~$//')"
}

# emit_group "label" "glob1" "glob2" ... — matches ANY of the globs against $DIST_DIR
emit_group() {
  local label="$1"; shift
  local files=()
  shopt -s nullglob
  for g in "$@"; do
    # shellcheck disable=SC2207
    for f in "$DIST_DIR"/$g; do
      [ -f "$f" ] || continue
      files+=("$f")
    done
  done
  shopt -u nullglob
  [ "${#files[@]}" -eq 0 ] && return 0
  printf '\n### %s\n\n' "$label"
  # sort by cleaned name so output is stable
  local sorted=()
  while IFS= read -r f; do sorted+=("$f"); done < <(printf '%s\n' "${files[@]}" | sort)
  files=("${sorted[@]}")
  for f in "${files[@]}"; do
    local name size_mb sha url
    name="$(clean_name "$f")"
    size_mb=$(awk -v b="$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f")" 'BEGIN{printf "%.1f MB", b/1048576}')
    sha="$(sha256sum < "$f" | awk '{print $1}')"
    url="https://github.com/${REPO}/releases/download/${VERSION}/${name}"
    printf -- '- [%s](%s) (%s)\n  - SHA-256: `%s`\n' "$name" "$url" "$size_mb" "$sha"
  done
}

# Each emit_group call covers both tinconnect-desktop-* AND mattermost-desktop-*
# prefixes (legacy v6.2.0 era). The ${VERSION} is suffixed where required.
PFX="tinconnect-desktop-${VERSION}"
MFX="mattermost-desktop-${VERSION}"

emit_group "macOS — Apple Silicon (M1/M2/M3/M4)" "${PFX}-mac-arm64.dmg"          "${MFX}-mac-arm64.dmg"
emit_group "macOS — Intel"                      "${PFX}-mac-x64.dmg"            "${MFX}-mac-x64.dmg"
emit_group "macOS — Universal (any Mac)"        "${PFX}-mac-universal.dmg"      "${MFX}-mac-universal.dmg"
emit_group "macOS — portable zip"               "${PFX}-mac-arm64.zip"          "${PFX}-mac-x64.zip" "${PFX}-mac-universal.zip" \
                                              "${MFX}-mac-arm64.zip"          "${MFX}-mac-x64.zip" "${MFX}-mac-universal.zip"
emit_group "Windows — installer (x64, MSI)"     "${PFX}-win-x64.msi"            "${MFX}-win-x64.msi"
emit_group "Windows — installer (ARM64, MSI)"   "${PFX}-win-arm64.msi"          "${MFX}-win-arm64.msi"
emit_group "Windows — portable zip"             "${PFX}-win-x64.zip"            "${PFX}-win-arm64.zip" \
                                              "${MFX}-win-x64.zip"            "${MFX}-win-arm64.zip"
emit_group "Linux — x86_64 (AppImage)"          "${PFX}-linux-x86_64.AppImage"  "${MFX}-linux-x86_64.AppImage"
emit_group "Linux — x86_64 (tar.gz)"            "${PFX}-linux-x64.tar.gz"       "${MFX}-linux-x64.tar.gz"
emit_group "Linux — ARM64 (AppImage)"           "${PFX}-linux-arm64.AppImage"   "${MFX}-linux-arm64.AppImage"
emit_group "Linux — ARM64 (tar.gz)"             "${PFX}-linux-arm64.tar.gz"     "${MFX}-linux-arm64.tar.gz"
emit_group "Linux — Debian / Ubuntu (.deb)"     "${PFX}-1_amd64.deb"            "${PFX}-1_arm64.deb" \
                                              "${MFX}-1_amd64.deb"            "${MFX}-1_arm64.deb"
emit_group "Linux — Fedora / RHEL (.rpm)"       "${PFX}-linux-x86_64.rpm"       "${PFX}-linux-aarch64.rpm" \
                                              "${MFX}-linux-x86_64.rpm"       "${MFX}-linux-aarch64.rpm"
emit_group "Linux — Flatpak"                    "${PFX}-linux-x86_64.flatpak"   "${PFX}-linux-aarch64.flatpak" \
                                              "${MFX}-linux-x86_64.flatpak"   "${MFX}-linux-aarch64.flatpak"
