#!/usr/bin/bash
# Runs inside the image build (see Containerfile). Everything here ends up in the read-only image.
set -xeuo pipefail

Z13CTL_VER=2.5.1
Z13CTL_TARBALL_SHA256=a5c62537546bdd927d93529b1bc1459f72ea576448135224e00ac1b9415362cb

# --- Packages ------------------------------------------------------------------------------------
# asusctl: fans, power profiles, charge limit, keyboard/cover RGB (Bazzite retired its ASUS images).
# howdy: face unlock. Fedora 44 dropped dlib; this COPR builds dlib + howdy for F44.
# ghostty: terminal. The rest are Fedora packages the restored helpers need.
COPRS=(lukenukem/asus-linux ronnypfannschmidt/howdy-beta scottames/ghostty)
for c in "${COPRS[@]}"; do dnf5 -y copr enable "$c"; done
dnf5 -y install \
    asusctl asusctl-rog-gui \
    howdy howdy-data \
    ghostty \
    gnome-keyring \
    python3-evdev \
    plasma-keyboard \
    kde-connect \
    policycoreutils-python-utils
# Updates come from rebuilding the image, so don't leave the COPRs enabled on the installed system.
for c in "${COPRS[@]}"; do dnf5 -y copr disable "$c"; done

# --- z13ctl-plus (display/tablet coordinator for z13-tablet-kit) ----------------------------------
# Binary + user units only, from the checksum-verified release tarball. Deliberately NOT its RPM:
# that ships udev rules giving the "users" group write access to fans, TDP, charge limit and RGB,
# which asusd already owns.
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/z13ctl-plus.tar.gz" \
    "https://github.com/aic0d3r/z13ctl-plus/releases/download/v${Z13CTL_VER}/z13ctl-plus_${Z13CTL_VER}_linux_amd64.tar.gz"
echo "${Z13CTL_TARBALL_SHA256}  $tmp/z13ctl-plus.tar.gz" | sha256sum -c -
tar -xzf "$tmp/z13ctl-plus.tar.gz" -C "$tmp"
install -Dm755 "$tmp/z13ctl-plus" /usr/bin/z13ctl-plus
install -Dm644 "$tmp/contrib/systemd/user/z13ctl-plus.socket"  /usr/lib/systemd/user/z13ctl-plus.socket
install -Dm644 "$tmp/contrib/systemd/user/z13ctl-plus.service" /usr/lib/systemd/user/z13ctl-plus.service
rm -rf "$tmp"

# --- Speaker amp gain 19.5 dB ---------------------------------------------------------------------
# The CS35L41 amps run Cirrus's 15.5 dB tuning; linux-firmware also ships 19.5 dB. Firmware in
# updates/ is searched first. Speaker protection and per-unit calibration stay active.
src=$(ls /usr/lib/firmware/cirrus/cs35l41/bincfgs/cs35l41-dsp1-19_5dB.bincfg* 2>/dev/null | head -1 || true)
if [[ -n $src ]]; then
    ext=${src##*.bincfg}            # .xz / .zst / empty: must match the file the link points to
    install -d /usr/lib/firmware/updates/cirrus
    for ch in l0 r0; do
        ln -sfn "$src" "/usr/lib/firmware/updates/cirrus/cs35l41-dsp1-spk-prot-10431fb3-${ch}.bincfg${ext}"
    done
    ls -l /usr/lib/firmware/updates/cirrus/
else
    echo "WARNING: 19.5 dB speaker profile not found in linux-firmware; speakers stay at stock gain" >&2
fi

# --- Bluetooth (from stephensedge/z13-bazzite) ----------------------------------------------------
# Power on at boot, resolve rotating BLE addresses (Privacy=device), keep retrying reconnects.
conf=/etc/bluetooth/main.conf
sed -i 's/^#AutoEnable=true/AutoEnable=true/' "$conf"
sed -i 's/^#Privacy = off/Privacy = device/' "$conf"
sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' "$conf"
sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' "$conf"
sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' "$conf"
for want in '^AutoEnable=true' '^Privacy = device' '^ReconnectUUIDs=' '^ReconnectAttempts=15'; do
    grep -q "$want" "$conf" || echo "WARNING: $conf: '$want' not applied (upstream file changed?)" >&2
done

# --- Login PIN on the Plasma login screen -----------------------------------------------------------
# Patch the base image's plasmalogin PAM file: before the password substack, a PIN check that skips
# it on success. Inert until `ujust z13-login-pin` writes /etc/z13-login-pin.
pam=/etc/pam.d/plasmalogin
[[ -f $pam ]] || cp /usr/lib/pam.d/plasmalogin "$pam"
if ! grep -q check-login-pin "$pam"; then
    awk '
      !done && /^auth[ \t]+(substack|include)[ \t]+(password-auth|system-auth|system-login)/ {
        print "# z13-bazzite: login PIN (/usr/libexec/z13/check-login-pin). A right PIN skips the next line;"
        print "# a wrong one is passed on to it as a password attempt, so pam_faillock counts it."
        print "auth        requisite   pam_faillock.so preauth"
        print "auth        [success=1 default=ignore]  pam_exec.so quiet expose_authtok /usr/libexec/z13/check-login-pin"
        done = 1
      }
      { print }
      END { if (!done) exit 1 }' "$pam" > "$pam.new"
    mv "$pam.new" "$pam"
fi
cat "$pam"
# Make wrong PINs/passwords count: 3 failures lock logins for 10 minutes (faillock.conf defaults).
authselect enable-feature with-faillock || echo "WARNING: authselect with-faillock not enabled" >&2
grep -q pam_faillock /etc/pam.d/password-auth || echo "WARNING: password-auth has no pam_faillock" >&2

# --- Services -----------------------------------------------------------------------------------
systemctl enable asusd.service bluetooth-poweron.service bt-auto-reconnect.service

# --- ujust recipes ------------------------------------------------------------------------------
# Same mechanism Bazzite uses for its own recipe files (build_files/bazzite/12-finalize.sh).
grep -q '60-z13.just' /usr/share/ublue-os/justfile || \
    echo 'import "/usr/share/ublue-os/just/60-z13.just"' >> /usr/share/ublue-os/justfile
just --justfile /usr/share/ublue-os/justfile --list | grep -q z13-kargs

# --- Report -------------------------------------------------------------------------------------
rpm -q asusctl howdy python3-dlib ghostty gnome-keyring python3-evdev plasma-keyboard kde-connect
rpm -q plasma-workspace kwin
