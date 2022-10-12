#!/bin/bash

echo
echo "┌───────────────────────────┐"
echo "│ MPU Image Generator Script|"
echo "│ Edu Meneses - 2022        |"
echo "│ Metalab - SAT             |"
echo "│ IDMIL - CIRMMT            |"
echo "└───────────────────────────┘"
echo

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# Setting the OS

sudo raspi-config nonint do_vnc 0
sudo raspi-config nonint do_vnc_resolution 1920x1080
sudo raspi-config nonint do_memory_split 256
sudo raspi-config nonint do_wifi_country CA
sudo raspi-config --expand-rootfs

# Set RealVNC security scheme

echo -e "mappings\nmappings" | sudo vncpasswd -service
sudo sed -i '$a Authentication=VncAuth' /root/.vnc/config.d/vncserver-x11

echo "The password set by default is \`mappings\`"

# Update OS, install basic apps, and install i3wm as an alternative window manager

sudo apt update -y && sudo apt upgrade -y &&\
sudo apt install -y i3 i3blocks htop vim feh x11-utils

echo "Update desktop alternatives and select i3 as the default window manager:"

sudo update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/bin/i3 60
echo "2" | sudo update-alternatives --config x-session-manager

# Disable the built-in and HDMI audio

sudo sed -i -e 's/Enable audio (loads snd_bcm2835)/Disable audio (snd_bcm2835)/ ; s/dtparam=audio=on/dtparam=audio=off/ ; s/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/' /boot/config.txt

# Add Metalab's MPA

sudo apt install -y coreutils wget && \
wget -qO - https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/sat-metalab-mpa-keyring.gpg \
    | gpg --dearmor \
    | sudo dd of=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg && \
echo 'deb [ arch=arm64, signed-by=/usr/share/keyrings/sat-metalab-mpa-keyring.gpg ] https://sat-mtl.gitlab.io/distribution/mpa-bullseye-arm64-rpi/debs/ sat-metalab main' \
    | sudo tee /etc/apt/sources.list.d/sat-metalab-mpa.list && \
sudo apt update &&\
sudo apt upgrade -y

# Install basic software

echo "Installing SuperCollider, SC3-Plugins, jackd2 (if needed):"

sudo apt install -y supercollider sc3-plugins libmapper python3-netifaces webmapper jackd2 puredata

echo "Installing SATIE:"

cd ~/sources
git clone https://gitlab.com/sat-mtl/tools/satie/satie.git
echo "Quarks.install(\"SC-HOA\");Quarks.install(\"~/sources/satie\")" | sclang

## Install KXStudio software

echo "Install Cadence:"

sudo apt -y install pyqt5-dev-tools libqt5webkit5-dev python3-pyqt5.qtsvg python3-pyqt5.qtwebkit python3-dbus.mainloop.pyqt5 python3-rdflib libmagic-dev liblo-dev
cd ~/sources
git clone https://github.com/falkTX/Cadence.git
cd Cadence

echo "Modify the compilation flags in \`Makefile.mk\`:"

sudo sed -i 's/'\
'BASE_FLAGS  = -O3 -ffast-math -mtune=generic -msse -mfpmath=sse -Wall -Wextra/'\
'# BASE_FLAGS  = -O3 -ffast-math -mtune=generic -msse -mfpmath=sse -Wall -Wextra\n'\
'BASE_FLAGS  = -O3 -ffast-math -mtune=native -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations -Wall -Wextra'\
'/' c++/Makefile.mk

make
sudo make install

echo "Install Carla:"

sudo apt install -y liblo-dev ffmpeg libmagic-dev pyqt5-dev pyqt5-dev-tools
cd ~/sources
git clone https://github.com/falkTX/Carla
cd Carla

echo "Modify the compilation flags in \`Makefile.mk\`:"

sudo sed -i 's/'\
'BASE_OPTS  = -O3 -ffast-math -mtune=generic -msse -msse2 -mfpmath=sse -fdata-sections -ffunction-sections/'\
'# BASE_OPTS  = -O3 -ffast-math -mtune=generic -msse -msse2 -mfpmath=sse -fdata-sections -ffunction-sections\n'\
'BASE_OPTS  = -O3 -ffast-math -mtune=native -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations -fdata-sections -ffunction-sections'\
'/' source/Makefile.mk

