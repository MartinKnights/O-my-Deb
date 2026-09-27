# Architecture

O-my-Deb is the **distribution layer** of the Omivoid project: it packages a
working, validated desktop for Debian-based systems. The design intent lives
in the umbrella `OmiVoid` repository; the implementation lives in the
`omivoid-lmde` submodule.

## The stack

```
┌─────────────────────────────────────────────────────────┐
│  DMS (Quickshell)          Niri (compositor)            │
│  bar · spotlight · power   scrollable tiling · binds    │
│  menu · cheat sheet        window rules · animations    │
└──────────┬──────────────────────┬───────────────────────┘
           │ plugins / IPC        │ generated bindings
           ▼                      ▼
┌─────────────────────────────────────────────────────────┐
│  omivoid CLI (omivoid-lmde submodule)                   │
│  action registry → adapters → execution                 │
│  registry build → Niri fragment                         │
└──────────┬──────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────┐
│  adapters: common · debian · void · niri · dms          │
│  (service.restart, package.install, app.launch, …)      │
└─────────────────────────────────────────────────────────┘
```

## Core principle: the action registry is the source of truth

Every capability of the desktop is an **action** defined in the registry
(`omivoid-lmde/actions/*.toml`). From the registry, the CLI:

1. **Validates** the registry (`omivoid registry validate`).
2. **Generates** the Niri keybinding fragment
   (`omivoid registry build` → `~/.config/omivoid/generated/niri/bindings.kdl`).
3. **Runs** actions through adapters (`omivoid action run <id>`).
4. **Serves** the DMS plugins (launcher entries, cheat-sheet rows).

No interaction surface hard-codes commands where a canonical action exists
(AGENTS.md Contract 3).

## Adapters

Actions are performed by **adapters**, resolved platform → common:

| Adapter | Purpose |
|---|---|
| `common/app_launch` | Launch applications by role (`app.browser.open`) |
| `common/command` | Run a declared command (`adapter = "command"`) |
| `debian/service_restart` | systemd user services (`system.audio.restart`) |
| `debian/package_install` | `apt-get install` (`package.install`) |
| `niri/native` | Native Niri operations |
| `dms/ipc` | DMS IPC calls (spotlight, power menu) |
| `dms/theme` | Wallpaper → palette regeneration |

The **Void** adapters (`void/service_restart` via runit `sv`,
`void/package_install` via `xbps-install`) exist but are not exercised on
Debian — they are the porting surface for the Void phase.

## Configuration flow

```
O-my-Deb/configs/  ──install.sh──▶  ~/.config/
├── niri/config.kdl                 ├── niri/config.kdl
├── niri/dms/*.kdl                  ├── niri/dms/*.kdl
├── dms/settings.json               ├── DankMaterialShell/settings.json
├── dms/plugin_settings.json.tpl    ├── DankMaterialShell/plugin_settings.json
└── omivoid/*.toml                  └── omivoid/*.toml   (user config wins)
```

- Templates use `__HOME__` placeholders substituted at install time.
- Existing user configuration is **backed up**, never silently destroyed.
- Omivoid user overrides (`~/.config/omivoid/`) win over shipped defaults.

## Hardware profiles

`profiles/<device>/` holds hardware-specific fragments (outputs, scripts).
The base config is hardware-agnostic; profiles are opt-in via
`./install.sh --profile <device>`.

## AI

The AI surface (`Super+A`) is a first-class interaction path:

- `ai.ask` runs through a provider layer (Pi or Ollama).
- AI actions respect registry policy: `ai_accessible`, `risk`,
  `confirmation`, `contexts`.
- `ai.*` actions are not re-exposed to AI (no recursion).

## Portability (Void)

The platform abstraction (`adapters/{debian,void}/`) isolates distribution
differences. The Void port is tracked in the separate `OmiVoid-install`
project and requires: xbps packaging, runit services, and exercising the
Void adapters. No architectural change is expected.

## Design documents

The authoritative design lives in the umbrella `OmiVoid` repository:

- `docs/00-project-overview.md` … `docs/14-gks-keyboard-grammar.md`
- `docs/decisions/ADR-*.md` (architecture decision records)
- `PROGRESS.md` (the living progress log)

The implementation's own records are in `omivoid-lmde/docs/`.