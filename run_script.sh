#!/bin/bash

echo "


### Set RealVNC security scheme

"
echo -e "nmappings\nmappings" | sudo vncpasswd -service
sudo sed -i '$a Authentication=VncAuth' /root/.vnc/config.d/vncserver-x11

echo "

- The password set by default is \`mappings\`

### Update OS, install basic apps, and install i3wm as an alternative window manager

"
sudo apt update -y && sudo apt upgrade -y &&\
sudo apt install -y i3 i3blocks htop vim feh tmux

echo "

- Update desktop alternatives and select i3 as the default window manager:

"
sudo update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/bin/i3 60
echo "2" | sudo update-alternatives --config x-session-manager

echo "

### Disable the built-in and HDMI audio

"
sudo sed -i -e 's/Enable audio (loads snd_bcm2835)/Disable audio (snd_bcm2835)/ ; s/dtparam=audio=on/dtparam=audio=off/ ; s/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/' /boot/config.txt

echo "

### Add Metalab's MPA

"
sudo apt install -y coreutils wget && \
wget -qO - https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/sat-metalab-mpa-keyring.gpg \
    | gpg --dearmor \
    | sudo dd of=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg && \
echo 'deb [ arch=arm64, signed-by=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg ] https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/debs/ sat-metalab main' \
    | sudo tee /etc/apt/sources.list.d/sat-metalab-mpa.list && \
sudo apt update &&\
sudo apt upgrade -y

echo "

### Install basic software

- Installing SuperCollider, SC3-Plugins, jackd2 (if needed):

"
sudo apt install -y supercollider sc3-plugins libmapper python3-netifaces webmapper jackd2 puredata

echo "

- Installing SATIE:

"
echo "Quarks.install(\"SC-HOA\");Quarks.install(\"~/sources/satie\")" | sclang

echo "

### Configure AP

- Install dependencies:

"
sudo apt install -y dnsmasq hostapd

echo "

- Create the hostapd config file:

"
cat <<- "EOF" | sudo tee /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=MPU001
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

echo "

- Configure a static IP for the wlan0 interface:

"
sudo sed -i -e 's/hostname/mpu001/' -e '$a\\ninterface wlan0\n    static ip_address=192.168.4.1/24\n    nohook wpa_supplicant\n    #denyinterfaces eth0\n    #denyinterfaces wlan0\n' /etc/dhcpcd.conf

echo "

- Set hostapd to read the config file:

"
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd

echo "

- Start the hostapd service:

"
sudo systemctl unmask hostapd &&
sudo systemctl enable hostapd &&
sudo systemctl start hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

echo "

- Start configuring the dnsmasq service

"
sudo unlink /etc/resolv.conf &&
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf &&
cat <<- "EOF" | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

echo "

- Modify \`/lib/systemd/system/dnsmasq.service\` to launch after network get ready:

"
sed -i '0,/^\s*$/'\
's//After=network-online.target\nWants=network-online.target\n/' \
/lib/systemd/system/dnsmasq.service

echo "

- To prevent a long waiting time during boot, edit \`/lib/systemd/system/systemd-networkd-wait-online.service\`:

"
sed -i '\,ExecStart=/lib/systemd/systemd-networkd-wait-online, s,$, --any,' /lib/systemd/system/systemd-networkd-wait-online.service

echo "

- Then:

"
sudo systemctl daemon-reload

echo "

### Set Jack to start at boot

- Add a dbus security policy:

"
cat <<- "EOF" | sudo tee /etc/dbus-1/system.conf
<policy user="micah">
     <allow own="org.freedesktop.ReserveDevice1.Audio0"/>
     <allow own="org.freedesktop.ReserveDevice1.Audio1"/>
</policy>
EOF

echo "

- Add path to environment:

"
cat <<- "EOF" | sudo tee /etc/environment
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
EOF

echo "

- Create the systemd service file:

"
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

echo "

"
sudo systemctl daemon-reload &&\
sudo systemctl enable jackaudio.service &&\
sudo systemctl start jackaudio.service

echo "

- Some commands:

- List information and connections on ports: \`jack_lsp -c\`
- Connect ports: \`jack_connect [ -s | --server servername ] [-h | --help ] port1 port2\` (The exit status is zero if successful, 1 otherwise)
- Disconnect ports: \`jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2\`

### Set Pure Data systemd service

"
cat <<- "EOF" | sudo tee /lib/systemd/system/puredata.service
[Unit]
Description=Pure Data
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/pd -nogui -noprefs -rt -jack -inchannels 8 -outchannels 8 ~/Documents/default.pd

[Install]
WantedBy=multi-user.target
EOF

echo "

"
sudo systemctl daemon-reload

echo "

- To enable PD to start at boot: \`sudo systemctl enable puredata.service\`

### Set SuperCollider systemd service

"
cat <<- "EOF" | sudo tee /lib/systemd/system/supercollider.service
[Unit]
Description=SuperCollider
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/sclang -D ~/Documents/default.scd

[Install]
WantedBy=multi-user.target
EOF

echo "

"
sudo systemctl daemon-reload

echo "

- To enable SC to start at boot: \`sudo systemctl enable supercollider.service\`

### Set up i3wm

- Copy i3_config to \`~/.config/i3\` and rename to \`config\`:

"
mkdir ~/.config/i3
cp ~/sources/mpu/i3_config ~/.config/i3/config

echo "

### Finish and rebooting

"
echo "Build done!"
echo
echo "rebooting..."
echo
sudo reboot

echo "
"
