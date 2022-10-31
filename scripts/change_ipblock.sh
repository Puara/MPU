#!/bin/bash


# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

echo
echo "┌──────────────────────┐"
echo "│ MPU IP block Script  |"
echo "│ Edu Meneses - 2022   |"
echo "│ Metalab - SAT        |"
echo "│ IDMIL - CIRMMT       |"
echo "└──────────────────────┘"
echo
echo "Don't forget to provide the new IP block (e.g., 192.168.5)"
echo "as an argument for this script"
echo

if [ -z "$1" ]
then
    echo "No argument was provided."
    echo "The script will be generate using 192.168.5 as"
    echo "the MPU's IP block."
    echo
    MPUsubnet="192.168.5"
else
    MPUsubnet=$1
    echo "MPU new IP block: ${MPUsubnet}"
    echo
fi

read -r -s -p $'Press enter to continue...\n\n'

sudo sed -i -e "s;static ip_address=.*;static ip_address=${MPUsubnet}.1/24;" /etc/dhcpcd.conf

sudo sed -i -e "s/dhcp-range=.*/dhcp-range=${MPUsubnet}.2,${MPUsubnet}.20,255.255.255.0,24h/" /etc/dnsmasq.conf

sudo sed -i -e "s;ExecStart=~/sources/jacktrip/builddir/jacktrip -c.*;ExecStart=~/sources/jacktrip/builddir/jacktrip -c ${MPUsubnet}.1 --clientname jacktrip_client;" /lib/systemd/system/jacktrip_client.service

echo "Done changing this MPU's IP block."
echo
echo "Please reboot the system for all changes to take effect."

trap - EXIT
