# z13-bazzite: ROG Flow Z13 (GZ302EA) recipes. `ujust --list` shows them under [group('Z13')].

# Kernel arguments: USB autosuspend off, RTC wake. Add --brightness-fix if 100% brightness goes black
[group('Z13')]
z13-kargs *ARGS:
    sudo /usr/libexec/z13/z13-kargs {{ ARGS }}

# Per-user setup inside Plasma: tablet kit, z13ctl-plus settings, Konveyor, Flatpaks
[group('Z13')]
z13-user-setup:
    bash /usr/share/z13-bazzite/z13-user-setup.sh

# Restore the CachyOS Plasma/Konveyor configs from the USB snapshot (run from a text console)
[group('Z13')]
z13-restore-home SNAPSHOT="/run/media/$USER/USBDRIVE/z13-setup/cachyos/snapshot":
    bash /usr/share/z13-bazzite/z13-restore-home.sh "{{ SNAPSHOT }}"

# Set or change the login-screen PIN (--remove for password only)
[group('Z13')]
z13-login-pin *ARGS:
    sudo /usr/libexec/z13/z13-login-pin {{ ARGS }}

# Seal your login password in the TPM so PIN login also unlocks the keyring
[group('Z13')]
z13-keyring-seal:
    bash /usr/share/z13-bazzite/z13-keyring-seal.sh

# Hibernation: 64G swapfile and resume kargs. Cover close and power button stay on plain suspend
[group('Z13')]
z13-hibernate-setup SIZE="64G":
    sudo /usr/libexec/z13/z13-hibernate-setup {{ SIZE }}

# Test each hibernate stage with pm_test (writes nothing to disk)
[group('Z13')]
z13-hibernate-test:
    sudo /usr/libexec/z13/z13-hibernate-test

# Keep detaching the keyboard cover from waking the tablet (on|off|status)
[group('Z13')]
z13-usb-wakeup-fix STATE="status":
    sudo /usr/libexec/z13/z13-usb-wakeup-fix {{ STATE }}

# Optional scx_lavd scheduler, as on CachyOS (on|off)
[group('Z13')]
z13-scx STATE:
    sudo /usr/libexec/z13/z13-scx {{ STATE }}
