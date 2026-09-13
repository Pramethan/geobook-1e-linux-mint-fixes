#!/usr/bin/env bash
#
# fix-wifi-rtl8821ce.sh
#
# Replaces the buggy in-kernel rtw88_8821ce driver with the actively
# maintained out-of-tree driver from tomaspinho/rtl8821ce, for laptops
# using the Realtek RTL8821CE Wi-Fi/Bluetooth chip (PCI ID 10ec:c821).
#
# Verified on: GeoBook 1E, Linux Mint (Cinnamon)
#
# Usage:
#   sudo ./fix-wifi-rtl8821ce.sh
#
# After running, POWER OFF fully (not just reboot) and power back on.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script with sudo: sudo $0" >&2
  exit 1
fi

echo "=== Checking for RTL8821CE hardware ==="
if ! lspci -nn | grep -qi "10ec:c821"; then
  echo "Warning: RTL8821CE (10ec:c821) not detected via lspci." >&2
  echo "This script targets that specific chip. Continuing anyway in 5s..." >&2
  sleep 5
fi

REAL_USER="${SUDO_USER:-$USER}"
BUILD_DIR="/home/${REAL_USER}/rtl8821ce-build"

echo "=== Installing build dependencies ==="
apt-get update
apt-get install -y bc build-essential dkms git "linux-headers-$(uname -r)"

echo "=== Cloning tomaspinho/rtl8821ce into ${BUILD_DIR} ==="
rm -rf "${BUILD_DIR}"
git clone https://github.com/tomaspinho/rtl8821ce.git "${BUILD_DIR}"
chown -R "${REAL_USER}:${REAL_USER}" "${BUILD_DIR}"

echo "=== Building and installing driver via DKMS ==="
cd "${BUILD_DIR}"
./dkms-install.sh

echo "=== Blacklisting the broken in-kernel rtw88_8821ce driver ==="
BLACKLIST_FILE="/etc/modprobe.d/blacklist-rtw88-8821ce.conf"
if ! grep -qs "blacklist rtw88_8821ce" "${BLACKLIST_FILE}" 2>/dev/null; then
  echo "blacklist rtw88_8821ce" > "${BLACKLIST_FILE}"
  echo "Wrote blacklist entry to ${BLACKLIST_FILE}"
else
  echo "Blacklist entry already present."
fi

echo "=== Regenerating initramfs ==="
update-initramfs -u

cat <<'EOF'

=== Done ===

Next steps:
  1. Fully power off the laptop (sudo poweroff) - a plain reboot is often
     not enough, the card needs a cold power cycle to reload firmware.
  2. Power back on.
  3. Verify with:  lsmod | grep 8821ce
     You should see "8821ce" loaded, and NOT "rtw88_8821ce".
  4. Test Wi-Fi stability, including one sleep/wake cycle.

If NetworkManager shows false "no internet" warnings on a working
connection afterwards, see the README for the optional connectivity-check
fix.
EOF
