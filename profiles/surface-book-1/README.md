# Surface Book 1 profile (optional)

Hardware-specific extras for the Microsoft Surface Book 1 (2016), the
reference device Ominty was developed on. **Not required** for a general
Debian desktop — apply only if you are on this hardware.

## What's here

| File | Purpose |
|---|---|
| `niri-outputs.kdl` | Built-in panel (`eDP-1`) at 2× scale. Copy to `~/.config/niri/dms/outputs.kdl` (or merge into your `config.kdl`). |
| `dgpu-power.sh` | Power the NVIDIA GeForce 940MX (in the base) on/off. The dGPU is firmware-powered-off by default and must be enabled before it appears in PCI enumeration. |

## Applying

```sh
# Outputs (2× scale on the built-in panel)
cp profiles/surface-book-1/niri-outputs.kdl ~/.config/niri/dms/outputs.kdl

# dGPU control (root-owned sysfs attribute)
sudo install -m 755 profiles/surface-book-1/dgpu-power.sh /usr/local/bin/dgpu-power
dgpu-power status
```

## Notes

- Verified on LMDE 7, kernel `6.17.1-surface-2` (2026-09-05). The Surface
  kernel comes from the [linux-surface](https://github.com/linux-surface/linux-surface)
  project — install it **before** the dGPU script will work.
- The dGPU is only present when the base is attached; `dgpu-power status`
  reports "not visible" when the base is detached.
- Other Surface models (Book 2/3, Laptop, Pro) may need different
  `outputs.kdl` values — see `docs/HARDWARE.md`.