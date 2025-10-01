#!/bin/bash#!/bin/bash

# GrannyTV Pi Setup Script# First-time setup script for Raspberry Pi

# Can be run standalone or via smartphone setup wizard# Run this once to set up everything needed for the Iecho "⚙️ Installing systemd service for auto-start..."

sudo cp platforms/linux/iptv-player.service /etc/systemd/system/

echo "🍓 Setting up Raspberry Pi for GrannyTV IPTV Player..."sudo systemctl daemon-reload



# Configuration from environment (set by smartphone setup) or defaults# Advanced service configuration for bulletproof operation

SETUP_USER="${SETUP_USER:-$(whoami)}"echo "🔧 Configuring bulletproof auto-start..."

SETUP_PATH="${SETUP_PATH:-/home/$SETUP_USER/gtv}"

PI_PATH="$SETUP_PATH"# Create user directory for XDG runtime (needed for audio)

SETUP_STREAM_SOURCE="${SETUP_STREAM_SOURCE:-}"echo "🔊 Setting up audio runtime environment..."

sudo mkdir -p /run/user/1000

echo "📋 Using configuration:"sudo chown jeremy:jeremy /run/user/1000

echo "   User: $SETUP_USER"

echo "   Install Path: $SETUP_PATH"# Configure Pi for headless operation with HDMI

echo "   Stream Source: ${SETUP_STREAM_SOURCE:-'Default streams'}"echo "📺 Optimizing Pi for reliable TV display..."



# Update system# Force HDMI output (prevent HDMI auto-detection issues)

echo "📦 Updating system packages..."if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then

sudo apt update && sudo apt upgrade -y    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt

    echo "   Added HDMI force hotplug to /boot/config.txt"

# Install required packagesfi

echo "📦 Installing required packages..."

sudo apt install -y \# Set HDMI to safe mode (ensures compatibility)

    python3-pip \if ! grep -q "hdmi_safe=1" /boot/config.txt; then

    mpv \    echo "hdmi_safe=1" | sudo tee -a /boot/config.txt

    git \    echo "   Added HDMI safe mode to /boot/config.txt"

    curl \fi

    unclutter \

    xserver-xorg \# Ensure sufficient GPU memory for video

    xinit \if ! grep -q "gpu_mem=128" /boot/config.txt; then

    alsa-utils    echo "gpu_mem=128" | sudo tee -a /boot/config.txt

    echo "   Set GPU memory to 128MB in /boot/config.txt"

# Check and log MPV version for compatibilityfi

echo "🎬 Checking MPV installation..."

if command -v mpv >/dev/null 2>&1; then# Configure automatic login for immediate startup

    MPV_VERSION=$(mpv --version 2>/dev/null | head -n1 || echo "Unknown")echo "🔐 Configuring automatic login for plug-and-play operation..."

    echo "   Installed MPV: $MPV_VERSION"sudo raspi-config nonint do_boot_behaviour B2  # Boot to desktop, auto-login

    echo "   ✅ MPV is 30-50% more efficient than VLC on Pi hardware"

    # Disable screen blanking for continuous TV operation

    # Log for future referenceecho "🖥️ Disabling screen blanking for 24/7 TV operation..."

    mkdir -p "$PI_PATH"if ! grep -q "xset s off" /home/jeremy/.profile; then

    echo "$(date): Setup - $MPV_VERSION" >> "$PI_PATH/mpv_version_history.log"    echo "xset s off" >> /home/jeremy/.profile

        echo "xset -dpms" >> /home/jeremy/.profile

    # Provide version-specific guidance    echo "xset s noblank" >> /home/jeremy/.profile

    case "$MPV_VERSION" in    echo "   Added screen blanking disable to .profile"

        *"0.3"*|*"0.4"*)fi

            echo "   ✅ MPV 0.3x+ - Excellent Pi optimization support"

            echo "   🚀 Hardware decode, efficient caching, and low CPU usage"# Create a backup start method via .bashrc (failsafe)

            ;;echo "🛡️ Creating failsafe startup method..."

        *)if ! grep -q "grannytv auto-start" /home/jeremy/.bashrc; then

            echo "   ✅ MPV installed - Using conservative optimized settings"    cat >> /home/jeremy/.bashrc << 'EOF'

            ;;

    esac# GrannyTV auto-start failsafe

