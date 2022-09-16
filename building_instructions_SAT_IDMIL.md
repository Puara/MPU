# Builing Instructions - GuitarAMI Media Processing Unit

- [Builing Instructions - GuitarAMI Media Processing Unit](#builing-instructions---guitarami-media-processing-unit)
  - [BOM](#bom)
  - [Prepare SD card](#prepare-sd-card)
  - [First configuration](#first-configuration)
  - [Configure AP](#configure-ap)
  - [Install Jack2](#install-jack2)
  - [Install Pure Data (0.49-0)](#install-pure-data-049-0)
  - [Compile and install SuperCollider](#compile-and-install-supercollider)
  - [Compile and install sc3-plugins](#compile-and-install-sc3-plugins)

## BOM

- hardware
  - [Raspberri Pi 4 model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
  - [Pisound](https://blokas.io/pisound/) (embedded)
  - external audio interface support
- softrware
  - [Custom PREEMPT-RT kernel](RT_kernel.md) (build on 5.10)
  - [Ubuntu Server for Rpi](https://ubuntu.com/download/raspberry-pi)

## Prepare SD card

- Download Ubuntu Server (link above)
- Flash the image using [ApplePiBaker](https://www.tweaking4all.com/hardware/raspberry-pi/applepi-baker-v2/), [balenaEtcher](https://www.balena.io/etcher/), or diskutil (dd)

## First configuration

- Ethernet connection recommended
- First boot requires a physical connection (keyboard and monitor) to configure user (ubuntu/ubuntu) and set a new password
- ssh to the MPU: `ssh pi@ip_address` or `ssh pi@ubuntu.local`

```bash
mkdir ~/sources &&
sudo apt update -y &&
sudo apt upgrade -y
sudo apt install tmux vim htop
```

## Configure AP

```bash
sudo apt install -y dnsmasq hostapd && 
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
EOF &&
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd
```

- Start the hostapd service:

  ```bash
  sudo systemctl unmask hostapd &&
  sudo systemctl enable hostapd &&
  sudo systemctl start hostapd &&
  sudo unlink /etc/resolv.conf &&
  echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf &&
  cat <<- "EOF" | sudo tee /etc/dnsmasq.conf
  interface=wlan0
  dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
  EOF
  ```

- Modify `/lib/systemd/system/dnsmasq.service` to launch after network get ready. Add the following:

  ```
  [Unit]
  ...
  After=network-online.target
  Wants=network-online.target
  ```

- To prevent a long waiting time during boot, edit `/lib/systemd/system/systemd-networkd-wait-online.service`: `ExecStart=/usr/lib/systemd/systemd-networkd-wait-online` -> `ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any`

- Then `sudo systemctl daemon-reload && sudo reboot`

## Install Jack2
(http://jackaudio.org/faq/build_info.html)

```bash
cd ~/sources &&\
sudo apt-get install -y git &&\
git clone https://github.com/jackaudio/jack2.git &&\
cd jack2 &&\
./waf configure &&\
./waf &&\
sudo ./waf install &&\
echo /usr/local/bin/jackd -P50 -dalsa -p128 -n2 -r48000 > ~/.jackdrc
```

Set Jack to start at boot:

```bash
cat <<- "EOF" | sudo tee /lib/systemd/system/jackaudio.service
[Unit]
Description=JACK Audio
After=sound.target

[Service]
ExecStart=/usr/bin/jackd -P50 -t2000 -dalsa -p128 -n2 -r48000 -s &

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload &&\
sudo systemctl enable jackaudio.service &&\
sudo systemctl start jackaudio.service
```

Some commands:

-  List informtion and connections on ports: `jack_lsp -c`
- Connect ports: `jack_connect [ -s | --server servername ] [-h | --help ] port1 port2` (The exit status is zero if successful, 1 otherwise)
- Disconnect ports: `jack_disconnect [ -s | --server servername ] [ -h | --help ] port1 port2`

## Install Pure Data (0.49-0)
(http://msp.ucsd.edu/Pd_documentation/x3.htm#s1.2)

```bash 
cd ~/sources &&\
wget http://msp.ucsd.edu/Software/pd-0.49-0.src.tar.gz &&\
tar -xvzf pd-0.49-0.src.tar.gz &&\
cd pd-0.49-0 &&\
sudo apt-get install autoconf libtool gettext libasound2-dev tcl tk libjack-jackd2-dev automake -y &&\
chmod +x ./autogen.sh &&\
sudo ./autogen.sh &&\
./configure --enable-jack --disable-oss --enable-fftw &&\
make &&\
sudo make install
sudo apt-get install pd-comport
```

Set PD to start at boot:

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

## Compile and install SuperCollider

[https://supercollider.github.io/development/building-raspberrypi](https://supercollider.github.io/development/building-raspberrypi)

SC:

```bash
cd ~/sources &&\
sudo apt-get install libsamplerate0-dev libsndfile1-dev libasound2-dev libavahi-client-dev libreadline-dev libfftw3-dev libudev-dev cmake git &&\
git clone --recursive git://github.com/supercollider/supercollider &&\
cd supercollider &&\
git checkout master &&\
git submodule init && git submodule update &&\
mkdir build && cd build &&\
cmake -L -DCMAKE_BUILD_TYPE="Release" -DBUILD_TESTING=OFF -DSUPERNOVA=ON -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=OFF -DSC_ED=OFF -DSC_EL=OFF -DSC_VIM=ON .. &&\
make -j 4 &&\
sudo make install &&\
sudo ldconfig
```

## Compile and install sc3-plugins

```bash
cd ~/sources &&\
git clone --recursive https://github.com/supercollider/sc3-plugins.git &&\
cd sc3-plugins &&\
mkdir build && cd build &&\
cmake -L -DCMAKE_BUILD_TYPE="Release" -DSUPERNOVA=ON -DNATIVE=ON -DSC_PATH=../../supercollider/ ..  &&\
make -j 4 &&\
sudo make install
```

Set SC to start at boot:

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
