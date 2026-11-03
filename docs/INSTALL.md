# Install: CachyOS → Bazzite with this image

Order matters: the image is built and checked **before** the CachyOS install is wiped.

## Phase 0: before wiping CachyOS

1. `bash ~/z13-backup.sh` with the USB drive (USBDRIVE) plugged in. That snapshot holds **configs only**.
2. Copy personal data separately: `Documents`, `Pictures`, `Projects`, `Games`, `Music`, `Videos`,
   `winboat`, `hue`, `~/.ssh`, `~/.gnupg`, browser and Thunderbird profiles, Lutris prefixes.
3. Test the brightness bug: `brightnessctl set 100%`. Note whether the panel goes black.
4. Have Wi-Fi passwords and 2FA/recovery codes at hand.

## Phase 1: build

5. Push to `main` (or run the workflow by hand): Actions → "Build and push the image".
6. Make the package public once: GitHub → your profile → Packages → `z13-bazzite` → Package
   settings → Change visibility → Public. (Or keep it private and `sudo podman login ghcr.io` on the tablet.)
7. Read the build log's last step: every `rpm -q` line should show a version, and there should be
   no `WARNING:` lines (speaker gain, Bluetooth, faillock).

## Phase 2: install Bazzite

8. Download the Bazzite ISO from bazzite.gg: Desktop, AMD GPU, **KDE**. Install with defaults
   (btrfs; no encryption, as before). Secure Boot off.
9. First boot, let it update, then:
   ```bash
   sudo bootc switch ghcr.io/r0ck3tman/z13-bazzite:latest
   systemctl reboot
   ```
   Check with `rpm-ostree status`. Keep the stock image as a fallback:
   `sudo ostree admin pin 1` (index 1 = the previous deployment; check `rpm-ostree status` first).
10. `ujust z13-kargs` (add `--brightness-fix` if step 3 went black). Reboot.

## Phase 3: desktop

11. In Plasma: `ujust z13-user-setup` (Flatpaks, tablet kit, z13ctl-plus, Konveyor).
12. Log out → Ctrl+Alt+F3 → log in → `ujust z13-restore-home` (USB plugged in). Log back in to Plasma.
13. `ujust z13-howdy-setup`, `ujust z13-login-pin`, `ujust z13-keyring-seal`. Lock the screen to test
    face unlock; reboot to test the PIN.
14. Mic: `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.40`. EasyEffects: set "Z13 Speakers" to autoload.
15. Optional: `ujust z13-scx on` (scx_lavd, as on CachyOS).

## Phase 4: hibernate (last)

16. `ujust z13-hibernate-setup`, reboot, `ujust z13-hibernate-test`, then `systemctl hibernate`.
    If resume fails, leave it: power button and cover close stay on plain suspend until step 16
    succeeds (`rm /etc/systemd/logind.conf.d/z13-hibernate.conf` to go back).

## Checklist

- [ ] `rpm-ostree status` shows `ghcr.io/r0ck3tman/z13-bazzite`; `systemctl status asusd` active
- [ ] Charge limit 80% survives a reboot; cover RGB follows ROG Control Center
- [ ] `journalctl -k -b | grep Gain:` shows 19
- [ ] `iw dev wlan0 get power_save` = off; Wi-Fi survives 5 suspend cycles
- [ ] Bluetooth mouse reconnects after suspend without re-pairing
- [ ] Brightness at 100% isn't black
- [ ] Konveyor loads after login, and again after the next image update (it rebuilds at login)
- [ ] Tablet mode: posture switch, iPad mode, OSK with Ctrl/Alt/Super, all four edge swipes
- [ ] Docked: both monitors at 1440p144, eDP centred below
- [ ] Lock screen face unlock; login PIN; keyring unlocked after both
- [ ] Hibernate + resume with Wi-Fi back

## Known risks

- **Plasma 6.8 → 6.7.** The CachyOS configs come from Plasma 6.8; Bazzite stable has 6.7.5. Watch
  `z13-ipad-mode`'s title-bar rule (`kwinrulesrc`) and the third-party widgets. Monitor layout
  (`kwinoutputconfig.json`) isn't restored on purpose.
- **Applet numbers** in the edge-swipe KWin script can change if widgets get re-added: re-run
  `~/z13-ipad-edges.sh` from the USB.
- **Hibernate on Bazzite** has open resume-failure reports on other hardware.
- **SELinux** (enforcing on Bazzite, not used on CachyOS) could block the PIN helper or howdy. The
  password always still works; check `sudo ausearch -m avc -ts recent`.

## Rollback

`sudo bootc rollback && systemctl reboot`, or pick the older boot entry. Kernel arguments and `/var`
(your home folder) aren't touched by image changes.
