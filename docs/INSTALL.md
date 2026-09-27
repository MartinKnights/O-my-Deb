# Installation Guide

## Requirements

- **Debian 13 (Trixie)** or **LMDE 7** (the reference platform). Other
  Debian-based distros may work but are untested.
- A user account with **sudo** access.
- ~2 GB free disk space (Niri + DMS + dependencies).
- An internet connection.

## 1. Clone

```sh
git clone --recurse-submodules https://github.com/<you>/O-my-Deb.git
cd O-my-Deb
```

The `--recurse-submodules` flag pulls the `omivoid-lmde` implementation
submodule. If you forgot it:

```sh
git submodule update --init --recursive
```

## 2. Install

```sh
./install.sh
```

The installer is **idempotent** — re-running it is safe. It will:

1. Install system packages via `apt` (DMS/Quickshell from backports,
   matugen, pipewire, xwayland, terminals, browser, file manager).
2. Install **Niri** and **xwayland-satellite** from the prebuilt `.deb`s in
   `packages/`.
3. Deploy the Niri configuration and DMS fragments to `~/.config/niri/`.
4. Deploy the DMS shell settings and plugin settings to
   `~/.config/DankMaterialShell/`.
5. Deploy the Omivoid configuration to `~/.config/omivoid/` (existing user
   config is **kept**).
6. Symlink the `omivoid` and `omivoid-hook` CLIs into `~/.local/bin/`.
7. Generate the Niri bindings fragment from the action registry.
8. Install the DMS plugins (Omivoid Actions, Omivoid Keybinds, and the
   third-party set: dankHooks, dankKDEConnect, dankLauncherKeys,
   quickCapture, wallpaperCarousel).
9. Validate the registry and the Niri config.

Existing configuration files are backed up with a
`.bak-omivoid-<timestamp>` suffix before being replaced.

### Options

| Flag | Effect |
|---|---|
| `--profile surface-book-1` | Apply the Surface Book 1 hardware profile (2× scale output, dGPU script). |
| `--no-plugins` | Skip the DMS plugin installation step. |
| `--help` | Show usage. |

## 3. First login

1. Log out of your current session.
2. At the display manager, select the **Niri** session.
3. Log in. The DMS bar appears; `Super+K` opens the interaction explorer.

## 4. Post-install checks

```sh
omivoid registry validate        # 44 action(s), 0 error(s), 0 warning(s)
niri validate -c ~/.config/niri/config.kdl   # config is valid
systemctl --user is-active dms   # active
```

Then exercise the surfaces:

- `Super+K` — interaction explorer
- `Super+Space` — universal palette (type `volume`)
- `Super+Shift+S` — cheat sheet (GKS)
- `Super+A` — AI menu
- `Super+X` — power menu (Restart Audio / Restart Network / Reload Niri)

## 5. AI setup (optional)

The default AI provider is **Pi** (`configs/omivoid/ai.toml`). To use a local
model instead:

1. Install [Ollama](https://ollama.com) and pull a model:
   ```sh
   ollama pull qwen2.5:3b
   ```
2. Create `~/.config/omivoid/ai.toml`:
   ```toml
   [ai]
   default_provider = "ollama"

   [ai.providers.ollama]
   enabled = true
   model = "qwen2.5:3b"
   ```
3. `Super+A` → **Ask AI** now uses the local model.

## 6. Wallpapers

The wallpaper carousel (`Super+Ctrl+P`) reads `~/Wallpapers`. Drop images
there. The `dankHooks` plugin regenerates the theme palette automatically
when the wallpaper changes.

## 7. Updating

```sh
git -C O-my-Deb pull
git -C O-my-Deb submodule update --init --recursive
./install.sh        # re-run; configs are backed up and replaced
```

## Uninstall

There is no automated uninstaller yet. To remove:

```sh
sudo apt remove --purge niri xwayland-satellite quickshell dms matugen
rm -rf ~/.config/niri ~/.config/DankMaterialShell ~/.config/omivoid
rm -f ~/.local/bin/omivoid ~/.local/bin/omivoid-hook
```

Restore any `.bak-omivoid-*` files you want to keep.