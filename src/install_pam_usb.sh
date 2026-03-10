#!/bin/bash
# pam_usb Installation Script (README / ADR 2)

PREREQS="git libxml2-dev libpam0g-dev libudisks2-dev libglib2.0-dev gir1.2-udisks-2.0 python3 python3-gi tpm2-tools"

echo "[*] Installing prerequisites..."
sudo apt-get update && sudo apt-get install -y $PREREQS

echo "[*] Cloning pam_usb repository..."
git clone https://github.com/mcdope/pam_usb.git /tmp/pam_usb
cd /tmp/pam_usb

echo "[*] Compiling and installing..."
make && sudo make install

echo "[*] Installation complete."
