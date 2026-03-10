#!/bin/bash
# Test AMFA context-check.sh behavior

# Mock nmcli for testing if it's not present or to simulate states
export PATH="$PWD/tests/mocks:$PATH"
mkdir -p tests/mocks

# Test Case 1: SSID is trusted
cat << 'EOF' > tests/mocks/nmcli
#!/bin/bash
if [[ "$*" == "-t -f active,ssid dev wifi" ]]; then
    echo "yes:Home-Secure"
fi
EOF
chmod +x tests/mocks/nmcli
bash src/amfa/context-check.sh
if [ $? -eq 0 ]; then
    echo "[PASS] Trusted SSID detected."
else
    echo "[FAIL] Trusted SSID NOT detected."
    exit 1
fi

# Test Case 2: SSID is untrusted
cat << 'EOF' > tests/mocks/nmcli
#!/bin/bash
if [[ "$*" == "-t -f active,ssid dev wifi" ]]; then
    echo "yes:Public-Coffee-Shop"
fi
EOF
chmod +x tests/mocks/nmcli
bash src/amfa/context-check.sh
if [ $? -eq 1 ]; then
    echo "[PASS] Untrusted SSID correctly identified."
else
    echo "[FAIL] Untrusted SSID NOT identified."
    exit 1
fi

# Cleanup mocks
rm -rf tests/mocks
echo "[ALL TESTS PASSED]"
