#!/usr/bin/env bash
# Store your login password sealed by this machine's TPM, so a face login can still unlock
# the GNOME keyring (~/.local/bin/z13-keyring-unlock reads it at login).
# Run as yourself, in a terminal: bash /usr/share/z13-bazzite/z13-keyring-seal.sh
# Re-run after changing your login password. Undo: rm ~/.config/z13/keyring.cred
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as yourself, not with sudo"; exit 1; }

CRED=$HOME/.config/z13/keyring.cred
read -rsp "Login password: " pw; echo
read -rsp "Again: " pw2; echo
[[ $pw == "$pw2" ]] || { echo "Passwords don't match"; exit 1; }

mkdir -p "${CRED%/*}"; chmod 700 "${CRED%/*}"
printf %s "$pw" | systemd-creds --user encrypt --name=z13-keyring - "$CRED"
chmod 600 "$CRED"
unset pw pw2
echo "Sealed to $CRED"

# Make the "login" keyring the default, so apps store secrets where the login unlock reaches.
echo -n login > ~/.local/share/keyrings/default
~/.local/bin/z13-keyring-unlock && echo "Keyring unlocked: it works."