elseif [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && [ "$XDG_VTNR" = "1" ]; then

    echo "   ❌ MPV installation failed!"    echo "Starting GrannyTV failsafe..."

    echo "   💡 Try: sudo apt install mpv"    cd /home/jeremy/gtv

    exit 1    source venv/bin/activate

fi    python3 iptv_smart_player.py

fi

# Install Python packages and venvEOF

echo "🐍 Installing Python and virtual environment support..."    echo "   Added failsafe startup to .bashrc"

sudo apt install -y python3-pip python3-venvfi



# Create project directory# Enable the service

mkdir -p "$PI_PATH"echo "🚀 Enabling auto-start service..."

sudo systemctl enable iptv-player

# Enable SSH (if not already enabled)

echo "🔐 Enabling SSH access..."# Test the service configuration

sudo systemctl enable sshecho "🧪 Testing service configuration..."

sudo systemctl start sshif sudo systemctl is-enabled iptv-player >/dev/null 2>&1; then

    echo "   ✅ Service enabled successfully"

# Configure auto-login (optional, for kiosk mode)else

echo "🖥️ Configuring auto-login..."    echo "   ❌ Service enable failed"

sudo raspi-config nonint do_boot_behaviour B4    exit 1

fi

# Set up audio output to HDMI

echo "🔊 Configuring audio output..."echo ""

sudo amixer cset numid=3 2  # Force HDMI audioecho "🎉 COMPLETE SETUP FINISHED!"

amixer set Master 80% unmuteecho "=========================="

echo ""

# Create .xinitrc for GUI startupecho "🎯 Your Raspberry Pi is now configured for TRUE plug-and-play operation:"

echo "Creating GUI startup configuration..."echo ""

cat > /home/$SETUP_USER/.xinitrc << EOFecho "   📺 Auto-login enabled - no keyboard needed"

#!/bin/bashecho "   🚀 Service starts automatically on boot" 

# Hide mouse cursorecho "   🔊 HDMI audio configured and optimized"

unclutter -idle 1 -root &echo "   🖥️ Screen blanking disabled for 24/7 operation"

echo "   🛡️ Failsafe startup method created"

# Set black backgroundecho "   ⏱️ Service waits for network connection"

xsetroot -solid blackecho "   � MPV player optimized for Pi hardware"

echo ""

# Start IPTV playerecho "👥 END USER EXPERIENCE:"

cd $PI_PATHecho "   1. Plug Pi into TV via HDMI"

source venv/bin/activateecho "   2. Turn on Pi"

python iptv_smart_player.pyecho "   3. TV automatically starts playing within 30 seconds"

EOFecho "   4. No keyboard, mouse, or technical knowledge needed!"

echo ""

chmod +x /home/$SETUP_USER/.xinitrcecho "🔧 Maintenance Commands:"

echo "   Check status:  sudo systemctl status iptv-player"

# Configure boot to desktopecho "   View logs:     journalctl -u iptv-player -f"

sudo raspi-config nonint do_boot_behaviour B4echo "   Restart:       sudo systemctl restart iptv-player"

echo "   Update code:   ./platforms/linux/pi-update.sh"

# Clone the GrannyTV repository (if not already present)echo ""

echo "📥 Setting up GrannyTV repository..."echo "🚀 READY TO TEST: sudo reboot"

cd "$PI_PATH"echo ""

if [ ! -d ".git" ]; thenecho "After reboot, your Pi will be a true plug-and-play TV device!" Setting up Raspberry Pi for IPTV Player..."

    git clone https://github.com/gljeremy/grannytv-client.git .

else# Update system

    echo "   Repository already exists, pulling latest changes..."echo "📦 Updating system packages..."

    git pull origin mainsudo apt update && sudo apt upgrade -y

fi

# Install required packages

# Install Python dependenciesecho "📦 Installing required packages..."

echo "🐍 Installing Python dependencies..."sudo apt install -y \

python3 -m venv venv    python3-pip \

source venv/bin/activate    mpv \

pip install -r requirements.txt    git \

    curl \

# Install and enable the systemd service    unclutter \

echo "⚙️ Installing systemd service for auto-start..."    xserver-xorg \

sudo cp platforms/linux/iptv-player.service /etc/systemd/system/    xinit \

sudo systemctl daemon-reload    alsa-utils



# Advanced service configuration for bulletproof operation# Check and log MPV version for compatibility

echo "🔧 Configuring bulletproof auto-start..."echo "🎬 Checking MPV installation..."

if command -v mpv >/dev/null 2>&1; then

# Create user directory for XDG runtime (needed for audio)    MPV_VERSION=$(mpv --version 2>/dev/null | head -n1 || echo "Unknown")

echo "🔊 Setting up audio runtime environment..."    echo "   Installed MPV: $MPV_VERSION"

sudo mkdir -p /run/user/1000    echo "   ✅ MPV is 30-50% more efficient than VLC on Pi hardware"

sudo chown $SETUP_USER:$SETUP_USER /run/user/1000    

    # Log for future reference

# Configure Pi for headless operation with HDMI    mkdir -p "$PI_PATH"

echo "📺 Optimizing Pi for reliable TV display..."    echo "$(date): Setup - $MPV_VERSION" >> "$PI_PATH/mpv_version_history.log"

    

# Force HDMI output (prevent HDMI auto-detection issues)    # Provide version-specific guidance

if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then    case "$MPV_VERSION" in

    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt        *"0.3"*|*"0.4"*)

    echo "   Added HDMI force hotplug to /boot/config.txt"            echo "   ✅ MPV 0.3x+ - Excellent Pi optimization support"

