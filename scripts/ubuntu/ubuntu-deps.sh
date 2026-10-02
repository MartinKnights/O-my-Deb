#!/usr/bin/env bash
#
# Ominty — Ubuntu/Mint system dependencies (the privileged step).
#
# Called by install.sh for the `ubuntu` / `mint-ubuntu` family, or run directly:
#
#     scripts/ubuntu/ubuntu-deps.sh
#
# It installs everything the Ubuntu-family source build needs, and the niri
# runtime pieces the bundled .deb does not declare:
#
#   * Quickshell build dependencies (libdrm, cli11, jemalloc, wayland, pam,
#     polkit, pipewire, shadertools, spirv-tools, …)
#   * niri + xwayland-satellite from the bundled .debs
#   * libseat1 (niri runtime; the .deb's Depends is incomplete)
#   * libdisplay-info 0.2 (Debian soname .so.2; Ubuntu 24.04 ships only .so.1)
#
# Ubuntu-family systems do not carry quickshell/dms/matugen in apt, so those
# are built from source by scripts/ubuntu/ubuntu-build.sh.
#
set -uo pipefail

REPO_DIR="${OMINTY_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIBDISPLAY_VERSION="${OMINTY_LIBDISPLAY_VERSION:-0.2.0}"
BUILD_DIR="${OMINTY_BUILD_DIR:-$HOME/.cache/ominty/build}"

say()  { printf '\033[1;34m[ominty/ubuntu]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have sudo || die "sudo is required."
have apt-get || die "This step targets Ubuntu-family systems (apt-get not found)."

say "Installing build dependencies + niri runtime deps (sudo)…"
# apt-get update can return non-zero because of an unrelated broken PPA; that
# must not abort the install.
sudo apt-get update || echo "[ominty/ubuntu] apt-get update reported errors — continuing"
sudo apt-get install -y \
  libdrm-dev libgbm-dev libcli11-dev libjemalloc-dev libunwind-dev \
  spirv-tools wayland-protocols libwayland-dev libwayland-bin \
  libpam0g-dev libpolkit-agent-1-dev libglib2.0-dev libpipewire-0.3-dev \
  libxcb1-dev libxcb-cursor0 extra-cmake-modules \
  libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev libxkbcommon-dev libvulkan-dev \
  libseat1 meson || die "build-dependency install failed"

say "Installing niri + xwayland-satellite from the bundled .debs…"
# shellcheck disable=SC2086
sudo apt-get install -y "$REPO_DIR"/packages/niri_*.deb "$REPO_DIR"/packages/xwayland-satellite_*.deb \
  || die "niri / xwayland-satellite install failed"

# --- libdisplay-info 0.2 (only if the soname niri wants is absent) ----------
if ldconfig -p 2>/dev/null | grep -q 'libdisplay-info\.so\.2'; then
  say "libdisplay-info.so.2 already present — skipping build."
else
  say "Building libdisplay-info ${LIBDISPLAY_VERSION} (provides libdisplay-info.so.2)…"
  stage="$BUILD_DIR/ldi-stage"
  rm -rf "$BUILD_DIR/libdisplay-info" "$stage"
  git clone --branch "$LIBDISPLAY_VERSION" --depth 1 \
    https://gitlab.freedesktop.org/emersion/libdisplay-info.git \
    "$BUILD_DIR/libdisplay-info" || die "libdisplay-info clone failed"
  (
    cd "$BUILD_DIR/libdisplay-info" || exit 1
    meson setup build --prefix=/usr/local --buildtype=release || exit 1
    meson compile -C build || exit 1
    # Install into a staging dir as the user, then copy as root. Running meson
    # itself under sudo resolves a different meson and fails to read install.dat.
    meson install -C build --destdir "$stage" || exit 1
  ) || die "libdisplay-info build failed"
  sudo cp -a "$stage/usr/local/." /usr/local/ || die "libdisplay-info install failed"
  sudo ldconfig
fi

say "Verifying niri runtime dependencies…"
missing=$(ldd "$(command -v niri)" 2>/dev/null | grep 'not found' || true)
if [ -n "$missing" ]; then
  echo "$missing" >&2
  die "niri still has unresolved libraries (see above)"
fi
say "niri runtime deps OK ($(niri --version 2>/dev/null || echo '?'))"
