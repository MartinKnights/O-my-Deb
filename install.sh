#!/usr/bin/env bash
#
# O-my-Deb — one-command installer for Debian 13 / LMDE 7
#
# Installs: Niri (prebuilt .deb) + xwayland-satellite, Quickshell + DMS
# (backports), matugen, pipewire, the omivoid CLI + actions + adapters,
# DMS plugins, and deploys the O-my-Deb configurations.
#
# Usage:
#   ./install.sh                              # full install
#   ./install.sh --profile surface-book-1     # + hardware profile
#   ./install.sh --no-plugins                 # skip DMS plugin install
#   ./install.sh --help
#
# Idempotent: safe to re-run. Existing configuration is backed up
# (suffix .bak-omivoid-<timestamp>) before being replaced.
#
set -euo pipefail

# --- configuration ---------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=""
INSTALL_PLUGINS=1

# System packages (Debian 13 / LMDE 7)
APT_PACKAGES=(
  quickshell dms matugen fuzzel
  pipewire pipewire-pulse wireplumber
  xwayland xdg-desktop-portal xdg-desktop-portal-gtk
  network-manager
  alacritty ghostty firefox-esr nemo nvim
)

# Third-party DMS plugins from the DMS plugin registry
DMS_PLUGINS=(dankHooks dankKDEConnect dankLauncherKeys quickCapture wallpaperCarousel)

# --- helpers ---------------------------------------------------------------

say()  { printf '\033[1;34m[O-my-Deb]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

backup_existing() {  # backup_existing <path>
  local p="$1"
  [ -e "$p" ] || return 0
  local bak="${p}.bak-omivoid-$(date +%Y%m%d-%H%M%S)"
  cp -a "$p" "$bak"
  say "Backed up existing $p -> $bak"
}

# --- argument parsing ------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --no-plugins) INSTALL_PLUGINS=0; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

# --- preflight -------------------------------------------------------------

[ "$(id -u)" -eq 0 ] && die "Do not run as root; run as a normal user (sudo is used internally)."
have sudo || die "sudo is required."
have apt-get || die "This installer targets Debian-based systems (apt-get not found)."

# OS check: Debian 13 (trixie) / LMDE 7 (faye)
. /etc/os-release 2>/dev/null || true
case "${VERSION_CODENAME:-}" in
  trixie|faye) : ;;
  *)
    warn "Untested distro (${PRETTY_NAME:-unknown}). Debian 13 / LMDE 7 is the supported target."
    ;;
esac

# --- 1. system packages ----------------------------------------------------

say "Installing system packages (this needs sudo)..."
sudo apt-get update -y
sudo apt-get install -y "${APT_PACKAGES[@]}"

# --- 2. Niri + xwayland-satellite ------------------------------------------

if ! have niri; then
  say "Installing Niri + xwayland-satellite from prebuilt .debs..."
  sudo apt-get install -y "$REPO_DIR"/packages/niri_*.deb "$REPO_DIR"/packages/xwayland-satellite_*.deb
else
  say "Niri already installed ($(niri --version 2>/dev/null || echo '?'))."
fi

# --- 3. deploy configurations ----------------------------------------------

say "Deploying configurations..."
mkdir -p ~/.config/niri ~/.config/DankMaterialShell ~/.config/omivoid ~/.local/bin

# niri
backup_existing ~/.config/niri/config.kdl
cp "$REPO_DIR/configs/niri/config.kdl" ~/.config/niri/config.kdl
mkdir -p ~/.config/niri/dms
for f in "$REPO_DIR"/configs/niri/dms/*.kdl; do
  cp "$f" ~/.config/niri/dms/
done

# hardware profile
if [ -n "$PROFILE" ]; then
  if [ -d "$REPO_DIR/profiles/$PROFILE" ]; then
    say "Applying hardware profile: $PROFILE"
    if [ -f "$REPO_DIR/profiles/$PROFILE/niri-outputs.kdl" ]; then
      cp "$REPO_DIR/profiles/$PROFILE/niri-outputs.kdl" ~/.config/niri/dms/outputs.kdl
    fi
  else
    die "Unknown profile: $PROFILE (available: $(ls "$REPO_DIR/profiles"))"
  fi
fi

# DMS
backup_existing ~/.config/DankMaterialShell/settings.json
cp "$REPO_DIR/configs/dms/settings.json" ~/.config/DankMaterialShell/settings.json
backup_existing ~/.config/DankMaterialShell/plugin_settings.json
sed "s|__HOME__|$HOME|g" "$REPO_DIR/configs/dms/plugin_settings.json.template" \
  > ~/.config/DankMaterialShell/plugin_settings.json

# omivoid (user configuration wins)
for f in ai.toml apps.toml; do
  if [ ! -f ~/.config/omivoid/$f ]; then
    cp "$REPO_DIR/configs/omivoid/$f" ~/.config/omivoid/$f
  else
    say "~/.config/omivoid/$f exists — keeping user configuration."
  fi
done

# --- 4. omivoid CLI ---------------------------------------------------------

say "Setting up the omivoid CLI..."
if [ ! -d "$REPO_DIR/omivoid-lmde" ]; then
  die "omivoid-lmde submodule missing. Clone with: git clone --recurse-submodules <url>"
fi
ln -sf "$REPO_DIR/omivoid-lmde/cli/omivoid" ~/.local/bin/omivoid
ln -sf "$REPO_DIR/omivoid-lmde/cli/omivoid-hook" ~/.local/bin/omivoid-hook

say "Generating the Niri bindings fragment..."
"$REPO_DIR/omivoid-lmde/cli/omivoid" registry build

# --- 5. DMS plugins ---------------------------------------------------------

if [ "$INSTALL_PLUGINS" -eq 1 ]; then
  say "Installing DMS plugins..."
  mkdir -p ~/.config/DankMaterialShell/plugins
  ln -sfn "$REPO_DIR/omivoid-lmde/shell/dms/omivoid-actions" \
    ~/.config/DankMaterialShell/plugins/omivoidActions
  ln -sfn "$REPO_DIR/omivoid-lmde/shell/dms/omivoid-keybinds" \
    ~/.config/DankMaterialShell/plugins/omivoidKeybinds
  for p in "${DMS_PLUGINS[@]}"; do
    if [ ! -e ~/.config/DankMaterialShell/plugins/$p ]; then
      dms plugins install "$p" || warn "Could not install plugin: $p"
    fi
  done
fi

# --- 6. validation ----------------------------------------------------------

say "Validating..."
"$REPO_DIR/omivoid-lmde/cli/omivoid" registry validate
if have niri; then
  niri validate -c ~/.config/niri/config.kdl \
    || warn "niri validate reported issues (re-check after first login)."
fi

say "Done. Log out and select the 'Niri' session at the display manager."
say "Next steps: docs/INSTALL.md (post-install checks, AI setup, troubleshooting)."