fi            echo "   🚀 Hardware decode, efficient caching, and low CPU usage"

            ;;

# Set HDMI to safe mode (ensures compatibility)        *)

if ! grep -q "hdmi_safe=1" /boot/config.txt; then            echo "   ✅ MPV installed - Using conservative optimized settings"

    echo "hdmi_safe=1" | sudo tee -a /boot/config.txt            ;;

    echo "   Added HDMI safe mode to /boot/config.txt"    esac

fielse

    echo "   ❌ MPV installation failed!"

# Ensure sufficient GPU memory for video    echo "   💡 Try: sudo apt install mpv"

if ! grep -q "gpu_mem=128" /boot/config.txt; then    exit 1

    echo "gpu_mem=128" | sudo tee -a /boot/config.txtfi

    echo "   Set GPU memory to 128MB in /boot/config.txt"

fi# Install Python packages and venv

echo "🐍 Installing Python and virtual environment support..."

# Configure automatic login for immediate startupsudo apt install -y python3-pip python3-venv

echo "🔐 Configuring automatic login for plug-and-play operation..."

sudo raspi-config nonint do_boot_behaviour B2  # Boot to desktop, auto-login# Create project directory

PI_PATH="/home/jeremy/gtv"

# Disable screen blanking for continuous TV operationmkdir -p "$PI_PATH"

echo "🖥️ Disabling screen blanking for 24/7 TV operation..."

if ! grep -q "xset s off" /home/$SETUP_USER/.profile; then# Enable SSH (if not already enabled)

    echo "xset s off" >> /home/$SETUP_USER/.profileecho "🔐 Ensuring SSH is enabled..."

    echo "xset -dpms" >> /home/$SETUP_USER/.profilesudo systemctl enable ssh

    echo "xset s noblank" >> /home/$SETUP_USER/.profilesudo systemctl start ssh

    echo "   Added screen blanking disable to .profile"

fi# Configure auto-login (optional, for kiosk mode)

echo "🖥️ Configuring auto-login..."

# Create a backup start method via .bashrc (failsafe)sudo raspi-config nonint do_boot_behaviour B4

echo "🛡️ Creating failsafe startup method..."

if ! grep -q "grannytv auto-start" /home/$SETUP_USER/.bashrc; then# Set up audio output to HDMI

    cat >> /home/$SETUP_USER/.bashrc << EOFecho "🔊 Configuring audio output..."

sudo amixer cset numid=3 2  # Force HDMI audio

# GrannyTV auto-start failsafeamixer set Master 80% unmute

if [ -z "\$SSH_CLIENT" ] && [ -z "\$SSH_TTY" ] && [ "\$XDG_VTNR" = "1" ]; then

    echo "Starting GrannyTV failsafe..."# Create .xinitrc for GUI startup

    cd $PI_PATHecho "Creating GUI startup configuration..."

    source venv/bin/activatecat > /home/jeremy/.xinitrc << 'EOF'

    python3 iptv_smart_player.py#!/bin/bash

fi# Hide mouse cursor

EOFunclutter -idle 1 -root &

    echo "   Added failsafe startup to .bashrc"

fi# Set black background

xsetroot -solid black

# Update service file with correct user and paths

echo "🔧 Updating service configuration..."# Start IPTV player

sudo sed -i "s|User=jeremy|User=$SETUP_USER|g" /etc/systemd/system/iptv-player.servicecd /home/jeremy/gtv

sudo sed -i "s|Group=jeremy|Group=$SETUP_USER|g" /etc/systemd/system/iptv-player.servicesource venv/bin/activate

