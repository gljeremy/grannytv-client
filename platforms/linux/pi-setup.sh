#!/bin/bash
# First-time setup script for Raspberry Pi
# Run this once to set up everything needed for the IPTV player

echo "🍓 Setting up Raspberry Pi for IPTV Player..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y \
    python3-pip \
    mpv \
    git \
    curl \
    unclutter \
    xserver-xorg \
    xinit \
    alsa-utils

# Check and log MPV version for compatibility
echo "🎬 Checking MPV installation..."
if command -v mpv >/dev/null 2>&1; then
    MPV_VERSION=$(mpv --version 2>/dev/null | head -n1 || echo "Unknown")
    echo "   Installed MPV: $MPV_VERSION"
    echo "   ✅ MPV is 30-50% more efficient than VLC on Pi hardware"
    
    # Log for future reference
    mkdir -p "$PI_PATH"
    echo "$(date): Setup - $MPV_VERSION" >> "$PI_PATH/mpv_version_history.log"
    
    # Provide version-specific guidance
    case "$MPV_VERSION" in
        *"0.3"*|*"0.4"*)
            echo "   ✅ MPV 0.3x+ - Excellent Pi optimization support"
            echo "   🚀 Hardware decode, efficient caching, and low CPU usage"
            ;;
        *)
            echo "   ✅ MPV installed - Using conservative optimized settings"
            ;;
    esac
else
    echo "   ❌ MPV installation failed!"
    echo "   💡 Try: sudo apt install mpv"
    exit 1
fi

# Install Python packages and venv
echo "🐍 Installing Python and virtual environment support..."
sudo apt install -y python3-pip python3-venv

# Create project directory
PI_PATH="/home/jeremy/gtv"
mkdir -p "$PI_PATH"

# Enable SSH (if not already enabled)
echo "🔐 Ensuring SSH is enabled..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure auto-login (optional, for kiosk mode)
echo "🖥️ Configuring auto-login..."
sudo raspi-config nonint do_boot_behaviour B4

# Set up audio output to HDMI
echo "🔊 Configuring audio output..."
sudo amixer cset numid=3 2  # Force HDMI audio
amixer set Master 80% unmute

# Create .xinitrc for GUI startup
echo "Creating GUI startup configuration..."
cat > /home/jeremy/.xinitrc << 'EOF'
#!/bin/bash
# Hide mouse cursor
unclutter -idle 1 -root &

# Set black background
xsetroot -solid black

# Start IPTV player
cd /home/jeremy/gtv
source venv/bin/activate
python iptv_smart_player.py
EOF

chmod +x /home/jeremy/.xinitrc

# Configure boot to desktop
sudo raspi-config nonint do_boot_behaviour B4

echo ""
echo "✅ Basic setup complete!"
echo ""
echo "🌐 Next steps:"
echo "1. Clone your GitHub repository:"
echo "   cd $PI_PATH"
echo "   git clone https://github.com/YOUR_USERNAME/grannytv-client.git ."
echo ""
echo "2. Run the update script:"
echo "   ./pi-update.sh"
echo ""
echo "3. Install the systemd service:"
echo "   sudo cp iptv-player.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable iptv-player"
echo ""
echo "4. Reboot to test:"
echo "   sudo reboot"
echo ""
echo "📋 Manual clone command:"
echo "git clone https://github.com/gljeremy/grannytv-client.git $PI_PATH"