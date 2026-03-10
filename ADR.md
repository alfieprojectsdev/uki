### Architecture Decision Records (ADRs) - Foundation Updates

#### ADR 1: Hardware Security Key vs. Software-Based USB Key (Updated for NIST Compliance)
*   **Context:** We must decide between purchasing dedicated cryptographic hardware keys (e.g., YubiKey, FIDO2 tokens) or repurposing standard USB flash drives using software to secure local Linux Mint access.
*   **Decision:** Repurpose a standard USB flash drive using software, formally accepting the inability to achieve NIST Authenticator Assurance Level 3 (AAL3).
*   **Technical Justification & Consequence:** NIST SP 800-63B explicitly states that to achieve AAL3 (the highest level of authentication assurance), the authenticator **must** utilize a hardware-protected, non-exportable private key within an isolated execution environment (like a secure element or TPM). Because our chosen architecture uses an ordinary flash drive—which authenticates by verifying unencrypted metadata (UUIDs, Vendor IDs) and software pads—the "key" is inherently exportable and susceptible to physical bit-for-bit cloning. Therefore, this architecture is mathematically capped at **AAL2**. 

#### ADR 2: Software Selection & UDisks2 Vulnerability Mitigation (Critical Update)
*   **Context:** We need software to bridge the USB hardware with the Linux PAM stack. We selected the `mcdope` fork of `pam_usb` because it utilizes `UDisks2` for seamless device auto-probing without requiring manual mounting. 
*   **Decision:** Retain `pam_usb` (`mcdope` fork), but implement mandatory Polkit mitigations to neutralize newly disclosed UDisks2/PAM zero-day vulnerabilities.
*   **Technical Gap & Mitigation:** Recent threat intelligence has disclosed critical local-to-root privilege escalation flaws chained through PAM and the `udisks` daemon (CVE-2025-6018 and CVE-2025-6019). Because `udisks` ships by default and is actively utilized by `pam_usb` to find the physical token, an attacker with active GUI or SSH access could exploit these daemons to gain full root privileges in seconds. 
*   **Implementation Spec:** To safely use `pam_usb`, the system administrator must immediately apply vendor patches for `libblockdev` and Linux PAM (addressing CVE-2025-6020 as well). As a mandatory workaround, the Polkit rule for `org.freedesktop.udisks2.modify-device` must be modified to strictly require administrator authentication (`auth_admin`) to prevent unprivileged abuse of the UDisks daemon.

#### ADR 3: Authentication Level Configuration / PAM Integration (Updated for AAL Mapping)
*   **Context:** How strictly should the Pluggable Authentication Module (PAM) stack enforce the presence of the USB token? Previously, this was left entirely to "user preference."
*   **Decision:** Deprecate "user preference" in favor of strict mappings to **NIST Assurance Levels (AAL1 vs. AAL2)**. 
*   **Technical Implementation:** The PAM configuration (`/etc/pam.d/common-auth`) must be structured deliberately based on the target threat model:
    1.  **AAL1 Target (Passwordless Convenience):** Configured using `auth sufficient pam_usb.so`. NIST defines AAL1 as requiring only single-factor authentication. If the USB is inserted, access is granted immediately. If lost or stolen, whoever holds the USB gains full access.
    2.  **AAL2 Target (Strict MFA):** Configured using `auth required pam_usb.so` followed by `auth required pam_unix.so`. NIST AAL2 mandates proof of possession and control of **two distinct authentication factors** (e.g., "something you have" like the USB, plus "something you know" like a password). This prevents the USB alone from unlocking the system.

---

**System Specifications (Updated for Linux Mint 22 / Ubuntu 24.04 Base)**

**Extended Project Goal:** Implement a fully hardened, multi-modal, and context-aware Pluggable Authentication Module (PAM) architecture integrating software-repurposed USB tokens, RGB-IR facial recognition, and voice biometrics, while securing the GNOME Keyring and adhering to Adaptive Multi-Factor Authentication (AMFA) principles.

**Software Stack & Mint 22 Dependencies:**
*   **USB:** `pam_usb` (maintained `mcdope` fork).
*   **Facial Recognition:** `Howdy` 3.0.0 Beta or `linux-hello`. Because Linux Mint 22 enforces PEP 668 ("externally-managed-environment"), traditional `pip` installations of `dlib` will fail. **Spec:** Installation must route through the `ubuntuhandbook1` PPA, or be built from source using a Python virtual environment and `meson`.
*   **Voice Recognition:** Experimental Python-based PAM wrappers utilizing Mel-frequency cepstral coefficients (MFCC) and Dynamic Time Warping (DTW).
*   **Keyring Automation:** `tpm2-tools` and custom `systemd` user services.

***

### Architecture Decision Records (ADRs) - Refined & Hardened

