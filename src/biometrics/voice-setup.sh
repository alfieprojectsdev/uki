#!/bin/bash
# usbki: Voice Setup & Dependency Installer (ADR 6)

echo "[*] Installing Python dependencies for voice biometrics..."
sudo apt-get install -y python3-pip libportaudio2 libasound2-dev
pip3 install sounddevice numpy scipy python_speech_features fastdtw --break-system-packages # Use PEP 668 override or venv

echo "[*] Making voice recognition executable..."
chmod +x src/biometrics/voice-recognition.py

echo "[*] Creating embedding storage..."
mkdir -p "$HOME/.config/usbki/voice/"

echo "[*] Initial Voice Training Required."
echo "[!] Record yourself reading the challenge phrases and save as .wav in ~/.config/usbki/voice/"
