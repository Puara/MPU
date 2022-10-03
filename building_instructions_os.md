# Building Instructions - Puara Media Processing Unit

- [Building Instructions - Puara Media Processing Unit](#building-instructions---puara-media-processing-unit)
  - [BOM](#bom)
  - [Prepare SD card](#prepare-sd-card)
  - [First configuration](#first-configuration)
  - [Optional: install PiSound drivers if using it](#optional-install-pisound-drivers-if-using-it)
  - [Setting the OS](#setting-the-os)
  - [MPU Script](#mpu-script)
    - [Set RealVNC security scheme](#set-realvnc-security-scheme)
    - [Update OS, install basic apps, and install i3wm as an alternative window manager](#update-os-install-basic-apps-and-install-i3wm-as-an-alternative-window-manager)
    - [Disable the built-in and HDMI audio](#disable-the-built-in-and-hdmi-audio)
    - [Add Metalab's MPA](#add-metalabs-mpa)
    - [Install basic software](#install-basic-software)
    - [Configure AP](#configure-ap)
    - [Set Jack to start at boot](#set-jack-to-start-at-boot)
    - [Set Pure Data systemd service](#set-pure-data-systemd-service)
    - [Set SuperCollider systemd service](#set-supercollider-systemd-service)
    - [Set up i3wm](#set-up-i3wm)
    - [Finish and rebooting](#finish-and-rebooting)

## BOM

- minimal hardware
  - [Raspberry Pi 4 model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
  - external audio interface
- software
  - [Custom PREEMPT-RT kernel](RT_kernel.md) (build on 5.10)
  - [Raspberry Pi OS](https://ubuntu.com/download/raspberry-pi)
  - Metalab software (through the [Metalab's MPA](https://gitlab.com/sat-mtl/distribution/mpa-bullseye-arm64-rpi/))

## Prepare SD card

- Download the (Raspberry Pi Imager)[https://www.raspberrypi.com/software/]
- Flash the Raspberry Pi OS 64 bits into the SD card. Use the configuration tool to set:
  - Enable ssh
  - set hostname: mpuXXX (replace XXX with the MPU's ID)
  - set user and password (mpu/mappings)
  - insert WiFi credential if needed

## First configuration

- ssh to the Rpi: `ssh mpu@<ip_address>` or `ssh mpu@mpuXXX.local`
- run `sudo raspi-config`
  - Update
  - Display Options
    - VNC Resolution: 1920x1080
  - Interface Options
    - VNC: enable (require installing extra packages for Raspberry OS Lite)
  - Performance Options
    - GPU Memory: 256
  - Localization Options
    - WLAN Country: set to the current country
  - Finish and reboot

## Optional: install PiSound drivers if using it

- ssh to the Rpi: `ssh mpu@<ip_address>` or `ssh mpu@mpuXXX.local`
- Execute `curl https://blokas.io/pisound/install.sh | sh` to add the PiSound audio card drivers

## Setting the OS

- Ssh to the Rpi: `ssh mpu@<ip_address>` or `ssh mpu@mpuXXX.local`
- Clone this repository into the Rpi using `mkdir ~/sources && cd ~/sources && git clone https://github.com/Puara/MPU.git`
- Navigate to the MPU folder: `cd ~/sources/mpu`
- Update the `run_script.sh` by running `sudo chmod +x building_script.sh` and `./building_script.sh XXX`, where XXX must be replaced by the MPU's ID
- Make **run_script.sh** executable: `sudo chmod +x run_script.sh`
- Run it with `./run_script.sh`

## MPU Script

### Set RealVNC security scheme

```bash
echo -e "nmappings\nmappings" | sudo vncpasswd -service
sudo sed -i '$a Authentication=VncAuth' /root/.vnc/config.d/vncserver-x11
```

- The password set by default is `mappings`

### Update OS, install basic apps, and install i3wm as an alternative window manager

```bash
sudo apt update -y && sudo apt upgrade -y &&\
sudo apt install -y i3 i3blocks htop vim feh tmux
```

- Update desktop alternatives and select i3 as the default window manager:

```bash
sudo update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/bin/i3 60
echo "2" | sudo update-alternatives --config x-session-manager
```

### Disable the built-in and HDMI audio

```bash
sudo sed -i -e 's/Enable audio (loads snd_bcm2835)/Disable audio (snd_bcm2835)/ ; s/dtparam=audio=on/dtparam=audio=off/ ; s/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/' /boot/config.txt
```

### Add Metalab's MPA

```bash
sudo apt install -y coreutils wget && \
wget -qO - https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/sat-metalab-mpa-keyring.gpg \
    | gpg --dearmor \
    | sudo dd of=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg && \
echo 'deb [ arch=arm64, signed-by=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg ] https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/debs/ sat-metalab main' \
    | sudo tee /etc/apt/sources.list.d/sat-metalab-mpa.list && \
sudo apt update &&\
sudo apt upgrade -y
```

### Install basic software

- Installing SuperCollider, SC3-Plugins, jackd2 (if needed):

```bash
sudo apt install -y supercollider sc3-plugins libmapper python3-netifaces webmapper jackd2 puredata
```

- Installing SATIE:

```bash
echo "Quarks.install(\"SC-HOA\");Quarks.install(\"~/sources/satie\")" | sclang
```

### Configure AP

- Install dependencies:

```bash
sudo apt install -y dnsmasq hostapd
```

- Create the hostapd config file:

```bash
cat <<- "EOF" | sudo tee /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=MPUXXX
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=mappings
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
```

- Configure a static IP for the wlan0 interface:

```bash
sudo sed -i -e 's/hostname/mpuXXX/' -e '$a\\ninterface wlan0\n    static ip_address=192.168.4.1/24\n    nohook wpa_supplicant\n    #denyinterfaces eth0\n    #denyinterfaces wlan0\n' /etc/dhcpcd.conf
```

- Set hostapd to read the config file:

```bash
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd
```

- Start the hostapd service:

```bash
sudo systemctl unmask hostapd &&
sudo systemctl enable hostapd &&
sudo systemctl start hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
```

- Start configuring the dnsmasq service

```bash
sudo unlink /etc/resolv.conf &&
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf &&
cat <<- "EOF" | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF
```

- Modify `/lib/systemd/system/dnsmasq.service` to launch after network get ready:

```bash
sed -i '0,/^\s*$/'\
's//After=network-online.target\nWants=network-online.target\n/' \
/lib/systemd/system/dnsmasq.service
```

- To prevent a long waiting time during boot, edit `/lib/systemd/system/systemd-networkd-wait-online.service`:

```bash
sed -i '\,ExecStart=/lib/systemd/systemd-networkd-wait-online, s,$, --any,' /lib/systemd/system/systemd-networkd-wait-online.service
```

- Then:

```bash
sudo systemctl daemon-reload
```

### Set Jack to start at boot

- Add a dbus security policy:

```bash
cat <<- "EOF" | sudo tee /etc/dbus-1/system.conf
<policy user="micah">
     <allow own="org.freedesktop.ReserveDevice1.Audio0"/>
     <allow own="org.freedesktop.ReserveDevice1.Audio1"/>
</policy>
EOF
```

- Add path to environment:

```bash
cat <<- "EOF" | sudo tee /etc/environment
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
EOF
```

- Create the systemd service file:

```bash
cat <<- "EOF" | sudo tee /lib/systemd/system/jackaudio.service
[Unit]
Description=JACK Audio
After=sound.target

[Service]
User=mpu
Environment="JACK_NO_AUDIO_RESERVATION=1"
ExecStart=/usr/bin/jackd -P50 -t2000 -dalsa -dhw:1 -p128 -n2 -r48000 -s &

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload &&\
sudo systemctl enable jackaudio.service &&\
sudo systemctl start jackaudio.service
```

- Some commands:

- List information and connections on ports: `jack_lsp -c`
- Connect ports: `jack_connect [ -s | --server servername ] [-h | --help ] port1 port2` (The exit status is zero if successful, 1 otherwise)
- Disconnect ports: `jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2`

### Set Pure Data systemd service

```bash
cat <<- "EOF" | sudo tee /lib/systemd/system/puredata.service
[Unit]
Description=Pure Data
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/pd -nogui -noprefs -rt -jack -inchannels 8 -outchannels 8 ~/Documents/default.pd

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload
```

- To enable PD to start at boot: `sudo systemctl enable puredata.service`

### Set SuperCollider systemd service

```bash
cat <<- "EOF" | sudo tee /lib/systemd/system/supercollider.service
[Unit]
Description=SuperCollider
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/sclang -D ~/Documents/default.scd

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload
```

- To enable SC to start at boot: `sudo systemctl enable supercollider.service`

### Set up i3wm

- Copy i3_config to `~/.config/i3` and rename to `config`:

```bash
mkdir ~/.config/i3
cp ~/sources/mpu/i3_config ~/.config/i3/config
```

### Finish and rebooting

```bash
echo "Build done!"
echo
echo "rebooting..."
echo
sudo reboot
```
