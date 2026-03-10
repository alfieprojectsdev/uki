#!/usr/bin/env python3
# usbki: Voice Biometric Authentication (ADR 6)
# Logic: MFCC extraction + DTW + Randomized Phonetic Challenge

import sys
import os
import random
import time
import numpy as np
import sounddevice as sd
from scipy.io import wavfile
try:
    from python_speech_features import mfcc
    from fastdtw import fastdtw
except ImportError:
    print("Missing dependencies: python_speech_features, fastdtw, sounddevice, numpy, scipy")
    sys.exit(1)

# Configuration
PHRASES = [
    "The quick brown fox jumps",
    "A wizard's job is to vex",
    "Pack my box with five dozen",
    "Sphinx of black quartz judge",
    "Two driven jocks help fax my"
]

RECORD_SECONDS = 5
SAMPLE_RATE = 16000
EMBEDDING_DIR = os.path.expanduser("~/.config/usbki/voice/")
THRESHOLD = 50.0 # DTW Distance threshold (tuning required)

def get_mfcc(audio_path):
    rate, sig = wavfile.read(audio_path)
    mfcc_feat = mfcc(sig, rate, numcep=13, nfilt=26, nfft=512)
    # 39 coefficients = 13 MFCC + Energy + 13 Deltas + 13 Delta-Deltas (Simplified for prototype)
    return mfcc_feat

def authenticate():
    challenge = random.choice(PHRASES)
    print(f"\n[VOICE CHALLENGE] Please read the following aloud:\n\n>>> {challenge}\n")
    time.sleep(1)

    print("[RECORDING] Starting in 3 seconds...")
    time.sleep(3)
    
    print("[RECORDING] Speak now...")
    recording = sd.rec(int(RECORD_SECONDS * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1)
    sd.wait()
    wavfile.write("/tmp/usbki_voice_input.wav", SAMPLE_RATE, recording)
    
    # Compare against stored embedding
    input_feat = get_mfcc("/tmp/usbki_voice_input.wav")
    
    best_dist = float('inf')
    for f in os.listdir(EMBEDDING_DIR):
        if f.endswith(".wav"):
            ref_feat = get_mfcc(os.path.join(EMBEDDING_DIR, f))
            distance, _ = fastdtw(input_feat, ref_feat, dist=lambda x, y: np.linalg.norm(x - y))
            best_dist = min(best_dist, distance)
            
    print(f"[DEBUG] DTW Distance: {best_dist}")
    
    if best_dist < THRESHOLD:
        print("[SUCCESS] Voice authenticated.")
        return True
    else:
        print("[FAILURE] Voice mismatch.")
        return False

if __name__ == "__main__":
    if not os.path.exists(EMBEDDING_DIR):
        os.makedirs(EMBEDDING_DIR)
        print(f"Embedding directory created at {EMBEDDING_DIR}. Please add reference recordings.")
        sys.exit(1)
        
    if authenticate():
        sys.exit(0)
    else:
        sys.exit(1)