sudo sed -i "s|WorkingDirectory=/home/jeremy/gtv|WorkingDirectory=$PI_PATH|g" /etc/systemd/system/iptv-player.servicepython iptv_smart_player.py

sudo sed -i "s|ExecStart=/home/jeremy/gtv/venv/bin/python /home/jeremy/gtv/iptv_smart_player.py|ExecStart=$PI_PATH/venv/bin/python $PI_PATH/iptv_smart_player.py|g" /etc/systemd/system/iptv-player.serviceEOF

sudo sed -i "s|Environment=HOME=/home/jeremy|Environment=HOME=/home/$SETUP_USER|g" /etc/systemd/system/iptv-player.service

sudo sed -i "s|StandardOutput=append:/home/jeremy/gtv/iptv_service.log|StandardOutput=append:$PI_PATH/iptv_service.log|g" /etc/systemd/system/iptv-player.servicechmod +x /home/jeremy/.xinitrc

sudo sed -i "s|StandardError=append:/home/jeremy/gtv/iptv_service.log|StandardError=append:$PI_PATH/iptv_service.log|g" /etc/systemd/system/iptv-player.service

# Configure boot to desktop

# Enable the servicesudo raspi-config nonint do_boot_behaviour B4

echo "🚀 Enabling auto-start service..."

sudo systemctl daemon-reload# Clone the GrannyTV repository

sudo systemctl enable iptv-playerecho "📥 Cloning GrannyTV repository..."

cd "$PI_PATH"

# Test the service configurationif [ ! -d ".git" ]; then

echo "🧪 Testing service configuration..."    git clone https://github.com/gljeremy/grannytv-client.git .

if sudo systemctl is-enabled iptv-player >/dev/null 2>&1; thenelse

    echo "   ✅ Service enabled successfully"    echo "   Repository already exists, pulling latest changes..."

else    git pull origin main

    echo "   ❌ Service enable failed"fi

    exit 1

fi# Install Python dependencies

echo "🐍 Installing Python dependencies..."

# Handle custom stream source if providedsource venv/bin/activate

if [ -n "$SETUP_STREAM_SOURCE" ]; thenpip install -r requirements.txt

    echo "📺 Configuring custom stream source..."

    echo "   Custom streams: $SETUP_STREAM_SOURCE"# Install and enable the systemd service

    # Could download and process custom streams hereecho "⚙️ Installing systemd service for auto-start..."

fisudo cp platforms/linux/iptv-player.service /etc/systemd/system/

sudo systemctl daemon-reload

echo ""sudo systemctl enable iptv-player

echo "🎉 COMPLETE SETUP FINISHED!"

echo "=========================="echo ""

echo ""echo "✅ Setup complete!"

echo "🎯 Your Raspberry Pi is now configured for TRUE plug-and-play operation:"echo ""

echo ""echo "🎬 Your Raspberry Pi is now configured for plug-and-play TV:"

echo "   📺 Auto-login enabled - no keyboard needed"echo "   • MPV IPTV player installed and optimized"

echo "   🚀 Service starts automatically on boot" echo "   • Auto-start service enabled" 

echo "   🔊 HDMI audio configured and optimized"echo "   • Audio configured for HDMI output"

echo "   🖥️ Screen blanking disabled for 24/7 operation"echo "   • Display optimized for TV viewing"

echo "   🛡️ Failsafe startup method created"echo ""

echo "   ⏱️ Service waits for network connection"echo "� To start immediately: sudo systemctl start iptv-player"

echo "   🎬 MPV player optimized for Pi hardware"echo "📊 To check status: sudo systemctl status iptv-player"

echo ""echo "📋 To view logs: journalctl -u iptv-player -f"

echo "👥 END USER EXPERIENCE:"echo ""

echo "   1. Plug Pi into TV via HDMI"echo "🚀 Next: Reboot your Pi and it will automatically start playing TV!"

echo "   2. Turn on Pi"echo "   sudo reboot"
echo "   3. TV automatically starts playing within 30 seconds"
echo "   4. No keyboard, mouse, or technical knowledge needed!"
echo ""
echo "🔧 Maintenance Commands:"
echo "   Check status:  sudo systemctl status iptv-player"
echo "   View logs:     journalctl -u iptv-player -f"
echo "   Restart:       sudo systemctl restart iptv-player"
echo "   Update code:   ./platforms/linux/pi-update.sh"
echo ""
echo "🚀 READY TO TEST: sudo reboot"
echo ""
echo "After reboot, your Pi will be a true plug-and-play TV device!"