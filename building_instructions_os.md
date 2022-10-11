# Building Instructions - Puara Media Processing Unit

- [Building Instructions - Puara Media Processing Unit](#building-instructions---puara-media-processing-unit)
  - [BOM](#bom)
  - [Prepare SD card](#prepare-sd-card)
  - [First configuration](#first-configuration)
  - [MPU Script](#mpu-script)
    - [Setting the OS](#setting-the-os)
    - [Set RealVNC security scheme](#set-realvnc-security-scheme)
    - [Update OS, install basic apps, and install i3wm as an alternative window manager](#update-os-install-basic-apps-and-install-i3wm-as-an-alternative-window-manager)
    - [Disable the built-in and HDMI audio](#disable-the-built-in-and-hdmi-audio)
    - [Add Metalab's MPA](#add-metalabs-mpa)
    - [Install basic software](#install-basic-software)
  - [Install KXStudio software](#install-kxstudio-software)
    - [Configure AP](#configure-ap)
    - [install Apache Guacamole](#install-apache-guacamole)
    - [Set Jack to start at boot](#set-jack-to-start-at-boot)
    - [Set Pure Data systemd service](#set-pure-data-systemd-service)
    - [Set SuperCollider systemd service](#set-supercollider-systemd-service)
    - [Set up i3wm](#set-up-i3wm)
    - [Compiling and running JackTrip on the MPU](#compiling-and-running-jacktrip-on-the-mpu)
    - [Adding a service to start JackTrip server](#adding-a-service-to-start-jacktrip-server)
    - [Adding a service to start JackTrip client](#adding-a-service-to-start-jacktrip-client)
    - [Install aj-snapshot](#install-aj-snapshot)
    - [Mapping using jack in CLI](#mapping-using-jack-in-cli)
    - [Latency tests](#latency-tests)
    - [Jack available commands](#jack-available-commands)
    - [Finish and rebooting](#finish-and-rebooting)

## BOM

- minimal hardware
  - [Raspberry Pi 4 model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
  - External audio interface. If using the PiSound refer to [https://blokas.io/pisound](https://blokas.io/pisound) for installation instructions
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
- insert the SD card in the Rpi and turn it on

## First configuration

- First configuration for the Raspberry Pi. Information on available ***raspi-config no interactive*** commands can be found at https://github.com/raspberrypi-ui/rc_gui/blob/master/src/rc_gui.c

- Ssh (with the X11-Forwarding flag) to the Rpi: `ssh -X mpu@<ip_address>` or `ssh -X mpu@mpuXXX.local`. The Rpi might take a longer time to be available to ssh during first boot as it is expanding the filesystem
- Clone this repository into the Rpi using `mkdir ~/sources && cd ~/sources && git clone https://github.com/Puara/MPU.git`
- Navigate to the MPU folder: `cd ~/sources/MPU`
- Update the `run_script.sh` by running `sudo chmod +x building_script.sh` and `./building_script.sh XXX`, where XXX must be replaced by the MPU's ID. You will be asked for the sudo password as the script tries to make run_script.sh executable
- Run it with `./run_script.sh`. All steps described in the section [MPU Script](#mpu-script) will be performed by the script

Alternatively, you can copy and paste the code block below:

```bash
sudo apt install -y tmux
mkdir ~/sources && cd ~/sources &&\
git clone https://github.com/Puara/MPU.git &&\
cd ~/sources/MPU &&\
sudo chmod +x building_script.sh &&\
./building_script.sh &&\
./run_script.sh
```

## MPU Script

### Setting the OS

```bash
sudo raspi-config nonint do_vnc 0
sudo raspi-config nonint do_vnc_resolution 1920x1080
sudo raspi-config nonint do_memory_split 256
sudo raspi-config nonint do_wifi_country CA
sudo raspi-config --expand-rootfs
```

### Set RealVNC security scheme

```bash
echo -e "mappings\nmappings" | sudo vncpasswd -service
sudo sed -i '$a Authentication=VncAuth' /root/.vnc/config.d/vncserver-x11
```

- The password set by default is `mappings`

### Update OS, install basic apps, and install i3wm as an alternative window manager

```bash
sudo apt update -y && sudo apt upgrade -y &&\
sudo apt install -y i3 i3blocks htop vim feh x11-utils
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
cd ~/sources
git clone https://gitlab.com/sat-mtl/tools/satie/satie.git
echo "Quarks.install(\"SC-HOA\");Quarks.install(\"~/sources/satie\")" | sclang
```

## Install KXStudio software

- Install Cadence:

```bash
sudo apt -y install pyqt5-dev-tools libqt5webkit5-dev python3-pyqt5.qtsvg python3-pyqt5.qtwebkit python3-dbus.mainloop.pyqt5 python3-rdflib libmagic-dev liblo-dev
cd ~/sources
git clone https://github.com/falkTX/Cadence.git
cd Cadence
```

- Modify the compilation flags in `Makefile.mk`:

```bash
sudo sed -i 's/'\
'BASE_FLAGS  = -O3 -ffast-math -mtune=generic -msse -mfpmath=sse -Wall -Wextra/'\
'# BASE_FLAGS  = -O3 -ffast-math -mtune=generic -msse -mfpmath=sse -Wall -Wextra\n'\
'BASE_FLAGS  = -O3 -ffast-math -mtune=native -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations -Wall -Wextra'\
'/' c++/Makefile.mk
```

```bash
make
sudo make install
```

- Install Carla:

```bash
sudo apt install -y liblo-dev ffmpeg libmagic-dev pyqt5-dev pyqt5-dev-tools
cd ~/sources
git clone https://github.com/falkTX/Carla
cd Carla
```

- Modify the compilation flags in `Makefile.mk`:

```bash
sudo sed -i 's/'\
'BASE_OPTS  = -O3 -ffast-math -mtune=generic -msse -msse2 -mfpmath=sse -fdata-sections -ffunction-sections/'\
'# BASE_OPTS  = -O3 -ffast-math -mtune=generic -msse -msse2 -mfpmath=sse -fdata-sections -ffunction-sections\n'\
'BASE_OPTS  = -O3 -ffast-math -mtune=native -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations -fdata-sections -ffunction-sections'\
'/' source/Makefile.mk
```

```bash
make
sudo make install
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
sudo sed -i '0,/^\s*$/'\
's//After=network-online.target\nWants=network-online.target\n/' \
/lib/systemd/system/dnsmasq.service
```

- To prevent a long waiting time during boot, edit `/lib/systemd/system/systemd-networkd-wait-online.service`:

```bash
sudo sed -i '\,ExecStart=/lib/systemd/systemd-networkd-wait-online, s,$, --any,' /lib/systemd/system/systemd-networkd-wait-online.service
```

- Then:

```bash
sudo systemctl daemon-reload
```

- Enable Routing and IP Masquerading

```bash
cat <<- "EOF" | sudo tee /etc/sysctl.d/routed-ap.conf
# Enable IPv4 routing
net.ipv4.ip_forward=1
EOF
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
```

### install Apache Guacamole

- Reference: [Guacamole manual](https://guacamole.apache.org/doc/gug/)

- Install dependencies:

```bash
sudo apt install -y libcairo2-dev libpng-dev libjpeg62-turbo-dev libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev jetty9
```

- Clone git and install (set for version 1.4.0):

```bash
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
```

- Create the Guacamole home:

```bash
sudo mkdir /etc/guacamole
```

- Create `user-mapping.xml`

```bash
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
```

```bash
sudo mv /var/lib/jetty9/webapps/root /var/lib/jetty9/webapps/root-OLD
sudo mv /var/lib/jetty9/webapps/guacamole.war /var/lib/jetty9/webapps/root.war
```

- Change Guacamole login screen:

```bash
sudo mkdir /etc/guacamole/extensions
sudo cp ~/sources/MPU/mpu.jar /etc/guacamole/extensions/mpu.jar
```

- Configure addresses

```bash
sudo apt install apache2 -y
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_byrequests
sudo a2enmod rewrite
sudo mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
```

```bash
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
```

```bash
sudo systemctl restart apache2
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
- Copy i3status.conf to `/etc`:

```bash
mkdir ~/.config/i3
cp ~/sources/MPU/i3_config ~/.config/i3/config
sudo cp ~/sources/MPU/i3status.conf /etc/i3status.conf
cp ~/sources/MPU/wallpaper.png ~/Pictures/wallpaper.png
```

### Compiling and running JackTrip on the MPU

- Dependencies: `sudo apt install libjack-jackd2-dev librtaudio-dev`
- Extra package to test latency: `sudo apt install -y jack-delay`

```bash
sudo apt install -y libjack-jackd2-dev librtaudio-dev jack-delay libqt5websockets5-dev libqt5svg5* libqt5networkauth5-dev
cd ~/sources
git clone https://github.com/jacktrip/jacktrip.git
cd ~/sources/jacktrip
./build
export JACK_NO_AUDIO_RESERVATION=1
```

- To manually use as a client with IP address: `./jacktrip -c [xxx.xx.xxx.xxx]`, or with name: `./jacktrip -c mpuXXX.local`

### Adding a service to start JackTrip server

- OBS: client name is the name of the other machine

```bash
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
```

```bash
systemctl --user daemon-reload
```

- To enable the service at boot: `sudo systemctl enable jacktrip_server.service`

### Adding a service to start JackTrip client

- Replace the IP address for the server IP.

```bash
cat <<- "EOF" | tee /lib/systemd/system/jacktrip_client.service
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
```

```bash
systemctl --user daemon-reload
```

- If you want to enable the client, disable the service and run `sudo systemctl enable jacktrip_client.service`

### Install aj-snapshot

- [http://aj-snapshot.sourceforge.net/](http://aj-snapshot.sourceforge.net/)

- Check the last version on the website

```bash
sudo apt install -y libmxml-dev
cd ~/sources
wget http://downloads.sourceforge.net/project/aj-snapshot/aj-snapshot-0.9.9.tar.bz2
tar -xvjf aj-snapshot-0.9.9.tar.bz2
cd aj-snapshot-0.9.9
./configure
make
sudo make install
```

- To create a snapshot: `aj-snapshot -f ~/Documents/default.connections`
- To remove all Jack connections: `aj-snapshot -xj`
- To save connections: `sudo aj-snapshot -f ~/Documents/default.connections`
- To restore connections: `sudo aj-snapshot -r ~/Documents/default.connections`

- Set custom Jack connections to load at boot:

```bash
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
```

```bash
sudo systemctl daemon-reload
```

- If you want to enable the client ajsnapshot to run on boot: `sudo systemctl enable ajsnapshot.service`

### Mapping using jack in CLI

- Check available devices: `cat /proc/asound/cards`. If you have multiple devices available, can call them by name
- lists jack available ports: `jack_lsp`
- List informtion and connections on ports: `jack_lsp -c` or `jack_lsp -A`
- Connect ports: `jack_connect [ -s | --server servername ] [-h | --help ] port1 port2` (The exit status is zero if successful, 1 otherwise)
- Disconnect ports: `jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2`

### Latency tests

- Make sure JackTrip is running.

- Connect the necessary audio cable to create a loopback on the client's audio interface (audio OUT -> audio IN)
- For the loopback (same interface test): `jack_delay -I system:capture_2 -O system:playback_2`
- run the test: `jack_delay -O jacktrip_client.local:send_2 -I jacktrip_client.local:receive_2`

### Jack available commands

- To get a list on the computer, type **jack** and hit *Tab*

|command          |command              |command                     |command              |command                 |
|-----------------|---------------------|----------------------------|---------------------|------------------------|
| jack_alias      | jack_bufsize        | jack_capture               | jack_capture_gui    | jack_connect           |
| jackdbus        | jack_disconnect     | jack-dl                    | jack-dssi-host      | jack_evmon             |
| jack_load       | jack_lsp            | jack_metro                 | jack_midi_dump      | jack_midi_latency_test |
| jack_net_master | jack_net_slave      | jack_netsource             | jack-osc            | jack-play              |
| jack_samplerate | jack-scope          | jack_server_control        | jack_session_notify | jack_showtime          |
| jack_thru       | jack_transport      | jack-transport             | jack-udp            | jack_unload            |
| jack_control    | jack_cpu            | jack_cpu_load              | jackd               | jack_wait              |
| jack_freewheel  | jack_iodelay        | jack-keyboard              | jack_latent_client  | jack_midiseq           |
| jack_midisine   | jack_monitor_client | jack_multiple_metro        | jack-plumbing       |
| jack-rack       | jack_rec            | jack-record                | jack_test           |
| jack_simdtests  | jack_simple_client  | jack_simple_session_client | jack_zombie         |

- To check Jack logs: `sudo journalctl -u jack.service`

### Finish and rebooting

```bash
echo "Build done!"
echo
echo "rebooting..."
echo
sudo reboot
```
