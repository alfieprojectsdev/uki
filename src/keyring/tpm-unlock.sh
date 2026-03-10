#!/bin/bash
# TPM-backed Keyring Decryption Logic (ADR 4)
# Note: Requires tpm2-tools. Ciphertext should be generated during initial setup.

CIPHERTEXT_PATH="$HOME/.config/usbki/keyring.tpm"
TPM_OBJ_HANDLE="0x81010001" # Persisted TPM key handle

if [ ! -f "$CIPHERTEXT_PATH" ]; then
    echo "Ciphertext not found. Initial setup required."
    exit 1
fi

# Decrypt password via TPM and pipe to gnome-keyring
PASSWORD=$(tpm2_unseal -c "$TPM_OBJ_HANDLE" -i "$CIPHERTEXT_PATH")

if [ $? -eq 0 ]; then
    echo -n "$PASSWORD" | gnome-keyring-daemon --unlock
    echo "GNOME Keyring unlocked via TPM."
else
    echo "TPM decryption failed."
    exit 1
fi
