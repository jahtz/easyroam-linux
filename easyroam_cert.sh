#!/bin/bash

# Create client cert, private key and root CA certificate 
# from easyroam PKCS12 file
# Developed by https://github.com/jahtz

# easyroam: https://www.easyroam.de/
# DFN: https://www.dfn.de/


### FUNCTONS ###
# Function to check for dependencies
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

### DEFAULT VALUES ###
homedir=$( getent passwd "$USER" | cut -d: -f6 )  # users home directory
outputdir="$homedir/Documents/easyroam"  # default output directory
legacy="-legacy"  # legacy option

### CHECKS ###
echo "Checking dependencies:"
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

echo
read -sp "Set password for private key: " pkpw
echo
read -sp "Confirm password: " pkpw_confirm
echo
if [[ $pkpw -ne $pkpw_confirm ]]; then
    echo "Passwords do not match!"
    exit 1 
fi

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

# Output CN identity:
echo -e "\nIdentity: $cn"