# O-my-Deb

**A keyboard-first, action-driven Wayland desktop for Debian-based systems.**

O-my-Deb packages the Omivoid Phase 1 reference implementation — built and
validated on LMDE 7 (Debian 13) — into a one-command installer for other
Debian-based machines. It brings together:

- **Niri** — the scrollable-tiling Wayland compositor (prebuilt `.deb`)
- **DankMaterialShell (DMS)** — the Quickshell-based desktop shell
- **Omivoid** — the action registry, CLI, and adapters that make the desktop
  discoverable and AI-native
- **matugen** — wallpaper-driven dynamic theming
- A complete, working configuration set (Niri + DMS + Omivoid)

## Quick start

```sh
git clone --recurse-submodules https://github.com/<you>/O-my-Deb.git
cd O-my-Deb
./install.sh
```

Log out, select the **Niri** session at the display manager, and you're in.

> Requires **Debian 13 (Trixie)** or **LMDE 7**. Needs `sudo`. See
> [docs/INSTALL.md](docs/INSTALL.md) for the full guide.

## What you get

| Surface | Key | What it does |
|---|---|---|
| Interaction explorer | `Super+K` | Browse and run every Omivoid action |
| Universal palette | `Super+Space` | Apps **and** actions together |
| Cheat sheet | `Super+Shift+S` | Tabbed keybinding reference (GKS) |
| AI menu | `Super+A` | Ask AI / open Pi |
| Power menu | `Super+X` | Restart audio/network, reload Niri, power controls |
| Wallpaper carousel | `Super+Ctrl+P` | Browse and apply wallpapers |

Everything is driven by the **action registry** — one source of truth that
generates the Niri keybindings, the DMS launcher, and the cheat sheet.

## Repository layout

```
O-my-Deb/
├── install.sh                  # one-command installer (idempotent)
├── configs/                    # deployable configurations
│   ├── niri/                   #   compositor config + DMS fragments
│   ├── dms/                    #   shell settings + plugin settings
│   └── omivoid/                #   action registry config (roles, AI)
├── packages/                   # prebuilt .debs (niri, xwayland-satellite)
├── profiles/                   # optional hardware profiles
│   └── surface-book-1/         #   reference hardware extras
├── docs/                       # INSTALL, HARDWARE, TROUBLESHOOTING, ARCHITECTURE
└── omivoid-lmde/               # the implementation (git submodule)
```

## Documentation

- [INSTALL.md](docs/INSTALL.md) — step-by-step install, post-install checks, AI setup
- [HARDWARE.md](docs/HARDWARE.md) — supported hardware, profiles, known devices
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common problems and fixes
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit together

## Project lineage

O-my-Deb is the distribution layer of the **Omivoid** project. The
implementation (CLI, action registry, adapters, DMS plugins) lives in the
[`omivoid-lmde`](https://github.com/<you>/omivoid-lmde) submodule; the design
documentation and progress log live in the umbrella `OmiVoid` repository.
A Void Linux port is planned (see the `OmiVoid-install` project).