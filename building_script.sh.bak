#!/bin/bash

echo
echo "┌──────────────────────┐"
echo "│ MPU Script Generator |"
echo "│ Edu Meneses - 2022   |"
echo "│ Metalab - SAT        |"
echo "│ IDMIL - CIRMMT       |"
echo "└──────────────────────┘"
echo
echo "Don't forget to provide the MPU's ID"
echo "as an argument for this script"
echo

if [ -z "$1" ]
then
    echo "No argument was provided."
    echo "The script will be generate using MPUXXX as"
    echo "the MPU's name."
    MPUid=XXX
else
    MPUid=$1
    echo "MPU name: MPU${MPUid}"
    echo
fi

cp building_instructions_os.md building_script.tmp

sed -i                              \
    -e '1i #!/bin/bash\n\necho "\n' \
    -e '1,/## MPU Script/d'         \
    -e 's/```bash/"/'               \
    -e 's/```/\necho "/'            \
    -e "s/mpuXXX/mpu${MPUid}/"      \
    -e "s/MPUXXX/MPU${MPUid}/"      \
    -e 's/`/\\`/g'                  \
    -e '$a "'                       \
    building_script.tmp

mv building_script.tmp run_script.sh
sudo chmod +x run_script.sh

echo "Done building the script."
echo "Copy the script to the Rpi and execute it after the"
echo "'Prepare SD card' and 'First configuration' instructions at" 
echo "https://github.com/Puara/MPU/blob/main/building_instructions_os.md"
echo