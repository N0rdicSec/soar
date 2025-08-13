#!/bin/bash

cat << "EOF"
 _______  _______  _                 _        _              _______  _______  _______  _______                 _______  ______   _______ _________ _______ 
(  ____ \(  ____ )( \      |\     /|( (    /|| \    /\      (  ____ \(  ___  )(  ___  )(  ____ )      |\     /|(  ____ )(  __  \ (  ___  )\__   __/(  ____ \
| (    \/| (    )|| (      | )   ( ||  \  ( ||  \  / /      | (    \/| (   ) || (   ) || (    )|      | )   ( || (    )|| (  \  )| (   ) |   ) (   | (    \/
| (_____ | (____)|| |      | |   | ||   \ | ||  (_/ /       | (_____ | |   | || (___) || (____)|      | |   | || (____)|| |   ) || (___) |   | |   | (__    
(_____  )|  _____)| |      | |   | || (\ \) ||   _ (        (_____  )| |   | ||  ___  ||     __)      | |   | ||  _____)| |   | ||  ___  |   | |   |  __)   
      ) || (      | |      | |   | || | \   ||  ( \ \             ) || |   | || (   ) || (\ (         | |   | || (      | |   ) || (   ) |   | |   | (      
/\____) || )      | (____/\| (___) || )  \  ||  /  \ \      /\____) || (___) || )   ( || ) \ \__      | (___) || )      | (__/  )| )   ( |   | |   | (____/\
\_______)|/       (_______/(_______)|/    )_)|_/    \/      \_______)(_______)|/     \||/   \__/      (_______)|/       (______/ |/     \|   )_(   (_______/
EOF

echo "_________________________________________________________________________"
echo "|Tips:                                                                   |"
echo "| > Make sure you have the user 'phantom', which owns the phantom folder.|"
echo "| > Usually the SOAR folder is '/opt/phantom.' So, the script should be  |"
echo "|   in the '/opt' folder.                                                |"
echo "| > The installation log is at '/opt/var/log/phantom'                    |"
echo "| > Please verify the Preparation documentation mentioned below.         |"
echo "|________________________________________________________________________|"

echo "Last update: 1/30/2024"
echo "Source: Instalation - https://docs.splunk.com/Documentation/SOARonprem/6.3.1/Install/PrepareSystemForUpgrading"
echo "          Preparatoion - https://docs.splunk.com/Documentation/SOARonprem/6.3.1/Install/PrepareSystemForUpgrading"
echo ""
rpm -q redhat-release
echo ""
echo ""

# Define variables
INSTALLER_PATTERN="splunk_soar-unpriv-*-x86_64.tgz"

# Function to prompt for confirmation
confirm() {
    while true; do
        read -rp "$1 [Y/N]: " yn
        case "$yn" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer Y or N." ;;
        esac
    done
}

echo "Update Preparation"

# Prompt user for PHANTOM_HOME if not set
if [ -z "$PHANTOM_HOME" ]; then
    read -rp "Enter the full path for PHANTOM_HOME (default: /opt/phantom/): " input_path
    PHANTOM_HOME="${input_path:-/opt/phantom/}"
fi

# Verify that PHANTOM_HOME exists
if [ ! -d "$PHANTOM_HOME" ]; then
    echo "Error: PHANTOM_HOME directory does not exist: $PHANTOM_HOME"
    echo "Please ensure the directory exists before running the script."
    exit 1
fi

echo "Step 1: Log in to the Splunk SOAR (On-premises) instance's operating system"
echo "Ensure you are logged in as the appropriate user before proceeding."

echo "Step 2: Disable warm standby and ibackup.pyc (if applicable)"
if confirm "Do you use warm standby or ibackup.pyc for backups?"; then
    echo "If using warm standby, disable it via the admin panel."
    echo "If using automation for backups (e.g., cron job for ibackup.pyc), disable the cron job."
else
    echo "Skipping warm standby and ibackup.pyc steps."
fi

echo "Step 3: Stop all Splunk SOAR (On-premises) services"
if confirm "Do you want to stop all Splunk SOAR services now?"; then
    sudo $PHANTOM_HOME/bin/stop_phantom.sh
else
    echo "Skipping service stop. Ensure services are stopped before proceeding."
fi

echo "Step 4: Clear YUM caches"
if confirm "Do you want to clear the YUM caches?"; then
    sudo yum clean all
else
    echo "Skipping YUM cache cleanup."
fi

echo "Step 5: Update installed software packages and apply OS patches"
if confirm "Do you want to update the operating system and installed packages?"; then
    sudo yum update -y
else
    echo "Skipping OS and package updates."
fi

echo "Step 6: Restart the operating system"
if confirm "Do you want to restart the system now?"; then
    sudo reboot
    exit 0  # Ensure the script stops execution since the system is rebooting
else
    echo "Skipping reboot. Ensure the system is restarted before proceeding."
fi

echo "Step 7: Check if the cron daemon is running"
if confirm "Do you want to check the cron daemon status?"; then
    ps -ef | grep crond
    if ! pgrep -x "crond" > /dev/null; then
        echo "Cron daemon is not running. Starting it now."
        sudo systemctl start crond.service
    else
        echo "Cron daemon is already running."
    fi
else
    echo "Skipping cron daemon check."
fi

echo "Step 8: Run the Splunk SOAR preparation script"
if confirm "Do you want to run the soar-prepare-system script?"; then
    sudo ./soar-prepare-system
else
    echo "Skipping soar-prepare-system script execution."
fi

# Instalation starts here
echo "Installation starts now..."

echo "Step 1: Restart the operating system"
if confirm "Do you want to restart the operating system now?"; then
    sudo /sbin/reboot
else
    echo "Skipping reboot. Please ensure the system is restarted before proceeding."
fi

echo "Step 2: Log in as the user that owns Splunk SOAR"
echo "Ensure you are logged in as the correct user before continuing."

echo "Step 3: Search for the installer file"
INSTALLER=$(find . -name "$INSTALLER_PATTERN" -print -quit)
if [ -z "$INSTALLER" ]; then
    echo "Error: No installer file matching the pattern '$INSTALLER_PATTERN' found."
    echo "Please download the installer and place it in the script directory."
    exit 1
fi
echo "Found installer: $INSTALLER"

echo "Step 4: Confirm removal of existing Splunk SOAR directory"
if confirm "Do you want to remove the existing Splunk SOAR directory?"; then
    rm -rf "$PHANTOM_HOME/splunk-soar"
else
    echo "Skipping removal of existing Splunk SOAR directory."
fi

echo "Step 5: Extract the TAR file into the Splunk SOAR installation directory"
if confirm "Do you want to extract the installer?"; then
    tar -xvf "$INSTALLER" -C "$PHANTOM_HOME"
else
    echo "Skipping extraction."
fi

echo "Step 6: Ensure the current Splunk SOAR installation is running"
if confirm "Do you want to start Splunk SOAR?"; then
    "$PHANTOM_HOME/bin/start_phantom.sh"
else
    echo "Skipping startup."
fi

echo "Step 7: Change to Splunk SOAR directory"
if ! cd "$PHANTOM_HOME/splunk-soar"; then
    echo "Error: Could not change directory to $PHANTOM_HOME/splunk-soar."
    exit 1
fi

echo "Step 8: Update the install_common.py file"
if confirm "Do you want to update the install_common.py file?"; then
    sed -i 's/mirror/vault/' "$PHANTOM_HOME/splunk-soar/install/install_common.py"
else
    echo "Skipping file update."
fi

echo "Step 9: Run the ugrade script"
if confirm "Do you want to run the upgrade script?"; then
    ./soar-install --upgrade --with-apps
else
    echo "Skipping upgrade."
fi

echo "Step 10: Verify upgrade completion"
echo "Log in to the Splunk SOAR web interface to confirm."

echo "Optional: Remove the installer file"
if confirm "Do you want to remove the installer file?"; then
    rm -f "$INSTALLER"
else
    echo "Installer file retained."
fi
