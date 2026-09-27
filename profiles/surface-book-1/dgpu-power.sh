#!/bin/sh
# dgpu-power.sh — Power the Surface Book 1 discrete GPU on/off
#
# The Surface Book 1 dGPU (NVIDIA GeForce 940MX) lives in the base and is
# powered off by default (firmware-controlled). It must be powered on before
# it appears in PCI enumeration.
#
# Usage:
#   sudo ./dgpu-power.sh on    # power on the dGPU
#   sudo ./dgpu-power.sh off   # power off the dGPU
#   sudo ./dgpu-power.sh status # show whether the dGPU is visible
#
# Requires root (the dgpu_power attribute is root-owned).
# Verified on: LMDE 7, kernel 6.17.1-surface-2 (2026-09-05)
# Upstream reference: linux-surface wiki "Surface Book" — dGPU power state.

DGPU_SWITCH=/sys/bus/platform/devices/MSHW0041:00/dgpu_power
DGPU_PCI=0000:01:00.0

case "$1" in
  on)
    echo 1 | tee "$DGPU_SWITCH"
    echo "dGPU power-on requested. Waiting ~20s for PCIe hot-plug detection..."
    sleep 20
    if lspci -nn | grep -q "10de"; then
      echo "dGPU is now visible:"
      lspci -nn | grep "10de"
    else
      echo "dGPU not yet visible. Check dmesg for PCIe hot-plug events."
      exit 1
    fi
    ;;
  off)
    echo 0 | tee "$DGPU_SWITCH"
    echo "dGPU power-off requested."
    ;;
  status)
    if lspci -nn | grep -q "10de"; then
      echo "dGPU is visible:"
      lspci -nn | grep "10de"
    else
      echo "dGPU is not visible (powered off or base not attached)."
    fi
    ;;
  *)
    echo "Usage: $0 {on|off|status}"
    exit 1
    ;;
esac