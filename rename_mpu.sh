#!/bin/bash


# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

echo
echo "┌────────────────────┐"
echo "│ MPU Rename Script  |"
echo "│ Edu Meneses - 2022 |"
echo "│ Metalab - SAT      |"
echo "│ IDMIL - CIRMMT     |"
echo "└────────────────────┘"
echo
echo "Don't forget to provide the MPU's ID"
echo "as an argument for this script"
echo

if [ -z "$1" ]
then
    echo "No argument was provided."
    echo "The script will be generate using MPUXXX as"
    echo "the MPU's name."
    echo
    MPUid=XXX
else
    MPUid=$1
    echo "MPU name: MPU${MPUid}"
    echo
fi

read -r -s -p $'Press enter to continue...\n\n'

sudo raspi-config nonint do_hostname MPU$MPUid

sudo sed -i -e "s/MPU.\{3\}/MPU${MPUid}/" /etc/hostapd/hostapd.conf

sudo sed -i -e "s/mpu.\{3\}/mpu${MPUid}/" /etc/dhcpcd.conf

sudo sed -i -e "s/MPU.\{3\}/MPU${MPUid}/" /etc/i3status.conf

sudo sed -i -e "s/MPU.\{3\}/MPU${MPUid}/" /etc/samba/smb.conf

sudo sed -i -e "s/MPU.\{3\}/MPU${MPUid}/" ~/sources/MPU/python/lcd.py

echo "Done renaming the MPU."
echo

trap - EXIT
