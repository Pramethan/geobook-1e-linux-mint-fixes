# GeoBook 1E - Linux Mint Fixes

Fixes for the two most commonly reported Linux problems on the **Geo GeoBook 1E**
education laptop: flaky Wi-Fi and a touchpad that moves the cursor but won't
click. Both issues are rooted in cheap, poorly-supported hardware that ships
on a whole class of budget/education laptops (not just the GeoBook), so the
fixes below draw on existing upstream and community work rather than
reinventing anything.

This laptop has a rough reputation in Linux/IT-admin circles - see the
[EduGeek "Geo GeoBook 1E Education Laptops - HORRIBLE!" thread](https://www.edugeek.net/forums/topic/198303-geo-geobook-1e-education-laptops-horrible/#comment-1790165)
for the scale of the problem. This repo exists to give people a working,
scripted fix instead of scouring that thread.

## Affected hardware

Confirmed on a GeoBook 1E with:

- **Wi-Fi/Bluetooth:** Realtek RTL8821CE (`10ec:c821`), PCIe
- **Touchpad:** Synaptics/Hantick I2C-HID touchpad, ACPI HID `SYNA3602:00`,
  I2C ID `0911:5288`

Check your own hardware IDs first:

```bash
lspci -knn | grep -A3 -i network      # Wi-Fi chipset
cat /proc/bus/input/devices | grep -A5 -i touchpad   # touchpad ID
```

If your IDs match, these fixes apply to you.

## Issue 1: Wi-Fi disconnects / drops out

**Symptom:** Wi-Fi connects but drops randomly, fails to reconnect after
suspend, or is generally unstable.

**Cause:** Linux Mint loads the in-kernel `rtw88_8821ce` driver for this
card by default. That driver has well-documented power-management bugs on
most revisions of the RTL8821CE chip.

**Fix:** Replace it with the actively maintained out-of-tree driver from
[`tomaspinho/rtl8821ce`](https://github.com/tomaspinho/rtl8821ce), and
blacklist the broken in-kernel module.

Run:

```bash
sudo scripts/fix-wifi-rtl8821ce.sh
```

Then **fully power off** (not just reboot) and power back on - the card
needs a cold power cycle to reload its firmware cleanly under the new driver.

See [`scripts/fix-wifi-rtl8821ce.sh`](scripts/fix-wifi-rtl8821ce.sh) for
exactly what it does; it's a thin, transparent wrapper, not a black box.

## Issue 2: Touchpad moves the cursor but clicks don't register

**Symptom:** Cursor tracking works fine, but tapping or pressing the
touchpad doesn't register as a click.

**Cause:** This touchpad (`0911:5288`) is a known-troublesome i2c-hid device
found on several Apollo Lake–era budget laptops. Two kernel-level quirks
were needed to make it work properly:

- A fix so the touchpad's HID report descriptor isn't misread as all zeros
  (visible in `dmesg` as `unknown main item tag 0x0` spam), which is what
  causes clicks to silently fail while movement still works.
- An earlier fix so the driver doesn't fail to bind at all on reset.

Both are merged into mainline Linux - **this is not a driver to install,
it's a kernel-version issue.** If you're on an older kernel that predates
these fixes, upgrading resolves it.

**Fix:** Check your kernel and confirm the quirk situation with:

```bash
scripts/check-touchpad-quirk.sh
```

If it tells you to upgrade, do so via Linux Mint's Update Manager
(**View → Linux Kernels**, pick a newer one), or:

```bash
sudo apt install linux-generic-hwe-22.04   #the HWE meta-package your Mint version offers
```

Reboot afterwards and re-run the check script to confirm.

## Why this happened / credits

- Wi-Fi driver: [tomaspinho/rtl8821ce](https://github.com/tomaspinho/rtl8821ce)
  and the wider RTL8821CE Linux community that maintains it.
- Touchpad quirks: upstream Linux HID maintainers, notably the
  `I2C_HID_QUIRK_NO_IRQ_AFTER_RESET` and power-on delay fixes authored by
  Hans de Goede and reviewed by Douglas Anderson, merged into
  `drivers/hid/i2c-hid/i2c-hid.c`.

This repo just packages the diagnosis and the fix into something a GeoBook
1E owner (or a school IT admin managing a fleet of them) can run in two
commands instead of rediscovering all of this from scratch.

## Tested on

- Linux Mint (Cinnamon), GeoBook 1E
- Please open an issue with your Mint version and kernel (`uname -r`) if you
  test this on other configurations — a compatibility table will go here.

## Contributing

If you hit a different issue on the GeoBook 1E (audio, camera, sleep/resume,
battery reporting, etc.), please open an issue or PR. The goal is for this
to become the one-stop fix repo for this laptop on Linux.

## License

MIT — see [LICENSE](LICENSE). The scripts here just orchestrate
third-party drivers and kernel packages; those retain their own licenses
(GPLv2 for the kernel driver and rtl8821ce module).
