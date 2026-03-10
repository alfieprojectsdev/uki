#!/bin/bash
# usbki: Adaptive Multi-Factor Authentication (AMFA) Context Check
# ADR 7: Network-Aware Authentication

# Configuration (Add your trusted SSIDs/BSSIDs here)
TRUSTED_NETWORKS=("Home-Secure" "Office-WPA3")
TRUSTED_BSSIDS=("00:11:22:33:44:55") # Optional: Harder to spoof than SSID

# 1. Check if nmcli is available
if ! command -v nmcli &> /dev/null; then
    echo "nmcli not found, defaulting to UNTRUSTED." >&2
    exit 1
fi

# 2. Get current SSID and BSSID
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
CURRENT_BSSID=$(nmcli -t -f active,bssid dev wifi | grep '^yes' | cut -d: -f2-7)

# 3. Check for Ethernet (Trusted by default if specified)
ETHERNET_STATE=$(nmcli dev show | grep -A 10 "GENERAL.TYPE: ethernet" | grep "GENERAL.STATE" | awk '{print $2}')
if [[ "$ETHERNET_STATE" == "100" ]]; then # 100 is 'connected' in nmcli
    exit 0 # Ethernet is considered trusted context
fi

# 4. Validate SSID
for SSID in "${TRUSTED_NETWORKS[@]}"; do
    if [[ "$CURRENT_SSID" == "$SSID" ]]; then
        exit 0 # Trusted
    fi
done

# 5. Validate BSSID
for BSSID in "${TRUSTED_BSSIDS[@]}"; do
    if [[ "$CURRENT_BSSID" == "$BSSID" ]]; then
        exit 0 # Trusted
    fi
done

# Default: Untrusted (Exit 1 triggers AAL2/Strict MFA)
exit 1
