# easyroam-linux
Setup eduroam with easyroam on unsupported linux devices.

## Motivation
German universities (as of the time of writing) are switching from the official eduroam client to [easyroam](https://www.easyroam.de) by [DFN](https://www.dfn.de/) in october 2024.
Since I needed to set up Wi-Fi on my Fedora notebook, I tried to follow their guide but quickly realized that they only officially provide a .deb client for Debian-based distributions and porting the file with [alien](https://joeyh.name/code/alien/) did not work. 

So, I sent an email asking for an .rpm package, and they responded with:

> [...] uns ist es leider nicht möglich die easyroam app für RHEL/Fedora basierte Distros (.rpm Package) und/oder für die vielen anderen proprietären Linux Derivate zur Verfügung zu stellen. Das wird uns leider niemals gelingen.

which roughly translates to: _no, never_.

I started following their [guide](https://doku.tid.dfn.de/de:eduroam:easyroam#installation_der_easyroam_app_auf_linux_geraeten_network_manager) for a manual setup with NetworkManager but realized that they assume you can only use NetworkManager on Debian, which is not always the case. So, here are two small scripts to make your life easier: one for extracting certificate and key files from a PKCS#12 (.p12) bundle file, and another for directly setting up easyroam/eduroam on Fedora (and possibly other distributions as well). 

Currently, the direct setup has been tested only on Fedora with NetworkManager, but I can extend support to other distributions and other network managers if there is interest.

## Usage
### Get certificate
1. Open https://www.easyroam.de
2. Search your university and log in.
3. Go to `Generate profile`.
4. Select `manual options`, select `PKCS12` and enter your device name.
5. Download the file by clicking on the `Generate profile`-Button.

### Fedora with NetworkManger
1. Download the script:
    ```
    curl -o easyroamlinux.sh https://raw.githubusercontent.com/jahtz/easyroam-linux/main/easyroam_nm.sh
    ```
2. Make it executable:
    ```
    chmod +x easyroam_nm.sh
    ```
3. Run setup (this script requires root):
    ```
    sudo  ./easyroam_nm.sh
    ```
4. If you want to delete the generated config remove `/etc/NetworkManager/system-connections/easyroam.nmconnection` or run:
    ```
    nmcli connection delete easyroam
    ```

### Manual extraction
1. Download the script:
    ```
    curl -o easyroamlinux.sh https://raw.githubusercontent.com/jahtz/easyroam-linux/main/easyroam_cert.sh
    ```
2. Make it executable:
    ```
    chmod +x easyroam_cert.sh
    ```
3. Run setup:
    ```
    sudo  ./easyroam_cert.sh
    ```
4. Follow setup guides:
    - [netctl](https://doku.tid.dfn.de/de:eduroam:easyroam#installation_der_easyroam_profile_auf_linux_geraeten) (e.g. Arch)
    - [wpa-supplicant](https://doku.tid.dfn.de/de:eduroam:easyroam#installation_der_easyroam_profile_auf_linux_geraeten_ohne_desktop_umgebung_wpa-supplicant_only) (e.g. Pi OS Lite):<br>
