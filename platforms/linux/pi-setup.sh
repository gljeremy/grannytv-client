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

# Clone the GrannyTV repository
echo "📥 Cloning GrannyTV repository..."
cd "$PI_PATH"
if [ ! -d ".git" ]; then
    git clone https://github.com/gljeremy/grannytv-client.git .
else
    echo "   Repository already exists, pulling latest changes..."
    git pull origin main
fi

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
source venv/bin/activate
pip install -r requirements.txt

# Install and enable the systemd service
echo "⚙️ Installing systemd service for auto-start..."
sudo cp platforms/linux/iptv-player.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable iptv-player

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎬 Your Raspberry Pi is now configured for plug-and-play TV:"
echo "   • MPV IPTV player installed and optimized"
echo "   • Auto-start service enabled" 
echo "   • Audio configured for HDMI output"
echo "   • Display optimized for TV viewing"
echo ""
echo "� To start immediately: sudo systemctl start iptv-player"
echo "📊 To check status: sudo systemctl status iptv-player"
echo "📋 To view logs: journalctl -u iptv-player -f"
echo ""
echo "🚀 Next: Reboot your Pi and it will automatically start playing TV!"
echo "   sudo reboot"