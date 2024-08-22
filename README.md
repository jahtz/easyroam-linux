# easyroam-linux
Setup eduroam with easyroam on unsupported linux devices.

## Motivation
German universities (as of the time of writing) are switching from the official eduroam client to [easyroam](https://www.easyroam.de) by [DFN](https://www.dfn.de/) in october 2024.
Since I needed to set up Wi-Fi on my Fedora notebook, I tried to follow their guide but quickly realized that they only officially offer a .deb client for Debian-based distributions. 
So, I sent an email asking for an .rpm package, and they responded with:

> [...]uns ist es leider nicht möglich die easyroam app für RHEL/Fedora basierte Distros (.rpm Package) und/oder für die vielen anderen proprietären Linux Derivate zur Verfügung zu stellen. Das wird uns leider niemals gelingen.

which roughly translates to: no, never.

I then started following their guide for a manual setup but realized they assume you are only using NetworkManager with Debian, which is obviously not always the case. 
So, here is a little script for setting up easyroam/eduroam on Fedora (and probably some other distros). 
Right now, only Fedora and NetworkManager are tested, but if there is interest, I can extend support to other distros and, for example, wpa_supplicant.

## Usage
### Get certificate
1. Open https://www.easyroam.de
2. Search your university and log in.
3. Go to `Generate profile`.
4. Select `manual options`, select `PKCS12` and enter your device name.
5. Download the file by clicking on the `Generate profile`-Button.

### Setup network
1. Download the script:
    ```
    curl -o easyroamlinux.sh https://raw.githubusercontent.com/jahtz/easyroam-linux/main/easyroamlinux.sh
    ```
    or
    ```
    wget -O easyroamlinux.sh https://raw.githubusercontent.com/jahtz/easyroam-linux/main/easyroamlinux.sh
    ```
3. Make it executable:
    ```
    chmod +x easyroamlinux.sh
    ```
4. Run setup:
    ```
    sudo  ./easyroamlinux.sh
    ```
    (enter the path of the downloaded .p12 file and follow the promts)