make
sudo make install

# Configure AP

echo "Install dependencies:"

sudo apt install -y dnsmasq hostapd

echo "Create the hostapd config file:"

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

echo "Configure a static IP for the wlan0 interface:"

sudo sed -i -e 's/hostname/mpu001/' -e '$a\\ninterface wlan0\n    static ip_address=192.168.4.1/24\n    nohook wpa_supplicant\n    #denyinterfaces eth0\n    #denyinterfaces wlan0\n' /etc/dhcpcd.conf

echo "Set hostapd to read the config file:"

sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd

echo "Start the hostapd service:"

sudo systemctl unmask hostapd &&
sudo systemctl enable hostapd &&
sudo systemctl start hostapd
sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

echo "Start configuring the dnsmasq service"

sudo unlink /etc/resolv.conf &&
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf &&
cat <<- "EOF" | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

echo "Modify \`/lib/systemd/system/dnsmasq.service\` to launch after network get ready:"

sudo sed -i '0,/^\s*$/'\
's//After=network-online.target\nWants=network-online.target\n/' \
/lib/systemd/system/dnsmasq.service

echo "To prevent a long waiting time during boot, edit \`/lib/systemd/system/systemd-networkd-wait-online.service\`:"

sudo sed -i '\,ExecStart=/lib/systemd/systemd-networkd-wait-online, s,$, --any,' /lib/systemd/system/systemd-networkd-wait-online.service
sudo systemctl daemon-reload

echo "Enable Routing and IP Masquerading"

cat <<- "EOF" | sudo tee /etc/sysctl.d/routed-ap.conf
# Enable IPv4 routing
net.ipv4.ip_forward=1
EOF
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save

# install Apache Guacamole

echo "Reference: [Guacamole manual](https://guacamole.apache.org/doc/gug/)"

echo "Install dependencies:"

sudo apt install -y libcairo2-dev libpng-dev libjpeg62-turbo-dev libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev jetty9

echo "Clone git and install (set for version 1.4.0):"

cd ~/sources
wget -O guacamole-server-1.4.0.tar.gz "https://apache.org/dyn/closer.lua/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz?action=download"
tar -xzf guacamole-server-1.4.0.tar.gz
cd guacamole-server-1.4.0
autoreconf -fi
./configure
make
sudo make install
sudo ldconfig
cd ~/sources
wget -O guacamole.war "https://apache.org/dyn/closer.lua/guacamole/1.4.0/binary/guacamole-1.4.0.war?action=download"
sudo cp ~/sources/guacamole.war /var/lib/jetty9/webapps/guacamole.war

echo "Create the Guacamole home:"

sudo mkdir /etc/guacamole

echo "Create \`user-mapping.xml\`"

cat <<- "EOF" | sudo tee /etc/guacamole/user-mapping.xml
<user-mapping>
    <authorize
    username="mpu"
    password="mappings">
        <connection name="localhost">
        <protocol>vnc</protocol>
        <param name="hostname">localhost</param>
        <param name="port">5900</param>
        <param name="password">mappings</param>
        </connection>
    </authorize>
</user-mapping>
EOF

sudo mv /var/lib/jetty9/webapps/root /var/lib/jetty9/webapps/root-OLD
sudo mv /var/lib/jetty9/webapps/guacamole.war /var/lib/jetty9/webapps/root.war

echo "Change Guacamole login screen:"

sudo mkdir /etc/guacamole/extensions
sudo cp ~/sources/MPU/mpu.jar /etc/guacamole/extensions/mpu.jar

echo "Configure addresses"

sudo apt install apache2 -y
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_byrequests
sudo a2enmod rewrite
sudo mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak

cat <<- "EOF" | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>

    RewriteEngine on
    RewriteRule ^/webmapper$ /webmapper/ [R]

    ProxyRequests Off
    ProxyPreserveHost On

    ProxyPass /webmapper http://127.0.0.1:50000
    ProxyPassReverse /webmapper http://127.0.0.1:50000
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

</VirtualHost>
EOF

