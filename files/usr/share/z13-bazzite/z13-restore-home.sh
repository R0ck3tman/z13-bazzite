#!/usr/bin/env bash
# Put back the Plasma/Konveyor part of the CachyOS home snapshot (made by ~/z13-backup.sh).
# Run as yourself from a text console (Ctrl+Alt+F3), NOT from inside Plasma (Plasma rewrites its panel
# file on logout):
#   bash /usr/share/z13-bazzite/z13-restore-home.sh /run/media/$USER/USBDRIVE/z13-setup/cachyos/snapshot
# Run z13-user-setup first (Konveyor's installer changes the panels; this restores yours over it).
# Hyprland/DMS/squeekboard/foot/kitty files are skipped, as is kwinoutputconfig.json (set monitors
# again in System Settings). Replaced files are kept as <file>.pre-restore.
set -euo pipefail
SNAP=${1:?usage: z13-restore-home.sh <snapshot dir>}
TAR=$SNAP/home.tar.gz
[[ -f $TAR ]] || { echo "No home.tar.gz in $SNAP"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not with sudo"; exit 1; }
if pgrep -u "$USER" -x plasmashell >/dev/null; then
  echo "Plasma is running. Log out and run this from a text console (Ctrl+Alt+F3)."; exit 1
fi

include=(
  .config/autostart/z13-keyring-unlock.desktop
  .config/ghostty .config/konveyor .config/matugen .config/Plasma-App-Portal
  .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/gtk-3.0/bookmarks
  .config/kcminputrc .config/kdeglobals .config/kglobalshortcutsrc .config/kwinrc .config/kwinrulesrc
  .config/plasma-localerc .config/plasmanotifyrc .config/plasma-org.kde.plasma.desktop-appletsrc
  .config/plasmarc .config/plasmashellrc
  .config/systemd/user/z13-ipad-mode.service .config/systemd/user/z13-osk-keys.service
  .local/bin/z13-ipad-mode .local/bin/z13-kbd-sync .local/bin/z13-keyring-unlock
  .local/bin/z13-osk-keys .local/bin/z13-osk-layout .local/bin/linux-plasma-screen-rotate
  .local/share/applications .local/share/color-schemes .local/share/icons .local/share/kwin
  .local/share/plasma .local/state/z13ctl-plus
)
# Only extract members that exist in the archive (tar fails on missing ones).
mapfile -t members < <(tar -tzf "$TAR")
want=()
for p in "${include[@]}"; do
  for m in "${members[@]}"; do
    if [[ $m == "$p" || $m == "$p"/* ]]; then want+=("$p"); break; fi
  done
done

echo "==> Saving copies of files that will be replaced"
for m in "${members[@]}"; do
  for p in "${want[@]}"; do
    if [[ $m == "$p" || $m == "$p"/* ]]; then
      [[ -f $HOME/$m && ! -L $HOME/$m ]] && cp -p "$HOME/$m" "$HOME/$m.pre-restore"
      break
    fi
  done
done

# Konveyor loads as a versioned KWin plugin (konveyor_effect_<timestamp>) that its installer enables
# in kwinrc. The CachyOS kwinrc names the old build's id, so keep this install's ids.
konveyor_keys() { grep -oE '^(konveyor_effect|process_monitor_telemetry)_[0-9]+Enabled' "$HOME/.config/kwinrc" 2>/dev/null || true; }
mapfile -t new_ids < <(konveyor_keys)
((${#new_ids[@]})) || echo "    Konveyor isn't installed yet (no plugin id in kwinrc). Run z13-user-setup first, or re-run Konveyor's install.sh after this."

echo "==> Restoring"
tar -xzf "$TAR" -C "$HOME" --exclude='*.pre-*' --exclude='*.backup*' --exclude='lsw-app-*' "${want[@]}"

echo "==> Applying this image's newer tablet-mode, swipe and lighting files"
cp -r /usr/share/z13-bazzite/home/. "$HOME"/

echo "==> Adjusting for Bazzite"
if ((${#new_ids[@]})); then
  for k in $(konveyor_keys); do kwriteconfig6 --file kwinrc --group Plugins --key "$k" --delete; done
  for k in "${new_ids[@]}"; do kwriteconfig6 --file kwinrc --group Plugins --key "$k" true; done
fi
# Web apps: Chromium is a Flatpak here.
for f in "$HOME"/.local/share/applications/webapp-*.desktop; do
  [[ -e $f ]] || continue
  sed -i -E 's#^Exec=chromium #Exec=flatpak run org.chromium.Chromium #' "$f"
done
# EasyEffects presets (from the USB folder next to snapshot/) into the Flatpak's data dir.
ee_src=$(dirname "$SNAP")/easyeffects
ee_dst=$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects
if [[ -d $ee_src ]]; then
  mkdir -p "$ee_dst"; cp -r "$ee_src"/. "$ee_dst"/
  echo "    EasyEffects presets copied; pick 'Z13 Speakers' and set it to autoload on the speakers."
fi

echo "==> User services"
systemctl --user daemon-reload
for u in z13-ipad-mode z13-osk-keys z13-kbd-sync; do systemctl --user enable "$u.service" 2>/dev/null || true; done
command -v plasma-keyboard >/dev/null && "$HOME/.local/bin/z13-osk-layout" || echo "    run ~/.local/bin/z13-osk-layout once plasma-keyboard is installed"

cat <<'MSG'

Done. Log in to Plasma. Then:
  * Panels look wrong or the left swipe opens the wrong widget: applet numbers changed. Re-run
    ~/z13-ipad-edges.sh (from the USB), then copy z13-touch-edges back over what it wrote:
    cp -r /usr/share/z13-bazzite/home/.local/share/kwin/scripts/z13-touch-edges ~/.local/share/kwin/scripts/
    and set the notifications number in its contents/code/main.js.
  * Monitors: System Settings > Display (kwinoutputconfig.json was not restored).
  * Mic level: wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.40
  * Keyring: bash /usr/share/z13-bazzite/z13-keyring-seal.sh
  * Web apps: sign in to each M365 account again (new Chromium profiles).
MSG