#### ADR 4: Resolving the GNOME Keyring Bottleneck via TPM 2.0
*   **Context:** Biometric modules and `pam_usb` bypass the standard password prompt, leaving the GNOME Keyring locked. This breaks background applications (browsers, SSH agents) that rely on the keyring.
*   **Decision:** Orchestrate hardware-backed keyring decryption using the laptop's Trusted Platform Module (TPM) 2.0.
*   **Technical Implementation:** 
    1. The user's plaintext password is encrypted using the TPM via the `tpm2_encryptdecrypt` command.
    2. The resulting ciphertext is stored locally in a hidden configuration file.
    3. A custom `systemd` user service (or `pam_exec` script) is triggered upon successful login. This script leverages the TPM to unseal the ciphertext and securely pipes the decrypted password into the `gnome-keyring-daemon`.
*   **Consequences:** The keyring is seamlessly unlocked upon face or USB login. However, this does not prevent "Evil Maid" attacks; if an attacker gains an active session, they could potentially execute the script to decode the password via the TPM. 

#### ADR 5: Hardening Facial Recognition Against Spoofing & Injection
*   **Context:** Standard `Howdy` configurations using RGB webcams are vulnerable to 2D photograph spoofing and virtual camera injection attacks (e.g., injecting deepfakes via `v4l2loopback`). Furthermore, storing facial embeddings in plaintext poses a privacy risk due to inversion attacks capable of reconstructing the user's face.
*   **Decision:** Mandate RGB-IR hardware binding and transition to encrypted embedding storage.
*   **Technical Implementation:**
    *   **Hardware Binding:** Use `v4l2-ctl` to identify the absolute path of the IR sensor under `/dev/v4l/by-path/` (which remains static, unlike `/dev/video*`). Configure Udev rules to ensure the PAM module reads *exclusively* from the physical hardware bus, preventing the software from intercepting streams from virtual loopback devices. The `v4l2loopback` kernel module should be explicitly blacklisted.
    *   **Active Liveness:** Configure Howdy's "rubberstamping" to require a randomized physical action (e.g., a nod) within a 10-second timeout to defeat static IR photo presentation.
    *   **Embedding Encryption:** Transition from Howdy to Rust-based `chissu-pam` (encrypts facial embeddings using D-Bus Secret Service) or `linux-hello` (encrypts 128-D vectors with a Fernet key stored in the TPM).

#### ADR 6: Voice Biometric Architecture & Deepfake Mitigation
*   **Context:** Voice authentication is highly susceptible to AI deepfakes and replay attacks. 
*   **Decision:** Deploy voice biometrics strictly as a secondary factor, protected by Dynamic Time Warping (DTW) and randomized challenge-response protocols.
*   **Technical Implementation:** The module extracts 39 MFCC coefficients (12 MFCC + energy + deltas) to model the voice. To defeat replay attacks and force latency upon real-time deepfake generators, the system will not use a static passphrase. Instead, it will generate a computationally unpredictable phonetic sentence that the user must read aloud. 
*   **Consequences:** Validating against a randomly generated text challenge effectively neutralises static recording attacks. However, variations in background noise, microphone quality, and voice drift (e.g., illness) will result in a high False Rejection Rate (FRR).

#### ADR 7: Adaptive Multi-Factor Authentication (AMFA) via Network Context
*   **Context:** Treating physical location agnostic to threat levels leaves mobile laptops vulnerable on public networks.
*   **Decision:** Implement contextual AMFA using `pam_exec.so` to dynamically alter the authentication stack requirements.
*   **Technical Implementation:** 
    *   Embed `pam_exec.so` early in the PAM configuration to trigger a shell script.
    *   The script utilises `nmcli` to query the currently connected Wi-Fi SSID. 
    *   If the SSID matches a trusted, encrypted home/office network, the script exits with a success code (`0`). The PAM stack uses control flags to "jump" over strict requirements, permitting passwordless login via Face *OR* USB.
    *   If the SSID is unrecognised, the script exits with a failure code (`1`). The jump instruction is ignored, and PAM cascades into strict MFA, demanding Password *AND* USB Token.

#### ADR 8: NIST SP 800-63B Benchmarking & Residual Risk Acceptance
*   **Context:** The architecture must be quantified against federal standards to understand its true security ceiling.
*   **Decision:** Classify the system at **Authenticator Assurance Level 2 (AAL2)** and formally accept the risk of physical token cloning.
*   **Technical Justification:** NIST AAL3 requires hardware-bound, non-exportable cryptographic tokens (e.g., FIDO2 YubiKeys utilizing a Secure Enclave). Because `pam_usb` relies on standard flash memory and verifies unencrypted metadata (Vendor ID, Product ID, UUID) and software pads, an attacker with brief physical access can execute a bit-for-bit forensic clone of the drive. 
*   **Compensating Controls:** To fortify the unconditional password fallback against brute-force attacks (a strict AAL2 requirement), the `pam_faillock.so` module must be implemented to enforce progressive lockouts after consecutive failed password or biometric attempts.