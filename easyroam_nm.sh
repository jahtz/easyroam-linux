#!/bin/bash

# +---------------------------------------------+ #
# | Setup easyroam with NetworkManager on linux | #
# | Developed by https://github.com/jahtz       | #
# +---------------------------------------------+ #

# easyroam: https://www.easyroam.de/
# DFN: https://www.dfn.de/


cat <<'EOF'
-----------------------------------------------------------------------------
 easyroam_nm.sh - Easyroam NetworkManager Auto-Setup Script

 This script automates the setup of an eduroam connection on Linux systems using 
 NetworkManager. It imports your Easyroam client certificate (provided as a 
 PKCS#12 (.p12) license file) and configures the necessary network profile for 
 secure wireless authentication.

 Result:
   After running this script, you will have:
    - Your PKCS#12 (.p12) client certificate imported into NetworkManager.
    - A new eduroam Wi-Fi profile configured and ready to use.

 Where to get your .p12 license file:
   The .p12 (PKCS#12) license/certificate file can be downloaded from
   https://www.easyroam.de

 For further instructions, please refer to the README.md file found in
 this repository.

-----------------------------------------------------------------------------
EOF

echo
read -n 1 -s -r -p "Press any key to continue..."
echo

# DEFAULT VALUES
PKPW=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 15)  # random password
OUTDIR="$( getent passwd "$USER" | cut -d: -f6 )/.cert/easyroam"
LEGACY="-legacy"

# DEPENDENCY CHECK
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

echo "Checking dependencies:"
check_dependency "nmcli"
check_dependency "openssl"

# PROMTS
echo
echo -e "Select PKCS12 (.p12) bundle file:"
read -e p12file
if [[ -z "$p12file" || ! -f "$p12file" || "${p12file##*.}" != "p12" ]]; then
    echo "Invalid PKCS12 file path!"
    exit 1
fi

echo
echo -e "Set output directory [Default: $OUTDIR]:"
read -e outputdir_new
outputdir="${outputdir_new:-$OUTDIR}"
p12name=$(basename "$p12file")

interfaces=()  # select wireless network interfaces
for iface in $(ls /sys/class/net/); do
    if [ -d "/sys/class/net/$iface/wireless" ]; then
        interfaces+=("$iface")
    fi
done
interface=""
echo -e "\nSelect wifi interface to configure"
PS3="Interface: "
select opt in "${interfaces[@]}" "Exit"; do
    case $opt in
        "Exit")
            exit 0
            ;;
        "")
            echo "Invalid option $REPLY"
            ;;
        *)
            interface="$opt"
            break
            ;;
    esac
done

# LOGIC
echo
echo -n -e "Create output directory... "
umask 077  # certificate and private key must only be readable by the owner
if [[ ! -d "$outputdir" ]]; then
    mkdir -p "$outputdir" || { echo "Failed to create directory."; exit 1; }
fi
echo "Done"

echo -n "Copy PKCS12 file... "
cp "$p12file" "$outputdir" || { echo "Failed to copy PKCS12 file."; exit 1; }
echo "Done"
cd "$outputdir" || { echo "Failed to change directory."; exit 1; }

echo -n "Build client certificate... "
openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
if [[ $? -ne 0 ]]; then
    LEGACY=""
    openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
    if [[ $? -ne 0 ]]; then
        echo "Failed to build client certificate."
        exit 1
    fi
fi
echo "Done"

cn=$(openssl x509 -noout -subject -in easyroam_client_cert.pem | sed -n 's/^.*CN *= *\([^,]*\).*$/\1/p')

echo -n "Build private key... "
openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$PKPW" -out easyroam_client_key.pem -legacy 2>/dev/null
if [[ $? -ne 0 ]]; then
    openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$PKPW" -out easyroam_client_key.pem 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Failed to build private key."
        exit 1
    fi
fi
echo "Done"

echo -n "Build RootCA certificate... "
openssl pkcs12 -in "$p12name" "$LEGACY" -cacerts -nokeys -passin pass: > easyroam_root_ca.pem
if [[ $? -ne 0 ]]; then
    echo "Failed to build RootCA certificate."
    exit 1
fi
echo "Done"

# Delete existing nm configurations
echo -n "Delete existing configurations... "
nmcli connection show eduroam >/dev/null 2>&1 && nmcli connection delete eduroam
nmcli connection show easyroam >/dev/null 2>&1 && nmcli connection delete easyroam

# Create new nm network profile
echo -n "Create new configurations... "
nmcli connection add type wifi ifname "$interface" con-name easyroam ssid eduroam \
    wifi-sec.key-mgmt wpa-eap 802-1x.eap tls 802-1x.identity "$cn" \
    802-1x.altsubject-matches "DNS:easyroam.eduroam.de" \
    802-1x.client-cert "$outputdir/easyroam_client_cert.pem" \
    802-1x.ca-cert "$outputdir/easyroam_root_ca.pem" \
    802-1x.private-key "$outputdir/easyroam_client_key.pem" \
    802-1x.private-key-password "$PKPW" 2>&1

if [[ $? -ne 0 ]]; then
    echo "FAIL: Could not create network configuration."
    exit 1
fi
echo -e "\nSUCCESS: You should now be able to connect to eduroam."

echo -e "\nIdentity: $cn"
echo "Certificate valid until: $(openssl x509 -noout -enddate -in "$outputdir/easyroam_client_cert.pem" | cut -d= -f2)"
