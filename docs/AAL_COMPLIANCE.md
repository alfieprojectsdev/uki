# NIST SP 800-63B Benchmarking & Compliance Report (ADR 8)

## Authenticator Assurance Level (AAL)
- **Target:** AAL2
- **Self-Assessment:** Achieved AAL2 (MFA Required). 

## Technical Limitations (ADR 1 & 8)
- **Non-Exportable Key:** NO. The key is software-based and resides on standard flash memory. 
- **Physical Cloning Risk:** YES. The USB token can be cloned bit-for-bit.
- **Security Ceiling:** Capped at AAL2. AAL3 requires hardware-bound cryptographic keys (e.g., FIDO2 tokens).

## Mitigations Implemented
1. **MFA (AAL2 Requirement):** System mandates "Something you HAVE" (USB) and "Something you KNOW" (Password).
2. **Brute-Force Protection:** `pam_faillock.so` enforces 15-minute lockouts after 5 failed attempts.
3. **Privilege Escalation Mitigation:** Polkit restricts UDisks2 device modification to admins only (ADR 2).
4. **Adaptive Context:** Network SSID checks (AMFA) adjust factor requirements based on location (ADR 7).