sudo systemctl restart apache2

echo "Set guacd to start at boot"

cat <<- "EOF" | sudo tee /lib/systemd/system/guacd.service
[Unit]
Description=Run Guacamole server
After=multi-user.target

[Service]
Type=idle
Restart=always
User=mpu
ExecStart=/usr/local/sbin/guacd -b 127.0.0.1 -f

[Install]
WantedBy=default.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable guacd
sudo systemctl start guacd

# Set Jack to start at boot

echo "Add a dbus security policy:"

cat <<- "EOF" | sudo tee /etc/dbus-1/system.conf
<policy user="micah">
     <allow own="org.freedesktop.ReserveDevice1.Audio0"/>
     <allow own="org.freedesktop.ReserveDevice1.Audio1"/>
</policy>
EOF

echo "Add path to environment:"

cat <<- "EOF" | sudo tee /etc/environment
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
EOF

echo "Create the systemd service file:"

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

echo "Some commands:"

echo "List information and connections on ports: \`jack_lsp -c\`"
echo "Connect ports: \`jack_connect [ -s | --server servername ] [-h | --help ] port1 port2\` (The exit status is zero if successful, 1 otherwise)"
echo "Disconnect ports: \`jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2\`"

# Set Pure Data systemd service

cat <<- "EOF" | sudo tee /lib/systemd/system/puredata.service
[Unit]
Description=Pure Data
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/pd -nogui -noprefs -rt -jack -inchannels 8 -outchannels 8 ~/Documents/default.pd

[Install]
WantedBy=multi-user.target
EOF

echo "To enable PD to start at boot: \`sudo systemctl enable puredata.service\`"

# Set SuperCollider systemd service

cat <<- "EOF" | sudo tee /lib/systemd/system/supercollider.service
[Unit]
Description=SuperCollider
After=sound.target jackaudio.service

[Service]
ExecStart=/usr/local/bin/sclang -D ~/Documents/default.scd

[Install]
WantedBy=multi-user.target
EOF

echo "To enable SC to start at boot: \`sudo systemctl enable supercollider.service\`"

# Set up i3wm

echo "Copy i3_config to \`~/.config/i3\` and rename to \`config\`:"
echo "Copy i3status.conf to \`/etc\`:"

mkdir ~/.config/i3
cp ~/sources/MPU/i3_config ~/.config/i3/config
sudo cp ~/sources/MPU/i3status.conf /etc/i3status.conf
cp ~/sources/MPU/wallpaper.png ~/Pictures/wallpaper.png
sudo sed -i -e "s/MPU/MPU001/" /etc/i3status.conf

# Compiling and running JackTrip on the MPU

echo "Dependencies: \`sudo apt install libjack-jackd2-dev librtaudio-dev\`"
echo "Extra package to test latency: \`sudo apt install -y jack-delay\`"

sudo apt install -y libjack-jackd2-dev librtaudio-dev jack-delay libqt5websockets5-dev libqt5svg5* libqt5networkauth5-dev
cd ~/sources
git clone https://github.com/jacktrip/jacktrip.git
cd ~/sources/jacktrip
./build
export JACK_NO_AUDIO_RESERVATION=1

echo "To manually use as a client with IP address: \`./jacktrip -c [xxx.xx.xxx.xxx]\`, or with name: \`./jacktrip -c mpu001.local\`"

# Adding a service to start JackTrip server

echo "OBS: client name is the name of the other machine"

cat <<- "EOF" | sudo tee /lib/systemd/system/jacktrip_server.service
[Unit]
Description=Run JackTrip server
After=multi-user.target

[Service]
Type=idle
Restart=always
ExecStart=/home/patch/sources/jacktrip/builddir/jacktrip -s --clientname jacktrip_client

[Install]
WantedBy=default.target
EOF

echo "To enable the service at boot: \`sudo systemctl enable jacktrip_server.service\`"

# Adding a service to start JackTrip client

echo "Replace the IP address for the server IP."

cat <<- "EOF" | sudo tee /lib/systemd/system/jacktrip_client.service
[Unit]
Description=Run JackTrip client
After=multi-user.target

