#!/usr/bin/env bash
# Per-user part of z13-bazzite. Run as yourself inside the Plasma (Wayland) session:
#   ujust z13-user-setup        (or: bash /usr/share/z13-bazzite/z13-user-setup.sh)
# Installs into your home folder: z13-tablet-kit, z13ctl-plus user service settings, Konveyor, the
# Flatpak apps, and a few Plasma settings. Safe to run again.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not with sudo"; exit 1; }
[[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]] || { echo "Run this inside the Plasma session"; exit 1; }

KIT_REF=v1.0.4
SRC=$HOME/.local/src
UNITS=$HOME/.config/systemd/user
mkdir -p "$SRC" "$UNITS" "$HOME/.local/bin"

fetch() {  # repo dir [ref]
  if [[ -d $2/.git ]]; then git -C "$2" fetch -q --tags origin; else git clone -q "$1" "$2"; fi
  [[ -z ${3:-} ]] || git -C "$2" checkout -q "$3"
}

echo "==> Flatpak apps"
flatpak install -y --noninteractive flathub \
  org.chromium.Chromium io.github.zen_browser.zen org.mozilla.Thunderbird com.discordapp.Discord \
  com.github.wwmm.easyeffects || echo "    Some Flatpaks failed; install them later from Bazaar."

echo "==> z13-tablet-kit $KIT_REF"
fetch https://github.com/aic0d3r/z13-tablet-kit "$SRC/z13-tablet-kit" "$KIT_REF"
for f in dock z13-tablet-switch z13-touch-scroll; do install -Dm755 "$SRC/z13-tablet-kit/bin/$f" "$HOME/.local/bin/$f"; done
# Two-finger scroll: wheel events go to the window under the pointer, so move the pointer to the fingers.
# Written for KIT_REF above; if the kit changes, git apply fails here rather than patching the wrong code.
(cd "$HOME/.local/bin" && git apply /usr/share/z13-bazzite/z13-touch-scroll-pointer.patch)
install -Dm644 "$SRC/z13-tablet-kit/systemd/z13-tablet-switch.service" "$UNITS/z13-tablet-switch.service"
install -Dm644 "$SRC/z13-tablet-kit/systemd/z13-touch-scroll.service"  "$UNITS/z13-touch-scroll.service"

echo "==> z13ctl-plus (display/tablet duties only)"
# The image ships the binary and user units but NOT z13ctl-plus's udev rules: asusd owns fans, power
# profiles, RGB and the charge limit. No Armoury-button watcher, no power presets (they set 60 Hz on
# battery and re-applied it after every resume).
mkdir -p "$UNITS/z13ctl-plus.service.d"
printf "[Service]\nExecStart=\nExecStart=/usr/bin/z13ctl-plus daemon --no-button\n" > "$UNITS/z13ctl-plus.service.d/no-button.conf"
rm -f "$UNITS"/{z13ctl-plus,z13-tablet-switch,z13-touch-scroll}.service.d/plasma-only.conf  # Hyprland is gone
systemctl --user daemon-reload
systemctl --user enable --now z13ctl-plus.socket z13ctl-plus.service
sleep 1
z13ctl-plus preset policy --disable
z13ctl-plus tablet settings set --touchpad-enabled=true --disable-touchscreen-in-desktop=false --two-finger-hold-context-menu=true \
  --keep-display-scale=false --scroll-sensitivity=5 --scroll-speed=1
systemctl --user enable --now z13-tablet-switch.service z13-touch-scroll.service

echo "==> Plasma settings"
osk=/usr/share/applications/org.kde.plasma.keyboard.desktop   # not kcm_plasmakeyboard.desktop
if [[ -e $osk ]]; then
  kwriteconfig6 --file kwinrc --group Wayland --key InputMethod "$osk"
else
  echo "    plasma-keyboard not found; pick it in System Settings > Keyboard > Virtual Keyboard"
fi
# Face/PIN login can't hand a password to the wallet, so ~/.local/bin/z13-keyring-unlock unlocks the
# GNOME keyring from a TPM-sealed copy instead. Make gnome-keyring the Secret Service, not KWallet.
kwriteconfig6 --file kwalletrc --group Wallet --key Enabled false
kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false

echo "==> Konveyor"
# On Bazzite its installer builds in a toolbox matching the system KWin, installs to ~/.local, and
# rebuilds itself at the next login after each image update.
fetch https://github.com/DevL0rd/Konveyor "$SRC/konveyor" main
(cd "$SRC/konveyor" && ./install.sh)

cat <<'MSG'

Done. Next:
  1. Log out, switch to a text console (Ctrl+Alt+F3), log in there and run:
       bash /usr/share/z13-bazzite/z13-restore-home.sh /run/media/$USER/USBDRIVE/z13-setup/cachyos/snapshot
  2. Log back in to Plasma.
By hand, once:
  * Quick Settings > Auto-rotate > right-click > "Rotate only in tablet mode"
  * System Settings > Power Management: "When laptop lid closed" = Sleep; untick
    "Even when an external monitor is connected".
MSG
