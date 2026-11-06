# Fixes

One section per fix: symptom, cause, where it lives, how to check it. "Upstream" means it came from
stephensedge/z13-bazzite; "CachyOS" means it was found on the previous CachyOS install of this tablet.

## Hardware control

### asusctl + ROG Control Center (upstream)
- **Why:** fans, power profiles (Quiet on battery / Balanced on AC on plug events), 80% charge limit,
  keyboard and cover RGB. Bazzite dropped its ASUS images, so the main image lacks asusctl.
- **Where:** `build.sh` (lukenukem/asus-linux COPR), `asusd.service` enabled.
- **Check:** `systemctl status asusd`; `asusctl battery limit 80` then reboot and `cat /sys/class/power_supply/BAT0/charge_control_end_threshold`.
- **Power profiles:** `z13-user-setup` sets Balanced on AC and Quiet on battery. `z13ctl-plus` logs
  `tuning restored profile=balanced` on every resume, but it runs as the user and can't write the
  profile, so it doesn't override this.

### ROG Control Center crashes on open
- **Symptom:** the window appears, then the app aborts:
  `setup_aura.rs: index out of bounds: the len is 7 but the index is 255`.
- **Cause:** the stock `aura_support.ron` gives GZ302's `18c6` the power zone `None` (255), and the app
  uses that value as an index into its list of zone names.
- **Where:** `files/etc/asusd/asusd_user_ledmodes.ron` reports zone `Keyboard` for `18c6`. It's named
  `GZ302EA` so that it's picked ahead of the stock `GZ302` entry.
- **Check:** `busctl get-property xyz.ljones.Asusd /xyz/ljones/aura/18c6_<bus>_<dev> xyz.ljones.Aura SupportedPowerZones` → `au 1 1`.

### ROG Control Center drives the cover and the back light
- **Why:** ROG Control Center and `asusctl` only change the first aura device, `18c6`. The cover (`1a30`)
  and the light bar need their own writes, and the `z13ctl-plus` daemon restores its own saved lighting
  when the cover is re-attached and after a resume.
- **Where:** `z13-kbd-sync` (`usr/share/z13-bazzite/home/`, installed by `z13-restore-home`) copies 18c6
  changes to the cover, then runs `z13ctl-plus apply` for the keyboard and light bar, which also saves them.
  It does the same at login. Both lights always match: asusd's values are the source of truth.
- **Pulse:** sent to `z13ctl-plus` as `strobe`, the closest name. How it looks hasn't been checked.
- **Check:** change the effect in ROG Control Center, then re-attach the cover and sleep and wake.

### z13ctl-plus instead of z13ctl (changed from upstream)
- **Why:** z13-tablet-kit uses z13ctl-plus as its display/posture coordinator. The project says to
  run only one Z13 hardware daemon, so upstream's z13ctl is dropped.
- **Where:** `build.sh` installs the binary and user units from the release tarball (sha256 pinned).
  Its udev rules and `z13ctl-plus-perms.service` are **not** installed: they give the `users` group
  write access to fans, TDP, charge limit and RGB, which asusd owns.
- **Gotchas:** `preset policy --disable` and `daemon --no-button` (presets set 60 Hz on battery and
  re-applied it after every resume); `tablet settings set` needs all flags. `z13-user-setup` does both.

### Light bar (dropped from upstream)
- Upstream's `lightbar` wrapper, uaccess rule for `18c6`/`1a30` and `gz302ea-lightbar-reset.service`
  (unbinds 18c6 from the asus driver at boot) are not included. The reset service would disturb
  asusd and z13-kbd-sync. The light bar still works without them: on this install the logged-in user
  can already open its hidraw device, and `z13-kbd-sync` drives it through `z13ctl-plus`.

## Wi-Fi and Bluetooth

### MT7925 ASPM off (upstream + CachyOS)
- **Symptom:** suspend crashes / Wi-Fi drops. **Where:** `files/usr/lib/modprobe.d/mt7925e.conf`.
- **Check:** `cat /sys/module/mt7925e/parameters/disable_aspm` → `Y`.

### Wi-Fi power saving off (CachyOS)
- **Where:** `files/usr/lib/NetworkManager/conf.d/z13-wifi-powersave.conf` (`wifi.powersave = 2`).
- **Check:** `iw dev wlp194s0 get power_save` → `off`.