[Service]
Type=idle
Restart=always
ExecStart=/home/patch/sources/jacktrip/builddir/jacktrip -c 192.168.4.1 --clientname jacktrip_client

[Install]
WantedBy=default.target
EOF

echo "If you want to enable the client, disable the service and run \`sudo systemctl enable jacktrip_client.service\`"

# Install aj-snapshot

echo "[http://aj-snapshot.sourceforge.net/](http://aj-snapshot.sourceforge.net/)"

echo "Check the last version on the website"

sudo apt install -y libmxml-dev
cd ~/sources
wget http://downloads.sourceforge.net/project/aj-snapshot/aj-snapshot-0.9.9.tar.bz2
tar -xvjf aj-snapshot-0.9.9.tar.bz2
cd aj-snapshot-0.9.9
./configure
make
sudo make install

echo "To create a snapshot: \`aj-snapshot -f ~/Documents/default.connections\`"
echo "To remove all Jack connections: \`aj-snapshot -xj\`"
echo "To save connections: \`sudo aj-snapshot -f ~/Documents/default.connections\`"
echo "To restore connections: \`sudo aj-snapshot -r ~/Documents/default.connections\`"

echo "Set custom Jack connections to load at boot:"

cat <<- "EOF" | sudo tee /lib/systemd/system/ajsnapshot.service
[Unit]
Description=AJ-Snapshot
After=sound.target jackaudio.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/aj-snapshot -r ~/Documents/default.connections

[Install]
WantedBy=multi-user.target
EOF

echo "If you want to enable the client ajsnapshot to run on boot: \`sudo systemctl enable ajsnapshot.service\`"

# Make all systemd services available

sudo systemctl daemon-reload

# Mapping using jack in CLI

echo "Check available devices: \`cat /proc/asound/cards\`. If you have multiple devices available, can call them by name"
echo "lists jack available ports: \`jack_lsp\`"
echo "List informtion and connections on ports: \`jack_lsp -c\` or \`jack_lsp -A\`"
echo "Connect ports: \`jack_connect [ -s | --server servername ] [-h | --help ] port1 port2\` (The exit status is zero if successful, 1 otherwise)"
echo "Disconnect ports: \`jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2\`"

# Latency tests

echo "Make sure JackTrip is running."

echo "Connect the necessary audio cable to create a loopback on the client's audio interface (audio OUT -> audio IN)"
echo "For the loopback (same interface test): \`jack_delay -I system:capture_2 -O system:playback_2\`"
echo "run the test: \`jack_delay -O jacktrip_client.local:send_2 -I jacktrip_client.local:receive_2\`"

# Jack available commands

echo "To get a list on the computer, type **jack** and hit *Tab*"

echo "|command          |command              |command                     |command              |command                 |"
echo "|-----------------|---------------------|----------------------------|---------------------|------------------------|"
echo "| jack_alias      | jack_bufsize        | jack_capture               | jack_capture_gui    | jack_connect           |"
echo "| jackdbus        | jack_disconnect     | jack-dl                    | jack-dssi-host      | jack_evmon             |"
echo "| jack_load       | jack_lsp            | jack_metro                 | jack_midi_dump      | jack_midi_latency_test |"
echo "| jack_net_master | jack_net_slave      | jack_netsource             | jack-osc            | jack-play              |"
echo "| jack_samplerate | jack-scope          | jack_server_control        | jack_session_notify | jack_showtime          |"
echo "| jack_thru       | jack_transport      | jack-transport             | jack-udp            | jack_unload            |"
echo "| jack_control    | jack_cpu            | jack_cpu_load              | jackd               | jack_wait              |"
echo "| jack_freewheel  | jack_iodelay        | jack-keyboard              | jack_latent_client  | jack_midiseq           |"
echo "| jack_midisine   | jack_monitor_client | jack_multiple_metro        | jack-plumbing       |"
echo "| jack-rack       | jack_rec            | jack-record                | jack_test           |"
echo "| jack_simdtests  | jack_simple_client  | jack_simple_session_client | jack_zombie         |"

echo "To check Jack logs: \`sudo journalctl -u jack.service\`"

# Finish and rebooting

echo "Build done!"
echo
echo "rebooting..."
echo
sudo reboot
