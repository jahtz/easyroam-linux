#!/bin/bash

# Setup eduroam with easyroam on unsupported linux devices. 
# Developed by https://github.com/jahtz

# easyroam: https://www.easyroam.de/
# DFN: https://www.dfn.de/


### FUNCTIONS ###
# Function to check for dependencies
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

### DEFAULT VALUES
pkpw=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 15)  # Generate a random certificate password
outputdir="/etc/NetworkManager/certs/"  # default output directory
legacy="-legacy"  # legacy option

### CHECKS ###
# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Check for required dependencies
echo "Checking dependencies:"
check_dependency "nmcli"
check_dependency "openssl"

### PROMTS ###
echo -e "\nSelect PKCS12 (.p12) bundle file:"
read -e p12file

if [[ -z "$p12file" || ! -f "$p12file" || "${p12file##*.}" != "p12" ]]; then
    echo "Invalid PKCS12 file path!"
    exit 1
fi

echo -e "\nChange output directory [Default: $outputdir]:"
read -e outputdir_new
outputdir="${outputdir_new:-$outputdir}"
p12name=$(basename "$p12file")

# Select network interface
interfaces=()
for iface in $(ls /sys/class/net/); do
    if iw dev "$iface" info &>/dev/null; then
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

### LOGIC ###
# Create output directory if it doesn't exist
echo -n -e "\nCreate output directory... "
if [[ ! -d "$outputdir" ]]; then
    mkdir -p "$outputdir" || { echo "Failed to create directory."; exit 1; }
fi
echo "Done"

# Copy PKCS12 file
echo -n "Copy PKCS12 file... "
cp "$p12file" "$outputdir" || { echo "Failed to copy PKCS12 file."; exit 1; }
echo "Done"
cd "$outputdir" || { echo "Failed to change directory."; exit 1; }

# Build client certificate
echo -n "Build client certificate... "
openssl pkcs12 -in "$p12name" "$legacy" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
if [[ $? -ne 0 ]]; then
    legacy=""
    openssl pkcs12 -in "$p12name" "$legacy" -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
    if [[ $? -ne 0 ]]; then
        echo "Failed to build client certificate."
        exit 1
    fi
fi
echo "Done"

# Read CN identity
cn=$(openssl x509 -noout -subject -in easyroam_client_cert.pem | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')

# Build private key
echo -n "Build private key... "
openssl pkcs12 "$legacy" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$pkpw" -out easyroam_client_key.pem -legacy 2>/dev/null
if [[ $? -ne 0 ]]; then
    openssl pkcs12 "$legacy" -in "$p12name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$pkpw" -out easyroam_client_key.pem 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Failed to build private key."
        exit 1
    fi
fi
echo "Done"

# Build RootCA certificate
echo -n "Build RootCA certificate... "
openssl pkcs12 -in "$p12name" "$legacy" -cacerts -nokeys -passin pass: > easyroam_root_ca.pem
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
    802-1x.client-cert "$outputdir/easyroam_client_cert.pem" \
    802-1x.ca-cert "$outputdir/easyroam_root_ca.pem" \
    802-1x.private-key "$outputdir/easyroam_client_key.pem" \
    802-1x.private-key-password "$pkpw" 2>&1

if [[ $? -ne 0 ]]; then
    echo "Failed to create network configuration."
    exit 1
fi
echo -e "\nSUCCESS: You should now be able to connect to eduroam."
