# Troubleshooting

## Installer

### `apt-get install` fails on `quickshell` / `dms`

DMS and Quickshell come from **Debian backports**. Enable backports:

```sh
# Debian 13
echo "deb http://deb.debian.org/debian trixie-backports main" \
  | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt-get update
```

(LMDE 7 already has backports configured.) Then re-run `./install.sh`.

### `niri validate` reports errors after install

The config includes `dms/*.kdl` fragments and the Omivoid-generated
`bindings.kdl`. If a fragment is missing, the include is `optional=true`
and Niri still starts. Re-run `./install.sh` to regenerate, or check:

```sh
ls ~/.config/niri/dms/
ls ~/.config/omivoid/generated/niri/bindings.kdl
```

### `omivoid` command not found

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

1. Check the Omivoid fragment is included:
   ```sh
   tail -3 ~/.config/niri/config.kdl
   ```
   It must end with the `include ... bindings.kdl` line.
2. Regenerate: `omivoid registry build`
3. Reload Niri: `Super+X` → **Reload Niri**, or `niri msg action reload-config`.

### `Super+Space` shows apps but no Omivoid actions

The `omivoidActions` plugin must be enabled:

```sh
ls ~/.config/DankMaterialShell/plugins/omivoidActions
```

and `plugin_settings.json` must have `"omivoidActions": { "enabled": true }`.
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

- Check the provider: `omivoid ai provider status`
- If using Ollama: is it running? `ollama list`
- Is the model pulled? `ollama pull qwen2.5:3b`
- Check `~/.config/omivoid/ai.toml` for the provider/model configuration.

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