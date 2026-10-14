#!/usr/bin/env bash
#
# install-nvim.sh — install a pinned, checksum-verified Neovim release.
#
# The nvim-config repo only links *config* files; the editor binary itself lives
# outside the repo. This script is therefore the reproducible source of "which
# nvim runs here", shared by every machine that uses this config.
#
# Usage:
#   ./scripts/install-nvim.sh              # install the pinned version
#   ./scripts/install-nvim.sh --help
#
# Env overrides:
#   NVIM_VERSION  release tag (default: PINNED_VERSION below)
#   NVIM_SHA      sha256 to use for a version missing from official_digest()
#   PREFIX        install dir    (default: /opt/nvim-<os>-<arch>)
#   BIN_DIR       symlink dir    (default: /usr/local/bin)
#
# Rollback: the previously installed tree is kept at "<PREFIX>.old".
#
set -euo pipefail

PINNED_VERSION="v0.12.6"
NVIM_VERSION="${NVIM_VERSION:-$PINNED_VERSION}"

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Official release digests (from the GitHub release asset "digest" field).
# Add a `case` line per version/platform; anything else needs NVIM_SHA.
# ---------------------------------------------------------------------------
official_digest() {
  case "$NVIM_VERSION/$1" in
    v0.12.6/linux-x86_64) echo 474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87 ;;
    v0.12.6/linux-arm64)  echo 8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815 ;;
    v0.12.6/macos-arm64)  echo 1dbd148222b051ba6c307c4d17a318ed083df018a4f6a5a0ce46955ffc9ab87b ;;
    v0.12.6/macos-x86_64) echo 481424f1dbc85f637d57e47d27d042aa9c883e5a4fe9ee64fc4ee9573b221998 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
case "$(uname -s)" in
  Linux)  OS=linux ;;
  Darwin) OS=macos ;;
  *) echo "error: unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64)   ARCH=x86_64 ;;
  arm64|aarch64)  ARCH=arm64 ;;
  *) echo "error: unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

PLATFORM="$OS-$ARCH"
NAME="nvim-$PLATFORM"
WANT_VERSION="${NVIM_VERSION#v}"

if [ "$OS" = linux ]; then
  PREFIX="${PREFIX:-/opt/$NAME}"
  BIN_DIR="${BIN_DIR:-/usr/local/bin}"
else
  PREFIX="${PREFIX:-$HOME/.local/$NAME}"
  BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
fi

# ---------------------------------------------------------------------------
# Writable? fall back to sudo
# ---------------------------------------------------------------------------
ensure_writable() {
  local d="$1"
  if [ -e "$d" ]; then
    [ -w "$d" ]
  else
    local p; p="$(dirname "$d")"
    while [ ! -e "$p" ]; do p="$(dirname "$p")"; done
    [ -w "$p" ]
  fi
}

SUDO=""
if ! ensure_writable "$PREFIX" || ! ensure_writable "$BIN_DIR"; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    echo "note: using sudo to write $PREFIX and $BIN_DIR"
  else
    echo "error: no write access to $PREFIX or $BIN_DIR, and sudo is unavailable" >&2
    exit 1
  fi
fi

run() { if [ -n "$SUDO" ]; then "$SUDO" "$@"; else "$@"; fi; }

installed_version() {
  [ -x "$PREFIX/bin/nvim" ] || return 1
  version_of "$PREFIX/bin/nvim"
}

version_of() {
  # "NVIM v0.12.6" -> "0.12.6"
  "$1" --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//'
}

link_target() { readlink "$BIN_DIR/nvim" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Already done?
# ---------------------------------------------------------------------------
if [ -x "$PREFIX/bin/nvim" ] \
   && [ "$(installed_version || true)" = "$WANT_VERSION" ] \
   && [ "$(link_target)" = "$PREFIX/bin/nvim" ]; then
  echo "nvim $WANT_VERSION already installed at $PREFIX"
  echo "symlink: $BIN_DIR/nvim -> $PREFIX/bin/nvim"
  exit 0
fi

# ---------------------------------------------------------------------------
# Checksum
# ---------------------------------------------------------------------------
SHA="${NVIM_SHA:-}"
if [ -z "$SHA" ]; then
  if ! SHA="$(official_digest "$PLATFORM")"; then
    echo "error: no pinned sha256 for $NVIM_VERSION/$PLATFORM" >&2
    echo "       pass NVIM_SHA=<sha256>, or add it to official_digest()." >&2
    echo "       fetch official digests with:" >&2
    echo "         curl -sL https://api.github.com/repos/neovim/neovim/releases/tags/$NVIM_VERSION \\" >&2
    echo "           | python3 -c \"import sys,json;[print(a['name'],a['digest']) for a in json.load(sys.stdin)['assets'] if a['name'].endswith('tar.gz')]\"" >&2
    exit 1
  fi
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ---------------------------------------------------------------------------
# Download + verify
# ---------------------------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nvim-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$NAME.tar.gz"
echo "downloading $URL"
curl -fL --retry 3 -o "$TMP/$NAME.tar.gz" "$URL"

actual="$(sha256_of "$TMP/$NAME.tar.gz")"
if [ "$actual" != "$SHA" ]; then
  echo "error: sha256 mismatch for $NAME.tar.gz" >&2
  echo "  expected $SHA" >&2
  echo "  actual   $actual" >&2
  exit 1
fi
echo "sha256 ok: $actual"

tar -xzf "$TMP/$NAME.tar.gz" -C "$TMP"
if [ ! -x "$TMP/$NAME/bin/nvim" ]; then
  echo "error: unexpected archive layout (no $NAME/bin/nvim)" >&2
  exit 1
fi

got="$(version_of "$TMP/$NAME/bin/nvim")"
if [ "$got" != "$WANT_VERSION" ]; then
  echo "error: archive reports nvim $got, expected $WANT_VERSION" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
# Legacy layout: a plain binary (e.g. an AppImage) sitting in BIN_DIR.
if [ -f "$BIN_DIR/nvim" ] && [ ! -L "$BIN_DIR/nvim" ]; then
  old="$(version_of "$BIN_DIR/nvim")"
  backup_dir="$(dirname "$PREFIX")/nvim-backups"
  run mkdir -p "$backup_dir"
  run mv "$BIN_DIR/nvim" "$backup_dir/nvim-${old:-unknown}.bak"
  echo "backed up $BIN_DIR/nvim -> $backup_dir/nvim-${old:-unknown}.bak"
fi

if [ -e "$PREFIX" ]; then
  run rm -rf "$PREFIX.old"
  run mv "$PREFIX" "$PREFIX.old"
  echo "backed up previous install -> $PREFIX.old"
fi

run mkdir -p "$(dirname "$PREFIX")" "$BIN_DIR"
run mv "$TMP/$NAME" "$PREFIX"
if [ -n "$SUDO" ]; then run chown -R 0:0 "$PREFIX"; fi
run ln -sfn "$PREFIX/bin/nvim" "$BIN_DIR/nvim"

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
echo
final="$(installed_version || true)"
if [ "$final" != "$WANT_VERSION" ]; then
  echo "error: post-install check failed (got '${final:-nothing}')" >&2
  exit 1
fi

"$BIN_DIR/nvim" --version | head -n1
echo "installed: $PREFIX"
echo "symlink:   $BIN_DIR/nvim -> $PREFIX/bin/nvim"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "warning: $BIN_DIR is not in \$PATH" ;;
esac