### Bluetooth reconnects (upstream)
- **Symptom:** mice/controllers drop, especially after sleep, and need re-pairing.
- **Cause:** adapter autosuspend, BLE address rotation, too few reconnect attempts.
- **Where:** `btusb enable_autosuspend=0`, udev no-suspend rule for `13d3:3608`, `/etc/bluetooth/main.conf`
  (`AutoEnable`, `Privacy = device`, `ReconnectUUIDs/Attempts/Intervals`, applied by `build.sh`, which
  warns in the build log if a line didn't apply), `bluetooth-poweron.service`, `bt-auto-reconnect.service`
  (every 15 s, reconnects paired+trusted HID devices and clears stuck "InProgress" states; never unpairs).
- **Check:** pair a mouse, trust it, suspend, resume: it reconnects within ~15 s. `journalctl -t bt-auto-reconnect`.

## Sleep and hibernate

### USB wakeup during sleep (upstream, opt-in here)
- **Symptom:** detaching the keyboard cover wakes the tablet straight back up.
- **Where:** `files/usr/lib/systemd/system-sleep/usb-wakeup-fix`, active only with `ujust z13-usb-wakeup-fix on`.
- **Trade-off:** while on, cover keys can't wake the tablet; use the power button. Off by default
  because it wasn't needed on CachyOS.

### Hibernate (CachyOS)
- **Symptoms and causes (found with pm_test):** MT7925 fails to resume (`wiphy_resume -110`); the
  ACPI S4 "platform" stage hangs; taking CPUs offline hangs while sched_ext is loaded.
- **Where:** `files/usr/lib/systemd/system-sleep/z13-mt7925e` (unload mt7925e, stop scx_loader if
  running), `files/usr/lib/systemd/sleep.conf.d/z13.conf` (`HibernateMode=shutdown`,
  `HibernateDelaySec=1h`). Swapfile + resume kargs: `ujust z13-hibernate-setup`.
- **Swapfile size:** 64G by default, since Linux can see up to ~58 GB of RAM.
- **Power button / cover close:** plain suspend, also after `z13-hibernate-setup`. To change that, use
  a logind drop-in whose name sorts after `z13.conf` (see `files/usr/lib/systemd/logind.conf.d/z13.conf`).
- **Check:** `ujust z13-hibernate-test`, then `systemctl hibernate`.

### Shutdown hang on test kernels (upstream, nothing to do)
- `wifi: mt76: Disable napi when removing device` hung every shutdown; reverted before Linux 7.2
  (`3aa1dcaa4f6f`). Bazzite stable is on 7.2.x.

## Display

### Black screen near full brightness (upstream, opt-in)
- **Symptom:** above ~98% brightness the panel goes black.
- **Cause:** amdgpu's custom brightness curve overflows near the top of the range. The kernel log
  shows `Using custom brightness curve` on this panel.
- **Fix:** `ujust z13-kargs --brightness-fix` → `amdgpu.dcdebugmask=0x40000`. Only if you see it.
- Don't add upstream's extra bits (`0x40600` = also PSR-SU and Panel Replay off) up front: the
  author's own sleep freeze came from his boot flags, and went away at defaults. Add them only for flicker.

### Two docked 1440p monitors: stay at 144 Hz (nothing to install)
- **Symptom:** with one monitor at 180 Hz, the second didn't come up in Display Settings.
- **Likely cause:** the dock runs DisplayPort on 2 lanes, so the link is tight even at 144 Hz. Not proven:
  lowering the rate didn't bring the second monitor back by itself, it still had to be enabled by hand.
- **Fix:** set both to 144 Hz in Display Settings. The layout isn't kept in this repo.

## Audio

### Speaker gain 19.5 dB (CachyOS)
- **Why:** the stock 15.5 dB amp tuning is quiet. linux-firmware ships a 19.5 dB profile.
- **Where:** `build.sh` links `cirrus/cs35l41/bincfgs/cs35l41-dsp1-19_5dB.bincfg*` into
  `/usr/lib/firmware/updates/cirrus/` under the GZ302EA names (`…-10431fb3-{l0,r0}`).
- **Check:** `journalctl -k -b | grep Gain:` → `Gain: 19`.
- Also from CachyOS (user side): mic at `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.40` (higher turns on
  the +30 dB boost and clips), EasyEffects "Z13 Speakers" preset.

## Input and tablet

| Fix | Where | Why |
|---|---|---|
| Cover touchpad = internal | `udev/rules.d/99-asus-z13-touchpad.rules` | Disable-while-typing ignores "external" touchpads |
| Touchscreen uaccess + `/dev/input/z13-touchscreen` | `udev/rules.d/70-z13-touchscreen.rules` | z13-tablet-kit reads the ELAN9008 directly |
| `uinput` at boot | `modules-load.d/z13-uinput.conf` | Not autoloaded, so `/dev/uinput` had no uaccess ACL |
| plasma-keyboard + python3-evdev | `build.sh` | Custom OSK; KWin drops modifiers from the input method, so Ctrl/Alt/Super go through `z13-osk-keys` (uinput) |
| Two-finger scroll follows the fingers, in finer steps | `z13-touch-scroll-pointer.patch`, `z13-user-setup` | Wheel events go to the window under the pointer, not under the fingers. Claude Code scrolls this way (it still selects text); plain Ghostty scrolls with one finger |
| `qdbus6` link to `qdbus-qt6` | `build.sh` | Fedora's name differs. Without it, z13-tablet-kit's `dock` logs `touchscreen unavailable` and never sets the posture or OSK mode, and `z13-ipad-mode`'s dock step fails |
| Tablet mode follows KWin 6.7 | `home/.local/bin/z13-ipad-mode` | KWin 6.7 announces tablet mode only with `tabletModeChanged`, so the script also listens for that signal |
| iPad-style panels and swipes | `home/.local/bin/z13-ipad-mode`, `home/.local/share/kwin/scripts/z13-touch-edges` | In tablet mode the dock and top panels hide. Swipe up shows the dock and swipe down shows the top panels, over the apps, for 5 s. Left = notifications, right = app switcher. Panels return when the cover is attached |
| KWin rules list stays complete | `home/.local/bin/z13-ipad-mode` | KWin 6.7 loads only the groups in `[General] rules`, and 6.7 and 6.8 delete groups missing from a non-empty list, so the title-bar rule is added to the list next to any others |
| Swipes over streaming apps | `home/.local/share/kwin/scripts/z13-touch-edges` | Bazzite's streaming launcher opens fullscreen, and KWin blocks edge swipes over fullscreen windows. Fullscreen is cancelled for the launcher's windows in their first 15 s; the player's own button still works after that |

`home/` is `files/usr/share/z13-bazzite/home/`. `z13-restore-home` copies it over the USB snapshot,
because the snapshot holds older versions of these files. Plasma's `windowsgobelow` panel mode reads
back as `none` in scripting; that's a gap in its getter, and the mode does apply.

## Login and lock screen

### Face unlock on the lock screen (out for now)
- **Status:** removed for Fedora 45. The howdy package in `ronnypfannschmidt/howdy-beta` needs Python 3.14,
  and Fedora 45 has 3.15, so the image wouldn't build. The lock screen uses the password until it's back.
- **To bring it back:** when that COPR has a Python 3.15 build, revert the commit that removed it. That
  restores the package, `files/etc/pam.d/kde-fingerprint` (pam_howdy instead of pam_fprintd; there's no
  fingerprint reader) and `ujust z13-howdy-setup` (IR camera path, `timeout = 8`, two models).
  `/etc/pam.d/kde` stays stock: two howdy runs fight over the IR camera.
- **Check:** `build.sh` fails the build if any PAM file still names `pam_howdy`.

### Login PIN (CachyOS)
- **Where:** `build.sh` patches `/etc/pam.d/plasmalogin`: `pam_faillock preauth`, then
  `pam_exec expose_authtok /usr/libexec/z13/check-login-pin` that skips the password substack on
  success. A wrong PIN goes on to the password check, so faillock counts it (`authselect
  with-faillock`: 3 failures → 10 minutes). Inert until `ujust z13-login-pin` creates `/etc/z13-login-pin`.
- Disk isn't encrypted: the PIN is a convenience lock, not data protection.

### Keyring after face/PIN login (CachyOS)
- **Why:** PAM never sees the password, so the keyring stays locked.
- **Where:** gnome-keyring in the image; `z13-user-setup` turns off KWallet's Secret Service;
  `ujust z13-keyring-seal` seals the password with the TPM (`systemd-creds --user`) and creates the
  login keyring if there isn't one (`/usr/libexec/z13/z13-keyring-create`);
  `~/.local/bin/z13-keyring-unlock` (autostart) unlocks at login. Re-seal after a password change.
