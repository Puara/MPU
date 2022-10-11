#!/bin/bash


# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

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

header='#!/bin/bash\
\
echo\
echo "┌───────────────────────────┐"\
echo "│ MPU Image Generator Script|"\
echo "│ Edu Meneses - 2022        |"\
echo "│ Metalab - SAT             |"\
echo "│ IDMIL - CIRMMT            |"\
echo "└───────────────────────────┘"\
echo\
\
# exit when any command fails\
set -e\
\
# keep track of the last executed command\
trap '"'"'last_command=$current_command; current_command=$BASH_COMMAND'"'"' DEBUG\
# echo an error message before exiting\
trap '"'"'echo "\\"${last_command}\\" command filed with exit code $?."'"'"' EXIT'

MPUid=$1

while [ -z "$MPUid" ]
do
    echo "Please enter the MPU ID:"
    echo
    read MPUid
done

echo
echo "MPU name: MPU${MPUid}"
echo

read -r -s -p $'Press enter to continue...\n\n'

cp building_instructions_os.md building_script.tmp

sed -i                                        \
    -e "1i ${header}"                         \
    -e '1,/## MPU Script/d'                   \
    -e '/```bash/d'                           \
    -e '/```/d'                               \
    -e 's/###/#/'                             \
    -e 's/^- .*/&"/'                          \
    -e 's/^- /echo "/'                        \
    -e 's/^|.*/&"/'                           \
    -e 's/^|/echo "|/'                        \
    -e "s/mpuXXX/mpu${MPUid}/"                \
    -e "s/MPUXXX/MPU${MPUid}/"                \
    -e 's/`/\\`/g'                            \
    building_script.tmp

mv building_script.tmp run_script.sh
sudo chmod +x run_script.sh

echo "Done building the script."
echo "Copy the script to the Rpi and execute it after the"
echo "'Prepare SD card' and 'First configuration' instructions at" 
echo "https://github.com/Puara/MPU/blob/main/building_instructions_os.md"
echo

trap - EXIT
