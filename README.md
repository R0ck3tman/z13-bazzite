# z13-bazzite

A custom [Bazzite](https://bazzite.gg) (KDE) image for the **ASUS ROG Flow Z13 (2025, GZ302EA)**,
set up for **Plasma + [Konveyor](https://github.com/DevL0rd/Konveyor)** scrolling tiling, an
iPad-style tablet mode and a PIN on the login screen.
GitHub Actions rebuilds it every Sunday on top of the latest `bazzite:stable`.

Forked from [stephensedge/z13-bazzite](https://github.com/stephensedge/z13-bazzite) (Root & Raid,
[video](https://youtu.be/DsqKCMzaBIE), [guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/)).
On top of that, it carries over the fixes from a CachyOS setup on the same tablet.

## What it adds to stock Bazzite

| Area | What |
|---|---|
| ASUS | asusctl + ROG Control Center (Bazzite retired its ASUS images) |
| Wi-Fi | MT7925: ASPM off, power saving off |
| Bluetooth | Power on at boot, BLE address privacy, reconnect retries + auto-reconnect service, no autosuspend |
| Sleep | Hibernate fixes (unload MT7925, stop sched_ext, `HibernateMode=shutdown`), opt-in USB-wakeup fix for the cover |
| Audio | Speaker amps at 19.5 dB (stock linux-firmware profile) instead of 15.5 dB |
| Input | Cover touchpad marked internal (disable-while-typing), touchscreen access for the tablet kit, `uinput` at boot |
| Tablet | z13ctl-plus (binary + user units only), plasma-keyboard, python3-evdev for the custom OSK helper |
| Login | Login PIN (pam_exec) with faillock. Face unlock is out for now: howdy has no Fedora 45 build |
| Apps | Ghostty, KDE Connect, gnome-keyring (TPM-sealed unlock after PIN login) |
| Tools | `ujust z13-*` recipes for the per-machine steps |

Full list with causes, files and how to verify each one: **[docs/FIXES.md](docs/FIXES.md)**.
Install procedure: **[docs/INSTALL.md](docs/INSTALL.md)**.

## Use it

From a Bazzite (KDE) install:

```bash
sudo bootc switch ghcr.io/r0ck3tman/z13-bazzite:latest
systemctl reboot
```

Roll back any time: `sudo bootc rollback && systemctl reboot`, or pick the previous entry in the
boot menu.

## `ujust` recipes

| Recipe | What |
|---|---|
| `ujust z13-kargs [--brightness-fix]` | USB autosuspend off, RTC wake; optional `amdgpu.dcdebugmask=0x40000` |
| `ujust z13-user-setup` | In Plasma: tablet kit, z13ctl-plus settings, Konveyor, Flatpaks |
| `ujust z13-restore-home [snapshot]` | From a text console: restore Plasma/Konveyor configs from a backup |
| `ujust z13-login-pin [--remove]` | Set/change/remove the login PIN |
| `ujust z13-keyring-seal` | TPM-seal the login password for keyring unlock after PIN login |
| `ujust z13-hibernate-setup [SIZE]` | Swapfile (64G by default) and resume kargs |
| `ujust z13-hibernate-test` | pm_test each hibernate stage |
| `ujust z13-usb-wakeup-fix on\|off` | Stop cover detach from waking the tablet |
| `ujust z13-scx on\|off` | scx_lavd scheduler |

## Notes

- Kernel arguments aren't in the image: they're per machine (`ujust z13-kargs`) and survive updates.
- Nothing secret is in this repo: the PIN hash, face models and sealed keyring password are created
  on the machine.
- Hardware-specific: built for a GZ302EA. On other hardware keep the method, change the fixes.
