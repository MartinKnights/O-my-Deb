# Troubleshooting

## Installer

### `apt-get install` fails on `dms` / `matugen` / `ghostty`

`dms`, `matugen`, and `ghostty` are **not packaged in Debian** — they come from
AvengeMedia's Open Build Service (OBS). The installer automatically adds two
repositories and their signing keys:

| OBS project | Provides |
|---|---|
| `home:AvengeMedia:danklinux` | `matugen`, `ghostty`, `danksearch`, `dgop`, `niri` (optional) |
| `home:AvengeMedia:dms` | `dms` (the shell itself) |

If keys are rejected or the network is blocked, see the Requirements section in
[INSTALL.md](INSTALL.md).

### `apt-get install` picks the wrong `quickshell` (deprecated OBS build)

The `danklinux` repo also ships a `quickshell` build. Its version number
(`0.3.1.db2`) sorts higher than Debian's (`0.3.0-1~bpo13+1`) and would
therefore be preferred by APT. The installer pins `quickshell` to
`trixie-backports` via `/etc/apt/preferences.d/ominty-quickshell`.

If you have modified this pin, you can restore it:

```sh
printf 'Package: quickshell\nPin: release n=trixie-backports\nPin-Priority: 1001\n' \
  | sudo tee /etc/apt/preferences.d/ominty-quickshell >/dev/null
sudo apt update && sudo apt install -t trixie-backports --reinstall quickshell
```

### `niri validate` reports errors after install

The config includes `dms/*.kdl` fragments and the Ominty-generated
`bindings.kdl`. If a fragment is missing, the include is `optional=true`
and Niri still starts. Re-run `./install.sh` to regenerate, or check:

```sh
ls ~/.config/niri/dms/
ls ~/.config/ominty/generated/niri/bindings.kdl
```

### `ominty` command not found

`~/.local/bin` must be on your `PATH`. Add to `~/.bashrc` / `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Runtime

### DMS bar doesn't appear

```sh
systemctl --user is-active dms
journalctl --user -u dms -n 50
```

If DMS isn't running, start it: `dms` (or check the Niri session autostart).

### `Super+K` does nothing

1. Check the Ominty fragment is included:
   ```sh
   tail -3 ~/.config/niri/config.kdl
   ```
   It must end with the `include ... bindings.kdl` line.
2. Regenerate: `ominty registry build`
3. Reload Niri: `Super+X` → **Reload Niri**, or `niri msg action reload-config`.

### `Super+Space` shows apps but no Ominty actions

The `omintyActions` plugin must be enabled:

```sh
ls ~/.config/DankMaterialShell/plugins/omintyActions
```

and `plugin_settings.json` must have `"omintyActions": { "enabled": true }`.
Re-run `./install.sh` to restore.

### Wallpaper carousel is empty

The carousel reads `~/Wallpapers`. Create it and add images:

```sh
mkdir -p ~/Wallpapers
```

### Audio restart button fails

`system.audio.restart` uses the `service.restart` adapter (systemd user
scope). Check:

```sh
systemctl --user is-active pipewire wireplumber
```

### Network restart drops the connection

`system.network.restart` runs `nmcli networking off/on`. This briefly
disconnects networking — don't run it over a remote session.

## AI

### `Super+A` → Ask AI errors

- Check the provider: `ominty ai provider status`
- If using Ollama: is it running? `ollama list`
- Is the model pulled? `ollama pull qwen2.5:3b`
- Check `~/.config/ominty/ai.toml` for the provider/model configuration.

### AI actions are refused

AI actions respect the registry policy (`ai_accessible`, `risk`,
`confirmation`). Some actions require `--confirmed` or are not AI-accessible
by design. This is intentional — see `docs/ARCHITECTURE.md`.

## Session

### Can't select Niri at the display manager

The Niri `.deb` installs the session file. Verify:

```sh
ls /usr/share/wayland-sessions/niri.desktop
```

If missing, reinstall the package: `sudo apt-get install -y ./packages/niri_*.deb`

### After logout, the session doesn't restart cleanly

Check the journal:

```sh
journalctl --user -b -u dms -n 50
journalctl -b -1 | grep -i niri | tail -20
```

## Reporting issues

Include:

- `cat /etc/os-release`
- `niri --version`, `quickshell --version`, `dms --version`
- The failing command and its output
- `journalctl --user -u dms -n 50` (if DMS-related)