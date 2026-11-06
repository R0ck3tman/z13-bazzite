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
12. Log out → Ctrl+Alt+F3 → log in with the USB plugged in. A text console doesn't mount it for you:
    ```bash
    udisksctl mount -b /dev/sda1   # check the device name with lsblk
    ujust z13-restore-home
    udisksctl unmount -b /dev/sda1
    exit
    ```
    Then Ctrl+Alt+F1 (or F2) and log back in to Plasma.
    If a widget fails with `uses incompatible Qt library`, it was built on the old system: see
    "Rebuilding Punchi Dock" below.
13. `ujust z13-login-pin`, `ujust z13-keyring-seal`. Reboot to test the PIN.
14. Mic: `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.40`. EasyEffects: set "Z13 Speakers" to autoload.
15. Optional: `ujust z13-scx on` (scx_lavd, as on CachyOS).

## Phase 4: hibernate (last)

16. `ujust z13-hibernate-setup`, reboot, `ujust z13-hibernate-test`, then `systemctl hibernate`.
    Power button and cover close stay on plain suspend either way, so if resume fails, you can leave it.
    Control Station's "Hibernate" button really runs suspend-then-hibernate: it sleeps first.

## Rebuilding Punchi Dock

The dock has a compiled plugin tied to the system's Qt version, and nothing rebuilds it automatically.
Repeat this when it fails with `uses incompatible Qt library`, for example after an image update.
Konveyor's toolbox matches the system's Qt, so build there:

```bash
git clone https://github.com/PunchiSoft/punchi-dock-remastered ~/.local/src/punchi-dock-remastered
toolbox run -c konveyor-fedora-44 sudo dnf install -y plasma-workspace-devel-6.7.5-1.fc44 \
  qt6-qtdeclarative-devel qt6-qtshadertools kf6-kconfig-devel kf6-kcoreaddons-devel \
  kf6-kglobalaccel-devel kf6-ki18n-devel kf6-kjobwidgets-devel kf6-kio-devel kf6-kpackage-devel \
  kf6-kservice-devel kf6-kwindowsystem-devel libplasma-devel plasma-activities-devel \
  plasma-activities-stats-devel pipewire-devel kf6-kpackage gettext unzip zip
cd ~/.local/src/punchi-dock-remastered
toolbox run -c konveyor-fedora-44 ./scripts-user/setup.sh --build-only --jobs 4
kpackagetool6 --type Plasma/Applet --upgrade dist/*.plasmoid   # on the host; keep only the newest in dist/
systemctl --user restart plasma-plasmashell
```

Match `plasma-workspace-devel` to the system's version (`rpm -q plasma-workspace`). The clone and
package install only need to happen once; after that, `git pull` and rebuild.

## Checklist

- [ ] `rpm-ostree status` shows `ghcr.io/r0ck3tman/z13-bazzite`; `systemctl status asusd` active
- [ ] Charge limit 80% survives a reboot; ROG Control Center opens; cover and back light follow it
- [ ] `asusctl profile get` shows AC Balanced, battery Quiet
- [ ] `journalctl -k -b | grep Gain:` shows 19
- [ ] `iw dev wlp194s0 get power_save` = off; Wi-Fi survives 5 suspend cycles
- [ ] Bluetooth mouse reconnects after suspend without re-pairing
- [ ] Brightness at 100% isn't black
- [ ] Konveyor loads after login, and again after the next image update (it rebuilds at login)
- [ ] Tablet mode: posture switch, iPad mode, panels hide and return, OSK with Ctrl/Alt/Super, all four edge swipes
- [ ] Docked: both monitors at 1440p144, eDP centred below
- [ ] Lock screen password; login PIN; keyring unlocked after PIN login
- [ ] Hibernate + resume with Wi-Fi back

## Known risks

- **Plasma 6.8 → 6.7.** The CachyOS configs come from Plasma 6.8; Bazzite stable has 6.7.5. Watch
  `z13-ipad-mode`'s title-bar rule (`kwinrulesrc`) and the third-party widgets. Monitor layout
  (`kwinoutputconfig.json`) isn't restored on purpose.
- **Applet numbers** in the edge-swipe KWin script can change if widgets get re-added: follow the note
  that `z13-restore-home` prints at the end. `~/z13-ipad-edges.sh` on the USB writes the old swipes.
- **Hibernate on Bazzite** has open resume-failure reports on other hardware. On this tablet, the first
  real hibernate restored the desktop and then reset (`internal CPU shutdown event`); the next three
  worked, including one right after `z13-hibernate-test`. The cause wasn't found, so save your work first.
- **SELinux** (enforcing on Bazzite, not used on CachyOS) could block the PIN helper. The
  password always still works; check `sudo ausearch -m avc -ts recent`.

## Rollback

`sudo bootc rollback && systemctl reboot`, or pick the older boot entry. Kernel arguments and `/var`
(your home folder) aren't touched by image changes.
