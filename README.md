# usbki: Hardened USB & Multi-Modal PAM Authentication

**usbki** is a secure, context-aware authentication framework for Linux (Mint 22/Ubuntu 24.04) that repurposes standard USB flash drives into MFA tokens. It aligns with **NIST SP 800-63B Authenticator Assurance Level 2 (AAL2)**, integrating physical tokens, biometrics, and network-based adaptive logic.

## Technical Architecture

The system operates by intercepting the Linux PAM (Pluggable Authentication Module) stack to orchestrate multiple factors:

1.  **Phase 1: Context Awareness**: `pam_exec.so` triggers a network scan (SSID/BSSID).
2.  **Phase 2: Factor Selection**: Based on context, the stack selects between **AAL1** (Passwordless/Biometric-only) or **AAL2** (USB + Password).
3.  **Phase 3: Hardware Verification**: `pam_usb` validates the hardware UUID and one-time pads (OTP) on the physical token.
4.  **Phase 4: Post-Auth Orchestration**: Successful login triggers a TPM 2.0 unsealing operation to unlock the GNOME Keyring.

---

## Detailed Configuration & Implementation

### 1. TPM 2.0 Keyring Unlocking (ADR 4)
To enable keyring decryption without a password prompt, you must seal your login password to the TPM. **Note:** This requires a hardware TPM 2.0 and `tpm2-tools`.

**Manual Sealing Process:**
```bash
# 1. Create a Primary Object in the Owner Hierarchy
tpm2_createprimary -C o -g sha256 -G rsa -c primary.ctx

# 2. Seal the password (piped from stdin)
echo -n "YOUR_PASSWORD" | tpm2_create -C primary.ctx -i- -u key.pub -r key.priv -a "fixedtpm|fixedparent|adminwithpolicy|sensitiveadataread"

# 3. Load and Evict to a Persistent Handle (0x81010001)
tpm2_load -C primary.ctx -u key.pub -r key.priv -c key.ctx
tpm2_evictcontrol -C o -c key.ctx 0x81010001
```
The script `src/keyring/tpm-unlock.sh` will then utilize this handle to unseal the secret during the login phase.

### 2. Adaptive MFA (AMFA) Logic (ADR 7)
The system uses `src/amfa/context-check.sh` to determine the threat level. 

*   **Trusted Context**: (SSID Match) -> Exits `0`. PAM uses `[success=ok]` to skip the mandatory password requirement.
*   **Untrusted Context**: Exits `1`. PAM proceeds to `common-auth.aal2`, demanding both the USB key and manual password entry.

### 3. Biometric Hardening (ADR 5 & 6)
To prevent spoofing, **usbki** mandates RGB-IR sensor binding rather than standard RGB webcams.

*   **Sensor Pathing**: Identify your IR sensor using `v4l2-ctl --list-devices`.
*   **Binding**: Use the absolute hardware path (e.g., `/dev/v4l/by-path/pci-0000:00:14.0-usb-0:5:1.2-video-index0`) in your biometric config to prevent `v4l2loopback` injection.
*   **Voice Challenge**: The voice module (scaffolded) requires reading a randomized 5-word challenge to defeat deepfake replays.

---

## Security Mitigations (ADR 2)

### UDisks2/PAM Zero-Day Hardening
Due to CVE-2025-6018 and CVE-2025-6019, `udisks2` poses a local root escalation risk. **usbki** deploys a mandatory Polkit rule:

```javascript
// /etc/polkit-1/rules.d/99-udisks2.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.udisks2.modify-device") {
        return polkit.Result.AUTH_ADMIN; // Forces admin auth for device manipulation
    }
});
```

### Brute-Force Protection
`pam_faillock.so` is integrated into the AAL2 stack to prevent automated password/USB probing. After 5 failed attempts, the account is locked for 15 minutes.

---

## Project Structure
```text
usbki/
├── setup.sh                 # Master installation & orchestration script
├── src/
│   ├── amfa/
│   │   └── context-check.sh # Network-aware PAM logic
│   ├── keyring/
│   │   └── tpm-unlock.sh    # TPM-backed keyring decryption
│   ├── biometrics/          # Scaffolding for Howdy/Voice
│   └── install_pam_usb.sh   # Build script for the mcdope/pam_usb fork
├── configs/
│   ├── polkit/
│   │   └── 99-udisks2.rules # UDisks2 mitigation rules
│   └── pam/
│       ├── common-auth.aal1 # NIST AAL1 template (Passwordless)
│       └── common-auth.aal2 # NIST AAL2 template (Strict MFA)
└── docs/
    └── AAL_COMPLIANCE.md    # NIST Benchmarking & Risk Report
```

## NIST Compliance (AAL2)
This architecture is mathematically capped at **AAL2**. It does *not* achieve AAL3 because the "something you have" factor is a bit-for-bit clonable USB drive without an isolated secure enclave. See [docs/AAL_COMPLIANCE.md](docs/AAL_COMPLIANCE.md) for the full risk assessment.
