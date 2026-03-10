#!/bin/bash
# usbki: Facial Recognition Setup (ADR 5)
# Focuses on IR-sensor binding and spoofing protection

# 1. Install Howdy 3.0.0 (UbuntuHandBook PPA)
echo "[*] Adding Howdy PPA and installing..."
sudo add-apt-repository -y ppa:boltgolt/howdy
sudo apt-get update && sudo apt-get install -y howdy

# 2. Identify the IR sensor path (ADR 5 Requirement)
echo "[*] Attempting to identify IR sensor..."
IR_PATH=$(v4l2-ctl --list-devices 2>/dev/null | grep -A 1 "IR Camera" | tail -n 1 | xargs)

if [ -z "$IR_PATH" ]; then
    echo "[!] IR sensor not automatically found. Please manually identify using 'v4l2-ctl --list-devices'."
    echo "[!] Ensure you bind to the absolute path under /dev/v4l/by-path/ for persistence."
else
    echo "[*] Found potential IR sensor: $IR_PATH"
    # Update Howdy config to use the IR path
    sudo sed -i "s|^device_path.*|device_path = $IR_PATH|" /usr/lib/security/howdy/config.ini
fi

# 3. Harden Howdy Config (ADR 5)
echo "[*] Applying security hardening to Howdy..."
sudo sed -i "s|^dark_threshold.*|dark_threshold = 50|" /usr/lib/security/howdy/config.ini
sudo sed -i "s|^certainty.*|certainty = 3.5|" /usr/lib/security/howdy/config.ini
sudo sed -i "s|^recording_plugin.*|recording_plugin = ffmpeg|" /usr/lib/security/howdy/config.ini

# 4. Blacklist Virtual Cameras (Prevention of v4l2loopback injection)
if ! grep -q "v4l2loopback" /etc/modprobe.d/blacklist.conf 2>/dev/null; then
    echo "blacklist v4l2loopback" | sudo tee -a /etc/modprobe.d/blacklist.conf
fi

echo "[*] Howdy setup complete. Add your face with 'sudo howdy add'."
