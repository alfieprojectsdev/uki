#!/bin/bash
# USBKI: Secure USB Key & Multi-Modal Biometric Implementation Orchestrator

set -e

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Banner
cat << "EOF"
  _   _  ____  ____  _  _______ 
 | | | |/ ___|| __ )| |/ /_   _|
 | | | |\___ \|  _ \| ' /  | |  
 | |_| | ___) | |_) | . \  | |  
  \___/ |____/|____/|_|\_\ |_|  
  Hardened Multi-Modal Authentication
EOF

echo "[*] Initializing usbki Setup (Linux Mint 22 / Ubuntu 24.04 Target)..."

# 2. Dependency Management (Basic & Biometric Prereqs)
sudo apt-get update && sudo apt-get install -y \
    v4l-utils nmcli libxml2-dev libpam0g-dev libudisks2-dev \
    libglib2.0-dev python3 python3-gi gir1.2-udisks-2.0 \
    tpm2-tools build-essential git

# 3. Deploy Polkit Mitigation (ADR 2)
POLKIT_DEST="/etc/polkit-1/rules.d/99-udisks2.rules"
echo "[*] Hardening UDisks2 via Polkit Policy (ADR 2)..."
cp configs/polkit/99-udisks2.rules "$POLKIT_DEST"

# 4. Core USB Auth Build (mcdope fork)
echo "[*] Building pam_usb from source..."
bash src/install_pam_usb.sh

# 5. Biometric Modules
echo "[*] Initializing Biometric Subsystems..."
read -p "Install Facial Recognition (Howdy)? [y/N]: " INSTALL_FACIAL
if [[ "$INSTALL_FACIAL" =~ ^[Yy]$ ]]; then
    bash src/biometrics/howdy-setup.sh
fi

read -p "Install Voice Biometrics Prototype? [y/N]: " INSTALL_VOICE
if [[ "$INSTALL_VOICE" =~ ^[Yy]$ ]]; then
    bash src/biometrics/voice-setup.sh
fi

# 6. Adaptive MFA (AMFA) Setup (ADR 7)
echo "[*] Deploying Network Context Helper (AMFA)..."
AMFA_SCRIPT="/usr/local/bin/usbki-context-check"
cp src/amfa/context-check.sh "$AMFA_SCRIPT"
chmod +x "$AMFA_SCRIPT"

# 7. Final PAM Configuration (ADR 3)
read -p "Target username: " AUTH_USER
pamusb-conf --add-user "$AUTH_USER"

echo -e "\n[SELECT AAL TARGET]"
echo "1) AAL1: Passwordless (Face/Voice OR USB)"
echo "2) AAL2: Strict MFA (USB + Password) [RECOMMENDED]"
read -p "Select [1-2]: " AAL_CHOICE

PAM_TARGET="/etc/pam.d/common-auth"
if [[ "$AAL_CHOICE" == "1" ]]; then
    cp configs/pam/common-auth.aal1 "$PAM_TARGET"
    echo "[!] AAL1 deployed. Note: Security is lower but convenience is high."
else
    cp configs/pam/common-auth.aal2 "$PAM_TARGET"
    echo "[*] AAL2 Strict MFA deployed."
fi

# 8. TPM Keyring Instructions
echo -e "\n[POST-INSTALLATION STEPS]"
echo "1. Run 'sudo howdy add' to register your face."
echo "2. Seal your password to the TPM (See README for manual instructions)."
echo "3. Configure trusted SSIDs in $AMFA_SCRIPT."
echo "4. Add voice recordings to ~/.config/usbki/voice/ for training."

echo -e "\n[SUCCESS] usbki system deployed. Reboot is recommended to verify PAM changes."
