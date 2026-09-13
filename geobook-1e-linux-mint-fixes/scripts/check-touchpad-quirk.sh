#!/usr/bin/env bash
#
# check-touchpad-quirk.sh
#
# Diagnoses the "cursor moves but clicks don't register" touchpad issue
# on laptops with the Synaptics/Hantick I2C-HID touchpad
# (ACPI HID "SYNA3602:00", I2C ID 0911:5288).
#
# This touchpad needed two kernel-level i2c-hid fixes to work reliably:
#   - I2C_HID_QUIRK_NO_IRQ_AFTER_RESET (fixes failure to bind at all)
#   - a mandatory 60ms delay after power-on commands (fixes the HID
#     report descriptor being misread as all zeros, which is what
#     causes movement to work but clicks to silently fail)
#
# Both are merged into mainline Linux. This script does not patch
# anything - it tells you whether you're likely missing these fixes
# and need a kernel upgrade.
#
# Usage:
#   ./check-touchpad-quirk.sh

set -uo pipefail

echo "=== Touchpad hardware check ==="
if ! cat /proc/bus/input/devices 2>/dev/null | grep -qi "0911:5288\|SYNA3602"; then
  echo "This system does not appear to have the SYNA3602:00 (0911:5288) touchpad."
  echo "This script is specific to that hardware. Exiting."
  exit 0
fi
echo "Detected: SYNA3602:00 0911:5288 touchpad."
echo

echo "=== Kernel version ==="
KERNEL_VER="$(uname -r)"
echo "Running kernel: ${KERNEL_VER}"
echo

echo "=== Checking dmesg for known symptom ==="
if dmesg 2>/dev/null | grep -qi "unknown main item tag 0x0"; then
  echo "FOUND: 'unknown main item tag 0x0' spam in dmesg."
  echo "This is the classic signature of the HID descriptor being"
  echo "misread as all zeros - the exact cause of clicks not registering."
  echo
  echo "RECOMMENDATION: Upgrade your kernel."
  FOUND_ISSUE=1
else
  echo "Did not find the 'unknown main item tag 0x0' pattern in the current"
  echo "dmesg buffer (note: dmesg only holds logs since last boot, and may"
  echo "have wrapped on a long-running session)."
  FOUND_ISSUE=0
fi
echo

if dmesg 2>/dev/null | grep -qi "failed to reset device"; then
  echo "FOUND: 'failed to reset device' for this touchpad in dmesg."
  echo "This is the older bind-failure bug (no IRQ after reset)."
  FOUND_ISSUE=1
fi

echo "=== Verdict ==="
if [[ "${FOUND_ISSUE}" -eq 1 ]]; then
  cat <<EOF
Your kernel is very likely missing the i2c-hid fixes this touchpad needs.

To fix: upgrade your kernel via Linux Mint's Update Manager
(View -> Linux Kernels, pick a newer one) or install an HWE kernel, e.g.:

  sudo apt install linux-generic-hwe-22.04

(substitute the HWE package matching your Mint/Ubuntu base version)

Then reboot and re-run this script to confirm the symptom is gone.
EOF
else
  cat <<EOF
No direct evidence of the missing-fix symptom was found in the current
dmesg buffer. If you were still experiencing clicks not registering
before a kernel upgrade, and it's resolved now, you're on a kernel new
enough to have both i2c-hid fixes for this touchpad.

If clicks are still not registering despite this, the cause may be
something else (e.g. tap-to-click disabled in touchpad settings, or a
libinput configuration issue) rather than the kernel quirk.
EOF
fi
