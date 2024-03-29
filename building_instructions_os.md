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
    - [Configure AP](#configure-ap)
    - [install Apache Guacamole](#install-apache-guacamole)
    - [Install basic software](#install-basic-software)
    - [Set Jack to start at boot](#set-jack-to-start-at-boot)
    - [Set Pure Data systemd service](#set-pure-data-systemd-service)
    - [Set SuperCollider systemd service](#set-supercollider-systemd-service)
    - [Set up i3wm](#set-up-i3wm)
    - [Adding a service to start JackTrip server](#adding-a-service-to-start-jacktrip-server)
    - [Adding a service to start JackTrip client](#adding-a-service-to-start-jacktrip-client)
    - [Make a systemd service for aj-snapshot](#make-a-systemd-service-for-aj-snapshot)
    - [Install Samba server](#install-samba-server)
    - [Make all systemd services available](#make-all-systemd-services-available)
    - [Optimize boot time](#optimize-boot-time)
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
- Flash the Raspberry Pi OS 64 bits into the microSD card. Use the configuration tool to set:
  - Enable ssh
  - set hostname: mpuXXX (replace XXX with the MPU's ID)
  - set user and password (mpu/mappings)
  - insert WiFi credential if needed
- OPTIONAL: if you plan to access your Rpi headlessly, you also need to ensure ssh is enabled on first boot by navigating to the `boot` partition on the microSD card and creating an empty file called **ssh** (e.g., use `touch ssh` in the command line)
- Insert the microSD card in the Rpi and turn it on

## First configuration

- First configuration for the Raspberry Pi. Information on available ***raspi-config no interactive*** commands can be found at https://github.com/raspberrypi-ui/rc_gui/blob/master/src/rc_gui.c

- Ssh (with the X11-Forwarding flag) to the Rpi: `ssh -X mpu@<ip_address>` or `ssh -X mpu@mpuXXX.local`. The Rpi might take a longer time to be available to ssh during the first boot as it is expanding the filesystem. Obs: it is important to enable X11 forwarding as the installed SuperCollider version needs it to run sclang and install SATIE. 
- Copy and paste the code block below to automatically run the [MPU Script](#mpu-script) routine:

```bash
sudo apt install -y tmux git liblo-tools
mkdir ~/sources && cd ~/sources &&\
git clone https://github.com/Puara/MPU.git &&\
cd ~/sources/MPU/scripts &&\
sudo chmod +x building_script.sh rename_mpu.sh change_ipblock.sh &&\
./building_script.sh &&\
./run_script.sh
```

- You will be asked to choose an MPU ID before the script starts preparing the OS.

- The next section describes all steps automatically executed by the commands presented above. If you copied and pasted the commands above, you don't need to follow the following instructions and your MPU will be automatically set.
 
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
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y i3 i3blocks htop vim feh x11-utils git-lfs fonts-font-awesome jacktrip
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
sudo sed -i -e 's/hostname/mpuXXX/' -e '$a\\ninterface wlan0\n    static ip_address=192.168.5.1/24\n    nohook wpa_supplicant\n    #denyinterfaces eth0\n    #denyinterfaces wlan0\n' /etc/dhcpcd.conf
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
dhcp-range=192.168.5.2,192.168.5.20,255.255.255.0,24h
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
sudo systemctl daemon-reload
```

### install Apache Guacamole

- More info at https://guacamole.apache.org
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
        <connection name="MPU">
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

- Set guacd to start at boot

```bash
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
```

### Install basic software

- Installing SuperCollider, SC3-Plugins, jackd2 (if needed):

```bash
sudo apt install -y supercollider sc3-plugins libmapper python3-netifaces webmapper jackd2 qjackctl puredata aj-snapshot
```

- Installing SATIE:

```bash
cd ~/sources
git clone https://gitlab.com/sat-mtl/tools/satie/satie.git
echo "Quarks.install(\"SC-HOA\");Quarks.install(\"~/sources/satie\")" | sclang
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
LimitRTPRIO=infinity
LimitMEMLOCK=infinity
User=mpu
Environment="JACK_NO_AUDIO_RESERVATION=1"
ExecStart=/usr/bin/jackd -R -P95 -t2000 -dalsa -dhw:1 -p256 -n2 -r48000 -s &

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable jackaudio.service
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
ConditionPathExists=/home/mpu/Documents/default.pd

[Service]
LimitRTPRIO=infinity
LimitMEMLOCK=infinity
User=mpu
ExecStart=pd -nogui -noprefs -rt -jack -inchannels 2 -outchannels 2 ~/Documents/default.pd

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable puredata.service
sudo systemctl start puredata.service
```

### Set SuperCollider systemd service

- OBS: starting as a user service to allow required access

```bash
mkdir -p ~/.config/systemd/user
cat <<- "EOF" | tee ~/.config/systemd/user/supercollider.service
[Unit]
Description=SuperCollider
After=multi-user.target
ConditionPathExists=/home/mpu/Documents/default.scd

[Service]
Type=idle
Restart=always
ExecStart=sclang -D /home/mpu/Documents/default.scd

[Install]
WantedBy=default.target
EOF
sudo chmod 644 ~/.config/systemd/user/supercollider.service
systemctl --user daemon-reload
systemctl --user enable --now supercollider.service
```

### Set up i3wm

- Copy i3_config to `~/.config/i3` and rename to `config`:
- Copy i3status.conf to `/etc`:

```bash
mkdir ~/.config/i3
cp ~/sources/MPU/i3_config ~/.config/i3/config
sudo cp ~/sources/MPU/i3status.conf /etc/i3status.conf
cp ~/sources/MPU/wallpaper.png ~/Pictures/wallpaper.png
sudo sed -i -e "s/MPU/MPUXXX/" /etc/i3status.conf
```

- OBS: for checking Font Awesome: https://fontawesome.com/v5/cheatsheet

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
ExecStart=~/sources/jacktrip/builddir/jacktrip -s --clientname jacktrip_client

[Install]
WantedBy=default.target
EOF
```

- To enable the service at boot: `sudo systemctl enable jacktrip_server.service`

### Adding a service to start JackTrip client

- Replace the IP address for the server IP.

```bash
cat <<- "EOF" | sudo tee /lib/systemd/system/jacktrip_client.service
[Unit]
Description=Run JackTrip client
After=multi-user.target

[Service]
Type=idle
Restart=always
ExecStart=~/sources/jacktrip/builddir/jacktrip -c 192.168.5.1 --clientname jacktrip_client

[Install]
WantedBy=default.target
EOF
```

- If you want to enable the client, disable the service and run `sudo systemctl enable jacktrip_client.service`
- To manually use as a client with IP address: `./jacktrip -c [xxx.xx.xxx.xxx]`, or with name: `./jacktrip -c mpuXXX.local`

### Make a systemd service for aj-snapshot

- More info at [http://aj-snapshot.sourceforge.net/](http://aj-snapshot.sourceforge.net/)

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
ConditionPathExists=/home/mpu/Documents/default.connections

[Service]
Type=idle
Restart=always
User=mpu
ExecStart=/usr/local/bin/aj-snapshot -d ~/Documents/default.connections

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ajsnapshot.service
sudo systemctl start ajsnapshot.service
```

- If you want to save a ajsnapshot file run: `aj-snapshot -f ~/Documents/default.connections`

### Install Samba server

- OBS: Choose *No* if asked **Modify smb.conf to use WINS settings from DHCP?**

```bash
sudo apt install -y samba
sudo systemctl stop smbd.service
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
```

- Create Samba configuration file and set the user:

```bash
cat <<- "EOF" | sudo tee /etc/samba/smb.conf
[global]
        server string = MPUXXX
        server role = standalone server
        interfaces = lo eth0 wlan0
        bind interfaces only = no
        smb ports = 445
        log file = /var/log/samba/smb.log
        max log size = 10000
        map to guest = bad user

[Documents]
        path = "/home/mpu/Documents"
        read only = no
        browsable = yes
        valid users = mpu
        vfs objects = recycle
        recycle:repository = .recycle
        recycle:touch = Yes
        recycle:keeptree = Yes
        recycle:versions = Yes
        recycle:noversions = *.tmp,*.temp,*.o,*.obj,*.TMP,*.TEMP
        recycle:exclude = *.tmp,*.temp,*.o,*.obj,*.TMP,*.TEMP
        recycle:excludedir = /.recycle,/tmp,/temp,/TMP,/TEMP

EOF
(echo mappings; echo mappings) | sudo smbpasswd -a mpu
sudo smbpasswd -e mpu
sudo systemctl start smbd.service
sudo systemctl enable smbd.service
```

### Make all systemd services available

```bash
sudo systemctl daemon-reload
```

### Optimize boot time

- Disable bluetooth and hciuart:

```bash
sudo sed  -i -e '$a\\n# Disable bluetooth (fast boot time)\ndtoverlay=disable-bt' /boot/config.txt
sudo systemctl disable hciuart.service
```

- Disable Modem Manager service. If using radio communication (2g, 3g, 4g) or USB devices that use radio, re-enabling it might be needed

```bash
sudo systemctl disable ModemManager.service
```

- Disable Samba NetBIOS name server daemon. If NETBIOS is needed, re-enable it

```bash
sudo systemctl disable nmbd.service
```

### Mapping using jack in CLI

- Check available devices: `cat /proc/asound/cards`. If you have multiple devices available, can call them by name
- Lists jack available ports: `jack_lsp`
- List information and connections on ports: `jack_lsp -c` or `jack_lsp -A`
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
