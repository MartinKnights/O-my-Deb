# Hardware Support

## Reference hardware

O-my-Deb was developed and validated on a **Microsoft Surface Book 1** (2016):

- Intel Core i7-6600U, 15 GiB RAM
- Built-in panel `eDP-1` at 2× scale
- NVIDIA GeForce 940MX in the base (firmware-powered-off by default)
- LMDE 7, kernel `6.17.1-surface-2` (linux-surface project)

The **Surface Book 1 profile** (`profiles/surface-book-1/`) contains the
hardware extras: the 2× scale output fragment and the `dgpu-power.sh` dGPU
control script. Apply it with:

```sh
./install.sh --profile surface-book-1
```

## General Debian desktops

The base configuration is hardware-agnostic:

- No hard-coded outputs (the `outputs.kdl` fragment is empty by default).
- No hard-coded input devices.
- Window rules target app-ids, not hardware.

On a fresh install, run `niri msg outputs` inside a Niri session to discover
your output names, then add scale/refresh-rate settings to
`~/.config/niri/dms/outputs.kdl`:

```kdl
output "DP-1" {
    scale 1
    // mode "2560x1440@144"
}
```

## Known-good configurations

| Device | Output | Scale | Notes |
|---|---|---|---|
| Surface Book 1 | `eDP-1` | 2 | Profile included |
| Generic desktop | `DP-1` / `HDMI-A-1` | 1 | Add your own `outputs.kdl` |

## Touch / pen devices

Niri supports touch and pen input natively. The Surface Book 1 pen works
out of the box; pressure-sensitive drawing apps (e.g. Xournal++) run under
XWayland.

## dGPU (Surface Book)

The dGPU only appears in PCI enumeration after being powered on:

```sh
sudo dgpu-power on     # ~20s for PCIe hot-plug detection
dgpu-power status
```

It is only present when the base is attached. See
`profiles/surface-book-1/README.md`.

## Contributing a profile

If you get O-my-Deb working on another device, add a `profiles/<device>/`
directory with:

- `niri-outputs.kdl` — the output configuration
- `README.md` — device notes
- Any device-specific scripts

and open a pull request.