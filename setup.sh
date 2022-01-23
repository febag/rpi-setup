#!/bin/bash

echo "Running automated raspi-config tasks"

# Via https://gist.github.com/damoclark/ab3d700aafa140efb97e510650d9b1be
# Execute the config options starting with 'do_' below
grep -E -v -e '^\s*#' -e '^\s*$' <<END | \
sed -e 's/$//' -e 's/^\s*/\/usr\/bin\/raspi-config nonint /' | bash -x -
#

# Drop this file in SD card root. After booting run: sudo /boot/setup.sh

# --- Begin raspi-config non-interactive config option specification ---

# Hardware Configuration
do_boot_wait 0            # Turn on waiting for network before booting
do_memory_split 1         # Set the GPU memory limit to 1MB

# System Configuration
do_configure_keyboard es
do_change_timezone Europe/Madrid
# do_change_locale LANG=es_ES.UTF-8
do_hostname ${host}

# Don't add any raspi-config configuration options after 'END' line below & don't remove 'END' line
END

# Note: do_camera 1 doesn't seem to work / be enough. Enabled below via /boot/config.txt mod.

############# CUSTOM COMMANDS ###########
# You may add your own custom GNU/Linux commands below this line
# These commands will execute as the root user

# Interactively set password for your login. Going through raspi-config w/do_change_pass is slower
sudo passwd pi

echo "Updating packages"
sudo apt-get update && sudo apt-get -y upgrade

echo "Set up a static IP Adress"
cat >> /etc/dhcpcd.conf << EOF

# Static IP address configuration
interface eth0
#IP address. First 24 bytes as subnet mask
static ip_address=10.128.0.244/24
#Router's IP address
static routers=10.128.0.1
static domain_name_servers= 1.1.1.1 8.8.8.8
EOF

echo "Restarting to apply changes. After run ssh pi@${host}.local"
# Reboot after all changes above complete
/sbin/shutdown -r now