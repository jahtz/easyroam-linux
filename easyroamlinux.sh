#!/bin/bash

# Generate a random certificate password
pkpw=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 15)

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to check for dependencies
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

# Check for required dependencies
echo "Checking dependencies:"
check_dependency "nmcli"
check_dependency "openssl"

# Prompt for PKCS12 file and validate input
echo -e "\nSelect PKCS12 (.p12) bundle file:"
read -e p12_path

if [[ -z "$p12_path" || ! -f "$p12_path" || "${p12_path##*.}" != "p12" ]]; then
    echo "Invalid PKCS12 file path!"
    exit 1
fi

# Set output directory
default_cert_path="/etc/NetworkManager/certs/"
echo -e "\nSet certificate directory [Default: $default_cert_path]:"
read -e certs_path
certs_path="${certs_path:-$default_cert_path}"

# Select network interface
interfaces=()
for iface in $(ls /sys/class/net/); do
    if iw dev "$iface" info &>/dev/null; then
        interfaces+=("$iface")
    fi
done

wifi_interface=""
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
            wifi_interface="$opt"
            break
            ;;
    esac
done

# Create certificate directory if it doesn't exist
echo -n -e "\nCreate certificate directory... "
if [[ ! -d "$certs_path" ]]; then
    mkdir -p "$certs_path" || { echo "Failed to create directory."; exit 1; }
fi
echo "Done"

# Copy PKCS12 file
echo -n "Copy PKCS12 file... "
cp "$p12_path" "$certs_path" || { echo "Failed to copy PKCS12 file."; exit 1; }
echo "Done"

cd "$certs_path" || { echo "Failed to change directory."; exit 1; }
p12_name=$(basename "$p12_path")

# Build client certificate
echo -n "Build client certificate... "
openssl pkcs12 -in "$p12_name" -legacy -nokeys -passin pass: | openssl x509 > easyroam_client_cert.pem
if [[ $? -ne 0 ]]; then
    echo "Failed to build client certificate."
    exit 1
fi
cn=$(openssl x509 -noout -subject -in easyroam_client_cert.pem | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')
echo "Done"

# Build private key
echo -n "Build private key... "
openssl pkcs12 -legacy -in "$p12_name" -nodes -nocerts -passin pass: | openssl rsa -aes256 -passout pass:"$pkpw" -out easyroam_client_key.pem 2>/dev/null
if [[ $? -ne 0 ]]; then
    echo "Failed to build private key."
    exit 1
fi
echo "Done"

# Build RootCA certificate
echo -n "Build RootCA certificate... "
openssl pkcs12 -in "$p12_name" -legacy -cacerts -nokeys -passin pass: > easyroam_root_ca.pem
if [[ $? -ne 0 ]]; then
    echo "Failed to build RootCA certificate."
    exit 1
fi
echo "Done"

# Delete existing configurations
echo -n "Delete existing configurations... "
nmcli connection show eduroam >/dev/null 2>&1 && nmcli connection delete eduroam
nmcli connection show easyroam >/dev/null 2>&1 && nmcli connection delete easyroam

# Create new network profile
echo -n "Create new configurations... "
nmcli connection add type wifi ifname "$wifi_interface" con-name easyroam ssid eduroam \
    wifi-sec.key-mgmt wpa-eap 802-1x.eap tls 802-1x.identity "$cn" \
    802-1x.client-cert "$certs_path/easyroam_client_cert.pem" \
    802-1x.ca-cert "$certs_path/easyroam_root_ca.pem" \
    802-1x.private-key "$certs_path/easyroam_client_key.pem" \
    802-1x.private-key-password "$pkpw" 2>&1

if [[ $? -ne 0 ]]; then
    echo "Failed to create network configuration."
    exit 1
fi
echo -e "\nSUCCESS: You should now be able to connect to eduroam."
