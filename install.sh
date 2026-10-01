#!/usr/bin/env bash
#
# Ominty — one-command installer for Debian 13 / LMDE 7
#
# Installs: Niri (prebuilt .deb) + xwayland-satellite, Quickshell (Debian
# trixie-backports), DMS + matugen + ghostty (AvengeMedia Open Build Service),
# pipewire, the ominty CLI + actions + adapters, DMS plugins, and deploys
# the Ominty configurations.
#
# Usage:
#   ./install.sh                              # full install
#   ./install.sh --profile surface-book-1     # + hardware profile
#   ./install.sh --no-plugins                 # skip DMS plugin install
#   ./install.sh --help
#
# Idempotent: safe to re-run. Existing configuration is backed up
# (suffix .bak-ominty-<timestamp>) before being replaced.
#
set -euo pipefail

# --- configuration ---------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=""
INSTALL_PLUGINS=1

# Debian-native packages (Debian 13 / LMDE 7 main + trixie-backports).
# Note: quickshell is installed separately with an explicit target release,
# and nvim is not a Debian package name — the editor is packaged as `neovim`.
#
# libseat1 is listed explicitly because packages/niri_*.deb declares only
# `alacritty, fuzzel` as dependencies. Without libseat1, niri installs but dies
# at runtime with "error while loading shared libraries: libseat.so.1", which
# also breaks `ominty registry build` (it shells out to `niri validate`).
APT_PACKAGES=(
  fuzzel
  pipewire pipewire-pulse wireplumber
  xwayland xdg-desktop-portal xdg-desktop-portal-gtk
  network-manager
  alacritty firefox-esr nemo neovim
  libseat1
)

# Third-party packages that are NOT in Debian. These resolve only once the
# AvengeMedia Open Build Service repositories have been added — see
# add_obs_repositories() below. Installing them from stock APT fails with
# "Unable to locate package".
OBS_PACKAGES=(dms matugen ghostty)

# Open Build Service projects providing those packages. `danklinux` carries the
# DMS runtime companions (matugen, ghostty, danksearch, dgop, niri);
# `dms` carries the DMS shell itself.
OBS_REPOS=(
  "danklinux|home:AvengeMedia:danklinux"
  "dms|home:AvengeMedia:dms"
)
OBS_SUITE="Debian_13"

# Third-party DMS plugins from the DMS plugin registry
DMS_PLUGINS=(dankHooks dankKDEConnect dankLauncherKeys quickCapture wallpaperCarousel)

# --- helpers ---------------------------------------------------------------

say()  { printf '\033[1;34m[Ominty]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

backup_existing() {  # backup_existing <path>
  local p="$1"
  [ -e "$p" ] || return 0
  local bak="${p}.bak-ominty-$(date +%Y%m%d-%H%M%S)"
  cp -a "$p" "$bak"
  say "Backed up existing $p -> $bak"
}

have_repo_line() {  # have_repo_line <suite>
  grep -rqs -- "$1" /etc/apt/sources.list /etc/apt/sources.list.d/
}

ensure_backports() {
  have_repo_line "trixie-backports" && return 0
  say "Enabling trixie-backports (required for quickshell)..."
  echo "deb http://deb.debian.org/debian trixie-backports main" \
    | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
}

pin_quickshell() {
  # The danklinux OBS repo also ships a quickshell build, but upstream marks it
  # deprecated for Debian and directs users to Debian's own build (trixie-backports
  # on Debian 13). The OBS version string (0.3.1.db2) sorts higher than Debian's
  # (0.3.0-1~bpo13+1), so without this pin APT would prefer the deprecated build.
  local pin=/etc/apt/preferences.d/ominty-quickshell
  if [ ! -f "$pin" ]; then
    say "Pinning quickshell to the Debian build..."
    printf 'Package: quickshell\nPin: release n=trixie-backports\nPin-Priority: 1001\n' \
      | sudo tee "$pin" >/dev/null
  fi
}

add_obs_repositories() {
  local entry name project base keyring list
  install -d -m 0755 /etc/apt/keyrings
  for entry in "${OBS_REPOS[@]}"; do
    name="${entry%%|*}"
    project="${entry#*|}"
    keyring="/etc/apt/keyrings/${name}.gpg"
    list="/etc/apt/sources.list.d/${name}.list"
    base="https://download.opensuse.org/repositories/${project}/${OBS_SUITE}"
    if [ ! -s "$keyring" ]; then
      say "Importing signing key for ${project}..."
      curl -fsSL "$base/Release.key" | sudo gpg --dearmor --yes -o "$keyring"
    fi
    if [ ! -f "$list" ]; then
      say "Adding APT source ${project}/${OBS_SUITE}..."
      echo "deb [signed-by=${keyring}] ${base}/ /" | sudo tee "$list" >/dev/null
    fi
  done
}

# --- argument parsing ------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --no-plugins) INSTALL_PLUGINS=0; shift ;;
    -h|--help)
      awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

