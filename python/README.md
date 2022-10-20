# MPU LCD + buttons setup (GuitarAMI version)

![MPUs](../docs/images_mpu/spus.jpg "MPUs")

Instruction on how to build the GuitarAMI MPU can be found in the [Media](./building_instructions_hardware.md) Processing Unit (MPU) - hardware](./building_instructions_hardware.md) guide.

## Set LCD

```bash
mkdir ~/sources/lcd
sudo apt install python3-rpi.gpio
sudo pip3 install osc4py3
cat <<- "EOF" | sudo tee /lib/systemd/system/lcd.service

[Unit]
 Description=OSC to LCD
 After=multi-user.target

 [Service]
 Type=idle
 ExecStart=/usr/bin/python3 ~/sources/MPU/python/lcd.py

 [Install]
 WantedBy=multi-user.target
EOF
sudo chmod 644 /lib/systemd/system/lcd.service
sudo systemctl daemon-reload
sudo systemctl enable lcd.service
```

- To send messages to the LCD use `/lcd message 0 0`, sent to port 20000. The first number represents the line and the second the column. Example using oscsend: `oscsend 127.0.0.1 20000 /lcd sii test_message 2 1`
- Sending `/lcd clear 0 0` will clean the LCD

## Set buttons to work

[https://raspberrypihq.com/use-a-push-button-with-raspberry-pi-gpio/](https://raspberrypihq.com/use-a-push-button-with-raspberry-pi-gpio/)

```bash
sudo apt install python3-rpi.gpio python3-gpiozero
sudo pip3 install osc4py3
cat <<- "EOF" | sudo tee /lib/systemd/system/buttonOSC.service
[Unit]
Description=Button to OSC Python3 code
After=multi-user.target

[Service]
WorkingDirectory= ~/sources/MPU/python/
User=pi
Type=idle
ExecStart=/usr/bin/python3 ~/sources/MPU/python/buttonOSC.py

[Install]
WantedBy=multi-user.target
EOF
sudo chmod 644 /lib/systemd/system/buttonOSC.service
sudo systemctl daemon-reload
sudo systemctl enable buttonOSC.service
```

## Set status bar

```bash
sudo apt install python3-rpi.gpio python3-gpiozero
sudo pip3 install osc4py3
cat <<- "EOF" | sudo tee /lib/systemd/system/status.service
[Unit]
Description=Status bar OSC Python3 code
After=multi-user.target

[Service]
WorkingDirectory= ~/sources/MPU/python/
User=pi
Type=idle
ExecStart=/usr/bin/python3 ~/sources/MPU/python/status.py

[Install]
WantedBy=multi-user.target
EOF
sudo chmod 644 /lib/systemd/system/status.service
sudo systemctl daemon-reload
sudo systemctl enable status.service
```
