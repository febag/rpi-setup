#!/bin/sh
# Original script: https://github.com/thnk2wn/rasp-cat-siren/blob/main/pi-setup/sd-card-write.sh


# PARAMETERS #
# ./sd-card-write.sh [--host hostname]

# Final host name (not initial login)
host_name=""

while [[ $# -ge 1 ]]; do
    case $1 in
        -h|--host)
            host_name=$2
            shift
            ;;
        *)
            echo "Unrecognized option $1"
            exit 1
            ;;
    esac
    shift
done


# EXTERNAL DISK INFO #
disk_name=$(diskutil list external | grep -o '^/dev\S*')
if [ -z "$disk_name" ]; then
    echo "Didn't find an external disk" ; exit -1
fi

matches=$(echo -n "$disk_name" | grep -c '^')
if [ $matches -ne 1 ]; then
    echo "Found ${matches} external disk(s); expected 1" ; exit -1
fi

disk_free=$(df -l -h | grep "$disk_name" | egrep -oi '(\s+/Volumes/.*)' | egrep -o '(/.*)')

if [ -z "$disk_free" ]; then
    echo "Disk ${disk_name} doesn't appear mounted. Try reinserting SD card" ; exit -1
fi

volume=$(echo "$disk_free" | sed -e 's/\/.*\///g')

# Spit out disk info for user confirmation
diskutil list external
echo $disk_free
echo

read -p "Format ${disk_name} (${volume}) (y/n)?" CONT
if [ "$CONT" = "n" ]; then
  exit -1
fi


# DOWNLOAD AND EXTRACT RASPBERRY PI OS IMAGE #
image_path=./downloads
image_zip="$image_path/image.zip"
image_iso="$image_path/image.img"

# Consider checking latest ver/sha online, download only if newer
# https://downloads.raspberrypi.org/raspios_lite_armhf/images/?C=M;O=D
# For now just delete any prior download zip to force downloading latest version
if [ ! -f $image_zip ]; then
  mkdir -p ./downloads
  echo "Downloading latest Raspbian lite image"
  curl -o $image_zip -L "https://downloads.raspberrypi.org/raspios_lite_armhf_latest"

  if [ $? -ne 0 ]; then
    echo "Download failed" ; exit -1;
  fi
fi

echo "Extracting ${image_zip} ISO"
unzip -p $image_zip > $image_iso

if [ $? -ne 0 ]; then
    echo "Unzipping image ${image_zip} failed" ; exit -1;
fi


# EXTERNAL DISK FORMATTING #
echo "Formatting ${disk_name} as FAT32"
sudo diskutil eraseDisk FAT32 PI MBRFormat "$disk_name"

if [ $? -ne 0 ]; then
    echo "Formatting disk ${disk_name} failed" ; exit -1;
fi


# COPY THE IMAGE TO THE SD CARD #
echo "Unmounting ${disk_name} before writing image"
diskutil unmountdisk "$disk_name"

if [ $? -ne 0 ]; then
    echo "Unmounting disk ${disk_name} failed" ; exit -1;
fi

echo "Copying ${image_iso} to ${disk_name}. ctrl+t as desired for status"
sudo dd bs=1m if="$image_iso" of="$disk_name" conv=sync

if [ $? -ne 0 ]; then
  echo "Copying ${image_iso} to ${disk_name} failed" ; exit -1
fi

# Remount for further SD card mods. Drive may not be quite ready.
attempt=0
until [ $attempt -ge 3 ]
do
  sleep 2s
  echo "Remounting ${disk_name}"
  diskutil mountDisk "$disk_name" && break
  attempt=$[$attempt+1]
done

echo "Removing ${image_iso}. Re-extract later if needed from ${image_zip}"
rm $image_iso


# ENABLE SSH AND COPY INITIAL SETUP SCRIPT #
volume="/Volumes/boot"

echo "Enabling ssh"
touch "$volume"/ssh

if [ $? -ne 0 ]; then
  echo "Configuring ssh failed" ; exit -1
fi

echo "Copying setup script. After Pi boot, run: sudo /boot/setup.sh"
cp setup.sh "$volume"

if [ -n "$host_name" ]; then
  echo "Modifying setup script"
  # Replace "${host}" placeholder in the setup script on SD card with final host name passed to script
  sed -i -e "s/\${host}/${host_name}/" "$volume/setup.sh"
fi

# echo "Copying docker pull script for app updates"
# cp pull.sh "$volume"

# cp raspbian-build.sh "$volume" 


# EJECT DISK #
echo "Image burned. Remove SD card, insert in PI and power on"
sudo diskutil eject "$disk_name"


# REMOVE SSH KEYS #
echo "Removing any prior PI SSH known hosts entry"
ssh-keygen -R raspberrypi.local # initial
if [ -n "$host_name" ]; then
  ssh-keygen -R "$host_name.local"
fi

echo "Power up the PI and give it a minute then"
echo "  ssh pi@raspberrypi.local"
echo "  yes, raspberry"
echo "  sudo /boot/setup.sh"