# --- preflight -------------------------------------------------------------

[ "$(id -u)" -eq 0 ] && die "Do not run as root; run as a normal user (sudo is used internally)."
have sudo || die "sudo is required."
have apt-get || die "This installer targets Debian-based systems (apt-get not found)."
have curl || die "curl is required (used to import the OBS signing keys)."
have gpg || die "gpg is required (used to dearmor the OBS signing keys)."

# OS check: Debian 13 (trixie) / LMDE 7 (faye)
. /etc/os-release 2>/dev/null || true
case "${VERSION_CODENAME:-}" in
  trixie|faye) : ;;
  *)
    warn "Untested distro (${PRETTY_NAME:-unknown}). Debian 13 / LMDE 7 is the supported target."
    ;;
esac

# --- 1. apt repositories ----------------------------------------------------

ensure_backports
pin_quickshell
add_obs_repositories

# --- 2. system packages -----------------------------------------------------

say "Installing system packages (this needs sudo)..."
sudo apt-get update -y

# quickshell first, pinned to Debian's trixie-backports build rather than the
# deprecated OBS one (see pin_quickshell).
sudo apt-get install -y -t trixie-backports quickshell
sudo apt-get install -y "${APT_PACKAGES[@]}"
sudo apt-get install -y "${OBS_PACKAGES[@]}"

# --- 3. Niri + xwayland-satellite -------------------------------------------

if ! have niri; then
  say "Installing Niri + xwayland-satellite from prebuilt .debs..."
  sudo apt-get install -y "$REPO_DIR"/packages/niri_*.deb "$REPO_DIR"/packages/xwayland-satellite_*.deb
else
  say "Niri already installed ($(niri --version 2>/dev/null || echo '?'))."
fi

# --- 4. deploy configurations -----------------------------------------------

say "Deploying configurations..."
mkdir -p ~/.config/niri ~/.config/DankMaterialShell ~/.config/ominty ~/.local/bin

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

# ominty (user configuration wins)
for f in ai.toml apps.toml; do
  if [ ! -f ~/.config/ominty/$f ]; then
    cp "$REPO_DIR/configs/ominty/$f" ~/.config/ominty/$f
  else
    say "~/.config/ominty/$f exists — keeping user configuration."
  fi
done

# --- 5. ominty CLI ---------------------------------------------------------

say "Setting up the ominty CLI..."
if [ ! -d "$REPO_DIR/ominty-core" ]; then
  die "ominty-core submodule missing. Clone with: git clone --recurse-submodules <url>"
fi
ln -sf "$REPO_DIR/ominty-core/cli/ominty" ~/.local/bin/ominty
ln -sf "$REPO_DIR/ominty-core/cli/ominty-hook" ~/.local/bin/ominty-hook

say "Generating the Niri bindings fragment..."
"$REPO_DIR/ominty-core/cli/ominty" registry build

# --- 6. DMS plugins ---------------------------------------------------------

if [ "$INSTALL_PLUGINS" -eq 1 ]; then
  say "Installing DMS plugins..."
  mkdir -p ~/.config/DankMaterialShell/plugins
  ln -sfn "$REPO_DIR/ominty-core/shell/dms/ominty-actions" \
    ~/.config/DankMaterialShell/plugins/omintyActions
  ln -sfn "$REPO_DIR/ominty-core/shell/dms/ominty-keybinds" \
    ~/.config/DankMaterialShell/plugins/omintyKeybinds
  for p in "${DMS_PLUGINS[@]}"; do
    if [ ! -e ~/.config/DankMaterialShell/plugins/$p ]; then
      dms plugins install "$p" || warn "Could not install plugin: $p"
    fi
  done
fi

# --- 7. validation ----------------------------------------------------------

say "Validating..."
"$REPO_DIR/ominty-core/cli/ominty" registry validate
if have niri; then
  niri validate -c ~/.config/niri/config.kdl \
    || warn "niri validate reported issues (re-check after first login)."
fi

say "Done. Log out and select the 'Niri' session at the display manager."
say "Next steps: docs/INSTALL.md (post-install checks, AI setup, troubleshooting)."