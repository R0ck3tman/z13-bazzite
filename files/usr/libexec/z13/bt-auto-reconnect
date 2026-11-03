#!/bin/bash
# Safety net for Bluetooth HID reconnection
# Primary reconnection is handled by BlueZ Privacy=device (IRK resolution).
# This script only clears stuck "InProgress" states that jam bluetoothctl.
# It NEVER removes pairings — address rotation is handled by the kernel IRK.

CHECK_INTERVAL=15
HID_UUID="00001812-0000-1000-8000-00805f9b34fb"

clear_stuck_connection() {
    local addr="$1"
    local dbus_path="/org/bluez/hci0/dev_$(echo "$addr" | tr ':' '_')"

    # Try D-Bus Disconnect to cancel InProgress without restarting bluetooth
    busctl call org.bluez "$dbus_path" org.bluez.Device1 Disconnect 2>/dev/null
    sleep 2
}

while true; do
    while IFS= read -r line; do
        addr=$(echo "$line" | awk '{print $2}')
        [ -z "$addr" ] && continue

        info=$(bluetoothctl info "$addr" 2>/dev/null)
        echo "$info" | grep -q "Trusted: yes" || continue
        echo "$info" | grep -q "Paired: yes" || continue
        echo "$info" | grep -q "Connected: yes" && continue
        echo "$info" | grep -q "$HID_UUID" || continue

        name=$(echo "$info" | grep "Name:" | head -1 | sed 's/.*Name: //')

        result=$(timeout 8 bluetoothctl connect "$addr" 2>&1)
        if echo "$result" | grep -q "Connection successful"; then
            logger -t bt-auto-reconnect "Reconnected: $name ($addr)"
        elif echo "$result" | grep -q "InProgress"; then
            logger -t bt-auto-reconnect "Clearing stuck connection for $name ($addr)"
            clear_stuck_connection "$addr"
            # Retry after clearing
            timeout 8 bluetoothctl connect "$addr" >/dev/null 2>&1
            if bluetoothctl info "$addr" 2>/dev/null | grep -q "Connected: yes"; then
                logger -t bt-auto-reconnect "Reconnected after clearing: $name ($addr)"
            fi
        fi
    done <<< "$(bluetoothctl devices Paired 2>/dev/null)"

    sleep "$CHECK_INTERVAL"
done
