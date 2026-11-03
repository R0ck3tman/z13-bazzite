# z13-bazzite: Bazzite (KDE) for the ASUS ROG Flow Z13 (2025, GZ302EA, Strix Halo),
# set up for Plasma + Konveyor with tablet mode, face unlock and a login PIN.
#
# Bazzite is image-based: system files are read-only and arrive as one image. Instead of changing
# the system by hand, the changes are described here, GitHub Actions builds the image every week on
# top of the latest Bazzite, and the tablet switches to it with `bootc switch`. The previous image
# stays on disk, so a bad build is one reboot away from being undone.
#
# What each fix does and why: docs/FIXES.md. Install procedure: docs/INSTALL.md.

FROM ghcr.io/ublue-os/bazzite:stable

# Config files, udev rules, sleep hooks, PAM, helper scripts, ujust recipes (mirrors the filesystem).
COPY files/ /

# Packages (asusctl, howdy, ghostty, ...), z13ctl-plus, speaker gain, Bluetooth, login PIN, services.
COPY build.sh /tmp/build.sh
RUN bash /tmp/build.sh && rm -f /tmp/build.sh && ostree container commit
